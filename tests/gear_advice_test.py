#!/usr/bin/env python3
"""Synthetic route fixtures: selection policy, not verified game data."""
from wowmock import runtime, start_battleplan, screen, ROGUE_30

checks = 0


def check(condition, label):
    global checks
    checks += 1
    assert condition, label


L = runtime(ROGUE_30)
ns = start_battleplan(L)
L.globals().BP = ns
L.execute('''
  W={AGILITY=1};BASE={[5]=100}
  QUEST={slot=5,itemID=900001,name="Test quest chest",minLevel=20,stats={AGILITY=120},routes={
    {key="q1",kind="quest",name="Test quest",questID=99001,location="Test zone",effort=1}}}
  CRAFT={slot=5,itemID=900002,name="Test crafted chest",minLevel=20,stats={AGILITY=125},routes={
    {key="c1",kind="craft",name="Test recipe",profession="Blacksmithing",effort=3}}}
  CTX={class="ROGUE",usable={[900001]=true,[900002]=true},access={q1="available",c1="available"}}
  TARGETS={QUEST,CRAFT}
  function choose() RESULT=BP.Engine.Gear.NextUpgrades(TARGETS,30,W,BASE,CTX);return RESULT end
''')
choose = L.globals().choose
r = choose()[1]
check(r.target.itemID == 900001 and r.alternative.target.itemID == 900002,
      'easy quest retains 80% of gain; stronger craft kept as alternative')
check(r.selectedForEase, 'easier primary has an explanation flag')
L.execute('CRAFT.routes[1].effort=nil')
check(choose()[1].target.itemID == 900002, 'unknown effort is not treated as expensive')
L.execute('CRAFT.routes[1].effort=3;CRAFT.stats.AGILITY=140')
r = choose()[1]
check(r.target.itemID == 900002 and r.alternative.target.itemID == 900001,
      'substantially stronger craft wins; accessible quest stays visible')
check(r.status == 'available', 'craft does not require the wearer to have Blacksmithing')
L.execute('CTX.access.c1="unknown"')
check(choose()[1].target.itemID == 900001, 'known access wins over unconfirmed craft availability')
L.execute('CTX.completedQuests={[99001]=true}')
r = choose()[1]
check(r.target.itemID == 900002 and r.status == 'unknown', 'completed one-time quest excluded')
L.execute('CTX.access.c1="blocked"')
check(len(choose()) == 0, 'all blocked/completed routes produce no recommendation')
L.execute('CTX.completedQuests={};CTX.access.c1="available";CTX.owned={[900002]=true}')
check(choose()[1].target.itemID == 900001, 'already-owned item excluded')
L.execute('CTX.owned={};CTX.usable[900002]=false')
check(choose()[1].target.itemID == 900001, 'unusable armor/weapon excluded')
L.execute('CTX.usable[900002]=true;CRAFT.classes={WARRIOR=true}')
check(choose()[1].target.itemID == 900001, 'class restriction excludes candidate')
L.execute('CRAFT.classes=nil;CRAFT.routes[1].wearerProfession="Blacksmithing";CTX.professions={Blacksmithing=0}')
check(choose()[1].target.itemID == 900001, 'actual wearer profession requirement enforced')
L.execute('CTX.professions=nil')
check(choose()[1].target.itemID == 900001, 'unknown wearer skill cannot outrank confirmed route')
L.execute('CRAFT.routes[1].wearerProfession=nil;QUEST.routes[1].prerequisites={99999}')
check(choose()[1].target.itemID == 900002, 'unknown prerequisites do not become available automatically')
L.execute('CTX.completedQuests[99999]=true;QUEST.routes[1].faction="Alliance";CTX.faction="Horde"')
check(choose()[1].target.itemID == 900002, 'opposite-faction quest excluded')
L.execute('QUEST.routes[1].faction=nil;CRAFT.minLevel=33')
r = choose()[1]
check(r.target.itemID == 900001 and r.alternative is None, 'usable-now option wins and future gear is not an immediate alternative')
L.execute('CTX.access.q1="blocked"')
r = choose()[1]
check(not r.now and r.requiredLevel == 33, 'future item explicitly labeled with required level')
L.execute('CRAFT.minLevel=36')
check(len(choose()) == 0, 'items over five levels away are excluded')
L.execute('CRAFT.minLevel=30;CRAFT.stats.AGILITY=104')
check(len(choose()) == 0, 'tiny gains filtered to avoid churn')
L.execute('CTX.minGainFraction=0')
check(len(choose()) == 1, 'churn threshold configurable by caller')
L.execute('BASE[5]=false')
check(len(choose()) == 0, 'unknown equipped stats never treated as empty gear')
L.execute('BASE[5]=nil')
check(len(choose()) == 1, 'empty slot supports upgrades without percentage division')
L.execute('''
  BASE[5]=100;CRAFT.stats.AGILITY=140;CTX.access.q1="available";CTX.minGainFraction=nil
  CTX.usable[900002]=nil;CTX.access.c1="available";choose()
''')
check(L.globals().RESULT[1].target.itemID == 900001, 'unknown usability cannot outrank confirmed option')
L.execute('''
  CTX.usable[900002]=true;choose()
  BP.state.upgrades=RESULT;BP.state.hasUpgradeData=true;BP.state.gearUnknown=false
''')
text = screen(L, ns, 'gear')
for phrase in ('Test crafted chest', 'Alternative: Test quest chest', 'Crafting: Test recipe',
               'Find a crafter with Blacksmithing', 'Quest: Test quest', 'Test zone', 'score', 'provisional'):
    check(phrase in text, 'source-aware presentation: ' + phrase)
L.execute('CTX.access.q1="blocked";CTX.access.c1="unknown";choose();BP.state.upgrades=RESULT')
text = screen(L, ns, 'gear')
check('Potential upgrade' in text and 'Check requirements' in text and 'not confirmed' in text, 'unknown route visibly requires checking')
L.execute('''
  CTX.access.c1="available";CRAFT.minLevel=33;choose();BP.state.upgrades=RESULT
''')
check('Level 33' in screen(L, ns, 'gear'), 'future item level rendered')
# Deterministic ties and bounded work yield throughout collection and selection.
L.execute('''
  CRAFT.minLevel=30;CRAFT.stats.AGILITY=120;CTX.access.q1="available";QUEST.routes[1].effort=3
  TARGETS={CRAFT,QUEST};choose();FIRST=RESULT[1].target.itemID
  TARGETS={QUEST,CRAFT};choose();SECOND=RESULT[1].target.itemID
  MANY={};for i=1,320 do MANY[i]=CRAFT end
  TICKS=0;BP.Engine.Gear.NextUpgrades(MANY,30,W,BASE,CTX,function() TICKS=TICKS+1 end)
''')
check(L.globals().FIRST == L.globals().SECOND, 'tie selection stable across catalog ordering')
check(L.globals().TICKS >= 30, 'collection and selection yield in bounded batches')
print(f'gear advice test passed: {checks} checks')
