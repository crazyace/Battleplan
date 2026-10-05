#!/usr/bin/env python3
"""Compare a BattleplanProbe export with Battleplan's data and list what to fix.

    python tools/capture_check.py data/probe/2026-10-08-spells-priest.json [more.json ...]

Reads the probe's captures and checks them against Battleplan/Data:

  spells    every spell a rotation, healing or tanking guide names for the
            captured class: in the spellbook? spelled the same? is its
            minLevel above the level it was captured at? do ranks and costs
            come through (downranking)?
  items     every consumable in Data/Consumables.lua: does the item exist on
            Forever, same name, same required level, do the amounts appear
            in its tooltip?
  env       APIs the client lacks, flagging the ones Core/API.lua calls
  threat    whether threat read as ok or secret, in and out of combat
  statlab   how many snapshots there are (tools/stat_lab.py turns them into numbers)

It only reports: fixing the data, BETA-FINDINGS.md and _status is still a
person's call (see the import-probe-capture skill). Exits 1 when any line
needs attention, 0 when everything checked out.
"""
import argparse
import difflib
import json
import re
import sys
from pathlib import Path

from probe_files import expand

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "Battleplan" / "Data"
API_LUA = ROOT / "Battleplan" / "Core" / "API.lua"
GUIDES = ("Rotations.lua", "Healing.lua", "Tanking.lua")

SPELL_ENTRY = re.compile(r'\{\s*spell\s*=\s*"([^"]+)"([^{}]*)\}')
PREFER = re.compile(r"prefer\s*=\s*\{([^{}]*)\}")
BRACKET_KEY = re.compile(r'\[\s*"([^"]+)"\s*\]\s*=')
QUOTED = re.compile(r'"([^"]+)"')
MIN_LEVEL = re.compile(r"minLevel\s*=\s*(\d+)")
TALENT = re.compile(r"talent\s*=\s*true")
ITEM = re.compile(r'\{\s*itemID\s*=\s*(\d+)\s*,\s*name\s*=\s*"([^"]+)"(.*?)\}\s*,\s*$', re.M | re.S)
FIELD_NUM = r"\b{}\s*=\s*(\d+(?:\.\d+)?)"
EXTRA = re.compile(r"extra\s*=\s*\{([^{}]*)\}")
EXTRA_PAIR = re.compile(r"([A-Z_]+)\s*=\s*(\d+(?:\.\d+)?)")
NUMBER = re.compile(r"\d+(?:\.\d+)?")
# WoW text codes: |4singular:plural; grammar, |cAARRGGBB colour, |r reset, |H...|h links.
# Their digits ("|4hour:hrs;") must not count as amounts.
ESCAPES = re.compile(r"\|4[^;]*;|\|c[0-9a-fA-F]{8}|\|[rh]|\|H[^|]*")
# The word a tooltip uses for each stat key, to tell "+4 Agility" from "4 Strength".
STAT_WORDS = {
    "STRENGTH": "strength", "AGILITY": "agility", "STAMINA": "stamina", "INTELLECT": "intellect",
    "SPIRIT": "spirit", "ARMOR": "armor", "HEALTH": "health", "MP5": "mana", "HEALING": "heal",
    "SPELL_POWER": "spell damage", "WEAPON_DAMAGE": "damage", "CRIT_PCT": "critical",
}
NEAR = 40  # characters between an amount and its stat word
DURATION = re.compile(r"\s*(?:sec|min|hour|hrs)", re.I)  # "10 sec eating" is not an amount


# Battleplan's data -------------------------------------------------------------------
def guide_spells(class_dir):
    """{spell name: {"minLevel": int|None, "talent": bool, "files": set}} for one class."""
    spells = {}

    def note(name, file, min_level=None, talent=False):
        s = spells.setdefault(name, {"minLevel": None, "talent": False, "files": set()})
        s["files"].add(file)
        if min_level is not None:
            s["minLevel"] = min_level if s["minLevel"] is None else min(s["minLevel"], min_level)
        s["talent"] = s["talent"] or talent

    for file in GUIDES:
        path = class_dir / file
        if not path.exists():
            continue
        text = path.read_text()
        for name, rest in SPELL_ENTRY.findall(text):
            m = MIN_LEVEL.search(rest)
            note(name, file, int(m.group(1)) if m else None, bool(TALENT.search(rest)))
        for body in PREFER.findall(text):
            for name in QUOTED.findall(body):
                note(name, file)
        for name in BRACKET_KEY.findall(text):
            note(name, file)
    return spells


