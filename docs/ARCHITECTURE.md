# Architecture

```
 game events ──► Core/Events ──► ns.Refresh (coalesce; wait out combat)
                                      │
                                      ▼
                 Core/Scheduler ◄── Core/Planner (a job: yields between steps)
                                      │  reads through Core/API (only file that calls the game)
                                      │  runs Engine/* (pure functions)
                                      ▼
                                  ns.state ──► UI/Tabs (rows) ──► UI/MainWindow + UI/List
```

## Rules

1. **Only `Core/API.lua` reads game data.** When the probe shows something works
   differently on Forever, one file changes.
2. **Engine has no game calls.** Everything takes plain tables, so `tests/` runs it all.
3. **Data is data.** A class is a folder in `Data/`: `Specs`, `Weights`, `Talents`,
   `Rotations`, `Gear`, plus `Healing` or `Tanking` for those roles. Adding a class means
   adding a folder and its lines in the `.toc`.
4. **Every data file has a `_status`**: `verified`, `provisional` or `todo`. The window
   shows a "provisional" line while any file the character uses isn't verified.
5. **Nothing heavy in combat.** `ns.Refresh` remembers what changed and runs once on
   `PLAYER_REGEN_ENABLED`; the scheduler pauses in combat too.
6. **UI/Tabs builds rows, UI/MainWindow draws them.** Every line a player reads is
   testable without frames.

## Data shapes

- **Talent build**: `order = { {name, toRank}, ... }`, each step raising a talent *to*
  that rank. `Engine/Talents` expands it into one entry per point (first point at level
  10). A situation can be another situation's name, or `{ from = "leveling", ... }`.
- **Rotation**: `opener`, `priority`, `utility` lists of `{ spell, minLevel | talent, note }`.
  `Engine/Rotation` keeps the ones in the spellbook and lists the rest as "coming up".
- **Consumable**: `{ itemID, name, kind, stat, amount, minLevel, extra?, weapon? }`, scored
  with the spec's weights (`Engine/Score`). Potions group by what they restore.
- **Healing guide**: situations with a preference list and a rank policy (`max` or
  `efficient`); the numbers come from the client (`C_Spell` cost, cast time, description).

## Load order

`Battleplan.toc`: Core (Init, Util, Perf, Events, Scheduler, API) → Data → Engine →
`Core/Planner` → UI → `Core/Commands`. Each file gets the shared namespace through
`local _, ns = ...`.

## Adding a class

1. Capture its talent tree (`/gwp talents` from GearwrightProbe) and add
   `Data/<CLASS>/Specs.lua` with `traitTabGroups`. Until then `Core/API.lua` works the
   spec tabs out from the tree layout.
2. Add `Weights`, `Talents`, `Rotations`, `Gear` (and `Healing` / `Tanking`), marked
   `provisional`.
3. Add the files to `Battleplan.toc` and a character to `tests/wowmock.py`.
