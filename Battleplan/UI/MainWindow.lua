-- A reusable planner window. Context controls are local settings; game reads
-- and planning stay behind the API wrapper and the out-of-combat scheduler.
local _, ns = ...
local UI = ns.UI
local WIDTH, HEIGHT = 760, 700
local frame, list, tabButtons, specButton, modeButton, detailsButton, menu
local context, badge, sizeLabel
local currentTab, showDetails = "talents", false
local shownVersion, shownTab, shownDetails
local MODES = { "auto", "leveling", "solo", "dungeon", "raid" }

local function label(parent, text, font, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  UI.ReadableFont(fs, "row", font)
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(text)
  return fs
end
local function tooltip(self)
  if not self.tip then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(self.tip, 0.94, 0.95, 0.97, nil, true)
  GameTooltip:Show()
end
local function hideTooltip() GameTooltip:Hide() end
local function button(parent, text, width, height)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, height)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  UI.ReadableFont(b.label, "row", "GameFontNormal")
  b.label:SetPoint("CENTER")
  b:SetFontString(b.label)
  b:SetText(text)
  b:SetScript("OnEnter", tooltip)
  b:SetScript("OnLeave", hideTooltip)
  return b
end
local function savePosition(f)
  local point, _, relPoint, x, y = f:GetPoint()
  ns.db.window = { point = point, relPoint = relPoint, x = x, y = y }
end
local function paintTabs()
  for _, b in ipairs(tabButtons) do
    local selected = b.key == currentTab
    if selected then b:LockHighlight() else b:UnlockHighlight() end
    b.label:SetTextColor(1, selected and 1 or 0.82, selected and 1 or 0)
  end
end
local function selectTab(key)
  if ns.InCombat() then return end
  currentTab = key
  menu:Hide()
  UI.CloseGearPicker()
  paintTabs()
  if list.pulse then list.pulse:Play() end
  list:ScrollToTop()
  UI.Refresh(true)
end
local function layoutTabs()
  local tabs = UI.TabsFor(ns.state)
  local valid = false
  for i, b in ipairs(tabButtons) do
    local t = tabs[i]
    b:SetShown(t ~= nil)
    if t then
      b.key = t.key
      if b.text ~= t.label then b.text = t.label; b:SetText(t.label) end
      if t.key == currentTab then valid = true end
    else b.key = nil end
  end
  if not valid then currentTab = "talents" end
  paintTabs()
end

local function choose(self)
  if ns.InCombat() then return end
  ns.db[menu.setting] = self.value
  menu:Hide()
  ns.Planner.Queue()
