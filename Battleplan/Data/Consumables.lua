-- Consumables every class draws from. Each entry gives one stat so the
-- engine can score it with the spec's weights.
--
-- PROVISIONAL: item IDs, amounts and levels are Classic values. Professions
-- were reworked for Forever, so confirm each one with the probe
-- (python tools/consumable_ids.py prints the /bpp items commands).
--
-- kind: elixir | weapon | food | potion
-- stat: a key from Data/Stats.lua; amount: how much of it
-- minLevel: required level to use it (0 = none)
-- weapon: "edged" (sharpening stones), "blunt" (weightstones) or "any" (oils)
local _, ns = ...

ns.Data.Consumables = {
  _status = "provisional",
  -- Food buffs all show as this aura, whatever the food.
  foodAura = "Well Fed",

  -- Elixirs
  { itemID = 2457, name = "Elixir of Minor Agility", kind = "elixir", stat = "AGILITY", amount = 4, minLevel = 2 },
  { itemID = 3390, name = "Elixir of Lesser Agility", kind = "elixir", stat = "AGILITY", amount = 8, minLevel = 18 },
  { itemID = 8949, name = "Elixir of Agility", kind = "elixir", stat = "AGILITY", amount = 15, minLevel = 27 },
  { itemID = 9187, name = "Elixir of Greater Agility", kind = "elixir", stat = "AGILITY", amount = 25, minLevel = 38 },
  { itemID = 13452, name = "Elixir of the Mongoose", kind = "elixir", stat = "AGILITY", amount = 25, minLevel = 46,
    extra = { CRIT_PCT = 2 } },
  { itemID = 2454, name = "Elixir of Lion's Strength", kind = "elixir", stat = "STRENGTH", amount = 4, minLevel = 1 },
  { itemID = 3391, name = "Elixir of Ogre's Strength", kind = "elixir", stat = "STRENGTH", amount = 8, minLevel = 20 },
  { itemID = 9206, name = "Elixir of Giants", kind = "elixir", stat = "STRENGTH", amount = 25, minLevel = 46 },
  { itemID = 3383, name = "Elixir of Wisdom", kind = "elixir", stat = "INTELLECT", amount = 6, minLevel = 15 },
  { itemID = 9179, name = "Elixir of Greater Intellect", kind = "elixir", stat = "INTELLECT", amount = 25, minLevel = 37 },
  { itemID = 20007, name = "Mageblood Potion", kind = "elixir", stat = "MP5", amount = 12, minLevel = 40 },
  { itemID = 2458, name = "Elixir of Minor Fortitude", kind = "elixir", stat = "HEALTH", amount = 27, minLevel = 2 },
  { itemID = 3825, name = "Elixir of Fortitude", kind = "elixir", stat = "HEALTH", amount = 120, minLevel = 25 },
  { itemID = 5997, name = "Elixir of Minor Defense", kind = "elixir", stat = "ARMOR", amount = 50, minLevel = 1 },
  { itemID = 3389, name = "Elixir of Defense", kind = "elixir", stat = "ARMOR", amount = 150, minLevel = 16 },
  { itemID = 8951, name = "Elixir of Greater Defense", kind = "elixir", stat = "ARMOR", amount = 250, minLevel = 29 },
  { itemID = 13445, name = "Elixir of Superior Defense", kind = "elixir", stat = "ARMOR", amount = 450, minLevel = 43 },

  -- Weapon: sharpening stones (edged), weightstones (blunt), oils (any)
  { itemID = 2862, name = "Rough Sharpening Stone", kind = "weapon", weapon = "edged", stat = "WEAPON_DAMAGE", amount = 2, minLevel = 1 },
  { itemID = 2863, name = "Coarse Sharpening Stone", kind = "weapon", weapon = "edged", stat = "WEAPON_DAMAGE", amount = 3, minLevel = 5 },
  { itemID = 2871, name = "Heavy Sharpening Stone", kind = "weapon", weapon = "edged", stat = "WEAPON_DAMAGE", amount = 4, minLevel = 15 },
  { itemID = 7964, name = "Solid Sharpening Stone", kind = "weapon", weapon = "edged", stat = "WEAPON_DAMAGE", amount = 6, minLevel = 25 },
  { itemID = 12404, name = "Dense Sharpening Stone", kind = "weapon", weapon = "edged", stat = "WEAPON_DAMAGE", amount = 8, minLevel = 35 },
  { itemID = 18262, name = "Elemental Sharpening Stone", kind = "weapon", weapon = "any", stat = "CRIT_PCT", amount = 2, minLevel = 50 },
  { itemID = 3239, name = "Rough Weightstone", kind = "weapon", weapon = "blunt", stat = "WEAPON_DAMAGE", amount = 2, minLevel = 1 },
  { itemID = 3240, name = "Coarse Weightstone", kind = "weapon", weapon = "blunt", stat = "WEAPON_DAMAGE", amount = 3, minLevel = 5 },
  { itemID = 3241, name = "Heavy Weightstone", kind = "weapon", weapon = "blunt", stat = "WEAPON_DAMAGE", amount = 4, minLevel = 15 },
  { itemID = 7965, name = "Solid Weightstone", kind = "weapon", weapon = "blunt", stat = "WEAPON_DAMAGE", amount = 6, minLevel = 25 },
  { itemID = 12643, name = "Dense Weightstone", kind = "weapon", weapon = "blunt", stat = "WEAPON_DAMAGE", amount = 8, minLevel = 35 },
  { itemID = 20744, name = "Minor Wizard Oil", kind = "weapon", weapon = "any", stat = "SPELL_POWER", amount = 8, minLevel = 5 },
  { itemID = 20746, name = "Lesser Wizard Oil", kind = "weapon", weapon = "any", stat = "SPELL_POWER", amount = 16, minLevel = 30 },
  { itemID = 20749, name = "Brilliant Wizard Oil", kind = "weapon", weapon = "any", stat = "SPELL_POWER", amount = 36, minLevel = 45 },
  { itemID = 20745, name = "Minor Mana Oil", kind = "weapon", weapon = "any", stat = "MP5", amount = 4, minLevel = 20 },
  { itemID = 20747, name = "Lesser Mana Oil", kind = "weapon", weapon = "any", stat = "MP5", amount = 8, minLevel = 40 },
  { itemID = 20748, name = "Brilliant Mana Oil", kind = "weapon", weapon = "any", stat = "MP5", amount = 12, minLevel = 45,
    extra = { HEALING = 25 } },

  -- Food (the buff is always "Well Fed")
  { itemID = 2680, name = "Spiced Wolf Meat", kind = "food", stat = "STAMINA", amount = 2, minLevel = 1, extra = { SPIRIT = 2 } },
  { itemID = 724, name = "Goretusk Liver Pie", kind = "food", stat = "STAMINA", amount = 4, minLevel = 5, extra = { SPIRIT = 4 } },
  { itemID = 3662, name = "Crocolisk Steak", kind = "food", stat = "STAMINA", amount = 4, minLevel = 15, extra = { SPIRIT = 4 } },
  { itemID = 12209, name = "Lean Wolf Steak", kind = "food", stat = "STAMINA", amount = 8, minLevel = 25, extra = { SPIRIT = 8 } },
  { itemID = 12218, name = "Monster Omelet", kind = "food", stat = "STAMINA", amount = 12, minLevel = 35, extra = { SPIRIT = 12 } },
  { itemID = 13928, name = "Grilled Squid", kind = "food", stat = "AGILITY", amount = 10, minLevel = 35 },
  { itemID = 20452, name = "Smoked Desert Dumplings", kind = "food", stat = "STRENGTH", amount = 20, minLevel = 45 },
  { itemID = 13931, name = "Nightfin Soup", kind = "food", stat = "MP5", amount = 8, minLevel = 35 },
  { itemID = 18254, name = "Runn Tum Tuber Surprise", kind = "food", stat = "INTELLECT", amount = 10, minLevel = 45 },

  -- Potions: amount is a tier (bigger is better), scored on its own
  { itemID = 118, name = "Minor Healing Potion", kind = "potion", stat = "HEAL_POTION", amount = 1, minLevel = 1 },
  { itemID = 858, name = "Lesser Healing Potion", kind = "potion", stat = "HEAL_POTION", amount = 2, minLevel = 3 },
  { itemID = 929, name = "Healing Potion", kind = "potion", stat = "HEAL_POTION", amount = 3, minLevel = 12 },
  { itemID = 1710, name = "Greater Healing Potion", kind = "potion", stat = "HEAL_POTION", amount = 4, minLevel = 21 },
  { itemID = 3928, name = "Superior Healing Potion", kind = "potion", stat = "HEAL_POTION", amount = 5, minLevel = 35 },
  { itemID = 13446, name = "Major Healing Potion", kind = "potion", stat = "HEAL_POTION", amount = 6, minLevel = 45 },
  { itemID = 2455, name = "Minor Mana Potion", kind = "potion", stat = "MANA_POTION", amount = 1, minLevel = 5 },
  { itemID = 3385, name = "Lesser Mana Potion", kind = "potion", stat = "MANA_POTION", amount = 2, minLevel = 14 },
  { itemID = 3827, name = "Mana Potion", kind = "potion", stat = "MANA_POTION", amount = 3, minLevel = 22 },
  { itemID = 6149, name = "Greater Mana Potion", kind = "potion", stat = "MANA_POTION", amount = 4, minLevel = 31 },
  { itemID = 13443, name = "Superior Mana Potion", kind = "potion", stat = "MANA_POTION", amount = 5, minLevel = 41 },
  { itemID = 13444, name = "Major Mana Potion", kind = "potion", stat = "MANA_POTION", amount = 6, minLevel = 49 },
}
