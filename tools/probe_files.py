"""Expand probe export paths the same way on every shell.

PowerShell and cmd pass "data/probe/*statlab*.json" to Python unexpanded,
so the tools expand wildcards themselves. A pattern that matches nothing
is an error, not an empty run.
"""
import glob
from pathlib import Path


def expand(patterns):
    """['data/probe/*.json', 'x.json'] -> sorted matches per pattern, in order, without duplicates."""
    out = []
    for p in patterns:
        if glob.has_magic(p):
            matches = sorted(glob.glob(p))
            if not matches:
                raise SystemExit(f"no files match {p}")
        elif not Path(p).is_file():
            raise SystemExit(f"no such file: {p}")
        else:
            matches = [p]
        out += [m for m in matches if m not in out]
    return out
