#!/usr/bin/env python3
"""Performance test: the "no hitching" budgets from docs/BUILD-GUIDE.md.

    python tests/perf_test.py

1. Every slice of the plan job stays under the scheduler budget (2 ms).
2. Building any tab's rows is well under a millisecond.
3. Hot paths allocate nothing: UNIT_AURA with the window closed, events in
   combat, and a window refresh when nothing changed. Allocation is what
   makes the garbage collector hitch later.

The mock client is much faster than the real one, so this measures
Battleplan's own work. Lupa runs plain Lua 5.1, about as fast as WoW's.
"""
import sys
import time
from wowmock import runtime, start_battleplan, drain, ROGUE_30, PRIEST_40

SLICE_BUDGET_MS = 2.0
ROWS_BUDGET_MS = 0.5
ALLOC_BUDGET_KB = 1.0
failures = []


def report(name, value, budget, unit):
    ok = value <= budget
    print(f"{'ok  ' if ok else 'FAIL'} {name}: {value:.3f} {unit} (budget {budget} {unit})")
    if not ok:
        failures.append(name)


def slices(char, label, runs=200):
    L = runtime(char)
    ns = start_battleplan(L)
    L.globals().SlashCmdList.BATTLEPLAN("perf on")
    L.globals().SlashCmdList.BATTLEPLAN("perf reset")
    for _ in range(runs):
        L.globals().fire("PLAYER_EQUIPMENT_CHANGED")
        drain(L, ns)
    worst = L.eval("""function(ns)
      for _, r in ipairs(ns.Perf.Report()) do if r.label == "job:plan" then return r.max, r.avg, r.n end end
    end""")(ns)
    report(f"{label} plan job, worst slice over {runs} plans (avg {worst[1]:.3f} ms, {worst[2]} slices)",
           worst[0], SLICE_BUDGET_MS, "ms")
    return L, ns


def rows(L, ns, label, runs=2000):
    tabs = L.eval("function(ns) local t = {} for _, x in ipairs(ns.UI.TabsFor(ns.state)) do t[#t+1] = x.key end return t end")(ns)
    build = L.eval("function(ns, tab, n) for _ = 1, n do ns.UI.BuildRows(tab, ns.state) end end")
    for i in range(1, len(tabs) + 1):
        tab = tabs[i]
        t = time.perf_counter()
        build(ns, tab, runs)
        ms = (time.perf_counter() - t) * 1000 / runs
        report(f"{label} {tab} rows", ms, ROWS_BUDGET_MS, "ms")


ALLOC = """function(fn, n)
  collectgarbage("collect")
  collectgarbage("stop")
  local before = collectgarbage("count")
  for _ = 1, n do fn() end
  local grew = collectgarbage("count") - before
  collectgarbage("restart")
  return grew
end"""


def allocations(L, ns):
    measure = L.eval(ALLOC)
    n = 10000
    # UNIT_AURA with the window closed: the handler returns at once.
    aura = L.eval("function() fire('UNIT_AURA', 'player') end")
    report(f"UNIT_AURA x{n}, window closed: memory", measure(aura, n), ALLOC_BUDGET_KB, "KB")
    # Real timers are asynchronous. The mock's default immediate timer recursively
    # runs the whole refresh inside the event and measures Lua stack growth instead.
    L.execute("SAVED_TIMER = C_Timer.After; C_Timer.After = function(_, fn) BAG_TIMER = fn end")
    bag = L.eval("function() fire('BAG_UPDATE', 0); fire('BAG_UPDATE_DELAYED') end")
    bag()
    report(f"bag events x{n}, coalesced: memory", measure(bag, n), ALLOC_BUDGET_KB, "KB")
    L.execute("BAG_TIMER(); C_Timer.After = SAVED_TIMER")
    count = L.eval("function() BattleplanNS.Planner.CheckCounts() end")
    L.globals().BattleplanNS = ns
    report(f"bag counts x{n}, unchanged: memory", measure(count, n), ALLOC_BUDGET_KB, "KB")
    # In combat every refresh trigger only marks the plan dirty.
    L.execute("IN_COMBAT = true")
    combat = L.eval("function() fire('PLAYER_EQUIPMENT_CHANGED'); fire('SPELLS_CHANGED'); fire('BAG_UPDATE', 0) end")
    report(f"gear/spell events x{n} in combat: memory", measure(combat, n), ALLOC_BUDGET_KB, "KB")
    L.execute("IN_COMBAT = false")
    L.globals().fire("PLAYER_REGEN_ENABLED")
    drain(L, ns)
    # Window open, nothing changed: Refresh returns without rebuilding rows.
    L.globals().SlashCmdList.BATTLEPLAN("")
    drain(L, ns)
    refresh = L.eval("function() BattleplanNS.UI.Refresh() end")
    L.globals().BattleplanNS = ns
    report(f"window refresh x{n}, nothing changed: memory", measure(refresh, n), ALLOC_BUDGET_KB, "KB")
    # Scrolling rebinds existing rows; no new frames or tables.
    scroll = L.eval("function() BattleplanNS.UI.list:Scroll(1); BattleplanNS.UI.list:Scroll(-1) end")
    report(f"list scroll x{n}: memory", measure(scroll, n), ALLOC_BUDGET_KB, "KB")
    # Synthetic icon values exercise texture rebinding, not actual client icons.
    L.execute("""
      BattleplanNS.state.icons={}
      for name in pairs(BattleplanNS.state.known) do BattleplanNS.state.icons[name]=987001 end
      BattleplanNS.UI.SelectTab("rotation")
      BattleplanNS.UI.list:Scroll(10000); BattleplanNS.UI.list:Scroll(-10000)
    """)
    report(f"list scroll with icons x{n}: memory", measure(scroll, n), ALLOC_BUDGET_KB, "KB")


L, ns = slices(ROGUE_30, "Rogue")
rows(L, ns, "Rogue")
allocations(L, ns)
L, ns = slices(PRIEST_40, "Priest (healing table)")
rows(L, ns, "Priest")

# Large synthetic source catalog: each resume must stay within the scheduler budget.
L.globals().GEAR_NS = ns
L.execute("""
  GEAR_TARGETS={}
  for i=1,3200 do
    GEAR_TARGETS[i]={slot=5,itemID=900000+i,name="Test item",stats={AGILITY=i},routes={
      {key="route"..i,kind="quest",name="Test quest"}}}
  end
  GEAR_JOB=coroutine.create(function()
    GEAR_RESULT=GEAR_NS.Engine.Gear.NextUpgrades(GEAR_TARGETS,30,{AGILITY=1},{[5]=100},{},coroutine.yield)
  end)
""")
resume = L.eval("function() return coroutine.resume(GEAR_JOB),coroutine.status(GEAR_JOB) end")
worst, count = 0.0, 0
while True:
    started = time.perf_counter()
    ok, status = resume()
    worst = max(worst, (time.perf_counter() - started) * 1000)
    count += 1
    if not ok:
        raise AssertionError('source catalog coroutine failed')
    if status == 'dead':
        break
report(f"3200 source candidates, worst of {count} slices", worst, SLICE_BUDGET_MS, "ms")

if failures:
    print(f"\nperf test FAILED: {len(failures)} over budget")
    sys.exit(1)
print("\nperf test passed")
