#!/usr/bin/env python3
"""Smoke test: run Battleplan and BattleplanProbe against the mock client.

    pip install "lupa>=2.0"
    python tests/smoke_test.py

Checks load order, spec detection, talent plans, rotations, consumables,
healer and tank guides, combat dormancy, the window, and the probe's stat
lab and export. Not real game data: see docs/BETA-FINDINGS.md for that.
"""
import json
import sys
from wowmock import (runtime, start_battleplan, load, drain, printed, screen, set_char,
                     ROGUE_30, PRIEST_40, WARRIOR_20, MAGE_20)

checks = 0


def check(cond, msg):
    global checks
    checks += 1
    if not cond:
        print("FAIL:", msg)
        sys.exit(1)


def has(text, *wants):
    for w in wants:
        check(w in text, f"expected {w!r} in:\n{text}")


# Rogue --------------------------------------------------------------------------------
L = runtime(ROGUE_30)
ns = start_battleplan(L)
s = ns.state
check(s.ready and s.supported, "plan ready")
check(s.spec == "combat" and s.specHow == "talents", f"spec {s.spec} {s.specHow}")
check(s.situation == "leveling", "auto situation below 60 is leveling")
check(s.role == "dps", "rogue role")
# CHARACTER_POINTS_CHANGED doesn't exist on the mock client: skipped, not an error.
check(not L.eval("function(ns) return ns.Events:On('CHARACTER_POINTS_CHANGED', function() end) end")(ns),
      "unknown event skipped")
# One handler's error doesn't stop the others on the same event.
L.execute("SECOND = false")
L.eval("function(ns) ns.Events:On('BAG_UPDATE', function() error('boom') end); ns.Events:On('BAG_UPDATE', function() SECOND = true end) end")(ns)
L.execute("geterrorhandler = function() return function() end end")
L.globals().fire("BAG_UPDATE")
check(L.globals().SECOND, "handler after a failing one still runs")

talents = screen(L, ns, "talents")
print("---- Rogue: Talents ----\n" + talents)
has(talents, "Combat", "Leveling  |  level 30", "Provisional", "Combat Swords/Axes",
    "Points spent | 21 of 21", "Next point | Blade Flurry (needs a respec)",
    "Different from the plan", "Blade Flurry | 0 / 1", "Malice | 1 (plan: 0)", "Why this point", "Target rank | 1")

rotation = screen(L, ns, "rotation")
print("---- Rogue: Rotation ----\n" + rotation)
has(rotation, "Opener", "1. Cheap Shot", "2. Sinister Strike | Rank 5", "Priority", "1. Slice and Dice",
    "2. Riposte", "3. Eviscerate | Rank 4", "4. Sinister Strike | Rank 5", "Kick", "Evasion",
    "Coming up", "Adrenaline Rush | talent", "Blade Flurry | talent")
check("Mutilate" not in rotation, "assassination spells stay out of a Combat rotation")

# Learning Blade Flurry: rotation updates and says where it goes.
L.execute('C.book[#C.book + 1] = { "Blade Flurry", nil, 13877 }')
L.globals().fire("SPELLS_CHANGED")
drain(L, ns)
has(screen(L, ns, "rotation"), "2. Blade Flurry", "3. Riposte")
check(any("Blade Flurry" in p and "#2 in your Combat rotation" in p for p in printed(L)), "announces new spell")

gear = screen(L, ns, "gear", tips=True)
print("---- Rogue: Gear ----\n" + gear)
has(gear, "Chest: Living Stats (+4 All stats) | |cff9d9d9denchanted|r",
    "Wrist: Superior Agility (+9 Agility) | |cffff4040missing|r", "Main hand: Agility (+15 Agility)",
    "unconfirmed", "Source not confirmed", "Crafted with Leatherworking",
    "Battleplan: +", "Gains:", "Score from item stats only")

cons = screen(L, ns, "consumables")
print("---- Rogue: Consumables ----\n" + cons)
has(cons, "Best for leveling at level 30", "Elixir: Elixir of Agility (+15 Agility) | 3 in bags",
    "Weapon: Solid Sharpening Stone (+6 Weapon damage)", "Food: Lean Wolf Steak (+5 Agility)",
    "Healing potion: Greater Healing Potion", "Missing right now", "Elixir | ", "Weapon | ")
check("Mana potion" not in cons, "no mana potions for a Rogue")
check("Food | " not in cons, "Well Fed is up, so food isn't missing")

