local _, ns = ...
ns.Data.PRIEST = ns.Data.PRIEST or {}

ns.Data.PRIEST.Specs = {
  _status = "verified", -- spec group IDs from the beta talent tree (level 12 Gnome, 2026-10-04)
  order = { "discipline", "holy", "shadow" },
  names = { discipline = "Discipline", holy = "Holy", shadow = "Shadow" },
  roles = { discipline = "healer", holy = "healer", shadow = "dps" },
  -- One tree (treeID 1114) holds all three specs.
  traitTabGroups = { [11608] = 1, [11615] = 2, [11622] = 3 },
  leveling = "shadow",
  usesMana = true,
  weaponKind = "any", -- oils, not stones
}
