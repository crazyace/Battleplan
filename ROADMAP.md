# Battleplan roadmap

Built around Forever's schedule: beta until **Oct 22** (level 30 cap), launch **Nov 4**,
first raids **Dec 9**.

## Phase 0: stat lab and beta data (now - Oct 22)

- [x] BattleplanProbe: stat snapshots and diffs, spellbook ranks and costs, auras,
      consumable effects, threat check, frame times, JSON export
- [x] `tools/stat_lab.py`: snapshots -> `data/stats/conversions.json`
- [ ] Stat lab at levels 10, 20, 30 for Rogue, Priest and Warrior ([docs/BETA-CHECKLIST.md](docs/BETA-CHECKLIST.md))
- [ ] Spell ranks and costs (`/bpp spells`), Priest and Warrior trainers
- [ ] Consumables checked in game (`tools/consumable_ids.py`)
- [ ] Warrior talent tree captured; fill `Data/WARRIOR/Specs.lua` and write Warrior builds

## Phase 1: theorycraft from real numbers (Oct - launch)

- [ ] `tools/theorycraft/`: per-spec models (DPS, healing per mana, mitigation) that read
      `conversions.json` and write Weights, Talents and Rotations as Lua tables
- [ ] Replace provisional Rogue weights and builds with model output
- [ ] Holy and Discipline healing model: downranking and mana plan from measured regen
- [ ] Protection Warrior mitigation weights; check whether a defense cap exists

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
