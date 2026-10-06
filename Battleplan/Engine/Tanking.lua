-- Tank guide filtered to what the character can cast. No WoW calls.
local _, ns = ...

local Tanking = {}
ns.Engine.Tanking = Tanking

local Rotation = ns.Engine.Rotation

function Tanking.Build(data, spec, known, level, ranks)
  local guide = data and ns.Engine.Score.Lookup(data, spec)
  if not guide then return nil end
  local upcoming, seen = {}, {}
  local built = {
    single = Rotation.Filter(guide.single, known, level, upcoming, seen, nil, ranks),
    multi = Rotation.Filter(guide.multi, known, level, upcoming, seen, nil, ranks),
    cooldowns = Rotation.Filter(guide.cooldowns, known, level, upcoming, seen, nil, ranks),
    pullPlan = {},
    setup = {},
    upcoming = upcoming,
  }
  for _, step in ipairs(guide.pullPlan or {}) do
    if type(step) == "string" then built.pullPlan[#built.pullPlan + 1] = step
    elseif not step.spell or known[step.spell] then built.pullPlan[#built.pullPlan + 1] = step.text end
  end
  for _, step in ipairs(guide.setup or {}) do
    local learned = not step.spell or known[step.spell] ~= nil
    if learned or step.unavailable then
      built.setup[#built.setup + 1] = { label = step.label,
        note = learned and step.note or step.unavailable, spell = learned and step.spell or nil }
    end
  end
  table.sort(upcoming, function(a, b) return (a.minLevel or 999) < (b.minLevel or 999) end)
  return built
end
