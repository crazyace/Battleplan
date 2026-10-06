-- The Gear tab's per-slot picker: click a suggestion to see every option for
-- that slot, grouped by where it comes from, and choose the one to chase.
-- Built once on first open and reused; the choice is saved by item ID.
local _, ns = ...
local UI = ns.UI
local util = ns.util

local WIDTH, ENTRY = 420, 28
local KIND_ORDER = { "quest", "craft", "vendor", "drop", "other" }
local KIND_NAMES = { quest = "Quests", craft = "Crafted", vendor = "Vendors", drop = "Drops", other = "Other" }
-- At most Gear.MAX_OPTIONS options plus one heading per kind.
local MAX_ENTRIES = ns.Engine.Gear.MAX_OPTIONS + #KIND_ORDER
local CHECK = "|TInterface\\Buttons\\UI-CheckBox-Check:16:16|t "
local picker

local function kindOf(option)
  local kind = option.route and option.route.kind
  return KIND_NAMES[kind] and kind or "other"
end

local function onEnter(entry)
  local option = entry.option
  if not option then return end
  entry.highlight:Show()
  GameTooltip:SetOwner(entry, "ANCHOR_RIGHT")
  if entry.hyperlink and GameTooltip.SetHyperlink then
    GameTooltip:SetHyperlink(entry.hyperlink)
    GameTooltip:AddLine(" ")
  else
    GameTooltip:SetText(option.target.name, 1, 0.82, 0, 1, true)
  end
  GameTooltip:AddLine(UI.GearItemTip(option, ns.state.equippedLinks), 1, 1, 1, true)
  GameTooltip:Show()
end
local function onLeave(entry)
  entry.highlight:Hide()
  GameTooltip:Hide()
end

-- Click: chase this one (the recommendation clears the saved pick).
-- Shift-click: link it in chat, like the Gear tab's rows.
local function onClick(entry)
  local option = entry.option
  if not option or ns.InCombat() then return end
  if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
    local link = option.target.itemID and ns.API.ItemLink(option.target.itemID)
    if link then ChatEdit_InsertLink(link) end
    return
  end
  ns.db.gearPicks = ns.db.gearPicks or {}
  ns.db.gearPicks[picker.slot] = option ~= picker.recommended and option.target.itemID or nil
  picker:Hide()
  GameTooltip:Hide()
  UI.Refresh(true)
end

local function create()
  picker = CreateFrame("Frame", nil, UI.frame, "BackdropTemplate")
  picker:SetWidth(WIDTH)
  picker:SetFrameStrata("DIALOG")
  picker:SetClampedToScreen(true)
  picker:EnableMouse(true)
  picker:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  picker:SetBackdropColor(0.08, 0.08, 0.08, 1)
  picker.entries = {}
  for i = 1, MAX_ENTRIES do
    local e = CreateFrame("Button", nil, picker)
    e:SetHeight(ENTRY)
    e:SetPoint("TOPLEFT", 6, -6 - (i - 1) * ENTRY)
    e:SetPoint("TOPRIGHT", -6, -6 - (i - 1) * ENTRY)
    e.highlight = e:CreateTexture(nil, "BACKGROUND")
    e.highlight:SetAllPoints()
    e.highlight:SetColorTexture(1, 0.82, 0, 0.12)
    e.highlight:Hide()
    e.icon = e:CreateTexture(nil, "ARTWORK")
    e.icon:SetSize(22, 22)
    e.icon:SetPoint("LEFT", 4, 0)
    e.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    e.left = e:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    UI.ReadableFont(e.left, "row")
    e.left:SetPoint("LEFT", 32, 0)
    e.left:SetJustifyH("LEFT")
    e.right = e:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    UI.ReadableFont(e.right, "row")
    e.right:SetPoint("RIGHT", -4, 0)
    e.right:SetJustifyH("RIGHT")
    e:SetScript("OnEnter", onEnter)
    e:SetScript("OnLeave", onLeave)
    e:SetScript("OnClick", onClick)
    picker.entries[i] = e
  end
  picker:Hide()
end

local function heading(e, kind)
  e.option, e.hyperlink = nil, nil
  e.icon:Hide()
  e.left:SetText(util.color("gold", KIND_NAMES[kind]))
  e.right:SetText("")
  e:Show()
end

local function choice(e, option, d)
  e.option = option
  local id = option.target.itemID
  e.hyperlink = id and ("item:" .. id) or nil
  if option.target.icon then e.icon:SetTexture(option.target.icon); e.icon:Show() else e.icon:Hide() end
  local name = (option == d.picked and CHECK or "") .. option.target.name
  if option == d.recommended then name = name .. util.color("gray", "  (recommended)") end
  e.left:SetText(name)
  e.right:SetText(UI.GearValue(option, true))
  e:Show()
end

-- Open (or close, on a second click) the picker under a Gear row.
function UI.OpenGearPicker(row, d)
  if ns.InCombat() or not (d and d.choices) or not UI.frame then return end
  if not picker then create() end
  if picker:IsShown() and picker.slot == d.slot then picker:Hide(); return end
  picker.slot, picker.recommended = d.slot, d.recommended
  local n = 0
  for _, kind in ipairs(KIND_ORDER) do
    local headed = false
    for _, option in ipairs(d.choices) do
      if kindOf(option) == kind then
        if not headed then n = n + 1; heading(picker.entries[n], kind); headed = true end
        n = n + 1
        choice(picker.entries[n], option, d)
      end
    end
  end
  for i = n + 1, MAX_ENTRIES do picker.entries[i]:Hide(); picker.entries[i].option = nil end
  picker:SetHeight(n * ENTRY + 12)
  picker:ClearAllPoints()
  picker:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", -8, 2)
  picker:Show()
end

function UI.CloseGearPicker()
  if picker then picker:Hide() end
end

-- The picker's entry frames while it's open (tests read them).
function UI.GearPickerEntries()
  if not (picker and picker:IsShown()) then return nil end
  return picker.entries
end
