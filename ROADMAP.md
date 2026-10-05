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
- [ ] Warrior talent tree captured; fill `Data/WARRIOR/Specs.lua` and write Warrior builds

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
