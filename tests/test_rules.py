#!/usr/bin/env python3
"""Architecture rules from AGENTS.md, checked on every push.

    python tests/test_rules.py

1. Only Core/API.lua reads game data.
2. Engine/ makes no WoW calls at all.
3. Every Data/ file declares a _status of verified, provisional or todo.
4. Every addon file is listed in its .toc, and every .toc entry exists.
5. Only the scheduler's runner and the probe's frame timer use OnUpdate.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADDON = ROOT / "Battleplan"
problems = []

GAME_READS = re.compile(r"C_(Item|Spell|SpellBook|Traits|ClassTalents|UnitAuras)\.|GetInventoryItemLink|"
                        r"\bUnitClass\b|\bUnitLevel\b|\bUnitBuff\b|GetWeaponEnchantInfo|\bIsInInstance\b")
WOW_CALLS = re.compile(r"\bC_[A-Z]\w*|\bUnit[A-Z]\w*\(|\bCreateFrame\b|\bGetInventory\w*|\bInCombatLockdown\b")


def code_lines(path):
    """(line number, text) for non-comment lines, with trailing comments removed."""
    for n, line in enumerate(path.read_text().splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("--"):
            continue
        yield n, line.split(" --")[0]


for path in sorted(ADDON.rglob("*.lua")):
    rel = path.relative_to(ROOT).as_posix()
    for n, line in code_lines(path):
        if rel != "Battleplan/Core/API.lua" and GAME_READS.search(line):
            problems.append(f"{rel}:{n}: game read outside Core/API.lua: {line.strip()}")
        if rel.startswith("Battleplan/Engine/") and WOW_CALLS.search(line):
            problems.append(f"{rel}:{n}: WoW call in the engine: {line.strip()}")
        if '"OnUpdate"' in line and rel != "Battleplan/Core/Scheduler.lua":
            problems.append(f"{rel}:{n}: OnUpdate outside the scheduler: {line.strip()}")

for path in sorted((ADDON / "Data").rglob("*.lua")):
    m = re.search(r'_status\s*=\s*"(\w+)"', path.read_text())
    if not m or m.group(1) not in ("verified", "provisional", "todo"):
        problems.append(f"{path.relative_to(ROOT)}: missing or invalid _status")

for folder, toc in (("Battleplan", "Battleplan.toc"), ("BattleplanProbe", "BattleplanProbe.toc")):
    listed = set()
    for line in (ROOT / folder / toc).read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            listed.add(line.replace("\\", "/"))
            if not (ROOT / folder / line.replace("\\", "/")).exists():
                problems.append(f"{folder}/{toc}: lists missing file {line}")
    for path in (ROOT / folder).rglob("*.lua"):
        rel = path.relative_to(ROOT / folder).as_posix()
        if rel not in listed:
            problems.append(f"{folder}/{rel}: not in {toc}")

if problems:
    print("\n".join(problems))
    print(f"\nrules test FAILED: {len(problems)} problems")
    sys.exit(1)
print("rules test passed")
