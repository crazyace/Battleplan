-- Which spec and situation to advise for. No WoW calls.
local _, ns = ...

local Spec = {}
ns.Engine.Spec = Spec

-- talents: API.ReadTalents() result (or nil); specs: Data/<CLASS>/Specs.lua.
-- Returns specKey, how ("override" | "talents" | "leveling" | "no-talents").
function Spec.Detect(talents, specs, override)
  if override and override ~= "auto" and specs.names[override] then return override, "override" end
  if not talents or not talents.tabs then return specs.leveling, "no-talents" end
  local bestTab, bestPoints = nil, 0
  for tab, entry in ipairs(talents.tabs) do
    if entry.points > bestPoints then bestTab, bestPoints = tab, entry.points end
  end
  if not bestTab then return specs.leveling, "leveling" end
  return specs.order[bestTab] or specs.leveling, "talents"
end

-- "auto" -> leveling below max level, dungeon at max level.
function Spec.Situation(setting, level, maxLevel)
  if setting and setting ~= "auto" then return setting end
  if level < (maxLevel or 60) then return "leveling" end
  return "dungeon"
end

-- All tabs' talents in one map: { [name] = rank }
function Spec.Flatten(talents)
  local out = {}
  if not talents or not talents.tabs then return out end
  for _, entry in ipairs(talents.tabs) do
    for name, rank in pairs(entry.talents) do
      if rank > (out[name] or 0) then out[name] = rank end
    end
  end
  return out
end
