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
| Defense skill | The character sheet shows it (57 / 60 at level 12), but `UnitDefense` is missing, so the API behind it is still unknown. At 57 it adds 0.00% dodge, block and parry | W12 stat lab, [defense tooltip](../data/probe/2026-10-05-warrior-12-defense-tooltip.png) |
| Defense cap | 440 Defense: can't be critically hit by raid bosses (the tooltip says that is -5.60% crit chance from 57). Crits do 200%; creatures 3+ levels above you can crush for 150% | [defense tooltip](../data/probe/2026-10-05-warrior-12-defense-tooltip.png) |
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

## Still to find out

See [BETA-CHECKLIST.md](BETA-CHECKLIST.md). Battleplan's data marks every unconfirmed
value as `provisional`:

- [ ] Stat conversions at levels 10, 20, 30 for Rogue, Priest and Warrior (stat lab)
- [ ] Can lower spell ranks be cast (downranking for healers)? Ranks exist (W12); only the top one is listed
- [ ] Priest and Warrior trainer levels
- [x] Consumable item IDs, names, levels and amounts (W12)
- [ ] Consumable buff (aura) names, and potion amounts
- [ ] Does `GetWeaponEnchantInfo` see stones and oils?
- [ ] Warrior talent tree and spec group IDs
- [ ] Which API the character sheet reads Defense from (`UnitDefense` is gone)
- [x] Is threat readable out of combat? Yes (W12)
- [ ] Is threat readable in combat?
- [ ] Frame-time comparison with Battleplan on and off
