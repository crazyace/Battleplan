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
> **Warrior** (tank). Spec detection, talent names and rating rates are confirmed on the
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
tests/               smoke, perf, tools and rules tests (mocked client, Lua 5.1)
data/probe/          Probe captures (raw research data)
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
| `/bpp export` | Probe: copyable JSON of everything recorded |

## Related

[Gearwright](https://github.com/crazyace/Gearwright) does item scoring and tooltip upgrade
lines; Battleplan leaves tooltips to it. Battleplan's confirmed API facts come from
Gearwright's beta findings.

## License

MIT - see [LICENSE](LICENSE).
