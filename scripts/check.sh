#!/usr/bin/env sh
# Every check CI runs, in one command. Run it before every commit:
#
#   sh scripts/check.sh
#
# The pre-push hook (.githooks/pre-push) runs it too, so a failing change
# can't be pushed. Works in Git Bash on Windows, macOS and Linux.
set -u
cd "$(dirname "$0")/.." || exit 1

if command -v python3 >/dev/null 2>&1 && python3 -c "import sys" >/dev/null 2>&1; then
  PY=python3
else
  PY=python
fi

if ! "$PY" -c "import lupa" >/dev/null 2>&1; then
  echo "check: the tests need lupa:  $PY -m pip install \"lupa>=2.0\""
  exit 1
fi

failed=0
run() {
  name=$1
  shift
  if out=$("$@" 2>&1); then
    printf 'ok    %s\n' "$name"
  else
    printf 'FAIL  %s\n%s\n\n' "$name" "$out"
    failed=1
  fi
}

run "smoke test" "$PY" tests/smoke_test.py
run "perf test" "$PY" tests/perf_test.py
run "tools test" "$PY" tests/test_tools.py
run "rules test" "$PY" tests/test_rules.py

if command -v luacheck >/dev/null 2>&1; then
  run "luacheck" luacheck . --no-color -q
elif [ "${BATTLEPLAN_REQUIRE_LUACHECK:-0}" = "1" ]; then
  echo "FAIL  luacheck is required here but not installed (luarocks install luacheck)"
  failed=1
else
  echo "skip  luacheck (not installed; luarocks install luacheck)"
fi

if [ "$failed" -ne 0 ]; then
  echo "check: FAILED"
  exit 1
fi
echo "check: all passed"
