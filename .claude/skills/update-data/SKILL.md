---
name: update-data
description: Change Battleplan's game data - talent builds, rotations, stat weights, consumables, enchants, healing or tanking guides - keeping provenance, _status and tests right.
---

# Update game data

Data lives in `Battleplan/Data/`. It's the part players judge Battleplan by, so every
change keeps its source visible.

## 1. Where the value comes from

| Source | Allowed for | Mark as |
|---|---|---|
| A probe capture in `data/probe/` | Anything | Can make the file `verified` once every value is traced |
| `data/stats/conversions.json` + a theorycraft model | Weights, build and rotation choices | `provisional` until checked in play, then `verified` |
| Classic values | Starting points only | `provisional`, with `source = "classic"` on the entry or a comment |
| Wowhead's Forever database | Leads to confirm | `provisional`, comment "Wowhead Forever, unconfirmed" |
| Another addon's data | Only MIT or compatible, credited | As its source |

Never invent talent, spell or item names. If something isn't captured, leave it out and
leave `_status = "todo"` where it would go.

## 2. Make the change

- **Talent builds** (`Talents.lua`): each step raises a talent *to* a rank. Keep the total
  at 51, keep each row reachable (5 points per row in that spec), and update `why` for any
  key talent that changes. Use the point-count check in the add-class skill.
- **Rotations**: order is priority. Each entry has `minLevel` (trainer) or `talent = true`,
  and a short `note` a player can act on ("Finisher at 5 combo points.").
- **Weights**: one table per spec, stat keys from `Data/Stats.lua`. Say in the file's
  header which conversions they come from.
- **Consumables**: one stat per entry (`extra` for secondary effects), real `itemID`,
  `minLevel` from the tooltip. Potions use `amount` as a tier.
- **Enchants**: keyed by inventory slot ID; `recipe` is the recipe spell ID from the
  Enchanting window; `source = "classic"` until confirmed.
- **Healing / Tanking guides**: spell names exactly as the spellbook shows them.

Write player-facing text plainly: short sentences, the action first, no jargon a new
player wouldn't know.

## 3. Update `_status` and findings

Set `_status` to what's true for the whole file. Add confirmed facts to
`docs/BETA-FINDINGS.md` with their capture.

## 4. Test

- Update the expected lines in `tests/smoke_test.py` for any tab whose output changed, and
  check the new output reads correctly (run the test and read the screen dump).
- New consumables: `python tools/consumable_ids.py` still lists every ID once
  (`tests/test_tools.py` checks this).

## 5. Verify and commit

Run the verify-change skill. Commit message says what changed and the source, e.g.
"Raise Combat hit weight to 20 from Rogue stat lab at 30".
