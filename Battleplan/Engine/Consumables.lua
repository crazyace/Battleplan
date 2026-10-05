-- Best consumables for a spec and level, and which buffs are missing.
-- No WoW calls.
local _, ns = ...

local Consumables = {}
ns.Engine.Consumables = Consumables

local Score = ns.Engine.Score

-- Potions are grouped by what they restore; everything else by kind.
local function groupOf(e)
  if e.kind == "potion" then return e.stat end
  return e.kind
end
Consumables.GROUP_ORDER = { "elixir", "weapon", "food", "HEAL_POTION", "MANA_POTION" }
Consumables.GROUP_NAMES = {
  elixir = "Elixir", weapon = "Weapon", food = "Food", HEAL_POTION = "Healing potion", MANA_POTION = "Mana potion",
}

-- opts: { level=, weights=, weaponKind = "edged"|"blunt"|"any" }
-- Returns { [group] = { item = entry, score = n } }
function Consumables.Recommend(list, opts)
  local best = {}
  for _, e in ipairs(list) do
    local usable = (e.minLevel or 0) <= opts.level
    if usable and e.kind == "weapon" and e.weapon ~= "any" then
      usable = opts.weaponKind == "any" or e.weapon == opts.weaponKind
    end
    if usable then
      local s = Score.Entry(e, opts.weights)
      local g = groupOf(e)
      local cur = best[g]
      if s > 0 and (not cur or s > cur.score or (s == cur.score and (e.minLevel or 0) > (cur.item.minLevel or 0))) then
        best[g] = { item = e, score = s }
      end
    end
  end
  return best
end

-- What's missing right now.
-- rec: Recommend() result; auras: { [auraName] = spellID }
-- elixirAuras: { [auraName] = true } for every elixir in the data
-- weaponHasEnchant: true / false / nil (unknown)
-- Returns { { group=, item= } } in GROUP_ORDER.
function Consumables.BuffCheck(rec, auras, elixirAuras, weaponHasEnchant, foodAura)
  local missing = {}
  if rec.elixir then
    local has = false
    for name in pairs(auras) do
      if elixirAuras[name] then has = true; break end
    end
    if not has then missing[#missing + 1] = { group = "elixir", item = rec.elixir.item } end
  end
  if rec.weapon and weaponHasEnchant == false then
    missing[#missing + 1] = { group = "weapon", item = rec.weapon.item }
  end
  if rec.food and not auras[foodAura or "Well Fed"] then
    missing[#missing + 1] = { group = "food", item = rec.food.item }
  end
  return missing
end