end
local function openMenu(self)
  if ns.InCombat() then return end
  if menu:IsShown() and menu.owner == self then menu:Hide(); return end
  menu.owner, menu.setting = self, self.setting
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -4)
  local specs = ns.Data[ns.state.class] and ns.Data[ns.state.class].Specs
  local choices = self.setting == "spec" and specs and specs.order or MODES
  local count = self.setting == "spec" and (specs and #choices + 1 or 1) or #choices
  for i, option in ipairs(menu.options) do
    local value = self.setting == "spec" and (i == 1 and "auto" or choices[i - 1]) or choices[i]
    option:SetShown(i <= count)
    if i <= count then
      option.value = value
      local text = value == "auto" and "Auto" or self.setting == "spec" and specs.names[value] or ns.util.title(value)
      option:SetText((ns.db[self.setting] == value and "* " or "  ") .. text)
    end
  end
  menu:SetHeight(count * 34 + 8)
  menu:Show()
end
local function toggleDetails()
  if ns.InCombat() then return end
  showDetails = not showDetails
  detailsButton:SetText(showDetails and "Hide build details" or "Show build details")
  UI.Refresh(true)
end
local function close() UI.Hide() end

-- UIParent dimensions are UI units, so this also respects the player's UI scale.
local function applyScale()
  if ns.InCombat() then return end
  local scale = tonumber(ns.db.uiScale) or 1
  if scale ~= scale then scale = 1 end
  scale = ns.util.clamp(scale, 0.8, 1.4)
  ns.db.uiScale = scale
  local fit = math.min((UIParent:GetWidth() - 32) / WIDTH, (UIParent:GetHeight() - 32) / HEIGHT)
  local applied = math.max(0.1, math.min(scale, fit))
  frame:SetScale(applied)
  sizeLabel:SetText("Size " .. math.floor(applied * 100 + 0.5) .. "%")
end
local function changeSize(self)
  if ns.InCombat() then return end
  ns.db.uiScale = ns.util.clamp(ns.db.uiScale + self.step, 0.8, 1.4)
  applyScale()
end
local function screenChanged()
  if frame then ns.Refresh("ui-scale", 0, applyScale) end
end
ns.Events:On("DISPLAY_SIZE_CHANGED", screenChanged, "planner-size")
ns.Events:On("UI_SCALE_CHANGED", screenChanged, "planner-size")

local function create()
  local f = CreateFrame("Frame", "BattleplanFrame", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(WIDTH, HEIGHT)
  local pos = ns.db.window or {}
  if pos.point then f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
  else f:SetPoint("CENTER") end
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  local titleBar = CreateFrame("Frame", nil, f)
  titleBar:SetPoint("TOPLEFT", 30, -2)
  titleBar:SetPoint("TOPRIGHT", -30, -2)
  titleBar:SetHeight(26)
  titleBar:SetFrameLevel(f:GetFrameLevel() + 3)
  f:SetMovable(true)
  titleBar:EnableMouse(true)
  titleBar:RegisterForDrag("LeftButton")
  titleBar:SetScript("OnDragStart", function() if not ns.InCombat() then f:StartMoving() end end)
  titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePosition(f) end)
  -- Keep content above the template's inset; the drag region has no opaque fill.
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", 8, -28)
  content:SetPoint("BOTTOMRIGHT", -8, 8)
  content:SetFrameLevel(f:GetFrameLevel() + 2)
  local title = label(titleBar, "Battleplan", "GameFontHighlight", 0, 0)
  title:ClearAllPoints()
  title:SetPoint("TOP", 0, -5)
  local x = f.CloseButton
  if type(x) ~= "table" and type(x) ~= "userdata" then
    x = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    x:SetPoint("TOPRIGHT", 0, 0)
  end
  x:SetFrameLevel(f:GetFrameLevel() + 4)
  x:SetScript("OnClick", close)
  context = label(content, "", "GameFontNormal", 14, -12)
  badge = CreateFrame("Button", nil, content)
  badge:SetSize(170, 20)
  badge:SetPoint("TOPRIGHT", -14, -8)
  badge.label = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  UI.ReadableFont(badge.label, "row", "GameFontNormal")
  badge.label:SetPoint("RIGHT")
  badge.SetText = function(self, text) self.label:SetText(text) end
  badge.tip = "Provisional advice is a first draft. Captured facts are labeled separately; build choices still need testing."
  badge:SetScript("OnEnter", tooltip)
  badge:SetScript("OnLeave", hideTooltip)

  label(content, "Spec", nil, 14, -49)
  specButton = button(content, "Auto", 190, 30)
  specButton:SetPoint("TOPLEFT", 54, -40)
  specButton.setting, specButton.tip = "spec", "Choose a spec to plan for, or Auto to follow your talents."
  specButton:SetScript("OnClick", openMenu)
  label(content, "Situation", nil, 264, -49)
  modeButton = button(content, "Auto", 190, 30)
  modeButton:SetPoint("TOPLEFT", 334, -40)
  modeButton.setting, modeButton.tip = "situation", "Choose leveling, solo, dungeon or raid advice. Auto follows your level."
  modeButton:SetScript("OnClick", openMenu)
  detailsButton = button(content, "Show build details", 190, 30)
  detailsButton:SetPoint("TOPRIGHT", -14, -40)
  detailsButton:SetScript("OnClick", toggleDetails)
  tabButtons = {}
  for i = 1, 5 do
    local b = button(content, "", 140, 30)
    b:SetPoint("TOPLEFT", 14 + (i - 1) * 144, -84)
    b:SetScript("OnClick", function(self) selectTab(self.key) end)
    tabButtons[i] = b
  end
  list = UI.CreateList(content)
  list:SetPoint("TOPLEFT", 14, -126)
  list:SetPoint("BOTTOMRIGHT", -14, 44)
  UI.AddPulse(list)
  UI.AddFade(f)
  local hint = label(content, "Scroll for more  |  Hover for extra details", "GameFontDisableSmall", 0, 0)
  hint:ClearAllPoints()
  hint:SetPoint("BOTTOMLEFT", 14, 12)
  sizeLabel = label(content, "", nil, 0, 0)
  sizeLabel:ClearAllPoints()
  sizeLabel:SetPoint("BOTTOMRIGHT", -58, 12)
  local smaller = button(content, "-", 32, 28)
  smaller:SetPoint("BOTTOMRIGHT", -154, 5)
  smaller.step, smaller.tip = -0.1, "Make Battleplan smaller. Your size preference is saved."
  smaller:SetScript("OnClick", changeSize)
  local larger = button(content, "+", 32, 28)
  larger:SetPoint("BOTTOMRIGHT", -14, 5)
  larger.step, larger.tip = 0.1, "Make Battleplan larger. The window stays within your screen."
  larger:SetScript("OnClick", changeSize)
  menu = CreateFrame("Frame", nil, f, "BackdropTemplate")
  menu:SetWidth(220)
  menu:SetFrameStrata("DIALOG")
  menu:EnableMouse(true)
  menu:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  menu:SetBackdropColor(0.08, 0.08, 0.08, 1)
  menu.options = {}
  for i = 1, 5 do
    local option = button(menu, "", 212, 30)
    option:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 34)
    option:SetScript("OnClick", choose)
    menu.options[i] = option
  end
  menu:Hide()
  f:SetScript("OnMouseDown", function() menu:Hide(); UI.CloseGearPicker() end)
  f:SetScript("OnHide", function() menu:Hide(); UI.CloseGearPicker(); GameTooltip:Hide() end)
  f:SetScript("OnShow", function() ns.Planner.Queue(); UI.Refresh(true) end)
  f:Hide()
  tinsert(UISpecialFrames, "BattleplanFrame")
  frame, UI.frame, UI.list = f, f, list
  UI.controls = { spec = specButton, situation = modeButton, details = detailsButton, menu = menu,
    smaller = smaller, larger = larger, size = sizeLabel, context = context, title = title,
    content = content, close = x, tabs = tabButtons }
  applyScale()
  list:Layout()
