# `forum_routes.py` Split — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split `backend/app/forum_routes.py` (8,345 lines, 64 routes) into 7 focused files under `app/routes/`, leaving `forum_routes.py` as a helper-only module with its 19 external importers untouched.

**Architecture:** Pure refactor. Each route function is moved verbatim to a new domain file; all 30+ helpers stay in `forum_routes.py`. New sub-routers are bare `APIRouter()` instances mounted in `main.py` via a `_FORUM_ROUTERS` list-loop with shared `prefix="/api/forum"`. Verification reuses the `routers.py`-split infrastructure (dump_routes.py, smoke test, GH Actions, linktest probes) — zero new infra.

**Tech Stack:** FastAPI, Python 3.11+, pytest, GitHub Actions, Railway (deploy target).

**Spec:** `docs/superpowers/specs/2026-04-26-forum-routes-split-design.md`

---

## File Structure

### Created

```
backend/app/routes/
├── forum_categories_routes.py    (12 routes; visibility, category CRUD, requests, feed, stats)
├── forum_posts_routes.py         (14 routes; post CRUD + pin/feature/lock/hide/restore)
├── forum_replies_routes.py       (5 routes; reply listing + CRUD + restore)
├── forum_interactions_routes.py  (7 routes; likes + favorites incl. category favorites)
├── forum_my_routes.py            (5 routes; my/posts, my/replies, my/favorites, my/likes, my/category-favorites)
├── forum_discovery_routes.py     (13 routes; search, hot-posts, leaderboard, user stats, notifications, linkable)
└── forum_admin_routes.py         (8 routes; reports + admin ops)
```

### Modified

- `backend/app/forum_routes.py` — routes deleted; all 30+ helpers preserved; final size ~1,200-1,500 lines
- `backend/app/main.py` — `_FORUM_ROUTERS` list added; legacy `forum_router` import + include_router removed in commit 7
- `backend/scripts/routes_baseline.json` — regenerated as new baseline
- `backend/tests/test_routers_split_smoke.py` — 7 forum probes appended
- `backend/scripts/smoke_linktest.sh` — 5 forum curl probes appended

### Untouched (verified by audit, see Pre-flight)

19 external importer call-sites across 11 files — all reference helpers that stay in `forum_routes.py`.

---

## Route → File Mapping (authoritative)

Lines refer to current `backend/app/forum_routes.py` HEAD (commit `f0ebade90` baseline).

### `forum_categories_routes.py` (12 routes)
| Line | Method | Path |
|---:|---|---|
| 1313 | GET | `/forums/visible` |
| 1717 | GET | `/categories` |
| 1811 | POST | `/categories/request` |
| 1919 | GET | `/categories/requests` |
| 1999 | GET | `/categories/requests/my` |
| 2053 | PUT | `/categories/requests/{request_id}/review` |
| 2243 | GET | `/categories/{category_id}` |
| 2316 | POST | `/categories` |
| 2429 | PUT | `/categories/{category_id}` |
| 2593 | DELETE | `/categories/{category_id}` |
| 2745 | GET | `/categories/{category_id}/feed` |
| 7815 | GET | `/categories/{category_id}/stats` |

**Note**: helpers at lines 2639, 2655, 2685, 2715 (`_parse_json_field`, `_post_to_feed_data`, `_task_to_feed_data`, `_service_to_feed_data`) are **interleaved** between category routes 2593 and 2745. They **stay in `forum_routes.py`**; the new file imports them.

### `forum_posts_routes.py` (14 routes)
| Line | Method | Path |
|---:|---|---|
| 2879 | GET | `/posts` |
| 3082 | GET | `/posts/{post_id}` |
| 3212 | POST | `/posts` |
| 3622 | PUT | `/posts/{post_id}` |
| 3936 | DELETE | `/posts/{post_id}` |
| 4020 | POST | `/posts/{post_id}/pin` |
| 4098 | DELETE | `/posts/{post_id}/pin` |
| 4165 | POST | `/posts/{post_id}/feature` |
| 4243 | DELETE | `/posts/{post_id}/feature` |
| 4310 | POST | `/posts/{post_id}/lock` |
| 4377 | DELETE | `/posts/{post_id}/lock` |
| 4444 | POST | `/posts/{post_id}/restore` |
| 4495 | POST | `/posts/{post_id}/unhide` |
| 4545 | POST | `/posts/{post_id}/hide` |

### `forum_replies_routes.py` (5 routes)
| Line | Method | Path |
|---:|---|---|
| 4597 | GET | `/posts/{post_id}/replies` |
| 4758 | POST | `/posts/{post_id}/replies` |
| 5035 | PUT | `/replies/{reply_id}` |
| 5135 | DELETE | `/replies/{reply_id}` |
| 5216 | POST | `/replies/{reply_id}/restore` |

