-- Tank guide for Protection Warriors. Threat is likely a secret value in
-- combat on Forever, so this is a guide to read between pulls, not a meter.
-- Early spell names/text are confirmed by the level-12 capture; learning levels
-- and uncaptured abilities/advice remain Classic-based and PROVISIONAL.
-- Upcoming icon lookup IDs are rank-one leads from foreverdb.net/data/spells.json;
-- the client must match the name before an icon is used. They do not prove learning levels.
local _, ns = ...

ns.Data.WARRIOR.Tanking = {
  _status = "provisional",
  protection = {
    single = {
      { spell = "Shield Slam", talent = true, note = "Very high threat: use when available and you can afford the Rage." },
      { spell = "Revenge", spellID = 6572, minLevel = 14, note = "Cheap and strong: use it every time it lights up." },
      { spell = "Sunder Armor", minLevel = 10, note = "Stack 5 early, then refresh; your filler." },
      { spell = "Heroic Strike", minLevel = 1, note = "Only with spare rage (above ~50)." },
    },
    multi = {
      { spell = "Thunder Clap", minLevel = 6, note = "Hits up to 4 nearby enemies and slows their attacks." },
      { spell = "Demoralizing Shout", spellID = 1160, minLevel = 14, note = "Threat on everything in range, and less damage taken." },
      { spell = "Cleave", spellID = 845, minLevel = 20, note = "Instead of Heroic Strike with 2+ mobs." },
      { spell = "Revenge", spellID = 6572, minLevel = 14, note = "Tab between targets with it." },
    },
    pullPlan = {
      "Mark a kill target (skull) and a crowd-control target before you pull.",
      "Pull around a corner so casters run to you.",
      { text = "Build on the kill target first, then use Sunder Armor on other enemies to keep them on you.", spell = "Sunder Armor" },
      { text = "Use Revenge when it lights up; switch targets when another enemy needs more threat.", spell = "Revenge" },
      { text = "Thunder Clap once the pack is on you.", spell = "Thunder Clap" },
      { text = "Use Demoralizing Shout once enemies are close enough.", spell = "Demoralizing Shout" },
      { text = "Taunt an enemy attacking your healer.", spell = "Taunt" },
      { text = "If Taunt is unavailable, Mocking Blow can help recover an enemy.", spell = "Mocking Blow" },
    },
    cooldowns = {
      { spell = "Shield Block", spellID = 2565, minLevel = 16, note = "Before big hits; it also makes Revenge come up." },
      { spell = "Last Stand", talent = true, note = "When you're about to die: extra health for a while." },
      { spell = "Shield Wall", spellID = 871, minLevel = 28, note = "Biggest cooldown: boss enrage or a bad pull." },
      { spell = "Taunt", minLevel = 10, note = "Get a mob back. Don't taunt something already on you." },
    },
    setup = {
      { label = "Equipment", note = "Equip a one-handed weapon and a shield." },
      { label = "Stance", spell = "Defensive Stance", note = "Switch to Defensive Stance before pulling.",
        unavailable = "Defensive Stance is not learned yet. Learn it before using this shield tank plan." },
      { label = "Starting Rage", spell = "Bloodrage",
        note = "If you need Rage, use Bloodrage only when you can afford the health cost." },
      { label = "Pull size", note = "Start with one enemy. Add more when you can hold them and stay alive." },
    },
  },
}
