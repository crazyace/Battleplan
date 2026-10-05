#!/usr/bin/env python3
"""Replay native Warrior groups and exercise rank-specific tooltip capture."""
import json
import sys
from pathlib import Path
from wowmock import runtime, load, start_battleplan, screen, WARRIOR_20

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
import capture_check

checks = 0


def check(value, why):
    global checks
    checks += 1
    assert value, why


def probe(setup=''):
    L = runtime(WARRIOR_20)
    L.execute('''pending={}; tooltipCalls=0; requests=0; nodeCalls=0
      C_Timer.After=function(_, fn) pending[#pending+1]=fn end
      function tick() local fn=table.remove(pending,1); if fn then fn() end end
      local old=C_Traits.GetNodeInfo
      C_Traits.GetNodeInfo=function(...)
        nodeCalls=nodeCalls+1; return old(...)
      end
      C_Spell.RequestLoadSpellData=function() requests=requests+1 end
      C_TooltipInfo.GetTraitEntry=function(id,rank)
        tooltipCalls=tooltipCalls+1
        return {lines={{leftText="Talent " .. id, rightText="Rank " .. rank},
                       {leftText="Synthetic effect for rank " .. rank}}}
      end
    ''')
    L.execute(setup)
    load(L, 'BattleplanProbe', 'BattleplanProbe.toc')
    L.globals().SlashCmdList.BATTLEPLANPROBE('talents')
    return L


def drain(L):
    for _ in range(100):
        if len(L.globals().pending) == 0:
            return
        nodes, tooltips = L.globals().nodeCalls, L.globals().tooltipCalls
        L.globals().tick()
        n, t = L.globals().nodeCalls - nodes, L.globals().tooltipCalls - tooltips
        check(n <= 4 and t <= 4 and not (n and t), 'node and rank phases have separate four-read budgets')
    raise AssertionError('probe did not finish')


def captured(L):
    return json.loads(L.globals().BattleplanProbe.export())['captures']['talents'][-1]['data']


L = probe()
drain(L)
data = captured(L)
check(data['complete'] and data['tooltipReadsComplete'], 'metadata and rank text separately complete')
check(data['tooltipReads'] == data['tooltipExpected'] == 35 and data['tooltipFailures'] == 0,
      'each synthetic entry requests all five ranks')
check(L.globals().requests == 7, 'request spell data once per valid definition')
for node in data['nodes']:
    tooltips = node['entries'][0]['tooltips']
    check([t['rank'] for t in tooltips] == [1, 2, 3, 4, 5], 'explicit ordered ranks retained')
    check(tooltips[0]['lines'][1]['leftText'] != tooltips[-1]['lines'][1]['leftText'], 'rank effects stay separate')
    check(tooltips[1]['lines'][0]['rightText'] == 'Rank 2', 'right-hand tooltip text retained')

for setup, expected in [
    ('C_TooltipInfo.GetTraitEntry=nil', 'missing'),
    ('C_TooltipInfo.GetTraitEntry=function() error("tooltip failed") end', 'error'),
    ('C_TooltipInfo.GetTraitEntry=function() return nil end', 'empty'),
    ('C_TooltipInfo.GetTraitEntry=function() return {lines={}} end', 'empty'),
    ('C_TooltipInfo.GetTraitEntry=function() return {lines={{leftText="SECRET"}}} end', 'secret'),
    ('C_TooltipInfo.GetTraitEntry=function() return "SECRET" end', 'secret'),
]:
    L = probe(setup)
    drain(L)
    data = captured(L)
    check(data['complete'] and not data['tooltipReadsComplete'], 'tooltip failure preserves structural tree: ' + expected)
    check(data['tooltipFailures'] == 35, 'unreadable rank text is counted: ' + expected)
    check(data['nodes'][0]['entries'][0]['tooltips'][0]['status'] == expected, 'rank status retained: ' + expected)
    _, bad, good = capture_check.check_talents({'data': data, 'source': 'test', 'who': {'class': 'WARRIOR'}})
    check(bad and good, 'checker reports effect gap while retaining usable structure')

