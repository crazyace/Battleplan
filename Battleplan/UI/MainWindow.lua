-- The Battleplan window. Built the first time it's opened (never at login),
-- shown with a short fade, hidden and reused on close. Rows come from
-- UI/Tabs.lua; this file only lays out frames.
local _, ns = ...

local UI = ns.UI
local WIDTH, HEIGHT = 440, 480

local frame, list, tabButtons
local currentTab = "talents"
local shownVersion, shownTab

local function savePosition(f)
  local point, _, relPoint, x, y = f:GetPoint()
  ns.db.window = { point = point, relPoint = relPoint, x = x, y = y }
end

local function selectTab(key)
  currentTab = key
  for _, b in ipairs(tabButtons) do
    if b.key == key then b:LockHighlight() else b:UnlockHighlight() end
  end
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
      if b.label ~= t.label then b.label = t.label; b:SetText(t.label) end
      if t.key == currentTab then valid = true end
    end
  end
  if not valid then currentTab = "talents" end
  for _, b in ipairs(tabButtons) do
    if b.key == currentTab then b:LockHighlight() else b:UnlockHighlight() end
  end
end

local function create()
  local f = CreateFrame("Frame", "BattleplanFrame", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(WIDTH, HEIGHT)
  local pos = ns.db.window or {}
  if pos.point then
    f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
  else
    f:SetPoint("CENTER")
  end
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); savePosition(self) end)
  f:Hide()
  tinsert(UISpecialFrames, "BattleplanFrame") -- Escape closes it

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -5)
  title:SetText("Battleplan")

  -- Tab buttons: one per possible tab, laid out once; labels set per role.
  tabButtons = {}
  local x = 12
  for i = 1, 5 do
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(82, 22)
    b:SetPoint("TOPLEFT", x, -30)
    x = x + 84
    b:SetScript("OnClick", function(self) selectTab(self.key) end)
    tabButtons[i] = b
  end

  list = UI.CreateList(f)
  list:SetPoint("TOPLEFT", 12, -58)
  list:SetPoint("BOTTOMRIGHT", -10, 10)
  UI.AddPulse(list)
  UI.AddFade(f)

  f:SetScript("OnShow", function()
    ns.Planner.Queue() -- cheap if nothing changed; keeps the window current
    UI.Refresh(true)
  end)
  frame = f
  UI.frame = f
  UI.list = list
  list:Layout()
end

function UI.IsShown()
  return frame ~= nil and frame:IsShown()
end

-- Re-reads ns.state into the list, but only if something changed.
function UI.Refresh(force)
  if not UI.IsShown() then return end
  local s = ns.state
  if not force and shownVersion == s.version and shownTab == currentTab then return end
  layoutTabs()
  shownVersion, shownTab = s.version, currentTab
  list:SetData(UI.BuildRows(currentTab, s))
end

function UI.Show()
  if not frame then create() end
  UI.ShowSmooth(frame)
end

function UI.Hide()
  if frame and frame:IsShown() then UI.HideSmooth(frame) end
end

function UI.Toggle()
  if UI.IsShown() then UI.Hide() else UI.Show() end
end

function UI.SelectTab(key)
  if not frame then create() end
  selectTab(key)
end

function UI.CurrentTab() return currentTab end
