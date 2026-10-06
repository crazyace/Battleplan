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

1. Capture its talent tree (`/bpp talents`; GearwrightProbe `/gwp talents` also works) and add
   `Data/<CLASS>/Specs.lua` with `traitTabGroups`. Until then `Core/API.lua` works the
   spec tabs out from the tree layout.
2. Add `Weights`, `Talents`, `Rotations`, `Gear` (and `Healing` / `Tanking`), marked
   `provisional`.
3. Add the files to `Battleplan.toc` and a character to `tests/wowmock.py`.

## Refresh and failure handling

`ns.Refresh` checks combat both when requested and when its coalesced timer fires.
Cached callbacks avoid allocations in frequent event handlers. Bag events update
counts separately; aura checks invalidate the UI only when the missing-buff list
changes. Item-data completion events trigger another plan.

`Jobs:Run(fn, label, onFailure)` releases failed jobs and invokes the owner's cleanup
callback before reporting the error. Planner computes into a separate table and
publishes only complete results, preserving the stable `ns.state` identity. Failure
releases the running flag, keeps the previous plan and exposes a retry message.

`API.EquippedItemStats` returns `false` for an equipped slot whose stats are unreadable;
an absent slot is genuinely empty. Gear comparisons skip the former and use zero
only for the latter.

## Imported structural talent data

`data/talents/catalog.json` retains source URL, build, collection date, original-source
SHA-256, numeric talent/spell IDs, layout and prerequisite metadata. It contains facts
extracted from the previously collected ForeverDB snapshot, not source-site code or
tooltip prose. `tools/import_talent_catalog.py` emits `Data/TalentRules.lua`; edit the
snapshot and regenerate, never hand-edit the output.

The pure talent engine validates all planned points and checks actual prerequisites
before recommending the next point. Only the gate's source-reported tree-point
threshold is interpreted; raw gate metadata stays in JSON. Extra prerequisite
conditions are preserved but fail closed until their semantics are confirmed (one
Druid record currently has such a condition). Imported data stays `provisional` and
does not establish live availability or supersede probe captures.

## Native talent captures and observed spell catalog

BattleplanProbe `/bpp talents` feature-detects the trait APIs and records config,
per-tree node IDs, raw node/entry/definition returns, condition metadata and spell
text. Node work runs in batches of four through zero-delay timers. Missing, errored,
secret or truncated required reads remain inspectable and mark the capture incomplete.
Combat interrupts it; a changed active config aborts it. `complete` means the required
records were readable, not that imported talent rules or gate semantics are verified.
There is no production dependency on the probe.

`tools/import_spell_catalog.py` generates `Data/WARRIOR/Spells.lua` directly from an
unchanged dated probe export. Observations are keyed by exact spell ID, with captured
rank, costs, level, timestamp, build and source SHA-256. Rotation rows carry the learned
ID and attach reference text only when both spell name and rank match the catalog.
The tooltip labels the captured level; it is not live damage or a live resource quote.
Learning levels and base cooldowns are never inferred from this catalog. Rotation
choices remain independently provisional, and the UI states the starter guide's scope.

## Rank-specific talent effects

The probe queues a second phase after node metadata: four rank-tooltip calls per
timer, never mixed with node batches. Every valid entry requests ranks `1..maxRanks`
through `C_TooltipInfo.GetTraitEntry(entryID, rank)`. The signature is documented by
Forever's generated API docs and used by its own talent UI. The implementation is
original and feature-detected, with no frame creation or production API changes.
When available, `C_Spell.RequestLoadSpellData` primes each entry's spell once before
the tooltip phase.

Per-entry `tooltips` keep requested rank, status, error and left/right lines.
`tooltipExpected`, `tooltipReads`, `tooltipFailures`, and `tooltipReadsComplete`
summarize the second phase without conflating missing effects with unreadable trait
structure. Old captures remain supported by `tools/capture_check.py`; new captures
report tooltip gaps separately. Neither readable text nor a complete structure
promotes talent effects or build choices automatically.

The Warrior spec map now uses captured groups rather than inferred layouts.
`tests/trait_capture_test.py` replays the unchanged 52-node export through the API
wrapper and verifies tree membership, point totals and Protection detection. It also
checks isolated rank-call batches, missing/error/secret text and combat interruption.


### Captured talent effects

`tools/import_talent_effects.py` generates the Warrior `TalentEffects.lua` text catalog
from the latest complete rank capture in an unchanged probe export. It fails closed
on incomplete reads, missing/duplicate ranks, unreadable text or mismatched totals.
The catalog is loaded before builds and includes source/build/hash/level provenance.
`Engine.Talents.Plan` accepts this optional plain table and returns the upcoming
rank's text without changing the cached expanded order. The UI attaches it to the
next-point tooltip, including the observed level and a scaling caveat. Other classes
continue to plan without this catalog. `tests/talent_effects_test.py` checks exact Lua
text round trips, regeneration, import rejection cases and every Protection level.


### Readable planner presentation

The 640x620 window uses reusable Blizzard panel/button templates, a fixed context header,
role-aware tabs and direct spec/situation menus. Settings go through `Planner.Queue`;
no additional game data reads are introduced. The provisional status is a compact
badge with an explanation on hover. `BuildRows` can omit the banner for this fixed
header and include optional talent details. Errors remain visible in the content.

`UI/List.lua` measures wrapped labels and values when data or width changes, stores
row tops/heights, and rebinds a fixed viewport pool during pixel scrolling. The
viewport clips partial rows; the thumb tracks total text height. No fonts, tables,
frames or measurement work are created by scrolling. Size changes, opening and
control work defer or return during combat. `tests/ui_test.py` checks wrapping,
scroll bounds, menus, details, role/class fallback and combat deferral with mock
geometry; the existing allocation tests exercise the new list. Mock geometry is
not a live-client render and must not be used to claim pixel-perfect compatibility.

Explanation rows wrap inline and have no hover tooltip. List hover also suppresses
identical title/body text defensively; tooltips with extra captured data retain a
wrapped heading and one body. The UI tests cover both paths.


### Spell and talent icons

`API.SpellIcon(id, expectedName)` reads the optional `iconID` from the existing
`C_Spell.GetSpellInfo` API, cleans fields and checks the returned name before caching
a successful texture file ID. Missing/error/secret values and mismatched names do
not produce an icon. `ForgetSpells` clears the icon cache; spell-data-load events
also queue a new plan so unavailable data can be retried.

The planner gathers icons for known spells and talents in the selected build, using
captured talent IDs when available and imported rules otherwise. Name checking is
required for both. Reads yield every four requests, run only out of combat and are
published with the rest of the state. Engines and the UI perform no icon data reads.
UI rows reserve 32 pixels for a reusable 24-pixel texture; measurement uses the same
inset, and text-only rows reclaim it. Rebinding hides stale icons and changes the
texture only when the file ID changes. The perf suite measures icon-bearing scrolls.


### Native WoW presentation

The main window uses `BasicFrameTemplateWithInset` and `UIPanelButtonTemplate`,
already seen working in the original live window. It reuses the native close button
(with a `UIPanelCloseButton` fallback), gold/white/gray text, a tooltip-textured menu
backdrop and `UI-Quickslot2` icon borders. The generic blue fills are removed.
A transparent, narrower title drag region leaves the close button accessible.
Title, content and close button levels are explicit so the inset/header artwork
cannot hide the title/context or consume close-button clicks. Offline tests track
template choice, ownership and frame levels as well as existing behavior/performance.
