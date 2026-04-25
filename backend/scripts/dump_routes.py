"""Dump all FastAPI APIRoute instances as sorted JSON for baseline/diff.

Usage:
    python -m scripts.dump_routes > scripts/routes_baseline.json

Or with explicit output:
    python -m scripts.dump_routes scripts/routes_current.json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

# Ensure `backend/` is on sys.path so `app.main` imports work when run from anywhere
_HERE = Path(__file__).resolve().parent.parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from fastapi.routing import APIRoute

from app.main import app


def dump_routes() -> list[dict]:
    entries: list[dict] = []
    for route in app.routes:
        if not isinstance(route, APIRoute):
            continue
        methods = sorted(route.methods or [])
        for method in methods:
            entries.append(
                {
                    "method": method,
                    "path": route.path,
                    "name": route.name,
                }
            )
    entries.sort(key=lambda e: (e["method"], e["path"], e["name"]))
    return entries


def main() -> int:
    entries = dump_routes()
    out = json.dumps(entries, indent=2, ensure_ascii=False)
    if len(sys.argv) > 1:
        Path(sys.argv[1]).write_text(out, encoding="utf-8")
        print(f"Wrote {len(entries)} routes to {sys.argv[1]}", file=sys.stderr)
    else:
        print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
