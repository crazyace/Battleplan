-- Warrior spec groups confirmed by the native talent capture on 2026-10-05.
-- One trait tree (1117) contains all three specs: Arms, Fury, Protection.
local _, ns = ...
ns.Data.WARRIOR = ns.Data.WARRIOR or {}

ns.Data.WARRIOR.Specs = {
  _status = "verified", -- data/probe/2026-10-05-warrior-12-talents.json, client 1.60.1.70205
  order = { "arms", "fury", "protection" },
  names = { arms = "Arms", fury = "Fury", protection = "Protection" },
  roles = { arms = "dps", fury = "dps", protection = "tank" },
  traitTabGroups = { [11650] = 1, [11657] = 2, [11670] = 3 },
  leveling = "arms",
  usesMana = false,
  weaponKind = "edged",
}
