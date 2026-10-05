-- One frame owns every event. Bursty events are coalesced, and nothing heavy
-- runs in combat: Battleplan has no combat display, so it stays dormant until
-- PLAYER_REGEN_ENABLED and then refreshes once.
local ADDON, ns = ...

local Events = {}
ns.Events = Events

local frame = CreateFrame("Frame")
local handlers = {}

-- Events the client doesn't have are skipped: modern clients error on an
-- unknown event name, and Forever doesn't fire every Classic or Mainline event
-- (Gearwright hit this on the beta). Returns false when skipped.
function Events:On(event, fn, label)
  local list = handlers[event]
  if not list then
    if not pcall(frame.RegisterEvent, frame, event) then
      ns.util.debug("event %s doesn't exist on this client; skipped", event)
      return false
    end
    list = {}
    handlers[event] = list
  end
  list[#list + 1] = ns.Perf.Timed(label or event, fn)
  return true
end

-- One handler's error doesn't stop the others; the error still goes to
-- whatever error handler is installed (BugSack, the default frame...).
frame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], ...)
    if not ok then geterrorhandler()(err) end
  end
end)

function ns.InCombat()
  return InCombatLockdown() == true
end

-- Coalesce: run fn once, `delay` seconds after the first call in a burst.
-- The timer callback for each key is made once and reused, so a burst
-- allocates nothing after the first time a key is used.
local pending, queued, callbacks = {}, {}, {}

function ns.Coalesce(key, delay, fn)
  queued[key] = fn
  if pending[key] then return end
  pending[key] = true
  local cb = callbacks[key]
  if not cb then
    cb = function()
      pending[key] = nil
      local f = queued[key]
      queued[key] = nil
      if f then f() end
    end
    callbacks[key] = cb
  end
  C_Timer.After(delay or 0, cb)
end

-- Refresh: coalesced out of combat; in combat, remembered and run once on
-- PLAYER_REGEN_ENABLED. This is the path every refresh trigger takes.
local dirty = {}

function ns.Refresh(key, delay, fn)
  if ns.InCombat() then
    dirty[key] = fn
    return
  end
  ns.Coalesce(key, delay, fn)
end

-- Run fn now if out of combat, else after combat (for frame changes).
local afterCombat = {}

function ns.OutOfCombat(fn)
  if not ns.InCombat() then return fn() end
  afterCombat[#afterCombat + 1] = fn
end

Events:On("PLAYER_REGEN_ENABLED", function()
  for key, fn in pairs(dirty) do
    dirty[key] = nil
    ns.Coalesce(key, 0, fn)
  end
  for i = 1, #afterCombat do
    local fn = afterCombat[i]
    afterCombat[i] = nil
    fn()
  end
end)

Events:On("ADDON_LOADED", function(name)
  if name == ADDON then ns:InitDB() end
end)

-- Startup work waits a frame so login isn't slowed down.
Events:On("PLAYER_LOGIN", function()
  if not ns.db then ns:InitDB() end
  C_Timer.After(0, function()
    if ns.Planner then ns.Planner.Start() end
  end)
end)
