"""A small mock of the Forever client for the offline tests.

Runs the real addon files on Lua 5.1 (the version WoW uses) with stub frames
and fake game data. Each test builds a fresh runtime from a character
description, so classes and levels don't leak between tests.

    pip install "lupa>=2.0"
"""
from pathlib import Path
from lupa import lua51

ROOT = Path(__file__).resolve().parent.parent

MOCK = r'''
unpack = unpack or table.unpack
printed = {}
function print(...)
  local t = {}
  for i = 1, select('#', ...) do t[#t + 1] = tostring((select(i, ...))) end
  printed[#printed + 1] = table.concat(t, " ")
end
function date() return "2026-10-05 15:00:00" end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
function debugprofilestop() return os.clock() * 1000 end
function geterrorhandler() return function(e) error(e, 0) end end

-- Frames: any method not defined returns the frame, so chains work. The
-- method is made once and kept, so the mock itself never allocates on a
-- repeat call (perf_test measures Battleplan's allocations, not the mock's).
local function stub()
  return setmetatable({}, { __index = function(t, k)
    local f = function() return t end
    rawset(t, k, f)
    return f
  end })
end
frames = {}
-- An event this mock client doesn't have (Forever may lack Classic's).
MISSING_EVENTS = { CHARACTER_POINTS_CHANGED = true }
local function fontString()
  local fs = stub()
  fs.SetText = function(self, t) self.text = t end
  fs.GetText = function(self) return self.text end
  fs.SetWidth = function(self, w) self.width = w end
  fs.SetWordWrap = function(self, w) self.wrap = w end
  fs.GetStringHeight = function(self)
    local text = (self.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local chars = math.max(1, math.floor((self.width or 200) / 7))
    local lines = 0
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
      lines = lines + (self.wrap and math.max(1, math.ceil(#line / chars)) or 1)
    end
    return lines * 16
  end
  return fs
end
local function animGroup(owner)
  local g = stub()
  g.CreateAnimation = function() return stub() end
  g.Play = function(self) self.playing = true; owner.alpha = 1 end
  g.Stop = function(self) self.playing = false end
  g.SetScript = function(self, k, fn) self["_" .. k] = fn end
  return g
end
function CreateFrame(kind, name, parent, template)
  local f = stub()
  f._kind, f._events, f._shown, f._height = kind, {}, true, 400
  f._parent, f._template = parent, template
  f._frameLevel = parent and rawget(parent, "_frameLevel") and parent._frameLevel + 1 or 0
  f.GetFrameLevel = function(self) return self._frameLevel end
  f.SetFrameLevel = function(self, level) self._frameLevel = level end
  f.RegisterEvent = function(self, e)
    -- Like the real client: an event it doesn't have is an error.
    if MISSING_EVENTS[e] then error("Attempt to register unknown event \"" .. e .. "\"") end
    self._events[e] = true
  end
  f.SetScript = function(self, k, fn) self["_" .. k] = fn end
  f.GetScript = function(self, k) return self["_" .. k] end
  f.IsShown = function(self) return self._shown end
  f.Show = function(self)
    local was = self._shown
    self._shown = true
    if not was and self._OnShow then self._OnShow(self) end
  end
  f.Hide = function(self) self._shown = false end
  f.SetShown = function(self, v) if v then self:Show() else self:Hide() end end
  f.GetHeight = function(self) return self._height end
  f.GetWidth = function(self) return rawget(self, "_width") or 600 end
  f.SetSize = function(self, w, h) self._width, self._height = w, h end
  f.SetWidth = function(self, w) self._width = w end
  f.SetHeight = function(self, h) self._height = h end
  f.SetText = function(self, t) self.text = t end
  f.GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end
  f.CreateFontString = function() local fs=fontString(); fs._parent=f; return fs end
  f.CreateTexture = function()
    local t = stub()
    t._shown = true
    t.Show = function(self) self._shown = true end
    t.Hide = function(self) self._shown = false end
    t.SetShown = function(self, v) self._shown = v end
    t.SetTexture = function(self, v) self.texture = v end
    return t
  end
  f.CreateAnimationGroup = function(self) return animGroup(self) end
  f.LockHighlight = function(self) self.highlit = true end
  f.UnlockHighlight = function(self) self.highlit = false end
  if template == "BasicFrameTemplateWithInset" then
    f.CloseButton = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  end
  frames[#frames + 1] = f
  if name then _G[name] = f end
  return f
end
function fire(event, ...)
  for _, f in ipairs(frames) do
    if f._events[event] and f._OnEvent then f._OnEvent(f, event, ...) end
  end
end
UIParent = CreateFrame("Frame"); UISpecialFrames = {}; GameTooltip = CreateFrame("Frame")
SlashCmdList = {}
C_Timer = { After = function(_, fn) fn() end }
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1, FutureSpell = 4 } }
C_AddOns = { GetAddOnMetadata = function() return "0.1.0-dev" end, IsAddOnLoaded = function() return true end }
function GetBuildInfo() return "1.60.1", "70205", "Oct 2 2026", 16001 end
function GetLocale() return "enUS" end
WOW_PROJECT_ID = 18

IN_COMBAT = false
function InCombatLockdown() return IN_COMBAT end
function issecretvalue(v) return v == "SECRET" end

-- Character (filled per test from C) ---------------------------------------------
function UnitClass() return C.className, C.class end
function UnitRace() return "Gnome", "Gnome" end
function UnitLevel() return C.level end
function UnitFullName() return "Tester", "Beta" end
function UnitName() return "Tester" end
function UnitExists() return true end
function IsInInstance() return C.instance ~= nil, C.instance or "none" end
function GetRealZoneText() return "Stormwind City" end

-- Talents (Traits API, like the beta): C.nodes = { {group, name, rank, x} }
C_ClassTalents = { GetActiveConfigID = function() return 1 end }
C_Traits = {
  GetConfigInfo = function() return { treeIDs = { 1111 } } end,
  GetTreeNodes = function() local ids = {} for i = 1, #C.nodes do ids[i] = i end return ids end,
  GetNodeInfo = function(_, id)
    local n = C.nodes[id]
    return { groupIDs = { n[1] }, activeRank = n[3], maxRanks = 5, entryIDs = { id }, posX = n[4] or 0, posY = id }
  end,
  GetEntryInfo = function(_, id) return { definitionID = id } end,
  GetDefinitionInfo = function(id) return { spellID = 900000 + id } end,
}

-- Spells: C.book = { {name, rank, spellID, cost, castMs, text} }
C_SpellBook = {
  GetNumSpellBookSkillLines = function() return 1 end,
  GetSpellBookSkillLineInfo = function() return { name = "Class", itemIndexOffset = 0, numSpellBookItems = #C.book } end,
  GetSpellBookItemInfo = function(i)
    local s = C.book[i]
    return { spellID = s[3], name = s[1], subName = s[2] and ("Rank " .. s[2]) or "", itemType = 1 }
  end,
}
local function spell(id)
  for _, s in ipairs(C.book) do if s[3] == id then return s end end
end
C_Spell = {
  GetSpellName = function(id)
    local n = C.nodes[id - 900000]
    return n and n[2]
  end,
  GetSpellInfo = function(id) local s = spell(id) return s and { name = s[1], castTime = s[5] or 0, iconID = s[7] } end,
  GetSpellPowerCost = function(id) local s = spell(id) return s and s[4] and { { type = 0, cost = s[4] } } or {} end,
  GetSpellDescription = function(id) local s = spell(id) return s and s[6] or "" end,
}

-- Items and gear: C.inv = { [slot] = link }, C.itemStats = { [link] = {...} }
function GetInventoryItemLink(_, slot) return C.inv[slot] end
C_Item = {
  GetItemStats = function(link) return C.itemStats[link] end,
  GetItemSpell = function(id) local n = C.itemSpells[id] return n, n and id end,
  GetItemCount = function(id) return C.bags[id] or 0 end,
  RequestLoadItemDataByID = function() end,
  GetItemInfo = function(id) return "Item " .. id, nil, 1, 1, 1 end,
}
C_TooltipInfo = { GetItemByID = function(id) return { lines = { { leftText = "Item " .. id }, { leftText = "Use: does a thing." } } } end }
C_UnitAuras = {
  GetAuraDataByIndex = function(_, i)
    local a = C.auras[i]
    return a and { name = a[1], spellId = a[2] } or nil
  end,
}
function GetWeaponEnchantInfo() return C.weaponMH, 0, 0, 0, false end

-- Stat lab readings (probe): C.stats = { name = value }
local function st(k) return C.stats[k] or 0 end
function UnitStat(_, i) local k = ({ "str", "agi", "sta", "int", "spi" })[i] return st(k), st(k), 0, 0 end
function UnitArmor() return st("armor"), st("armor") end
-- Forever has UnitDefenseSkill (base, modifier), not UnitDefense (2026-10-05-warrior-12).
function UnitDefenseSkill() return st("def"), st("def_mod") end
function UnitHealthMax() return st("hp") end
function UnitPowerMax() return 100 end
function UnitAttackPower() return st("ap"), 0, 0 end
function GetCritChance() return st("crit") end
function GetHaste() return "SECRET" end
function GetCombatRating() return 0 end
function GetCombatRatingBonus() return 0 end
CR_HIT_MELEE = 6
'''


