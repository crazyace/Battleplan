#!/usr/bin/env python3
"""Every check CI runs, in one command. Run it before every commit:

    python scripts/check.py

Works the same from PowerShell, cmd, Git Bash, macOS and Linux. scripts/check.sh
(used by the pre-push hook and CI) runs this file. Set BATTLEPLAN_REQUIRE_LUACHECK=1
to fail instead of skipping when luacheck isn't installed (CI does).
"""
import importlib.util
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TESTS = [
    ("smoke test", "tests/smoke_test.py"),
    ("icons test", "tests/icons_test.py"),
    ("UI test", "tests/ui_test.py"),
    ("gear advice test", "tests/gear_advice_test.py"),
    ("gear comparison test", "tests/gear_comparison_test.py"),
    ("gear tooltip test", "tests/gear_tooltip_test.py"),
    ("gear catalog test", "tests/gear_catalog_test.py"),
    ("full data test", "tests/full_data_test.py"),
    ("class data test", "tests/class_data_test.py"),
    ("perf test", "tests/perf_test.py"),
    ("regression test", "tests/regression_test.py"),
    ("milestone test", "tests/milestone_test.py"),
    ("trait capture test", "tests/trait_capture_test.py"),
    ("talent effects test", "tests/talent_effects_test.py"),
    ("tools test", "tests/test_tools.py"),
    ("rules test", "tests/test_rules.py"),
]


def run(name, cmd):
    res = subprocess.run(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         text=True, encoding="utf-8", errors="replace")
    if res.returncode == 0:
        print(f"ok    {name}")
        return True
    print(f"FAIL  {name}\n{res.stdout}\n")
    return False


def main():
    if importlib.util.find_spec("lupa") is None:
        print(f'check: the tests need lupa:  {Path(sys.executable).name} -m pip install "lupa>=2.0"')
        return 1
    ok = True
    for name, script in TESTS:
        ok = run(name, [sys.executable, script]) and ok
    luacheck = shutil.which("luacheck")
    if luacheck:
        ok = run("luacheck", [luacheck, ".", "--no-color", "-q"]) and ok
    elif os.environ.get("BATTLEPLAN_REQUIRE_LUACHECK") == "1":
        print("FAIL  luacheck is required here but not installed (luarocks install luacheck)")
        ok = False
    else:
        print("skip  luacheck (not installed; luarocks install luacheck)")
    print("check: all passed" if ok else "check: FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
