#!/usr/bin/env python3
"""Planner presentation and controls using mock geometry, not a live WoW renderer."""
from wowmock import runtime, start_battleplan, drain, screen, WARRIOR_20, ROGUE_30, PRIEST_40, MAGE_20

checks = 0


def check(condition, label):
    global checks
    checks += 1
    assert condition, label


def click(button):
    button._OnClick(button)


character = '''{class="WARRIOR",className="Warrior",level=12,
  nodes={{11670,"Shield Specialization",3,9000}},book={}}'''
L = runtime(character)
ns = start_battleplan(L)
check(ns.UI.frame is None, 'no frames at login')
ns.UI.Show()
controls = ns.UI.controls
check(ns.UI.frame.GetWidth(ns.UI.frame) == 640, 'roomier window')
check('Protection' in controls.context.text and 'Level 12' in controls.context.text, 'persistent context')
check(ns.UI.frame._template == 'BasicFrameTemplateWithInset', 'native framed panel')
check(controls.spec._template == 'UIPanelButtonTemplate' and controls.tabs[1]._template == 'UIPanelButtonTemplate',
      'controls and navigation use Blizzard button artwork')
check(controls.close._template == 'UIPanelCloseButton', 'native close button')
check(controls.title.text == 'Battleplan', 'visible title belongs to transparent drag region')
check(L.eval('function(c) return c.context._parent == c.content and c.spec._parent == c.content end')(controls),
      'context and controls are above native inset, not behind header artwork')
check(controls.content._frameLevel > ns.UI.frame._frameLevel + 1 and
      controls.close._frameLevel > controls.title._parent._frameLevel,
      'explicit layers protect header text and close-button input')
rows = ns.UI.list.data
check('Shield Specialization' in str([(rows[i].text, rows[i].value) for i in range(1, len(rows) + 1)]), 'next point visible')
check(not any(rows[i].text == 'Why' for i in range(1, len(rows) + 1)), 'full reasons collapsed')
check(any(rows[i].text == 'Why this point' for i in range(1, len(rows) + 1)), 'current reason shown')
check(any(rows[i].emphasis is True for i in range(1, len(rows) + 1)), 'next action highlighted')
check(any(rows[i].text == 'Target rank' and rows[i].value == '4' for i in range(1, len(rows) + 1)), 'rank shown without hover')
click(controls.details)
check(any(ns.UI.list.data[i].text == 'Why' for i in range(1, len(ns.UI.list.data) + 1)), 'details expand')
click(controls.details)
check(not any(ns.UI.list.data[i].text == 'Why' for i in range(1, len(ns.UI.list.data) + 1)), 'details collapse')

click(controls.situation)
menu = controls.menu
check(menu.IsShown(menu), 'situation menu opens')
check(menu.options[4].value == 'dungeon', 'readable situation choices')
click(menu.options[4])
drain(L, ns)
check(ns.db.situation == 'dungeon' and ns.state.situation == 'dungeon', 'control replans situation')
check(not menu.IsShown(menu), 'selection closes menu')
click(controls.spec)
check(menu.options[2].value == 'arms', 'spec choices from class metadata')
click(menu.options[2])
drain(L, ns)
check(ns.db.spec == 'arms' and ns.state.spec == 'arms', 'control replans spec')
check('No recommended build' in screen(L, ns, 'talents'), 'unsupported advice stays explicit')
click(controls.spec)
click(menu.options[1])
drain(L, ns)
check(ns.db.spec == 'auto' and ns.state.spec == 'protection', 'Auto follows allocated talents')
ns.UI.SelectTab('rotation')
check(not controls.details.IsShown(controls.details), 'details only on talent tab')
ns.UI.SelectTab('talents')

# Explanation text stays inline; only extra information earns a tooltip.
check(all(ns.UI.list.data[i].tip is None for i in range(1, len(ns.UI.list.data) + 1)
          if ns.UI.list.data[i].kind == 'note'), 'notes have no duplicate hover text')
