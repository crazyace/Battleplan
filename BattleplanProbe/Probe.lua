-- BattleplanProbe: measures what Battleplan's theorycrafting needs from the
-- Forever client. Dev tool, never shipped to players.
--
--   /bpp stats [label]   stat lab snapshot (label it with what you changed,
--                        e.g. "/bpp stats +10 agility")
--   /bpp stats diff      what changed between the last two snapshots
--   /bpp stats list      the snapshots taken so far
--   /bpp stats clear     forget all stat lab snapshots
--   /bpp spells          every spell and rank you know: ID, cost, cast time, text
--   /bpp talents         trait nodes, entries, definitions and prerequisite metadata
--   /bpp auras           your buffs and weapon enchants, right now
--   /bpp items <ids>     what consumables do (item spell + tooltip), by item ID
--   /bpp threat          is threat readable (have a target, out of combat)
--   /bpp perf [seconds]  frame times for a while (default 30 s)
--   /bpp all             env + spells + talents + auras + stats
--   /bpp export          copyable JSON of everything recorded
--
-- Everything lands in BattleplanProbeDB (SavedVariables persist on the Forever
-- beta: confirmed by GearwrightProbe on 2026-10-03), and /bpp export shows it
-- in a copyable window.
local P = {}
local PREFIX = "|cff66ccffBattleplanProbe|r: "
local function say(s, ...) print(PREFIX .. (select("#", ...) > 0 and s:format(...) or s)) end
local function now() return date("%Y-%m-%d %H:%M:%S") end
local function pack(...) return { n = select("#", ...), ... } end

-- Values -------------------------------------------------------------------------
local function isSecret(v) return issecretvalue ~= nil and issecretvalue(v) == true end

local function sanitize(v, depth)
  depth = depth or 0
  if isSecret(v) then return "<secret>" end
  local t = type(v)
  if t == "nil" then return "<nil>" end
  if t == "string" or t == "number" or t == "boolean" then return v end
  if t == "table" then
    if depth >= 3 then return "<table>" end
    local out = {}
    for k, val in pairs(v) do
      local key = (type(k) == "string" or type(k) == "number") and k or tostring(k)
      out[key] = sanitize(val, depth + 1)
    end
    return out
  end
  return "<" .. t .. ">"
end

local function resolve(path)
  local cur = _G
  for part in path:gmatch("[^%.]+") do
    if type(cur) ~= "table" then return nil end
    cur = cur[part]
  end
  return cur
end

-- Call a function by path: { status = ok|secret|missing|error, values = {...} }
local function capture(path, ...)
  local fn = resolve(path)
  if type(fn) ~= "function" then return { status = "missing" } end
  local res = pack(pcall(fn, ...))
  if not res[1] then return { status = "error", error = tostring(res[2]) } end
  local values, secret = {}, false
  for i = 2, res.n do
    if isSecret(res[i]) then secret = true end
    values[i - 1] = sanitize(res[i])
  end
  return { status = secret and "secret" or "ok", values = values }
end

-- Storage ---------------------------------------------------------------------------
local function db()
  BattleplanProbeDB = BattleplanProbeDB or {}
  local d = BattleplanProbeDB
  d.version = 1
  d.statlab = d.statlab or {}
  d.captures = d.captures or {}
  d.perf = d.perf or {}
  return d
end

local function who()
  local name, realm = UnitFullName("player")
  local _, class = UnitClass("player")
  local _, race = UnitRace("player")
  return {
    character = tostring(sanitize(name)) .. "-" .. tostring(sanitize(realm)),
    class = class, race = race, level = sanitize(UnitLevel("player")),
  }
end

-- A capture: { at, who, kind, data }, newest last, kept per kind.
local function record(kind, data)
  local c = { at = now(), who = who(), data = data }
  local d = db()
  d.captures[kind] = d.captures[kind] or {}
  table.insert(d.captures[kind], c)
  return c
end

