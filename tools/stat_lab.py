#!/usr/bin/env python3
"""Turn stat lab snapshots into a conversion table.

In game (BattleplanProbe), change ONE thing between snapshots and label the
second one with what you changed:

    /bpp stats                    (baseline)
    (equip a +10 Agility item)
    /bpp stats +10 agility
    /bpp export                   (paste into data/probe/YYYY-MM-DD-statlab.json)

Then:

    python tools/stat_lab.py data/probe/*statlab*.json

writes data/stats/conversions.json: for each class, level and input stat,
what one point of it changed (crit, attack power, armor, dodge...), plus a
straight-line fit over level wherever several levels were measured.
Snapshots whose buffs differ from the one before are skipped, because a
buff falling off in between would be counted as the stat's effect.

An item carries more than its stat: armor, a weapon's damage, a shield's block.
When the gear differs between two snapshots, the outputs the swapped slots can
carry on their own are left out of that measurement and listed under
"confounded", so a +3 Strength pair of leggings doesn't read as 37 armor per
Strength. Measure those outputs with a buff, an enchant or a slot that has none.
"""
import argparse
import json
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

from probe_files import expand

ROOT = Path(__file__).resolve().parent.parent
LABEL = re.compile(r"^\s*([+-]?\d+(?:\.\d+)?)\s+([A-Za-z][A-Za-z _%-]*?)\s*$")
ALIASES = {
    "agi": "agility", "str": "strength", "sta": "stamina", "stam": "stamina", "int": "intellect",
    "spi": "spirit", "ap": "attack_power", "hit": "hit_rating", "crit": "crit_rating",
    "haste": "haste_rating", "expertise": "expertise_rating", "def": "defense", "armour": "armor",
}


def parse_label(label):
    """'+10 agility' -> (10.0, 'agility'); None when it isn't a stat change."""
    m = LABEL.match(label or "")
    if not m:
        return None
    amount = float(m.group(1))
    name = m.group(2).strip().lower().replace(" ", "_").replace("-", "_")
    name = ALIASES.get(name, name)
    if amount == 0:
        return None
    return amount, name


# Inventory slot -> outputs an item in that slot changes by itself (slot numbers
# are the client's INVSLOT_*). Neck, shirt, rings, trinkets and tabard add none.
ARMOR_SLOTS = ("1", "3", "5", "6", "7", "8", "9", "10", "15", "17")
SLOT_OUTPUTS = {
    "16": ("mh_min", "mh_max", "mh_speed"),
    "17": ("oh_min", "oh_max", "oh_speed", "block", "block_value"),
    "18": ("ranged_speed",),
}


def confounded(before, after):
    """Outputs the gear swapped between two snapshots can change on its own."""
    ga, gb = before.get("gear") or {}, after.get("gear") or {}
    slots = [slot for slot in set(ga) | set(gb) if ga.get(slot) != gb.get(slot)]
    outputs = set()
    for slot in slots:
        if slot in ARMOR_SLOTS:
            outputs.add("armor")
        outputs.update(SLOT_OUTPUTS.get(slot, ()))
    return outputs


def aura_names(snap):
    return sorted(str(a.get("name")) for a in snap.get("auras", []) if isinstance(a, dict))


def steps(snapshots, source):
    """Yield one measurement per labelled snapshot that follows another."""
    for before, after in zip(snapshots, snapshots[1:]):
        parsed = parse_label(after.get("label", ""))
        if not parsed:
            continue
        amount, stat = parsed
        who_a, who_b = before.get("who", {}), after.get("who", {})
        if who_a.get("character") != who_b.get("character") or who_a.get("level") != who_b.get("level"):
            yield {"skipped": "different character or level", "label": after.get("label"), "source": source}
            continue
        if aura_names(before) != aura_names(after):
            yield {"skipped": "buffs changed between snapshots", "label": after.get("label"), "source": source}
            continue
        per_point, mixed = {}, confounded(before, after)
        va, vb = before.get("values", {}), after.get("values", {})
        for key in sorted(set(va) | set(vb)):
            x, y = va.get(key), vb.get(key)
            if key in mixed:
                continue
            if isinstance(x, (int, float)) and isinstance(y, (int, float)) and abs(y - x) > 1e-9:
                per_point[key] = round((y - x) / amount, 6)
        entry = {
            "class": who_b.get("class"), "race": who_b.get("race"), "level": who_b.get("level"),
            "input": stat, "amount": amount, "per_point": per_point,
            "at": after.get("at"), "source": source,
        }
        if mixed:
            entry["confounded"] = sorted(mixed)
        yield entry


def fit(points):
    """Least-squares line through (level, value): (slope, intercept)."""
    n = len(points)
    mx = sum(p[0] for p in points) / n
    my = sum(p[1] for p in points) / n
    sxx = sum((p[0] - mx) ** 2 for p in points)
    if sxx == 0:
        return 0.0, my
    slope = sum((p[0] - mx) * (p[1] - my) for p in points) / sxx
    return slope, my - slope * mx


def build(files):
    entries, skipped = [], []
    for path in files:
        data = json.loads(Path(path).read_text())
        snaps = sorted(data.get("statlab", []), key=lambda s: s.get("at", ""))
        for e in steps(snaps, Path(path).name):
            (skipped if "skipped" in e else entries).append(e)

    # One line per class/input/output: value per point at each level, and a fit.
    by_key = defaultdict(lambda: defaultdict(list))
    for e in entries:
        for out, v in e["per_point"].items():
            by_key[(e["class"], e["input"], out)][e["level"]].append(v)
    fits = []
    for (cls, inp, out), levels in sorted(by_key.items()):
        pts = [(lvl, sum(vs) / len(vs)) for lvl, vs in sorted(levels.items())]
        row = {"class": cls, "input": inp, "output": out,
               "levels": {str(l): round(v, 6) for l, v in pts}}
        if len(pts) >= 2:
            slope, intercept = fit(pts)
            row["fit"] = {"per_level": round(slope, 8), "at_level_0": round(intercept, 6),
                          "at_level_60": round(intercept + 60 * slope, 6)}
        fits.append(row)
    return entries, skipped, fits


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+", help="BattleplanProbe export JSON files")
    ap.add_argument("--out", default=str(ROOT / "data" / "stats" / "conversions.json"))
    args = ap.parse_args(argv)
    files = expand(args.files)

    entries, skipped, fits = build(files)
    result = {
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "sources": sorted({Path(f).name for f in files}),
        "entries": entries, "skipped": skipped, "conversions": fits,
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2) + "\n")

    print(f"{len(entries)} measurements, {len(skipped)} skipped -> {out}")
    for s in skipped:
        print(f"  skipped '{s['label']}' ({s['source']}): {s['skipped']}")
    for e in entries:
        if e.get("confounded"):
            print(f"  +{e['amount']:g} {e['input']} at {e['at']}: gear changed, so not measured: "
                  + ", ".join(e["confounded"]))
    for row in fits:
        levels = ", ".join(f"L{l} {v:g}" for l, v in row["levels"].items())
        line = f"  {row['class']} {row['input']} -> {row['output']}: {levels}"
        if "fit" in row:
            line += f"  (fit: {row['fit']['at_level_60']:g} at 60)"
        print(line)
        # Ratings and stats are easier to read the other way round: "agility per 1% crit".
        last = list(row["levels"].values())[-1]
        if row["output"].startswith(("crit", "dodge", "parry", "hit", "block")) and last:
            print(f"      = {1 / last:.2f} {row['input']} per 1 {row['output']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
