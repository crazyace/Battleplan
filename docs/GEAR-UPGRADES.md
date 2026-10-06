# Practical leveling upgrades

The player needs the next worthwhile upgrade for a slot and a practical way to
obtain it. Quest rewards, player-made gear, vendors and drops compete in the same
candidate set. A craftable item does not require the wearer to be its crafter.

## Selection implemented in this milestone

1. Exclude known unusable items, already-owned items, opposite-class/faction routes,
   completed one-time quests and routes explicitly observed to be blocked.
2. Keep only positive weighted-stat gains and gear within five levels. An unknown
   equipped score blocks comparisons for that slot; an empty slot starts at zero.
3. For structured routes, filter gains below 5% of the equipped weighted score.
   This is a provisional anti-churn policy, adjustable through `minGainFraction`.
   It is not a claim about damage, healing or mitigation percentages.
4. Prefer usable-now gear, then confirmed access, then the strongest score gain.
   Equipment usability and source access are separate checks; missing observations
   remain unknown. Quest prerequisites and wearer-profession requirements must also
   be known before a route is presented as available.
5. Prefer an explicitly easier route if it keeps at least 80% of the strongest
   option's gain. Both routes must be available now and have known effort bands.
   These bands must be based on acquisition evidence, not guessed from source kind.
   Unknown effort never means expensive. The 80% rule is also provisional policy.
6. Show one primary and at most one alternative per slot. Keep a materially stronger
   item when an easier item wins, otherwise the strongest different acquisition
   kind at the same availability/level status. Do not duplicate the same item.
7. Show a compact row (slot, name, one-line source, gain) and put source/location,
   requirements, provisional provenance and availability in the hover under the item
   tooltip. Future gear shows its required level; unknown access shows "unconfirmed" on
   the row, and the hover says Source not confirmed with a requirements warning.

A deterministic item ID / route-key tie break prevents catalog ordering from changing
recommendations. Catalog collection and selection yield in batches of 32. The engine
stays pure and consumes plain data; the planner owns out-of-combat scheduling.

## Data contract

A target retains `slot`, `itemID`, `name`, `minLevel`, `stats` and provenance, and adds
`routes`. Item restrictions can use `classes = { CLASS = true }`.

| Route field | Meaning |
|---|---|
| `key` | Stable unique acquisition route key |
| `kind` | `quest`, `craft`, `vendor` or `drop` |
| `name`, `location`, `requirements` | Source and actionable details, when known |
| `questID`, `prerequisites`, `repeatable` | Quest eligibility and chain information |
| `minLevel`, `faction`, `classes` | Acquisition restrictions, separate from wearing level |
| `profession` | Profession of the producer; does not restrict the wearer |
| `wearerProfession`, `wearerSkill` | Actual wearer requirement, only when evidenced |
| `effort` | Evidence-backed band: 1 easy, 2 moderate, 3 involved; omitted when unknown |
| `_status` | Provenance status; missing/unverified data is visibly provisional |

Observed context is supplied independently:

| Context field | Meaning |
|---|---|
| `class`, `faction`, `professions` | Known player restrictions/skill values |
| `access[routeKey]` | `available`, `blocked`, or unknown; never inferred from catalog presence |
| `usable[itemID]` | true, false or unknown; must cover armor, weapons and wearer restrictions |
| `owned[itemID]` | Item already acquired; avoid suggesting the player acquire it again |
| `completedQuests[questID]` | Observed completion for one-time rewards and prerequisites |
| `minGainFraction` | Optional nonnegative churn threshold; default 0.05 |

Legacy targets with a text `source` retain their previous behavior until migrated.
They should not be used to bypass the checks for newly imported source data.

## Work required before real quest/crafting recommendations

The planner passes class and observed equipped/bag ownership. The shared catalog
contains 133 provisional crafted armor/cloak items for the three supported classes
through level 30 (44 Warrior, 60 Rogue and 49 Priest entries, with shared cloaks).
Usual armor-type selection is a conservative cohort filter, not a live usability claim.
It excludes weapons, duplicate slots, bind-on-pickup crafting, wearer profession or
specialization restrictions, new/test candidates, unsupported stats and item effects.
It does not claim to know quest completion, recipe access, material costs,
item usability or actual acquisition time.

The cached ForeverDB quest JSON contains 293 quests, 134 with item rewards and 187
unique reward items matching the existing local item snapshot. It is not included in
this repository. Its source declares GPL-3.0 / CMaNGOS classic-db; an approved
redistribution path is required under this repository's MIT-compatible source policy.
Most cached records are Classic-derived and need Forever confirmation. Other feeds
must be reviewed individually rather than assumed to share item-data licensing.

The crafted cohort uses client-derived items.json and crafting shard facts only;
recipe skill values are deliberately omitted because snapshot fields conflict.
It imports no Classic quest/loot source records or website/addon code. The input
preserves selected original item records and recipe tuples, build/date and source
hashes. Regenerate with tools/import_gear_catalog.py; no external source file is
needed for CI. The default generation cannot promote the data to verified.

Next milestones must expand source-linked records with version/provenance,
confirm APIs with the probe for usability/completion, then wire observed
context through Core/API and the planner. Quest pickup/chain/map guidance follows
confirmed client support. Costs and effort stay unknown until supported by evidence.
Do not classify all crafting as expensive or all quest rewards as free/easy.

Before weapon swaps, model two-hand/off-hand changes and spec restrictions together.
Before duplicate-slot suggestions, compare both rings/trinkets and ownership. Initial
stat scores cannot faithfully value every proc, set bonus or weapon effect; those
items need explicit model coverage before being called the best upgrade.

## Full collection import

The complete external JSON collection is preserved; 1,635 items currently have
supported static armor stats, modeled slots, and at least one identified source.
Quest, vendor, drop and craft routes share the same scoring model. Raw data also
retains spells, talents, recipe ingredients, quest rewards and all source associations.
Existing verified class/build data is not overwritten by external records.

The runtime uses up to two representative routes per acquisition kind and faction;
the full associations stay in the archive. Quest names, known prerequisite IDs,
givers and locations are included where supplied. Faction and completed one-time
quests are filtered only when the optional client read succeeds. Bind-on-pickup
crafts say to craft the item yourself. Class-specific quests remain unconfirmed.
Dungeon levels are provisional acquisition floors, not verified entrance rules.
No drop rates, prices, travel-time estimates or recipe skill requirements are invented.

Weapons, jewelry/trinket duplicate slots, set bonuses, proc effects, profession/class/
reputation restrictions and missing source/level facts remain reference data until
the model supports them. `data/external/catalog-report.json` accounts for every item.
All imported recommendations remain Potential upgrades; these data do not prove
source availability or equipment usability.

## Explain an upgrade before chasing it

Every selected primary/alternative now includes the estimated gain against the
equipped weighted stat score, even when acquisition access is unknown. Gains and
losses show actual differences in the modeled stats. Percent changes in chance
stats are percentage-point differences; the score percentage is an estimate from
the current weights, never a damage, healing or mitigation percentage.

An empty slot starts at zero and has no percentage against zero. An equipped item
with a zero weighted score remains equipped. Secret/unreadable links or item stats
block the slot instead of being treated as empty. Effects, set bonuses and unmodeled
stats are outside this comparison. Source warnings and future wearing levels stay
visible, and selection policy is unchanged.
