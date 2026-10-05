#!/usr/bin/env python3
"""Tests for tools/stat_lab.py, consumable_ids.py, capture_check.py and probe_files.py.

    python tests/test_tools.py
"""
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import stat_lab  # noqa: E402
import consumable_ids  # noqa: E402
import capture_check  # noqa: E402
import probe_files  # noqa: E402


def snap(at, level, label, values, auras=("Well Fed",), gear=None):
    return {"at": at, "label": label, "values": values, "gear": gear or {},
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

# Gear swaps: what the item carries by itself (armor, weapon damage, shield block) is
# not the stat's effect, so it is left out and listed as confounded.
pants = "|cnIQ2:|Hitem:6084::::::::12:1491::11:::::::|h[Stormwind Guard Leggings]|h|r"
shield = "|cnIQ1:|Hitem:1201::::::::12:1491::14:::::::|h[Dull Heater Shield]|h|r"
swaps = list(stat_lab.steps([
    snap("t1", 12, "", {"strength": 39, "ap_base": 94, "armor": 572, "block_value": 3}, gear={"17": shield}),
    snap("t2", 12, "+3 strength", {"strength": 42, "ap_base": 100, "armor": 685, "block_value": 4},
         gear={"7": pants, "17": shield}),
    snap("t3", 12, "+5 stamina", {"health_max": 200, "armor": 600, "block_value": 9}, gear={"7": pants}),
], "swaps.json"))
assert swaps[0]["per_point"] == {"strength": 1, "ap_base": 2, "block_value": 0.333333}, swaps[0]
assert swaps[0]["confounded"] == ["armor"]
assert "armor" not in swaps[1]["per_point"] and "block_value" not in swaps[1]["per_point"]
assert set(swaps[1]["confounded"]) == {"armor", "block", "block_value", "oh_max", "oh_min", "oh_speed"}
assert "confounded" not in first, "same gear: nothing left out"

# The committed Warrior 12 pair (Stormwind Guard Leggings, +3 Strength) gives 2 AP per Strength, no armor.
warrior, skipped_w, _ = stat_lab.build([str(Path(__file__).resolve().parent.parent
                                            / "data" / "probe" / "2026-10-05-statlab-warrior-12.json")])
assert len(warrior) == 1 and not skipped_w, (warrior, skipped_w)
assert warrior[0]["per_point"]["ap_base"] == 2 and "armor" not in warrior[0]["per_point"], warrior[0]

# Consumable commands: every ID, each line short enough for chat.
ids = consumable_ids.item_ids((consumable_ids.DATA).read_text())
assert len(ids) > 40 and 13452 in ids and len(set(ids)) == len(ids), "unique consumable IDs"
lines = consumable_ids.commands(ids)
assert all(len(l) <= 255 and l.startswith("/bpp items ") for l in lines)
joined = ",".join(l[len("/bpp items "):] for l in lines)
assert [int(x) for x in joined.split(",")] == ids

# Capture check: a level 20 Rogue export with one of each kind of mismatch.
def spell(name, sub="", cost=0):
    return {"name": name, "bookName": name, "subName": sub,
            "costs": [{"type": 3, "name": "ENERGY", "cost": cost}] if cost else [], "description": "<nil>"}


rogue = {"character": "Sassy-Beta", "class": "ROGUE", "race": "Gnome", "level": 20}
probe = {"statlab": [], "perf": [], "captures": {
    "spells": [{"at": "2026-10-05 12:00:00", "who": rogue, "data": {"how": "C_SpellBook", "spells": [
        spell("Sinister Strike", "Rank 1", 45), spell("Sinister Strike", "Rank 2", 45),
        spell("Eviscerate", "Rank 1", 35), spell("Eviscerate", "Rank 2", 35),
        spell("Slice And Dice", "Rank 1", 25),           # client capitalises differently
        spell("Rupturee", "Rank 1", 25),                 # near miss for Rupture
        spell("Evasion", "", 0), spell("Backstab", "Rank 1", 60), spell("Garrote", "Rank 1", 50),
        spell("Feint", "Rank 1", 20),
        spell("Vanish", "Rank 1", 0),                    # data says 22: known earlier
        # Kick (minLevel 12) is missing: a real gap
    ]}}],
    "items": [{"at": "2026-10-05 12:05:00", "who": rogue, "data": {"items": [
        {"itemID": 3390, "name": "Elixir of Lesser Agility", "spellName": "Lesser Agility", "requiredLevel": 18,
         "tooltip": ["Elixir of Lesser Agility", "Use: Increases Agility by 8 for 1 hour."]},
        {"itemID": 2457, "name": "Elixir of Minor Agility", "spellName": "Minor Agility", "requiredLevel": 3,
         "tooltip": ["Use: Increases Agility by 5 for 1 hour."]},
        {"itemID": 8949, "name": "<nil>", "spellName": "<nil>"},
        {"itemID": 118, "name": "Minor Healing Potion", "spellName": "Healing Potion", "requiredLevel": 1,
         "tooltip": ["Use: Restores 70 to 90 health."]},
    ]}}],
    "env": [{"at": "2026-10-05 12:00:00", "who": rogue, "data": {
        "build": ["1.15.8", "12345", "Oct 1 2026", 11508],
        "apis": {"C_Spell.GetSpellPowerCost": "missing", "GetFramerate": "missing", "UnitBuff": "present"}}}],
    "threat": [{"at": "2026-10-05 12:10:00", "who": rogue, "data": {
        "inCombat": True, "detailed": {"status": "secret"}, "simple": {"status": "ok"}}}],
}}
src = tmp / "capture.json"
src.write_text(json.dumps(probe))
lines, flagged = capture_check.report([str(src)], verbose=True)
out = "\n".join(lines)
fixes = [l for l in lines if l.startswith("  FIX")]
assert 'Slice and Dice: the client spells it "Slice And Dice"' in out, out
assert 'Rupture: not in the spellbook; did you mean "Rupturee"?' in out, out
assert "Kick: not in the spellbook at level 20, but data says minLevel 12" in out, out
assert "Vanish: known at level 20 but data says minLevel 22" in out, out
assert "Cheap Shot: not known yet (minLevel 26)" in out and "Adrenaline Rush: not known (talent" in out
assert not any("Eviscerate" in l or "Sinister Strike" in l for l in fixes), "known spells pass"
assert "8949 Elixir of Agility: no item data" in out, out
assert "2457 Elixir of Minor Agility: required level 3, data says 2; tooltip lacks AGILITY 4" in out, out
assert "3390 Elixir of Lesser Agility: ok" in out and "118 Minor Healing Potion: ok" in out, out
assert "consumables not in this capture" in out
assert "only uses them as feature-detected fallbacks: C_Spell.GetSpellPowerCost" in out, out
assert not any("GetFramerate" in l for l in fixes) and "also missing: GetFramerate" in out
assert "in combat: detailed secret, simple ok" in out
assert flagged == len(fixes) and capture_check.main([str(src)]) == 1

# An API called without a feature check is flagged; one behind "if X" or "A or X" isn't.
api = tmp / "API.lua"
api.write_text("local n = C_Spell.GetSpellPowerCost(1)\nif GetFramerate then end\n")
lines, _ = capture_check.report([str(src)], api_path=api)
assert any("C_Spell.GetSpellPowerCost: missing, and Core/API.lua calls it unguarded" in l for l in lines), lines

# Tooltip amounts: WoW's |4hour:hrs; codes and durations don't count, and the stat word must be near.
tip = capture_check.plain("Use: Increases Agility by 8 for 1 |4hour:hrs;. (1 |4Sec:Sec; Cooldown)")
assert tip == "Use: Increases Agility by 8 for 1 . (1  Cooldown)", tip
assert capture_check.states(tip, "AGILITY", 8) and not capture_check.states(tip, "AGILITY", 4)
assert not capture_check.states(tip, "STRENGTH", 8), "right amount, wrong stat"
food = "Use: If you spend at least 10 sec eating, you will become well fed and gain 15 Intellect for 15 min."
assert capture_check.states(food, "INTELLECT", 15) and not capture_check.states(food, "INTELLECT", 10)

# The committed beta capture agrees with Data/Consumables.lua and the Warrior guide.
real = Path(__file__).resolve().parent.parent / "data" / "probe" / "2026-10-05-warrior-12.json"
lines, flagged = capture_check.report([str(real)])
assert flagged == 0, "\n".join(lines)

# A clean capture exits 0; an empty export says what to run.
clean = tmp / "clean.json"
one_item = probe["captures"]["items"][0]["data"]["items"][0]
clean.write_text(json.dumps({"captures": {"items": [{"who": rogue, "data": {"items": [one_item]}}]}}))
lines, flagged = capture_check.report([str(clean)])
assert flagged == 1 and "consumables not in this capture" in lines[1], lines  # the other 54 weren't read
empty = tmp / "empty.json"
empty.write_text("{}")
lines, flagged = capture_check.report([str(empty)])
assert flagged == 0 and lines[0].startswith("nothing captured"), lines

# Wildcards: PowerShell hands them to Python unexpanded, so the tools expand them.
wild = tmp / "wild"
wild.mkdir()
a, b, c = (wild / n for n in ("a.json", "b1.json", "b2.json"))
for f in (a, b, c):
    f.write_text("{}")
assert probe_files.expand([str(wild / "*.json")]) == [str(a), str(b), str(c)]
assert probe_files.expand([str(c), str(wild / "b*.json")]) == [str(c), str(b)], "in order, no duplicates"
for bad in (str(wild / "nothing*.json"), str(wild / "missing.json")):
    try:
        probe_files.expand([bad])
        raise AssertionError(f"{bad} should fail")
    except SystemExit as e:
        assert "no" in str(e)
statlab_dir = tmp / "probe"
statlab_dir.mkdir()
(statlab_dir / "2026-10-05-statlab-rogue.json").write_text(json.dumps(export))
out2 = tmp / "conversions2.json"
assert stat_lab.main([str(statlab_dir / "*statlab*.json"), "--out", str(out2)]) == 0
assert json.loads(out2.read_text())["sources"] == ["2026-10-05-statlab-rogue.json"]

print("tools tests passed")