-- Environment ----------------------------------------------------------------------------
local API_PATHS = {
  "C_TooltipInfo.GetTraitEntry", "C_Spell.RequestLoadSpellData",
  "C_ClassTalents.GetActiveConfigID", "C_Traits.GetConfigInfo", "C_Traits.GetTreeNodes",
  "C_Traits.GetNodeInfo", "C_Traits.GetEntryInfo", "C_Traits.GetDefinitionInfo", "C_Traits.GetConditionInfo",
  "issecretvalue", "canaccessvalue", "InCombatLockdown",
  "C_SpellBook.GetNumSpellBookSkillLines", "C_SpellBook.GetSpellBookSkillLineInfo",
  "C_SpellBook.GetSpellBookItemInfo", "C_SpellBook.IsSpellKnown",
  "GetNumSpellTabs", "GetSpellTabInfo", "GetSpellBookItemName", "GetSpellBookItemInfo",
  "IsPlayerSpell", "IsSpellKnown",
  "C_Spell.GetSpellInfo", "C_Spell.GetSpellName", "C_Spell.GetSpellPowerCost",
  "C_Spell.GetSpellDescription", "C_Spell.GetSpellCooldown", "GetSpellPowerCost",
  "C_UnitAuras.GetAuraDataByIndex", "UnitBuff", "GetWeaponEnchantInfo",
  "C_Item.GetItemSpell", "GetItemSpell", "C_Item.GetItemCount", "C_TooltipInfo.GetItemByID",
  "C_Item.RequestLoadItemDataByID",
  "UnitDetailedThreatSituation", "UnitThreatSituation",
  "C_AddOnProfiler.GetAddOnMetric", "C_AddOnProfiler.GetOverallMetric", "GetFramerate",
  "debugprofilestop", "IsInInstance", "GetInstanceInfo", "UnitDefense", "UnitDefenseSkill",
}

