-- Enchant advice and upgrade targets. No WoW calls.
local _, ns = ...

local Gear = {}
ns.Engine.Gear = Gear

local Score = ns.Engine.Score
local EMPTY = {}

Gear.SLOT_NAMES = {
  [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
  [9] = "Wrist", [10] = "Hands", [11] = "Finger", [12] = "Finger", [13] = "Trinket", [14] = "Trinket",
  [15] = "Back", [16] = "Main hand", [17] = "Off hand", [18] = "Ranged",
}
Gear.SLOT_ORDER = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

-- Best enchant per equipped slot, and whether the slot has one already.
-- enchants: { [slot] = { options } }; equipped: { [slot] = enchantID (0 = none) }
-- Returns rows in slot order: { slot=, slotName=, best=, score=, hasEnchant= }
function Gear.EnchantAdvice(enchants, equipped, weights)
  local rows = {}
  if not enchants then return rows end
  for _, slot in ipairs(Gear.SLOT_ORDER) do
    local options = enchants[slot]
    if options and equipped[slot] ~= nil then
      local best, bestScore
      for _, opt in ipairs(options) do
        local s = Score.Entry(opt, weights)
        if s > 0 and (not bestScore or s > bestScore) then best, bestScore = opt, s end
      end
      if best then
        rows[#rows + 1] = {
          slot = slot, slotName = Gear.SLOT_NAMES[slot], best = best, score = bestScore,
          hasEnchant = (equipped[slot] or 0) ~= 0,
        }
      end
    end
  end
  return rows
end

-- Compact imported records keep GC traversal bounded; decode only a relevant chunk.
local function fieldsOf(line)
  local fields = {}
  for value in line:gmatch("(.-)|") do fields[#fields + 1] = value end
  return fields
end
local routePattern = "^R|" .. string.rep("(.-)|", 14) .. "$"
local function optional(value) if value ~= "" then return value end end
local function decodeRoute(line)
  local key, kind, name, evidence, recipe, profession, wearer, quest, level, prerequisites,
    requirements, faction, map, location = line:match(routePattern)
  local route = { _status = "provisional", key = key, kind = kind, name = name, sourceEvidence = evidence,
    recipeID = tonumber(recipe), profession = optional(profession), wearerProfession = optional(wearer),
    questID = tonumber(quest), minLevel = tonumber(level), requirements = optional(requirements),
    faction = optional(faction), mapID = tonumber(map), location = optional(location) }
  if prerequisites ~= "" then
    route.prerequisites = {}
    for id in prerequisites:gmatch("%d+") do route.prerequisites[#route.prerequisites + 1] = tonumber(id) end
  end
  return route
end
local routeCache = setmetatable({}, { __mode = "v" })
local function nextRoute(data, offset)
  local stop = data:find("`", offset + 1, true)
  if stop then
    local raw = data:sub(offset + 1, stop - 1)
    local route = routeCache[raw]
    if not route then route = decodeRoute(raw); routeCache[raw] = route end
    return stop, route
  end
end
-- Keep source strings compact between plans; only selected route tables survive.
function Gear.Routes(target)
  if target.routes then return ipairs(target.routes) end
  if target.routeData then return nextRoute, target.routeData, 0 end
  return ipairs(EMPTY)
end
local function decodeChunk(data)
  local targets = {}
  for line in data:gsub("\n", ""):gmatch("([^`]+)") do
    if line:sub(1, 1) == "T" then
      local fields = fieldsOf(line)
      local target = { _status = "provisional", itemID = tonumber(fields[2]), name = fields[3],
        slot = tonumber(fields[4]), minLevel = tonumber(fields[5]), icon = tonumber(fields[6]), stats = {}, routeData = "" }
      for i = 7, #fields do
        local key, value = fields[i]:match("^(.-)=(.+)$")
        target.stats[key] = tonumber(value)
      end
      targets[#targets + 1] = target
    else
      local target = targets[#targets]
      target.routeData = target.routeData .. line .. "`"
      local fields = fieldsOf(line)
      if fields[9] ~= "" or fields[11] ~= "" then
        target.questIDs = target.questIDs or {}
        if fields[9] ~= "" then target.questIDs[#target.questIDs + 1] = tonumber(fields[9]) end
        for id in fields[11]:gmatch("%d+") do target.questIDs[#target.questIDs + 1] = tonumber(id) end
      end
    end
  end
  return targets
end

-- At most 16 items per yield; loaded class targets are reused between plans.
function Gear.CatalogTargets(catalog, class, level, workTick)
  local chunks = catalog and catalog[class]
  if not chunks then return nil end
  catalog.cache = catalog.cache or {}
  local cache = catalog.cache[class]
  if not cache then cache = { level = -1, targets = {} }; catalog.cache[class] = cache end
  if cache.level >= level then return cache.targets end
  for _, chunk in ipairs(chunks) do
    if chunk.minLevel <= level + 5 and not chunk.loaded then
      chunk.loaded = decodeChunk(chunk.data)
      chunk.data = nil
      for _, target in ipairs(chunk.loaded) do cache.targets[#cache.targets + 1] = target end
      if workTick then workTick() end
    end
  end
  cache.level = level
  return cache.targets
end

-- Route effort is an explicit, evidence-backed band: 1 easy, 2 moderate, 3 involved.
-- Missing effort/cost is unknown; never infer it from source kind or invent prices.
local function effort(route)
  local band = route and route.effort
  return type(band) == "number" and band >= 1 and band <= 3 and band or 4
end
local function better(a, b)
  if not b then return true end
  if a.now ~= b.now then return a.now end
  if a.status ~= b.status then return a.status == "available" end
  if a.gain ~= b.gain then return a.gain > b.gain end
  if effort(a.route) ~= effort(b.route) then return effort(a.route) < effort(b.route) end
  if a.target.itemID ~= b.target.itemID then return (a.target.itemID or 0) < (b.target.itemID or 0) end
  return (a.route and a.route.key or "") < (b.route and b.route.key or "")
end

local function access(route, target, level, ctx)
  local required = math.max(target.minLevel or 0, route.minLevel or 0)
  if required > level + 5 then return nil end
  if route.questID and ctx.completedQuests and ctx.completedQuests[route.questID] and not route.repeatable then return nil end
  if route.faction and ctx.faction and route.faction ~= ctx.faction then return nil end
  if route.classes and ctx.class and not route.classes[ctx.class] then return nil end
  local known = ctx.access and ctx.access[route.key]
  if known == "blocked" then return nil end
  local status = known == "available" and "available" or "unknown"
  -- Bind-on-pickup crafts (the importer sets wearerProfession) only reach a player
  -- with that profession; anyone else can't get one, so they aren't shown at all.
  -- Wearing restrictions are separate from the crafter's profession.
  if route.wearerProfession then
    local skill = ctx.professions and ctx.professions[route.wearerProfession]
    if not skill or skill < (route.wearerSkill or 1) then return nil end
  end
  for _, id in ipairs(route.prerequisites or EMPTY) do
    if not ctx.completedQuests or not ctx.completedQuests[id] then status = "unknown" end
  end
  if route.faction and not ctx.faction or route.classes and not ctx.class then status = "unknown" end
  if not ctx.usable or ctx.usable[target.itemID] ~= true or target.classes and not ctx.class then status = "unknown" end
  return status, required
end

-- Only two distinct items per equivalent route band can affect a primary/alternative.
-- Reuse those records while scanning so a large catalog does not create a GC spike.
local function retain(group, option)
  local kind = option.route and option.route.kind or "legacy"
  local bands = group.bands[kind]
  if not bands then bands = {}; group.bands[kind] = bands end
  local key = (option.now and 0 or 10) + (option.status == "available" and 0 or 20) + effort(option.route)
  local bucket = bands[key]
  if not bucket then bucket = {}; bands[key] = bucket end
  local same, worst
  for i, old in ipairs(bucket) do
    if old.target.itemID == option.target.itemID then same = i end
    if not worst or better(bucket[worst], old) then worst = i end
  end
  local kept
  if same then
    if not better(option, bucket[same]) then return end
    kept = bucket[same]
  elseif #bucket < 2 then
    kept = {}
    bucket[#bucket + 1] = kept
    group[#group + 1] = kept
  elseif better(option, bucket[worst]) then kept = bucket[worst]
  else return end
  kept.slot, kept.slotName, kept.target = option.slot, option.slotName, option.target
  kept.gain, kept.now, kept.requiredLevel = option.gain, option.now, option.requiredLevel
  kept.route, kept.status = option.route, option.status
end

-- Reuse a bounded order of modeled stats instead of allocating/sorting keys per recommendation.
local comparisonStats = {}
for key in pairs(ns.Data.Stats.names) do
  if key ~= "ALL_STATS" then comparisonStats[#comparisonStats + 1] = key end
end
table.sort(comparisonStats)
local baseStats = { STRENGTH = true, AGILITY = true, STAMINA = true, INTELLECT = true, SPIRIT = true }
local function comparison(option, scores, equipped)
  local baseline = scores[option.slot] or 0
  local result = { baselineScore = baseline, targetScore = baseline + option.gain,
    gainFraction = baseline > 0 and option.gain / baseline or nil }
  -- Legacy score-only callers do not provide enough facts to describe individual stats.
  if not equipped or equipped[option.slot] == false then return result end
  result.empty = equipped[option.slot] == nil
  local old, new = equipped[option.slot] or EMPTY, option.target.stats or EMPTY
  result.changes = {}
  for _, key in ipairs(comparisonStats) do
    local before = (old[key] or 0) + (baseStats[key] and old.ALL_STATS or 0)
    local after = (new[key] or 0) + (baseStats[key] and new.ALL_STATS or 0)
    local delta = after - before
    if math.abs(delta) > 0.000001 then
      result.changes[#result.changes + 1] = { stat = key, before = before, after = after, delta = delta }
    end
  end
  return result
end

-- Every distinct item kept for a slot, best first (each with its best route),
-- so the player can pick a quest, crafted, vendor or drop option themselves.
-- The recommendation is always included; at most MAX_OPTIONS in all.
Gear.MAX_OPTIONS = 12
local function slotOptions(candidates, recommended)
  local options, at = {}, {}
  for _, option in ipairs(candidates) do
    local id = option.target.itemID
    local index = id and at[id]
    if not index then
      options[#options + 1] = option
      if id then at[id] = #options end
    elseif better(option, options[index]) then options[index] = option end
  end
  table.sort(options, better)
  for i = #options, Gear.MAX_OPTIONS + 1, -1 do
    if options[i] ~= recommended then table.remove(options, i) end
  end
  if #options > Gear.MAX_OPTIONS then
    for i = #options, 1, -1 do
      if options[i] ~= recommended then table.remove(options, i); break end
    end
  end
  return options
end

-- Structured targets use routes with stable keys, source names/locations and requirements.
-- Context contains observed access, usability, owned items and quest completion only.
-- Legacy text sources keep their existing behavior until migrated to structured routes.
-- The default 5% weighted-score threshold is a provisional churn filter, not a DPS claim.
function Gear.NextUpgrades(targets, level, weights, equippedScores, context, workTick)
  local ctx, groups = context or {}, {}
  local threshold = ctx.minGainFraction or 0.05
  local routeWork, scratch = 0, {}
  for i, t in ipairs(targets or EMPTY) do
    local baseline = equippedScores[t.slot]
    local usable = not ctx.usable or ctx.usable[t.itemID] ~= false
    local owned = ctx.owned and ctx.owned[t.itemID]
    local allowed = not t.classes or not ctx.class or t.classes[ctx.class]
    if baseline ~= false and usable and not owned and allowed and Gear.SLOT_NAMES[t.slot] then
      local gain = Score.Stats(t.stats, weights) - (baseline or 0)
      if gain > 0 and (not (t.routes or t.routeData) or gain >= (baseline or 0) * threshold) then
        local group = groups[t.slot]
        if not group then group = { bands = {} }; groups[t.slot] = group end
        if t.routes or t.routeData then
          for _, route in Gear.Routes(t) do
            routeWork = routeWork + 1
            if workTick and routeWork % 4 == 0 then workTick() end
            local status, required = access(route, t, level, ctx)
            if status then
              scratch.slot, scratch.slotName, scratch.target = t.slot, Gear.SLOT_NAMES[t.slot], t
              scratch.gain, scratch.now, scratch.requiredLevel = gain, required <= level, required
              scratch.route, scratch.status = route, status
              retain(group, scratch)
            end
          end
        elseif (t.minLevel or 0) <= level + 5 then
          scratch.slot, scratch.slotName, scratch.target = t.slot, Gear.SLOT_NAMES[t.slot], t
          scratch.gain, scratch.now, scratch.requiredLevel = gain, (t.minLevel or 0) <= level, t.minLevel or 0
          scratch.route, scratch.status = nil, "available"
          retain(group, scratch)
        end
      end
    end
    if workTick and i % 8 == 0 then workTick() end
  end
  local rows = {}
  for _, slot in ipairs(Gear.SLOT_ORDER) do
    local candidates = groups[slot]
    local strongest
    for i, option in ipairs(candidates or EMPTY) do
      if better(option, strongest) then strongest = option end
      if workTick and i % 32 == 0 then workTick() end
    end
    if strongest then
      local practical = strongest
      for i, option in ipairs(candidates) do
        -- Prefer substantially easier access only when it retains >=80% of the gain.
        -- Both options must be usable now and their source access confirmed.
        if option.now and strongest.now and option.status == "available" and strongest.status == "available"
          and effort(strongest.route) < 4 and effort(option.route) < effort(strongest.route)
          and option.gain >= strongest.gain * 0.8
          and (effort(option.route) < effort(practical.route)
            or effort(option.route) == effort(practical.route) and better(option, practical)) then practical = option end
        if workTick and i % 32 == 0 then workTick() end
      end
      local alternative
      if practical ~= strongest and practical.target.itemID ~= strongest.target.itemID then alternative = strongest end
      if not alternative then
        for i, option in ipairs(candidates) do
          -- Keep a different acquisition path when useful; cap at one alternative per slot.
          if option.target.itemID ~= practical.target.itemID and option.now == practical.now
            and option.status == practical.status and option.route and practical.route
            and option.route.kind ~= practical.route.kind and better(option, alternative) then alternative = option end
          if workTick and i % 32 == 0 then workTick() end
        end
      end
      practical.selectedForEase = practical ~= strongest
      practical.alternative = alternative
      practical.options = slotOptions(candidates, practical)
      for _, option in ipairs(practical.options) do
        option.comparison = comparison(option, equippedScores, ctx.equippedStats)
      end
      if alternative and not alternative.comparison then
        alternative.comparison = comparison(alternative, equippedScores, ctx.equippedStats)
      end
      rows[#rows + 1] = practical
      if workTick then workTick() end
    end
  end
  return rows
end
