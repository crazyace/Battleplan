# Battleplan

Plan your build before the pull, for **World of Warcraft: Forever**.

Battleplan is an out-of-combat planner. It reads your talents, spells and gear and tells you:

- **Talents**: the build for your spec and situation (leveling, solo, dungeon, raid), where
  your next point goes, and where your current build differs from the plan.
- **Rotation**: a priority list filtered to the spells and ranks you actually know, so a
  level 22 character sees a level 22 rotation. When you learn something, it says where
  it goes.
- **Gear**: the best enchant for each slot and which ones you're missing, and the next
  upgrade to chase (once the upgrade lists are filled in).
- **Consumables**: the best elixir, weapon stone or oil, food and potions for your spec,
  level and situation, what's in your bags, and which buffs are missing before a pull.
- **Healers**: which heal for which situation, a healing-per-mana table built from your own
  spell ranks, and a mana plan.
- **Tanks**: threat priority for one target and for packs, a pull plan, and cooldowns.

There's no in-combat display. Forever hides enemy health from addons, so a live "cast this
next" prompt can't be made reliable. Battleplan does its work between pulls and does
nothing in combat.

> **Status: pre-alpha.** v1 covers **Rogue** (DPS), **Priest** (healer and Shadow) and
> **Warrior** (provisional shield leveling build, tank guide, and starter Arms/Fury rotations). Spec detection, talent names and rating rates are confirmed on the
> beta; builds, rotations and consumable values are first drafts until the stat lab has
> real numbers. The window says so while anything is provisional. See [ROADMAP.md](ROADMAP.md).

## Built not to hitch

Performance is a requirement, not a nice-to-have ([docs/BUILD-GUIDE.md](docs/BUILD-GUIDE.md)):

- Dormant in combat: every refresh waits until combat ends, then runs once.
- Bursty events (gear, bags, auras) are coalesced into one refresh.
- The plan runs as a time-sliced job, at most 2 ms per frame.
- The window is built the first time you open it, fades in with client-side animations,
  and reuses a fixed set of row frames.
- `tests/perf_test.py` fails the build if a job slice goes over budget or a hot path
  allocates memory.

## Repo layout

```
Battleplan/          The addon players install
  Core/              Init, events, scheduler, perf timing, API wrapper, planner, commands
  Data/              Stats, consumables, and per class: specs, weights, talents,
                     rotations, gear, healing or tanking guides
  Engine/            Pure logic, no game calls: spec, talents, rotation, gear,
                     consumables, healing, tanking
  UI/                Window, tabs, recycled row list, animations
BattleplanProbe/     Dev-only addon: stat lab, spellbook ranks and costs, auras,
                     consumable effects, frame times
tools/               stat_lab.py (snapshots -> conversion table), consumable_ids.py,
                     capture_check.py (probe export vs Battleplan's data)
tests/               smoke, perf, regression, tools and rules tests (mocked client, Lua 5.1)
data/probe/          Probe captures (raw research data)
data/talents/        Dated structural talent snapshot used to validate build orders
data/stats/          conversions.json from the stat lab
docs/                BUILD-GUIDE, ARCHITECTURE, BETA-CHECKLIST, BETA-FINDINGS
AGENTS.md            Dev workflow and guidelines (CLAUDE.md points here)
.claude/skills/      Procedures: verify-change, import-probe-capture, add-class,
                     add-game-api, update-data
```

## Development setup

Read [AGENTS.md](AGENTS.md) first: how we work, coding and testing guidelines, and the
definition of done. Step-by-step procedures are in [.claude/skills/](.claude/skills/).


1. Clone the repo.
2. Link both addon folders into Forever's AddOns folder, which is
   `<WoW>\_classic_beta_\Interface\AddOns` on the beta (Windows, as admin):

   ```
   mklink /J "<WoW>\_classic_beta_\Interface\AddOns\Battleplan"      "<repo>\Battleplan"
   mklink /J "<WoW>\_classic_beta_\Interface\AddOns\BattleplanProbe" "<repo>\BattleplanProbe"
   ```

3. In game, `/reload` after edits.

Once per clone:

```
pip install "lupa>=2.0"
luarocks install luacheck            # optional locally, but recommended
git config core.hooksPath .githooks  # runs every check before each push
```

Before committing: `python scripts/check.py` (PowerShell, cmd or any shell; `sh scripts/check.sh`
does the same). The tools in `tools/` expand `*` wildcards themselves, so the commands in the
docs work as written in PowerShell.

## Commands