### `forum_interactions_routes.py` (7 routes)
| Line | Method | Path |
|---:|---|---|
| 5285 | POST | `/likes` |
| 5373 | GET | `/posts/{post_id}/likes` |
| 5434 | GET | `/replies/{reply_id}/likes` |
| 5497 | POST | `/favorites` |
| 5553 | POST | `/categories/{category_id}/favorite` |
| 5604 | GET | `/categories/{category_id}/favorite/status` |
| 5627 | POST | `/categories/favorites/batch` |

### `forum_my_routes.py` (5 routes)
| Line | Method | Path |
|---:|---|---|
| 5655 | GET | `/my/category-favorites` |
| 6378 | GET | `/my/posts` |
| 6538 | GET | `/my/replies` |
| 6619 | GET | `/my/favorites` |
| 6724 | GET | `/my/likes` |

### `forum_discovery_routes.py` (13 routes)
| Line | Method | Path |
|---:|---|---|
| 5713 | GET | `/search` |
| 6084 | GET | `/notifications` |
| 6227 | PUT | `/notifications/{notification_id}/read` |
| 6254 | PUT | `/notifications/read-all` |
| 6281 | GET | `/notifications/unread-count` |
| 7213 | GET | `/hot-posts` |
| 7377 | GET | `/users/{user_id}/stats` |
| 7446 | GET | `/users/{user_id}/hot-posts` |
| 7597 | GET | `/leaderboard/posts` |
| 7663 | GET | `/leaderboard/favorites` |
| 7730 | GET | `/leaderboard/likes` |
| 7901 | GET | `/search-linkable` |
| 8191 | GET | `/linkable-for-user` |

### `forum_admin_routes.py` (8 routes)
| Line | Method | Path |
|---:|---|---|
| 5872 | POST | `/reports` |
| 5972 | GET | `/reports` |
| 6021 | PUT | `/admin/reports/{report_id}/process` |
| 6864 | GET | `/admin/operation-logs` |
| 6928 | GET | `/admin/stats` |
| 7082 | GET | `/admin/categories` |
| 7125 | GET | `/admin/pending-requests/count` |
| 7144 | POST | `/admin/fix-statistics` |

**Total: 64 routes.** Counts verified against `grep -cE "^@router\." backend/app/forum_routes.py`.

---

## External Importer Audit (pre-validated 2026-04-26)

The following 18 import call-sites (excluding `main.py`, which we modify) reference only **helpers** — never route handlers. Zero changes required.

| File:line | Imported names |
|---|---|
| `app/admin_student_verification_routes.py:184` | `invalidate_forum_visibility_cache` |
| `app/custom_leaderboard_routes.py:182,251,795,927,1057` (×5) | `build_user_info, preload_badge_cache` |
| `app/discovery_routes.py:20` | `get_current_user_optional, visible_forums` |
| `app/follow_routes.py:18` | `get_current_user_optional` |
| `app/routes/message_routes.py:385,471` (×2) | `visible_forums` |
| `app/scheduled_tasks.py:571` | `invalidate_forum_visibility_cache` |
| `app/services/ai_tools.py:949` | `assert_forum_visible` |
| `app/services/ai_tools.py:1193,1593` (×2) | `visible_forums` |
| `app/student_verification_routes.py:628,921` (×2) | `invalidate_forum_visibility_cache` |
| `app/trending_routes.py:92` | `get_current_user_optional` |
| `app/trending_routes.py:106` | `get_current_admin_async` |

All 7 unique names (`invalidate_forum_visibility_cache`, `build_user_info`, `preload_badge_cache`, `get_current_user_optional`, `visible_forums`, `assert_forum_visible`, `get_current_admin_async`) are in the helper set being preserved in `forum_routes.py`.

---

## Per-Commit Migration Procedure

Each migration commit (1-7) follows the same 8-step recipe. Steps shown once here, then referenced by number in each commit.

**Recipe:**

1. Create the new file `backend/app/routes/forum_<domain>_routes.py` with the standard scaffold (header + imports + `router = APIRouter()`).
2. For each route in the mapping table for this domain, locate its `@router.<verb>(...)` line in `forum_routes.py`. The route block extends from that line down through its complete function body, ending at (a) the next `@router` line, (b) the next module-level `def`/`async def`, or (c) end of file — whichever comes first.
3. **Cut** each route block (decorator + function body, including any blank lines immediately after) from `forum_routes.py` and **paste** into the new file. Preserve order.
4. The new file's import block should pull from `app.forum_routes` every helper / dependency referenced by the moved routes. Start with the explicit list given for that commit; add more if `python -c "from app.routes.forum_<domain>_routes import router"` fails with `NameError`.
5. In `main.py`, append a tuple `(forum_<domain>_routes.router, "论坛-<中文>")` to the `_FORUM_ROUTERS` list, and add the corresponding `from app.routes import forum_<domain>_routes` import.
6. Run the local gate (see "Per-Commit Local Gate" below). All 5 checks must pass.
7. `git add` the changed files and commit with message `refactor(forum): extract <domain> routes`.
8. `git push origin main`. Wait for Railway to deploy linktest, then run `bash backend/scripts/smoke_linktest.sh`. All probes must return expected codes.

