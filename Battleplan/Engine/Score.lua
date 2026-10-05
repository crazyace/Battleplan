-- Scoring and data lookups shared by every engine module. No WoW calls.
local _, ns = ...

local Score = {}
ns.Engine.Score = Score

-- Value of `amount` of one stat under a weight table.
function Score.Value(stat, amount, weights)
  if not weights or not amount then return 0 end
  if stat == "ALL_STATS" then
    local total = 0
    for _, s in ipairs(ns.Data.Stats.allStats) do total = total + (weights[s] or 0) end
    return total * amount
  end
  return (weights[stat] or 0) * amount
end

-- Value of a consumable or enchant entry: { stat=, amount=, extra = { STAT = n } }
function Score.Entry(entry, weights)
  local s = Score.Value(entry.stat, entry.amount, weights)
  if entry.extra then
    for stat, amount in pairs(entry.extra) do s = s + Score.Value(stat, amount, weights) end
  end
  return s
end

-- Value of a stat table: { STAT = amount, ... }
function Score.Stats(stats, weights)
  local s = 0
  for stat, amount in pairs(stats or {}) do s = s + Score.Value(stat, amount, weights) end
  return s
end

-- C_Item.GetItemStats tokens -> Battleplan stat table (unknown tokens ignored).
function Score.FromTokens(raw)
  local out = {}
  local map = ns.Data.Stats.tokens
  for token, value in pairs(raw or {}) do
    local m = map[token]
    if m and type(value) == "number" then out[m[1]] = (out[m[1]] or 0) + value / m[2] end
  end
  return out
end

-- Data lookup with reuse:
--   tbl[key] = "other"               -> tbl.other
--   tbl[key] = { from = "other", x } -> tbl.other with x laid over it
-- Returns nil when there's nothing usable.
function Score.Lookup(tbl, key, depth)
  if type(tbl) ~= "table" or key == nil then return nil end
  depth = depth or 0
  if depth > 5 then return nil end
  local v = tbl[key]
  if type(v) == "string" then return Score.Lookup(tbl, v, depth + 1) end
  if type(v) ~= "table" then return nil end
  if v.from then
    local base = Score.Lookup(tbl, v.from, depth + 1)
    if not base then return v end
    local merged = {}
    for k, val in pairs(base) do merged[k] = val end
    for k, val in pairs(v) do if k ~= "from" then merged[k] = val end end
    return merged
  end
  return v
end
