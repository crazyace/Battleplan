# Battleplan

Plan your build before the pull, for **World of Warcraft: Forever**.

Battleplan is an out-of-combat planner. It reads your talents, spells and gear and tells you:

- **Talents**: the build for your spec and situation (leveling, solo, dungeon, raid), where
  your next point goes, and where your current build differs from the plan.
- **Rotation**: a priority list filtered to the spells and ranks you actually know, so a
  level 22 character sees a level 22 rotation. When you learn something, it says where
  it goes.
- **Gear**: the best enchant for each slot and which ones you're missing, and the next
  potential upgrade to chase, with quest, crafter, vendor or drop leads.
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
lines on every item tooltip; Battleplan leaves those to it. Battleplan's suggested-gear
hover works the way Gearwright's item rows do. Battleplan's confirmed API facts come from
Gearwright's beta findings.

## License

Authored code: MIT - see [LICENSE](LICENSE). Imported external data retains its
upstream terms; see [data/external/NOTICE.md](data/external/NOTICE.md).

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

The window uses Blizzard’s framed panel, red buttons, gold headings, close button
and icon borders so it fits the WoW UI. Readable wrapping and direct controls remain.

The Tanking tab starts with **Before you pull**: equipment, your learned stance,
Bloodrage when learned, and pull size. Pull instructions omit abilities you have
not learned. Upcoming Warrior abilities can show client icons even before learning
them; this does not make them usable or verify their provisional learning levels.

The planner now starts at 760x700 with 14-point body/control text, 16-point section
headings and 32-pixel icons. Icon rims sit outside the image rather than overlapping
it. Use the footer **- / +** buttons to save a size preference (80–140%); the window
automatically fits smaller screens and respects WoW's own UI scale.

### Practical upgrade selection

The gear engine can compare quest, crafted, vendor and drop routes for each slot,
showing one next upgrade and one useful alternative with source/location and
requirements inline. Confirmed usable-now routes take priority; unknown availability
is explicitly labeled **Check requirements**. Crafted gear can come from another
player unless the item requires the wearer's profession.

The starter catalog now contains 133 client-derived crafted armor/cloak items for
Warrior, Rogue and Priest through level 30. Unconfirmed routes are marked **unconfirmed**,
and their hover says **Source not confirmed**, with the recipe and crafter profession. Equipped/bag
items are excluded. A live access/usability resolver and quest-source import are
still needed. Stat weights remain provisional; scores are not damage/healing percentages.
See [the gearing design](docs/GEAR-UPGRADES.md) for the policy and remaining work.

The first cohort uses each class's usual armor type and shared cloaks. It excludes
weapons, rings/trinkets, bind-on-pickup crafting, wearer-profession restrictions,
unknown stats and unmodeled item effects. It is a starter list, not a complete best-in-slot
catalog. Open `/bplan` and choose **Gear**; updates after equipment/level changes and
visible-window bag changes run outside combat. Regenerate with
`python tools/import_gear_catalog.py`; use `--check` to check the committed output.

## Full downloaded data

The complete downloaded JSON snapshot is preserved in `data/external/full-snapshot.zip`.
The Gear tab now draws provisional quest, crafting, vendor and drop options from
1,635 supported armor/cloak items across the three supported classes. All 22,069
item records remain available to developers; weapons, duplicate slots, effects and
unmodeled restrictions are excluded from ranking. Source access and live usability
still need confirmation. Classic-derived routes are explicitly labeled.

Run `python tools/import_full_data.py --check` to verify checksums and generation;
`python tools/import_full_data.py` regenerates the catalog from the preserved ZIP.
See [data provenance and licensing](data/external/NOTICE.md).

## Ability learn levels and Forever changes

`python tools/import_class_data.py` reads `classes.json` and `changes.json` from the
preserved snapshot and writes two files: `Data/SpellRanks.lua`, the learn level of every
rank of every trainer- or quest-taught ability for all nine classes, and
[docs/FOREVER-CHANGES.md](docs/FOREVER-CHANGES.md), what Forever changed from Classic
for each class. `--check` fails when either file is stale. Both are provisional.

The Rotation, Tanking and Healing tabs use the learn levels. A known spell with a
higher rank available at your level shows "Rank N at trainer". An upcoming ability with
no hand-written `minLevel` gets the imported one, and quest-taught abilities say
"quest" rather than "train now". `tests/class_data_test.py` also fails when a
hand-written `minLevel` disagrees with the import, or when a class's advice names a
talent or ability that Forever removed.

Gear suggestions are laid out like Gearwright's: one compact row per item with the
slot and name, a one-line source ("Crafted with Blacksmithing", "Quest: ..."), and the
score gain (with "level N" or "unconfirmed" under it when that applies). These
estimates describe modeled static stats, not DPS/healing gains; unavailable equipped
stats block comparisons.

Each slot shows one row. When a slot has more than one option, click the row to open
its picker: every option for that slot (up to 12), grouped under Quests, Crafted,
Vendors and Drops, each with its gain, and the recommendation marked. Hover an option
for its tooltip; click one to chase it instead. The row then shows your pick, saved per
slot by item ID; pick the recommendation again to go back. A saved pick that stops
being an option (you got it, or it's no longer an upgrade) falls back to the
recommendation. Bind-on-pickup crafted gear only appears if you have that profession
(read from the game, and refreshed when you learn or drop one); anyone can buy the
other crafted items from a crafter.

Hover a suggested item for the game's own item tooltip, with Battleplan's details under
it: score gain and percentage, the item it replaces (or that the slot is empty), stat
gains and losses, the full source with requirements, and any provisional or
unconfirmed warning. Shift-click the row to link the item in chat. Battleplan asks the
server for each suggested item once, so the tooltip is complete on the first hover;
the tooltip stays up while the list redraws under the mouse.