end

function UI.IsShown() return frame ~= nil and frame:IsShown() end
function UI.Refresh(force)
  if not UI.IsShown() or ns.InCombat() then return end
  local s = ns.state
  if not force and shownVersion == s.version and shownTab == currentTab and shownDetails == showDetails then return end
  layoutTabs()
  shownVersion, shownTab, shownDetails = s.version, currentTab, showDetails
  context:SetText(s.supported and ((s.specName or "") .. "  |  Level " .. (s.level or 0)) or "Preparing your plan")
  badge:SetText(s.provisional and "Provisional advice" or "Plan ready")
  badge:SetShown(s.supported == true)
  local specs = ns.Data[s.class] and ns.Data[s.class].Specs
  local specText = ns.db.spec == "auto" and ("Auto: " .. (s.specName or ""))
    or (specs and specs.names[ns.db.spec] or "Auto")
  local modeText = ns.db.situation == "auto" and ("Auto: " .. ns.util.title(s.situation or "leveling"))
    or ns.util.title(ns.db.situation)
  specButton:SetText(specText .. "  v")
  modeButton:SetText(modeText .. "  v")
  detailsButton:SetShown(currentTab == "talents" and s.build ~= nil)
  list:SetData(UI.BuildRows(currentTab, s, true, showDetails))
end
local function show()
  if not frame then create() end
  applyScale()
  UI.ShowSmooth(frame)
end
function UI.Show() ns.OutOfCombat(show) end
function UI.Hide() if frame and frame:IsShown() then UI.HideSmooth(frame) end end
function UI.Toggle() if UI.IsShown() then UI.Hide() else UI.Show() end end
function UI.SelectTab(key)
  if ns.InCombat() then return end
  if not frame then create() end
  selectTab(key)
end
function UI.CurrentTab() return currentTab end
