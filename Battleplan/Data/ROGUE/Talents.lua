-- Talent builds per spec and situation.
--
-- Talent names, ranks and rows come from the beta tree (client 1.60.1,
-- docs/BETA-FINDINGS.md). The builds themselves are PROVISIONAL first drafts:
-- tools/theorycraft will replace them once the stat lab has real numbers.
--
-- order: each step raises a talent TO that rank. The first point is at level
-- 10, then one per level (51 at level 60). Rows unlock every 5 points spent in
-- that spec (assumed from Classic; the probe will confirm).
-- A situation can be a table, or the name of another situation to reuse.
local _, ns = ...

ns.Data.ROGUE.Talents = {
  _status = "provisional",

  combat = {
    leveling = {
      title = "Combat Swords/Axes",
      summary = "Sustained damage with any weapon. The easiest Rogue to level and the default before you pick a spec.",
      order = {
        { "Improved Sinister Strike", 2 }, { "Lightning Reflexes", 3 }, { "Precision", 3 }, { "Deflection", 2 },
        { "Riposte", 1 }, { "Endurance", 2 }, { "Improved Sprint", 2 }, { "Dual Wield Specialization", 5 },
        { "Blade Flurry", 1 }, { "Hack and Slash", 5 }, { "Weapon Expertise", 2 }, { "Aggression", 3 },
        { "Adrenaline Rush", 1 }, { "Lightning Reflexes", 5 }, { "Improved Eviscerate", 3 },
        { "Puncturing Wounds", 3 }, { "Deflection", 3 }, { "Improved Kick", 2 }, { "Flawless Execution", 1 },
        { "Malice", 5 }, { "Remorseless Attacks", 2 },
      },
      why = {
        ["Hack and Slash"] = "Replaces Sword/Mace Specialization: extra attacks with swords and axes, crit with daggers and fists.",
        ["Precision"] = "Hit is the first stat that matters for dual wielding.",
        ["Blade Flurry"] = "Big damage on two targets; save it for packs in dungeons.",
        ["Adrenaline Rush"] = "Energy for burst; use it on long fights and elites.",
      },
    },
    solo = "leveling",
    dungeon = { from = "leveling", summary = "Same points as leveling. Blade Flurry and Adrenaline Rush do the heavy lifting on packs." },
    raid = { from = "leveling", summary = "Same points as leveling until raid testing says otherwise." },
  },

  assassination = {
    leveling = {
      title = "Mutilate / Seal Fate",
      summary = "Burst finishers from crit-driven combo points. Mutilate needs no dagger on Forever.",
      order = {
        { "Malice", 5 }, { "Ruthlessness", 3 }, { "Murder", 2 }, { "Lethality", 5 }, { "Relentless Strikes", 1 },
        { "Cold Blood", 1 }, { "Vile Poisons", 3 }, { "Mutilate", 1 }, { "Vigor", 2 },
        { "Improved Slice and Dice", 2 }, { "Seal Fate", 5 }, { "Venom", 1 }, { "Improved Poisons", 5 },
        { "Vile Poisons", 5 }, { "Improved Slice and Dice", 3 }, { "Improved Eviscerate", 3 },
        { "Lightning Reflexes", 2 }, { "Precision", 3 }, { "Remorseless Attacks", 2 }, { "Improved Expose Armor", 2 },
      },
      why = {
        ["Mutilate"] = "Attacks with both weapons and has no dagger requirement on Forever (Wowhead, Forever database).",
        ["Seal Fate"] = "Crits add combo points, which makes crit worth more for this spec.",
        ["Lethality"] = "More crit damage on your builders.",
      },
    },
    solo = "leveling",
    dungeon = { from = "leveling" },
    raid = { from = "leveling" },
  },

  subtlety = {
    leveling = {
      title = "Hemorrhage / Ambush",
      summary = "Strong openers and control. Strongest in small fights and PvP.",
      order = {
        { "Opportunity", 2 }, { "Camouflage", 3 }, { "Improved Ambush", 3 }, { "Setup", 2 }, { "Initiative", 3 },
        { "Ghostly Strike", 1 }, { "Improved Distract", 1 }, { "Premeditation", 1 }, { "Serrated Blades", 3 },
        { "Heightened Senses", 1 }, { "Hemorrhage", 1 }, { "Dirty Deeds", 2 }, { "Preparation", 1 },
        { "Elusiveness", 1 }, { "Cutthroat", 5 }, { "Thousand Cuts", 1 }, { "Quietus", 5 }, { "Setup", 3 },
        { "Camouflage", 5 }, { "Master of Deception", 3 }, { "Improved Sinister Strike", 2 },
        { "Improved Eviscerate", 3 }, { "Precision", 3 }, { "Lightning Reflexes", 1 },
      },
      why = {
        ["Hemorrhage"] = "Your builder once you have it; Sinister Strike before that.",
        ["Premeditation"] = "Two free combo points before an opener.",
      },
    },
    solo = "leveling",
    dungeon = { from = "leveling", summary = "Subtlety is weaker in long dungeon fights; consider Combat for dungeons." },
    raid = { from = "leveling", summary = "Subtlety is weaker in long fights; consider Combat or Assassination for raids." },
  },
}