# Combat: the addon stays dormant, then refreshes once after.
version = s.version
L.execute("IN_COMBAT = true")
L.globals().fire("PLAYER_EQUIPMENT_CHANGED")
L.globals().fire("SPELLS_CHANGED")
drain(L, ns)
check(s.version == version, "nothing recomputed in combat")
check(not L.eval("function(ns) return ns.Jobs:Busy() end")(ns), "no job queued in combat")
L.execute("IN_COMBAT = false")
L.globals().fire("PLAYER_REGEN_ENABLED")
drain(L, ns)
check(s.version == version + 1, f"exactly one refresh after combat ({s.version - version})")

# Situation and spec overrides.
L.globals().SlashCmdList.BATTLEPLAN("situation dungeon")
drain(L, ns)
rotation = screen(L, ns, "rotation")
has(rotation, "Dungeon  |  level 30", "Feint")
L.globals().SlashCmdList.BATTLEPLAN("spec subtlety")
drain(L, ns)
has(screen(L, ns, "talents"), "Subtlety|r (set by you)", "Hemorrhage / Ambush")
L.globals().SlashCmdList.BATTLEPLAN("spec auto")
L.globals().SlashCmdList.BATTLEPLAN("situation auto")
drain(L, ns)
check(s.spec == "combat", "back to auto spec")

# Window: built on first open, rows bound, tabs for the role, closes with a fade.
check(L.eval("function(ns) return ns.UI.frame == nil end")(ns), "window not built at login")
L.globals().SlashCmdList.BATTLEPLAN("")
drain(L, ns)
check(L.eval("function(ns) return ns.UI.IsShown() end")(ns), "window shown")
tabs = L.eval("function(ns) local t = {} for _, x in ipairs(ns.UI.TabsFor(ns.state)) do t[#t+1] = x.key end return table.concat(t, ',') end")(ns)
check(tabs == "talents,rotation,gear,consumables", f"rogue tabs: {tabs}")
first = L.eval("function(ns) return ns.UI.controls.context.text end")(ns)
check(first and "Combat" in first, f"persistent context bound: {first}")
rows_made = L.eval("function(ns) return #ns.UI.list.rows end")(ns)
L.eval("function(ns) ns.UI.SelectTab('rotation') end")(ns)
check(L.eval("function(ns) return #ns.UI.list.rows end")(ns) == rows_made, "tab switch reuses rows")
check(L.eval("function(ns) return ns.UI.CurrentTab() end")(ns) == "rotation", "tab switched")
L.globals().SlashCmdList.BATTLEPLAN("")
check(L.eval("function(ns) return ns.UI.frame.fadeOut.playing end")(ns), "closes with a fade")

# Commands that print.
L.globals().SlashCmdList.BATTLEPLAN("buffs")
check(any("missing elixir: Elixir of Agility" in p for p in printed(L)), "buffs command")
L.globals().SlashCmdList.BATTLEPLAN("perf on")
L.globals().fire("PLAYER_EQUIPMENT_CHANGED")
drain(L, ns)
L.globals().SlashCmdList.BATTLEPLAN("perf")
check(any("job:plan" in p for p in printed(L)), "perf report lists the plan job")

# Zone-in reminder in a dungeon.
L.execute('C.instance = "party"')
L.globals().fire("PLAYER_ENTERING_WORLD")
check(any("before the pull: no Elixir (Elixir of Agility), Weapon (Solid Sharpening Stone)" in p
          for p in printed(L)), "dungeon reminder")

# Priest (healer) -----------------------------------------------------------------------
L = runtime(PRIEST_40)
ns = start_battleplan(L)
s = ns.state
check(s.spec == "holy" and s.role == "healer", f"priest {s.spec} {s.role}")
tabs = L.eval("function(ns) local t = {} for _, x in ipairs(ns.UI.TabsFor(ns.state)) do t[#t+1] = x.key end return table.concat(t, ',') end")(ns)
check(tabs == "talents,rotation,gear,consumables,healing", f"healer tabs: {tabs}")
has(screen(L, ns, "talents"), "Points spent | 31 of 31", "Next point | Spirit of Redemption at level 41")
check("Different from the plan" not in screen(L, ns, "talents"), "duplicate Holy Specialization node read once")

healing = screen(L, ns, "healing")
print("---- Priest: Healing ----\n" + healing)
# Renew rank 2 heals 100 for 65 mana (1.54/mana) vs rank 6 at 2.0/mana: efficient = rank 6.
has(healing, "Light top-up: Renew (Rank 6) | 2.0 per mana",
    "Steady tank damage: Greater Heal | 2.6 per mana",
    "Sudden spike: Power Word: Shield (Rank 6)",
    "Party-wide damage: Prayer of Healing (Rank 2) | 3.8 per mana", "Prayer of Healing (Rank 2) x5",
    "Renew (Rank 6) | 2.0/mana  over 15 s  205 mana",
    "Heals by mana efficiency", "Mana plan", "Cooldowns", "Inner Focus", "Fade")
