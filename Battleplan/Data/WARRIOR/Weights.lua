-- Protection in Stamina-equivalents; Arms/Fury in Strength-equivalents.
-- PROVISIONAL (Classic thinking) until the stat lab runs on a Warrior.
local _, ns = ...

ns.Data.WARRIOR.Weights = {
  _status = "provisional",
  protection = {
    STAMINA = 1.0, ARMOR = 0.08, DEFENSE = 1.5, DODGE_PCT = 18, AGILITY = 0.6, STRENGTH = 0.4,
    HEALTH = 0.1, HIT_PCT = 6, EXPERTISE_PCT = 6, ATTACK_POWER = 0.15, WEAPON_DAMAGE = 0.5,
    HEAL_POTION = 1,
  },
  arms = {
    STRENGTH = 1.0, AGILITY = 0.6, ATTACK_POWER = 0.5, CRIT_PCT = 16, HIT_PCT = 18, STAMINA = 0.15,
    WEAPON_DAMAGE = 3, HEALTH = 0.015, ARMOR = 0.005, HEAL_POTION = 1,
  },
}
ns.Data.WARRIOR.Weights.fury = ns.Data.WARRIOR.Weights.arms
