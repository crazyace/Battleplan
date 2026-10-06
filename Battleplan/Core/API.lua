-- The ONLY file that reads game data. Forever runs the Mainline UI with
-- Midnight's restrictions (secret values), so every read goes through here:
-- when the probe shows something works differently, this is the file to fix.
--
-- Confirmed on the beta (Gearwright's findings, client 1.60.1): talents use
-- C_ClassTalents + C_Traits; C_Item / C_Spell / C_TooltipInfo exist; the
-- globals GetItemStats, GetItemInfoInstant and GetSpecialization are gone;
-- issecretvalue exists and nothing read out of combat has been secret.
local _, ns = ...

local API = {}
ns.API = API

-- Secret values -----------------------------------------------------------------
function API.isSecret(v)
  return issecretvalue ~= nil and issecretvalue(v) == true
end

-- v, or nil if the client handed us a secret value.
function API.clean(v)
  if API.isSecret(v) then return nil end
  return v
end

-- Player ---------------------------------------------------------------------------
function API.PlayerClass()
  local _, token = UnitClass("player")
  return API.clean(token)
end

function API.PlayerLevel()
  return API.clean(UnitLevel("player")) or 1
end

-- Optional reads; presence/value captures are added to the probe, still unconfirmed live.
function API.PlayerFaction()
  if ns.InCombat() or not UnitFactionGroup then return nil end
  local ok, value = pcall(UnitFactionGroup, "player")
  value = ok and API.clean(value) or nil
  if value == "Alliance" or value == "Horde" then return value end
end

local questValues, questEpochs, questEpoch = {}, {}, 0
function API.QuestCompleted(id)
  if ns.InCombat() or type(id) ~= "number" or id <= 0 then return nil end
  if questEpochs[id] == questEpoch then return questValues[id] end
  local fn = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
  if not fn then return nil end
  local ok, value = pcall(fn, id)
  if not ok then return nil end
  value = API.clean(value)
  if type(value) ~= "boolean" then return nil end
  questValues[id], questEpochs[id] = value, questEpoch
  return value
end
function API.ForgetQuestStates() questEpoch = questEpoch + 1 end

function API.InInstance()
  if not IsInInstance then return false, nil end
  local inside, kind = IsInInstance()
  return API.clean(inside) == true, API.clean(kind)
end

-- Spellbook --------------------------------------------------------------------------
-- Known spells by name: { [name] = { best = rank, id = bestSpellID, ranks = { [rank] = spellID } } }
-- Read once and cached until a spell event says it changed.
local spellCache

local function rankOf(subName)
  if type(subName) ~= "string" then return 1 end
  return tonumber(subName:match("(%d+)")) or 1
end

local function addSpell(out, name, subName, spellID)
  name, spellID = API.clean(name), API.clean(spellID)
  if type(name) ~= "string" or not spellID then return end
  local rank = rankOf(API.clean(subName))
  local s = out[name]
  if not s then
    s = { best = 0, ranks = {} }
    out[name] = s
  end
  s.ranks[rank] = spellID
  if rank > s.best then
    s.best, s.id = rank, spellID
  end
end

local function readModernBook(out)
  local SB = C_SpellBook
  if not (SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo) then
    return false
  end
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
  local future = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
  for line = 1, SB.GetNumSpellBookSkillLines() or 0 do
    local info = SB.GetSpellBookSkillLineInfo(line)
    if type(info) == "table" and not info.shouldHide then
      local first = (info.itemIndexOffset or 0) + 1
      for i = first, first + (info.numSpellBookItems or 0) - 1 do
        local ok, item = pcall(SB.GetSpellBookItemInfo, i, bank)
        if ok and type(item) == "table" and item.spellID and (future == nil or item.itemType ~= future) then
          addSpell(out, item.name, item.subName, item.spellID)
        end
      end
    end
  end
  return true
end

local function readClassicBook(out)
  if not (GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName and GetSpellBookItemInfo) then return false end
  for tab = 1, GetNumSpellTabs() do
    local _, _, offset, n = GetSpellTabInfo(tab)
    for i = (offset or 0) + 1, (offset or 0) + (n or 0) do
      local name, subName = GetSpellBookItemName(i, "spell")
      local kind, spellID = GetSpellBookItemInfo(i, "spell")
      if kind ~= "FUTURESPELL" then addSpell(out, name, subName, spellID) end
    end
  end
  return true
end

function API.KnownSpells()
  if spellCache then return spellCache end
  local out = {}
  if not readModernBook(out) then readClassicBook(out) end
  spellCache = out
  return out
end

local iconCache = {}

-- Optional iconID from the existing GetSpellInfo read. Check identity before
-- showing an imported talent's icon; missing/secret data stays text-only.
function API.SpellIcon(spellID, expectedName)
  if ns.InCombat() then return nil end
  spellID, expectedName = API.clean(spellID), API.clean(expectedName)
  if type(spellID) ~= "number" or spellID <= 0 or spellID >= math.huge or spellID % 1 ~= 0
    or type(expectedName) ~= "string" then return nil end
  local cached = iconCache[spellID]
  if cached then return cached.name == expectedName and cached.icon or nil end
  if not (C_Spell and C_Spell.GetSpellInfo) then return nil end
  local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
  if not ok or type(info) ~= "table" then return nil end
  local name, icon = API.clean(info.name), API.clean(info.iconID)
  if name ~= expectedName or type(icon) ~= "number" or icon <= 0 or icon >= math.huge or icon % 1 ~= 0 then return nil end
  iconCache[spellID] = { name = name, icon = icon }
  return icon
end

function API.ForgetSpells()
  spellCache = nil
  for id in pairs(iconCache) do iconCache[id] = nil end
end
API.SPELL_EVENTS = { "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_LEVEL_UP", "SPELL_DATA_LOAD_RESULT" }

-- What a heal or ability costs and does, for the healing table:
-- { cost=, power=, castMs=, min=, max=, overSeconds= }  (nil fields when unknown)
function API.SpellDetails(spellID)
  local d = {}
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    if ok and type(info) == "table" then d.castMs = API.clean(info.castTime) end
  end
  local costFn = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
  if costFn then
    local ok, costs = pcall(costFn, spellID)
    if ok and type(costs) == "table" and costs[1] then
      d.cost, d.power = API.clean(costs[1].cost), API.clean(costs[1].type)
    end
  end
  if C_Spell and C_Spell.GetSpellDescription then
    local ok, text = pcall(C_Spell.GetSpellDescription, spellID)
    text = ok and API.clean(text)
    if type(text) == "string" then
      d.min, d.max, d.overSeconds = ns.Engine.Healing.ParseAmount(text)
    end
  end
  return d
end

-- Auras and weapon enchants (read out of combat only) --------------------------------
-- { [auraName] = spellID }
function API.PlayerAuras()
  local out = {}
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    for i = 1, 40 do
      local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
      if not ok or type(a) ~= "table" then break end
      local name = API.clean(a.name)
      if name then out[name] = API.clean(a.spellId) or true end
    end
  elseif UnitBuff then
    for i = 1, 40 do
      local name, _, _, _, _, _, _, _, _, spellID = UnitBuff("player", i)
      name = API.clean(name)
      if not name then break end
      out[name] = API.clean(spellID) or true
    end
  end
  return out
end

-- Whether a main-hand weapon is equipped.
function API.HasMainHand()
  return type(API.clean(GetInventoryItemLink("player", 16))) == "string"
end

-- hasMainHand, hasOffHand temporary enchants (stones, oils, poisons).
function API.WeaponEnchants()
  if not GetWeaponEnchantInfo then return nil, nil end
  local ok, mh, _, _, _, oh = pcall(GetWeaponEnchantInfo)
  if not ok then return nil, nil end
  return API.clean(mh) == true, API.clean(oh) == true
end

-- Items ------------------------------------------------------------------------------
-- The buff a consumable gives, by name: "Well Fed", "Elixir of the Mongoose"...
local itemSpellCache = {}
function API.ItemBuffName(itemID)
  local cached = itemSpellCache[itemID]
  if cached ~= nil then return cached or nil end
  local fn = (C_Item and C_Item.GetItemSpell) or GetItemSpell
  if not fn then return nil end
  local ok, name = pcall(fn, itemID)
  name = ok and API.clean(name) or nil
  if name then itemSpellCache[itemID] = name
  elseif C_Item and C_Item.RequestLoadItemDataByID then
    pcall(C_Item.RequestLoadItemDataByID, itemID)
  end
  return name
end

function API.ItemCount(itemID)
  local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
  if not fn then return 0 end
  local ok, n = pcall(fn, itemID)
  return ok and API.clean(n) or 0
end

-- Equipped enchants: { [slotID] = enchantID (0 = none) } for slots with an item.
API.ENCHANT_SLOTS = { 1, 2, 3, 5, 7, 8, 9, 10, 15, 16, 17 }
function API.EquippedEnchants()
  local out = {}
  for _, slot in ipairs(API.ENCHANT_SLOTS) do
    local link = API.clean(GetInventoryItemLink("player", slot))
    if type(link) == "string" then
      out[slot] = tonumber(link:match("item:%-?%d+:(%-?%d*)")) or 0
    end
  end
  return out
end

-- Raw stat tokens: { [slotID] = { ITEM_MOD_*_SHORT = n } or false (not readable yet) }
-- Second return: item IDs from the same equipped links, for ownership filtering.
API.GEAR_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
function API.EquippedItemStats()
  local out, owned = {}, {}
  local getStats = C_Item and C_Item.GetItemStats
  -- Still mark equipped slots unknown when the stats API is unavailable.
  for _, slot in ipairs(API.GEAR_SLOTS) do
    local link = GetInventoryItemLink("player", slot)
    if API.isSecret(link) or link ~= nil and type(link) ~= "string" then
      out[slot] = false
    elseif type(link) == "string" then
      link = API.clean(link)
      local itemID = tonumber(link:match("item:(%d+)"))
      if itemID then owned[itemID] = true end
      local ok, stats
      if getStats then ok, stats = pcall(getStats, link) end
      local clean, readable = {}, ok and type(stats) == "table"
      if readable then
        for token, v in pairs(stats) do
          v = API.clean(v)
          if v == nil then readable = false else clean[token] = v end
        end
      end
      if readable then out[slot] = clean
      else
        out[slot] = false -- unknown, not an empty item with zero stats
        local id = tonumber(link:match("item:(%d+)"))
        if id and C_Item and C_Item.RequestLoadItemDataByID then
          pcall(C_Item.RequestLoadItemDataByID, id)
        end
      end
    end
  end
  return out, owned
end

-- Talents ---------------------------------------------------------------------------------
-- { source = "traits"|"classic", tabs = { { points=, talents = { [name] = rank } } } }
-- or nil, reason. Reading the tree is ~160 calls, so it's cached until a
-- talent event fires.

local function spellName(spellID)
  if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
  return GetSpellInfo and (GetSpellInfo(spellID))
end

local function nodeName(configID, info)
  local entryID = (info.activeEntry and info.activeEntry.entryID) or (info.entryIDs and info.entryIDs[1])
  local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
  local def = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
  if not def then return nil end
  return API.clean(def.overrideName) or (def.spellID and API.clean(spellName(def.spellID)))
end

-- For a class whose spec group IDs aren't in Data yet: the biggest groups
-- that don't overlap, numbered left to right (how the Rogue and Priest trees
-- are laid out). Same method as Gearwright.
local function inferTabGroups(configID, treeIDs)
  local nodes, size = {}, {}
  for _, treeID in ipairs(treeIDs) do
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
      local info = C_Traits.GetNodeInfo(configID, nodeID)
      if info and info.groupIDs and #info.groupIDs > 0 then
        nodes[#nodes + 1] = info
        for _, g in ipairs(info.groupIDs) do size[g] = (size[g] or 0) + 1 end
      end
    end
  end
  local groups = {}
  for g in pairs(size) do groups[#groups + 1] = g end
  table.sort(groups, function(a, b)
    if size[a] ~= size[b] then return size[a] > size[b] end
    return a < b
  end)
  local taken, picked = {}, {}
  for _, g in ipairs(groups) do
    local members, clash = {}, false
    for i, info in ipairs(nodes) do
      for _, ng in ipairs(info.groupIDs) do
        if ng == g then
          if taken[i] then clash = true end
          members[#members + 1] = i
        end
      end
    end
    if not clash then
      local x = 0
      for _, i in ipairs(members) do taken[i] = true; x = x + (nodes[i].posX or 0) end
      picked[#picked + 1] = { group = g, x = x / #members }
    end
  end
  if #picked < 2 then return nil end
  table.sort(picked, function(a, b) return a.x < b.x end)
  local map = {}
  for tab, p in ipairs(picked) do map[p.group] = tab end
  return map
end

local function readTraits(tabGroups)
  local configID = API.clean(C_ClassTalents.GetActiveConfigID())
  if not configID then return nil, "no-talent-config" end
  local config = C_Traits.GetConfigInfo(configID)
  local treeIDs = config and API.clean(config.treeIDs)
  if type(treeIDs) ~= "table" then return nil, "no-talent-config" end
  tabGroups = tabGroups or inferTabGroups(configID, treeIDs)
  if not tabGroups then return nil, "no-trait-tab-map" end
  local result = { source = "traits", tabs = {} }
  for _, tab in pairs(tabGroups) do
    for i = #result.tabs + 1, tab do result.tabs[i] = { points = 0, talents = {} } end
  end
  for _, treeID in ipairs(treeIDs) do
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
      local info = C_Traits.GetNodeInfo(configID, nodeID)
      local tab
      for _, g in ipairs(info and info.groupIDs or {}) do tab = tab or tabGroups[g] end
      local name = tab and nodeName(configID, info)
      if name then
        local rank = API.clean(info.activeRank) or API.clean(info.ranksPurchased) or 0
        local entry = result.tabs[tab]
        -- The Priest tree has a duplicate "Holy Specialization" node: keep the higher rank.
        if rank > (entry.talents[name] or -1) then
          entry.points = entry.points - (entry.talents[name] or 0) + rank
          entry.talents[name] = rank
        end
      end
    end
  end
  return result
end

local function readClassic()
  local result = { source = "classic", tabs = {} }
  for tab = 1, GetNumTalentTabs() do
    local entry = { points = 0, talents = {} }
    for i = 1, (GetNumTalents(tab) or 0) do
      local name, _, _, _, rank = GetTalentInfo(tab, i)
      name, rank = API.clean(name), API.clean(rank) or 0
      if name then
        entry.talents[name] = rank
        entry.points = entry.points + rank
      end
    end
    result.tabs[tab] = entry
  end
  return result
end

API.TALENT_EVENTS = { "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED" }
local talentCache

function API.ReadTalents(tabGroups)
  if talentCache then return talentCache.result, talentCache.reason end
  local result, reason
  if C_ClassTalents and C_Traits then
    local ok, r, why = pcall(readTraits, tabGroups)
    if ok then result, reason = r, why else reason = "traits-error"; ns.util.debug("talent read: %s", tostring(r)) end
  elseif GetNumTalentTabs and GetTalentInfo then
    result = readClassic()
  else
    reason = "no-talent-api"
  end
  talentCache = { result = result, reason = reason }
  return result, reason
end

function API.ForgetTalents() talentCache = nil end
