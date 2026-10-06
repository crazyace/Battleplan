-- Gathers what the engine needs (through Core/API.lua), runs the engine, and
-- keeps the result in ns.state for the UI. It runs as a scheduler job that
-- yields between steps, only out of combat, and only when something changed.
local _, ns = ...
local EMPTY = {}

local Planner = {}
ns.Planner = Planner

local API, E = ns.API, ns.Engine
local state = { version = 0, ready = false }
ns.state = state

local function upcomingIcons(guide, icons, reads, rules)
  if not guide then return reads end
  for _, spell in ipairs(guide.upcoming or {}) do
    if not icons[spell.spell] then
      local rule = rules and rules[spell.spell]
      icons[spell.spell] = API.SpellIcon(spell.spellID or rule and rule.spellID, spell.spell)
      reads = reads + 1
      if reads % 4 == 0 then coroutine.yield() end
    end
  end
  return reads
end

-- Icon reads are bounded per slice and published with the rest of the plan.
local function spellIcons(s, data, rules)
  local icons, reads = {}, 0
  for name, spell in pairs(s.known) do
    icons[name] = API.SpellIcon(spell.id, name)
    reads = reads + 1
    if reads % 4 == 0 then coroutine.yield() end
  end
  for _, step in ipairs(s.build and s.build.order or {}) do
    local name = step[1]
    local effect = data.TalentEffects and data.TalentEffects[name]
    local rule = rules and rules[name]
    if not icons[name] then
      icons[name] = API.SpellIcon(effect and effect.spellID or rule and rule.spellID, name)
      reads = reads + 1
      if reads % 4 == 0 then coroutine.yield() end
    end
  end
  reads = upcomingIcons(s.rotation, icons, reads, rules)
  upcomingIcons(s.tanking, icons, reads, rules)
  return icons
end

