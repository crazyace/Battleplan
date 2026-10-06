#!/usr/bin/env python3
"""Complete snapshot integrity, lazy decoding and optional source-state reads."""
import hashlib
import json
import subprocess
import sys
import zipfile
from pathlib import Path
from wowmock import runtime, start_battleplan, drain, screen, WARRIOR_20

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
import import_full_data as importer

checks = 0

def check(condition, label):
    global checks
    checks += 1
    assert condition, label

manifest = json.loads(importer.MANIFEST.read_text())
check(hashlib.sha256(importer.ARCHIVE.read_bytes()).hexdigest() == manifest['archiveSha256'], 'archive checksum')
with zipfile.ZipFile(importer.ARCHIVE) as archive:
    check(sorted(archive.namelist()) == sorted(f['path'] for f in manifest['files']), 'every member recorded')
    for entry in manifest['files']:
        raw = archive.read(entry['path'])
        check(len(raw) == entry['bytes'] and hashlib.sha256(raw).hexdigest() == entry['sha256'], entry['path'])
    records, report = importer.build(archive)
    quests = importer.read(archive, 'quests')
    check(len(quests['quests']) == 293, 'full collected quest table retained')
    check(quests['source']['license'] == 'GPL-3.0', 'original quest licensing retained')
    check(any('talents' in n for n in archive.namelist()), 'older talent inputs retained separately')
    check(not any(n.endswith(('.js', '.html')) for n in archive.namelist()), 'no frontend code bundled')
check(report['itemsPreserved'] == 22069 and report['rankableItems'] == 1635, 'complete item accounting')
check(sum(report['excludedFromRanking'].values()) + len(records) == 22069, 'no lost exclusions')
check(set(report['sourceKinds']) == {'quest', 'craft', 'drop', 'vendor'}, 'four source types imported')
check(importer.render(records) == importer.OUTPUT.read_text(), 'deterministic catalog regeneration')
check(report == json.loads((importer.MANIFEST.parent / 'catalog-report.json').read_text()), 'report matches archive')
example = {'c':4, 'inv':5, 'sc':1, 'src':'f', 'n':'Golden Robe', 'rl':10, 'ar':10, 'ic':123, 'st':[[7,2]]}
check(importer.exclusion(example) is None, 'Gold is not OLD test data')
for change in ({'cls':1}, {'set':1}, {'rep':[1,2]}, {'sp':[[1,2]]}, {'st':[[999,1]]}):
    check(importer.exclusion(dict(example, **change)) is not None, 'unsupported facts excluded: '+str(change))
check(importer.exclusion(dict(example, new=True)) is None, 'new flag does not invent a test restriction')

L = runtime(WARRIOR_20)
ns = start_battleplan(L)
L.globals().BP = ns
check(len(ns.state.upgrades) > 0 and ns.state.hasUpgradeData, 'full catalog connected')
check(ns.Data.FullGearCatalog.cache.ROGUE is None, 'other classes not decoded')
check(all(chunk.loaded is None for _, chunk in ns.Data.FullGearCatalog.ROGUE.items()), 'other class chunks deferred')
loaded = ns.Engine.Gear.CatalogTargets(ns.Data.FullGearCatalog, 'WARRIOR', 20, None)
expected = sorted((r for r in records if 'WARRIOR' in r['classes']), key=lambda r:(r['minLevel'],r['itemID']))
check(len(loaded) > 133, 'larger catalog actually used')
for i in range(1, len(loaded)+1):
    target, original = loaded[i], expected[i-1]
    check(target.itemID == original['itemID'] and target.name == original['name'], 'decoded item identity')
    check(dict(target.stats.items()) == original['stats'], 'decoded static stats')
    routes = L.eval('function(g,t) local out={} for _,r in g.Routes(t) do out[#out+1]=r end return out end')(ns.Engine.Gear,target)
    for j, raw in enumerate(original['routes'], 1):
        decoded = dict(routes[j].items()); decoded.pop('_status')
        if 'prerequisites' in decoded: decoded['prerequisites'] = list(decoded['prerequisites'].values())
        check(decoded == raw, 'decoded source fields')
L.execute('''
  C.faction="Alliance"; assert(BP.API.PlayerFaction()=="Alliance")
  C.faction="Invalid"; assert(BP.API.PlayerFaction()==nil)
  C.completedQuests={[6]=true}; BP.API.ForgetQuestStates()
  assert(BP.API.QuestCompleted(6)==true and BP.API.QuestCompleted(7)==false)
  C.completedQuests[6]=false; assert(BP.API.QuestCompleted(6)==true)
  BP.API.ForgetQuestStates(); assert(BP.API.QuestCompleted(6)==false)
  C_QuestLog.IsQuestFlaggedCompleted=function() error("unavailable") end
  BP.API.ForgetQuestStates(); assert(BP.API.QuestCompleted(6)==nil)
  C_QuestLog.IsQuestFlaggedCompleted=nil; assert(BP.API.QuestCompleted(7)==nil)
  C_QuestLog.IsQuestFlaggedCompleted=function() return 123 end
  assert(BP.API.QuestCompleted(7)==nil)
  SAVED_SECRET=issecretvalue; issecretvalue=function(v) return v==123 end
  UnitFactionGroup=function() return 123 end
  assert(BP.API.PlayerFaction()==nil and BP.API.QuestCompleted(7)==nil)
  issecretvalue=SAVED_SECRET; IN_COMBAT=true
  UnitFactionGroup=function() error("read in combat") end
  C_QuestLog.IsQuestFlaggedCompleted=function() error("read in combat") end
  assert(BP.API.PlayerFaction()==nil and BP.API.QuestCompleted(7)==nil)
  BEFORE=BP.state.version;fire("QUEST_LOG_UPDATE");assert(BP.state.version==BEFORE)
  IN_COMBAT=false;fire("PLAYER_REGEN_ENABLED")
''')
drain(L, ns)
check(ns.state.version > L.globals().BEFORE, 'quest refresh deferred until out of combat')
check('Source not confirmed' in screen(L, ns, 'gear'), 'import is never access proof')
L.execute('''
  BP.UI.Show(); C.faction="Horde"; UnitFactionGroup=function() return C.faction end
  C_QuestLog.IsQuestFlaggedCompleted=function() return true end
  fire("QUEST_TURNED_IN")
''')
drain(L, ns)
check(all(u.route.kind != 'quest' for _,u in ns.state.upgrades.items()), 'completed one-time quests suppressed')
check(all(u.route.faction != 'Alliance' for _,u in ns.state.upgrades.items()), 'opposite faction suppressed')
# Both routes on the strongest item must not hide the next distinct alternative.
L.execute('''
  local a={slot=5,itemID=900001,stats={AGILITY=100},routes={
    {key="a1",kind="quest"},{key="a2",kind="craft"}}}
  local b={slot=5,itemID=900002,stats={AGILITY=90},routes={{key="b1",kind="craft"}}}
  local c={slot=5,itemID=900003,stats={AGILITY=80},routes={{key="c1",kind="craft"}}}
  local rows=BP.Engine.Gear.NextUpgrades({c,b,a},30,{AGILITY=1},{},{})
  assert(rows[1].target.itemID==900001 and rows[1].alternative.target.itemID==900002)
''')
check(True, 'bounded selection retains a distinct alternative behind duplicate source leaders')
subprocess.run([sys.executable,str(ROOT / 'tools/import_full_data.py'),'--check'],check=True,stdout=subprocess.DEVNULL)
print(f'full data test passed: {checks} checks')
