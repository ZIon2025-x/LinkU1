"""
Route modules extracted from app/routers.py (split completed 2026-04-25).

Each submodule owns one domain of routes. main.py iterates over them and
double-mounts at /api and /api/users prefixes via the _SPLIT_ROUTERS list.

This package intentionally does NOT expose a combined_router — main.py handles
registration directly to match the style of other *_routes.py files in app/.

See docs/superpowers/specs/2026-04-25-routers-py-split-design.md
"""
