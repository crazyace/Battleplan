#!/usr/bin/env sh
# Every check CI runs, in one command; the work is in scripts/check.py so it
# runs the same from PowerShell (python scripts/check.py). The pre-push hook
# (.githooks/pre-push) and CI call this file.
cd "$(dirname "$0")/.." || exit 1

if command -v python3 >/dev/null 2>&1 && python3 -c "import sys" >/dev/null 2>&1; then
  exec python3 scripts/check.py "$@"
fi
exec python scripts/check.py "$@"
