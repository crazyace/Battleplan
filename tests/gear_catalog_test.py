#!/usr/bin/env python3
"""Dated catalog regeneration and provisional in-game planning integration."""
import copy
import importlib.util
import json
import tempfile
from pathlib import Path
from wowmock import runtime, start_battleplan, drain, screen, ROGUE_30, PRIEST_40

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('gear_import', ROOT / 'tools/import_gear_catalog.py')
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)
data = json.loads(importer.SOURCE.read_text())
checks = 0


def check(condition, label):
    global checks
    checks += 1
    assert condition, label


def reject(change, label):
    bad = copy.deepcopy(data)
    change(bad)
    try:
        importer.render(bad)
    except (ValueError, KeyError):
        check(True, label)
    else:
        check(False, label)


check(len(data['records']) == 133, 'dated cohort has 133 items')
check(importer.render(data) == importer.OUTPUT.read_text(), 'generated Lua matches input')
check(len(data['sourceSha256']) == 64 and len(data['recipeShardSha256']) == 64, 'source hashes retained')
reject(lambda d: d.update(_status='verified'), 'cannot promote external catalog to verified')
reject(lambda d: d['records'].append(d['records'][0]), 'duplicate item ID rejected')
reject(lambda d: d['records'][0]['item'].update(b=1), 'bind-on-pickup crafting rejected')
reject(lambda d: d['records'][0]['item'].update(sp=[[1, 1234]]), 'unmodeled effects rejected')
reject(lambda d: d['records'][0]['item'].update(rs=202), 'wearer profession restriction rejected')
reject(lambda d: d['records'][0]['item'].update(el=31), 'effective level above cap rejected')
reject(lambda d: d['records'][0]['item'].update(inv=11), 'duplicate-slot jewelry excluded')
reject(lambda d: d['records'][0]['item'].update(st=[[999, 5]]), 'unknown stat cannot silently disappear')
reject(lambda d: d['records'][0].update(recipes=[]), 'source-less candidate rejected')
reject(lambda d: d['records'][0]['item'].update(st=[[7, -5]]), 'negative source stat rejected')
reject(lambda d: d['records'][0]['item'].update(st=[[7, float('nan')]]), 'nonfinite source stat rejected')
reject(lambda d: d['records'][0].update(recipes=[['tailoring', 1]]), 'malformed recipe rejected')
with tempfile.TemporaryDirectory() as directory:
    folder = Path(directory)
    (folder / 'crafting').mkdir()
    record = data['records'][0]
    bad_item = dict(record['item'], id=999999, b=1)
    (folder / 'items.json').write_text(json.dumps([record['item'], bad_item]))
    (folder / 'stats-explained.json').write_text(json.dumps({'build': 'test-build'}))
    (folder / 'crafting/0.json').write_text(json.dumps({
        str(record['item']['id']): {'made': record['recipes']}, '999999': {'made': record['recipes']}}))
    snapshot = importer.snapshot(folder, '2026-10-05')
    check(snapshot['sourceBuild'] == 'test-build' and snapshot['retrievedAt'] == '2026-10-05',
          'new snapshot retains supplied extraction date and actual source build')
    check(len(snapshot['records']) == 1, 'snapshot filter excludes unsupported item before generation')

# Source values are current fields, not the historical chg payload.
leggings = next(r for r in data['records'] if r['item']['id'] == 4242)
check([45, 3] in leggings['item']['st'], 'current crafted spell power preserved')

warrior = '{class="WARRIOR",className="Warrior",level=12,nodes={{11670,"Shield Specialization",3,9000}}}'
L = runtime(warrior)
ns = start_battleplan(L)
L.globals().BP = ns
check(ns.state.hasUpgradeData and len(ns.state.upgrades) > 0, 'catalog connected for Warrior without class Gear file')
text = screen(L, ns, 'gear', tips=True)
check('Crafting:' in text and 'Blacksmithing' in text and 'Source not confirmed' in text,
      'real source and provisional warning visible')
check('unconfirmed' in text and 'Score from item stats' in text, 'potential label and scoring scope visible')
check(all(ns.state.upgrades[i].status == 'unknown' for i in range(1, len(ns.state.upgrades) + 1)),
      'catalog presence never proves source access/usability')
check(all(ns.state.upgrades[i].slot not in (11, 12, 13, 14, 16, 17, 18)
          for i in range(1, len(ns.state.upgrades) + 1)), 'unmodeled duplicate slots and weapons absent')
ns.UI.Show()
L.execute('''
  SELECTED=BP.state.upgrades[1].target.itemID
  SELECTED_SLOT=BP.state.upgrades[1].slot
  C.bags[SELECTED]=1;fire("BAG_UPDATE_DELAYED")
''')
drain(L, ns)
selected = L.globals().SELECTED
check(all(ns.state.upgrades[i].target.itemID != selected for i in range(1, len(ns.state.upgrades) + 1)),
      'bag acquisition refreshes visible recommendations and excludes owned item')
L.execute('''
  C.bags[SELECTED]=0
  C.inv[SELECTED_SLOT]="item:"..SELECTED..":0"
  C.itemStats[C.inv[SELECTED_SLOT]]={ITEM_MOD_STAMINA_SHORT=0}
  fire("PLAYER_EQUIPMENT_CHANGED")
''')
drain(L, ns)
check(all(ns.state.upgrades[i].target.itemID != selected for i in range(1, len(ns.state.upgrades) + 1)),
      'same equipped ID suppressed even when imported/live stats differ')
# Unknown equipment blocks that slot, without hiding other empty-slot suggestions.
L.execute('C_Item.GetItemStats=nil;fire("PLAYER_EQUIPMENT_CHANGED")')
drain(L, ns)
check(all(ns.state.upgrades[i].slot != L.globals().SELECTED_SLOT for i in range(1, len(ns.state.upgrades) + 1)),
      'unknown equipped comparison is not scored as empty')
L.execute('''
  BEFORE=BP.state.version;IN_COMBAT=true;C.bags[2865]=1;fire("BAG_UPDATE_DELAYED")
''')
check(ns.state.version == L.globals().BEFORE, 'bag source work dormant in combat')
L.execute('IN_COMBAT=false;fire("PLAYER_REGEN_ENABLED")')
drain(L, ns)
check(ns.state.version > L.globals().BEFORE, 'deferred catalog refresh completes after combat')
for character, cls, prof in ((ROGUE_30, 'ROGUE', 'Leatherworking'), (PRIEST_40, 'PRIEST', 'Tailoring')):
    other = runtime(character)
    addon = start_battleplan(other)
    check(addon.state.hasUpgradeData and len(addon.state.upgrades) > 0, cls + ' catalog connected')
    check(prof in screen(other, addon, 'gear'), cls + ' relevant crafter source shown')
print(f'gear catalog test passed: {checks} checks')