def consumables(path=DATA / "Consumables.lua"):
    """{itemID: {"name", "kind", "minLevel", "amounts": {stat: amount}}}."""
    out = {}
    for item_id, name, rest in ITEM.findall(path.read_text()):
        def num(field):
            m = re.search(FIELD_NUM.format(field), rest)
            return float(m.group(1)) if m else None
        kind = re.search(r'kind\s*=\s*"([^"]+)"', rest)
        stat = re.search(r'stat\s*=\s*"([^"]+)"', rest)
        amounts = {}
        if stat and num("amount") is not None:
            amounts[stat.group(1)] = num("amount")
        extra = EXTRA.search(rest)
        if extra:
            amounts.update({k: float(v) for k, v in EXTRA_PAIR.findall(extra.group(1))})
        level = num("minLevel")
        out[int(item_id)] = {"name": name, "kind": kind.group(1) if kind else None,
                             "minLevel": int(level) if level is not None else None, "amounts": amounts}
    return out


# The capture -------------------------------------------------------------------------
def load(files):
    """Merge several exports: statlab and perf lists, captures per kind, each tagged with its file."""
    merged = {"statlab": [], "captures": {}, "perf": []}
    for f in files:
        d = json.loads(Path(f).read_text())
        name = Path(f).name
        merged["statlab"] += d.get("statlab") or []
        merged["perf"] += d.get("perf") or []
        for kind, caps in (d.get("captures") or {}).items():
            for c in caps or []:
                merged["captures"].setdefault(kind, []).append(dict(c, source=name))
    return merged


def text(v):
    """Probe placeholders ("<nil>", "<secret>") and non-strings read as missing."""
    return v if isinstance(v, str) and not (v.startswith("<") and v.endswith(">")) else None


def fmt(n):
    return f"{n:g}"


def plain(s):
    return ESCAPES.sub("", s)


def states(tip, stat, amount):
    """Does the tooltip give this amount, next to this stat's word when we know the word?"""
    word = STAT_WORDS.get(stat)
    for m in NUMBER.finditer(tip):
        if float(m.group()) != amount or DURATION.match(tip, m.end()):
            continue
        if word is None or word in tip[max(0, m.start() - NEAR):m.end() + NEAR].lower():
            return True
    return False


