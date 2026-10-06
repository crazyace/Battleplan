#!/usr/bin/env python3
"""Explain selected static-stat upgrades without claiming confirmed access or DPS gains."""
from wowmock import runtime, start_battleplan, drain, screen, ROGUE_30

checks = 0

def check(condition, label):
    global checks
    checks += 1
    assert condition, label

L = runtime(ROGUE_30)
ns = start_battleplan(L)
L.globals().BP = ns
L.execute('''
  W={AGILITY=2,STRENGTH=.2,HIT_PCT=10}
  OLD={AGILITY=10,STRENGTH=20,STAMINA=5,HIT_PCT=1}
  TARGET={slot=5,itemID=900100,name="Comparison chest",minLevel=20,
    stats={AGILITY=15,STRENGTH=10,STAMINA=5,HIT_PCT=.5,ARMOR=30},
    routes={{key="comparison-q",kind="quest",name="Comparison quest"}}}
  ALT={slot=5,itemID=900101,name="Alternative chest",minLevel=20,
    stats={AGILITY=14,STRENGTH=20,STAMINA=2,HIT_PCT=.5,ARMOR=10},
    routes={{key="comparison-c",kind="craft",name="Comparison recipe"}}}
  TARGETS={TARGET,ALT};CTX={equippedStats={[5]=OLD}}
  BASE={[5]=BP.Engine.Score.Stats(OLD,W)}
  function choose() return BP.Engine.Gear.NextUpgrades(TARGETS,30,W,BASE,CTX) end
''')
rows = L.globals().choose()
r = rows[1]
check(r.target.itemID == 900100, 'comparison does not change selection')
check(abs(r.comparison.baselineScore-34)<1e-8 and abs(r.comparison.targetScore-37)<1e-8, 'scores use equipped baseline')
check(abs(r.comparison.gainFraction-3/34)<1e-8, 'gain fraction uses baseline rather than target score')
changes = {v.stat:(v.before,v.after,v.delta) for _,v in r.comparison.changes.items()}
check(changes == {'AGILITY':(10,15,5),'ARMOR':(0,30,30),'HIT_PCT':(1,.5,-.5),'STRENGTH':(20,10,-10)},
      'positive, negative and absent stats compared; unchanged omitted')
check(not r.comparison.empty and r.status == 'unknown', 'comparison never upgrades source access')
check(r.alternative.target.itemID == 900101 and r.alternative.comparison.baselineScore == 34,
      'alternative compared with equipped item, not primary recommendation')
check(list(changes) == sorted(changes), 'stat order deterministic')
L.execute('BP.state.upgrades=choose();BP.state.hasUpgradeData=true')
text = screen(L,ns,'gear',tips=True)
check('+3.0 score (8.8%) in Chest' in text, 'unknown-access item still shows estimate')
check('Gains: +5 Agility, +30 Armor' in text and 'Losses: -0.50% Hit, -10 Strength' in text, 'tradeoffs visible')
check('unconfirmed' in text and 'Source not confirmed' in text, 'availability warnings retained')
check('not a damage or healing percentage' in text, 'percent scope explicit')
check('choice: Alternative chest' in text, 'alternative remains visible')

L.execute('TARGETS={TARGET};BASE={};CTX={equippedStats={}}')
r = L.globals().choose()[1]
check(r.comparison.empty and r.comparison.gainFraction is None, 'empty slots have no percentage against zero')
L.execute('BP.state.upgrades=choose()')
check('Your Chest slot is empty.' in screen(L,ns,'gear',tips=True), 'empty slot explained')
L.execute('CTX={equippedStats={[5]={ARMOR=10}}};BASE={[5]=0}')
r = L.globals().choose()[1]
check(not r.comparison.empty and r.comparison.gainFraction is None, 'zero weighted equipped score is not empty')
L.execute('CTX={};BASE={[5]=34}')
r = L.globals().choose()[1]
check(r.comparison.changes is None and r.comparison.empty is None, 'score-only legacy callers do not invent stat details')
L.execute('TARGET.minLevel=33;CTX={equippedStats={[5]=OLD}}')
r = L.globals().choose()[1]
check(not r.now and r.requiredLevel==33 and len(r.comparison.changes)==4, 'future gear also has comparison')
L.execute('BP.state.upgrades=choose()')
check('level 33' in screen(L,ns,'gear') and 'Usable at level 33.' in screen(L,ns,'gear',tips=True), 'future label kept')
L.execute('TARGET.minLevel=20;BASE={[5]=false};CTX={equippedStats={[5]=false}}')
check(len(L.globals().choose())==0, 'unknown equipment cannot generate a comparison')

L.execute('''
  W={AGILITY=1,STRENGTH=1,STAMINA=1,INTELLECT=1,SPIRIT=1}
  OLD={ALL_STATS=1,AGILITY=1,STAMINA=1}
  TARGET.stats={ALL_STATS=2,AGILITY=3};CTX={equippedStats={[5]=OLD}}
  BASE={[5]=BP.Engine.Score.Stats(OLD,W)}
''')
r = L.globals().choose()[1]
changes = {v.stat:v.delta for _,v in r.comparison.changes.items()}
check(changes == {'AGILITY':3,'STRENGTH':1,'INTELLECT':1,'SPIRIT':1}, 'All stats expanded once; zero delta omitted')
check('STAMINA' not in changes, 'unchanged expanded stat omitted')
check(L.globals().OLD.ALL_STATS == 1 and L.globals().TARGET.stats.ALL_STATS == 2, 'input stats not mutated')

# Planner supplies the actual normalized equipped tokens, with no additional game API.
L.execute('''
  BP.Data.ROGUE.Gear.targets={TARGET};TARGET.stats={AGILITY=20,ARMOR=30};TARGET.minLevel=20
  C.inv[5]="item:42:0";C.itemStats[C.inv[5]]={ITEM_MOD_AGILITY_SHORT=10,RESISTANCE0_NAME=40}
  fire("PLAYER_EQUIPMENT_CHANGED")
''')
drain(L,ns)
r=ns.state.upgrades[1]
changes={v.stat:v.delta for _,v in r.comparison.changes.items()}
check(changes=={'AGILITY':10,'ARMOR':-10}, 'live token baseline passed through planner')
check('Losses: -10 Armor' in screen(L,ns,'gear',tips=True), 'live comparison shown')
L.execute('C.inv[5]="SECRET";fire("PLAYER_EQUIPMENT_CHANGED")')
drain(L,ns)
check(len(ns.state.upgrades)==0 and ns.state.gearUnknown, 'secret equipped link blocks that slot')
check('slot is empty.' not in screen(L,ns,'gear',tips=True), 'secret equipment not presented as empty')
L.execute('C.inv[5]=123;fire("PLAYER_EQUIPMENT_CHANGED")')
drain(L,ns)
check(len(ns.state.upgrades)==0 and ns.state.gearUnknown, 'malformed equipped link remains unknown')
L.execute('C.inv[5]=nil;fire("PLAYER_EQUIPMENT_CHANGED")')
drain(L,ns)
check(ns.state.upgrades[1].comparison.empty, 'confirmed empty slot compared from zero')
print(f'gear comparison test passed: {checks} checks')
