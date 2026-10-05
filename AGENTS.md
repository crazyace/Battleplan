# AGENTS.md

Guidelines for anyone (human or AI agent) working on Battleplan, a World of Warcraft:
Forever addon. Read this before changing anything. The design is in
[docs/BUILD-GUIDE.md](docs/BUILD-GUIDE.md), the structure in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), and what the game client actually does in
[docs/BETA-FINDINGS.md](docs/BETA-FINDINGS.md).

## How we work

1. **Work autonomously.** Ask a question only when the answer can't be found in this repo,
   the docs, a probe capture or a reasonable default, *and* a wrong guess would be costly
   or hard to undo (deleting data, publishing a release, changing a public command).
   Otherwise decide, write the decision down (commit message, and the doc it affects),
   and keep going.
2. **Production grade, not a hack.** Every change is tested, linted, documented and small
   enough to review. No "temporary" shortcuts, no commented-out code, no TODOs without an
   entry in [ROADMAP.md](ROADMAP.md).
3. **Facts come from the client.** Game data is either confirmed by a probe capture
   (`verified`) or marked `provisional` / `todo`. Never present a guess as a fact, and
   never invent talent, spell or item names for a tree nobody has captured.
4. **Finish the job.** A task is done when the [definition of done](#definition-of-done)
   holds, the change is committed and pushed, and the docs say what changed.

## Commands

```
pip install "lupa>=2.0"          # once; the tests run real Lua 5.1 through it
python tests/smoke_test.py       # behaviour: every tab, every class, combat dormancy, probe
python tests/perf_test.py        # budgets: slice time, row building, zero allocation
python tests/test_tools.py       # tools/stat_lab.py and tools/consumable_ids.py
python tests/test_rules.py       # architecture rules below (API boundary, pure engine, _status, .toc)
luacheck .                       # lint (luarocks install luacheck)
```

All five must pass before every commit. CI runs the same five on every push.

## Repository map

| Path | What it is | Rule |
|---|---|---|
| `Battleplan/Core/API.lua` | Every game read | The only file that calls the WoW API for game data |
| `Battleplan/Core/Events.lua` | Event bus, `ns.Refresh`, `ns.Coalesce`, `ns.OutOfCombat` | Every refresh trigger goes through `ns.Refresh` |
| `Battleplan/Core/Scheduler.lua` | Time-sliced jobs | Heavy work runs as a job that yields |
| `Battleplan/Core/Planner.lua` | Gathers data, runs the engine, fills `ns.state` | No frames, no printing except change notices |
| `Battleplan/Data/` | Static tables, one folder per class | Every file has `_status` |
| `Battleplan/Engine/` | Pure logic | No WoW calls at all |
| `Battleplan/UI/Tabs.lua` | Rows each tab shows | No frames: rows only, so tests can read them |
| `Battleplan/UI/MainWindow.lua`, `List.lua`, `Animations.lua` | Frames | Built lazily, reused, never rebuilt per refresh |
| `BattleplanProbe/` | Dev-only data collector | Never shipped, never required by Battleplan |
| `tools/` | Python helpers (stat lab, ID lists) | Standard library only |
| `tests/wowmock.py` | Mock client and test characters | Mirrors confirmed client behaviour |
| `data/probe/` | Raw captures | Commit as exported; never edit |

## Coding guidelines

### Lua (the addon)

- **Lua 5.1 only.** No `goto`, `//`, bitwise operators, `utf8`, or `table.unpack`.
  The tests run Lua 5.1 so this is enforced.
- **Namespace, not globals.** Every file starts `local _, ns = ...`. The only globals are
  in `.luacheckrc` `globals`; adding one needs a reason in the commit message.
- **Game reads go through `Core/API.lua`.** Each API function:
  - feature-detects (`if C_Spell and C_Spell.GetSpellInfo then`), because Forever has
    removed some globals and may not have every Mainline function;
  - wraps calls that can error in `pcall`;
  - passes every value through `API.clean` so secret values become `nil`;
  - caches expensive reads and exposes a `Forget...` function wired to the events that
    invalidate them.
- **Events:** register with `ns.Events:On(event, fn, label)`. It returns `false` for
  events the client doesn't have (Forever errors on unknown names); code must cope.
- **Engine functions take plain tables and return plain tables.** If you need game data
  in the engine, add an API function and pass its result in from `Planner`.
- **Data tables:** stat keys from `Data/Stats.lua` only; spell names exactly as the
  client spells them; `minLevel` from a trainer capture or marked Classic in a comment;
  `_status` updated when the data's provenance changes.
- **Style:** two-space indent, `local` everything, lines under 140 characters, comments
  explain *why* (the client quirk, the capture it came from), not what.

### Performance (the "no hitching" contract)

These are tested, and a failing perf test blocks the commit:

- Nothing heavy in combat. Refresh triggers call `ns.Refresh(key, delay, fn)`, which
  defers until `PLAYER_REGEN_ENABLED`. Frame changes in combat go through `ns.OutOfCombat`.
- Work that loops over many things runs inside `ns.Jobs:Run` and calls
  `coroutine.yield()` between chunks. Budget: 2 ms per frame.
- Hot paths allocate nothing: no table, closure or string creation in event handlers
  that can fire often (`UNIT_AURA`, `BAG_UPDATE`, combat log), in `UI.Refresh` when
  nothing changed, or in list scrolling. Define callbacks once at file scope.
- No `OnUpdate` scripts except the scheduler's runner, which hides itself when idle.
  Animate with `AnimationGroup`s.
- UI frames are created once (lazily, on first open) and reused. Set text only when it
  changed.
- Never call `collectgarbage()` in addon code.

### Python (tools and tests)

- Python 3.10+, standard library only (plus `lupa` for tests).
- Tools read probe exports and write generated files (`data/stats/conversions.json`,
  Lua tables). Generated files say which tool wrote them; nobody edits them by hand.
- Each tool has a test in `tests/test_tools.py` (or its own test file run by CI).

## Testing guidelines

- **Every behaviour change gets a test** in `tests/smoke_test.py` that reads what the
  player would see (`screen(L, ns, "tab")`) or the state that drives it.
- **Every bug fix gets a regression test** that fails without the fix.
- **The mock follows the real client.** When a capture shows the client behaving a
  certain way (an event missing, a value secret, an API absent), make `tests/wowmock.py`
  do the same, then make Battleplan handle it.
- **New hot paths get a perf check** in `tests/perf_test.py` (time budget, allocation
  budget, or both).
- Don't loosen a test or budget to make it pass. If a budget is wrong, change it in
  `docs/BUILD-GUIDE.md` first, with the reason.

## Game data and provenance

| `_status` | Meaning | Who sets it |
|---|---|---|
| `verified` | Every value traced to a probe capture or the client's own text | After a capture, citing it in `docs/BETA-FINDINGS.md` |
| `provisional` | Reasonable first draft (Classic values, theorycraft not yet run) | Anyone adding data |
| `todo` | Not written yet; the UI says so | Anyone adding a stub |

- A fact goes in `docs/BETA-FINDINGS.md` with its source capture before code relies on it.
- Code and data borrowed from other projects: only MIT or compatible licenses, with
  credit. "All Rights Reserved" addons (Gear Journey, TrainerSpells, Auctionator) may be
  read to learn which APIs exist, never copied.
- Wowhead's Forever database is a lead to confirm, not ground truth.

## Commits and pushes

- One logical change per commit. Subject in the imperative, under 72 characters
  ("Add Druid healing guide"); body says what and why, and which capture any new fact
  came from.
- Run all five checks before committing. Push to `main` when they pass; CI must stay
  green. If CI fails, fixing it is the next task.
- Never commit secrets, personal data from other players (names in captures are fine
  only when the client shows them publicly, and AH seller names are never recorded),
  or `__pycache__`.

## Definition of done

- [ ] `smoke_test.py`, `perf_test.py`, `test_tools.py`, `test_rules.py` and `luacheck .` pass
- [ ] New behaviour has a test; fixed bugs have a regression test
- [ ] No game calls outside `Core/API.lua`; no WoW calls in `Engine/` (`test_rules.py` checks)
- [ ] Nothing new runs in combat; hot paths allocate nothing
- [ ] Data files have the right `_status`; new facts are in `docs/BETA-FINDINGS.md`
- [ ] Docs updated: README (commands), ARCHITECTURE (structure), ROADMAP (checked off or added)
- [ ] Committed with a clear message and pushed

## Skills

Step-by-step procedures for recurring jobs live in [.claude/skills/](.claude/skills/):

| Skill | Use it when |
|---|---|
| [verify-change](.claude/skills/verify-change/SKILL.md) | Before every commit: runs all checks and the done list |
| [import-probe-capture](.claude/skills/import-probe-capture/SKILL.md) | A new `/bpp export` or `/gwp export` arrives |
| [add-class](.claude/skills/add-class/SKILL.md) | Adding a class or a spec's role guide |
| [add-game-api](.claude/skills/add-game-api/SKILL.md) | Battleplan needs to read something new from the client |
| [update-data](.claude/skills/update-data/SKILL.md) | Changing builds, rotations, weights, consumables or enchants |
