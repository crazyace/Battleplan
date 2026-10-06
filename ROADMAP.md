# Battleplan roadmap

Built around Forever's schedule: beta until **Oct 22** (level 30 cap), launch **Nov 4**,
first raids **Dec 9**.

## Dev workflow

How every phase below gets done. Details in [AGENTS.md](AGENTS.md).

- **Work autonomously.** Ask questions only when absolutely necessary: when the answer
  isn't in the repo, the docs or a capture, and a wrong guess would be costly or hard to
  undo. Otherwise decide, note the decision, and keep going.
- **Production grade, not a hack.** Every change is tested, linted, documented, reviewed
  against the definition of done, committed with a clear message, and pushed with CI green.
- **AGENTS.md and skills** hold the concrete guidelines: coding and performance rules,
  testing, data provenance, commits, and step-by-step procedures in
  [.claude/skills/](.claude/skills/) for verifying a change, importing a probe capture,
  adding a class, adding a game API read, and updating data.
- [x] AGENTS.md with development guidelines and the definition of done
- [x] Skills: verify-change, import-probe-capture, add-class, add-game-api, update-data
- [x] Architecture rules enforced in CI (`tests/test_rules.py`)
- [x] Local gate: `scripts/check.sh` + pre-push hook; CI runs the same script (repo is public, so Actions is free)

## Phase 0: stat lab and beta data (now - Oct 22)

- [x] BattleplanProbe: stat snapshots and diffs, spellbook ranks and costs, auras,
      consumable effects, threat check, frame times, JSON export
- [x] `tools/stat_lab.py`: snapshots -> `data/stats/conversions.json`
- [x] `tools/capture_check.py`: probe export vs Battleplan's data (spells, items, APIs, threat)
- [ ] Stat lab at levels 10, 20, 30 for Rogue, Priest and Warrior ([docs/BETA-CHECKLIST.md](docs/BETA-CHECKLIST.md))
- [ ] Spell ranks and costs (`/bpp spells`), Priest and Warrior trainers
- [ ] Consumables checked in game (`tools/consumable_ids.py`)
- [x] Warrior talent tree captured; fill `Data/WARRIOR/Specs.lua` with confirmed groups
- [x] Capture all 150 Warrior rank tooltips and import a verified text catalog
- [x] Add and validate a provisional 51-point Protection shield leveling path
- [ ] Model and play-test Warrior builds, including Arms/Fury and raid allocations

## Phase 1: theorycraft from real numbers (Oct - launch)

- [ ] `tools/theorycraft/`: per-spec models (DPS, healing per mana, mitigation) that read
      `conversions.json` and write Weights, Talents and Rotations as Lua tables
- [ ] Replace provisional Rogue weights and builds with model output
- [ ] Holy and Discipline healing model: downranking and mana plan from measured regen
- [ ] Protection Warrior mitigation weights, with the 440 Defense raid-boss crit cap
      ([BETA-FINDINGS](docs/BETA-FINDINGS.md))

## Phase 2: launch (Nov 4)

