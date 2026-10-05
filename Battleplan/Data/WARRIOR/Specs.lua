-- Warrior: the first tank class. The talent tree hasn't been captured yet, so
-- the spec group IDs are unknown: Battleplan works them out from the tree's
-- layout (Core/API.lua inferTabGroups) until a capture fills them in.
local _, ns = ...
ns.Data.WARRIOR = ns.Data.WARRIOR or {}

ns.Data.WARRIOR.Specs = {
  _status = "todo", -- needs /gwp talents on a Warrior with points in each tree
  order = { "arms", "fury", "protection" },
  names = { arms = "Arms", fury = "Fury", protection = "Protection" },
  roles = { arms = "dps", fury = "dps", protection = "tank" },
  traitTabGroups = nil,
  leveling = "arms",
  usesMana = false,
  weaponKind = "edged",
}