L.globals().BP = ns
L.execute("""
  tooltipBodies = 0
  GameTooltip.SetText=function(self, text, _, _, _, _, wrap)
    self.text=text; tooltipTitleWrap=wrap
  end
  GameTooltip.AddLine=function(_, text) tooltipBodies=tooltipBodies+1; tooltipBody=text end
  BP.UI.list:SetData({{kind="note",text="Explanation",tip="Explanation"}})
  GameTooltip:Hide()
  BP.UI.list.rows[1]._OnEnter(BP.UI.list.rows[1])
""")
check(not L.globals().GameTooltip._shown and L.globals().tooltipBodies == 0,
      'legacy identical title/body tooltip is suppressed')
L.execute("""
  BP.UI.list:SetData({{kind="row",text="Next point",tip="Captured rank 4: 80% chance of 5 Rage on block."}})
  BP.UI.list.rows[1]._OnEnter(BP.UI.list.rows[1])
""")
check(L.globals().GameTooltip._shown and L.globals().tooltipBodies == 1,
      'captured details still show one tooltip body')
check(L.globals().tooltipTitleWrap is True and '80%' in L.globals().tooltipBody,
      'tooltip heading wraps and preserves captured text')
ns.UI.Refresh(True)

# Narrow layout with a long label, value and description; no text is shortened.
list_ = ns.UI.list
L.globals().BP = ns
L.execute('''
  LONG = string.rep("A complete explanation with spaces. ", 12)
  BP.UI.list:SetSize(320, 160)
  BP.UI.list:Layout()
  BP.UI.list:SetData({{kind="row",text=LONG,value="A long item name with details"},
    {kind="note",text=LONG,tip=LONG},{kind="row",text="Last row",value="End"}})
''')
check(list_.heights[1] > 26 and list_.heights[2] > 26, 'label, value and note wrap into tall rows')
check(list_.rows[1].left.text == L.globals().LONG, 'long text preserved in row')
check(list_.rows[1].left.wrap and list_.rows[1].right.wrap, 'both columns wrap')
check(list_.totalHeight > 160, 'overflow is scrollable')
count = len(list_.rows)
list_.Scroll(list_, 1000)
check(list_.offset == list_.totalHeight - 160, 'scroll clamps at bottom')
visible = [list_.rows[i].data for i in range(1, len(list_.rows) + 1) if list_.rows[i].data]
check(any(r.text == 'Last row' for r in visible), 'final row reachable')
list_.Scroll(list_, -1000)
check(list_.offset == 0 and len(list_.rows) == count, 'scroll returns to top and reuses frame pool')
list_.SetData(list_, L.table_from([L.table_from({'text': 'Short list'})]))
check(list_.offset == 0 and not list_.thumb._shown, 'short list hides thumb')
# Size changes remeasure text; already allocated pool is retained.
list_.SetData(list_, L.table_from([L.table_from({'text': L.globals().LONG})]))
narrow_height = list_.totalHeight
list_.SetWidth(list_, 600)
list_.Layout(list_)
check(list_.totalHeight < narrow_height, 'wider layout remeasures wrapping')

L.execute('IN_COMBAT=true')
offset = list_.offset
list_.Scroll(list_, 3)
check(list_.offset == offset, 'scroll does no work in combat')
height_before = list_.totalHeight
list_.SetWidth(list_, 320)
list_._OnSizeChanged(list_)
check(list_.totalHeight == height_before, 'size remeasurement defers in combat')
setting = ns.db.situation
click(controls.situation)
click(menu.options[4])
check(ns.db.situation == setting, 'controls dormant in combat')
ns.UI.SelectTab('rotation')
check(ns.UI.CurrentTab() == 'talents', 'tab changes dormant in combat')
L.execute('IN_COMBAT=false;fire("PLAYER_REGEN_ENABLED")')
check(list_.totalHeight > height_before, 'deferred size change remeasures after combat')
for char in (ROGUE_30, PRIEST_40, MAGE_20):
    other = runtime(char)
    addon = start_battleplan(other)
    addon.UI.Show()
    check(addon.UI.IsShown(), 'layout loads for supported and unsupported classes')
    addon.UI.Hide()

other = runtime(character)
addon = start_battleplan(other)
other.execute('IN_COMBAT=true')
addon.UI.Show()
check(addon.UI.frame is None, 'opening in combat defers frame creation')
other.execute('IN_COMBAT=false;fire("PLAYER_REGEN_ENABLED")')
drain(other, addon)
check(addon.UI.IsShown(), 'deferred opening occurs after combat')
print(f'UI test passed: {checks} checks')
