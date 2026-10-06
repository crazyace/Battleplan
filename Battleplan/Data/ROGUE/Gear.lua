-- Gear advice: enchants per slot and upgrade targets.
--
-- Enchants: recipe IDs and amounts from the beta's Enchanting window
-- (2026-10-03, docs/BETA-FINDINGS.md) where the amount was confirmed; Classic
-- amounts otherwise (marked "classic"). Slot IDs are inventory slots.
-- targets: the next item to chase per slot. Empty until the probe's loot log
-- and the stat lab give us real items (see ROADMAP.md).
-- Empty class targets fall back to the provisional shared GearCatalog.
local _, ns = ...

local AGI_ENCHANTS = {
  [9] = { -- wrist
    { recipe = 1248599, name = "Superior Agility", stat = "AGILITY", amount = 9 },
    { recipe = 1217203, name = "Agility", stat = "AGILITY", amount = 9 },
    { recipe = 1248497, name = "Agility", stat = "AGILITY", amount = 5 },
    { recipe = 7779, name = "Minor Agility", stat = "AGILITY", amount = 1, source = "classic" },
  },
  [8] = { -- feet
    { recipe = 20023, name = "Greater Agility", stat = "AGILITY", amount = 7, source = "classic" },
    { recipe = 13935, name = "Agility", stat = "AGILITY", amount = 5, source = "classic" },
    { recipe = 13637, name = "Lesser Agility", stat = "AGILITY", amount = 3, source = "classic" },
    { recipe = 7867, name = "Minor Agility", stat = "AGILITY", amount = 1, source = "classic" },
  },
  [10] = { -- hands
    { recipe = 25080, name = "Superior Agility", stat = "AGILITY", amount = 15, source = "classic" },
    { recipe = 20012, name = "Greater Agility", stat = "AGILITY", amount = 7, source = "classic" },
    { recipe = 13815, name = "Agility", stat = "AGILITY", amount = 5, source = "classic" },
  },
  [15] = { -- back
    { recipe = 13882, name = "Lesser Agility", stat = "AGILITY", amount = 3 },
    { recipe = 13419, name = "Minor Agility", stat = "AGILITY", amount = 3 },
  },
  [5] = { -- chest
    { recipe = 1213616, name = "Living Stats", stat = "ALL_STATS", amount = 4 },
    { recipe = 13700, name = "Lesser Stats", stat = "ALL_STATS", amount = 2 },
    { recipe = 13626, name = "Minor Stats", stat = "ALL_STATS", amount = 2 },
  },
  [16] = { -- main hand
    { recipe = 23800, name = "Agility", stat = "AGILITY", amount = 15, source = "classic" },
    { recipe = 20031, name = "Superior Striking", stat = "WEAPON_DAMAGE", amount = 5, source = "classic" },
    { recipe = 13943, name = "Greater Striking", stat = "WEAPON_DAMAGE", amount = 4, source = "classic" },
    { recipe = 13503, name = "Lesser Striking", stat = "WEAPON_DAMAGE", amount = 2, source = "classic" },
  },
}
AGI_ENCHANTS[17] = AGI_ENCHANTS[16] -- off hand takes the same weapon enchants

ns.Data.ROGUE.Gear = {
  _status = "provisional",
  enchants = AGI_ENCHANTS,
  targets = {},
}
