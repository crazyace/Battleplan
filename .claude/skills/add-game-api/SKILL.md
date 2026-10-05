---
name: add-game-api
description: Add a new read from the WoW Forever client to Battleplan safely - probe it first, wrap it in Core/API.lua with feature detection, secret-value cleaning and caching, mirror it in the mock, and test it.
---

# Add a game API read

Battleplan reads the game only through `Battleplan/Core/API.lua`. Forever has removed some
globals (`GetItemStats`, `GetItemInfoInstant`, `GetSpecialization`), errors on unknown
events, and may hide values as secrets. So every new read follows these steps.

## 1. Probe it first

If `docs/BETA-FINDINGS.md` doesn't already say the function exists and what it returns:

- Add its path to `API_PATHS` in `BattleplanProbe/Probe.lua` (records present/missing).
- If the return values matter, add a capture command or extend an existing one
  (`capture(path, args...)` records status `ok` / `secret` / `missing` / `error`).
- Ask Jeff to run it on the beta only if nothing else answers the question; meanwhile
  write the wrapper defensively (steps 2-3) so it works either way.

## 2. Write the wrapper

```lua
-- What it returns, which capture confirmed it, and when it's nil.
function API.Thing(arg)
  local fn = (C_Namespace and C_Namespace.GetThing) or GetThing   -- feature-detect
  if not fn then return nil end
  local ok, value = pcall(fn, arg)                                  -- never let it error
  if not ok then return nil end
  return API.clean(value)                                           -- secrets become nil
end
```

- Tables from the client: clean each field you use, copy what you keep.
- Expensive reads (whole trees, spellbook, every bag slot): cache in a file-local, add
  `API.ForgetThing()`, and list the events that invalidate it (like `API.SPELL_EVENTS`).
  Wire them in `Planner.Start` through `ns.Events:On`, which skips events the client
  doesn't have.
- Out-of-combat data only (auras, threat): callers must not call it in combat; say so in
  the comment.

## 3. Use it from the Planner, not the Engine

`Core/Planner.lua` calls the API and passes plain values into `Engine/` functions. Engine
code never calls the game. If the read is slow, put it after a `coroutine.yield()`.

## 4. Mirror it in the mock

Add the function to `MOCK` in `tests/wowmock.py`, returning data from the character table
`C`. If the real client is known to lack it or return secrets, make the mock do that too.

## 5. Test

- Smoke test: the visible result of the new data, plus the missing-API case (set the mock
  function to `nil` and check Battleplan still loads and shows a sensible line).
- Perf test: if it's read on a frequent event, check it allocates nothing there.
- luacheck: add the global to `read_globals` in `.luacheckrc`.

## 6. Document

`docs/BETA-FINDINGS.md`: the function, what it returns on Forever, the capture. Then run
the verify-change skill and commit.
