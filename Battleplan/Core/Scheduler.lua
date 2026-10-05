-- Spreads heavy work across frames: each job is a coroutine that yields every
-- few units of work, and the runner stops for the frame once the budget is
-- spent. The runner is a hidden frame when idle, so idle cost is zero.
local _, ns = ...

local Jobs = {}
ns.Jobs = Jobs

Jobs.BUDGET_MS = 2

local queue, labels, failures, head, tail = {}, {}, {}, 1, 0
local runner = CreateFrame("Frame")
runner:Hide()
Jobs.runner = runner -- the offline tests drive it by hand

function Jobs:Run(fn, label, onFailure)
  tail = tail + 1
  queue[tail] = coroutine.create(fn)
  labels[tail] = "job:" .. (label or "job")
  failures[tail] = onFailure
  runner:Show()
end

function Jobs:Busy()
  return head <= tail
end

local clock = debugprofilestop

local function step(self)
  if ns.InCombat() then return end -- jobs pause in combat
  local start = clock()
  while head <= tail do
    local co = queue[head]
    local sliceStart = clock()
    local ok, err = coroutine.resume(co)
    if ns.Perf.Enabled() then ns.Perf.Note(labels[head], clock() - sliceStart) end
    local onFailure = failures[head]
    if coroutine.status(co) == "dead" then
      queue[head], labels[head], failures[head] = nil, nil, nil
      head = head + 1
    end
    if not ok then
      -- Release the owner before reporting: the next event must be able to retry.
      if onFailure then
        local cleaned, cleanupError = pcall(onFailure, err)
        if not cleaned then geterrorhandler()(cleanupError) end
      end
      geterrorhandler()(err)
    end
    if clock() - start > Jobs.BUDGET_MS then return end
  end
  head, tail = 1, 0
  self:Hide()
end

runner:SetScript("OnUpdate", step)

-- Runs every queued job to the end right now (tests, and /reload-free debugging).
function Jobs:Drain()
  local guard = 0
  while head <= tail and guard < 100000 do
    step(runner)
    guard = guard + 1
  end
end
