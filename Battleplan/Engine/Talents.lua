-- Talent plans: where the next point goes, and how the current build differs
-- from the recommended one. No WoW calls.
local _, ns = ...

local Talents = {}
ns.Engine.Talents = Talents

Talents.FIRST_LEVEL = 10 -- first point at 10, then one per level (beta capture)
Talents.MAX_POINTS = 51

function Talents.Points(level)
  local n = level - Talents.FIRST_LEVEL + 1
  if n < 0 then return 0 end
  if n > Talents.MAX_POINTS then return Talents.MAX_POINTS end
  return n
end

-- Point i is reached at this level.
function Talents.LevelOfPoint(i)
  return Talents.FIRST_LEVEL + i - 1
end

-- order = { {name, toRank}, ... } -> one entry per point: { name=, rank= }
-- Cached per order table, since the data never changes at runtime.
local expanded = setmetatable({}, { __mode = "k" })

function Talents.Expand(order)
  if expanded[order] then return expanded[order] end
  local points, have = {}, {}
  for _, step in ipairs(order) do
    local name, to = step[1], step[2]
    for r = (have[name] or 0) + 1, to do
      points[#points + 1] = { name = name, rank = r }
    end
    if to > (have[name] or 0) then have[name] = to end
  end
  expanded[order] = points
  return points
end

-- build: a Data talent build (with .order); current: { [name] = rank }.
function Talents.Plan(build, level, current)
  local points = Talents.Expand(build.order)
  local available = Talents.Points(level)
  local spent = 0
  for _, rank in pairs(current) do spent = spent + rank end

  local target = {}
  for i = 1, math.min(available, #points) do
    local p = points[i]
    target[p.name] = p.rank
  end

  -- Next point: the first step of the build this character hasn't taken.
  local nextPoint, nextIndex
  for i, p in ipairs(points) do
    if (current[p.name] or 0) < p.rank then
      nextPoint, nextIndex = p, i
      break
    end
  end

  local missing, extra = {}, {}
  for name, want in pairs(target) do
    local have = current[name] or 0
    if have < want then missing[#missing + 1] = { name = name, have = have, want = want } end
  end
  for name, have in pairs(current) do
    local want = target[name] or 0
    if have > want then extra[#extra + 1] = { name = name, have = have, want = want } end
  end
  table.sort(missing, function(a, b) return a.name < b.name end)
  table.sort(extra, function(a, b) return a.name < b.name end)

  return {
    available = available, spent = spent, unspent = available - spent, total = #points,
    next = (spent < available) and nextPoint or nil, nextIndex = nextIndex,
    upcoming = nextPoint, -- the next step even when no point is free yet
    missing = missing, extra = extra, target = target, onPlan = #missing == 0 and #extra == 0,
  }
end
