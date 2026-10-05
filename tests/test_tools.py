#!/usr/bin/env python3
"""Tests for tools/stat_lab.py and tools/consumable_ids.py.

    python tests/test_tools.py
"""
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import stat_lab  # noqa: E402
import consumable_ids  # noqa: E402


def snap(at, level, label, values, auras=("Well Fed",)):
    return {"at": at, "label": label, "values": values,
            "who": {"character": "Sassy-Beta", "class": "ROGUE", "race": "Gnome", "level": level},
            "auras": [{"name": a} for a in auras]}


# Labels
assert stat_lab.parse_label("+10 agility") == (10.0, "agility")
assert stat_lab.parse_label("10 agi") == (10.0, "agility")
assert stat_lab.parse_label("+14 crit rating") == (14.0, "crit_rating")
assert stat_lab.parse_label("-15 parry rating") == (-15.0, "parry_rating")
assert stat_lab.parse_label("all") is None and stat_lab.parse_label("") is None

# Agility at level 19 and 29, plus one pair spoiled by a buff falling off.
export = {"statlab": [
    snap("2026-10-05 10:00:00", 19, "", {"agility": 66, "crit_melee": 13.69, "ap_base": 117, "armor": 487}),
    snap("2026-10-05 10:01:00", 19, "+10 agility", {"agility": 76, "crit_melee": 15.0, "ap_base": 127, "armor": 507}),
    snap("2026-10-05 11:00:00", 29, "", {"agility": 90, "crit_melee": 14.0, "ap_base": 160}),
    snap("2026-10-05 11:01:00", 29, "+10 agility", {"agility": 100, "crit_melee": 15.0, "ap_base": 170}),
    snap("2026-10-05 11:02:00", 29, "+5 strength", {"agility": 100, "crit_melee": 15.0, "ap_base": 175},
         auras=()),
]}
tmp = Path(tempfile.mkdtemp())
src = tmp / "statlab.json"
src.write_text(json.dumps(export))
out = tmp / "conversions.json"
assert stat_lab.main([str(src), "--out", str(out)]) == 0
result = json.loads(out.read_text())

assert len(result["entries"]) == 2, result["entries"]
assert len(result["skipped"]) == 1 and "buffs changed" in result["skipped"][0]["skipped"]
first = result["entries"][0]
assert first["level"] == 19 and first["input"] == "agility"
assert abs(first["per_point"]["crit_melee"] - 0.131) < 1e-9
assert first["per_point"]["ap_base"] == 1 and first["per_point"]["armor"] == 2
crit = next(c for c in result["conversions"] if c["output"] == "crit_melee")
assert crit["levels"] == {"19": 0.131, "29": 0.1}
assert abs(crit["fit"]["per_level"] - (-0.0031)) < 1e-9, crit["fit"]

# Consumable commands: every ID, each line short enough for chat.
ids = consumable_ids.item_ids((consumable_ids.DATA).read_text())
assert len(ids) > 40 and 13452 in ids and len(set(ids)) == len(ids), "unique consumable IDs"
lines = consumable_ids.commands(ids)
assert all(len(l) <= 255 and l.startswith("/bpp items ") for l in lines)
joined = ",".join(l[len("/bpp items "):] for l in lines)
assert [int(x) for x in joined.split(",")] == ids

print("tools tests passed")
