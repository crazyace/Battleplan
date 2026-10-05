-- Priest builds. Talent names from the beta tree (2026-10-04); the builds
-- are PROVISIONAL drafts. "*" talents in the findings are new for Forever
-- and left out until we know what they do.
local _, ns = ...

ns.Data.PRIEST.Talents = {
  _status = "provisional",

  shadow = {
    leveling = {
      title = "Shadow leveling",
      summary = "The fastest Priest to level: damage over time, Mind Flay, and Spirit Tap to drink less.",
      order = {
        { "Spirit Tap", 5 }, { "Improved Shadow Word: Pain", 2 }, { "Shadow Focus", 3 },
        { "Improved Mind Blast", 5 }, { "Mind Flay", 1 }, { "Vampiric Embrace", 1 }, { "Shadow Weaving", 3 },
        { "Devouring Contagion", 2 }, { "Improved Mind Flay", 2 }, { "Shadow Affinity", 1 }, { "Darkness", 5 },
        { "Shadowform", 1 }, { "Shadow Focus", 5 }, { "Early Demise", 2 }, { "Shadow Reach", 2 }, { "Silence", 1 },
        { "Twin Disciplines", 5 }, { "Silent Resolve", 3 }, { "Improved Power Word: Shield", 2 },
        { "Mental Agility", 3 },
      },
      why = {
        ["Spirit Tap"] = "Mana back after every kill: less drinking between pulls.",
        ["Mind Flay"] = "Your main filler and it slows the target.",
        ["Shadowform"] = "More shadow damage and less damage taken; stay in it.",
      },
    },
    solo = "leveling",
    dungeon = { from = "leveling", summary = "Vampiric Embrace heals the party while you deal damage." },
    raid = { from = "leveling" },
  },

  holy = {
    leveling = {
      title = "Holy healer",
      summary = "Big, efficient heals and the best group healing. Prayer of Mending at 30 points.",
      order = {
        { "Improved Renew", 3 }, { "Holy Specialization", 2 }, { "Divine Fury", 5 }, { "Inspiration", 3 },
        { "Holy Nova", 1 }, { "Blessed Recovery", 1 }, { "Improved Healing", 3 }, { "Holy Reach", 2 },
        { "Spiritual Guidance", 5 }, { "Spiritual Healing", 3 }, { "Holy Specialization", 5 },
        { "Prayer of Mending", 1 }, { "Litany of Light", 2 }, { "Spirit of Redemption", 1 }, { "Binding Heal", 1 },
        { "Twin Disciplines", 5 }, { "Improved Power Word: Shield", 3 }, { "Silent Resolve", 2 },
        { "Meditation", 3 }, { "Mental Agility", 2 },
      },
      why = {
        ["Improved Healing"] = "Cheaper Lesser Heal, Heal and Greater Heal: the core of not going out of mana.",
        ["Divine Fury"] = "Faster casts on your big heals.",
        ["Meditation"] = "Mana keeps coming back while you cast.",
        ["Prayer of Mending"] = "Bounces through the party as people take damage.",
      },
    },
    solo = { from = "leveling", summary = "Holy levels slowly. Shadow is faster for solo leveling." },
    dungeon = "leveling",
    raid = "leveling",
  },

  discipline = {
    leveling = {
      title = "Discipline healer",
      summary = "Shields and mana efficiency. Prevents damage instead of healing it after.",
      order = {
        { "Twin Disciplines", 5 }, { "Improved Power Word: Shield", 3 }, { "Silent Resolve", 2 },
        { "Meditation", 3 }, { "Inner Focus", 1 }, { "Mental Agility", 1 }, { "Mental Strength", 5 },
        { "Penance", 1 }, { "Renewed Hope", 4 }, { "Divine Aegis", 3 }, { "Renewed Hope", 5 },
        { "Improved Inner Fire", 1 }, { "Power Infusion", 1 }, { "Mental Agility", 3 }, { "Soul Warding", 1 },
        { "Martyrdom", 2 }, { "Improved Renew", 3 }, { "Holy Specialization", 2 }, { "Divine Fury", 5 },
        { "Inspiration", 3 }, { "Holy Nova", 1 }, { "Blessed Recovery", 1 },
      },
      why = {
        ["Meditation"] = "Mana regen while casting.",
        ["Inner Focus"] = "A free, guaranteed-crit heal for emergencies.",
        ["Power Infusion"] = "Faster, cheaper spells for 15 seconds; use it in the hardest part of a fight.",
      },
    },
    solo = { from = "leveling", summary = "Shields make solo play safe, but Shadow kills faster." },
    dungeon = "leveling",
    raid = "leveling",
  },
}
