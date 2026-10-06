#!/usr/bin/env python3
"""One Gear row per slot; clicking it lists every option by source, and the pick is saved."""
from wowmock import runtime, start_battleplan, ROGUE_30

checks = 0


def check(condition, label):
    global checks
    checks += 1
    assert condition, label


L = runtime(ROGUE_30)
L.execute('RECORD_POINTS = true')
ns = start_battleplan(L)
L.globals().BP = ns
gear = ns.Engine.Gear

# Engine: every distinct item kept for the slot, best first, recommendation included.
upgrades = [ns.state.upgrades[i] for i in range(1, len(ns.state.upgrades) + 1)]
check(all(u.options is not None and len(u.options) >= 1 for u in upgrades), 'every slot has options')
for u in upgrades:
    options = [u.options[i] for i in range(1, len(u.options) + 1)]
    ids = [o.target.itemID for o in options]
    check(len(ids) == len(set(ids)), 'each item listed once')
    check(len(options) <= gear.MAX_OPTIONS, 'options capped')
    check(any(o.target.itemID == u.target.itemID for o in options), 'recommendation is an option')
    check(all(o.slot == u.slot and o.comparison is not None for o in options), 'options compared for that slot')
multi = next(u for u in upgrades if len(u.options) > 1)
kinds = {multi.options[i].route.kind for i in range(1, len(multi.options) + 1)}
check(len(kinds) > 1, 'a slot offers more than one kind of source')

# UI: one row per slot, no stacked "Or:" rows.
ns.UI.Show()
ns.UI.SelectTab('gear')
data = ns.UI.list.data
rows = [data[i] for i in range(1, len(data) + 1)]
check(not any((r.text or '').startswith('Or: ') for r in rows), 'no stacked alternative rows')
check(sum(1 for r in rows if r.itemID) == len(upgrades), 'one item row per slot')
slot_row = next(r for r in rows if r.slot == multi.slot)
check(f'{len(multi.options)} options, click to choose' in slot_row.text, 'row says it has options')

L.execute('''
  function rowFor(slot)
    for _, row in ipairs(BP.UI.list.rows) do
      if row.data and row.data.slot == slot then return row end
    end
  end
  function entries()
    local out = {}
    for _, e in ipairs(BP.UI.GearPickerEntries() or {}) do
      if e:IsShown() then
        out[#out + 1] = { text = e.left.text, sub = e.sub.text, value = e.right.text, when = e.when.text,
          option = rawget(e, "option"), frame = e }
      end
    end
    return out
  end
''')
row = L.globals().rowFor(multi.slot)
check(row is not None, 'slot row is on screen')
row._OnClick(row)
shown = L.globals().entries()
shown = [shown[i] for i in range(1, len(shown) + 1)]
headings = [e.text for e in shown if e.option is None]
choices = [e for e in shown if e.option is not None]
check(len(choices) == len(multi.options), 'picker lists every option')
check(all(h.endswith(('Quests|r', 'Crafted|r', 'Vendors|r', 'Drops|r', 'Other|r')) for h in headings)
      and len(headings) == len(kinds), 'options grouped under one heading per source kind')
recommended = next(e for e in choices if 'Recommended' in e.sub)
check(recommended.option.target.itemID == multi.target.itemID, 'recommendation marked')
check('UI-CheckBox-Check' in recommended.text and '(recommended)' not in recommended.text,
      'current choice checked; the name line holds only the name')
check(all('+' in e.value and '|' not in e.value.replace('|cff', '').replace('|r', '') for e in choices),
      'gain alone in the value column')
check(all(e.when in ('|cff9d9d9d|r', '|cff9d9d9dunconfirmed|r') or 'level' in e.when for e in choices),
      'level or confirmation on the line under the gain')

# Regression: long names overlapped the gain and rows behind showed through.
frame = recommended.frame
value_width = L.eval('BP.UI.GearPickerEntries()[1].right.width')
check(frame.left.wrap is False and frame.sub.wrap is False, 'names cut short instead of wrapping')
check(frame.left.points.TOPRIGHT[1] <= -value_width and frame.sub.points.TOPRIGHT[1] <= -value_width,
      'name and source stop before the value column')
check(frame.right.width == value_width and frame.when.width == value_width, 'fixed-width value column')
picker_bg = L.eval('BP.UI.GearPickerEntries()[1]:GetParent().bg')
check(picker_bg.color == 1, 'picker background is opaque')

# Hover an option: its item tooltip with Battleplan's details.
L.execute('TIP = {}; GameTooltip.SetHyperlink = function(_, link) TIP.link = link end')
other = next(e for e in choices if e.option.target.itemID != multi.target.itemID)
other.frame._OnEnter(other.frame)
check(L.globals().TIP.link == f'item:{other.option.target.itemID}', 'option hover shows its item tooltip')

# Pick another option: saved, the row shows it, and the picker closes.
other.frame._OnClick(other.frame)
check(ns.db.gearPicks[multi.slot] == other.option.target.itemID, 'pick saved by item ID')
check(L.globals().entries()[1] is None, 'picker closes after a pick')
data = ns.UI.list.data
slot_row = next(data[i] for i in range(1, len(data) + 1) if data[i].slot == multi.slot)
check(other.option.target.name in slot_row.text and 'your pick' in slot_row.text, 'row shows the pick')
check(slot_row.itemID == other.option.target.itemID, 'hover and links follow the pick')

# Picking the recommendation again clears the saved pick.
row = L.globals().rowFor(multi.slot)
row._OnClick(row)
shown = L.globals().entries()
rec = next(shown[i] for i in range(1, len(shown) + 1)
           if shown[i].option is not None and shown[i].option.target.itemID == multi.target.itemID)
rec.frame._OnClick(rec.frame)
check(ns.db.gearPicks[multi.slot] is None, 'choosing the recommendation clears the pick')

# A saved pick that is no longer an option falls back to the recommendation.
L.execute(f'BP.db.gearPicks[{multi.slot}] = 999999; BP.UI.Refresh(true)')
data = ns.UI.list.data
slot_row = next(data[i] for i in range(1, len(data) + 1) if data[i].slot == multi.slot)
check(slot_row.itemID == multi.target.itemID and 'your pick' not in slot_row.text, 'stale pick ignored')

# Second click closes; changing tabs closes it too.
row = L.globals().rowFor(multi.slot)
row._OnClick(row)
row._OnClick(row)
check(L.globals().entries()[1] is None, 'second click closes the picker')
row._OnClick(row)
ns.UI.SelectTab('talents')
check(L.globals().entries()[1] is None, 'changing tabs closes the picker')

# Shift-click an option links it without picking.
L.execute(f'BP.db.gearPicks[{multi.slot}] = nil')
ns.UI.SelectTab('gear')
row = L.globals().rowFor(multi.slot)
row._OnClick(row)
shown = L.globals().entries()
first = next(shown[i] for i in range(1, len(shown) + 1) if shown[i].option is not None)
L.execute('C.modified = "CHATLINK"')
first.frame._OnClick(first.frame)
check(L.eval('C.chatLinks and C.chatLinks[1]') is not None, 'shift-click links an option')
check(ns.db.gearPicks[multi.slot] is None, 'shift-click does not pick')

print(f"gear picker test passed ({checks} checks)")
