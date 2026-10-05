-- Rotations filtered to what the character can actually cast. No WoW calls.
local _, ns = ...

local Rotation = {}
ns.Engine.Rotation = Rotation

local Lookup = ns.Engine.Score.Lookup

-- list: Data entries; known: API.KnownSpells() shape ({ [name] = { best = rank } }).
-- Returns rows the character can use, and upcoming entries they can't yet.
function Rotation.Filter(list, known, level, upcoming, seen)
  local rows = {}
  for _, e in ipairs(list or {}) do
    local k = known[e.spell]
    if k then
      rows[#rows + 1] = { spell = e.spell, note = e.note, rank = k.best, talent = e.talent }
    elseif upcoming and not seen[e.spell] then
      seen[e.spell] = true
      upcoming[#upcoming + 1] = {
        spell = e.spell, note = e.note, talent = e.talent, minLevel = e.minLevel,
        trainable = (not e.talent) and e.minLevel ~= nil and e.minLevel <= level,
      }
    end
  end
  return rows
end

local function byLevel(a, b)
  local la, lb = a.minLevel or 999, b.minLevel or 999
  if la ~= lb then return la < lb end
  return a.spell < b.spell
end

-- data: Data/<CLASS>/Rotations.lua; returns nil when there's no rotation for the spec.
function Rotation.Build(data, spec, situation, known, level)
  local specData = Lookup(data, spec)
  if not specData then return nil end
  local r = Lookup(specData, situation) or Lookup(specData, "default")
  if not r then return nil end
  local upcoming, seen = {}, {}
  local built = {
    opener = Rotation.Filter(r.opener, known, level, upcoming, seen),
    priority = Rotation.Filter(r.priority, known, level, upcoming, seen),
    utility = Rotation.Filter(r.utility, known, level, upcoming, seen),
    upcoming = upcoming,
  }
  table.sort(upcoming, byLevel)
  return built
end

-- What's new in the priority list since last time: { {spell=, position=, rank=, why = "new"|"rank"} }
function Rotation.Changes(old, new)
  local changes = {}
  if not old or not new then return changes end
  local before = {}
  for _, row in ipairs(old.priority) do before[row.spell] = row.rank end
  for i, row in ipairs(new.priority) do
    local was = before[row.spell]
    if not was then
      changes[#changes + 1] = { spell = row.spell, position = i, rank = row.rank, why = "new" }
    elseif (row.rank or 0) > (was or 0) then
      changes[#changes + 1] = { spell = row.spell, position = i, rank = row.rank, why = "rank" }
    end
  end
  return changes
end