check(healing.index("Lesser Heal (Rank 3)") < healing.index("Flash Heal (Rank 3)"),
      "table sorted by healing per mana")

cons = screen(L, ns, "consumables")
print("---- Priest: Consumables ----\n" + cons)
# Names, amounts and levels from the beta capture (data/probe/2026-10-05-warrior-12.json).
has(cons, "Elixir: Mageblood Elixir (+12 Mana per 5 s)", "Weapon: Lesser Mana Oil (+10 Mana per 5 s)",
    "Food: Runn Tum Tuber Surprise (+15 Intellect)", "Mana potion: Greater Mana Potion")
check("Elixir | " not in cons, "Mageblood is up: elixir not missing")
has(screen(L, ns, "rotation"), "Shadow Word: Pain", "Mind Blast", "Smite")

# Warrior (tank: confirmed spec groups) ---------------------------------------
L = runtime(WARRIOR_20)
ns = start_battleplan(L)
s = ns.state
check(s.spec == "protection" and s.role == "tank", f"warrior {s.spec} {s.role}")
has(screen(L, ns, "talents"), "Protection: shield leveling", "Provisional", "Improved Revenge (needs a respec)")
tank = screen(L, ns, "tanking")
print("---- Warrior: Tanking ----\n" + tank)
has(tank, "One target", "1. Revenge", "2. Sunder Armor", "3. Heroic Strike | Rank 3", "A pack", "Thunder Clap",
    "Shield Block", "Pull plan", "Mark a kill target", "Before you pull", "Coming up", "Shield Slam | talent",
    "Demoralizing Shout | |cff40ff40train now|r", "Shield Wall | level 28")
has(screen(L, ns, "rotation"), "Starter guide", "Sunder Armor", "Heroic Strike | Rank 3", "Taunt")

# Unsupported class ---------------------------------------------------------------------------
L = runtime(MAGE_20)
ns = start_battleplan(L)
has(screen(L, ns, "talents"), "no data for your class yet")

# Probe -------------------------------------------------------------------------------------------
L = runtime(ROGUE_30)
load(L, "BattleplanProbe", "BattleplanProbe.toc")
L.globals().fire("ADDON_LOADED", "BattleplanProbe")
cmd = L.globals().SlashCmdList.BATTLEPLANPROBE
cmd("stats")
L.execute("C.stats.agi = 76; C.stats.ap = 127; C.stats.crit = 15.0")
cmd("stats +10 agility")
out = "\n".join(printed(L))
print("---- Probe ----\n" + out)
has(out, "stat lab #1", "stat lab #2 [+10 agility]", "agility: 66 -> 76 (+10)", "crit_melee: 13.69 -> 15 (+1.31)",
    "ap_base: 117 -> 127 (+10)")
check("haste" not in out.split("stat lab #2")[1], "secret values are left out of the diff")
cmd("spells")
cmd("auras")
cmd("items 8949,3390")
cmd("threat")
has("\n".join(printed(L)), "spellbook (C_SpellBook): 10 entries", "buffs: Well Fed (24800)", "items: read 2",
    "threat: detailed missing")
text = L.eval("function() return BattleplanProbe.export() end")()
data = json.loads(text)
check(len(data["statlab"]) == 2 and data["statlab"][1]["label"] == "+10 agility", "export has the stat lab")
check(data["statlab"][0]["unreadable"]["haste"] == "secret", "secret stats recorded as secret")
check(data["captures"]["spells"][0]["data"]["spells"][0]["bookName"] == "Sinister Strike", "export has spells")
check(data["captures"]["items"][0]["data"]["items"][0]["spellName"] == "Agility", "export has item buffs")
check("defense_base" in data["statlab"][0]["values"], "stat lab reads defense through UnitDefenseSkill")

# The beta client lacks these Classic globals (data/probe/2026-10-05-warrior-12.json, env), so the
# mock must too: Battleplan and the probe have to work from the C_* APIs alone.
for name in ("UnitBuff", "GetItemSpell", "GetSpellPowerCost", "GetNumSpellTabs", "GetSpellTabInfo",
             "GetSpellBookItemName", "GetSpellBookItemInfo", "UnitDefense"):
    check(L.eval(name) is None, f"mock has no {name}, like the beta client")

print(f"\nsmoke test passed: {checks} checks")
