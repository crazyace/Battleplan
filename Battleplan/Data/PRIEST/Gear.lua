-- Priest enchants (Classic amounts, PROVISIONAL until an Enchanting capture
-- lists the Forever healing and intellect recipes) and upgrade targets.
-- Empty class targets fall back to the provisional shared FullGearCatalog.
local _, ns = ...

local CASTER = {
  [9] = {
    { recipe = 13945, name = "Greater Intellect", stat = "INTELLECT", amount = 7, source = "classic" },
    { recipe = 13822, name = "Intellect", stat = "INTELLECT", amount = 5, source = "classic" },
  },
  [5] = {
    { recipe = 1213616, name = "Living Stats", stat = "ALL_STATS", amount = 4 },
    { recipe = 13700, name = "Lesser Stats", stat = "ALL_STATS", amount = 2 },
  },
  [15] = {
    { recipe = 13419, name = "Minor Agility", stat = "AGILITY", amount = 3 },
  },
  [16] = {
    { recipe = 22750, name = "Healing Power", stat = "HEALING", amount = 55, source = "classic" },
    { recipe = 22749, name = "Spell Power", stat = "SPELL_POWER", amount = 30, source = "classic" },
    { recipe = 23804, name = "Mighty Intellect", stat = "INTELLECT", amount = 22, source = "classic" },
  },
}

ns.Data.PRIEST.Gear = {
  _status = "provisional",
  enchants = CASTER,
  targets = {},
}