def runtime(char):
    """A fresh Lua 5.1 runtime with the mock client and `char` as C."""
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    assert L.eval("_VERSION") == "Lua 5.1"
    L.execute("C = {}")
    L.execute(MOCK)
    set_char(L, char)
    return L


def set_char(L, char):
    """Replace the character description (Lua source for a table)."""
    L.execute("C = " + char)
    L.execute("""
      C.nodes = C.nodes or {}; C.book = C.book or {}; C.inv = C.inv or {}; C.itemStats = C.itemStats or {}
      C.itemSpells = C.itemSpells or {}; C.bags = C.bags or {}; C.auras = C.auras or {}; C.stats = C.stats or {}
    """)


def load(L, folder, toc):
    """Load an addon's files in .toc order with a shared namespace table."""
    ns = L.table()
    loader = L.eval("function(src, name) return assert(loadstring(src, '@' .. name)) end")
    for line in (ROOT / folder / toc).read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        path = ROOT / folder / line.replace("\\", "/")
        loader(path.read_text(), str(path.relative_to(ROOT)))(folder, ns)
    return ns


def start_battleplan(L):
    """Load Battleplan, log in, and run the first plan to the end."""
    ns = load(L, "Battleplan", "Battleplan.toc")
    L.globals().fire("ADDON_LOADED", "Battleplan")
    L.globals().fire("PLAYER_LOGIN")
    drain(L, ns)
    return ns


