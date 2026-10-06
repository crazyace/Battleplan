-- Starter advice uses names confirmed by the level-12 Warrior spell capture.
-- Priority/advice remain provisional; higher-level abilities need integration.
-- No minLevel: possession at 12 does not establish a trainer requirement. Upcoming
-- abilities take their learn level from the imported Data/SpellRanks.lua instead.
local _, ns = ...

local SHOUT = { spell = "Battle Shout", note = "Keep the attack power buff up when it benefits your party." }
local HEROIC = { spell = "Heroic Strike", note = "Spend spare rage; keep enough for your other abilities." }
local REND = { spell = "Rend", note = "Use on enemies that will live through the bleed; avoid refreshing early." }
local CLAP = { spell = "Thunder Clap", note = "Slow nearby enemies' attacks when you need to reduce incoming damage." }
local BLOODRAGE = { spell = "Bloodrage", note = "Gain rage when you can afford the health cost." }
local starter = {
  default = {
    opener = { { spell = "Charge", note = "Open from Battle Stance, outside combat, with room to charge." } },
    priority = { SHOUT, REND, HEROIC },
    utility = {
      BLOODRAGE, CLAP,
      { spell = "Hamstring", note = "Slow a fleeing enemy or create distance." },
    },
  },
}

ns.Data.WARRIOR.Rotations = {
  _status = "provisional",
  scopeNote = "Starter guide: captured early abilities. Higher-level and talent abilities are still being validated.",
  arms = starter,
  fury = starter,
  protection = {
    default = {
      opener = { { spell = "Defensive Stance", note = "Use for tanking: more threat and less damage taken." } },
      priority = {
        SHOUT,
        { spell = "Sunder Armor", note = "Build stacks on a durable target, then refresh before they expire." },
        CLAP, HEROIC,
      },
      utility = { BLOODRAGE, { spell = "Taunt", note = "Recover an enemy attacking someone else." } },
    },
  },
}