-- Healing table: every rank of every heal the guide mentions.
local function healingRows(known, guide)
  local raw = {}
  for _, name in ipairs(E.Healing.SpellNames(guide)) do
    local k = known[name]
    if k then
      for rank, id in pairs(k.ranks) do
        local d = API.SpellDetails(id)
        d.name, d.rank, d.id = name, rank, id
        d.targets = guide.partyHeals and guide.partyHeals[name] or nil
        raw[#raw + 1] = d
      end
      coroutine.yield()
    end
  end
  return E.Healing.Rows(raw)
end

local function equippedScores(weights)
  local out, details, unknown = {}, {}, false
  local equipped, owned = API.EquippedItemStats()
  for slot, raw in pairs(equipped) do
    if raw == false then out[slot], details[slot], unknown = false, false, true
    else
      details[slot] = E.Score.FromTokens(raw)
      out[slot] = E.Score.Stats(details[slot], weights)
    end
  end
  return out, unknown, owned, details
end

-- Every elixir's buff name, for the buff check. Item data can arrive late,
-- so names fill in over several refreshes.
local elixirAuras = {}
local function elixirAuraNames()
  for _, e in ipairs(ns.Data.Consumables) do
    if e.kind == "elixir" then
      local name = API.ItemBuffName(e.itemID)
      if name then elixirAuras[name] = true end
    end
  end
  return elixirAuras
end

local function anyProvisional(data)
  for _, part in pairs(data) do
    if type(part) == "table" and part._status and part._status ~= "verified" then return true end
  end
  return ns.Data.Consumables._status ~= "verified"
end

-- Says what's new in the rotation after a level-up or a new spell.
local function announce(changes, specName)
  for _, c in ipairs(changes) do
    if c.why == "new" then
      ns.util.print("%s is now #%d in your %s rotation.", ns.util.color("gold", c.spell), c.position, specName)
    else
      ns.util.print("%s rank %d: same place in your rotation, hits harder.", ns.util.color("gold", c.spell), c.rank)
    end
  end
end

local function yieldGear() coroutine.yield() end

local function compute()
  local s = {} -- publish only after the whole job succeeds
  local oldRotation, oldSpec = state.rotation, state.spec
  s.class = API.PlayerClass()
  s.level = API.PlayerLevel()
  local data = s.class and ns.Data[s.class]
  s.supported = data ~= nil and data.Specs ~= nil
  if not s.supported then
    state.supported, state.ready, state.version = false, true, state.version + 1
    return
  end
  local specs = data.Specs
  s.talents, s.talentReason = API.ReadTalents(specs.traitTabGroups)
  s.spec, s.specHow = E.Spec.Detect(s.talents, specs, ns.db.spec)
  s.specName = specs.names[s.spec] or s.spec
  s.role = specs.roles[s.spec] or "dps"
  s.situation = E.Spec.Situation(ns.db.situation, s.level, ns.MAX_LEVEL)
  s.weights = (data.Weights and data.Weights[s.spec]) or {}
  s.provisional = anyProvisional(data)
  coroutine.yield()

  -- Talents
  local specTalents = data.Talents and data.Talents[s.spec]
  s.build = specTalents and (E.Score.Lookup(specTalents, s.situation) or E.Score.Lookup(specTalents, "leveling"))
  local rules = ns.Data.TalentRules and ns.Data.TalentRules[s.class]
  s.talentPlan = s.build and s.build.order and E.Talents.Plan(s.build, s.level, E.Spec.Flatten(s.talents), rules, data.TalentEffects) or nil
  if s.build and ns.Data.TalentRules and ns.Data.TalentRules._status ~= "verified" then s.provisional = true end
  coroutine.yield()

  -- Rotation
  s.known = API.KnownSpells()
  s.rotation = data.Rotations and E.Rotation.Build(data.Rotations, s.spec, s.situation, s.known, s.level, data.Spells) or nil
  local changes
  if oldRotation and s.rotation and oldSpec == s.spec then
    changes = E.Rotation.Changes(oldRotation, s.rotation)
  end
  coroutine.yield()

  -- Gear
  s.enchants = E.Gear.EnchantAdvice(data.Gear and data.Gear.enchants, API.EquippedEnchants(), s.weights)
  local targets = data.Gear and data.Gear.targets
  if not targets or #targets == 0 then
    targets = E.Gear.CatalogTargets(ns.Data.FullGearCatalog, s.class, s.level, yieldGear)
  end
  s.upgrades = {}
  if targets and #targets > 0 then
    local scores, owned, details
    scores, s.gearUnknown, owned, details = equippedScores(s.weights)
    local context = { class = s.class, owned = owned, faction = API.PlayerFaction(), completedQuests = {}, equippedStats = details }
    local queried, reads = {}, 0
    for i, target in ipairs(targets) do
      if (target.minLevel or 0) <= s.level + 5 and not owned[target.itemID] then
        local count = API.ItemCount(target.itemID)
        if type(count) == "number" and count > 0 then owned[target.itemID] = true end
      end
      if (target.minLevel or 0) <= s.level + 5 then
        if target.routeData then
          for _, id in ipairs(target.questIDs or EMPTY) do
            if not queried[id] then
              queried[id] = true
              context.completedQuests[id] = API.QuestCompleted(id)
              reads = reads + 1
              if reads % 4 == 0 then coroutine.yield() end
            end
          end
        else
          for _, route in E.Gear.Routes(target) do
            local id = route.questID
            if id and not queried[id] then
              queried[id] = true
              context.completedQuests[id] = API.QuestCompleted(id)
              reads = reads + 1
              if reads % 4 == 0 then coroutine.yield() end
            end
            for _, previous in ipairs(route.prerequisites or EMPTY) do
              if not queried[previous] then
                queried[previous] = true
                context.completedQuests[previous] = API.QuestCompleted(previous)
                reads = reads + 1
                if reads % 4 == 0 then coroutine.yield() end
              end
            end
          end
        end
      end
      if i % 4 == 0 then coroutine.yield() end
    end
    s.upgrades = E.Gear.NextUpgrades(targets, s.level, s.weights, scores, context, yieldGear)
  end
  s.hasUpgradeData = targets ~= nil and #targets > 0
  coroutine.yield()

  -- Consumables
  s.consumables = E.Consumables.Recommend(ns.Data.Consumables, {
    level = s.level, weights = s.weights, weaponKind = specs.weaponKind or "any",
  })
  s.counts = {}
  for _, rec in pairs(s.consumables) do s.counts[rec.item.itemID] = API.ItemCount(rec.item.itemID) end
  Planner.CheckBuffs(s)
  coroutine.yield()

  -- Role guides
  s.healing, s.tanking = nil, nil
  if s.role == "healer" and data.Healing then
    local guide = E.Score.Lookup(data.Healing, s.spec)
    if guide then
      local rows = healingRows(s.known, guide)
      s.healing = {
        rows = rows,
        picks = E.Healing.Pick(guide.situations, rows),
        manaPlan = guide.manaPlan or {},
        cooldowns = E.Rotation.Filter(guide.cooldowns, s.known, s.level),
      }
    end
  elseif s.role == "tank" then
    s.tanking = E.Tanking.Build(data.Tanking, s.spec, s.known, s.level)
  end

  coroutine.yield()
  s.icons = spellIcons(s, data, rules)

  s.ready, s.version = true, state.version + 1
  for k in pairs(state) do state[k] = nil end
  for k, v in pairs(s) do state[k] = v end
  if changes then announce(changes, s.specName) end
end

-- Buffs only (cheap): used on its own when auras change.
local function sameMissing(a, b)
  if not a or #a ~= #b then return false end
  for i, row in ipairs(b) do
    if a[i].group ~= row.group or a[i].item.itemID ~= row.item.itemID then return false end
  end
  return true
end

function Planner.CheckBuffs(target)
  local s = target or state
  if not s.consumables or ns.InCombat() then return end
  local mh = API.WeaponEnchants()
  if not API.HasMainHand() then mh = nil end -- no weapon, nothing to check
  local missing = E.Consumables.BuffCheck(s.consumables, API.PlayerAuras(), elixirAuraNames(), mh,
    ns.Data.Consumables.foodAura)
  if not sameMissing(s.missing, missing) then
    s.missing = missing
    if s == state then s.version = s.version + 1 end
  end
end

-- Bags can change without a spell, talent or equipment event.
function Planner.CheckCounts()
  local s = state
  if not s.consumables or ns.InCombat() then return end
  local changed = false
  for _, rec in pairs(s.consumables) do
    local id = rec.item.itemID
    local count = API.ItemCount(id)
    if s.counts[id] ~= count then s.counts[id], changed = count, true end
  end
  if changed then s.version = s.version + 1 end
  if ns.UI.Refresh then ns.UI.Refresh() end
end

-- Queue a refresh: coalesced, deferred until after combat, run as a job.
local running, again = false, false

local function finish()
  running = false
  if ns.UI.Refresh then ns.UI.Refresh() end
  if again then
    again = false
    Planner.Queue()
  end
end

local function job()
  compute()
  finish()
end

local function failed()
  running, again = false, false
  state.error = "Couldn't update the plan. Reopen Battleplan to try again."
  state.version = state.version + 1
  if ns.UI.Refresh then ns.UI.Refresh() end
end

local function start()
  if running then
    again = true
    return
  end
  running = true
  ns.Jobs:Run(job, "plan", failed)
end

function Planner.Queue()
  ns.Refresh("plan", 0.2, start)
end

-- In a dungeon or raid: name what's missing, once per zone-in.
local function announceMissing()
  local s = state
  if not ns.db.buffCheck or not s.consumables then return end
  local inside, kind = API.InInstance()
  if not inside or (kind ~= "party" and kind ~= "raid") then return end
  Planner.CheckBuffs()
  if not s.missing or #s.missing == 0 then return end
  local parts = {}
  for _, m in ipairs(s.missing) do
    parts[#parts + 1] = ("%s (%s)"):format(E.Consumables.GROUP_NAMES[m.group], m.item.name)
  end
  ns.util.print("before the pull: no %s.", table.concat(parts, ", "))
end

local function questsChanged()
  API.ForgetQuestStates()
  Planner.Queue()
end

local function bagsChanged()
  Planner.CheckCounts()
  -- Ownership comparisons run in the existing sliced job, only while visible.
  if ns.UI.IsShown and ns.UI.IsShown() then Planner.Queue() end
end

local started = false
function Planner.Start()
  if started then return end
  started = true
  local Events = ns.Events
  for _, event in ipairs(API.SPELL_EVENTS) do
    Events:On(event, function() API.ForgetSpells(); Planner.Queue() end, "spells")
  end
  for _, event in ipairs(API.TALENT_EVENTS) do
    Events:On(event, function() API.ForgetTalents(); Planner.Queue() end, "talents")
  end
  Events:On("PLAYER_EQUIPMENT_CHANGED", Planner.Queue, "gear")
  Events:On("QUEST_TURNED_IN", questsChanged, "quests")
  Events:On("QUEST_LOG_UPDATE", questsChanged, "quests")
  Events:On("GET_ITEM_INFO_RECEIVED", Planner.Queue, "item-data")
  Events:On("ITEM_DATA_LOAD_RESULT", Planner.Queue, "item-data")
  local function bagRefresh() ns.Refresh("bags", 0.2, bagsChanged) end
  Events:On("BAG_UPDATE_DELAYED", bagRefresh, "bags")
  Events:On("BAG_UPDATE", bagRefresh, "bags")
  -- UNIT_AURA fires constantly: player only, only while the window is open,
  -- coalesced, and with no new closure per event.
  local function buffRefresh() Planner.CheckBuffs(); ns.UI.Refresh() end
  Events:On("UNIT_AURA", function(unit)
    if unit == "player" and ns.UI.IsShown and ns.UI.IsShown() then
      ns.Refresh("buffs", 0.5, buffRefresh)
    end
  end, "auras")
  Events:On("PLAYER_ENTERING_WORLD", function()
    ns.Refresh("zone-in", 3, announceMissing)
  end, "zone")
  Planner.Queue()
end
