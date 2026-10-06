#!/usr/bin/env python3
"""Imported ability learn levels (Data/SpellRanks.lua) and the Forever change report."""
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path
from wowmock import runtime, start_battleplan, screen, WARRIOR_20, ROGUE_30, PRIEST_40

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
import import_class_data as importer

checks = 0


def check(condition, label):
    global checks
    checks += 1
    assert condition, label


# Generated files are fresh and deterministic.
ranks_lua, changes_md = importer.build()
check(ranks_lua == importer.RANKS_OUT.read_text(encoding='utf-8'), 'SpellRanks.lua regenerates identically')
check(changes_md == importer.CHANGES_OUT.read_text(encoding='utf-8'), 'FOREVER-CHANGES.md regenerates identically')
subprocess.run([sys.executable, str(ROOT / 'tools/import_class_data.py'), '--check'], check=True,
               stdout=subprocess.DEVNULL)

classes, changes, provenance = importer.load()
ranks = importer.spell_ranks(classes)
check(sorted(ranks) == ['DRUID', 'HUNTER', 'MAGE', 'PALADIN', 'PRIEST', 'ROGUE', 'SHAMAN', 'WARLOCK', 'WARRIOR'],
      'all nine classes imported')
warrior = ranks['WARRIOR']
# changes.json: Forever moved Slam from 30 to 20 and added a fifth rank.
check(warrior['Slam']['ranks'] == [20, 30, 38, 46, 54], 'Forever Slam levels, not Classic')
check(warrior['Taunt'].get('quest') and warrior['Taunt']['level'] == 10, 'quest-taught abilities marked')
check('Devastate' not in warrior and 'Commanding Shout' not in warrior, 'Season of Discovery runes left out')
check(ranks['PRIEST']['Desperate Prayer']['races'] == ['Dwarf'], 'racial priest spells keep their race')
check(ranks['MAGE']['Teleport: Ironforge']['faction'] == 'Alliance', 'faction spells keep their faction')
check(ranks['DRUID']['Bear Form'] == {'id': 5487, 'level': 10, 'quest': True}, 'subtext like Shapeshift is not a rank')
check(all(1 <= e['level'] <= 60 for c in ranks.values() for e in c.values()), 'learn levels in range')

# Tooltip prose stays out of the generated report.
prose = [a.get('era') or a.get('d') for v in changes.values() for kind in v.values() if isinstance(kind, list)
         for a in kind if isinstance(a, dict) and (a.get('era') or a.get('d'))]
check(prose and not any(p in changes_md for p in prose), 'no tooltip text copied')
check('Slam: Rank 1 30 to 20' in changes_md, 'level changes listed Classic to Forever')

# Battleplan's hand-written data agrees with the import and avoids what Forever removed.
CLASS_IDS = {'WARRIOR': '1', 'ROGUE': '4', 'PRIEST': '5'}
for cls, cid in CLASS_IDS.items():
    gone = {t['n'] for kind in ('talentsRemoved', 'talentsReplaced', 'talentsHidden') for t in changes[cid][kind]}
    gone |= {a['n'] for kind in ('abilitiesRemoved', 'abilitiesInClientNotTaught') for a in changes[cid][kind]}
    # Spells.lua is a capture of the spellbook; Sword Specialization there is the Human racial.
    for path in sorted(p for p in (ROOT / 'Battleplan/Data' / cls).glob('*.lua') if p.name != 'Spells.lua'):
        text = path.read_text(encoding='utf-8')
        for name in gone:
            check(f'"{name}"' not in text, f'{path.name} names {name}, which Forever removed')
        for name, level in re.findall(r'spell = "([^"]+)"[^}]*?minLevel = (\d+)', text):
            if name in ranks[cls]:
                check(ranks[cls][name]['level'] == int(level),
                      f'{cls} {path.name}: {name} minLevel {level}, import says {ranks[cls][name]["level"]}')


def fresh(char):
    lua = runtime(char)
    ns = start_battleplan(lua)
    lua.globals().BP = ns
    return lua, ns


# The player sees trainable ranks and learn levels the rotation data didn't carry.
L, ns = fresh(ROGUE_30)
rotation = screen(L, ns, 'rotation')
check('Kick | |cff40ff40Rank 2 at trainer|r' in rotation, 'known spell with a higher trainable rank')
check('Eviscerate | Rank 4' in rotation, 'no trainer hint when the known rank is current')

L, ns = fresh(PRIEST_40)
check('3. Smite | |cff40ff40Rank 6 at trainer|r' in screen(L, ns, 'rotation'), 'Priest rank hint')

L, ns = fresh(WARRIOR_20)
rotation = screen(L, ns, 'rotation')
check('Defensive Stance | quest, level 10' in rotation, 'quest ability is not "train now"')
check('Battle Shout | |cff40ff40train now|r' in rotation, 'imported level fills a missing minLevel')
check('Shield Wall | level 28' in screen(L, ns, 'tanking'), 'tank guide still upcoming by level')

# Engine rules, directly: a hand-written minLevel wins, quests never offer a trainer rank.
L.execute('''
  local R = BP.Engine.Rotation
  local imported = { Strike = { id = 9, level = 4, ranks = { 4, 10, 20 } }, Shout = { id = 8, level = 10, quest = true,
    ranks = { 10, 12 } } }
  local up = {}
  rows = R.Filter({ { spell = "Strike" }, { spell = "Shout" }, { spell = "Later", minLevel = 30 } },
    { Strike = { best = 1, id = 9 }, Shout = { best = 1, id = 8 } }, 12, up, {}, nil, imported)
  upcoming = up
  local up2 = {}
  R.Filter({ { spell = "Strike", minLevel = 6 } }, {}, 12, up2, {}, nil, imported)
  override = up2[1]
''')
g = L.globals()
check(g.rows[1].trainRank == 2, 'highest rank within level')
check(g.rows[2].trainRank is None, 'quest-taught ranks are not trainer ranks')
check(g.upcoming[1].minLevel == 30 and not g.upcoming[1].trainable, 'unimported entry keeps its own level')
check(g.override.minLevel == 6 and g.override.spellID == 9, 'hand-written minLevel wins; imported id fills in')

print(f'class data test passed ({checks} checks)')