| Command | What it does |
|---|---|
| `/bplan` | Open or close the window |
| `/bplan situation <auto\|leveling\|solo\|dungeon\|raid>` | Advise for a situation (auto: leveling below 60, dungeon at 60) |
| `/bplan spec <auto\|name>` | Advise for another spec |
| `/bplan buffs` | Which consumable buffs are missing |
| `/bplan buffcheck` | Turn the dungeon/raid zone-in reminder on or off |
| `/bplan perf [on\|off\|reset]` | Handler timings; anything over budget shows in red |
| `/bpp stats [label]` | Probe: stat lab snapshot ([docs/BETA-CHECKLIST.md](docs/BETA-CHECKLIST.md)) |
| `/bpp talents` | Probe: capture trait structure and a separate tooltip for each talent rank outside combat |
| `/bpp spells` | Probe: capture learned spell ranks, costs and descriptions |
| `/bpp all` | Probe: environment, spells, talents, auras and stats; wait for talent completion before exporting |
| `/bpp export` | Probe: copyable JSON of everything recorded |

## Related

[Gearwright](https://github.com/crazyace/Gearwright) does item scoring and tooltip upgrade
lines; Battleplan leaves tooltips to it. Battleplan's confirmed API facts come from
Gearwright's beta findings.

## License

MIT - see [LICENSE](LICENSE).

## Talent catalog and refresh validation

`python tools/import_talent_catalog.py` generates `Data/TalentRules.lua` from
`data/talents/catalog.json`. `--check` detects stale generated output. The imported
ForeverDB snapshot (build 1.60.1.70205) contains structural rules for all nine classes;
it remains provisional. It does not add recommended builds for unsupported classes.

Every Rogue/Priest build order is checked for rank limits, minimum levels, points in
its tree and prerequisites. Invalid plans are withheld with a reason. The engine also
checks the next point against the character's actual talents. The current Combat,
Holy and Discipline orders place their prerequisites before Riposte, Prayer of Mending
and Renewed Hope while retaining 51 total points.

Aura changes and bag changes refresh their displayed values out of combat. Timers
recheck combat before executing. Failed plans keep the last completed result and can
retry on the next refresh. Unavailable equipped stats show a waiting message and
cannot produce an upgrade comparison until item data arrives.

`python scripts/check.py` now includes `tests/regression_test.py`, which covers these
behaviors and checks that the generated catalog matches its snapshot.

## Warrior capture integration

`python tools/import_spell_catalog.py` regenerates `Data/WARRIOR/Spells.lua` from
`data/probe/2026-10-05-warrior-12-followup.json`; `--check` detects stale output in CI.
The catalog records observed ranks, costs, text, build and source hash. A spell known
at level 12 is not proof of its trainer level. Current cooldown duration is not a
base cooldown, so neither becomes a learning requirement or cooldown model.

Arms, Fury and Protection have provisional starter rotation guides filtered to your
learned spells and highest ranks. Hover a captured spell row for its dated reference
text; a new rank never inherits an older rank's text. Higher-level abilities and
Warrior talent builds remain on the roadmap.

For the next live capture, update **BattleplanProbe** too, then run `/bpp talents`
outside combat. Wait for the completion message and run `/bpp export`. Reads are
batched; metadata and per-rank tooltip reads run in separate batches of four. Combat
or a config change produces an explicitly incomplete capture that can be retried. Raw conditions and edges are retained for validation, not interpreted
as confirmed spending rules automatically.

Warrior spec detection now uses the captured group IDs directly: Arms `11650`, Fury
`11657`, Protection `11670`, all in tree `1117`. The live level-12 allocation replays
as three points in Shield Specialization and selects Protection.

`/bpp talents` requests `C_TooltipInfo.GetTraitEntry(entryID, rank)` for every rank,
so passive talents no longer depend solely on generic spell descriptions. The export
stores each rank's left/right tooltip lines and status separately. `complete` covers
structural reads; `tooltipReadsComplete` covers readable rank text. A missing tooltip
API or empty/secret/error result preserves the usable structure and reports the gap.
The new tooltip path remains unconfirmed until its first live export; readable text
still needs review before it can support optimized builds.

### Warrior talent effects

Protection has a provisional 51-point shield leveling path, with Shield Slam planned
at level 40. The next-point tooltip shows the exact captured rank text and the capture
level. All 52 Warrior talents / 150 ranks are imported from the live client; the point
order still needs play testing. Arms/Fury builds and optimized raid allocations remain
unfinished. Rebuild the text catalog with `python tools/import_talent_effects.py`; use
`--check` to detect stale generated data. No additional in-game command is needed.

### Planner window

Open `/bplan` outside combat. Use the **Spec** and **Situation** controls to change
advice directly; **Auto** shows the resolved choice and follows your talents/level.
The Talents tab highlights the next point and its target rank, then explains that
choice. **Show build details** expands the remaining talent reasons. Explanations
and item names wrap instead of being cut off; scroll for longer guides and hover
for extra captured spell/rank text. Inline explanations do not repeat on hover. Drag the title bar to move the window; Escape closes it.

Spell rows and the next talent point show the client's icon beside the text when it
is available. Full build details also show talent icons. Missing icon data keeps a
text-only row; names and ranks remain visible. Update BattleplanProbe as well to
include icon IDs in future `/bpp spells` and `/bpp talents` exports.
