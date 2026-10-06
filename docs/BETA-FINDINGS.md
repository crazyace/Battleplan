# Beta findings

What Battleplan relies on, and where it came from. Most of the client facts were
established by GearwrightProbe (see Gearwright's `docs/BETA-FINDINGS.md`, captures in
that repo's `data/probe/`). Battleplan's own captures go in this repo's `data/probe/`.

## Confirmed (beta client 1.60.1, build 70205)

| Fact | Value | Source |
|---|---|---|
| Interface number | 16001 | Gearwright, 2026-10-03 |
| AddOns folder | `<WoW>\_classic_beta_\Interface\AddOns` | Gearwright setup |
| API style | Mainline: `C_Item`, `C_Spell`, `C_TooltipInfo`, `TooltipDataProcessor`, `C_Traits` | Gearwright |
| Removed globals | `GetItemStats`, `GetItemInfoInstant`, `GetSpecialization` (use `C_*`) | Gearwright |
| Talent API | `C_ClassTalents` + `C_Traits`; one tree per class holds all three specs | Gearwright |
| Rogue spec groups | 11580 Assassination, 11573 Combat, 11572 Subtlety | Gearwright |
| Priest spec groups | 11608 Discipline, 11615 Holy, 11622 Shadow | Gearwright, 2026-10-04 |
| Priest duplicate node | A second "Holy Specialization" node; keep the higher rank | Gearwright |
| First talent point | Level 10, then one per level | Gearwright |
| Secret values | `issecretvalue` exists; nothing read out of combat was secret | Gearwright |
| SavedVariables | Persist across sessions | Gearwright |
| Ratings per 1% | Hit 10, Crit 14, Haste 10, Expertise 10, Parry 15, Defense 1 | Gearwright, tooltips and AH scan |
| Rogue Agility | ~7.6 Agility per 1% crit at level 19; 1 AP per Agility and Strength | Gearwright character sheet |
| Priest Intellect | 9.6 Intellect per 1% spell crit at level 12 | Gearwright character sheet |
| Rogue trainer levels | SS 1, Backstab 4, Gouge 6, Evasion 8, SnD 10, Kick 12, Garrote 14, Feint 16, Ambush 18, Rupture 20, Vanish 22, Cheap Shot 26, Kidney Shot 30 | Gearwright trainer capture |
| Mutilate | Talent rank 1; no dagger requirement; attacks with both weapons | Wowhead Forever database |
| Enchant amounts | Bracer Agility 1217203 / Superior Agility 1248599: +9; Cloak Minor and Lesser Agility: +3; Chest Minor/Lesser Stats +2, Living Stats +4 | Gearwright Enchanting capture |

## Battleplan's own captures

`W12` = [data/probe/2026-10-05-warrior-12.json](../data/probe/2026-10-05-warrior-12.json): Human
Warrior level 12, `/bpp all` twice, `/bpp threat` out of combat, `/bpp items` for every consumable;
plus a screenshot of the same character's Defense tooltip.

| Fact | Value | Source |
|---|---|---|
| Classic globals missing | `UnitBuff`, `GetItemSpell`, `GetSpellPowerCost`, `GetNumSpellTabs`, `GetSpellTabInfo`, `GetSpellBookItemName`, `GetSpellBookItemInfo`, `UnitDefense`. All but `UnitDefense` have a `C_*` version, and Battleplan only uses the old ones as fallbacks | W12 env, stat lab |
| Defense skill | The character sheet shows it (57 / 60 at level 12). `UnitDefenseSkill("player")` returns base 57, modifier 0, matching the sheet (`UnitDefense` is gone). Max is 5 x level; each point above max is 0.04% dodge, block, parry and less chance to be hit or crit, hence 0.00% at 57 | [Blizzard UI source](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot), `Camelot/PaperDollFrameStats.lua`, [W12 defense export](../data/probe/2026-10-05-warrior-12-defense.json) stat lab, [defense tooltip](../data/probe/2026-10-05-warrior-12-defense-tooltip.png) |
| Defense cap | 440 Defense: can't be critically hit by raid bosses (the tooltip calls it -5.60% crit chance: 140 points above the level 60 max of 300, at 0.04% each). It matches the UI's formula: enemy crit = 5% + 0.04% x (5 x enemy level - defense), and a level 63 boss has 315 skill. Crits do 200%; creatures 3+ levels above you can crush for 150% | [defense tooltip](../data/probe/2026-10-05-warrior-12-defense-tooltip.png), [Blizzard UI source](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_UIPanels_Game/Camelot), `Camelot/PaperDollFrameStats.lua` |
| Spell ranks in the spellbook | `subName` is "Rank N" (Heroic Strike and Rend Rank 2 at 12), one entry per spell: only the highest rank is listed. Whether lower ranks can be cast is still open | W12 spells |
| Spell costs and text | `C_Spell.GetSpellPowerCost` gives rage costs (Heroic Strike 15, Thunder Clap 20, Sunder Armor 15); descriptions include the numbers | W12 spells |
| Warrior spells known at 12 | Battle Stance, Charge, Hamstring, Heroic Strike, Rend, Thunder Clap, Battle Shout, Bloodrage, Defensive Stance, Sunder Armor, Taunt | W12 spells |
| Human racials | Sword Specialization is +2% crit with swords; Will to Survive removes stuns; The Human Spirit +5% Spirit; Perception | W12 spells |
| Threat out of combat | `UnitDetailedThreatSituation` and `UnitThreatSituation` read `ok` (nil values with no aggro). In combat: still open | W12 threat |
| Weapon enchant read | `GetWeaponEnchantInfo` works (false with nothing applied); stones and oils still untested | W12 auras |
| Consumable items | All 55 item IDs exist. Renamed: Elixir of Minor Strength (2454), Ogre Strength (3391), Greater Strength (9206, level 48), Lesser Fortitude (3825), Lesser Defense (3389), Defense (8951), Greater Defense (13445), Mageblood Elixir (20007). Elixir of Wisdom is level 10 | W12 items |
| Food | One stat each, for 15 min after 10 s of eating; item spell "Nutritious Food". Spiced Wolf Meat +1 Agi, Goretusk Liver Pie +3 Str, Crocolisk Steak +3 Agi (level 5), Lean Wolf Steak +5 Agi (15), Monster Omelet +15 Sta, Grilled Squid +1% crit, Smoked Desert Dumplings +20 Str, Nightfin Soup +22 spell damage, Runn Tum Tuber Surprise +15 Int (35) | W12 items |
| Weapon oils | Wizard oils: spell damage and healing +8 / 16 / 36 (Brilliant also +1% spell crit). Mana oils: 5 / 10 / 15 mana per 5 s and healing +10 / 20 / 30 | W12 items |
| Item tooltips | The first `/bpp items` read has names and levels but no "Use:" line; the second, seconds later, has the full text | W12 items |
| Warrior level 12 stats | Blessing of Kings landed between the two snapshots (+10% every stat). From it: 1 Stamina = 10 health; 2 Agility = +0.357% melee crit and dodge and +4 armor (about 5.6 Agility per 1% crit); 3 Strength = +6 melee AP. One-off pair, not a stat lab measurement | W12 stat lab |

## References

- Blizzard's own UI code for Forever ("Camelot") is mirrored at
  [Gethe/wow-ui-source, branch `forever`](https://github.com/Gethe/wow-ui-source/tree/forever).
  It shows which functions the client's character sheet calls (`Camelot/PaperDollFrame*.lua`).
  Read it to find APIs; confirm each with the probe before relying on it, and don't copy it.
- ExtraStats 3.0.0 for Forever (CurseForge project 803163, MIT, by Wuild)
  pointed there: it reuses the native `PAPERDOLL_STATINFO` stat functions rather than its own reads.

## Still to find out

See [BETA-CHECKLIST.md](BETA-CHECKLIST.md). Battleplan's data marks every unconfirmed
value as `provisional`:

- [ ] Stat conversions at levels 10, 20, 30 for Rogue, Priest and Warrior (stat lab)
- [ ] Can lower spell ranks be cast (downranking for healers)? Ranks exist (W12); only the top one is listed
- [ ] Priest and Warrior trainer levels
- [x] Consumable item IDs, names, levels and amounts (W12)
- [ ] Consumable buff (aura) names, and potion amounts
- [ ] Does `GetWeaponEnchantInfo` see stones and oils?
- [x] Warrior talent tree and spec group IDs (native W12 talent capture)
- [ ] Rank-specific Warrior talent effect text, then modeled build orders
- [x] Confirm `UnitDefenseSkill` in a probe export: 57 / 0 at level 12 (`2026-10-05-warrior-12-defense.json`)
- [x] Is threat readable out of combat? Yes (W12)
- [ ] Is threat readable in combat?
- [ ] Frame-time comparison with Battleplan on and off

## External talent snapshot used for validation (provisional)

The 2026-10-05 collected ForeverDB `data/classes.json` snapshot reports client build
1.60.1.70205. Structural facts for 466 talents across nine classes are recorded in
`data/talents/catalog.json`, with the URL and SHA-256 of the original collected source.
These are imported leads, **not new verified beta captures**.

It reports Riposte requiring Deflection rank 3, Renewed Hope requiring Soul Warding
rank 1, and Prayer of Mending requiring Spirit of Redemption rank 1. Existing build
orders have been rearranged to satisfy those rules and still spend 51 points; the
orders and imported catalog remain provisional pending a talent-tree capture.

Nature's Splendor has an additional prerequisite field whose semantics are not
confirmed. The field is preserved; the runtime rejects such a condition rather than
interpreting it as a verified rule. No Druid build is introduced by this import.

The regression suite confirms code behavior against the mock, including delayed timer
races and item-data completion. It does not claim those synthetic scenarios are new
observations from the live client. Bag and item-data events are feature-detected;
missing event names are skipped through the existing event wrapper.

## Follow-up Warrior capture (2026-10-05)

Source: [2026-10-05-warrior-12-followup.json](../data/probe/2026-10-05-warrior-12-followup.json),
committed byte-for-byte from Jeff's export. Client 1.60.1.70205, Human Warrior level 12.
Latest spellbook: 21 entries, including the 11 class abilities listed above; Heroic
Strike 284 and Rend 6546 are rank 2. Captured rage costs are Charge/Battle Stance/
Defensive Stance/Taunt 0, Hamstring/Rend/Battle Shout 10, Heroic Strike/Sunder Armor 15,
and Thunder Clap 20. Bloodrage has no cost record; that is unknown, not zero.
Thunder Clap's text specifies at most four targets, not an unlimited pack.

The 16:40:56 to 16:41:07 gear pair changes only slot 7 with unchanged aura names:
Strength 39 → 42, base AP 94 → 100, armor 572 → 685 and block value 3 → 4.
This supports 2 melee AP per Strength at level 12. The item also supplies armor, so
113 armor must not be treated as a Strength conversion. The single rounded block
change does not establish a per-point block-value formula. No weights were promoted
or general stat conversion file generated from this mixed-effect pair.

The latest snapshot records defense base 58, bonus 0. The export contains no talent
or performance captures, and both threat captures are out of combat. Those tasks
remain open. Native `/bpp talents` is now implemented defensively; its optional
condition API and raw field semantics still need a live capture before promotion.

## Native Warrior talent capture (2026-10-05 17:50)

Source: [2026-10-05-warrior-12-talents.json](../data/probe/2026-10-05-warrior-12-talents.json),
committed unchanged from Jeff's export. Client 1.60.1.70205, level-12 Human Warrior.
The capture completed with zero structural failures: tree `1117`, 52 nodes.

| Tree | Spec group | Talents | Purchased points |
|---|---:|---:|---:|
| Arms | 11650 | 17 | 0 |
| Fury | 11657 | 17 | 0 |
| Protection | 11670 | 18 | 3 |

All three points are Shield Specialization (3/5). All 52 names, node IDs, spell IDs
and maximum ranks match the external catalog, as do its seven prerequisite node
links. Exact prerequisite rank semantics remain provisional where this one allocation
cannot distinguish them. Global `TalentRules` status is unchanged.

`GetConditionInfo.spentAmountRequired` is the remaining amount in this capture,
not an absolute threshold: Protection row two reports 2 after three points spent,
row three 7, and Shield Slam 27. Arms/Fury, with zero points, report 5, 10 and 30.
The checker/replay never substitutes these remaining values for absolute gate rules.

Only 11 generic talent spell descriptions are readable; 41 are `<nil>`. The generic
Shield Specialization text says 5% block and 100% chance to generate 5 Rage while
its node has only three ranks purchased. Other zero-rank talents return zero-valued
text. These reads do not establish each rank's effect.

**Tooltip lead (subsequently verified below):** the Forever UI calls
`GetTraitEntry(entryID, rank)` for talent descriptions. Its generated API documentation
lists the same two arguments. The probe now uses this API defensively for every rank;
Jeff's next capture must confirm returned text before effects are promoted.

- [Forever talent display source](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_TalentDisplay.lua)
- [Forever tooltip API documentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoDocumentation.lua)


### Warrior rank effects — 2026-10-05 18:14:01

Source: unchanged `data/probe/2026-10-05-warrior-12-talent-effects.json`, Human Warrior
level 12, client 1.60.1.70205. The second talent snapshot completes all 52 nodes and
150 rank tooltip reads with zero failures. Every multi-rank talent has distinct text
between ranks. `GetTraitEntry(entryID, rank)` is now confirmed in the live client.

The generated `Data/WARRIOR/TalentEffects.lua` preserves all readable left/right
text, in line order, for each rank, with source hash, build, timestamp and observed
level. It imports text only: no inferred coefficients, trainer levels or base damage.
Shield Slam's captured damage, for example, is not a universal level-60 value.

Confirmed examples: Shield Specialization rank 3 grants +3% block and a 60% chance
of 5 Rage on block (rank 5: +5%, 100%); Anticipation adds 4 Defense skill per rank;
Improved Revenge adds 20% damage per rank. Master of Defense rank 2 generates 5 Rage
on dodge/parry with a shield; Defiance rank 3 adds 15% threat in Defensive Stance with
a shield; Bastion rank 5 adds 10% damage with a shield.

The Protection order is a provisional shield questing / leveling dungeon choice:
31 Protection points by level 40, then 5 Deflection, 5 Cruelty and 10 further
Protection points (5 Arms / 5 Fury / 41 Protection at level 60). Every point is tested
against the imported gates, rank limits and prerequisites. This validates the order
under those rules, not optimal performance or full live prerequisite semantics.
The global `TalentRules` status remains provisional. Raid builds and damage/mitigation
optimization still require a model and play tests.


### Icon display — awaiting live confirmation

The existing captures confirm `C_Spell.GetSpellInfo` exists, but the probe previously
omitted its optional icon field. The Forever generated API documentation lists
`SpellInfo.iconID` as a texture file ID:
[SpellDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua).
This is a documented lead, not a captured icon result. The probe now records
`iconID` in spell and talent spell metadata; production reads it defensively by ID
and verifies the returned name. Missing icon data leaves the text visible. No icon
constants or talent-rule statuses are promoted from documentation or synthetic tests.


### Live UI feedback — 2026-10-05 19:05

The screenshot `image(20261006-000510).png` shows spell/talent icons rendering
(including Shield Specialization, Anticipation, Bastion and Cruelty), but the custom
blue window styling does not fit WoW. Title/context text is also obscured by the
opaque child header. The window now returns to the native panel/button artwork
previously seen in the live client, and explicitly layers content/title/close controls.
The restored layout needs a fresh visual check; numeric icon IDs still await a probe.


### Tank setup / upcoming icon feedback — 2026-10-05 19:12

`image(20261006-001238).png` shows Last Stand and Shield Slam icons, but no icons for
five unlearned non-talent abilities. The planner previously resolved only known
spells and talents in its build. Upcoming rows now carry lookup candidates and the
planner queries their client icons, still checking names and leaving unknown data
text-only. The local Forever database snapshot supplies these provisional leads:

| Ability | Candidate spell ID |
|---|---:|
| Revenge | 6572 |
| Demoralizing Shout | 1160 |
| Shield Block | 2565 |
| Cleave | 845 |
| Shield Wall | 871 |

Source: `https://foreverdb.net/data/spells.json`, existing 1.60.1.70205 snapshot.
These are icon lookup candidates, not proof of trainer levels or availability.
Client rendering for these new lookups still needs confirmation.

The same screenshot exposes inappropriate Safe/Threat setup prose for a level-12
Warrior: unlearned cooldowns described as ready, and an unmodeled Stamina-for-hit
trade. These choices are replaced by a pre-pull checklist with known-spell filtering;
pull instructions also omit unlearned ability names. Shield Slam advice no longer
asserts an unmodeled best threat-per-Rage ranking.

### Provisional crafted gear cohort — 2026-10-05

The existing ForeverDB client-derived snapshot (1.60.1.70205) now supplies an
initial 133-item crafted armor/cloak catalog. The dated input is
`data/gear/client-crafting.json`; it retains source URLs, extraction date,
SHA-256 of items.json and all 64 crafting shards. Items and recipe associations
remain provisional; client presence does not prove recipe access or live usability.

Only ordinary tradeable armor with supported static stats is included. Current
`st` fields are used, never historical `chg.st` values (for example, Embossed
Leather Pants currently list Spell Power rather than their historical Spirit).
Recipe skill fields disagree across feeds, so this import omits skill requirements
instead of choosing one. No quest/Classic source tables are bundled.

The production change reuses existing item-count and equipped-link reads. Equipped
IDs are extracted from the same cleaned links already used for stat comparisons;
no new client API is introduced or declared verified. Bag/equipment ownership,
source icons and source-side recipe details still need a live visual check.

### Complete external snapshot — 2026-10-06

The existing 2026-10-05 ForeverDB collection (item build 1.60.1.70205) is preserved
in `data/external/full-snapshot.zip`, including all downloaded JSON and collection
manifest files. The new member/archive SHA-256 manifest permits integrity checks.
This supersedes the starter cohort's statement that no Classic source tables are
bundled: the complete reference archive now retains their declarations and license.

The importer emits 1,635 provisional armor/cloak records with quest/craft/vendor/
drop associations. These are imported leads, never verified player access. Older
talent data is archived but does not replace verified trees. The import excludes
effects and unsupported wearer requirements instead of silently scoring them away.
See the exclusion report and `data/external/NOTICE.md` for provenance/license details.

`UnitFactionGroup` and `C_QuestLog.IsQuestFlaggedCompleted` are optional, unconfirmed
live reads. Production wrappers feature-detect, pcall, clean and preserve unknown
results; completion caches invalidate on supported quest events. The probe env now
records API presence, player faction and a completion sample for quest 6. Synthetic
tests exercise missing/error/secret values; they do not verify these APIs on Forever.
After maintenance, `/bpp all` and `/bpp export` can confirm their actual behavior.

### Ability learn levels and Forever changes — 2026-10-06

ForeverDB `classes.json` (build 1.60.1.70205, SHA-256 `c6f07937...`) lists every
class ability rank with its learn level and source. The 1,504 trainer and quest ranks (430
abilities) are generated into `Data/SpellRanks.lua` as **provisional** leads. Every `minLevel`
Battleplan already had (12 Rogue, 8 Priest and 10 Warrior abilities, from the Rogue
trainer capture and Classic values) matches the import.

`changes.json` (SHA-256 `ce54a829...`) compares the Forever client with Classic. For
example, Slam is learned at 20 instead of 30 and gains a fifth rank, Berserker Rage
moves from 32 to 30, and Warrior loses Sword Specialization, Polearm Specialization,
Improved Battle Shout, Toughness and Improved Taunt as talents. No Rogue, Priest or
Warrior advice names a talent or ability that Forever removed. The full list is in
`docs/FOREVER-CHANGES.md`. A trainer capture is still needed before marking learn
levels verified.

### Selected gear comparison — 2026-10-06

No new client API or game facts are introduced. Planner reuses existing cleaned
item-stat tokens for gains/losses and score estimates. These explanations inherit
the provisional item catalog and weights; they do not verify item usability or
source access. Synthetic tests cover empty/zero-score/unknown baselines, rating
conversion, alternatives, future items and ALL_STATS expansion.

Secret or malformed equipped links now mark their slots unknown rather than
empty. This is defensive handling exercised by the mock, not a new live capture.
After maintenance, check the Gear tab with known equipped items and capture any
mismatch between listed stat differences and the client tooltip.
