local _, ns = ...
ns.Data.ROGUE = ns.Data.ROGUE or {}

ns.Data.ROGUE.Specs = {
  _status = "verified", -- spec group IDs from the beta talent tree (client 1.60.1)
  order = { "assassination", "combat", "subtlety" }, -- tab 1, 2, 3
  names = { assassination = "Assassination", combat = "Combat", subtlety = "Subtlety" },
  roles = { assassination = "dps", combat = "dps", subtlety = "dps" },
  -- C_Traits group ID -> tab. One tree (treeID 1111) holds all three specs.
  traitTabGroups = { [11580] = 1, [11573] = 2, [11572] = 3 },
  -- Advised before the first talent point (level 10): any weapon in either hand.
  leveling = "combat",
  usesMana = false,
  weaponKind = "edged", -- daggers and swords; maces switch this to blunt in a later version
}