function P.env()
  local apis = {}
  for _, path in ipairs(API_PATHS) do
    apis[path] = type(resolve(path)) == "function" and "present" or "missing"
  end
  local build = capture("GetBuildInfo")
  record("env", {
    build = build.values, project = sanitize(rawget(_G, "WOW_PROJECT_ID")),
    locale = sanitize(GetLocale and GetLocale()), apis = apis,
  })
  local missing = 0
  for _, v in pairs(apis) do if v == "missing" then missing = missing + 1 end end
  say("env: interface %s, %d of %d APIs missing", tostring(build.values and build.values[4]), missing, #API_PATHS)
end

-- Stat lab ---------------------------------------------------------------------------------
-- Each entry: { name, function path, args, which return value }.
local LAB = {
  { "strength", "UnitStat", { "player", 1 }, 2 }, { "agility", "UnitStat", { "player", 2 }, 2 },
  { "stamina", "UnitStat", { "player", 3 }, 2 }, { "intellect", "UnitStat", { "player", 4 }, 2 },
  { "spirit", "UnitStat", { "player", 5 }, 2 },
  { "armor", "UnitArmor", { "player" }, 2 },
  { "health_max", "UnitHealthMax", { "player" }, 1 }, { "power_max", "UnitPowerMax", { "player" }, 1 },
  { "ap_base", "UnitAttackPower", { "player" }, 1 }, { "ap_bonus", "UnitAttackPower", { "player" }, 2 },
  { "ap_malus", "UnitAttackPower", { "player" }, 3 },
  { "rap_base", "UnitRangedAttackPower", { "player" }, 1 }, { "rap_bonus", "UnitRangedAttackPower", { "player" }, 2 },
  { "crit_melee", "GetCritChance", {}, 1 }, { "crit_ranged", "GetRangedCritChance", {}, 1 },
  { "crit_spell", "GetSpellCritChance", { 2 }, 1 },
  { "hit_melee", "GetHitModifier", {}, 1 }, { "hit_spell", "GetSpellHitModifier", {}, 1 },
  { "expertise", "GetExpertise", {}, 1 },
  { "haste", "GetHaste", {}, 1 }, { "haste_melee", "GetMeleeHaste", {}, 1 },
  { "haste_spell", "UnitSpellHaste", { "player" }, 1 },
  { "dodge", "GetDodgeChance", {}, 1 }, { "parry", "GetParryChance", {}, 1 },
  { "block", "GetBlockChance", {}, 1 }, { "block_value", "GetShieldBlock", {}, 1 },
  -- UnitDefense is gone on Forever; the character sheet reads UnitDefenseSkill -> base, modifier
  -- (Blizzard UI source, Camelot/PaperDollFrameStats.lua).
  { "defense_base", "UnitDefenseSkill", { "player" }, 1 }, { "defense_bonus", "UnitDefenseSkill", { "player" }, 2 },
  { "spell_damage_holy", "GetSpellBonusDamage", { 2 }, 1 },
  { "spell_damage_fire", "GetSpellBonusDamage", { 3 }, 1 },
  { "spell_damage_nature", "GetSpellBonusDamage", { 4 }, 1 },
  { "spell_damage_frost", "GetSpellBonusDamage", { 5 }, 1 },
  { "spell_damage_shadow", "GetSpellBonusDamage", { 6 }, 1 },
  { "spell_damage_arcane", "GetSpellBonusDamage", { 7 }, 1 },
  { "healing", "GetSpellBonusHealing", {}, 1 },
  { "mana_regen", "GetManaRegen", {}, 1 }, { "mana_regen_casting", "GetManaRegen", {}, 2 },
  { "power_regen", "GetPowerRegen", {}, 1 }, { "power_regen_casting", "GetPowerRegen", {}, 2 },
  { "mh_min", "UnitDamage", { "player" }, 1 }, { "mh_max", "UnitDamage", { "player" }, 2 },
  { "oh_min", "UnitDamage", { "player" }, 3 }, { "oh_max", "UnitDamage", { "player" }, 4 },
  { "mh_speed", "UnitAttackSpeed", { "player" }, 1 }, { "oh_speed", "UnitAttackSpeed", { "player" }, 2 },
  { "ranged_speed", "UnitRangedDamage", { "player" }, 1 },
  { "res_holy", "UnitResistance", { "player", 1 }, 2 }, { "res_fire", "UnitResistance", { "player", 2 }, 2 },
  { "res_nature", "UnitResistance", { "player", 3 }, 2 }, { "res_frost", "UnitResistance", { "player", 4 }, 2 },
  { "res_shadow", "UnitResistance", { "player", 5 }, 2 }, { "res_arcane", "UnitResistance", { "player", 6 }, 2 },
}

local function ratingNames()
  local out = {}
  for name, id in pairs(_G) do
    if type(name) == "string" and name:find("^CR_") and type(id) == "number" then out[#out + 1] = name end
  end
  table.sort(out)
  return out
end

-- Numbers only, keyed by friendly name; what isn't a number is listed apart.
local function readStats()
  local values, odd = {}, {}
  for _, e in ipairs(LAB) do
    local r = capture(e[2], unpack(e[3]))
    local v = r.values and r.values[e[4]]
    if r.status == "ok" and type(v) == "number" then
      values[e[1]] = v
    else
      odd[e[1]] = r.status == "ok" and tostring(v) or r.status
    end
  end
  for _, c in ipairs(ratingNames()) do
    local rating = capture("GetCombatRating", _G[c])
    local bonus = capture("GetCombatRatingBonus", _G[c])
    local rv, bv = rating.values and rating.values[1], bonus.values and bonus.values[1]
    if type(rv) == "number" and rv ~= 0 then values["rating_" .. c] = rv end
    if type(bv) == "number" and bv ~= 0 then values["rating_bonus_" .. c] = bv end
  end
  return values, odd
end

local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

local function gearLinks()
  local out = {}
  for _, slot in ipairs(SLOTS) do
    local link = GetInventoryItemLink("player", slot)
    if link and not isSecret(link) then out[tostring(slot)] = link end
  end
  return out
end

local function auraList()
  local out = {}
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    for i = 1, 40 do
      local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
      if not ok or type(a) ~= "table" then break end
      out[#out + 1] = { name = sanitize(a.name), spellId = sanitize(a.spellId), duration = sanitize(a.duration),
                        source = sanitize(a.sourceUnit), points = sanitize(a.points) }
    end
  elseif UnitBuff then
    for i = 1, 40 do
      local name, _, _, _, duration, _, source, _, _, spellId = UnitBuff("player", i)
      if not name then break end
      out[#out + 1] = { name = sanitize(name), spellId = sanitize(spellId), duration = sanitize(duration),
                        source = sanitize(source) }
    end
  end
  return out
end

local function weaponEnchants()
  local r = capture("GetWeaponEnchantInfo")
  local v = r.values or {}
  return { status = r.status, mainHand = v[1], mainHandMs = v[2], mainHandCharges = v[3], mainHandID = v[4],
           offHand = v[5], offHandMs = v[6], offHandCharges = v[7], offHandID = v[8] }
end

function P.stats(arg)
  arg = arg or ""
  local d = db()
  if arg == "diff" then return P.statsDiff() end
  if arg == "list" then
    for i, s in ipairs(d.statlab) do
      say("%d. %s  level %s  %s", i, s.at, tostring(s.who.level), s.label ~= "" and s.label or "(no label)")
    end
    if #d.statlab == 0 then say("no stat lab snapshots yet: /bpp stats") end
    return
  end
  if arg == "clear" then
    d.statlab = {}
    return say("stat lab cleared")
  end
  if InCombatLockdown() then return say("leave combat first: stats change in combat") end
  local values, odd = readStats()
  local snap = {
    at = now(), who = who(), label = arg, values = values, unreadable = odd,
    gear = gearLinks(), auras = auraList(), weapon = weaponEnchants(),
  }
  table.insert(d.statlab, snap)
  local n = 0
  for _ in pairs(values) do n = n + 1 end
  say("stat lab #%d%s: %d values", #d.statlab, arg ~= "" and (" [" .. arg .. "]") or "", n)
  if #d.statlab > 1 then P.statsDiff(true) end
end

function P.statsDiff(quiet)
  local list = db().statlab
  if #list < 2 then return say("need two snapshots: /bpp stats, change one thing, /bpp stats <what you changed>") end
  local a, b = list[#list - 1], list[#list]
  local keys = {}
  for k in pairs(b.values) do keys[#keys + 1] = k end
  for k in pairs(a.values) do if b.values[k] == nil then keys[#keys + 1] = k end end
  table.sort(keys)
  local changed = 0
  for _, k in ipairs(keys) do
    local x, y = a.values[k], b.values[k]
    if x ~= y and not (x and y and math.abs(x - y) < 1e-6) then
      changed = changed + 1
      say("  %s: %s -> %s%s", k, tostring(x), tostring(y),
        (x and y) and (" (%+.4g)"):format(y - x) or "")
    end
  end
  if changed == 0 then say("  nothing changed between #%d and #%d", #list - 1, #list)
  elseif not quiet then say("%d values changed between #%d and #%d", changed, #list - 1, #list) end
  local gearChanged = {}
  for slot, link in pairs(b.gear) do if a.gear[slot] ~= link then gearChanged[#gearChanged + 1] = slot end end
  for slot in pairs(a.gear) do if not b.gear[slot] then gearChanged[#gearChanged + 1] = slot end end
  if #gearChanged > 0 then
    table.sort(gearChanged)
    say("  gear changed in slot(s) %s", table.concat(gearChanged, ", "))
  end
end

-- Spellbook ----------------------------------------------------------------------------------
local function spellDetails(spellID)
  local d = { spellID = spellID }
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
    if ok and type(info) == "table" then
      d.name, d.castTime, d.minRange, d.maxRange = sanitize(info.name), sanitize(info.castTime),
        sanitize(info.minRange), sanitize(info.maxRange)
    end
  end
  local costFn = (C_Spell and C_Spell.GetSpellPowerCost) or GetSpellPowerCost
  if costFn then
    local ok, costs = pcall(costFn, spellID)
    if ok and type(costs) == "table" then
      d.costs = {}
      for _, c in ipairs(costs) do
        d.costs[#d.costs + 1] = { type = sanitize(c.type), name = sanitize(c.name), cost = sanitize(c.cost),
                                  costPercent = sanitize(c.costPercent) }
      end
    end
  end
  if C_Spell and C_Spell.GetSpellDescription then
    local ok, text = pcall(C_Spell.GetSpellDescription, spellID)
    if ok then d.description = sanitize(text) end
  end
  if C_Spell and C_Spell.GetSpellCooldown then
    local ok, cd = pcall(C_Spell.GetSpellCooldown, spellID)
    if ok and type(cd) == "table" then d.cooldownDuration = sanitize(cd.duration) end
  end
  return d
end

local function readBook()
  local out, how = {}, nil
  local SB = C_SpellBook
  if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo then
    how = "C_SpellBook"
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    for line = 1, SB.GetNumSpellBookSkillLines() do
      local info = SB.GetSpellBookSkillLineInfo(line)
      if type(info) == "table" then
        local first = (info.itemIndexOffset or 0) + 1
        for i = first, first + (info.numSpellBookItems or 0) - 1 do
          local ok, item = pcall(SB.GetSpellBookItemInfo, i, bank)
          if ok and type(item) == "table" and item.spellID then
            local d = spellDetails(item.spellID)
            d.tab, d.bookName, d.subName = sanitize(info.name), sanitize(item.name), sanitize(item.subName)
            d.itemType, d.isPassive, d.isOffSpec = sanitize(item.itemType), sanitize(item.isPassive), sanitize(item.isOffSpec)
            out[#out + 1] = d
          end
        end
      end
    end
  elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
    how = "classic"
    for tab = 1, GetNumSpellTabs() do
      local tabName, _, offset, n = GetSpellTabInfo(tab)
      for i = offset + 1, offset + n do
        local name, subName = GetSpellBookItemName(i, "spell")
        local kind, spellID = GetSpellBookItemInfo(i, "spell")
        if spellID then
          local d = spellDetails(spellID)
          d.tab, d.bookName, d.subName, d.itemType = sanitize(tabName), sanitize(name), sanitize(subName), sanitize(kind)
          out[#out + 1] = d
        end
      end
    end
  end
  return out, how
end

function P.spells()
  local list, how = readBook()
  if not how then return say("no spellbook API found") end
  record("spells", { how = how, spells = list })
  local ranked, withCost = 0, 0
  for _, s in ipairs(list) do
    if type(s.subName) == "string" and s.subName:find("%d") then ranked = ranked + 1 end
    if s.costs and #s.costs > 0 then withCost = withCost + 1 end
  end
  say("spellbook (%s): %d entries, %d with a rank in the name, %d with a cost", how, #list, ranked, withCost)
end

-- Talents: raw API results retain unknown gates and prerequisite fields. -------------------------
-- Capture each record separately so sanitize's depth limit does not flatten the whole tree.
-- This is a manual developer command, never an event handler or a production dependency.
local talentRun
local function firstValue(result)
  return result.status == "ok" and result.values and result.values[1] or nil
end
local function readableID(id) return type(id) == "number" and id > 0 and id % 1 == 0 end

local function finishTalents(run, reason)
  run.data.complete = reason == nil and run.data.failures == 0
  run.data.reason = reason or (run.data.failures > 0 and "unreadable-records" or nil)
  run.data.tooltipReadsComplete = reason == nil and run.data.tooltipFailures == 0
    and run.data.tooltipReads == run.data.tooltipExpected and run.data.tooltipExpected > 0
  talentRun = nil
  record("talents", run.data)
  say("talents: %d nodes, %d unreadable records (%s); /bpp export",
    #run.data.nodes, run.data.failures, run.data.complete and "complete" or "incomplete")
  say("talent tooltips: %d/%d rank reads, %d without readable text (%s)",
    run.data.tooltipReads, run.data.tooltipExpected, run.data.tooltipFailures,
    run.data.tooltipReadsComplete and "complete" or "incomplete")
end

local function unreadableField(value)
  if value == "<secret>" or value == "<table>" then return true end
  if type(value) == "table" then
    for _, field in pairs(value) do if unreadableField(field) then return true end end
  end
  return false
end

local function traitRead(run, path, ...)
  local result = capture(path, ...)
  local value = firstValue(result)
  if result.status ~= "ok" or value == nil or value == "<nil>" or unreadableField(value)
    or (path ~= "C_ClassTalents.GetActiveConfigID" and type(value) ~= "table") then
    run.data.failures = run.data.failures + 1
  end
  return result
end

-- The Forever talent UI uses GetTraitEntry(entryID, rank), not generic spell text.
-- Keep rank-specific lines apart; missing tooltip text never becomes a zero effect.
local function readTalentTooltip(entryID, rank)
  local result = capture("C_TooltipInfo.GetTraitEntry", entryID, rank)
  local out = { rank = rank, status = result.status, error = result.error, lines = {} }
  local tooltip = firstValue(result)
  if result.status == "ok" then
    if type(tooltip) ~= "table" or type(tooltip.lines) ~= "table" then
      out.status = "empty"
    else
      for _, line in ipairs(tooltip.lines) do
        if type(line) == "table" then
          local left, right = line.leftText, line.rightText
          if left == "<secret>" or right == "<secret>" then out.status = "secret" end
          local readableLeft = type(left) == "string" and left ~= "" and left ~= "<nil>" and left ~= "<secret>" and left ~= "<table>"
          local readableRight = type(right) == "string" and right ~= "" and right ~= "<nil>" and right ~= "<secret>" and right ~= "<table>"
          if readableLeft or readableRight then
            out.lines[#out.lines + 1] = { leftText = left, rightText = right, type = line.type }
          end
        end
      end
      if #out.lines == 0 and out.status == "ok" then out.status = "empty" end
    end
  end
  return out
end

local talentBatch
local function queueTalentBatch() C_Timer.After(0, talentBatch) end

talentBatch = function()
  local run = talentRun
  if not run then return end
  if InCombatLockdown() then return finishTalents(run, "combat-interrupted") end
  local active = firstValue(capture("C_ClassTalents.GetActiveConfigID"))
  if active ~= run.data.configID then return finishTalents(run, "config-changed") end
  if run.readingTooltips then
    for _ = 1, 4 do
      local request = run.tooltipPending[run.tooltipIndex]
      if not request then return finishTalents(run) end
      run.tooltipIndex = run.tooltipIndex + 1
      local tooltip = readTalentTooltip(request.entry.entryID, request.rank)
      request.entry.tooltips[#request.entry.tooltips + 1] = tooltip
      run.data.tooltipReads = run.data.tooltipReads + 1
      if tooltip.status ~= "ok" then run.data.tooltipFailures = run.data.tooltipFailures + 1 end
    end
    queueTalentBatch()
    return
  end
  for _ = 1, 4 do
    local pending = run.pending[run.index]
    if not pending then
      run.readingTooltips = true
      queueTalentBatch()
      return
    end
    run.index = run.index + 1
    local node = { nodeID = pending.nodeID, treeID = pending.treeID, entries = {}, conditions = {} }
    node.info = traitRead(run, "C_Traits.GetNodeInfo", run.data.configID, node.nodeID)
    local info = firstValue(node.info)
    if type(info) == "table" then
      for _, entryID in ipairs(type(info.entryIDs) == "table" and info.entryIDs or {}) do
        if readableID(entryID) then
          local entry = { entryID = entryID, tooltips = {} }
          entry.info = traitRead(run, "C_Traits.GetEntryInfo", run.data.configID, entryID)
          local value = firstValue(entry.info)
          if type(value) == "table" and readableID(value.definitionID) then
            entry.definition = traitRead(run, "C_Traits.GetDefinitionInfo", value.definitionID)
            local def = firstValue(entry.definition)
            if type(def) == "table" and readableID(def.spellID) then
              if C_Spell and C_Spell.RequestLoadSpellData then
                entry.spellLoad = capture("C_Spell.RequestLoadSpellData", def.spellID)
              end
              entry.spell = spellDetails(def.spellID)
              entry.spell.name = entry.spell.name or firstValue(capture("C_Spell.GetSpellName", def.spellID))
            end
          else run.data.failures = run.data.failures + 1 end
          local maxRank = type(value) == "table" and value.maxRanks or info.maxRanks
          if readableID(maxRank) and maxRank <= 100 then
            for rank = 1, maxRank do
              run.tooltipPending[#run.tooltipPending + 1] = { entry = entry, rank = rank }
              run.data.tooltipExpected = run.data.tooltipExpected + 1
            end
          else
            entry.tooltips[1] = { status = "invalid-rank-count", lines = {} }
            run.data.tooltipFailures = run.data.tooltipFailures + 1
          end
          node.entries[#node.entries + 1] = entry
        else run.data.failures = run.data.failures + 1 end
      end
      for _, conditionID in ipairs(type(info.conditionIDs) == "table" and info.conditionIDs or {}) do
        if readableID(conditionID) then
          node.conditions[#node.conditions + 1] = {
            conditionID = conditionID,
            info = traitRead(run, "C_Traits.GetConditionInfo", run.data.configID, conditionID),
          }
        else run.data.failures = run.data.failures + 1 end
      end
    end
    run.data.nodes[#run.data.nodes + 1] = node
  end
  queueTalentBatch()
end

function P.talents()
  if InCombatLockdown() then return say("leave combat first: /bpp talents") end
  if talentRun then return say("talent capture already running") end
  local run = {
    data = { how = "C_Traits", trees = {}, nodes = {}, failures = 0,
      tooltipExpected = 0, tooltipReads = 0, tooltipFailures = 0 },
    pending = {}, index = 1, tooltipPending = {}, tooltipIndex = 1,
  }
  run.data.activeConfig = traitRead(run, "C_ClassTalents.GetActiveConfigID")
  local configID = firstValue(run.data.activeConfig)
  if not readableID(configID) then return finishTalents(run, "no-talent-config") end
  run.data.configID = configID
  run.data.config = traitRead(run, "C_Traits.GetConfigInfo", configID)
  local config = firstValue(run.data.config)
  if type(config) ~= "table" or type(config.treeIDs) ~= "table" then
    return finishTalents(run, "no-talent-trees")
  end
  for _, treeID in ipairs(config.treeIDs) do
    if readableID(treeID) then
      local tree = { treeID = treeID, info = traitRead(run, "C_Traits.GetTreeNodes", treeID) }
      run.data.trees[#run.data.trees + 1] = tree
      local ids = firstValue(tree.info)
      if type(ids) == "table" then
        for _, nodeID in ipairs(ids) do
          if readableID(nodeID) then run.pending[#run.pending + 1] = { treeID = treeID, nodeID = nodeID }
          else run.data.failures = run.data.failures + 1 end
        end
      else run.data.failures = run.data.failures + 1 end
    else run.data.failures = run.data.failures + 1 end
  end
  if #run.pending == 0 then return finishTalents(run, "no-talent-nodes") end
  run.data.build = capture("GetBuildInfo")
  talentRun = run
  say("capturing %d talent nodes in batches; stay out of combat", #run.pending)
  queueTalentBatch()
end

-- Auras ----------------------------------------------------------------------------------------
function P.auras()
  local list = auraList()
  local weapon = weaponEnchants()
  record("auras", { auras = list, weapon = weapon })
  local names = {}
  for _, a in ipairs(list) do names[#names + 1] = ("%s (%s)"):format(tostring(a.name), tostring(a.spellId)) end
  say("buffs: %s", #names > 0 and table.concat(names, ", ") or "none")
  say("weapon: main hand %s, off hand %s", tostring(weapon.mainHand), tostring(weapon.offHand))
end

-- Consumables by item ID -----------------------------------------------------------------------
local function readItem(id)
  local r = { itemID = id }
  local spellFn = (C_Item and C_Item.GetItemSpell) or GetItemSpell
  if spellFn then
    local ok, name, spellID = pcall(spellFn, id)
    if ok then r.spellName, r.spellID = sanitize(name), sanitize(spellID) end
  end
  if C_Item and C_Item.GetItemInfo then
    local ok, name, _, _, _, reqLevel = pcall(C_Item.GetItemInfo, id)
    if ok then r.name, r.requiredLevel = sanitize(name), sanitize(reqLevel) end
  end
  if C_TooltipInfo and C_TooltipInfo.GetItemByID then
    local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
    if ok and type(data) == "table" and type(data.lines) == "table" then
      r.tooltip = {}
      for _, line in ipairs(data.lines) do
        local t = sanitize(line.leftText)
        if type(t) == "string" and t ~= "" then r.tooltip[#r.tooltip + 1] = t end
      end
    end
  end
  return r
end

function P.items(arg)
  local ids = {}
  for n in (arg or ""):gmatch("%d+") do ids[#ids + 1] = tonumber(n) end
  if #ids == 0 then return say("usage: /bpp items 3390,8949,...  (python tools/consumable_ids.py prints the lists)") end
  for _, id in ipairs(ids) do
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  end
  -- Give the server a moment to send item data, then read.
  C_Timer.After(2, function()
    local out, missing = {}, 0
    for _, id in ipairs(ids) do
      local r = readItem(id)
      if not r.name then missing = missing + 1 end
      out[#out + 1] = r
    end
    record("items", { items = out })
    say("items: read %d, %d without data yet (run the same command again if so)", #out, missing)
  end)
end

-- Threat ------------------------------------------------------------------------------------------
function P.threat()
  if not UnitExists("target") then return say("target something first") end
  local detailed = capture("UnitDetailedThreatSituation", "player", "target")
  local simple = capture("UnitThreatSituation", "player", "target")
  record("threat", { inCombat = InCombatLockdown(), detailed = detailed, simple = simple })
  say("threat: detailed %s, simple %s (in combat: %s)", detailed.status, simple.status, tostring(InCombatLockdown()))
end

-- Frame times ------------------------------------------------------------------------------------
local perfFrame
function P.perf(arg)
  local seconds = tonumber(arg) or 30
  if perfFrame and perfFrame:IsShown() then return say("already measuring") end
  perfFrame = perfFrame or CreateFrame("Frame")
  local run = { started = now(), seconds = seconds, frames = 0, total = 0, max = 0, over33 = 0, over50 = 0,
                over100 = 0, zone = sanitize(GetRealZoneText and GetRealZoneText()),
                inInstance = sanitize(IsInInstance and IsInInstance()), combatFrames = 0 }
  local addons = {}
  local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
  for _, name in ipairs({ "Battleplan", "Gearwright" }) do
    if loaded then
      local ok, isLoaded = pcall(loaded, name)
      if ok and isLoaded then addons[#addons + 1] = name end
    end
  end
  run.addonsLoaded = addons
  perfFrame:SetScript("OnUpdate", function(self, elapsed)
    local ms = elapsed * 1000
    run.frames = run.frames + 1
    run.total = run.total + ms
    if ms > run.max then run.max = ms end
    if ms > 33.4 then run.over33 = run.over33 + 1 end
    if ms > 50 then run.over50 = run.over50 + 1 end
    if ms > 100 then run.over100 = run.over100 + 1 end
    if InCombatLockdown() then run.combatFrames = run.combatFrames + 1 end
    if run.total >= seconds * 1000 then
      self:Hide()
      run.avgMs = run.total / run.frames
      if C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric and Enum and Enum.AddOnProfilerMetric then
        run.profiler = {}
        for _, name in ipairs(addons) do
          run.profiler[name] = {
            recentAverage = capture("C_AddOnProfiler.GetAddOnMetric", name, Enum.AddOnProfilerMetric.RecentAverageTime),
            peak = capture("C_AddOnProfiler.GetAddOnMetric", name, Enum.AddOnProfilerMetric.PeakTime),
          }
        end
      end
      table.insert(db().perf, run)
      say("perf: %d frames, avg %.1f ms, worst %.1f ms, %d over 33 ms, %d over 50 ms (loaded: %s)",
        run.frames, run.avgMs, run.max, run.over33, run.over50, #addons > 0 and table.concat(addons, ", ") or "none")
    end
  end)
  perfFrame:Show()
  say("measuring frame times for %d s; play normally", seconds)
end

-- Everything at once -------------------------------------------------------------------------------
function P.all()
  if InCombatLockdown() then return say("leave combat first: /bpp all") end
  P.env()
  P.spells()
  P.talents()
  P.auras()
  if not InCombatLockdown() then P.stats("all") end
end

-- SavedVariables check ------------------------------------------------------------------------------
local persistReport
local function persistenceCheck()
  local d = db()
  persistReport = d.persistTest
    and ("SavedVariables OK: found data written %s"):format(tostring(d.persistTest.written))
    or "SavedVariables: nothing from a previous session (first run)"
  d.persistTest = { written = now() }
end

-- JSON export ---------------------------------------------------------------------------------------
local ESC = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
local function jsonString(s)
  s = s:gsub('[%c"\\]', function(c) return ESC[c] or ("\\u%04x"):format(c:byte()) end)
  return '"' .. s:gsub("|", "\\u007c") .. '"' -- "|" breaks WoW edit boxes
end

local function isArray(t)
  local n = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then return false end
    n = n + 1
  end
  for i = 1, n do if t[i] == nil then return false end end
  return true, n
end

local function toJSON(v, buf)
  local t = type(v)
  if t == "table" then
    local arr, n = isArray(v)
    if arr and n > 0 then
      buf[#buf + 1] = "["
      for i = 1, n do
        if i > 1 then buf[#buf + 1] = "," end
        toJSON(v[i], buf)
      end
      buf[#buf + 1] = "]"
    else
      buf[#buf + 1] = "{"
      local keys = {}
      for k in pairs(v) do keys[#keys + 1] = tostring(k) end
      table.sort(keys)
      for i, k in ipairs(keys) do
        if i > 1 then buf[#buf + 1] = "," end
        buf[#buf + 1] = jsonString(k)
        buf[#buf + 1] = ":"
        local val = v[k]
        if val == nil then val = v[tonumber(k)] end
        toJSON(val, buf)
      end
      buf[#buf + 1] = "}"
    end
  elseif t == "string" then
    buf[#buf + 1] = jsonString(v)
  elseif t == "number" then
    buf[#buf + 1] = (v ~= v or v == math.huge or v == -math.huge) and "null" or tostring(v)
  elseif t == "boolean" then
    buf[#buf + 1] = tostring(v)
  else
    buf[#buf + 1] = "null"
  end
end
P.toJSON = toJSON

function P.export()
  if talentRun then return say("talent capture is still running; wait for its completion message, then /bpp export") end
  local buf = {}
  toJSON(db(), buf)
  local text = table.concat(buf)
  if not P.exportFrame then
    local f = CreateFrame("Frame", "BattleplanProbeExport", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(640, 440)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "BattleplanProbeExport")
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText("BattleplanProbe export  -  Ctrl+A, Ctrl+C, paste into a .json file")
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -30)
    sf:SetPoint("BOTTOMRIGHT", -32, 12)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(580)
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    sf:SetScrollChild(eb)
    f.edit = eb
    P.exportFrame = f
  end
  P.exportFrame.edit:SetText(text)
  P.exportFrame:Show()
  P.exportFrame.edit:SetFocus()
  P.exportFrame.edit:HighlightText()
  say("export: %d characters", #text)
  return text
end

-- Commands --------------------------------------------------------------------------------------------
local HELP = {
  "/bpp stats [label]  - stat lab snapshot (label = what you changed, e.g. +10 agility)",
  "/bpp stats diff | list | clear",
  "/bpp spells  - spellbook: every rank, cost, cast time, description",
  "/bpp talents  - trait tree, ranks and prerequisite metadata (out of combat)",
  "/bpp auras  - current buffs and weapon enchants",
  "/bpp items <ids>  - consumable effects by item ID",
  "/bpp threat  - is threat readable (with a target)",
  "/bpp perf [seconds]  - frame times",
  "/bpp all  - env, spells, talents, auras, stats",
  "/bpp export  - copyable JSON",
}

local COMMANDS = {
  stats = P.stats, spells = P.spells, talents = P.talents, auras = P.auras, items = P.items, threat = P.threat,
  perf = P.perf, all = P.all, export = P.export, env = P.env,
}

SLASH_BATTLEPLANPROBE1 = "/bpp"
SlashCmdList.BATTLEPLANPROBE = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  local fn = COMMANDS[(cmd or ""):lower()]
  if fn then return fn(rest) end
  for _, line in ipairs(HELP) do say(line) end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == "BattleplanProbe" then
    persistenceCheck()
    say("%s. /bpp for commands", persistReport)
  end
end)

BattleplanProbe = P -- for the offline test only; nothing else reads it
