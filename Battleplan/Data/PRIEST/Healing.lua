-- Healer guide: which heal for which situation, and how to pace mana.
-- Battleplan adds the numbers itself from the spells you know (cost, cast
-- time and amount from the client), so the table is right for your ranks.
--
-- rank: "max" uses your highest rank; "efficient" uses the rank that heals
-- the most per mana (downranking), if Forever keeps spell ranks.
-- PROVISIONAL: drafted from Classic healing; check on the beta.
local _, ns = ...

local holy = {
  -- Heals that hit the whole party: the table counts this many targets.
  partyHeals = { ["Prayer of Healing"] = 5, ["Holy Nova"] = 5 },

  situations = {
    { key = "topup", label = "Light top-up", rank = "efficient", prefer = { "Renew", "Heal", "Lesser Heal" },
      note = "Small damage: a cheap heal or Renew. Don't spend big heals on it." },
    { key = "tank", label = "Steady tank damage", rank = "efficient",
      prefer = { "Greater Heal", "Heal", "Lesser Heal" },
      note = "Start the cast before the tank needs it. Cancel it (move or jump) if they're topped off." },
    { key = "spike", label = "Sudden spike", rank = "max",
      prefer = { "Power Word: Shield", "Flash Heal", "Heal", "Lesser Heal" },
      note = "Shield first, then Flash Heal. Flash Heal is fast but costs the most per point healed." },
    { key = "group", label = "Party-wide damage", rank = "max",
      prefer = { "Prayer of Mending", "Prayer of Healing", "Holy Nova", "Renew" },
      note = "Prayer of Healing when 3+ party members are hurt; Prayer of Mending before damage lands." },
  },

  -- Shown as a checklist under the table.
  manaPlan = {
    "Let the party top off from Renew and small heals; big heals are for the tank.",
    "Stop casting for a few seconds when you can: Spirit regen is faster while you aren't casting"
      .. " (if Forever keeps Classic's five-second rule; the stat lab measures it).",
    "Drink between pulls, not halfway through one. Tell the tank when you're under half mana.",
    "On long fights: mana potion around 40% mana, then the next one as soon as its cooldown is back.",
    "Overhealing is wasted mana. Pick the smallest heal that covers the damage.",
  },

  cooldowns = {
    { spell = "Inner Focus", note = "Next spell is free and crits: use it on your most expensive heal." },
    { spell = "Power Infusion", note = "Faster, cheaper spells for a while: the hardest part of a fight." },
    { spell = "Fade", note = "When mobs turn to you after a big heal." },
    { spell = "Psychic Scream", note = "When several mobs reach you at once." },
  },
}

ns.Data.PRIEST.Healing = {
  _status = "provisional",
  holy = holy,
  discipline = {
    situations = {
      { key = "topup", label = "Light top-up", rank = "efficient", prefer = { "Renew", "Heal", "Lesser Heal" },
        note = "Renew and small heals; save shields for incoming damage." },
      { key = "tank", label = "Steady tank damage", rank = "efficient",
        prefer = { "Power Word: Shield", "Greater Heal", "Heal", "Lesser Heal" },
        note = "Shield the tank when it's off cooldown, heal between shields." },
      holy.situations[3],
      holy.situations[4],
    },
    partyHeals = holy.partyHeals,
    manaPlan = holy.manaPlan,
    cooldowns = holy.cooldowns,
  },
}