# Checks: each returns (heading, [lines that need attention], [lines that are fine]) ---
def check_spells(capture, class_root=DATA):
    who = capture.get("who") or {}
    cls, level = who.get("class"), who.get("level")
    data = capture.get("data") or {}
    book = data.get("spells") or []
    head = f"spells: {cls} level {level} ({capture['source']}, {data.get('how')}, {len(book)} entries)"
    bad, good = [], []
    class_dir = class_root / str(cls)
    if not class_dir.is_dir():
        return head, [f"no Battleplan/Data/{cls}/ folder: is this a class Battleplan covers?"], good

    ranks, names = {}, {}
    for s in book:
        name = text(s.get("name")) or text(s.get("bookName"))
        if not name:
            continue
        names.setdefault(name.lower(), name)
        r = ranks.setdefault(name, {"ranks": 0, "cost": False, "desc": False})
        r["ranks"] += 1
        sub = text(s.get("subName"))
        r["ranked"] = r.get("ranked", False) or bool(sub and re.search(r"\d", sub))
        r["cost"] = r["cost"] or any(isinstance(c.get("cost"), (int, float)) and c["cost"] > 0
                                     for c in (s.get("costs") or []))
        r["desc"] = r["desc"] or bool(text(s.get("description")))

    wanted = guide_spells(class_dir)
    for name, info in sorted(wanted.items()):
        where = ", ".join(sorted(info["files"]))
        if name in ranks:
            if info["minLevel"] is not None and isinstance(level, int) and info["minLevel"] > level:
                bad.append(f"{name}: known at level {level} but data says minLevel {info['minLevel']} ({where})")
            continue
        if name.lower() in names:
            bad.append(f'{name}: the client spells it "{names[name.lower()]}" ({where})')
            continue
        close = difflib.get_close_matches(name, list(ranks), n=1, cutoff=0.8)
        if close:
            bad.append(f'{name}: not in the spellbook; did you mean "{close[0]}"? ({where})')
        elif info["talent"]:
            good.append(f"{name}: not known (talent; fine unless the capture had points in it)")
        elif info["minLevel"] is not None and isinstance(level, int) and info["minLevel"] > level:
            good.append(f"{name}: not known yet (minLevel {info['minLevel']})")
        elif info["minLevel"] is None:
            good.append(f"{name}: not known (no minLevel in data: may be a talent or a higher-level spell)")
        else:
            bad.append(f"{name}: not in the spellbook at level {level}, but data says minLevel "
                       f"{info['minLevel']} ({where})")

    ranked = sum(1 for r in ranks.values() if r.get("ranked"))
    listed = sum(1 for r in ranks.values() if r["ranks"] > 1)
    with_cost = sum(1 for r in ranks.values() if r["cost"])
    with_desc = sum(1 for r in ranks.values() if r["desc"])
    good.append(f"{len(ranks)} spells; {ranked} have a rank in their name, {listed} are listed at more than one"
                f" rank, {with_cost} have a cost, {with_desc} a description")
    if ranks and ranked == 0:
        bad.append("no spell has a rank in its name: ranks may be gone (healing guide 'efficient' rank)")
    if ranks and with_cost == 0:
        bad.append("no spell came with a cost: GetSpellPowerCost may be missing or secret")
    return head, bad, good


def check_items(captures, data):
    seen = {}
    for c in captures:
        for item in (c.get("data") or {}).get("items") or []:
            if isinstance(item.get("itemID"), int):
                # Later reads win: a re-run fills in items the server hadn't sent yet.
                if text(item.get("name")) or item["itemID"] not in seen:
                    seen[item["itemID"]] = item
    head = f"items: {len(seen)} read, {len(data)} in Data/Consumables.lua"
    bad, good = [], []
    for item_id, want in data.items():
        got = seen.get(item_id)
        label = f"{item_id} {want['name']}"
        if got is None:
            continue
        name = text(got.get("name"))
        if not name:
            bad.append(f"{label}: no item data (missing on Forever, or run /bpp items again)")
            continue
        problems = []
        if name != want["name"]:
            problems.append(f'client calls it "{name}"')
        req = got.get("requiredLevel")
        if isinstance(req, int) and want["minLevel"] is not None and req != want["minLevel"]:
            problems.append(f"required level {req}, data says {want['minLevel']}")
        if not text(got.get("spellName")):
            problems.append("no item spell (does it still do anything?)")
        if want["kind"] != "potion":  # potion amounts are tiers, not tooltip numbers
            tip = plain(" ".join(t for t in (got.get("tooltip") or []) if isinstance(t, str)))
            missing = [f"{stat} {fmt(v)}" for stat, v in want["amounts"].items() if not states(tip, stat, v)]
            if not tip:
                problems.append("no tooltip text to check the amount against")
            elif missing:
                problems.append(f"tooltip lacks {', '.join(missing)}: \"{tip[:120]}\"")
        if problems:
            bad.append(f"{label}: " + "; ".join(problems))
        else:
            good.append(f"{label}: ok")
    unread = [i for i in data if i not in seen]
    if seen and unread:
        bad.append(f"{len(unread)} consumables not in this capture: {', '.join(map(str, unread[:12]))}"
                   + (" ..." if len(unread) > 12 else "") + " (python tools/consumable_ids.py)")
    extra = sorted(i for i in seen if i not in data)
    if extra:
        good.append(f"captured but not in data: {', '.join(map(str, extra))}")
    return head, bad, good