def drain(L, ns):
    L.eval("function(ns) ns.Jobs:Drain() end")(ns)


def printed(L):
    p = L.globals().printed
    return [p[i] for i in range(1, len(p) + 1)]


def screen(L, ns, tab):
    """Every row of a tab as 'text | value' lines."""
    return L.eval("""function(ns, tab)
      local out = {}
      for _, r in ipairs(ns.UI.BuildRows(tab, ns.state)) do
        out[#out + 1] = (r.text or "") .. " | " .. (r.value or "")
      end
      return table.concat(out, "\\n")
    end""")(ns, tab)


# Characters -------------------------------------------------------------------------

ROGUE_30 = r'''{
  class = "ROGUE", className = "Rogue", level = 30,
  nodes = {
    -- Combat (group 11573): the build's first 20 points, Blade Flurry not yet
    { 11573, "Improved Sinister Strike", 2, 5100 }, { 11573, "Lightning Reflexes", 3, 5200 },
    { 11573, "Precision", 3, 5300 }, { 11573, "Deflection", 3, 5400 }, { 11573, "Riposte", 1, 5500 },
    { 11573, "Endurance", 1, 5600 }, { 11573, "Improved Sprint", 2, 5700 },
    { 11573, "Dual Wield Specialization", 5, 5800 }, { 11573, "Blade Flurry", 0, 5900 },
    -- Assassination (11580): one point the plan doesn't want
    { 11580, "Malice", 1, 1100 }, { 11580, "Mutilate", 0, 1200 },
    -- Subtlety (11572)
    { 11572, "Hemorrhage", 0, 9100 },
  },
  book = {
    { "Sinister Strike", 1, 1752 }, { "Sinister Strike", 5, 11293 }, { "Eviscerate", 4, 8623 },
    { "Slice and Dice", 1, 5171 }, { "Kick", 1, 1766 }, { "Evasion", nil, 5277 }, { "Riposte", nil, 14251 },
    { "Cheap Shot", nil, 1833 }, { "Backstab", 3, 2590 }, { "Kidney Shot", 1, 408 },
  },
  inv = { [9] = "item:100:0:0", [5] = "item:101:15:0", [16] = "item:102:0:0", [1] = "item:103:0:0" },
  itemStats = {
    ["item:103:0:0"] = { ITEM_MOD_AGILITY_SHORT = 10, ITEM_MOD_HIT_RATING_SHORT = 10 },
  },
  itemSpells = { [8949] = "Agility", [3390] = "Lesser Agility", [13452] = "Elixir of the Mongoose" },
  bags = { [8949] = 3 },
  auras = { { "Well Fed", 24800 } },
  weaponMH = false,
  stats = { str = 33, agi = 66, sta = 56, int = 26, spi = 29, armor = 487, hp = 601, ap = 117, crit = 13.69 },
}'''

