-- What each tab shows, as plain row tables built from ns.state. No frames
-- here, so the offline test checks every line a player would read.
local _, ns = ...

local UI = ns.UI
local util = ns.util
local Stats = ns.Data.Stats

UI.TABS = {
  { key = "talents", label = "Talents" },
  { key = "rotation", label = "Rotation" },
  { key = "gear", label = "Gear" },
  { key = "consumables", label = "Consumables" },
  { key = "healing", label = "Healing", role = "healer" },
  { key = "tanking", label = "Tanking", role = "tank" },
}

-- Tabs for the current role (Healing only for healers, Tanking only for tanks).
function UI.TabsFor(state)
  local out = {}
  for _, t in ipairs(UI.TABS) do
    if not t.role or t.role == state.role then out[#out + 1] = t end
  end
  return out
end

local function header(rows, text) rows[#rows + 1] = { kind = "header", text = text } end
local function row(rows, text, value, tip, indent, icon)
  rows[#rows + 1] = { kind = "row", text = text, value = value, tip = tip, indent = indent, icon = icon }
end
local function note(rows, text, indent) rows[#rows + 1] = { kind = "note", text = text, indent = indent or 1 } end
local function blank(rows) rows[#rows + 1] = { kind = "blank" } end

local function amountText(stat, amount)
  local name = Stats.names[stat] or stat
  if stat:find("_PCT$") then return ("+%g%% %s"):format(amount, (name:gsub(" %%", ""))) end
  return ("+%g %s"):format(amount, name)
end

local function rankText(rank) return (rank and rank > 1) and ("Rank " .. rank) or "" end

-- Lines every tab starts with.
function UI.Banner(state)
  local rows = {}
  if state.error then note(rows, state.error, 0) end
  if not state.ready then
    note(rows, "Working out your plan...", 0)
    return rows
  end
  if not state.supported then
    note(rows, "Battleplan has no data for your class yet. Rogue, Priest and Warrior come first.", 0)
    return rows
  end
  local how = state.specHow == "override" and " (set by you)"
    or state.specHow == "talents" and "" or " (until you spend talent points)"
  row(rows, util.color("gold", state.specName) .. how, util.title(state.situation) .. "  |  level " .. state.level,
    "Change with /bplan spec <name> and /bplan situation <leveling|solo|dungeon|raid>.", 0)
  if state.provisional then
    note(rows, "Provisional: first-draft advice until the stat lab has real Forever numbers.", 0)
  end
  blank(rows)
  return rows
end

local build = {}

function build.talents(s, rows, details)
  if not s.build then
    note(rows, "No recommended build for this spec yet: its build advice is still being developed.", 0)
    return
  end
  header(rows, s.build.title or "Recommended build")
  if s.build.summary then note(rows, s.build.summary) end
  local p = s.talentPlan
  if p.invalid then
    note(rows, "Build advice is unavailable: it fails the imported talent rules.", 0)
    for _, issue in ipairs(p.errors) do
      note(rows, (issue.name and (issue.name .. ": ") or "") .. issue.reason)
    end
    return
  end
  local rankTip
  if p.rankText then
    rankTip = ("Captured rank %d text (level %d character; ability values may scale):\n%s"):format(
      p.upcoming.rank, p.observedAtLevel, p.rankText)
  end
  row(rows, "Points spent", ("%d of %d"):format(p.spent, p.available))
  if p.blocked then
    row(rows, "Next point", "Prerequisites not met", p.blocked)
    note(rows, p.blocked)
  elseif p.next then
    row(rows, "Next point", util.color("green", p.next.name), rankTip or ("Rank %d of the build's %s."):format(p.next.rank, p.next.name))
  elseif p.upcoming and p.nextIndex and p.nextIndex <= p.available then
    row(rows, "Next point", ("%s (needs a respec)"):format(p.upcoming.name),
      "Your points are all spent, some of them off the plan. A trainer can reset them." .. (rankTip and ("\n\n" .. rankTip) or ""))
  elseif p.upcoming and p.nextIndex then
    row(rows, "Next point", ("%s at level %d"):format(p.upcoming.name, ns.Engine.Talents.LevelOfPoint(p.nextIndex)), rankTip)
  elseif p.available == 0 then
    note(rows, "Your first talent point comes at level 10.")
  end
  local nextRow
  for _, r in ipairs(rows) do if r.text == "Next point" then nextRow = r end end
  if nextRow then
    nextRow.emphasis = true
    nextRow.icon = s.icons and p.upcoming and s.icons[p.upcoming.name]
  end
  if p.upcoming then
    row(rows, "Target rank", tostring(p.upcoming.rank), nil, 1)
    local reason = s.build.why and s.build.why[p.upcoming.name]
    if reason then header(rows, "Why this point"); note(rows, reason, 0) end
  elseif p.onPlan and p.spent == p.total then
    note(rows, "Your talent plan is complete.", 0)
  end
  if not p.onPlan then
    blank(rows)
    header(rows, "Different from the plan")
    for _, m in ipairs(p.missing) do
      row(rows, m.name, ("%d / %d"):format(m.have, m.want), "The plan wants more points here.", 1, s.icons and s.icons[m.name])
    end
    for _, x in ipairs(p.extra) do
      row(rows, x.name, ("%d (plan: %d)"):format(x.have, x.want), "Points the plan puts elsewhere.", 1, s.icons and s.icons[x.name])
    end
  end
  if details and s.build.why then
    blank(rows)
    header(rows, "Why")
    local names = {}
    for name in pairs(s.build.why) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
      row(rows, name, nil, s.build.why[name], 1, s.icons and s.icons[name])
      note(rows, s.build.why[name], 2)
    end
  end
end

local function spellRows(rows, list, numbered, icons)
  for i, r in ipairs(list) do
    local text = numbered and ("%d. %s"):format(i, r.spell) or r.spell
    local tip = r.note
    if r.reference and r.reference.description and r.reference.description ~= "" then
      tip = (tip or "") .. "\n\nCaptured spell text (level " .. r.reference.observedAtLevel .. "): " .. r.reference.description
    end
    row(rows, text, rankText(r.rank), tip, 1, icons and icons[r.spell])
    if r.note then note(rows, r.note, 2) end
  end
end

local function upcomingRows(rows, upcoming, icons)
  if #upcoming == 0 then return end
  blank(rows)
  header(rows, "Coming up")
  for _, u in ipairs(upcoming) do
    local when = u.talent and "talent"
      or u.trainable and util.color("green", "train now")
      or u.minLevel and ("level %d"):format(u.minLevel) or ""
    row(rows, u.spell, when, u.note, 1, icons and icons[u.spell])
  end
end

function build.rotation(s, rows)
  local r = s.rotation
  if not r then
    note(rows, "No rotation for this spec yet.", 0)
    return
  end
  if r.scopeNote then note(rows, r.scopeNote, 0); blank(rows) end
  if #r.opener > 0 then header(rows, "Opener"); spellRows(rows, r.opener, true, s.icons); blank(rows) end
  header(rows, "Priority")
  if #r.priority == 0 then note(rows, "Nothing from this list is learned yet.") end
  spellRows(rows, r.priority, true, s.icons)
  if #r.utility > 0 then blank(rows); header(rows, "Also"); spellRows(rows, r.utility, false, s.icons) end
  upcomingRows(rows, r.upcoming, s.icons)
end

local SOURCE_NAMES = { quest = "Quest", craft = "Crafting", vendor = "Vendor", drop = "Drop" }
local function upgradeRow(rows, u, alternative)
  local when
  if not u.now then when = ("Level %d"):format(u.requiredLevel or u.target.minLevel or 0)
  elseif u.status == "unknown" then when = "Check requirements"
  else when = util.color("green", ("+%.1f score"):format(u.gain)) end
  local prefix = alternative and "Alternative: " or (u.slotName .. ": ")
  row(rows, prefix .. u.target.name, when, type(u.target.source) == "string" and u.target.source or nil, 1, u.target.icon)
  if u.selectedForEase then note(rows, "Easier to obtain while keeping most of the stronger option's score gain.", 2) end
  local route = u.route
  if route then
    local source = (SOURCE_NAMES[route.kind] or "Source") .. ": " .. (route.name or "Details unavailable")
    if route.location then source = source .. " — " .. route.location end
    note(rows, source, 2)
    if route.requirements then note(rows, route.requirements, 2) end
    if route.kind == "craft" and route.profession then
      note(rows, "Find a crafter with " .. route.profession .. "; confirm the recipe, materials and price.", 2)
    end
    if u.status == "unknown" then note(rows, "Availability or equipment requirements are not confirmed.", 2) end
    if u.target._status ~= "verified" or route._status ~= "verified" then note(rows, "Source data is provisional.", 2) end
  end
end

function build.gear(s, rows)
  header(rows, "Enchants")
  if #s.enchants == 0 then note(rows, "No enchant advice for your gear yet.") end
  for _, e in ipairs(s.enchants) do
    local status = e.hasEnchant and util.color("gray", "enchanted") or util.color("red", "missing")
    local text = ("%s: %s (%s)"):format(e.slotName, e.best.name, amountText(e.best.stat, e.best.amount))
    local tip = e.best.source == "classic" and "Amount from Classic; not confirmed on Forever yet." or nil
    row(rows, text, status, tip, 1)
  end
  blank(rows)
  header(rows, "Next upgrades")
  if not s.hasUpgradeData then
    note(rows, "No upgrade sources for your class yet. Quest, crafted, vendor and drop options need confirmed data.")
  elseif s.gearUnknown then
    note(rows, "Waiting for equipped item stats; comparisons for those slots are unavailable.")
  elseif #s.upgrades == 0 then
    note(rows, "No suitable upgrade found in the current catalog. Unknown or blocked options may be excluded.")
  end
  for _, u in ipairs(s.upgrades) do
    upgradeRow(rows, u, false)
    if u.alternative then upgradeRow(rows, u.alternative, true) end
  end
end

function build.consumables(s, rows)
  header(rows, ("Best for %s at level %d"):format(s.situation, s.level))
  local any = false
  for _, group in ipairs(ns.Engine.Consumables.GROUP_ORDER) do
    local rec = s.consumables[group]
    if rec then
      any = true
      local e = rec.item
      local have = s.counts and s.counts[e.itemID] or 0
      local bags = have > 0 and ("%d in bags"):format(have) or util.color("gray", "none in bags")
      local what = e.kind == "potion" and "" or (" (" .. amountText(e.stat, e.amount) .. ")")
      row(rows, ("%s: %s%s"):format(ns.Engine.Consumables.GROUP_NAMES[group], e.name, what), bags, nil, 1)
    end
  end
  if not any then note(rows, "Nothing on the list fits your level and spec yet.") end
  blank(rows)
  header(rows, "Missing right now")
  if not s.missing or #s.missing == 0 then
    note(rows, "Nothing: you're set.")
  else
    for _, m in ipairs(s.missing) do
      row(rows, ns.Engine.Consumables.GROUP_NAMES[m.group], util.color("red", m.item.name), nil, 1)
    end
  end
end

function build.healing(s, rows)
  local h = s.healing
  if not h then
    note(rows, "No healing guide for this spec yet.", 0)
    return
  end
  header(rows, "Which heal")
  for _, p in ipairs(h.picks) do
    local what = p.row and (p.row.name .. (p.row.rank > 1 and (" (Rank %d)"):format(p.row.rank) or ""))
      or util.color("gray", "not learned yet")
    local value = p.row and p.row.hpm and ("%.1f per mana"):format(p.row.hpm) or ""
    row(rows, ("%s: %s"):format(p.label, what), value, p.note, 1, p.row and s.icons and s.icons[p.row.name])
    if p.note then note(rows, p.note, 2) end
  end
  blank(rows)
  header(rows, "Heals by mana efficiency")
  if #h.rows == 0 then note(rows, "Learn a heal first.") end
  for _, r in ipairs(h.rows) do
    local value
    if not r.hpm then
      value = util.color("gray", "amount unknown")
    elseif r.overSeconds then
      value = ("%.1f/mana  over %d s  %d mana"):format(r.hpm, r.overSeconds, r.cost or 0)
    else
      value = ("%.1f/mana  %d/s  %d mana"):format(r.hpm, r.hps or 0, r.cost or 0)
    end
    local name = r.name .. (r.rank > 1 and (" (Rank %d)"):format(r.rank) or "")
    if r.targets then name = name .. (" x%d"):format(r.targets) end
    local tip = r.targets and ("Counted for %d targets: the whole party."):format(r.targets) or nil
    row(rows, name, value, tip, 1, s.icons and s.icons[r.name])
  end
  blank(rows)
  header(rows, "Mana plan")
  for _, line in ipairs(h.manaPlan) do note(rows, line) end
  if #h.cooldowns > 0 then
    blank(rows)
    header(rows, "Cooldowns")
    spellRows(rows, h.cooldowns, false, s.icons)
  end
end

function build.tanking(s, rows)
  local t = s.tanking
  if not t then
    note(rows, "No tank guide for this spec yet.", 0)
    return
  end
  if t.setup and #t.setup > 0 then
    blank(rows); header(rows, "Before you pull")
    for _, step in ipairs(t.setup) do
      row(rows, step.label, step.spell, nil, 1, s.icons and step.spell and s.icons[step.spell])
      note(rows, step.note, 2)
    end
  end
  blank(rows)
  header(rows, "One target"); spellRows(rows, t.single, true, s.icons)
  blank(rows); header(rows, "A pack"); spellRows(rows, t.multi, true, s.icons)
  blank(rows); header(rows, "Cooldowns"); spellRows(rows, t.cooldowns, false, s.icons)
  blank(rows); header(rows, "Pull plan")
  for i, line in ipairs(t.pullPlan) do note(rows, ("%d. %s"):format(i, line)) end
  upcomingRows(rows, t.upcoming, s.icons)
end

-- All rows for one tab.
function UI.BuildRows(tab, state, contentOnly, details)
  local rows = contentOnly and state.ready and state.supported and {} or UI.Banner(state)
  if not state.ready or not state.supported then return rows end
  if contentOnly and state.error then note(rows, state.error, 0) end
  local fn = build[tab]
  if fn then fn(state, rows, details) end
  return rows
end
