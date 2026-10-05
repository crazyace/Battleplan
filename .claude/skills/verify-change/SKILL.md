---
name: verify-change
description: Run Battleplan's full check (smoke, perf and tools tests, luacheck) and the definition-of-done list before committing any change to this repo.
---

# Verify a change

Run this before every commit. A change that fails any step isn't done.

## 1. Run the checks

From the repo root, one command runs everything:

```
python scripts/check.py      # any shell; sh scripts/check.sh does the same
```

Make sure the pre-push hook is on for this clone (`git config core.hooksPath .githooks`).
To run one check alone:

```
python tests/smoke_test.py
python tests/perf_test.py
python tests/test_tools.py
python tests/test_rules.py
luacheck .
```

If `lupa` is missing: `pip install "lupa>=2.0"` (add `--break-system-packages` on
system Python). If `luacheck` is missing: `luarocks install luacheck`.

All five must pass. Expected endings: `smoke test passed: N checks`, `perf test passed`,
`tools tests passed`, `rules test passed`, `0 warnings / 0 errors`.

## 2. If something fails

- **Smoke test:** read the `FAIL:` line and the screen dump above it. Fix the code, not
  the expectation, unless the expectation itself was wrong (then say why in the commit).
- **Perf test:** a slice over 2 ms means a step in `Core/Planner.lua` needs a
  `coroutine.yield()` or its loop moved into a job. Memory growth on a hot path means a
  table, closure or string is created per call; hoist it to file scope or cache it.
  Before blaming Battleplan, check the mock isn't the one allocating (`tests/wowmock.py`
  stub methods are cached for this reason).
- **Rules test:** it names the file and line. Move game reads into `Core/API.lua`
  (see the add-game-api skill), keep `Engine/` pure, add `_status` to data files, and
  list every new file in its `.toc`.
- **luacheck:** fix the code. Only add a global to `.luacheckrc` if the addon really
  defines or reads it, and say why in the commit message.

## 3. Walk the definition of done

Check each item in `AGENTS.md` "Definition of done". `test_rules.py` already enforces
the API boundary; these greps show the same thing by hand:

```
# game data reads outside the API wrapper (should print nothing)
grep -rnE "C_(Item|Spell|SpellBook|Traits|ClassTalents|UnitAuras)\.|GetInventoryItemLink|UnitClass|UnitLevel" \
  Battleplan --include=*.lua | grep -v "Core/API.lua" | grep -vE ":[0-9]+:\s*--"

# WoW calls in the engine (should print nothing)
grep -rnE "C_[A-Z]|Unit[A-Z]|Get[A-Z][a-zA-Z]+\(|CreateFrame" Battleplan/Engine | grep -vE ":[0-9]+:\s*--"
```

New behaviour needs a test, bug fixes a regression test, new facts a line in
`docs/BETA-FINDINGS.md`, and the README / ARCHITECTURE / ROADMAP updated where relevant.

## 4. Commit and push

One logical change per commit, imperative subject under 72 characters, a body with what
and why. Then `git push`: the hook runs check.sh again and blocks the push if anything
fails. CI runs the same script on GitHub; check it went green
(`gh run list -R crazyace/Battleplan --limit 1`), and if it's red, fixing it is next.
