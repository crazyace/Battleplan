-- Healers in Healing-equivalents (+1 healing = 1.0); Shadow in
-- Spell-power-equivalents. PROVISIONAL until the stat lab measures
-- Intellect -> crit and Spirit -> regen on Forever. Known so far (level 12):
-- 9.6 Intellect per 1% spell crit.
local _, ns = ...

local healer = {
  HEALING = 1.0, INTELLECT = 0.6, SPIRIT = 0.45, MP5 = 2.5, STAMINA = 0.1,
  SPELL_POWER = 0.25, CRIT_PCT = 8, HASTE_PCT = 8, HEALTH = 0.01, ARMOR = 0.002,
  MANA_POTION = 1, HEAL_POTION = 1,
}

ns.Data.PRIEST.Weights = {
  _status = "provisional",
  holy = healer,
  discipline = healer,
  shadow = {
    SPELL_POWER = 1.0, INTELLECT = 0.4, SPIRIT = 0.35, STAMINA = 0.15, HIT_PCT = 12, CRIT_PCT = 6,
    HASTE_PCT = 8, MP5 = 1.0, HEALTH = 0.015, ARMOR = 0.002, MANA_POTION = 1, HEAL_POTION = 1,
  },
}
