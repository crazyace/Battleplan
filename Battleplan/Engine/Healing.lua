-- Healing per mana for the heals a character knows, and which heal fits each
-- situation. No WoW calls: Planner feeds it spell details from Core/API.lua.
local _, ns = ...

local Healing = {}
ns.Engine.Healing = Healing

Healing.GCD_SECONDS = 1.5

local function num(s)
  return s and tonumber((s:gsub(",", ""))) or nil
end

-- Healing amount from a spell description:
--   "Heals your target for 47 to 58."            -> 47, 58
--   "Heals the target for 45 over 15 sec."       -> 45, 45, 15
--   "... absorbing 48 damage. Lasts 30 sec."     -> 48, 48
-- Returns min, max, overSeconds (nil when no amount is found).
function Healing.ParseAmount(text)
  if type(text) ~= "string" then return nil end
  local a, b = text:match("(%d[%d,]*) to (%d[%d,]*)")
  if a then return num(a), num(b) end
  local amount, secs = text:match("for (%d[%d,]*) over (%d+) sec")
  if amount then return num(amount), num(amount), tonumber(secs) end
  amount = text:match("absorbing (%d[%d,]*) damage")
  if amount then return num(amount), num(amount) end
  return nil
end

-- raw: { { name=, rank=, id=, cost=, castMs=, min=, max=, overSeconds=, targets= }, ... }
-- Adds avg, hpm (healing per mana) and hps (healing per second of casting).
-- Rows without an amount or a cost are kept with nil hpm, so the table can
-- still list them.
function Healing.Rows(raw)
  local rows = {}
  for _, r in ipairs(raw) do
    local row = {}
    for k, v in pairs(r) do row[k] = v end
    if r.min and r.max then
      -- Party heals count every target they hit (r.targets, from the guide).
      row.avg = (r.min + r.max) / 2 * (r.targets or 1)
      if r.cost and r.cost > 0 then row.hpm = row.avg / r.cost end
      local seconds = (r.castMs and r.castMs > 0) and (r.castMs / 1000) or Healing.GCD_SECONDS
      if seconds < Healing.GCD_SECONDS then seconds = Healing.GCD_SECONDS end
      row.hps = row.avg / seconds
    end
    rows[#rows + 1] = row
  end
  table.sort(rows, function(a, b)
    if (a.hpm or -1) ~= (b.hpm or -1) then return (a.hpm or -1) > (b.hpm or -1) end
    if a.name ~= b.name then return a.name < b.name end
    return (a.rank or 0) > (b.rank or 0)
  end)
  return rows
end

-- The rank to use: "max" = highest; "efficient" = best healing per mana
-- (falls back to highest when amounts are unknown).
local function better(row, best, policy)
  if policy == "efficient" then
    if row.hpm and not best.hpm then return true end
    if row.hpm and best.hpm then
      if row.hpm ~= best.hpm then return row.hpm > best.hpm end
      return row.rank > best.rank
    end
    if best.hpm then return false end
  end
  return (row.rank or 0) > (best.rank or 0)
end

function Healing.ChooseRank(rows, name, policy)
  local best
  for _, row in ipairs(rows) do
    if row.name == name and (not best or better(row, best, policy)) then best = row end
  end
  return best
end

-- situations: Data situations; rows: Healing.Rows().
-- Returns { { label=, note=, row= (or nil), spell= } } in data order.
function Healing.Pick(situations, rows)
  local out = {}
  for _, s in ipairs(situations or {}) do
    local pick
    for _, name in ipairs(s.prefer) do
      pick = Healing.ChooseRank(rows, name, s.rank)
      if pick then break end
    end
    out[#out + 1] = { key = s.key, label = s.label, note = s.note, row = pick, spell = pick and pick.name }
  end
  return out
end

-- Every spell name a healing guide mentions, for Planner to look up.
function Healing.SpellNames(guide)
  local names, seen = {}, {}
  local function add(n) if n and not seen[n] then seen[n] = true; names[#names + 1] = n end end
  for _, s in ipairs(guide.situations or {}) do
    for _, n in ipairs(s.prefer) do add(n) end
  end
  return names
end
