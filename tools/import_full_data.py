#!/usr/bin/env python3
"""Preserve all downloaded JSON and generate bounded, provisional gear source chunks."""
import argparse
import collections
import hashlib
import json
import math
import re
import zipfile
from pathlib import Path
from import_gear_catalog import SLOTS, STATS, quote

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = ROOT / 'data/external/full-snapshot.zip'
MANIFEST = ROOT / 'data/external/manifest.json'
OUTPUT = ROOT / 'Battleplan/Data/FullGearCatalog.lua'
CLASSES = {'PRIEST': {1}, 'ROGUE': {2}, 'WARRIOR': {3, 4}}
PROFS = {'blacksmithing': 'Blacksmithing', 'leatherworking': 'Leatherworking',
         'tailoring': 'Tailoring', 'engineering': 'Engineering'}


def read(archive, name):
    return json.loads(archive.read('raw/foreverdb/' + name + '.json'))


def shards(archive, kind):
    out = {}
    for name in sorted(archive.namelist()):
        if name.startswith('raw/foreverdb/' + kind + '/') and name.endswith('.json'):
            out.update(json.loads(archive.read(name)))
    return out


def preserve(folder):
    folder = Path(folder)
    ARCHIVE.parent.mkdir(parents=True, exist_ok=True)
    entries = {str(p.relative_to(folder)): p.read_bytes() for p in sorted((folder / 'raw').rglob('*.json'))}
    for name in ('collection_manifest.json', 'extra_manifest.json', 'repair_manifest.json', 'validation.json'):
        if (folder / name).exists():
            entries[name] = (folder / name).read_bytes()
    entries['licenses/GPL-3.0.txt'] = (ROOT / 'data/external/GPL-3.0.txt').read_bytes()
    with zipfile.ZipFile(ARCHIVE, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, value in sorted(entries.items()):
            info = zipfile.ZipInfo(name, (2026, 10, 5, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, value, compresslevel=9)
    build = json.loads(entries['raw/foreverdb/stats-explained.json'])['build']
    retrieved = json.loads(entries['collection_manifest.json'])['retrieved_at']
    manifest = {'_status': 'provisional', 'sourceBuild': build,
                'retrievedAt': retrieved, 'archiveSha256': hashlib.sha256(ARCHIVE.read_bytes()).hexdigest(),
                'files': [{'path': name, 'bytes': len(value), 'sha256': hashlib.sha256(value).hexdigest()}
                          for name, value in sorted(entries.items())]}
    MANIFEST.write_text(json.dumps(manifest, indent=2) + '\n')


def exclusion(item):
    if item.get('c') != 4 or item.get('inv') not in SLOTS or item.get('sc') not in (1, 2, 3, 4):
        return 'unmodeled_slot_or_item_class'
    if item.get('src') != 'f' or re.search(r'^OLD|\b(test|deprecated|unused)\b', item.get('n', ''), re.I):
        return 'legacy_or_test_record'
    if any(item.get(k) for k in ('sp', 'rs', 'spec', 'bar', 'cls', 'set', 'rep', 'lim', 'ev', 'qs', 'u')):
        return 'effects_or_wearer_requirements'
    if type(item.get('rl')) is not int or type(item.get('el', 0)) is not int:
        return 'unknown_level'
    level = max(item['rl'], item.get('el', 0))
    if not 0 <= level <= 60 or not level and item.get('il', 0) > 15:
        return 'future_or_unknown_acquisition_level'
    if any(stat not in STATS for stat, _ in item.get('st', [])):
        return 'unsupported_stats'
    values = [item.get('ar', 0)] + [v for _, v in item.get('st', [])]
    if any(type(v) not in (int, float) or not math.isfinite(v) or v < 0 for v in values):
        return 'invalid_stats'
    if not item.get('ar') or not item.get('ic'):
        return 'missing_armor_or_icon'
    return None


def routes(item, sources, crafts, sold, quests, vendors, dungeons, maps, npcs):
    out, used = [], set()
    def add(route):
        if route['key'] not in used:
            used.add(route['key']); out.append(route)
    for recipe in crafts.get(str(item['id']), {}).get('made', []):
        if recipe[0] in PROFS:
            route = {'key': f'craft:{item["id"]}:{recipe[1]}', 'kind': 'craft', 'name': recipe[3],
                     'recipeID': recipe[1], 'profession': PROFS[recipe[0]], 'sourceEvidence': 'client'}
            if item.get('b') == 1:
                route['wearerProfession'] = PROFS[recipe[0]]
            add(route)
    for source in sources.get(str(item['id']), []):
        kind = source.get('t')
        if kind not in ('quest', 'drop', 'vendor'):
            continue
        key = source.get('q') if kind == 'quest' else source.get('npc')
        if not key or not source.get('n'):
            continue
        route = {'key': f'{kind}:{item["id"]}:{key}', 'kind': kind,
                 'name': source['n'], 'sourceEvidence': source.get('src', 'unknown')}
        if kind == 'quest':
            route['questID'] = key
            quest = quests.get(str(key), {})
            if quest.get('min'):
                route['minLevel'] = quest['min']
            if quest.get('prev'):
                route['prerequisites'] = [quest['prev']]
                route['requirements'] = 'Prerequisite: ' + quest.get('prevT', 'check the quest chain')
            side = source.get('side') or quest.get('side')
            if side in ('a', 'h'):
                route['faction'] = 'Alliance' if side == 'a' else 'Horde'
            if quest.get('classes'):
                route['requirements'] = 'Class-specific quest; confirm eligibility and prerequisites.'
            if source.get('m'):
                route['mapID'] = source['m']
                if source['m'] in maps:
                    route['location'] = f'{maps[source["m"]]} ({source.get("x", "?")}, {source.get("y", "?")})'
            for giver in quest.get('from', []):
                npc = npcs.get(str(giver.get('npc')), {})
                if npc.get('n'):
                    route['requirements'] = 'Pick up from ' + npc['n'] + '. ' + route.get('requirements', '')
                    for place in npc.get('at', []):
                        zone = place.get('near') or maps.get(place.get('m'))
                        if zone:
                            route['location'] = zone
                            break
                    break
        if kind == 'drop' and source.get('inst'):
            dungeon = dungeons.get(source['inst'])
            if dungeon:
                route['location'] = dungeon['n']
                route['minLevel'] = dungeon.get('lv', 0)
        if kind == 'vendor':
            vendor = vendors.get(str(key), {})
            if vendor.get('zone'):
                route['location'] = vendor['zone']
            if vendor.get('side') in ('Alliance', 'Horde'):
                route['faction'] = vendor['side']
        add(route)
    for vendor in sold.get(str(item['id']), {}).get('v', []):
        if vendor.get('npc') and vendor.get('n'):
            route = {'key': f'vendor:{item["id"]}:{vendor["npc"]}', 'kind': 'vendor',
                     'name': vendor['n'], 'sourceEvidence': 'forever' if vendor.get('fv') else 'classic'}
            if vendor.get('zone'):
                route['location'] = vendor['zone']
            if vendor.get('side') in ('Alliance', 'Horde'):
                route['faction'] = vendor['side']
            add(route)
    # Full associations remain in the archive; the UI needs a bounded representative set.
    selected, counts = [], collections.Counter()
    for route in sorted(out, key=lambda r: (r.get('sourceEvidence') == 'classic', r['key'])):
        group = (route['kind'], route.get('faction', 'any'))
        if counts[group] < 2:
            selected.append(route); counts[group] += 1
    return selected


def build(archive):
    items = read(archive, 'items')
    sources, crafts, sold = (shards(archive, k) for k in ('sources', 'crafting', 'sold'))
    quest_data = read(archive, 'quests')
    quests = quest_data['quests']
    vendors = read(archive, 'vendors')['vendors']
    dungeons = {d['id']: d for d in read(archive, 'dungeons')}
    maps = {v['m']: v['zone'] for v in vendors.values() if v.get('m') and v.get('zone')}
    records, excluded = [], collections.Counter()
    for item in items:
        reason = exclusion(item)
        if reason:
            excluded[reason] += 1; continue
        paths = routes(item, sources, crafts, sold, quests, vendors, dungeons, maps, quest_data["npcs"])
        if not paths:
            excluded['source_not_located'] += 1; continue
        stats = {'ARMOR': item['ar']}
        for stat, value in item.get('st', []):
            key, divisor = STATS[stat]
            stats[key] = stats.get(key, 0) + value / divisor
        level = max(item['rl'], item.get('el', 0), 40 if item['sc'] == 4 else 0)
        allowed = sorted(CLASSES) if item['inv'] == 16 else [c for c, types in CLASSES.items() if item['sc'] in types]
        records.append({'itemID': item['id'], 'name': item['n'], 'slot': SLOTS[item['inv']],
                        'minLevel': level, 'icon': item['ic'], 'stats': stats, 'classes': allowed, 'routes': paths})
    report = {'_status': 'provisional', 'itemsPreserved': len(items), 'rankableItems': len(records),
              'excludedFromRanking': dict(sorted(excluded.items())),
              'sourceKinds': dict(collections.Counter(r['kind'] for t in records for r in t['routes']))}
    return records, report


def scalar(v):
    return quote(v) if isinstance(v, str) else str(v).lower() if isinstance(v, bool) else f'{v:g}'


ROUTE_FIELDS = ('key', 'kind', 'name', 'sourceEvidence', 'recipeID', 'profession',
                'wearerProfession', 'questID', 'minLevel', 'prerequisites', 'requirements',
                'faction', 'mapID', 'location')


def encoded(value):
    text = ','.join(str(v) for v in value) if isinstance(value, list) else str(value)
    if any(c in text for c in ('|', '`', '\t', '\n', '\r')):
        raise ValueError('Catalog fields must not contain line or tab delimiters')
    return text


def render(records):
    lines = ['-- Generated by tools/import_full_data.py; do not edit.',
             '-- SPDX-License-Identifier: GPL-3.0-only',
             '-- Derived acquisition data; original licensing: data/external/NOTICE.md.',
             '-- Provisional records decoded in small batches by Engine/Gear.lua.',
             'local _, ns = ...', '', 'ns.Data.FullGearCatalog = {', '  _status = "provisional",']
    for cls in sorted(CLASSES):
        selected = sorted((r for r in records if cls in r['classes']), key=lambda r: (r['minLevel'], r['itemID']))
        lines.append(f'  {cls} = {{')
        for start in range(0, len(selected), 16):
            chunk = selected[start:start + 16]
            rows = []
            for record in chunk:
                fields = ['T', record['itemID'], record['name'], record['slot'], record['minLevel'], record['icon']]
                fields.extend(k + '=' + f'{v:g}' for k, v in sorted(record['stats'].items()))
                rows.append('|'.join(encoded(v) for v in fields) + '|`')
                for route in record['routes']:
                    rows.append('|'.join(['R'] + [encoded(route.get(k, '')) for k in ROUTE_FIELDS]) + '|`')
            data = ''.join(rows)
            lines.extend(['    {', f'      minLevel = {chunk[0]["minLevel"]}, data = [=['])
            if ']=]' in data:
                raise ValueError('Catalog contains long-string delimiter')
            offset = 0
            while offset < len(data):
                end = min(offset + 120, len(data))
                while end < len(data) and data[end - 1].isspace():
                    end += 1
                lines.append(data[offset:end])
                offset = end
            lines.append(']=],')
            lines.append('    },')
        lines.append('  },')
    lines.extend(['}', ''])
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--collection-dir', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.collection_dir:
        preserve(args.collection_dir)
    manifest = json.loads(MANIFEST.read_text())
    if hashlib.sha256(ARCHIVE.read_bytes()).hexdigest() != manifest['archiveSha256']:
        parser.exit(1, 'Archive checksum does not match manifest\n')
    with zipfile.ZipFile(ARCHIVE) as archive:
        if sorted(archive.namelist()) != sorted(f['path'] for f in manifest['files']):
            parser.exit(1, 'Archive member list does not match manifest\n')
        for entry in manifest['files']:
            raw = archive.read(entry['path'])
            if len(raw) != entry['bytes'] or hashlib.sha256(raw).hexdigest() != entry['sha256']:
                parser.exit(1, 'Archive member checksum mismatch: ' + entry['path'] + '\n')
        records, report = build(archive)
    generated = render(records)
    report_text = json.dumps(report, indent=2) + '\n'
    report_path = MANIFEST.parent / 'catalog-report.json'
    if args.check:
        if OUTPUT.read_text() != generated or report_path.read_text() != report_text:
            parser.exit(1, 'Full catalog is stale; run tools/import_full_data.py\n')
    else:
        OUTPUT.write_text(generated); report_path.write_text(report_text)
    print(json.dumps(report))


if __name__ == '__main__':
    main()