- [x] Window: talents, rotation, gear, consumables, healing or tanking tabs
- [x] Dormant in combat; time-sliced planning; perf test in CI
- [ ] Recheck every conversion at level 60
- [ ] Upgrade targets per slot from dungeon drops (probe loot log, Gearwright's captures)
- [ ] Settings panel (situation, spec, reminders) besides slash commands
- [ ] CurseForge / Wago listing

## Phase 3: raids (Dec 9)

- [ ] Raid builds and raid consumable sets
- [ ] More classes: Mage, Warlock, Hunter, Druid, Paladin, Shaman
- [ ] Healer guides for Druid, Paladin and Shaman; tank guides for Druid and Paladin

## Review fixes and database integration (2026-10-05)

- [x] Recover from planner errors without publishing partial results
- [x] Refresh displayed buffs and bag counts; recheck combat when timers fire
- [x] Preserve unreadable equipped stats as unknown and retry on item-data events
- [x] Import a reproducible provisional structural catalog for all nine classes
- [x] Validate build orders, next-point prerequisites and generated Lua in CI
- [x] Repair Combat, Holy and Discipline prerequisite order without changing 51-point totals
- [ ] Confirm imported prerequisite rules against each class's beta talent capture
- [ ] Interpret additional gate/prerequisite condition fields after client verification
- [x] Add native `/bpp talents` with batched reads, raw prerequisites and explicit incomplete captures
- [x] Confirm Warrior spec groups and replay the 52-node live capture in tests
- [x] Add a separately batched per-rank talent tooltip collector
- [x] Confirm native rank-tooltip results in the live client before promoting effects
- [x] Import captured Warrior spell ranks/costs/text with build and source hashes; CI checks regeneration
- [x] Add provisional known-spell starter rotations for Arms, Fury and Protection
- [ ] Extend Warrior rotations to higher-level/talent abilities after captures and modeling
- [ ] Extend the importer to other classes, eligible items, enchants and consumable aura IDs,
      preserving source/build labels and availability evidence
- [ ] Use models and captures to account for caps, procs, set bonuses, weapon restrictions
      and consumable stacking before expanding upgrade or best-consumable claims


### Planner usability

- [x] Replace the cramped window with a larger, calmer layout and clear selected tabs
- [x] Wrap advice/item text in measured, reusable rows without scroll allocations
- [x] Add direct spec/situation controls and compact provisional status
- [x] Prioritize the next talent/rank and put full reasoning behind a details toggle
- [ ] Live-client visual check after maintenance: wrapping, menus, tooltips, scrolling,
      title dragging and Escape at the player's UI scale

- [x] Remove duplicated explanation tooltips; preserve captured-detail tooltips

- [x] Add optional client spell/talent icons with name checks and reusable textures
- [ ] Confirm icon display and capture icon IDs on Forever after maintenance

- [x] Restore native WoW frame/buttons and fix header layering; retain icons and wrapping
- [ ] Verify the restored native window, title/context and menu appearance in the client

- [x] Resolve client icons for upcoming Warrior abilities without marking them learned
- [x] Replace Safe/Threat setup prose with preparation filtered to learned abilities
- [ ] Live-check upcoming ability icons and level-appropriate tank preparation

- [x] Fix icon rims to enclose images; enlarge text, icons, window and controls
- [x] Add saved size controls and automatic screen fitting outside combat
- [ ] Live-check larger typography, rim geometry and size controls at different UI scales

### Practical leveling gear

- [x] Compare structured quest, crafted, vendor and drop routes by slot
- [x] Keep one primary plus one meaningful alternative; label unknown access and future level
- [x] Add observed-context guards and provisional small-gain/easier-route policy
- [x] Show source, location, requirements and crafting access inline; bound large-catalog work
- [ ] Establish an approved redistribution path for quest/crafting/source data
- [ ] Import source-linked item stats with provenance and build/version checks
- [ ] Add probe-confirmed live item usability, ownership, quest completion and access resolver
- [ ] Validate two-slot rings/trinkets and weapon-pair changes before recommending swaps
- [ ] Add quest pickup/chain guidance and map links backed by confirmed client APIs
- [ ] Use known material/recipe availability and observed prices; never estimate costs from source kind
- [ ] Live-test practical upgrades as players level; tune scoring/churn policy from results

- [x] Connect a dated provisional client-derived crafted armor/cloak starter catalog
- [x] Label potential upgrades and unconfirmed sources; filter equipped/bag ownership
- [x] Keep recipe profession separate from wearer requirements and skip restricted/effect items
- [ ] Live-check starter Gear tab icons, ownership updates and imported stats on Forever
- [ ] Expand source coverage with approved quest/vendor/drop feeds and verified access checks

## Full collected data milestone

- [x] Import learn levels for every rank of every trained ability, all nine classes (`Data/SpellRanks.lua`)
- [x] Generate a per-class Forever-vs-Classic change report (`docs/FOREVER-CHANGES.md`) and gate our data against it
- [ ] Confirm imported learn levels against Priest and Warrior trainer captures, then mark verified
- [ ] Use the imported enchants, item sets and dungeon data

- [x] Preserve every downloaded JSON record and collection manifest with checksums and upstream credits/licenses
- [x] Generate a lazy provisional armor catalog with quest, crafting, vendor and drop routes
- [x] Filter observed faction/completed quests and retain unknown access honestly
- [ ] Confirm optional faction/quest APIs and new source details in a live probe capture
- [ ] Model weapons, duplicate slots, effects and restricted items before ranking them
- [ ] Verify acquisition effort, quest chains, crafter requirements and locations on Forever

- [x] Explain selected upgrades with equipped-stat gains/losses and estimated score gain
- [x] Hover a suggested item for its item tooltip plus gain, replaced item and source; shift-click links it
- [x] Compact Gearwright-style gear rows; keep the hover tooltip up across replans
- [x] Per-slot picker: every quest, crafted, vendor and drop option; the player's pick is saved
- [x] Bind-on-pickup crafted gear only for players with that profession (read live)
- [ ] Live-check suggested-item hover tooltips and shift-click links on Forever
- [x] Distinguish empty slots, zero-score equipment and unreadable equipped links
- [ ] Live-check primary/alternative comparisons against equipped and item tooltips