def check_env(captures, api_text):
    bad, good = [], []
    c = captures[-1]
    data = c.get("data") or {}
    apis = data.get("apis") or {}
    build = data.get("build") or []
    head = f"env: build {' '.join(str(b) for b in build[:4])} ({c['source']})"
    missing = sorted(p for p, v in apis.items() if v == "missing")
    used = [p for p in missing if re.search(r"\b" + re.escape(p) + r"\b", api_text)]
    # "if X", "elseif X", "A and X", "A or X", "(X": API.lua checks for it before calling,
    # so it's a fallback the client doesn't need; anything else would error.
    guard = r"(\b(?:if|elseif|and|or|not)\s+|\()\(?\s*"
    guarded = [p for p in used if re.search(guard + re.escape(p) + r"\b", api_text)]
    for p in used:
        if p not in guarded:
            bad.append(f"{p}: missing, and Core/API.lua calls it unguarded (needs a fallback and a mock to match)")
    rest = [p for p in missing if p not in used]
    good.append(f"{len(apis) - len(missing)} of {len(apis)} APIs present"
                + (f"; also missing: {', '.join(rest)}" if rest else ""))
    if guarded:
        good.append(f"missing, but Core/API.lua only uses them as feature-detected fallbacks: {', '.join(guarded)}")
    return head, bad, good


def check_threat(captures):
    lines = []
    for c in captures:
        d = c.get("data") or {}
        combat = "in combat" if d.get("inCombat") else "out of combat"
        lines.append(f"{combat}: detailed {(d.get('detailed') or {}).get('status')}, "
                     f"simple {(d.get('simple') or {}).get('status')}")
    return f"threat: {len(captures)} reads", [], lines


def report(files, verbose=False, class_root=DATA, consumables_path=DATA / "Consumables.lua", api_path=API_LUA):
    """Returns (printable lines, number of lines that need attention)."""
    cap = load(files)
    caps = cap["captures"]
    sections = []
    # One spellbook per character and level: /bpp all twice gives two identical reads.
    latest = {}
    for c in caps.get("spells", []):
        who = c.get("who") or {}
        latest[(who.get("character"), who.get("level"))] = c
    for c in latest.values():
        sections.append(check_spells(c, class_root))
    if caps.get("items"):
        sections.append(check_items(caps["items"], consumables(consumables_path)))
    if caps.get("env"):
        sections.append(check_env(caps["env"], api_path.read_text()))
    if caps.get("threat"):
        sections.append(check_threat(caps["threat"]))
    if cap["statlab"]:
        sections.append((f"statlab: {len(cap['statlab'])} snapshots", [],
                         ["python tools/stat_lab.py " + " ".join(files)]))
    if cap["perf"]:
        sections.append((f"perf: {len(cap['perf'])} runs", [], ["compare runs with Battleplan on and off"]))
    for kind in sorted(set(caps) - {"spells", "items", "env", "threat"}):
        sections.append((f"{kind}: {len(caps[kind])} captures (not checked here)", [], []))

    out, flagged = [], 0
    for head, bad, good in sections:
        out.append(head)
        out += [f"  FIX  {b}" for b in bad]
        if verbose or not bad:
            out += [f"  ok   {g}" for g in good]
        flagged += len(bad)
    if not sections:
        out.append("nothing captured: run /bpp all (and /bpp items ...) before /bpp export")
    out.append(f"{flagged} to fix" if flagged else "everything checked out")
    return out, flagged


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+", help="BattleplanProbe export JSON files")
    ap.add_argument("-v", "--verbose", action="store_true", help="also list what checked out")
    args = ap.parse_args(argv)
    lines, flagged = report(expand(args.files), args.verbose)
    # Tooltips can hold characters a Windows console code page can't print.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="replace")
    print("\n".join(lines))
    return 1 if flagged else 0


if __name__ == "__main__":
    sys.exit(main())
