-- Timing for every handler, so "it never hitches" is something we measure.
-- Off unless /bplan perf on. Report: /bplan perf.
local _, ns = ...

local Perf = {}
ns.Perf = Perf

-- Budgets from the build guide, in ms. A max over budget is a bug.
Perf.BUDGET = { handler = 2, job = 3 }

local stats = {}
local clock = debugprofilestop

local function note(label, ms)
  local s = stats[label]
  if not s then
    s = { n = 0, total = 0, max = 0 }
    stats[label] = s
  end
  s.n, s.total = s.n + 1, s.total + ms
  if ms > s.max then s.max = ms end
end
Perf.Note = note

function Perf.Enabled()
  return ns.db ~= nil and ns.db.debugPerf == true and clock ~= nil
end

-- Wraps fn so each call is timed while perf mode is on. Free when it's off.
function Perf.Timed(label, fn)
  return function(...)
    if not Perf.Enabled() then return fn(...) end
    local t = clock()
    fn(...)
    note(label, clock() - t)
  end
end

function Perf.Reset()
  for k in pairs(stats) do stats[k] = nil end
end

-- Sorted by worst single call: { {label=, n=, avg=, max=, over=}, ... }
function Perf.Report()
  local out = {}
  for label, s in pairs(stats) do
    local budget = label:find("^job:") and Perf.BUDGET.job or Perf.BUDGET.handler
    out[#out + 1] = { label = label, n = s.n, avg = s.total / s.n, max = s.max, over = s.max > budget }
  end
  table.sort(out, function(a, b) return a.max > b.max end)
  return out
end
