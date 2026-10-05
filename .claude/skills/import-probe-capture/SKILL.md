---
name: import-probe-capture
description: Turn a BattleplanProbe or GearwrightProbe JSON export into Battleplan facts and data - stat conversions, spell ranks, consumables, auras, threat, frame times - with provenance.
---

# Import a probe capture

Use when Jeff pastes or attaches a `/bpp export` (BattleplanProbe) or `/gwp export`
(GearwrightProbe) JSON.

## 1. Save it untouched

Save the JSON as `data/probe/YYYY-MM-DD-<topic>.json` (date of the capture, topic such as
`statlab-rogue-20`, `spells-priest`, `consumables`). Never edit a capture after saving it.
Check it parses: `python -c "import json,sys; json.load(open(sys.argv[1]))" <file>`.

## 2. Find what's in it

```
python - <<'EOF' <file>
import json, sys
d = json.load(open(sys.argv[1]))
print("statlab snapshots:", len(d.get("statlab", [])))
for kind, caps in d.get("captures", {}).items():
    print(kind, len(caps), [c["who"]["class"] + " " + str(c["who"]["level"]) for c in caps])
print("perf runs:", len(d.get("perf", [])))
EOF
```

Then run the checker, which compares spells, consumables, missing APIs and threat with
Battleplan's data and prints one `FIX` line per mismatch (`-v` also lists what matched):

```
python tools/capture_check.py data/probe/<file>.json
```

Work through its `FIX` lines in step 3. It only reports; the fixes, findings and `_status`
changes are still yours to make.

## 3. Act on each part

| Part | What to do |
|---|---|
| `statlab` | `python tools/stat_lab.py data/probe/*statlab*.json`. Commit `data/stats/conversions.json`. Add the per-point numbers (e.g. "Agility per 1% crit at 20") to `docs/BETA-FINDINGS.md`. Skipped pairs: tell Jeff which labels to redo and why. |
| `captures.spells` | Compare spell names with `Data/<CLASS>/Rotations.lua`, `Healing.lua`, `Tanking.lua`. Fix names exactly as the client spells them. Note whether lower ranks are listed (downranking) and whether costs and descriptions came through. |
| `captures.items` | Compare each item with `Data/Consumables.lua`: exists (has a name)? buff name (`spellName`)? amount (tooltip)? Fix amounts, drop items that don't exist on Forever, mark the file `verified` only when every entry is checked. |
| `captures.auras` | Record the aura names for food and elixirs; check `GetWeaponEnchantInfo` (`weapon.mainHand`) saw stones/oils. |
| `captures.threat` | Record whether threat is `ok` or `secret` in and out of combat. |
| `captures.env` | Record missing APIs; if Battleplan uses one, make `Core/API.lua` fall back and the mock (`tests/wowmock.py`) remove it. |
| `perf` | Compare frame times with Battleplan on vs off. Note results in `docs/BETA-FINDINGS.md`; anything worse with it on is a bug to chase with `/bplan perf`. |
| GearwrightProbe `talents` | New class tree: spec group IDs into `Data/<CLASS>/Specs.lua` `traitTabGroups`, talent names into builds (see the add-class skill). |
| GearwrightProbe trainer | Replace Classic `minLevel` values; remove the "Classic" comments for what's confirmed. |

## 4. Record provenance

Every fact goes in `docs/BETA-FINDINGS.md` "Confirmed" with the capture file name, and
comes off "Still to find out" / `docs/BETA-CHECKLIST.md` questions. Update `_status` on
data files whose every value is now traced to a capture.

## 5. Mirror the client in the mock

If the capture showed new client behaviour (an API missing, an event absent, a value
secret), make `tests/wowmock.py` behave the same and add a smoke check that Battleplan
handles it.

## 6. Verify and commit

Run the verify-change skill. Commit message names the capture, e.g.
"Confirm Rogue agility conversions from 2026-10-08-statlab-rogue-20".
