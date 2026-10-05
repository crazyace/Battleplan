-- Tank guide for Protection Warriors. Threat is likely a secret value in
-- combat on Forever, so this is a guide to read between pulls, not a meter.
-- Spell names and levels are Classic: PROVISIONAL until a Warrior trainer
-- capture confirms them.
local _, ns = ...

ns.Data.WARRIOR.Tanking = {
  _status = "provisional",
  protection = {
    single = {
      { spell = "Shield Slam", talent = true, note = "Highest threat per rage: on cooldown." },
      { spell = "Revenge", minLevel = 14, note = "Cheap and strong: use it every time it lights up." },
      { spell = "Sunder Armor", minLevel = 10, note = "Stack 5 early, then refresh; your filler." },
      { spell = "Heroic Strike", minLevel = 1, note = "Only with spare rage (above ~50)." },
    },
    multi = {
      { spell = "Thunder Clap", minLevel = 6, note = "Hits the whole pack and slows them." },
      { spell = "Demoralizing Shout", minLevel = 14, note = "Threat on everything in range, and less damage taken." },
      { spell = "Cleave", minLevel = 20, note = "Instead of Heroic Strike with 2+ mobs." },
      { spell = "Revenge", minLevel = 14, note = "Tab between targets with it." },
    },
    pullPlan = {
      "Mark a kill target (skull) and a crowd-control target before you pull.",
      "Pull around a corner so casters run to you.",
      "Build on the kill target first, then tab and Sunder or Revenge each other mob.",
      "Thunder Clap and Demoralizing Shout once the pack is on you.",
      "Taunt anything that runs at the healer, then Mocking Blow if Taunt is on cooldown.",
    },
    cooldowns = {
      { spell = "Shield Block", minLevel = 16, note = "Before big hits; it also makes Revenge come up." },
      { spell = "Last Stand", talent = true, note = "When you're about to die: extra health for a while." },
      { spell = "Shield Wall", minLevel = 28, note = "Biggest cooldown: boss enrage or a bad pull." },
      { spell = "Taunt", minLevel = 10, note = "Get a mob back. Don't taunt something already on you." },
    },
    -- Builds: "safe" leans into survival, "threat" into damage.
    setups = {
      safe = "Shield and one-hander, defensive stats, Last Stand and Shield Wall ready.",
      threat = "Same shield, but trade some Stamina for hit and weapon damage once healers can keep up.",
    },
  },
}
