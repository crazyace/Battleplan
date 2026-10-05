#!/usr/bin/env python3
"""Regression coverage for refresh races, planner recovery and imported talent rules."""
import copy
import importlib.util
import json
from pathlib import Path
from wowmock import runtime, start_battleplan, drain, screen, ROGUE_30

ROOT = Path(__file__).resolve().parent.parent
checks = 0


def check(condition, label):
    global checks
    checks += 1
    assert condition, label


def fresh(char=ROGUE_30):
    lua = runtime(char)
    ns = start_battleplan(lua)
    lua.globals().BP = ns
    return lua, ns


# Inspect actual rendered rows, not just the newer backing state.
L, ns = fresh()
L.globals().SlashCmdList.BATTLEPLAN('')
drain(L, ns)
ns.UI.SelectTab('consumables')
L.execute('C.auras[#C.auras+1]={"Agility",11328};C.weaponMH=true;fire("UNIT_AURA","player")')
check(len(ns.state.missing) == 0, 'buff state updated')
check(L.eval('''function()
  for _, r in ipairs(BP.UI.list.data) do
    if r.text == "Elixir" or r.text == "Weapon" then return false end
  end
  return true
end''')(), 'rendered missing buffs updated without reopening')
version = ns.state.version
L.globals().fire('UNIT_AURA', 'player')
check(ns.state.version == version, 'unchanged buffs do not invalidate UI')

# Bag updates are lightweight and deferred in combat.
L, ns = fresh()
version = ns.state.version
L.execute('C.bags[8949]=0;fire("BAG_UPDATE",0);fire("BAG_UPDATE_DELAYED")')
check(ns.state.counts[8949] == 0, 'counts update when the last consumable is used')
check(ns.state.version == version + 1, 'duplicate bag events do not invalidate unchanged counts')
L.execute('IN_COMBAT=true;C.bags[8949]=4;fire("BAG_UPDATE",0)')
check(ns.state.counts[8949] == 0, 'bags stay dormant in combat')
L.execute('IN_COMBAT=false;fire("PLAYER_REGEN_ENABLED")')
check(ns.state.counts[8949] == 4, 'bag counts refresh after combat')

# A failed coroutine releases its owner; partial computed state is not published.
L, ns = fresh()
L.execute('''
  geterrorhandler=function() return function(e) LAST_ERROR=e end end
  SAVED_COUNT=BP.API.ItemCount
  BP.API.ItemCount=function() error("transient failure") end
  BattleplanDB.spec="subtlety"
  fire("PLAYER_EQUIPMENT_CHANGED")
''')
drain(L, ns)
check(ns.state.spec == 'combat', 'failure retains the completed plan')
check(ns.state.error is not None, 'failure is visible')
check(not ns.Jobs.Busy(ns.Jobs), 'failed job removed')
L.execute('BP.API.ItemCount=SAVED_COUNT;fire("PLAYER_EQUIPMENT_CHANGED")')
drain(L, ns)
check(ns.state.spec == 'subtlety' and ns.state.error is None, 'next refresh recovers and clears error')

# Model real delayed timers: scheduling outside combat is insufficient.
L, ns = fresh()
L.execute('''
  TIMERS={};C_Timer.After=function(_,fn) TIMERS[#TIMERS+1]=fn end
  CALLS=0
  BP.Refresh("race",0.2,function() CALLS=CALLS+1 end)
  IN_COMBAT=true;TIMERS[1]()
''')
check(L.globals().CALLS == 0, 'queued timer rechecks combat')
L.execute('IN_COMBAT=false;fire("PLAYER_REGEN_ENABLED");TIMERS[2]()')
check(L.globals().CALLS == 1, 'deferred timer runs once after combat')
# Newer combat requests win over older pre-combat requests for the same key.
L.execute('''
  BP.Refresh("latest",0.2,function() CALLS=99 end)
  IN_COMBAT=true
  BP.Refresh("latest",0.2,function() CALLS=2 end)
  TIMERS[3]();IN_COMBAT=false;fire("PLAYER_REGEN_ENABLED");TIMERS[4]()
''')
check(L.globals().CALLS == 2, 'latest refresh callback wins')

