#!/usr/bin/env python3
"""Optional client icons: safe identity/cache reads and reusable row geometry."""
import json
from wowmock import runtime, start_battleplan, load, WARRIOR_20, drain

checks = 0


def check(condition, label):
    global checks
    checks += 1
    assert condition, label


L = runtime(WARRIOR_20)
L.execute('''
  C.book[1][7]=987001 -- Synthetic texture ID, not a claimed live icon.
  oldInfo=C_Spell.GetSpellInfo; iconReads=0
  C_Spell.GetSpellInfo=function(id)
    iconReads=iconReads+1
    if id==12298 then return {name="Shield Specialization",iconID=987002} end
    if id==12797 then return {name="Improved Revenge",iconID=987003} end
    return oldInfo(id)
  end
''')
ns = start_battleplan(L)
check(ns.state.icons['Heroic Strike'] == 987001, 'known spell icon comes from exact spell ID')
check(ns.state.icons['Shield Specialization'] == 987002, 'captured talent ID resolves name-checked icon')
ns.UI.Show()
ns.UI.SelectTab('rotation')
rows = ns.UI.list.data
check(any(rows[i].icon == 987001 and 'Heroic Strike' in rows[i].text for i in range(1, len(rows) + 1)),
      'rotation keeps name/rank with icon')
ns.UI.SelectTab('talents')
check(any(ns.UI.list.data[i].icon == 987003 and ns.UI.list.data[i].text == 'Next point'
          for i in range(1, len(ns.UI.list.data) + 1)), 'next talent row has icon')
ns.UI.SelectTab('tanking')
check(any(ns.UI.list.data[i].icon == 987001 and 'Heroic Strike' in ns.UI.list.data[i].text
          for i in range(1, len(ns.UI.list.data) + 1)), 'tank guide has known-spell icons')
count = L.globals().iconReads
check(ns.API.SpellIcon(285, 'Heroic Strike') == 987001 and L.globals().iconReads == count, 'successful lookup cached')
check(ns.API.SpellIcon(285, 'Wrong name') is None, 'cached identity mismatch fails closed')
ns.API.ForgetSpells()
check(ns.API.SpellIcon(285, 'Heroic Strike') == 987001 and L.globals().iconReads == count + 1, 'spell event invalidates cache')
for setup in ('C_Spell.GetSpellInfo=nil', 'C_Spell.GetSpellInfo=function() error("unavailable") end',
              'C_Spell.GetSpellInfo=function() return {name="Heroic Strike",iconID="SECRET"} end',
              'C_Spell.GetSpellInfo=function() return {name="SECRET",iconID=987001} end',
              'C_Spell.GetSpellInfo=function() return {name="Different spell",iconID=987001} end',
              'C_Spell.GetSpellInfo=function() return {name="Heroic Strike",iconID=0} end',
              'C_Spell.GetSpellInfo=function() return {name="Heroic Strike",iconID={}} end',
              'C_Spell.GetSpellInfo=function() return false end'):
    ns.API.ForgetSpells()
    L.execute(setup)
    check(ns.API.SpellIcon(285, 'Heroic Strike') is None, 'optional icon fails safely: ' + setup)
L.execute('C_Spell.GetSpellInfo=oldInfo')
ns.API.ForgetSpells()
L.execute('IN_COMBAT=true')
check(ns.API.SpellIcon(285, 'Heroic Strike') is None, 'icon reads dormant in combat')
L.execute('IN_COMBAT=false')
check(ns.API.SpellIcon('SECRET', 'Heroic Strike') is None, 'secret spell identifier rejected')

# Same row is recycled across icon, no-icon and changed-icon data.
L.globals().BP = ns
L.execute('''
  BP.UI.list:SetData({{text="Heroic Strike",icon=987001}})
  iconHeight=BP.UI.list.heights[1]
  iconWidth=BP.UI.list.rows[1].left.width
''')
row = ns.UI.list.rows[1]
check(row.icon._shown and row.icon.texture == 987001 and L.globals().iconHeight >= 34, 'icon visible with enough height')
L.execute('BP.UI.list:SetData({{text="No icon available"}})')
check(not row.icon._shown and L.eval("function(row) return rawget(row, 'iconID') == nil end")(row) and row.left.width > L.globals().iconWidth,
      'text-only row hides stale icon and reclaims width')
L.execute('BP.UI.list:SetData({{text="Another spell",icon=987002}})')
check(row.icon.texture == 987002, 'recycled texture updates correctly')
L.execute('C_Spell.GetSpellInfo=nil;fire("SPELLS_CHANGED")')
drain(L, ns)
check(ns.state.icons['Heroic Strike'] is None, 'planner remains usable without icon API')

P = runtime(WARRIOR_20)
P.execute('C.book[1][7]=987001')
load(P, 'BattleplanProbe', 'BattleplanProbe.toc')
P.globals().SlashCmdList.BATTLEPLANPROBE('spells')
spells = json.loads(P.globals().BattleplanProbe.export())['captures']['spells'][-1]['data']['spells']
check(any(s.get('iconID') == 987001 for s in spells), 'future probe exports include observed icon IDs')
print(f'icons test passed: {checks} checks')
