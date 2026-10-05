-- Enchant advice and upgrade targets. No WoW calls.
local _, ns = ...

local Gear = {}
ns.Engine.Gear = Gear

local Score = ns.Engine.Score

Gear.SLOT_NAMES = {
  [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs", [8] = "Feet",
  [9] = "Wrist", [10] = "Hands", [11] = "Finger", [12] = "Finger", [13] = "Trinket", [14] = "Trinket",
  [15] = "Back", [16] = "Main hand", [17] = "Off hand", [18] = "Ranged",
}
Gear.SLOT_ORDER = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 }

-- Best enchant per equipped slot, and whether the slot has one already.
-- enchants: { [slot] = { options } }; equipped: { [slot] = enchantID (0 = none) }
-- Returns rows in slot order: { slot=, slotName=, best=, score=, hasEnchant= }
function Gear.EnchantAdvice(enchants, equipped, weights)
  local rows = {}
  if not enchants then return rows end
  for _, slot in ipairs(Gear.SLOT_ORDER) do
    local options = enchants[slot]
    if options and equipped[slot] ~= nil then
      local best, bestScore
      for _, opt in ipairs(options) do
        local s = Score.Entry(opt, weights)
        if s > 0 and (not bestScore or s > bestScore) then best, bestScore = opt, s end
      end
      if best then
        rows[#rows + 1] = {
          slot = slot, slotName = Gear.SLOT_NAMES[slot], best = best, score = bestScore,
          hasEnchant = (equipped[slot] or 0) ~= 0,
        }
      end
    end
  end
  return rows
end

-- targets: { { slot=, itemID=, name=, source=, minLevel=, stats = { STAT = n } } }
-- equippedScores: { [slot] = score or false (unknown) } (missing = empty slot)
-- Returns the best reachable upgrade per slot: { slot=, slotName=, target=, gain=, now= }
-- `now` is true when the level allows it already.
function Gear.NextUpgrades(targets, level, weights, equippedScores)
  local best = {}
  for _, t in ipairs(targets or {}) do
    local score = Score.Stats(t.stats, weights)
    local gain = score - (equippedScores[t.slot] or 0)
    local reachable = (t.minLevel or 0) <= level + 5 -- what's worth planning for next
    if equippedScores[t.slot] ~= false and gain > 0 and reachable then
      local cur = best[t.slot]
      local nowOk = (t.minLevel or 0) <= level
      -- Prefer what you can use now; among equals, the bigger gain.
      if not cur or (nowOk and not cur.now) or (nowOk == cur.now and gain > cur.gain) then
        best[t.slot] = { slot = t.slot, slotName = Gear.SLOT_NAMES[t.slot], target = t, gain = gain, now = nowOk }
      end
    end
  end
  local rows = {}
  for _, slot in ipairs(Gear.SLOT_ORDER) do
    if best[slot] then rows[#rows + 1] = best[slot] end
  end
  return rows
end