**Per-Commit Local Gate (run before commit):**

```bash
# 1. Route diff: zero unexpected changes
python backend/scripts/dump_routes.py /tmp/routes_after.json
diff backend/scripts/routes_baseline.json /tmp/routes_after.json
# Expected: zero output (forum split is pure move)

# 2. Smoke tests
pytest backend/tests/test_routers_split_smoke.py -v
# Expected: all green

# 3. App boots
python -c "from app.main import app; print('ok')"
# Expected: 'ok'

# 4. External importer integrity
python -c "from app.custom_leaderboard_routes import *; from app.discovery_routes import *; from app.follow_routes import *; from app.admin_student_verification_routes import *; from app.routes.message_routes import *; from app.trending_routes import *; from app.services.ai_tools import *; from app.scheduled_tasks import *; from app.student_verification_routes import *; print('importers ok')"
# Expected: 'importers ok'

# 5. Full test suite
pytest backend/tests/
# Expected: all green (no new failures vs. baseline run before commit 0)
```

**Standard new-file scaffold:**

```python
"""
论坛<domain中文> routes — extracted from forum_routes.py (2026-04-26 split).

All helpers remain in app.forum_routes; this module imports them as needed.
"""
from typing import List, Optional
from datetime import datetime, timezone, timedelta
import json
import logging

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status, Request, Body
from sqlalchemy import select, func, or_, and_, desc, asc, case, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload, joinedload

from app import models, schemas
from app.deps import get_async_db_dependency
from app.database import get_db
from app.utils.time_utils import get_utc_time
from app.performance_monitor import measure_api_performance
from app.cache import cache_response

# Helpers from the original forum_routes module (stays as helper hub)
from app.forum_routes import (
    # ... domain-specific list, see each commit
)

logger = logging.getLogger(__name__)

router = APIRouter()
```

**Imports may need pruning.** If an import is unused in the new file, remove it (let Python compile-time errors and ruff guide). Don't leave dead imports.

---

## Tasks

### Task 0: Pre-flight Audit & Baseline

**Files:**
- Verify (read-only): `backend/app/forum_routes.py`, all importer files
- Modify: `backend/scripts/routes_baseline.json`, `backend/tests/test_routers_split_smoke.py`, `backend/scripts/smoke_linktest.sh`
- Modify: `backend/app/main.py` (add empty `_FORUM_ROUTERS` scaffold)

- [ ] **Step 1: Verify external importer audit matches plan**

```bash
grep -rn "from app.forum_routes import\|import app.forum_routes" backend/ --include="*.py"
```

Expected output: 19 lines (18 helper imports + `main.py:511` `forum_router`). If the count differs or any line imports something other than the 7 helpers listed in the External Importer Audit table, **stop** and update the plan before proceeding.

- [ ] **Step 2: Verify route count**

```bash
grep -cE "^@router\." backend/app/forum_routes.py
```

Expected: `64`. If different, the file has drifted since plan-write — re-map and update the route tables.

- [ ] **Step 3: Run full backend test suite as pre-baseline**

```bash
pytest backend/tests/ 2>&1 | tail -5
```

Record the pass/fail count. Subsequent commits must not regress this baseline.

- [ ] **Step 4: Regenerate routes baseline**

```bash
python backend/scripts/dump_routes.py backend/scripts/routes_baseline.json
```

Expected: file is overwritten with current full route inventory (sorted JSON).

- [ ] **Step 5: Add 7 forum smoke probes**

