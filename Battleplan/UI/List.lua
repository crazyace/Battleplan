-- A recycled list: only as many row frames as fit on screen, rebound to new
-- data as you scroll. Long lists cost the same as short ones, and rows are
-- made once, not on every refresh.
--
-- Row data: { kind = "header"|"row"|"note"|"blank", text=, value=, tip=, indent= }
local _, ns = ...

local UI = ns.UI
local ROW_HEIGHT = 18
local FONTS = { header = "GameFontNormal", row = "GameFontHighlightSmall", note = "GameFontDisableSmall" }

local List = {}
List.__index = List

local function setText(fs, text)
  if fs.last ~= text then
    fs.last = text
    fs:SetText(text)
  end
end

local function onEnter(row)
  local d = row.data
  if not d or not d.tip then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText(d.text or "", 1, 0.82, 0)
  GameTooltip:AddLine(d.tip, 1, 1, 1, true)
  GameTooltip:Show()
end

local function onLeave() GameTooltip:Hide() end

local function makeRow(list)
  local row = CreateFrame("Button", nil, list)
  row:SetHeight(ROW_HEIGHT)
  row.left = row:CreateFontString(nil, "OVERLAY", FONTS.row)
  row.left:SetPoint("LEFT", 4, 0)
  row.left:SetJustifyH("LEFT")
  row.left:SetWordWrap(false)
  row.right = row:CreateFontString(nil, "OVERLAY", FONTS.row)
  row.right:SetPoint("RIGHT", -4, 0)
  row.right:SetJustifyH("RIGHT")
  row.left:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
  row:SetScript("OnEnter", onEnter)
  row:SetScript("OnLeave", onLeave)
  return row
end

local function bind(row, d)
  row.data = d
  local kind = d.kind or "row"
  if row.kind ~= kind then
    row.kind = kind
    row.left:SetFontObject(FONTS[kind] or FONTS.row)
  end
  local indent = (d.indent or 0) * 12 + 4
  if row.indent ~= indent then
    row.indent = indent
    row.left:SetPoint("LEFT", indent, 0)
  end
  setText(row.left, d.text or "")
  setText(row.right, d.value or "")
end

function List:Layout()
  local height = self:GetHeight() or 0
  local fit = math.max(1, math.floor(height / ROW_HEIGHT))
  for i = #self.rows + 1, fit do
    local row = makeRow(self)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", self, "RIGHT", -8, 0)
    self.rows[i] = row
  end
  self.fit = fit
  self:Rebind()
end

function List:Rebind()
  local maxOffset = math.max(0, #self.data - (self.fit or 0))
  self.offset = ns.util.clamp(self.offset, 0, maxOffset)
  for i, row in ipairs(self.rows) do
    local d = (i <= (self.fit or 0)) and self.data[self.offset + i] or nil
    if d then bind(row, d) else row.data = nil end
    row:SetShown(d ~= nil)
  end
  -- Scroll position marker
  local thumb = self.thumb
  if maxOffset == 0 then
    thumb:Hide()
  else
    local h = self:GetHeight() or 0
    local size = math.max(16, h * self.fit / #self.data)
    thumb:SetHeight(size)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", 0, -(h - size) * self.offset / maxOffset)
    thumb:Show()
  end
end

function List:SetData(rows)
  self.data = rows
  self:Rebind()
end

function List:Scroll(delta)
  self.offset = self.offset + delta
  self:Rebind()
end

function List:ScrollToTop()
  self.offset = 0
  self:Rebind()
end

function UI.CreateList(parent)
  local list = CreateFrame("Frame", nil, parent)
  for k, v in pairs(List) do if k ~= "__index" then list[k] = v end end
  list.rows, list.data, list.offset, list.fit = {}, {}, 0, 0
  list.thumb = list:CreateTexture(nil, "OVERLAY")
  list.thumb:SetWidth(4)
  list.thumb:SetColorTexture(1, 0.82, 0, 0.5)
  list.thumb:Hide()
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(self, delta) self:Scroll(-delta * 3) end)
  list:SetScript("OnSizeChanged", function(self) self:Layout() end)
  return list
end
