-- Enchant advice and upgrade targets. No WoW calls.
local _, ns = ...

local Gear = {}
ns.Engine.Gear = Gear

local Score = ns.Engine.Score

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
  -- Wearing restrictions are separate from the crafter's profession.
  if route.wearerProfession then
    local skill = ctx.professions and ctx.professions[route.wearerProfession]
    if skill and skill < (route.wearerSkill or 1) then return nil end
    if not skill then status = "unknown" end
  end
  for _, id in ipairs(route.prerequisites or {}) do
    if not ctx.completedQuests or not ctx.completedQuests[id] then status = "unknown" end
  end
  if route.faction and not ctx.faction or route.classes and not ctx.class then status = "unknown" end
  if not ctx.usable or ctx.usable[target.itemID] ~= true or target.classes and not ctx.class then status = "unknown" end
  return status, required
end

-- Structured targets use routes with stable keys, source names/locations and requirements.
-- Context contains observed access, usability, owned items and quest completion only.
-- Legacy text sources keep their existing behavior until migrated to structured routes.
-- The default 5% weighted-score threshold is a provisional churn filter, not a DPS claim.
function Gear.NextUpgrades(targets, level, weights, equippedScores, context, workTick)
  local ctx, groups = context or {}, {}
  local threshold = ctx.minGainFraction or 0.05
  for i, t in ipairs(targets or {}) do
    local baseline = equippedScores[t.slot]
    local usable = not ctx.usable or ctx.usable[t.itemID] ~= false
    local owned = ctx.owned and ctx.owned[t.itemID]
    local allowed = not t.classes or not ctx.class or t.classes[ctx.class]
    if baseline ~= false and usable and not owned and allowed and Gear.SLOT_NAMES[t.slot] then
      local gain = Score.Stats(t.stats, weights) - (baseline or 0)
      if gain > 0 and (not t.routes or gain >= (baseline or 0) * threshold) then
        local group = groups[t.slot]
        if not group then group = {}; groups[t.slot] = group end
        if t.routes then
          for _, route in ipairs(t.routes) do
            local status, required = access(route, t, level, ctx)
            if status then
              group[#group + 1] = { slot = t.slot, slotName = Gear.SLOT_NAMES[t.slot], target = t,
                gain = gain, now = required <= level, requiredLevel = required, route = route, status = status }
            end
          end
        elseif (t.minLevel or 0) <= level + 5 then
          group[#group + 1] = { slot = t.slot, slotName = Gear.SLOT_NAMES[t.slot], target = t,
            gain = gain, now = (t.minLevel or 0) <= level, requiredLevel = t.minLevel or 0, status = "available" }
        end
      end
    end
    if workTick and i % 32 == 0 then workTick() end
  end
  local rows = {}
  for _, slot in ipairs(Gear.SLOT_ORDER) do
    local candidates = groups[slot]
    local strongest
    for i, option in ipairs(candidates or {}) do
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
      rows[#rows + 1] = practical
    end
  end
  return rows
end
