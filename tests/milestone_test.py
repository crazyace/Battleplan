#!/usr/bin/env python3
"""Native trait capture and capture-backed Warrior starter guide coverage."""
import hashlib
import json
import sys
from pathlib import Path
from wowmock import runtime, load, start_battleplan, screen, WARRIOR_20

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
import import_spell_catalog as importer
import capture_check

checks = 0


def check(condition, label):
    global checks
    checks += 1
    assert condition, label


def probe(setup=''):
    L = runtime(WARRIOR_20)
    L.execute('''pending = {}; nodeReads = 0
      C_Timer.After = function(_, fn) pending[#pending+1] = fn end
      function tick() local fn=table.remove(pending,1); if fn then fn() end end
      local original = C_Traits.GetNodeInfo
      C_Traits.GetNodeInfo = function(...)
        nodeReads=nodeReads+1
        local info=original(...)
        info.conditionIDs={77}; info.visibleEdges={{targetNode=2,isActive=true}}
        return info
      end
      C_Traits.GetConditionInfo=function(_, id) return {conditionID=id,requiredRanks=5} end
    ''')
    L.execute(setup)
    load(L, 'BattleplanProbe', 'BattleplanProbe.toc')
    return L


def exported(L):
    return json.loads(L.globals().BattleplanProbe.export())


L = probe()
cmd = L.globals().SlashCmdList.BATTLEPLANPROBE
cmd('talents')
check(L.globals().nodeReads == 0, 'command schedules node work')
check(L.globals().BattleplanProbe.export() is None, 'export waits for asynchronous talent capture')
cmd('talents')
check(len(L.globals().pending) == 1, 'duplicate command does not enqueue another capture')
L.globals().tick()
check(L.globals().nodeReads == 4, 'at most four nodes per timer batch')
L.globals().tick()
data = exported(L)['captures']['talents'][0]['data']
check(data['complete'] and len(data['nodes']) == 7, 'whole trait tree exported')
node = data['nodes'][0]
check(node['info']['values'][0]['groupIDs'] == [3001], 'raw spec groups retained')
check(node['info']['values'][0]['visibleEdges'][0]['targetNode'] == 2, 'prerequisite edge retained')
check(node['conditions'][0]['info']['values'][0]['requiredRanks'] == 5, 'gate metadata retained')
entry = node['entries'][0]
check(entry['definition']['values'][0]['spellID'] == 900001, 'definition spell IDs retained')
check(entry['spell']['name'] == 'Deflection', 'talent name resolved from spell ID')
check(data['build']['values'][1] == '70205', 'trait capture records client build')
head, bad, good = capture_check.check_talents({'data': data, 'source': 'test.json', 'who': {'class': 'WARRIOR'}})
check(not bad and good, 'checker recognizes complete talent capture')

for setup, status in [
    ('C_ClassTalents=nil', 'missing'),
    ('C_ClassTalents.GetActiveConfigID=function() error("test") end', 'error'),
    ('C_ClassTalents.GetActiveConfigID=function() return "SECRET" end', 'secret'),
    ('C_ClassTalents.GetActiveConfigID=function() return nil end', 'ok'),
]:
    L = probe(setup)
    L.globals().SlashCmdList.BATTLEPLANPROBE('talents')
    data = exported(L)['captures']['talents'][0]['data']
    check(not data['complete'] and data['activeConfig']['status'] == status, 'config ' + status + ' is recorded')
    check(data['reason'] == 'no-talent-config', 'unreadable config fails closed')

L = probe('C_Traits.GetNodeInfo=function() error("node read failed") end')
L.globals().SlashCmdList.BATTLEPLANPROBE('talents')
for _ in range(3):
    L.globals().tick()
data = exported(L)['captures']['talents'][0]['data']
check(not data['complete'] and data['failures'] == 7, 'failed node reads preserve partial capture')
check(data['nodes'][0]['info']['status'] == 'error', 'node error remains inspectable')

L = probe('C_Traits.GetDefinitionInfo=function() return {spellID="SECRET"} end')
L.globals().SlashCmdList.BATTLEPLANPROBE('talents')
for _ in range(3):
    L.globals().tick()
data = exported(L)['captures']['talents'][0]['data']
check(not data['complete'] and data['failures'] == 7, 'nested secret definitions mark capture incomplete')

L = probe('C_Traits.GetNodeInfo=function() return 4 end')
L.globals().SlashCmdList.BATTLEPLANPROBE('talents')
for _ in range(3):
    L.globals().tick()
check(not exported(L)['captures']['talents'][0]['data']['complete'], 'malformed node shape fails closed')

L = probe('C_Traits.GetConditionInfo=nil')
L.globals().SlashCmdList.BATTLEPLANPROBE('talents')
for _ in range(3):
    L.globals().tick()
data = exported(L)['captures']['talents'][0]['data']
check(not data['complete'] and data['failures'] == 7, 'missing gate API never implies verified prerequisites')

