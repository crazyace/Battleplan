-- Rotations as priority lists: work down the list and use the first thing
-- that makes sense. Battleplan filters each list to the spells the character
-- knows, so a level 22 Rogue sees a level 22 rotation.
--
-- minLevel: trainer level from the beta capture (Rogue trainer, 2026-10-03).
-- talent = true: comes from a talent, not the trainer.
-- PROVISIONAL: the order and advice are first drafts for tools/theorycraft to check.
local _, ns = ...

local SND = { spell = "Slice and Dice", minLevel = 10, note = "Keep it up. Refresh at 1-2 combo points when it's about to drop." }
local EVIS = { spell = "Eviscerate", minLevel = 1, note = "Finisher at 5 combo points." }
local RUPTURE = { spell = "Rupture", minLevel = 20, note = "Finisher on targets that live 15+ seconds (bosses, elites)." }
local SS = { spell = "Sinister Strike", minLevel = 1, note = "Combo point builder." }
local KICK = { spell = "Kick", minLevel = 12, note = "Interrupt casters, especially healers." }

ns.Data.ROGUE.Rotations = {
  _status = "provisional",

  combat = {
    default = {
      opener = {
        { spell = "Cheap Shot", minLevel = 26, note = "From stealth: stuns and gives 2 combo points." },
        { spell = "Sinister Strike", minLevel = 1, note = "Open from stealth before you have Cheap Shot." },
      },
      priority = {
        SND,
        { spell = "Adrenaline Rush", talent = true, note = "Burst: use on elites and long fights." },
        { spell = "Blade Flurry", talent = true, note = "Only with 2+ enemies in melee range." },
        { spell = "Riposte", talent = true, note = "Use right after you parry." },
        EVIS,
        SS,
      },
      utility = { KICK, { spell = "Evasion", minLevel = 8, note = "When a mob or pack is hitting you hard." } },
    },
    dungeon = {
      from = "default",
      priority = {
        SND,
        { spell = "Adrenaline Rush", talent = true, note = "Save for boss pulls or big packs." },
        { spell = "Blade Flurry", talent = true, note = "On packs, after the tank has threat." },
        RUPTURE,
        EVIS,
        SS,
      },
      utility = {
        KICK,
        { spell = "Feint", minLevel = 16, note = "Drop threat when you're close to the tank." },
        { spell = "Vanish", minLevel = 22, note = "Emergency threat wipe." },
      },
    },
    raid = "dungeon",
  },

  assassination = {
    default = {
      opener = {
        { spell = "Cheap Shot", minLevel = 26, note = "Stun and 2 combo points." },
        { spell = "Garrote", minLevel = 14, note = "From behind before you have Cheap Shot." },
      },
      priority = {
        SND,
        { spell = "Cold Blood", talent = true, note = "Right before a 5 combo point Eviscerate." },
        EVIS,
        { spell = "Mutilate", talent = true, note = "Builder once you have it; hits with both weapons." },
        { spell = "Backstab", minLevel = 4, note = "Builder from behind with a dagger in the main hand." },
        SS,
      },
      utility = { KICK },
    },
    dungeon = {
      from = "default",
      priority = {
        SND,
        RUPTURE,
        { spell = "Cold Blood", talent = true, note = "On cooldown, with a 5 combo point finisher." },
        EVIS,
        { spell = "Mutilate", talent = true, note = "Builder." },
        { spell = "Backstab", minLevel = 4, note = "Builder before Mutilate (needs a main-hand dagger)." },
      },
    },
    raid = "dungeon",
  },

  subtlety = {
    default = {
      opener = {
        { spell = "Premeditation", talent = true, note = "Two free combo points before the opener." },
        { spell = "Ambush", minLevel = 18, note = "Big opener from stealth (needs a main-hand dagger)." },
        { spell = "Cheap Shot", minLevel = 26, note = "Use instead of Ambush when you need the stun." },
      },
      priority = {
        SND,
        { spell = "Ghostly Strike", talent = true, note = "Builder that also raises dodge." },
        EVIS,
        { spell = "Hemorrhage", talent = true, note = "Main builder once you have it." },
        SS,
      },
      utility = {
        KICK,
        { spell = "Preparation", talent = true, note = "Resets Vanish, Evasion and Sprint: a second chance." },
      },
    },
    dungeon = "default",
    raid = "default",
  },
}
