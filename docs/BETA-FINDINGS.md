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

## Still to find out

See [BETA-CHECKLIST.md](BETA-CHECKLIST.md). Battleplan's data marks every unconfirmed
value as `provisional`:

- [ ] Stat conversions at levels 10, 20, 30 for Rogue, Priest and Warrior (stat lab)
- [ ] Do spell ranks exist on Forever (downranking for healers)?
- [ ] Priest and Warrior trainer levels
- [ ] Consumable item IDs, amounts and buff names
- [ ] Does `GetWeaponEnchantInfo` see stones and oils?
- [ ] Warrior talent tree and spec group IDs
- [ ] Is threat readable out of combat? In combat?
- [ ] Frame-time comparison with Battleplan on and off
