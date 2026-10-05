#!/usr/bin/env python3
"""Captured rank text, importer failures, and the full Protection leveling path."""
import copy
import hashlib
import json
import sys
from pathlib import Path
from wowmock import runtime, load, start_battleplan, screen, WARRIOR_20

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tools'))
import import_talent_effects as importer

checks = 0


def check(condition, label):
    global checks
    checks += 1
    assert condition, label


raw = importer.SOURCE.read_bytes()
data = json.loads(raw)
cap, records = importer.catalog(data)
check(len(records) == 52 and sum(len(r['ranks']) for r in records.values()) == 150, 'all observed ranks imported')
check(importer.OUTPUT.read_text() == importer.render(raw, str(importer.SOURCE.relative_to(ROOT))), 'generated data is current')
L = runtime(WARRIOR_20)
ns = load(L, 'Battleplan', 'Battleplan.toc')
effects = ns.Data.WARRIOR.TalentEffects
check(effects._status == 'verified' and effects.sourceSha256 == hashlib.sha256(raw).hexdigest(), 'verified source hash')
for name, record in records.items():
    for rank, value in enumerate(record['ranks'], 1):
        check(effects[name].ranks[rank] == value, f'{name} rank {rank}: Lua preserves text and control escapes')
check('60%' in effects['Shield Specialization'].ranks[3], 'rank three uses 60% Rage proc, not generic maximum')
check('4.' in effects['Anticipation'].ranks[1] or '4' in effects['Anticipation'].ranks[1], 'Defense rank one is four')
check('20%' in effects['Improved Revenge'].ranks[1], 'Revenge damage rank one is 20%')

for defect in ('missing', 'duplicate', 'error', 'empty', 'secret', 'total', 'incomplete', 'node'):
    bad = copy.deepcopy(data)
    snapshot = bad['captures']['talents'][-1]['data']
    entry = snapshot['nodes'][0]['entries'][0]
    if defect == 'missing':
        entry['tooltips'].pop()
    elif defect == 'duplicate':
        entry['tooltips'].append(copy.deepcopy(entry['tooltips'][0]))
    elif defect == 'error':
        entry['tooltips'][0]['status'] = 'error'
    elif defect == 'empty':
        entry['tooltips'][0]['lines'] = []
    elif defect == 'secret':
        entry['tooltips'][0]['lines'][0]['leftText'] = '<secret>'
    elif defect == 'total':
        snapshot['tooltipExpected'] += 1
    elif defect == 'node':
        snapshot['nodes'][0]['info']['status'] = 'error'
    else:
        snapshot['complete'] = False
    try:
        importer.catalog(bad)
    except ValueError:
        check(True, f'reject {defect}')
    else:
        check(False, f'reject {defect}')

engine = ns.Engine.Talents
build = ns.Data.WARRIOR.Talents.protection.leveling
rules = ns.Data.TalentRules.WARRIOR
check(len(engine.Validate(build, rules)) == 0, 'all 51 points satisfy imported rules')
points = engine.Expand(build.order)
check(len(points) == 51 and points[31].name == 'Shield Slam', 'Shield Slam at level 40')
current = L.table()
for i in range(1, 52):
    point = points[i]
    level = engine.LevelOfPoint(i)
    plan = engine.Plan(build, level, current, rules, effects)
    check(plan.next.name == point.name and plan.next.rank == point.rank and plan.unspent == 1,
          f'level {level}: spend the next legal point')
    check(plan.rankText == effects[point.name].ranks[point.rank], f'level {level}: exact rank reference')
    current[point.name] = point.rank
    after = engine.Plan(build, level, current, rules, effects)
    check(after.onPlan and after.next is None, f'level {level}: allocated point matches target')
check(engine.Plan(build, 60, current, rules, effects).upcoming is None, 'finished path has no extra point')
check(engine.Plan(build, 9, L.table(), rules, effects).next is None, 'no point before level ten')
check(engine.Plan(build, 13, L.table_from({'Shield Specialization': 3}), rules).rankText is None,
      'older classes work without an effect catalog')
blocked = engine.Plan(build, 20, L.table_from({'Anticipation': 5}), rules, effects)
check(not blocked.invalid, 'valid build can compare an off-plan allocation')

# Replay the captured three-point allocation through the real planner and UI.
character = '''{class="WARRIOR",className="Warrior",level=12,
  nodes={{11670,"Shield Specialization",3,9000}},book={}}'''
L = runtime(character)
ns = start_battleplan(L)
check(ns.state.spec == 'protection' and ns.state.talentPlan.onPlan, 'captured level twelve allocation follows plan')
check('Shield Specialization at level 13' in screen(L, ns, 'talents'), 'next level shown to player')
rows = ns.UI.BuildRows('talents', ns.state)
tips = [rows[i].tip for i in range(1, len(rows) + 1) if rows[i].tip]
check(any('80%' in t and 'Captured rank 4 text (level 12' in t for t in tips), 'UI shows exact future rank and capture level')
print(f'talent effects test passed: {checks} checks')
