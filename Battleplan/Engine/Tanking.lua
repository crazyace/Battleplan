-- Tank guide filtered to what the character can cast. No WoW calls.
local _, ns = ...

local Tanking = {}
ns.Engine.Tanking = Tanking

local Rotation = ns.Engine.Rotation

function Tanking.Build(data, spec, known, level)
  local guide = data and ns.Engine.Score.Lookup(data, spec)
  if not guide then return nil end
  local upcoming, seen = {}, {}
  local built = {
    single = Rotation.Filter(guide.single, known, level, upcoming, seen),
    multi = Rotation.Filter(guide.multi, known, level, upcoming, seen),
    cooldowns = Rotation.Filter(guide.cooldowns, known, level, upcoming, seen),
    pullPlan = guide.pullPlan or {},
    setups = guide.setups,
    upcoming = upcoming,
  }
  table.sort(upcoming, function(a, b) return (a.minLevel or 999) < (b.minLevel or 999) end)
  return built
end
