-- A reusable planner window. Context controls are local settings; game reads
-- and planning stay behind the API wrapper and the out-of-combat scheduler.
local _, ns = ...
local UI = ns.UI
local WIDTH, HEIGHT = 640, 620
local frame, list, tabButtons, specButton, modeButton, detailsButton, menu
local context, badge
local currentTab, showDetails = "talents", false
local shownVersion, shownTab, shownDetails
local MODES = { "auto", "leveling", "solo", "dungeon", "raid" }

local function fill(parent, r, g, b, a)
  local texture = parent:CreateTexture(nil, "BACKGROUND")
  texture:SetAllPoints()
  texture:SetColorTexture(r, g, b, a or 1)
  return texture
end
local function label(parent, text, font, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
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
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, height)
  b.background = fill(b, 0.13, 0.17, 0.23)
  local highlight = b:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints()
  highlight:SetColorTexture(1, 1, 1, 0.07)
  b:SetHighlightTexture(highlight)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
    b.accent:SetShown(selected)
    b.label:SetTextColor(selected and 1 or 0.70, selected and 0.84 or 0.76, selected and 0.64 or 0.82)
  end
end
local function selectTab(key)
  if ns.InCombat() then return end
  currentTab = key
  menu:Hide()
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
  menu:SetHeight(count * 30 + 8)
  menu:Show()
end
local function toggleDetails()
  if ns.InCombat() then return end
  showDetails = not showDetails
  detailsButton:SetText(showDetails and "Hide build details" or "Show build details")
  UI.Refresh(true)
end
local function close() UI.Hide() end

local function create()
  local f = CreateFrame("Frame", "BattleplanFrame", UIParent)
  f:SetSize(WIDTH, HEIGHT)
  local pos = ns.db.window or {}
  if pos.point then f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
  else f:SetPoint("CENTER") end
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  fill(f, 0.055, 0.075, 0.10, 0.98)
  local titleBar = CreateFrame("Frame", nil, f)
  titleBar:SetPoint("TOPLEFT")
  titleBar:SetPoint("TOPRIGHT")
  titleBar:SetHeight(58)
  fill(titleBar, 0.09, 0.12, 0.17)
  f:SetMovable(true)
  titleBar:EnableMouse(true)
  titleBar:RegisterForDrag("LeftButton")
  titleBar:SetScript("OnDragStart", function() if not ns.InCombat() then f:StartMoving() end end)
  titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing(); savePosition(f) end)
  label(f, "Battleplan", "GameFontNormalLarge", 22, -16)
  label(f, "Your plan between pulls", nil, 22, -38):SetTextColor(0.70, 0.76, 0.82)
  local x = button(f, "X", 28, 28)
  x:SetPoint("TOPRIGHT", -12, -12)
  x.tip = "Close (Escape)"
  x:SetScript("OnClick", close)
  context = label(f, "", nil, 330, -14)
  badge = button(f, "", 170, 20)
  badge:SetPoint("TOPRIGHT", -48, -36)
  badge.tip = "Provisional advice is a first draft. Captured facts are labeled separately; build choices still need testing."

  label(f, "Spec", nil, 22, -78):SetTextColor(0.70, 0.76, 0.82)
  specButton = button(f, "Auto", 150, 28)
  specButton:SetPoint("TOPLEFT", 62, -70)
  specButton.setting, specButton.tip = "spec", "Choose a spec to plan for, or Auto to follow your talents."
  specButton:SetScript("OnClick", openMenu)
  label(f, "Situation", nil, 234, -78):SetTextColor(0.70, 0.76, 0.82)
  modeButton = button(f, "Auto", 150, 28)
  modeButton:SetPoint("TOPLEFT", 300, -70)
  modeButton.setting, modeButton.tip = "situation", "Choose leveling, solo, dungeon or raid advice. Auto follows your level."
  modeButton:SetScript("OnClick", openMenu)
  detailsButton = button(f, "Show build details", 150, 28)
  detailsButton:SetPoint("TOPRIGHT", -22, -70)
  detailsButton:SetScript("OnClick", toggleDetails)
  tabButtons = {}
  for i = 1, 5 do
    local b = button(f, "", 116, 32)
    b:SetPoint("TOPLEFT", 22 + (i - 1) * 120, -110)
    b.accent = b:CreateTexture(nil, "OVERLAY")
    b.accent:SetHeight(2)
    b.accent:SetPoint("BOTTOMLEFT")
    b.accent:SetPoint("BOTTOMRIGHT")
    b.accent:SetColorTexture(1, 0.76, 0.36)
    b:SetScript("OnClick", function(self) selectTab(self.key) end)
    tabButtons[i] = b
  end
  list = UI.CreateList(f)
  list:SetPoint("TOPLEFT", 22, -156)
  list:SetPoint("BOTTOMRIGHT", -22, 34)
  UI.AddPulse(list)
  UI.AddFade(f)
  label(f, "Scroll to read more  |  Hover for captured text and details", nil, 22, -HEIGHT + 22):SetTextColor(0.55, 0.63, 0.72)
  menu = CreateFrame("Frame", nil, f)
  menu:SetWidth(180)
  menu:SetFrameStrata("DIALOG")
  menu:EnableMouse(true)
  fill(menu, 0.12, 0.16, 0.22)
  menu.options = {}
  for i = 1, 5 do
    local option = button(menu, "", 172, 28)
    option:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 30)
    option:SetScript("OnClick", choose)
    menu.options[i] = option
  end
  menu:Hide()
  f:SetScript("OnMouseDown", function() menu:Hide() end)
  f:SetScript("OnHide", function() menu:Hide(); GameTooltip:Hide() end)
  f:SetScript("OnShow", function() ns.Planner.Queue(); UI.Refresh(true) end)
  f:Hide()
  tinsert(UISpecialFrames, "BattleplanFrame")
  frame, UI.frame, UI.list = f, f, list
  UI.controls = { spec = specButton, situation = modeButton, details = detailsButton, menu = menu, context = context }
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