Open `backend/tests/test_routers_split_smoke.py` and append (after the existing PROBES or test functions — match the file's existing style):

```python
# Forum domain probes — added by 2026-04-26 forum_routes.py split.
# Each domain gets one probe to verify its router is mounted at /api/forum.

@pytest.mark.parametrize("path,expected_codes", [
    ("/api/forum/categories", {200, 401}),
    ("/api/forum/posts/1", {401, 404}),
    ("/api/forum/posts/1/replies", {401, 404}),
    ("/api/forum/likes", {401, 422, 405}),  # POST endpoint, GET should be 405
    ("/api/forum/my/posts", {401}),
    ("/api/forum/hot-posts", {200, 401}),
    ("/api/forum/admin/stats", {401, 403}),
])
def test_forum_route_registered(client, path, expected_codes):
    """Smoke probe — verify each forum domain router is mounted."""
    response = client.get(path)
    assert response.status_code in expected_codes, (
        f"GET {path} returned {response.status_code}, expected one of {expected_codes}"
    )
```

If `test_routers_split_smoke.py` uses a different probe style (e.g. a `PROBES` list), follow that style instead and add equivalent entries.

- [ ] **Step 6: Add forum probes to linktest smoke script**

Open `backend/scripts/smoke_linktest.sh` and append to the `PROBES` array (between the existing probes and the closing `)`):

```bash
  "GET /api/forum/categories 200|401 /api"
  "GET /api/forum/hot-posts 200|401 /api"
  "GET /api/forum/my/posts 401 /api"
  "GET /api/forum/admin/stats 401|403 /api"
  "GET /api/forum/leaderboard/posts 200|401 /api"
```

(Adjust delimiter / format to exactly match the existing `PROBES` entry format in the file.)

- [ ] **Step 7: Add empty `_FORUM_ROUTERS` scaffold to main.py**

Locate `main.py:511-512`:

```python
from app.forum_routes import router as forum_router
app.include_router(forum_router)
```

**Leave those two lines in place** (they keep working as routes peel off — empty router is harmless). **Add immediately after them:**

```python
# 2026-04-26 forum_routes.py split — sub-routers populated commit-by-commit.
# When _FORUM_ROUTERS reaches 7 entries (final commit), the legacy
# `forum_router` import + include_router two lines above are deleted.
_FORUM_ROUTERS: list[tuple] = []
for r, tag in _FORUM_ROUTERS:
    app.include_router(r, prefix="/api/forum", tags=[tag])
```

Use `list[tuple]` (not `list[tuple[APIRouter, str]]`) to avoid having to import APIRouter just for the annotation; the loop body works on any 2-tuple.

- [ ] **Step 8: Verify boot + tests + smoke still green (no behavioral change yet)**

```bash
python -c "from app.main import app; print('ok')"
pytest backend/tests/test_routers_split_smoke.py -v
python backend/scripts/dump_routes.py /tmp/routes_after.json
diff backend/scripts/routes_baseline.json /tmp/routes_after.json
```

Expected: all pass; diff is empty.

- [ ] **Step 9: Commit**

```bash
git add backend/scripts/routes_baseline.json backend/tests/test_routers_split_smoke.py backend/scripts/smoke_linktest.sh backend/app/main.py
git commit -m "$(cat <<'EOF'
chore(forum): regenerate route baseline + add forum smoke probes

Pre-flight for 8,345-line forum_routes.py split into 7 domain files.
- Regenerated routes_baseline.json (still 100% covers current routes)
- Added 7 forum probes to test_routers_split_smoke.py
- Added 5 forum curl probes to smoke_linktest.sh
- Scaffolded empty _FORUM_ROUTERS list in main.py for incremental population

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
```

- [ ] **Step 10: Confirm Railway deploys linktest, then run remote smoke**

```bash
bash backend/scripts/smoke_linktest.sh
```

Expected: all probes (existing + 5 new forum probes) return expected codes.

---

### Task 1: Extract `forum_my_routes.py` (5 routes — lowest risk)

**Files:**
- Create: `backend/app/routes/forum_my_routes.py`
- Modify: `backend/app/forum_routes.py` (delete 5 routes)
- Modify: `backend/app/main.py` (append 1 tuple to `_FORUM_ROUTERS` + 1 import line)

**Routes to move:** lines 5655, 6378, 6538, 6619, 6724 (see route table — `my/category-favorites`, `my/posts`, `my/replies`, `my/favorites`, `my/likes`).

**Helpers to import from `app.forum_routes`:** start with this set; add more if `NameError` on first import attempt:

```python
from app.forum_routes import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    visible_forums,
    build_user_info,
    preload_badge_cache,
    get_post_display_view_count,
    _batch_get_post_display_view_counts,
    _batch_get_user_liked_favorited_posts,
    _parse_attachments,
    strip_markdown,
)
```

- [ ] **Step 1: Create scaffold file `backend/app/routes/forum_my_routes.py`**

Use the standard scaffold from "Per-Commit Migration Procedure" with the import list above and `"""论坛-我的内容 routes — ..."""` docstring.

- [ ] **Step 2: Move 5 route blocks from `forum_routes.py` to new file**

For each line in [5655, 6378, 6538, 6619, 6724], cut the route block (decorator + body, ending at next `@router` or `def` at column 0) and paste into the new file. Preserve order in destination as 5655 → 6378 → 6538 → 6619 → 6724.

- [ ] **Step 3: Wire in `main.py`**

Add to imports section (with other `from app.routes import ...`):

```python
from app.routes import forum_my_routes
```

Update the `_FORUM_ROUTERS` list:

```python
_FORUM_ROUTERS: list[tuple] = [
    (forum_my_routes.router, "论坛-我的"),
]
```

- [ ] **Step 4: Run local gate (5 checks from Per-Commit Local Gate section)**

If any check fails:
- `NameError` in step 3 import test → add the missing name to forum_my_routes.py imports from forum_routes
- `dump_routes` diff non-empty → either a route was lost (path missing) or an extra route appeared — inspect diff and reconcile
- Smoke test failure → router not mounted at expected prefix; check main.py wiring

- [ ] **Step 5: Commit and push**

```bash
git add backend/app/routes/forum_my_routes.py backend/app/forum_routes.py backend/app/main.py
git commit -m "$(cat <<'EOF'
refactor(forum): extract my-content routes (5 endpoints)

Moves /my/posts, /my/replies, /my/favorites, /my/likes,
/my/category-favorites from forum_routes.py to
app/routes/forum_my_routes.py. Helpers stay in forum_routes.py;
new module imports them. main.py mounts via _FORUM_ROUTERS list.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
```

- [ ] **Step 6: Wait for Railway deploy + run linktest smoke**

```bash
bash backend/scripts/smoke_linktest.sh
```

Expected: all probes pass. If `/api/forum/my/posts` returns 404, the new router isn't mounted — `git revert HEAD && git push` immediately.

---

### Task 2: Extract `forum_replies_routes.py` (5 routes)

**Files:**
- Create: `backend/app/routes/forum_replies_routes.py`
- Modify: `backend/app/forum_routes.py` (delete 5 routes)
- Modify: `backend/app/main.py` (append 1 tuple + 1 import)

**Routes to move:** lines 4597, 4758, 5035, 5135, 5216 (`/posts/{id}/replies` GET+POST, `/replies/{id}` PUT+DELETE, `/replies/{id}/restore`).

**Helpers to import:**

```python
from app.forum_routes import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    get_current_admin_async,
    visible_forums,
    assert_forum_visible,
    require_student_verified,
    build_user_info,
    build_admin_user_info,
    get_reply_author_info,
    preload_badge_cache,
    get_post_with_permissions,
    log_admin_operation,
    check_and_trigger_risk_control,
    update_category_stats,
    get_user_language_preference,
    _bg_translate_post,
    _post_identity,
)
```

- [ ] **Step 1: Create scaffold** with imports above.

- [ ] **Step 2: Move 5 route blocks** from lines [4597, 4758, 5035, 5135, 5216].

- [ ] **Step 3: Wire in `main.py`**

```python
from app.routes import forum_my_routes, forum_replies_routes

_FORUM_ROUTERS: list[tuple] = [
    (forum_my_routes.router, "论坛-我的"),
    (forum_replies_routes.router, "论坛-回复"),
]
```

- [ ] **Step 4: Run local gate (5 checks).** Reconcile NameErrors / diff anomalies as in Task 1.

- [ ] **Step 5: Commit and push**

```bash
git add backend/app/routes/forum_replies_routes.py backend/app/forum_routes.py backend/app/main.py
git commit -m "$(cat <<'EOF'
refactor(forum): extract reply routes (5 endpoints)

Moves /posts/{id}/replies (GET+POST), /replies/{id} (PUT+DELETE),
/replies/{id}/restore from forum_routes.py to
app/routes/forum_replies_routes.py.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
```

- [ ] **Step 6: Wait for deploy + linktest smoke.**

---

### Task 3: Extract `forum_interactions_routes.py` (7 routes)

**Files:**
- Create: `backend/app/routes/forum_interactions_routes.py`
- Modify: `backend/app/forum_routes.py` (delete 7 routes)
- Modify: `backend/app/main.py` (append 1 tuple + 1 import)

**Routes to move:** lines 5285, 5373, 5434, 5497, 5553, 5604, 5627 (likes, post likes, reply likes, favorites, category favorite, category favorite status, category favorites batch).

**Helpers to import:**

```python
from app.forum_routes import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    visible_forums,
    assert_forum_visible,
    require_student_verified,
    build_user_info,
    preload_badge_cache,
    get_post_with_permissions,
    update_category_stats,
)
```

- [ ] **Step 1: Create scaffold.**
- [ ] **Step 2: Move 7 route blocks** from lines [5285, 5373, 5434, 5497, 5553, 5604, 5627].
- [ ] **Step 3: Wire in `main.py`** (append `(forum_interactions_routes.router, "论坛-互动")` to list, add import).
- [ ] **Step 4: Run local gate.**
- [ ] **Step 5: Commit:** `refactor(forum): extract interaction routes (7 endpoints — likes + favorites)`. Push.
- [ ] **Step 6: Wait for deploy + linktest smoke.**

---

### Task 4: Extract `forum_admin_routes.py` (8 routes)

**Files:**
- Create: `backend/app/routes/forum_admin_routes.py`
- Modify: `backend/app/forum_routes.py` (delete 8 routes)
- Modify: `backend/app/main.py` (append 1 tuple + 1 import)

**Routes to move:** lines 5872, 5972, 6021, 6864, 6928, 7082, 7125, 7144 (`/reports` POST+GET, `/admin/reports/{id}/process`, `/admin/operation-logs`, `/admin/stats`, `/admin/categories`, `/admin/pending-requests/count`, `/admin/fix-statistics`).

**Helpers to import:**

```python
from app.forum_routes import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    get_current_admin_async,
    visible_forums,
    build_user_info,
    build_admin_user_info,
    preload_badge_cache,
    log_admin_operation,
    invalidate_forum_visibility_cache,
    clear_all_forum_visibility_cache,
    update_category_stats,
)
```

- [ ] **Step 1: Create scaffold.**
- [ ] **Step 2: Move 8 route blocks** from lines [5872, 5972, 6021, 6864, 6928, 7082, 7125, 7144].
- [ ] **Step 3: Wire in `main.py`** (append `(forum_admin_routes.router, "论坛-管理")`).
- [ ] **Step 4: Run local gate.** Pay extra attention to `/reports` POST since user-side report submission goes through here despite the file name.
- [ ] **Step 5: Commit:** `refactor(forum): extract admin + report routes (8 endpoints)`. Push.
- [ ] **Step 6: Wait for deploy + linktest smoke.**

---

### Task 5: Extract `forum_discovery_routes.py` (13 routes)

**Files:**
- Create: `backend/app/routes/forum_discovery_routes.py`
- Modify: `backend/app/forum_routes.py` (delete 13 routes)
- Modify: `backend/app/main.py` (append 1 tuple + 1 import)

**Routes to move:** lines 5713, 6084, 6227, 6254, 6281, 7213, 7377, 7446, 7597, 7663, 7730, 7901, 8191 (search, notifications×4, hot-posts, user stats, user hot-posts, leaderboard×3, search-linkable, linkable-for-user).

**Helpers to import:**

```python
from app.forum_routes import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    visible_forums,
    assert_forum_visible,
    build_user_info,
    preload_badge_cache,
    get_post_display_view_count,
    _batch_get_post_display_view_counts,
    _batch_get_user_liked_favorited_posts,
    _batch_get_users_by_ids_async,
    _parse_attachments,
    strip_markdown,
    get_user_language_preference,
    _resolve_linked_item_name,
    create_latest_post_info,
)
```

- [ ] **Step 1: Create scaffold.**
- [ ] **Step 2: Move 13 route blocks** in the order they appear in `forum_routes.py` (5713, 6084, 6227, 6254, 6281, 7213, 7377, 7446, 7597, 7663, 7730, 7901, 8191).
- [ ] **Step 3: Wire in `main.py`** (append `(forum_discovery_routes.router, "论坛-发现")`).
- [ ] **Step 4: Run local gate.** This is the largest commit so far (13 routes); expect to iterate on imports if first try has `NameError`.
- [ ] **Step 5: Commit:** `refactor(forum): extract discovery routes (13 endpoints — search + leaderboard + notifications)`. Push.
- [ ] **Step 6: Wait for deploy + linktest smoke.**

---

### Task 6: Extract `forum_categories_routes.py` (12 routes)

**Files:**
- Create: `backend/app/routes/forum_categories_routes.py`
- Modify: `backend/app/forum_routes.py` (delete 12 routes; **interleaved helpers at lines 2639, 2655, 2685, 2715 STAY**)
- Modify: `backend/app/main.py` (append 1 tuple + 1 import)

**Routes to move:** lines 1313, 1717, 1811, 1919, 1999, 2053, 2243, 2316, 2429, 2593, 2745, 7815.

**⚠ Interleaved-helpers caveat:** Between routes 2593 and 2745 there are 4 module-level helpers at lines 2639 (`_parse_json_field`), 2655 (`_post_to_feed_data`), 2685 (`_task_to_feed_data`), 2715 (`_service_to_feed_data`). When moving the 2593 route block, **stop the cut at line 2638** (before `def _parse_json_field`). When moving the 2745 route block, **start the cut at line 2745** (skip the helpers above). Helpers stay; new file imports them.

**Helpers to import:**

```python
from app.forum_routes import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    get_current_admin_async,
    visible_forums,
    assert_forum_visible,
    require_student_verified,
    is_uk_university,
    invalidate_forum_visibility_cache,
    clear_all_forum_visibility_cache,
    check_forum_visibility,
    build_user_info,
    build_admin_user_info,
    preload_badge_cache,
    log_admin_operation,
    update_category_stats,
    create_latest_post_info,
    _batch_get_category_post_counts_and_latest_posts,
    _post_to_feed_data,
    _task_to_feed_data,
    _service_to_feed_data,
    _parse_json_field,
    _resolve_linked_item_name,
    get_user_language_preference,
)
```

- [ ] **Step 1: Create scaffold.**
- [ ] **Step 2: Move 12 route blocks** in order (1313, 1717, 1811, 1919, 1999, 2053, 2243, 2316, 2429, 2593, 2745, 7815). **Re-verify** the 2593 cut stops at 2638 and the 2745 cut starts at 2745 (interleaved helpers preserved in original file).
- [ ] **Step 3: Wire in `main.py`** (append `(forum_categories_routes.router, "论坛-板块")`).
- [ ] **Step 4: Run local gate.** Particularly verify the 4 interleaved helpers still exist in `forum_routes.py`:

```bash
grep -nE "^def _(parse_json_field|post_to_feed_data|task_to_feed_data|service_to_feed_data)" backend/app/forum_routes.py
```

Expected: 4 lines, all with line numbers in the range that originally held them (will shift downward as routes above are deleted).

- [ ] **Step 5: Commit:** `refactor(forum): extract category routes (12 endpoints)`. Push.
- [ ] **Step 6: Wait for deploy + linktest smoke.**

---

### Task 7: Extract `forum_posts_routes.py` (14 routes) + remove legacy `forum_router`

**Files:**
- Create: `backend/app/routes/forum_posts_routes.py`
- Modify: `backend/app/forum_routes.py` (delete 14 routes; delete `router = APIRouter(prefix="/api/forum", tags=["论坛"])` line; rewrite docstring)
- Modify: `backend/app/main.py` (append final tuple; delete legacy `forum_router` import + include_router)

**Routes to move:** lines 2879, 3082, 3212, 3622, 3936, 4020, 4098, 4165, 4243, 4310, 4377, 4444, 4495, 4545.

**Helpers to import:**

```python
from app.forum_routes import (
    get_current_user_secure_async_csrf,
    get_current_user_optional,
    get_current_admin_async,
    visible_forums,
    assert_forum_visible,
    require_student_verified,
    build_user_info,
    build_admin_user_info,
    preload_badge_cache,
    get_post_author_info,
    get_post_with_permissions,
    get_post_display_view_count,
    _batch_get_post_display_view_counts,
    _batch_get_user_liked_favorited_posts,
    _batch_get_users_by_ids_async,
    _parse_attachments,
    _resolve_linked_item_name,
    strip_markdown,
    create_latest_post_info,
    log_admin_operation,
    check_and_trigger_risk_control,
    update_category_stats,
    get_user_language_preference,
    _bg_translate_post,
    _post_identity,
)
```

- [ ] **Step 1: Create scaffold.**

- [ ] **Step 2: Move 14 route blocks** in order (2879, 3082, 3212, 3622, 3936, 4020, 4098, 4165, 4243, 4310, 4377, 4444, 4495, 4545).

- [ ] **Step 3: Verify zero `@router.` decorators remain in `forum_routes.py`**

```bash
grep -cE "^@router\." backend/app/forum_routes.py
```

Expected: `0`.

- [ ] **Step 4: Delete the legacy `router = APIRouter(...)` line in `forum_routes.py`**

```bash
grep -n "^router = APIRouter" backend/app/forum_routes.py
```

Expected: 1 line. Delete that line and the surrounding `from fastapi import APIRouter` if no longer used (run `python -c "import app.forum_routes"` to verify).

- [ ] **Step 5: Update `forum_routes.py` docstring**

Replace the top docstring (currently `"""论坛功能路由\n实现论坛板块、帖子、回复、点赞、收藏、搜索、通知、举报等功能\n"""`) with:

```python
"""
Shared helpers for forum route modules (extraction completed 2026-04-26).

Routes have been migrated to:
  - app/routes/forum_categories_routes.py
  - app/routes/forum_posts_routes.py
  - app/routes/forum_replies_routes.py
  - app/routes/forum_interactions_routes.py
  - app/routes/forum_my_routes.py
  - app/routes/forum_discovery_routes.py
  - app/routes/forum_admin_routes.py

This module retains 30+ module-level helpers (visible_forums,
build_user_info, preload_badge_cache, invalidate_forum_visibility_cache,
assert_forum_visible, get_current_user_optional, get_current_admin_async,
batch query helpers, etc.) which are imported by the route modules above
and by 18 external call-sites across the backend.

Do not add new routes here. If you need a new endpoint, create it in the
appropriate app/routes/forum_*_routes.py.

See docs/superpowers/specs/2026-04-26-forum-routes-split-design.md
"""
```

- [ ] **Step 6: Wire in `main.py` and remove legacy mount**

Add the final entry:

```python
from app.routes import (
    forum_my_routes,
    forum_replies_routes,
    forum_interactions_routes,
    forum_admin_routes,
    forum_discovery_routes,
    forum_categories_routes,
    forum_posts_routes,
)

_FORUM_ROUTERS: list[tuple] = [
    (forum_my_routes.router, "论坛-我的"),
    (forum_replies_routes.router, "论坛-回复"),
    (forum_interactions_routes.router, "论坛-互动"),
    (forum_admin_routes.router, "论坛-管理"),
    (forum_discovery_routes.router, "论坛-发现"),
    (forum_categories_routes.router, "论坛-板块"),
    (forum_posts_routes.router, "论坛-帖子"),
]
for r, tag in _FORUM_ROUTERS:
    app.include_router(r, prefix="/api/forum", tags=[tag])
```

**Delete** the legacy two lines:

```python
from app.forum_routes import router as forum_router  # DELETE
app.include_router(forum_router)                      # DELETE
```

- [ ] **Step 7: Run local gate (all 5 checks)**

Particularly verify:
```bash
python -c "from app.main import app; print(sum(1 for r in app.routes if hasattr(r, 'path') and r.path.startswith('/api/forum/')))"
```
Expected: `64` (every original forum route is reachable at `/api/forum/...`).

- [ ] **Step 8: Verify forum_routes.py final size**

```bash
wc -l backend/app/forum_routes.py
```

Expected: 1,200-1,500 lines (down from 8,345). If significantly outside this range, investigate — too low means helpers were accidentally removed; too high means routes weren't fully cut.

- [ ] **Step 9: Commit and push**

```bash
git add backend/app/routes/forum_posts_routes.py backend/app/forum_routes.py backend/app/main.py
git commit -m "$(cat <<'EOF'
refactor(forum): extract post routes + remove legacy forum_router

Moves the final 14 routes (post CRUD + pin/feature/lock/hide/restore)
to app/routes/forum_posts_routes.py, completing the 7-file split
of the original 8,345-line forum_routes.py.

forum_routes.py is now a helper-only module (~1,400 lines) preserving
all 30+ helpers used by the new route files and 18 external importers.
The legacy `forum_router` import + include_router in main.py are removed;
all forum endpoints are now mounted via the _FORUM_ROUTERS list.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git push origin main
```

- [ ] **Step 10: Wait for Railway deploy + run final linktest smoke**

```bash
bash backend/scripts/smoke_linktest.sh
```

Expected: all 5 forum probes (and all pre-existing probes) pass.

- [ ] **Step 11: Final verification — Flutter app sanity check**

In the link2ur Flutter app pointed at `linktest`, manually verify:
1. Open the forum tab — categories list loads
2. Tap into a category — posts list loads
3. Tap a post — detail loads with replies
4. Like a post — like count increments
5. Search for a keyword — results return
6. Open `我的` tab → my posts/replies/favorites — all load

Any 404 or 500 → `git revert HEAD && git push` immediately, then investigate.

---

## Success Criteria (verify after Task 7)

- [ ] `wc -l backend/app/forum_routes.py` shows 1,200-1,500 lines
- [ ] `ls backend/app/routes/forum_*_routes.py | wc -l` shows `7`
- [ ] `python backend/scripts/dump_routes.py /tmp/r.json && diff backend/scripts/routes_baseline.json /tmp/r.json` produces zero output
- [ ] `pytest backend/tests/test_routers_split_smoke.py -v` is all green
- [ ] `pytest backend/tests/` passes the same set as the pre-baseline run from Task 0 Step 3
- [ ] `grep -c "^@router\." backend/app/forum_routes.py` returns `0`
- [ ] `grep -c "from app.forum_routes import router" backend/app/main.py` returns `0`
- [ ] All 18 external importers from the audit table successfully import (covered by gate check 4)
- [ ] Linktest deployment is green and `bash backend/scripts/smoke_linktest.sh` passes
- [ ] Flutter forum tab manually verified against linktest backend

---

## Rollback Procedure

Each commit is independent. To roll back any commit after push:

```bash
git revert <sha>
git push origin main
```

Railway auto-deploys the revert. Each commit is a single git operation that simultaneously (a) creates / appends to the new file and (b) deletes the corresponding lines from `forum_routes.py` and (c) updates `main.py`. `git revert` undoes all three atomically — the moved routes return to `forum_routes.py`, the new file's additions are removed, and `_FORUM_ROUTERS` shrinks by one entry. The legacy `forum_router` mount in `main.py` (still present until Task 7) keeps serving the resurrected routes.

To abort the entire migration mid-way: `git revert <oldest-sha>..HEAD && git push`.

---

## Out-of-Scope Reminders

- Helper reorganization (down-sinking helpers from forum_routes.py) — separate future refactor
- `task_chat_routes.py` (6,244 lines), `flea_market_routes.py` (4,758 lines), `schemas.py`, `models.py` — separate future refactors
- Changing any route's URL, response shape, or auth dependency — strictly forbidden in this refactor
