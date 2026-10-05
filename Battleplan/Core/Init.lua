-- Battleplan: out-of-combat build planner for World of Warcraft: Forever.
-- Every file shares this namespace through `local _, ns = ...`.
local ADDON, ns = ...

ns.name = ADDON
ns.Data = ns.Data or {}
ns.Engine = ns.Engine or {}
ns.UI = ns.UI or {}

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = getMeta and getMeta(ADDON, "Version") or "dev"

ns.SITUATIONS = { "leveling", "solo", "dungeon", "raid" }
ns.MAX_LEVEL = 60

local DEFAULTS = {
  situation = "auto",   -- auto = leveling below max level, dungeon at max level
  spec = "auto",
  buffCheck = true,     -- name missing consumables when you enter a dungeon or raid
  debug = false,
  debugPerf = false,
  window = {},
}

-- Fills missing settings without touching the ones the player changed.
function ns:InitDB()
  BattleplanDB = type(BattleplanDB) == "table" and BattleplanDB or {}
  for k, v in pairs(DEFAULTS) do
    if BattleplanDB[k] == nil then
      if type(v) == "table" then
        local copy = {}
        for kk, vv in pairs(v) do copy[kk] = vv end
        BattleplanDB[k] = copy
      else
        BattleplanDB[k] = v
      end
    end
  end
  ns.db = BattleplanDB
end

function ns:ResetDB()
  BattleplanDB = nil
  ns:InitDB()
end
