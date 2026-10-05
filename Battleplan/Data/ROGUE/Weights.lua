-- Stat weights per spec, in Agility-equivalents (Agility = 1.0).
-- PROVISIONAL until tools/theorycraft reads data/stats/conversions.json from
-- the stat lab. Known so far (level 19, beta): ~7.6 Agility per 1% crit,
-- 1 AP per Agility and per Strength for Rogues.
local _, ns = ...

local base = {
  AGILITY = 1.0, STRENGTH = 0.5, ATTACK_POWER = 0.5, STAMINA = 0.15,
  CRIT_PCT = 14, HIT_PCT = 16, HASTE_PCT = 10, EXPERTISE_PCT = 10,
  WEAPON_DAMAGE = 2.5, HEALTH = 0.015, ARMOR = 0.005,
  HEAL_POTION = 1,
}

local function with(changes)
  local t = {}
  for k, v in pairs(base) do t[k] = v end
  for k, v in pairs(changes or {}) do t[k] = v end
  return t
end

ns.Data.ROGUE.Weights = {
  _status = "provisional",
  assassination = with({ CRIT_PCT = 16 }), -- Seal Fate turns crits into combo points
  combat = with({ HIT_PCT = 18, WEAPON_DAMAGE = 3 }),
  subtlety = with({}),
}