L = probe('C_Spell.RequestLoadSpellData=nil')
drain(L)
check(captured(L)['tooltipReadsComplete'], 'loading API is optional when tooltip text is ready')

L = probe()
# Reach the rank phase, then enter combat: no tooltip API calls happen during combat.
while L.globals().nodeCalls < 7:
    L.globals().tick()
check(L.globals().tooltipCalls == 0, 'phase transition schedules work instead of mixing batches')
L.globals().tick()
check(L.globals().tooltipCalls == 4, 'first rank batch is four calls')
L.execute('IN_COMBAT=true')
L.globals().tick()
data = captured(L)
check(data['reason'] == 'combat-interrupted' and data['tooltipReads'] == 4, 'combat stops rank work')
check(not data['tooltipReadsComplete'] and L.globals().tooltipCalls == 4, 'partial rank reads never count as complete')

# Replay the real capture to test spec detection against overlapping gate groups and real ranks.
raw = json.loads((ROOT / 'data/probe/2026-10-05-warrior-12-talents.json').read_text())
fixture = raw['captures']['talents'][-1]['data']
L = runtime(WARRIOR_20)
L.globals().fixture = L.table_from(fixture, recursive=True)
L.execute('''C.level=12
  nodesByID={}; entriesByID={}; definitionsByID={}; namesBySpell={}
  for _, node in ipairs(fixture.nodes) do
    nodesByID[node.nodeID]=node.info.values[1]
    for _, entry in ipairs(node.entries) do
      entriesByID[entry.entryID]=entry.info.values[1]
      definitionsByID[entry.info.values[1].definitionID]=entry.definition.values[1]
      namesBySpell[entry.spell.spellID]=entry.spell.name
    end
  end
  C_ClassTalents.GetActiveConfigID=function() return fixture.configID end
  C_Traits.GetConfigInfo=function() return fixture.config.values[1] end
  C_Traits.GetTreeNodes=function() return fixture.trees[1].info.values[1] end
  C_Traits.GetNodeInfo=function(_, id) return nodesByID[id] end
  C_Traits.GetEntryInfo=function(_, id) return entriesByID[id] end
  C_Traits.GetDefinitionInfo=function(id) return definitionsByID[id] end
  C_Spell.GetSpellName=function(id) return namesBySpell[id] end
''')
ns = start_battleplan(L)
check(ns.state.spec == 'protection' and ns.state.specHow == 'talents', 'live allocation selects Protection')
check([ns.state.talents.tabs[i].points for i in range(1, 4)] == [0, 0, 3], 'overlapping groups do not double-count points')
check(ns.state.talents.tabs[3].talents['Shield Specialization'] == 3, 'live allocated rank retained')
check([len(list(ns.state.talents.tabs[i].talents.keys())) for i in range(1, 4)] == [17, 17, 18], 'all captured names mapped')
check('Protection' in screen(L, ns, 'tanking'), 'live role guide renders')
check(ns.Data.WARRIOR.Specs._status == 'verified', 'spec map carries capture-backed status')

rules = json.loads((ROOT / 'data/talents/catalog.json').read_text())['classes']['WARRIOR']
edges = {}
for node in fixture['nodes']:
    info = node['info']['values'][0]
    name = node['entries'][0]['spell']['name']
    rule = rules[name]
    check(rule['id'] == node['nodeID'] and rule['maxRank'] == info['maxRanks'], 'captured IDs/max ranks match catalog')
    for edge in info.get('visibleEdges', []):
        edges.setdefault(edge['targetNode'], []).append(node['nodeID'])
    points = 3 if rule['tree'] == 'Protection' else 0
    for condition in node.get('conditions', []):
        check(condition['info']['values'][0]['spentAmountRequired'] + points == rule['gate'][0],
              'remaining-point text is not an absolute gate')
for node in fixture['nodes']:
    rule = rules[node['entries'][0]['spell']['name']]
    check(sorted(edges.get(node['nodeID'], [])) == sorted(r[0] for r in rule['requires']), 'prerequisite nodes match capture')
print(f'trait capture test passed: {checks} checks')
