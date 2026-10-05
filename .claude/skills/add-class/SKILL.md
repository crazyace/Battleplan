---
name: add-class
description: Add a WoW Forever class (or a new role guide for an existing class) to Battleplan - data folder, spec IDs, builds, rotations, gear, healing or tanking guide, TOC entries, mock character and tests.
---

# Add a class

Example: adding `DRUID`. Class tokens are the second return of `UnitClass`, upper case.

## 1. What must already exist

- A talent tree capture (`/gwp talents` with points in each tree) for spec group IDs and
  talent names. **Without it, write no builds**: `Talents.lua` stays `_status = "todo"`
  and Battleplan works out spec tabs from the tree layout (`inferTabGroups`).
- Ideally a trainer capture for `minLevel` values. Without it, use Classic levels and
  mark them so in a comment.

## 2. Data files

Create `Battleplan/Data/DRUID/` by copying the closest existing class (Priest for a
healer, Warrior for a tank, Rogue for melee):

| File | Contents |
|---|---|
| `Specs.lua` | `order`, `names`, `roles` (`dps`/`healer`/`tank`), `traitTabGroups` (or `nil`), `leveling` spec, `usesMana`, `weaponKind` (`edged`/`blunt`/`any`) |
| `Weights.lua` | One table per spec; stat keys from `Data/Stats.lua`; include `HEAL_POTION`, and `MANA_POTION` if `usesMana` |
| `Talents.lua` | Per spec: `leveling = { title, summary, order = { {name, toRank}, ... }, why }`, other situations as aliases or `{ from = "leveling" }`. Check: points sum to 51, rows unlock at 5 points per row in that spec, every name exists in the capture |
| `Rotations.lua` | Per spec: `default` with `opener`, `priority`, `utility`; `dungeon`/`raid` overrides where play differs |
| `Gear.lua` | `enchants` by inventory slot ID, `targets = {}` until drops are captured |
| `Healing.lua` | Healer specs: `situations` (prefer list + `rank` policy), `partyHeals`, `manaPlan`, `cooldowns` |
| `Tanking.lua` | Tank specs: `single`, `multi`, `cooldowns`, `pullPlan`, `setups` |

Every file starts with a comment saying where its values came from, and `_status`.

Check a talent order quickly:

```
python - <<'EOF'
import re, sys
t = open("Battleplan/Data/DRUID/Talents.lua").read()
for spec, body in re.findall(r"(\w+) = \{\s*leveling = \{(.*?)\n    \},", t, re.S):
    have = {}
    for name, to in re.findall(r'\{ "([^"]+)", (\d+) \}', body):
        have[name] = max(have.get(name, 0), int(to))
    print(spec, sum(have.values()), "points")
EOF
```

## 3. TOC

Add the files to `Battleplan/Battleplan.toc` under `Data\`, in the order Specs, Weights,
Talents, Rotations, Gear, then Healing / Tanking.

## 4. Mock character and tests

In `tests/wowmock.py` add `DRUID_<level>` with talent `nodes` (`{ group, name, rank, x }`
using the real group IDs), a `book` of known spells (with cost, cast time and description
for heals), gear in `inv`, and `auras`.

In `tests/smoke_test.py` add a block that loads it and checks:
- detected spec and role,
- the tabs (`TabsFor`) match the role,
- the Talents tab shows the build title and a correct next point,
- the Rotation tab lists known spells in order and unknown ones under "Coming up",
- the role tab (Healing / Tanking) picks the expected spells.

Add the class to the perf test if it brings a new role guide.

## 5. Docs

- README: supported classes line.
- ROADMAP: tick the class off.
- docs/BETA-FINDINGS.md: spec group IDs and tree, with the capture.

## 6. Verify

Run the verify-change skill, then commit ("Add Druid: specs, healer guide, provisional builds").
