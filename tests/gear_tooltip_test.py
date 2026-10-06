#!/usr/bin/env python3
"""Suggested gear shows the item's own tooltip on hover, and shift-click links it."""
from wowmock import runtime, start_battleplan, drain, ROGUE_30

checks = 0


def check(condition, label):
    global checks
    checks += 1
    assert condition, label


L = runtime(ROGUE_30)
L.execute('''
  REQUESTED = {}
  C_Item.RequestLoadItemDataByID = function(id) REQUESTED[id] = (REQUESTED[id] or 0) + 1 end
''')
ns = start_battleplan(L)
L.globals().BP = ns
L.globals().fire("PLAYER_EQUIPMENT_CHANGED")
drain(L, ns)

upgrade = ns.state.upgrades[1]
item = upgrade.target.itemID
check(L.globals().REQUESTED[item] and L.globals().REQUESTED[upgrade.alternative.target.itemID],
      'suggested items are loaded before they are hovered')
check(L.globals().REQUESTED[item] == 1, 'each item is asked for once, not on every plan')
check(ns.state.equippedLinks[5] == 'item:101:15:0', 'equipped links kept for the replaces line')

ns.UI.Show()
ns.UI.SelectTab('gear')
data = ns.UI.list.data
items = [data[i] for i in range(1, len(data) + 1) if data[i].itemID]
check(len(items) >= 2, 'every suggestion row carries its item')
first = items[0]
check(first.itemID == item and first.hyperlink == f'item:{item}', 'row links the suggested item')
check(all(data[i].hyperlink is None for i in range(1, len(data) + 1) if data[i].kind == 'note'),
      'explanation notes are not item rows')

L.execute('''
  TIP = {}
  GameTooltip.SetHyperlink = function(_, link) TIP.link = link end
  GameTooltip.SetText = function(_, text) TIP.title = text end
  GameTooltip.AddLine = function(_, text) TIP[#TIP + 1] = text end
  function hover(i)
    local list = BP.UI.list
    for _, row in ipairs(list.rows) do
      if row.data == list.data[i] then TIP = {}; row._OnEnter(row); return row end
    end
  end
''')
index = next(i for i in range(1, len(data) + 1) if data[i].itemID == item)
row = L.globals().hover(index)
tip = L.globals().TIP
check(tip.link == f'item:{item}' and tip.title is None, 'hover shows the client item tooltip, not a text title')
body = tip[2]
check(f'+{upgrade.gain:.1f} score in {upgrade.slotName}' in body, 'tooltip says how much it gains and where')
check(f'Your {upgrade.slotName} slot is empty.' in body, 'tooltip says the slot is empty')
check('Shift-click to link it in chat.' in body, 'tooltip says how to link it')
check(L.globals().GameTooltip._shown, 'tooltip shown')

# Regression: the tooltip flashed for a second. A redraw while hovering keeps
# it on the row under the mouse, and item data arriving no longer replans
# when the plan isn't waiting for any.
L.execute('GameTooltip:Hide()')
row._mouseOver = True
ns.UI.Refresh(True)
check(L.globals().GameTooltip._shown and L.globals().TIP.link == f'item:{item}',
      'redraw while hovering keeps the item tooltip')
row._mouseOver = False
L.execute('''
  for _, link in pairs(C.inv) do C.itemStats[link] = C.itemStats[link] or {} end
  for _, e in ipairs(BP.Data.Consumables) do C.itemSpells[e.itemID] = C.itemSpells[e.itemID] or ("Buff " .. e.itemID) end
''')
L.globals().fire("PLAYER_EQUIPMENT_CHANGED")
drain(L, ns)
check(not ns.state.gearUnknown, 'all equipped stats readable now')
version = ns.state.version
L.globals().fire("GET_ITEM_INFO_RECEIVED", item, True)
L.globals().fire("ITEM_DATA_LOAD_RESULT", item, True)
drain(L, ns)
check(ns.state.version == version, 'item data arriving does not replan when nothing waits on it')
ns.UI.Refresh(True)
check(not L.globals().GameTooltip._shown, 'redraw with the mouse elsewhere hides the tooltip')

# A suggestion for an equipped slot names the item it replaces.
L.execute('''
  BP.state.upgrades = { { slot = 5, slotName = "Chest", gain = 4, now = true, status = "available",
    target = { itemID = 4242, name = "Better chest", minLevel = 30, stats = {} } } }
  BP.UI.Refresh(true)
''')
data = ns.UI.list.data
index = next(i for i in range(1, len(data) + 1) if data[i].itemID == 4242)
L.globals().hover(index)
check('Replaces item:101:15:0' in L.globals().TIP[2], 'tooltip names the equipped item it replaces')

# Shift-click puts the item's chat link in the edit box; a plain click does nothing.
row = L.globals().hover(index)
row._OnClick(row)
check(L.eval('C.chatLinks') is None, 'plain click does not link')
L.execute('C.modified = "CHATLINK"')
row._OnClick(row)
check('|Hitem:4242:' in L.eval('C.chatLinks[1]'), 'shift-click links the item in chat')

# Rows without an item keep the plain text tooltip.
L.execute('''
  BP.UI.list:SetData({{kind="row",text="Next point",tip="Extra detail."}})
  TIP = {}
  BP.UI.list.rows[1]._OnEnter(BP.UI.list.rows[1])
''')
check(L.globals().TIP.link is None and L.globals().TIP.title == 'Next point', 'text rows unchanged')

print(f"gear tooltip test passed ({checks} checks)")
