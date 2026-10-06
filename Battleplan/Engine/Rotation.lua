-- Rotations filtered to what the character can actually cast. No WoW calls.
local _, ns = ...

local Rotation = {}
ns.Engine.Rotation = Rotation

local Lookup = ns.Engine.Score.Lookup

-- Highest rank of a trainer ability the level allows, when it beats the one known.
local function trainRank(learn, best, level)
  if not (learn and learn.ranks and best) or learn.quest then return nil end
  local n = 0
  for i = 1, #learn.ranks do
    if learn.ranks[i] <= level then n = i end
  end
  return n > best and n or nil
end

-- list: Data entries; known: API.KnownSpells() shape ({ [name] = { best = rank } }).
-- ranks: Data/SpellRanks.lua for the class (optional). A hand-written minLevel wins
-- over the imported learn level.
-- Returns rows the character can use, and upcoming entries they can't yet.
function Rotation.Filter(list, known, level, upcoming, seen, catalog, ranks)
  local rows = {}
  for _, e in ipairs(list or {}) do
    local k = known[e.spell]
    local learn = ranks and ranks[e.spell]
    if k then
      local reference = catalog and catalog[k.id]
      if reference and reference.rank and reference.rank ~= k.best then reference = nil end
      rows[#rows + 1] = { spell = e.spell, note = e.note, rank = k.best, talent = e.talent,
        spellID = k.id, reference = reference and reference.name == e.spell and reference or nil,
        trainRank = trainRank(learn, k.best, level) }
    elseif upcoming and not seen[e.spell] then
      seen[e.spell] = true
      local minLevel = e.minLevel or (not e.talent and learn and learn.level or nil)
      local quest = learn and learn.quest or nil
      upcoming[#upcoming + 1] = {
        spell = e.spell, spellID = e.spellID or learn and learn.id, note = e.note, talent = e.talent,
        minLevel = minLevel, quest = quest,
        trainable = (not e.talent) and not quest and minLevel ~= nil and minLevel <= level,
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
function Rotation.Build(data, spec, situation, known, level, catalog, ranks)
  local specData = Lookup(data, spec)
  if not specData then return nil end
  local r = Lookup(specData, situation) or Lookup(specData, "default")
  if not r then return nil end
  local upcoming, seen = {}, {}
  local built = {
    opener = Rotation.Filter(r.opener, known, level, upcoming, seen, catalog, ranks),
    priority = Rotation.Filter(r.priority, known, level, upcoming, seen, catalog, ranks),
    utility = Rotation.Filter(r.utility, known, level, upcoming, seen, catalog, ranks),
    upcoming = upcoming,
    scopeNote = data.scopeNote,
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
