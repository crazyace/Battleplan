local _, ns = ...

local util = ns.util

local HELP = {
  "/bplan  - open or close the window",
  "/bplan situation <auto|leveling|solo|dungeon|raid>",
  "/bplan spec <auto|spec name>  - advise for another spec",
  "/bplan buffs  - which consumable buffs are missing",
  "/bplan buffcheck  - turn the dungeon/raid reminder on or off",
  "/bplan perf [on|off|reset]  - handler timings (perf report)",
  "/bplan debug  - debug messages on or off",
  "/bplan reset  - reset settings and window position",
}

local function situation(arg)
  local valid = { auto = true }
  for _, s in ipairs(ns.SITUATIONS) do valid[s] = true end
  if not valid[arg] then return util.print("situation: auto, leveling, solo, dungeon or raid") end
  ns.db.situation = arg
  util.print("situation: %s", arg)
  ns.Planner.Queue()
end

local function spec(arg)
  local data = ns.Data[ns.API.PlayerClass() or ""]
  if arg ~= "auto" and not (data and data.Specs.names[arg]) then
    local names = {}
    for _, key in ipairs(data and data.Specs.order or {}) do names[#names + 1] = key end
    return util.print("spec: auto%s", #names > 0 and (", " .. table.concat(names, ", ")) or "")
  end
  ns.db.spec = arg
  util.print("spec: %s", arg)
  ns.Planner.Queue()
end

local function buffs()
  ns.Planner.CheckBuffs()
  local missing = ns.state.missing
  if not missing then return util.print("no plan yet; try again in a moment") end
  if #missing == 0 then return util.print("consumables: you're set") end
  for _, m in ipairs(missing) do
    util.print("missing %s: %s", ns.Engine.Consumables.GROUP_NAMES[m.group]:lower(), m.item.name)
  end
end

local function perf(arg)
  if arg == "on" or arg == "off" then
    ns.db.debugPerf = arg == "on"
    return util.print("perf timing %s", arg)
  end
  if arg == "reset" then
    ns.Perf.Reset()
    return util.print("perf timings cleared")
  end
  if not ns.db.debugPerf then util.print("perf timing is off: /bplan perf on, play a while, then /bplan perf") end
  local report = ns.Perf.Report()
  if #report == 0 then return util.print("no timings yet") end
  for _, r in ipairs(report) do
    util.print("%s%s  n=%d  avg=%.3f ms  max=%.3f ms", r.over and util.color("red", "OVER ") or "",
      r.label, r.n, r.avg, r.max)
  end
end

local COMMANDS = {
  situation = situation, spec = spec, buffs = buffs, perf = perf,
  buffcheck = function()
    ns.db.buffCheck = not ns.db.buffCheck
    util.print("dungeon/raid buff reminder %s", ns.db.buffCheck and "on" or "off")
  end,
  debug = function()
    ns.db.debug = not ns.db.debug
    util.print("debug %s", ns.db.debug and "on" or "off")
  end,
  reset = function()
    ns:ResetDB()
    util.print("settings reset (window position applies after /reload)")
    ns.Planner.Queue()
  end,
  help = function() for _, line in ipairs(HELP) do util.print(line) end end,
}

SLASH_BATTLEPLAN1 = "/bplan"
SLASH_BATTLEPLAN2 = "/battleplan"
SlashCmdList.BATTLEPLAN = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  if cmd == "" then return ns.UI.Toggle() end
  local fn = COMMANDS[cmd]
  if fn then return fn(rest:lower()) end
  COMMANDS.help()
end
