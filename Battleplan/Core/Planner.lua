-- Gathers what the engine needs (through Core/API.lua), runs the engine, and
-- keeps the result in ns.state for the UI. It runs as a scheduler job that
-- yields between steps, only out of combat, and only when something changed.
local _, ns = ...

local Planner = {}
ns.Planner = Planner

local API, E = ns.API, ns.Engine
local state = { version = 0, ready = false }
ns.state = state

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
  local out = {}
  for slot, raw in pairs(API.EquippedItemStats()) do
    out[slot] = E.Score.Stats(E.Score.FromTokens(raw), weights)
  end
  return out
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

local function compute()
  local s = state
  local oldRotation, oldSpec = s.rotation, s.spec
  s.class = API.PlayerClass()
  s.level = API.PlayerLevel()
  local data = s.class and ns.Data[s.class]
  s.supported = data ~= nil and data.Specs ~= nil
  if not s.supported then
    s.ready, s.version = true, s.version + 1
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
  s.talentPlan = s.build and s.build.order and E.Talents.Plan(s.build, s.level, E.Spec.Flatten(s.talents)) or nil
  coroutine.yield()

  -- Rotation
  s.known = API.KnownSpells()
  s.rotation = data.Rotations and E.Rotation.Build(data.Rotations, s.spec, s.situation, s.known, s.level) or nil
  if oldRotation and s.rotation and oldSpec == s.spec then
    announce(E.Rotation.Changes(oldRotation, s.rotation), s.specName)
  end
  coroutine.yield()

  -- Gear
  s.enchants = E.Gear.EnchantAdvice(data.Gear and data.Gear.enchants, API.EquippedEnchants(), s.weights)
  local targets = data.Gear and data.Gear.targets
  s.upgrades = (targets and #targets > 0) and E.Gear.NextUpgrades(targets, s.level, s.weights, equippedScores(s.weights)) or {}
  s.hasUpgradeData = targets ~= nil and #targets > 0
  coroutine.yield()

  -- Consumables
  s.consumables = E.Consumables.Recommend(ns.Data.Consumables, {
    level = s.level, weights = s.weights, weaponKind = specs.weaponKind or "any",
  })
  s.counts = {}
  for _, rec in pairs(s.consumables) do s.counts[rec.item.itemID] = API.ItemCount(rec.item.itemID) end
  Planner.CheckBuffs()
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

  s.ready = true
  s.version = s.version + 1
end

-- Buffs only (cheap): used on its own when auras change.
function Planner.CheckBuffs()
  local s = state
  if not s.consumables or ns.InCombat() then return end
  local mh = API.WeaponEnchants()
  if GetInventoryItemLink("player", 16) == nil then mh = nil end -- no weapon, nothing to check
  s.missing = E.Consumables.BuffCheck(s.consumables, API.PlayerAuras(), elixirAuraNames(), mh,
    ns.Data.Consumables.foodAura)
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

local function start()
  if running then
    again = true
    return
  end
  running = true
  ns.Jobs:Run(job, "plan")
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