PRIEST_40 = r'''{
  class = "PRIEST", className = "Priest", level = 40,
  nodes = {
    { 11615, "Improved Renew", 3, 5100 }, { 11615, "Holy Specialization", 2, 5200 },
    { 11615, "Divine Fury", 5, 5300 }, { 11615, "Inspiration", 3, 5400 }, { 11615, "Holy Nova", 1, 5500 },
    { 11615, "Blessed Recovery", 1, 5600 }, { 11615, "Improved Healing", 3, 5700 }, { 11615, "Holy Reach", 2, 5800 },
    { 11615, "Spiritual Guidance", 5, 5900 }, { 11615, "Spiritual Healing", 3, 6000 },
    { 11615, "Holy Specialization", 5, 6100 },
    { 11608, "Twin Disciplines", 0, 1100 }, { 11622, "Spirit Tap", 0, 9100 },
  },
  book = {
    { "Lesser Heal", 1, 2050, 30, 1500, "Heals your target for 47 to 58." },
    { "Lesser Heal", 3, 2053, 75, 2500, "Heals your target for 135 to 158." },
    { "Heal", 1, 2054, 155, 3000, "Heals your target for 295 to 341." },
    { "Heal", 3, 6064, 255, 3000, "Heals your target for 566 to 642." },
    { "Greater Heal", 1, 2060, 370, 3000, "Heals your target for 899 to 1013." },
    { "Flash Heal", 3, 9473, 215, 1500, "Heals a friendly target for 327 to 394." },
    { "Renew", 2, 6074, 65, 0, "Heals the target for 100 over 15 sec." },
    { "Renew", 6, 6078, 205, 0, "Heals the target for 410 over 15 sec." },
    { "Power Word: Shield", 6, 10898, 210, 0, "Draws on the soul of the party member to shield them, absorbing 381 damage. Lasts 30 sec." },
    { "Prayer of Healing", 2, 996, 560, 3000, "A powerful prayer heals party members within 30 yards for 412 to 437." },
    { "Inner Focus", nil, 14751 }, { "Fade", 3, 9578 }, { "Smite", 5, 6060 },
    { "Shadow Word: Pain", 5, 10892 }, { "Mind Blast", 5, 8106 },
  },
  inv = { [16] = "item:200:0:0" },
  itemSpells = { [20007] = "Mageblood Potion", [9179] = "Greater Intellect" },
  auras = { { "Mageblood Potion", 24363 } },
  weaponMH = false,
}'''

WARRIOR_20 = r'''{
  class = "WARRIOR", className = "Warrior", level = 20,
  nodes = {
    -- Confirmed spec groups; synthetic level-20 allocation in Protection.
    { 11650, "Deflection", 0, 1000 }, { 11650, "Improved Tactical Mastery", 0, 1500 },
    { 11657, "Cruelty", 0, 5000 }, { 11657, "Unbridled Wrath", 0, 5500 },
    { 11670, "Shield Specialization", 5, 9000 }, { 11670, "Anticipation", 5, 9500 },
    { 11670, "Improved Revenge", 1, 9800 },
  },
  book = {
    { "Heroic Strike", 3, 285 }, { "Sunder Armor", 2, 7386 }, { "Revenge", 1, 6572 },
    { "Thunder Clap", 2, 6343 }, { "Taunt", nil, 355 }, { "Shield Block", nil, 2565 },
  },
  inv = { [16] = "item:300:0:0" },
  weaponMH = true,
}'''

MAGE_20 = r'''{ class = "MAGE", className = "Mage", level = 20 }'''
