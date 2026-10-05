-- Stat keys used across Battleplan's data files, and what we know about them.
local _, ns = ...

ns.Data.Stats = {
  _status = "verified", -- rating rates confirmed in the beta client (Gearwright findings, 2026-10-03)

  -- Display names for every stat key a weight, consumable or enchant can use.
  names = {
    STRENGTH = "Strength", AGILITY = "Agility", STAMINA = "Stamina", INTELLECT = "Intellect",
    SPIRIT = "Spirit", ALL_STATS = "All stats",
    ATTACK_POWER = "Attack power", SPELL_POWER = "Spell power", HEALING = "Healing",
    CRIT_PCT = "Crit %", HIT_PCT = "Hit %", HASTE_PCT = "Haste %", EXPERTISE_PCT = "Expertise %",
    MP5 = "Mana per 5 s", HEALTH = "Health", ARMOR = "Armor", DEFENSE = "Defense",
    DODGE_PCT = "Dodge %", WEAPON_DAMAGE = "Weapon damage",
    HEAL_POTION = "Healing potion", MANA_POTION = "Mana potion",
  },

  -- ALL_STATS counts as one point of each of these.
  allStats = { "STRENGTH", "AGILITY", "STAMINA", "INTELLECT", "SPIRIT" },

  -- Rating needed for 1%, the same at every item level on Forever.
  ratingPerPercent = { HIT = 10, CRIT = 14, HASTE = 10, EXPERTISE = 10, PARRY = 15, DEFENSE = 1 },

  -- C_Item.GetItemStats tokens -> { stat key, divide by } (ratings become %).
  -- Tokens seen on the beta: the six base stats, AP, ratings, armor (RESISTANCE0_NAME).
  tokens = {
    ITEM_MOD_STRENGTH_SHORT = { "STRENGTH", 1 }, ITEM_MOD_AGILITY_SHORT = { "AGILITY", 1 },
    ITEM_MOD_STAMINA_SHORT = { "STAMINA", 1 }, ITEM_MOD_INTELLECT_SHORT = { "INTELLECT", 1 },
    ITEM_MOD_SPIRIT_SHORT = { "SPIRIT", 1 },
    ITEM_MOD_ATTACK_POWER_SHORT = { "ATTACK_POWER", 1 },
    ITEM_MOD_HIT_RATING_SHORT = { "HIT_PCT", 10 }, ITEM_MOD_CRIT_RATING_SHORT = { "CRIT_PCT", 14 },
    ITEM_MOD_HASTE_RATING_SHORT = { "HASTE_PCT", 10 }, ITEM_MOD_EXPERTISE_RATING_SHORT = { "EXPERTISE_PCT", 10 },
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = { "DEFENSE", 1 },
    ITEM_MOD_SPELL_POWER_SHORT = { "SPELL_POWER", 1 }, ITEM_MOD_SPELL_HEALING_DONE_SHORT = { "HEALING", 1 },
    ITEM_MOD_MANA_REGENERATION_SHORT = { "MP5", 1 },
    RESISTANCE0_NAME = { "ARMOR", 1 },
  },
}