# Missing/secret item stats stay unknown until the data-ready event.
L, ns = fresh()
L.execute('''
  BP.Data.ROGUE.Gear.targets={{slot=1,itemID=999,name="Weaker hat",minLevel=1,stats={AGILITY=1}}}
  SAVED_STATS=C.itemStats;C.itemStats={};fire("PLAYER_EQUIPMENT_CHANGED")
''')
drain(L, ns)
check(len(ns.state.upgrades) == 0, 'unknown equipped stats never score as zero')
check('Waiting for equipped item stats' in screen(L, ns, 'gear'), 'waiting state shown')
L.execute('C.itemStats=SAVED_STATS;fire("GET_ITEM_INFO_RECEIVED",103,true)')
drain(L, ns)
check(len(ns.state.upgrades) == 0, 'weaker hat stays rejected after its stats load')
L.execute('C.itemStats["item:103:0:0"]={ITEM_MOD_AGILITY_SHORT="SECRET"};fire("PLAYER_EQUIPMENT_CHANGED")')
drain(L, ns)
check(len(ns.state.upgrades) == 0, 'secret stat is unknown, not zero')
L.execute('C_Item.GetItemStats=nil;fire("PLAYER_EQUIPMENT_CHANGED")')
drain(L, ns)
check(len(ns.state.upgrades) == 0, 'missing stats API is unknown, not zero')
# A genuinely empty slot retains zero as its comparison baseline.
L.execute('C.inv[1]=nil;fire("PLAYER_EQUIPMENT_CHANGED")')
drain(L, ns)
check(len(ns.state.upgrades) == 1, 'empty slot can still have an upgrade')

# All spec/situation build orders must be legal, not just fit a mock character.
L, ns = fresh()
for cls in ('ROGUE', 'PRIEST'):
    data = ns.Data[cls]
    for spec in data.Specs.order.values():
        for situation in ('leveling', 'solo', 'dungeon', 'raid'):
            build = ns.Engine.Score.Lookup(data.Talents[spec], situation)
            errors = ns.Engine.Talents.Validate(build, ns.Data.TalentRules[cls])
            check(len(errors) == 0, f'{cls} {spec} {situation}: legal 51-point order')
            check(len(ns.Engine.Talents.Expand(build.order)) == 51, 'exact point count preserved')
# Off-plan spent points can satisfy the total gate while missing a specific prerequisite.
L.execute('''
  CUR={ ["Improved Sinister Strike"]=2,["Lightning Reflexes"]=3,["Precision"]=3,["Deflection"]=2 }
  TEST_PLAN=BP.Engine.Talents.Plan(BP.Data.ROGUE.Talents.combat.leveling,20,CUR,BP.Data.TalentRules.ROGUE)
''')
check(L.eval('TEST_PLAN.next.name') == 'Deflection', 'next point fills the missing prerequisite rank')
# Exercise the guard directly for a talent not represented by the current sequence's next step.
legal, reason = ns.Engine.Talents.CanSpend(ns.Data.TalentRules.ROGUE, 'Riposte', 1, L.globals().CUR, 20)
check(not legal and 'Deflection rank 3' in reason, 'specific prerequisite checked')
legal, reason = ns.Engine.Talents.CanSpend(ns.Data.TalentRules.ROGUE, 'Riposte', 2, L.globals().CUR, 20)
check(not legal and 'maximum' in reason, 'rank cap checked')
L.execute('''
  BAD={order={{"Not a talent",51}}}
  BAD_PLAN=BP.Engine.Talents.Plan(BAD,20,{},BP.Data.TalentRules.ROGUE)
''')
check(L.eval('BAD_PLAN.invalid'), 'invalid imported build is blocked')

# Generated output must match the structural snapshot exactly.
spec = importlib.util.spec_from_file_location('catalog_import', ROOT / 'tools/import_talent_catalog.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
catalog = json.loads((ROOT / 'data/talents/catalog.json').read_text())
check(len(catalog['classes']) == 9, 'all nine classes imported')
check(sum(map(len, catalog['classes'].values())) == 466, 'all talent records imported')
check(module.render(catalog) == (ROOT / 'Battleplan/Data/TalentRules.lua').read_text(), 'generated Lua current')
invalid = copy.deepcopy(catalog)
invalid['_status'] = 'verified'
try:
    module.render(invalid)
except ValueError:
    check(True, 'external imports cannot be labeled verified')
else:
    check(False, 'external imports cannot be labeled verified')

print(f'regression test passed: {checks} checks')