L = probe()
L.execute('IN_COMBAT=true')
L.globals().SlashCmdList.BATTLEPLANPROBE('talents')
check(L.globals().BattleplanProbeDB is None and len(L.globals().pending) == 0, 'combat command does no tree work')
L.execute('IN_COMBAT=false')
L.globals().SlashCmdList.BATTLEPLANPROBE('talents')
L.globals().tick()
L.execute('IN_COMBAT=true')
L.globals().tick()
data = exported(L)['captures']['talents'][0]['data']
check(data['reason'] == 'combat-interrupted' and len(data['nodes']) == 4, 'combat interrupts remaining tree work')
L.execute('IN_COMBAT=false')
L.globals().SlashCmdList.BATTLEPLANPROBE('talents')
for _ in range(3):
    L.globals().tick()
check(exported(L)['captures']['talents'][1]['data']['complete'], 'capture can retry after interruption')
import tempfile
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / 'retry.json'
    path.write_text(json.dumps({'captures': {'talents': exported(L)['captures']['talents']}}))
    _, flagged = capture_check.report([str(path)])
    check(flagged == 0, 'successful retry supersedes older incomplete talent capture')

L = probe()
L.globals().SlashCmdList.BATTLEPLANPROBE('talents')
L.execute('C_ClassTalents.GetActiveConfigID=function() return 2 end')
L.globals().tick()
check(exported(L)['captures']['talents'][0]['data']['reason'] == 'config-changed', 'config changes abort capture')

raw = importer.SOURCE.read_bytes()
source = str(importer.SOURCE.relative_to(ROOT))
check(importer.render(raw, source) == importer.OUTPUT.read_text(), 'generated output matches untouched capture')
records = importer.catalog(json.loads(raw))
check(len(records) == 21 and records[284]['rank'] == 2, 'all captured spell entries imported')
check(records[284]['costs'][0]['cost'] == 15 and records[284]['costs'][0]['type'] == 1, 'captured rage cost retained')
check('costs' not in records[2687], 'missing cost is not replaced by zero')
check('minLevel' not in importer.render(raw, source) and 'cooldownDuration' not in records[100],
      'observed level and ready cooldown never become requirements/base cooldown')
check(hashlib.sha256(raw).hexdigest() in importer.render(raw, source), 'source hash retained')
mutated = json.loads(raw)
mutated['captures']['spells'][-1]['data']['spells'][0]['name'] = '<secret>'
check(importer.catalog(mutated)[6603]['name'] == 'Attack', 'secret later record does not replace readable evidence')

L = runtime(WARRIOR_20)
# Readable book entries from the uploaded live capture, not guessed rank/ID pairs.
book = json.loads(raw)['captures']['spells'][-1]['data']['spells']
L.globals().capturedBook = L.table_from([L.table_from(s) for s in book])
L.execute('''C.level=12; C.book={}
  for _, s in ipairs(capturedBook) do
    local rank=tonumber((s.subName or ""):match("%d+"))
    C.book[#C.book+1]={s.name,rank,s.spellID}
  end''')
ns = start_battleplan(L)
L.globals().BP = ns
rotation = screen(L, ns, 'rotation')
check('Starter guide' in rotation and 'Sunder Armor' in rotation and 'Taunt' in rotation, 'tank starter guide visible')
check('train now' not in rotation and all(r.minLevel is None for r in ns.state.rotation.upcoming.values()), 'guide makes no invented trainer claims')
check(ns.state.rotation.priority[2].spellID == 7386, 'rotation uses exact learned spell ID')
check(ns.state.rotation.priority[2].reference.name == 'Sunder Armor', 'rotation links captured spell evidence')
check(ns.Data.WARRIOR.Spells._status == 'verified' and ns.Data.WARRIOR.Rotations._status == 'provisional',
      'observed facts and advice have separate statuses')
for spec in ('arms', 'fury'):
    ns.db.spec = spec
    ns.Planner.Queue()
    ns.Jobs.Drain(ns.Jobs)
    rotation = screen(L, ns, 'rotation')
    check('Heroic Strike | Rank 2' in rotation and 'Rend | Rank 2' in rotation, spec + ' uses learned ranks')
    check('Charge' in rotation and 'Shield Slam' not in rotation, spec + ' known spells only')
L.execute('C.book={{"Heroic Strike",3,285}}; BP.API.ForgetSpells(); BP.Planner.Queue()')
ns.Jobs.Drain(ns.Jobs)
L.execute('C.book={{"Heroic Strike",3,284}}; BP.API.ForgetSpells(); BP.Planner.Queue()')
ns.Jobs.Drain(ns.Jobs)
check(ns.state.rotation.priority[1].reference is None, 'same ID with mismatched rank cannot attach capture text')
L.execute('C.book={{"Heroic Strike",3,285}}; BP.API.ForgetSpells(); BP.Planner.Queue()')
ns.Jobs.Drain(ns.Jobs)
row = ns.state.rotation.priority[1]
check(row.rank == 3 and row.spellID == 285 and row.reference is None, 'new rank never inherits old-rank capture data')
check('Rend | Rank 2' not in screen(L, ns, 'rotation'), 'unlearned entries leave active priority')
print(f'milestone test passed: {checks} checks')
