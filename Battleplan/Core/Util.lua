local _, ns = ...

local util = {}
ns.util = util

local PREFIX = "|cffd4a017Battleplan|r: "

function util.print(fmt, ...)
  if select("#", ...) > 0 then fmt = fmt:format(...) end
  print(PREFIX .. fmt)
end

function util.debug(fmt, ...)
  if ns.db and ns.db.debug then util.print("|cff888888" .. fmt .. "|r", ...) end
end

util.COLOR = {
  gold = "|cffffd100", gray = "|cff9d9d9d", green = "|cff40ff40", red = "|cffff4040",
  blue = "|cff66ccff", white = "|cffffffff", reset = "|r",
}

function util.color(name, text)
  return (util.COLOR[name] or "") .. tostring(text) .. "|r"
end

-- "combat" -> "Combat", "dungeon" -> "Dungeon"
function util.title(s)
  s = tostring(s or "")
  return (s:gsub("^%l", string.upper))
end

function util.clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- Shallow copy of an array.
function util.copy(t)
  local out = {}
  for i = 1, #t do out[i] = t[i] end
  return out
end
