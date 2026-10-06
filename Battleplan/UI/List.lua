-- Wrapped, variable-height rows. Measure on data/size changes; scrolling only
-- rebinds a fixed pool and never builds tables or frames.
local _, ns = ...
local UI = ns.UI
local MIN_HEIGHT, LINE_HEIGHT = 32, 20
local FONTS = { header = "GameFontNormal", row = "GameFontHighlight", note = "GameFontHighlight" }
-- Keep measurements and displayed text on the same readable font metrics.
function UI.ReadableFont(fs, kind, font)
  fs:SetFontObject(font or FONTS[kind] or FONTS.row)
  local face, _, flags = fs:GetFont()
  fs:SetFont(face, kind == "header" and 16 or 14, flags)
end
local List = {}
List.__index = List

local function setText(fs, text)
  if fs.last ~= text then fs.last = text; fs:SetText(text) end
end

-- Item rows show the client's own item tooltip with Battleplan's lines under
-- it (Gearwright does the same with SetHyperlink on the Forever beta).
local function onEnter(row)
  local d = row.data
  if not d then return end
  if d.hyperlink and GameTooltip.SetHyperlink then
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(d.hyperlink)
    if d.tip then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(d.tip, 1, 1, 1, true)
    end
    GameTooltip:Show()
    return
  end
  if not d.tip or d.tip == d.text then return end
  GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
  GameTooltip:SetText(d.text or "", 1, 0.82, 0, 1, true)
  GameTooltip:AddLine(d.tip, 1, 1, 1, true)
  GameTooltip:Show()
end
local function onLeave() GameTooltip:Hide() end

