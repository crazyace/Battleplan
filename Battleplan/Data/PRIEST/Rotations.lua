-- Priest damage rotations (Shadow, and Holy/Discipline while soloing).
-- minLevel values are Classic trainer levels: PROVISIONAL until a Priest
-- trainer capture (/gwp trainer) confirms them.
local _, ns = ...

local SWP = { spell = "Shadow Word: Pain", minLevel = 4, note = "Keep it on the target." }
local MB = { spell = "Mind Blast", minLevel = 10, note = "On cooldown." }
local SMITE = { spell = "Smite", minLevel = 1, note = "Filler before you have Mind Flay." }
local WAND = { spell = "Shoot", minLevel = 1, note = "Wand: finish low targets without spending mana." }
local SHIELD = { spell = "Power Word: Shield", minLevel = 6, note = "Before the pull, so you aren't pushed back while casting." }

ns.Data.PRIEST.Rotations = {
  _status = "provisional",

  shadow = {
    default = {
      opener = { SHIELD, { spell = "Mind Blast", minLevel = 10, note = "Open with it from range." } },
      priority = {
        { spell = "Shadowform", talent = true, note = "Stay in it." },
        { spell = "Vampiric Embrace", talent = true, note = "On the target in groups: heals the party." },
        SWP,
        MB,
        { spell = "Mind Flay", talent = true, note = "Main filler once you have it." },
        SMITE,
        WAND,
      },
      utility = {
        { spell = "Psychic Scream", minLevel = 14, note = "When more than one mob reaches you." },
        { spell = "Renew", minLevel = 8, note = "Heal yourself between pulls." },
      },
    },
    dungeon = {
      from = "default",
      priority = {
        { spell = "Shadowform", talent = true, note = "Stay in it." },
        { spell = "Vampiric Embrace", talent = true, note = "Keep it up on the boss." },
        SWP,
        MB,
        { spell = "Mind Flay", talent = true, note = "Filler." },
        WAND,
      },
      utility = { { spell = "Fade", minLevel = 8, note = "Drop threat if a mob turns to you." } },
    },
    raid = "dungeon",
  },

  holy = {
    default = {
      opener = { SHIELD },
      priority = {
        SWP,
        { spell = "Holy Fire", minLevel = 20, note = "Opener from range; long cast." },
        MB,
        SMITE,
        WAND,
      },
      utility = { { spell = "Renew", minLevel = 8, note = "Heal yourself while you fight." } },
    },
    dungeon = "default",
    raid = "default",
  },

  discipline = "holy",
}
