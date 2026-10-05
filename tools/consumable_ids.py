#!/usr/bin/env python3
"""Print /bpp items commands for every consumable in Battleplan's data.

    python tools/consumable_ids.py

Paste each line into WoW chat with BattleplanProbe loaded, then /bpp export.
The capture records each item's buff (spell) name and tooltip, which is how
Data/Consumables.lua gets confirmed (or fixed) for Forever. Chat lines are
capped at 255 characters, so the IDs are split across several commands.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "Battleplan" / "Data" / "Consumables.lua"
LIMIT = 250


def item_ids(text):
    return [int(m) for m in re.findall(r"itemID\s*=\s*(\d+)", text)]


def commands(ids, limit=LIMIT):
    lines, cur = [], "/bpp items "
    for i in ids:
        piece = str(i) if cur.endswith(" ") else "," + str(i)
        if len(cur) + len(piece) > limit:
            lines.append(cur)
            cur = "/bpp items " + str(i)
        else:
            cur += piece
    if not cur.endswith(" "):
        lines.append(cur)
    return lines


def main():
    ids = item_ids(DATA.read_text())
    for line in commands(ids):
        print(line)
    print(f"# {len(ids)} items", file=sys.stderr)


if __name__ == "__main__":
    main()