-- Shift-click (the player's chat-link binding) puts an item row's link in chat.
local function onClick(row)
  local d = row.data
  if not (d and d.itemID and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink) then return end
  local link = ns.API.ItemLink(d.itemID)
  if link then ChatEdit_InsertLink(link) end
end

local function makeRow(list)
  local row = CreateFrame("Button", nil, list)
  row.left = row:CreateFontString(nil, "OVERLAY", FONTS.row)
  row.right = row:CreateFontString(nil, "OVERLAY", FONTS.row)
  row.left:SetJustifyH("LEFT")
  row.right:SetJustifyH("RIGHT")
  UI.ReadableFont(row.right, "row")
  row.left:SetJustifyV("TOP")
  row.right:SetJustifyV("TOP")
  row.left:SetWordWrap(true)
  row.right:SetWordWrap(true)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(32, 32)
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  row.icon:Hide()
  row.iconBorder = row:CreateTexture(nil, "BORDER")
  row.iconBorder:SetSize(36, 36)
  row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
  -- A solid rim behind the icon has no artwork padding to shrink its edges.
  row.iconBorder:SetColorTexture(0.55, 0.45, 0.24, 1)
  row.iconBorder:Hide()
  row.accent = row:CreateTexture(nil, "BACKGROUND")
  row.accent:SetAllPoints()
  row.accent:SetColorTexture(1, 0.82, 0, 0.08)
  row:SetScript("OnEnter", onEnter)
  row:SetScript("OnLeave", onLeave)
  row:SetScript("OnClick", onClick)
  return row
end

local function measure(fs, value, width)
  fs:SetWidth(width)
  fs:SetText(value or "")
  return math.max(LINE_HEIGHT, fs:GetStringHeight())
end

function List:Measure()
  local width = math.max(200, self:GetWidth() or 200) - 20
  self.width = width
  local y = 0
  for i, d in ipairs(self.data) do
    local kind = d.kind or "row"
    local indent = (d.indent or 0) * 12 + 8 + (d.icon and 44 or 0)
    local rightWidth = d.value and d.value ~= "" and math.floor(width * 0.40) or 0
    local leftWidth = width - indent - (rightWidth > 0 and rightWidth + 14 or 0)
    UI.ReadableFont(self.measure, kind)
    local height = math.max(measure(self.measure, d.text, leftWidth),
      rightWidth > 0 and measure(self.measure, d.value, rightWidth) or 0) + 12
    if d.icon then height = math.max(height, 44) end
    if kind == "blank" then height = 10
    elseif kind == "header" then height = height + 8
    elseif d.emphasis then height = height + 10 end
    self.tops[i], self.heights[i] = y, math.max(kind == "blank" and 10 or MIN_HEIGHT, height)
    y = y + self.heights[i]
  end
  self.totalHeight = y
end

local function bind(row, d, list, index)
  row.data = d
  local kind = d.kind or "row"
  if row.kind ~= kind then
    row.kind = kind
    UI.ReadableFont(row.left, kind)
    UI.ReadableFont(row.right, kind)
  end
  local indent = (d.indent or 0) * 12 + 8 + (d.icon and 44 or 0)
  local rightWidth = d.value and d.value ~= "" and math.floor(list.width * 0.40) or 0
  local top = d.emphasis and -11 or -6
  if d.icon then
    row.icon:ClearAllPoints()
    row.icon:SetPoint("TOPLEFT", indent - 42, top)
    if row.iconID ~= d.icon then row.iconID = d.icon; row.icon:SetTexture(d.icon) end
    row.icon:Show()
    row.iconBorder:Show()
  else
    row.iconID = nil
    row.icon:Hide()
    row.iconBorder:Hide()
  end
  row.left:ClearAllPoints()
  row.left:SetPoint("TOPLEFT", indent, top)
  row.left:SetWidth(list.width - indent - (rightWidth > 0 and rightWidth + 14 or 0))
  row.right:ClearAllPoints()
  row.right:SetPoint("TOPRIGHT", -12, top)
  row.right:SetWidth(math.max(1, rightWidth))
  row.left:SetTextColor(kind == "note" and 0.75 or 1, kind == "note" and 0.75 or 0.82, kind == "note" and 0.75 or 0)
  if kind == "row" then row.left:SetTextColor(1, 1, 1) end
  row.right:SetTextColor(1, 1, 1)
  row.accent:SetShown(d.emphasis == true)
  row:SetHeight(list.heights[index])
  setText(row.left, d.text or "")
  setText(row.right, d.value or "")
end

function List:Layout()
  local fit = math.max(1, math.ceil((self:GetHeight() or 0) / 10) + 1)
  for i = #self.rows + 1, fit do self.rows[i] = makeRow(self) end
  self.fit = fit
  self:Measure()
  self:Rebind()
end

function List:Rebind()
  local height = self:GetHeight() or 0
  local maxOffset = math.max(0, self.totalHeight - height)
  self.offset = ns.util.clamp(self.offset, 0, maxOffset)
  local index = 1
  while index <= #self.data and self.tops[index] + self.heights[index] <= self.offset do index = index + 1 end
  for _, row in ipairs(self.rows) do
    local d = self.data[index]
    local y = d and self.tops[index] - self.offset or height
    if d and y < height then
      bind(row, d, self, index)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, -y)
      row:SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -y)
      row:Show()
      index = index + 1
    else
      row.data = nil
      row:Hide()
    end
  end
  if maxOffset == 0 then self.thumb:Hide()
  else
    local size = math.max(20, height * height / self.totalHeight)
    self.thumb:SetHeight(size)
    self.thumb:ClearAllPoints()
    self.thumb:SetPoint("TOPRIGHT", 0, -(height - size) * self.offset / maxOffset)
    self.thumb:Show()
  end
end

function List:SetData(rows)
  GameTooltip:Hide()
  self.data = rows
  self:Measure()
  self:Rebind()
end
function List:Scroll(delta)
  if ns.InCombat() then return end
  GameTooltip:Hide()
  self.offset = self.offset + delta * MIN_HEIGHT
  self:Rebind()
end
function List:ScrollToTop() self.offset = 0; self:Rebind() end

function UI.CreateList(parent)
  local list = CreateFrame("Frame", nil, parent)
  for k, v in pairs(List) do if k ~= "__index" then list[k] = v end end
  list.rows, list.data, list.tops, list.heights = {}, {}, {}, {}
  list.offset, list.fit, list.totalHeight = 0, 0, 0
  list:SetClipsChildren(true)
  list.measure = list:CreateFontString(nil, "OVERLAY", FONTS.row)
  list.measure:SetWordWrap(true)
  list.measure:Hide()
  list.thumb = list:CreateTexture(nil, "OVERLAY")
  list.thumb:SetWidth(3)
  list.thumb:SetColorTexture(1, 0.76, 0.36, 0.8)
  list.thumb:Hide()
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(self, delta) self:Scroll(-delta * 3) end)
  list.layoutCallback = function() list:Layout() end
  list:SetScript("OnSizeChanged", function(self)
    if ns.InCombat() then ns.Refresh("ui-layout", 0, self.layoutCallback) else self:Layout() end
  end)
  return list
end
