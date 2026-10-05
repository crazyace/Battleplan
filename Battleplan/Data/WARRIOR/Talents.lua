-- Shield-focused first draft, justified by captured rank text, not a combat optimizer.
-- Source: data/probe/2026-10-05-warrior-12-talent-effects.json (client 1.60.1.70205).
-- Structural rules remain provisional; play testing must confirm the point order.
local _, ns = ...

ns.Data.WARRIOR.Talents = {
  _status = "provisional",
  protection = {
    leveling = {
      title = "Protection: shield leveling",
      summary = "Provisional path for questing with a shield and tanking leveling dungeons. Needs play testing.",
      order = {
        { "Shield Specialization", 5 }, { "Improved Revenge", 3 }, { "Improved Bloodrage", 2 },
        { "Master of Defense", 2 }, { "Last Stand", 1 }, { "Defiance", 2 },
        { "Defiance", 3 }, { "Improved Sunder Armor", 3 }, { "Vanguard", 1 },
        { "Concussion Blow", 1 }, { "Focused Rage", 3 }, { "Anticipation", 1 },
        { "Bastion", 5 }, { "Shield Slam", 1 },
        { "Deflection", 5 }, { "Cruelty", 5 }, { "Anticipation", 5 },
        { "Improved Thunder Clap", 3 }, { "Improved Shield Wall", 2 }, { "Improved Shield Bash", 1 },
      },
      why = {
        ["Shield Specialization"] = "At 5/5: +5% block chance and 5 Rage on every block. Use a shield.",
        ["Improved Revenge"] = "At 3/3: +60% Revenge damage. Take it early for damage when Revenge is available.",
        ["Improved Bloodrage"] = "At 2/2: Bloodrage generates 50% more Rage. Helps start a pull with Rage.",
        ["Master of Defense"] = "At 2/2: dodges and parries generate 5 Rage while using a shield.",
        ["Last Stand"] = "Temporarily adds 30% maximum health for 20 seconds; that health is lost when it ends.",
        ["Defiance"] = "At 3/3: +15% threat in Defensive Stance with a shield. Prioritized for dungeon tanking.",
        ["Vanguard"] = "Lets you Charge in Defensive Stance. Chosen for pulling convenience.",
        ["Focused Rage"] = "At 3/3: offensive abilities cost 3 less Rage. Pair with cheaper Sunder Armor.",
        ["Bastion"] = "At 5/5: +10% damage with a shield. Chosen before Shield Slam for shield questing.",
        ["Shield Slam"] = "The capture calls it very high threat and adds shield block value to damage. Planned at level 40.",
        ["Anticipation"] = "At 5/5: +20 Defense skill. Fill out after Shield Slam and the parry and crit talents.",
        ["Deflection"] = "At 5/5: +5% parry chance. Taken after Shield Slam; parries can also trigger Master of Defense.",
        ["Cruelty"] = "At 5/5: +5% melee critical strike chance. A provisional damage choice after the Protection core.",
      },
    },
    solo = "leveling",
    dungeon = { from = "leveling", summary = "Provisional shield tank path for leveling dungeons. Test Rage and threat on pulls." },
    raid = { from = "leveling", summary = "Untested leveling allocation. Raid gearing and an optimized raid build are not modeled yet." },
  },
}
