# Beta checklist

The beta ends **October 22** and is capped at **level 30**. These captures turn
Battleplan's provisional data into verified data. Commit every export to `data/probe/`.

## Stat lab (most important)

Out of combat, in a quiet spot. Change **one thing** between snapshots, and label the
second snapshot with exactly what you changed (`+10 agility`, `+14 crit rating`,
`+5 strength`). Buffs must stay the same between the two, or `tools/stat_lab.py` skips
the pair.

1. Take off everything that has the stat you're testing. `/bpp stats`
2. Put on one item with a known amount of that stat. `/bpp stats +10 agility`
3. The diff prints right away. Repeat for each stat below.
4. `/bpp export` -> paste into `data/probe/YYYY-MM-DD-statlab-<class>-<level>.json`
5. `python tools/stat_lab.py data/probe/*statlab*.json`

Per class, at **level 10, 20 and 30** (conversions change with level):

| Class | Stats to test |
|---|---|
| Rogue | Agility, Strength, Stamina, hit rating, crit rating, expertise, haste |
| Priest | Intellect, Spirit (casting and not casting), Stamina, +healing, spell power, mp5 |
| Warrior | Strength, Agility, Stamina, armor, defense rating, parry rating, dodge, block |

Then one each of: an enchant, an elixir, a weapon stone or oil, and a food buff (label it
with the item name and amount, e.g. `+15 agility`).

## Spellbook and heals

- [ ] `/bpp spells` on a Priest with several heals learned: do lower ranks still exist
      (downranking), and do costs and descriptions come through?
- [ ] Same on a Rogue and a Warrior: spell names match `Data/*/Rotations.lua`?
- After any export: `python tools/capture_check.py data/probe/<file>.json` lists every
  spell name, level, item and API that doesn't match Battleplan's data.
- [ ] A Priest trainer and a Warrior trainer with GearwrightProbe (`/gwp trainer`):
      confirms the `minLevel` values marked Classic.

## Consumables

- [ ] `python tools/consumable_ids.py`, paste each line in game, then `/bpp export`.
      Which items exist on Forever, what buff each gives, and its tooltip amounts.
- [ ] Eat any food and drink an elixir, then `/bpp auras`: the aura names Battleplan
      looks for ("Well Fed" and each elixir's buff).
- [ ] Put a sharpening stone on your weapon, then `/bpp auras`: does
      `GetWeaponEnchantInfo` see it?

## Tanking

- [x] Warrior talent tree and spec groups: native capture has 52 nodes, Arms 11650,
      Fury 11657, Protection 11670; three points in Shield Specialization.
- [ ] Update BattleplanProbe, run `/bpp talents` outside combat, wait for both structural
      and rank-tooltip summaries, then `/bpp export`. Confirm text for every rank,
      especially passive talents that returned nil or zero-valued generic descriptions.
- [ ] Target a mob, `/bpp threat` out of combat; and once in combat if you can type it:
      is threat readable or secret?

## Performance

- [ ] `/bpp perf 60` in a busy city with Battleplan loaded, then again with it disabled.
- [ ] `/bplan perf on`, play an hour (level up, change gear, learn spells, run a
      dungeon), then `/bplan perf`: nothing in red.
- [ ] Open the window during a pull: it should open, but nothing recomputes until the
      fight ends.

## Questions to answer in BETA-FINDINGS.md

| Question | Answer | Capture |
|---|---|---|
| Do spell ranks exist (can you cast lower ranks)? | | |
| Five-second rule for mana regen? | | |
| Agility per 1% crit at 10 / 20 / 30 (Rogue) | | |
| Intellect per 1% spell crit at 10 / 20 / 30 (Priest) | | |
| Does `GetWeaponEnchantInfo` see stones and oils? | | |
| Elixir buff names | | |
| Threat readable out of combat? In combat? | | |
| Warrior spec group IDs | 11650 / 11657 / 11670 | `2026-10-05-warrior-12-talents.json` |
