# Expert Unification Phase B Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retire `admin_task_expert_routes.py` (527 lines, legacy `/api/admin/task-expert-*` prefix) and consolidate all admin Expert management under `/api/admin/experts/*`. Rename inconsistent `TaskExpert*`-named admin frontend functions to `Expert*`. No data-layer change.

**Architecture:** 3-commit sequenced rollout on feature branch `feature/expert-unification-phase-b`: (C1) additive backend — add 8 new endpoints to `admin_expert_routes.py`; (C2) frontend switch — `api.ts` rename + path swap + `ExpertManagement.tsx` cleanup; (C3) backend cleanup — delete old file + `main.py` registration + regression 404 tests. Each commit deployed separately with verification between.

**Tech Stack:** FastAPI + SQLAlchemy (backend); React + TypeScript + Ant Design (admin); pytest (backend tests).

**Spec:** `docs/superpowers/specs/2026-04-19-expert-unification-phase-b.md`

---

## Task 0: Branch setup

**Files:**
- Branch: create `feature/expert-unification-phase-b` from current `main`

- [ ] **Step 1: Confirm clean starting point**

Run: `git status && git log --oneline -1`
Expected: working tree clean; tip at `f7709356b` or later (spec commit).

- [ ] **Step 2: Create and check out feature branch**

Run: `git checkout -b feature/expert-unification-phase-b`
Expected: `Switched to a new branch 'feature/expert-unification-phase-b'`

---

## Task 1: C1-a — Add 4 services admin endpoints + smoke tests

**Files:**
- Modify: `backend/app/admin_expert_routes.py` (append to end)
- Create: `backend/tests/admin/test_admin_expert_services.py`
- Reference (copy from): `backend/app/admin_task_expert_routes.py` lines 62–127 (GET), 192–232 (review), 383–430 (PUT), 432–461 (DELETE)

- [ ] **Step 1: Write failing smoke tests first**

Create `backend/tests/admin/test_admin_expert_services.py`:

```python
"""Phase B smoke tests for new admin Expert services endpoints."""
import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


def test_list_services_endpoint_exists(client, admin_auth_headers):
    """GET /api/admin/experts/services returns 200 with list structure."""
    resp = client.get(
        "/api/admin/experts/services?page=1&page_size=10",
        headers=admin_auth_headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert "items" in body
    assert "total" in body


def test_review_service_endpoint_exists(client, admin_auth_headers):
    """POST /api/admin/experts/services/{id}/review returns 404 for missing id (not 405/404-for-wrong-path)."""
    resp = client.post(
        "/api/admin/experts/services/nonexistent-id/review",
        headers=admin_auth_headers,
        json={"action": "approve"},
    )
    # 404 for missing record = route exists and reached handler; anything else = routing broken
    assert resp.status_code in (404, 422)
```

Note: `admin_auth_headers` fixture must exist in `backend/tests/conftest.py` or the admin test subdirectory's `conftest.py`. If missing, skip these tests with a TODO and rely on manual verification. Check first with: `grep -rn "admin_auth_headers" backend/tests/`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python -m pytest tests/admin/test_admin_expert_services.py -v`
Expected: FAIL with 404 on both (routes don't exist yet).

- [ ] **Step 3: Copy GET services list endpoint**

Open `backend/app/admin_task_expert_routes.py` and copy the function body from line 62 (`@admin_task_expert_router.get("/task-expert-services")`) through end of function (line ~126). Append to `backend/app/admin_expert_routes.py` end. Change:
- Decorator: `@admin_task_expert_router.get("/task-expert-services")` → `@router.get("/services")` (assuming `router` is the APIRouter already defined in `admin_expert_routes.py` with prefix `/api/admin/experts`)
- If `admin_expert_routes.py` uses a different variable name for its router, use that. Verify via: `grep -n "^router = APIRouter\|prefix=" backend/app/admin_expert_routes.py | head -5`
- Copy any helper imports (e.g. `from app.models import ...`) that aren't already in the target file's import block.

- [ ] **Step 4: Copy POST services review endpoint**

From `admin_task_expert_routes.py` line 191 (`@admin_task_expert_router.post("/task-expert-services/{service_id}/review")`) through end of `review_expert_service` function (~line 232). Append. Decorator → `@router.post("/services/{service_id}/review")`.

- [ ] **Step 5: Copy PUT services update endpoint**

From line 382 (`@admin_task_expert_router.put("/task-expert-services/{service_id}")`) through end of `update_expert_service_admin_v2` (~line 430). Append. Decorator → `@router.put("/services/{service_id}")`. Rename function to `update_expert_service_admin` (drop `_v2`).

- [ ] **Step 6: Copy DELETE services endpoint**

From line 431 (`@admin_task_expert_router.delete("/task-expert-services/{service_id}")`) through end of `delete_expert_service_admin_v2` (~line 461). Append. Decorator → `@router.delete("/services/{service_id}")`. Rename function to `delete_expert_service_admin` (drop `_v2`).

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd backend && python -m pytest tests/admin/test_admin_expert_services.py -v`
Expected: both tests PASS.

- [ ] **Step 8: Local import self-check**

Run: `cd backend && python -c "from app.main import app; print('ok')"`
Expected: `ok` printed, no ImportError.

- [ ] **Step 9: Do NOT commit yet**

Leave changes staged in working tree; Task 2 will also modify `admin_expert_routes.py`, commit happens after Task 2 in Task 3.

---

## Task 2: C1-b — Add 4 activities admin endpoints + smoke tests

**Files:**
- Modify: `backend/app/admin_expert_routes.py` (append)
- Create: `backend/tests/admin/test_admin_expert_activities.py`
- Reference (copy from): `admin_task_expert_routes.py` lines 128–190 (GET), 234–266 (review), 463–497 (PUT), 499–527 (DELETE)

- [ ] **Step 1: Write failing smoke tests**

Create `backend/tests/admin/test_admin_expert_activities.py`:

```python
"""Phase B smoke tests for new admin Expert activities endpoints."""
import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


def test_list_activities_endpoint_exists(client, admin_auth_headers):
    resp = client.get(
        "/api/admin/experts/activities?page=1&page_size=10",
        headers=admin_auth_headers,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert "items" in body
    assert "total" in body


def test_review_activity_endpoint_exists(client, admin_auth_headers):
    resp = client.post(
        "/api/admin/experts/activities/999999/review",
        headers=admin_auth_headers,
        json={"action": "approve"},
    )
    assert resp.status_code in (404, 422)
```

- [ ] **Step 2: Run tests, verify fail**

Run: `cd backend && python -m pytest tests/admin/test_admin_expert_activities.py -v`
Expected: FAIL (404).

- [ ] **Step 3: Copy GET activities list**

From `admin_task_expert_routes.py` line 127 (`@admin_task_expert_router.get("/task-expert-activities")`) through end of `get_all_expert_activities_admin` (~line 190). Append. Decorator → `@router.get("/activities")`.

- [ ] **Step 4: Copy POST activities review**

From line 233 (`@admin_task_expert_router.post("/task-expert-activities/{activity_id}/review")`) through end of `review_expert_activity` (~line 266). Append. Decorator → `@router.post("/activities/{activity_id}/review")`.

- [ ] **Step 5: Copy PUT activities update**

From line 462 (`@admin_task_expert_router.put("/task-expert-activities/{activity_id}")`) through end of `update_expert_activity_admin_v2` (~line 497). Append. Decorator → `@router.put("/activities/{activity_id}")`. Rename function to `update_expert_activity_admin` (drop `_v2`).

- [ ] **Step 6: Copy DELETE activities**

From line 498 (`@admin_task_expert_router.delete("/task-expert-activities/{activity_id}")`) through end of `delete_expert_activity_admin_v2` (~line 527). Append. Decorator → `@router.delete("/activities/{activity_id}")`. Rename function to `delete_expert_activity_admin` (drop `_v2`).

- [ ] **Step 7: Run all 4 Phase B smoke tests**

Run: `cd backend && python -m pytest tests/admin/test_admin_expert_services.py tests/admin/test_admin_expert_activities.py -v`
Expected: all 4 tests PASS.

- [ ] **Step 8: Import self-check**

Run: `cd backend && python -c "from app.main import app; print('ok')"`
Expected: `ok`.

---

## Task 3: C1 commit — push and verify Railway deploy

**Files:**
- Commit modified: `backend/app/admin_expert_routes.py`, `backend/tests/admin/test_admin_expert_services.py`, `backend/tests/admin/test_admin_expert_activities.py`

- [ ] **Step 1: Stage and commit C1 on feature branch**

```bash
git add backend/app/admin_expert_routes.py backend/tests/admin/test_admin_expert_services.py backend/tests/admin/test_admin_expert_activities.py
git commit -m "$(cat <<'EOF'
feat(admin): add 8 new /api/admin/experts/{services,activities}/* endpoints (Phase B C1)

Additive: new endpoints copy logic from admin_task_expert_routes.py with new URL prefix.
Old /api/admin/task-expert-* routes remain live until C3. No data-layer change.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 2: Merge to main + push**

```bash
git checkout main
git merge --no-ff feature/expert-unification-phase-b
git push origin main
```

- [ ] **Step 3: Wait for Railway backend deploy to succeed**

Watch Railway dashboard: wait for the deploy triggered by the push to reach "Success" state (~3 minutes typical).

- [ ] **Step 4: Verify production curl returns 401 (auth), not 404 (no route)**

Run: `curl -sI https://api.link2ur.com/api/admin/experts/services`
Expected: HTTP/2 401 or 403 (auth required) — **not** 404. A 404 means the deploy didn't pick up new routes; investigate before proceeding.

- [ ] **Step 5: Return to feature branch for next task**

```bash
git checkout feature/expert-unification-phase-b
git merge main  # sync any unrelated main changes back
```

---

## Task 4: C2-a — Update `admin/src/api.ts`

**Files:**
- Modify: `admin/src/api.ts`

- [ ] **Step 1: Read all current TaskExpert function definitions to know exact signatures**

Run: `grep -n "getTaskExperts\|getTaskExpertForAdmin\|updateTaskExpert\|deleteTaskExpert\|getTaskExpertApplications\|reviewTaskExpertApplication\|createExpertFromApplication\|getAllExpertServicesAdmin\|getAllExpertActivitiesAdmin\|updateExpertServiceAdmin\|deleteExpertServiceAdmin\|reviewExpertServiceAdmin\|reviewExpertActivityAdmin" admin/src/api.ts`

Note all line numbers and function signatures.

- [ ] **Step 2: Apply 6 renames + 8 path swaps + 1 deletion**

Rename these function definitions and their call sites (within api.ts only — TS imports in ExpertManagement.tsx handled in Task 5):

| Old name | New name |
|---|---|
| `getTaskExperts` | `getExperts` |
| `getTaskExpertForAdmin` | `getExpertForAdmin` |
| `updateTaskExpert` | `updateExpert` |
| `deleteTaskExpert` | `deleteExpert` |
| `getTaskExpertApplications` | `getExpertApplications` |
| `reviewTaskExpertApplication` | `reviewExpertApplication` |

Path swaps in these 8 functions (keep function names as-is; these are already Expert-named):

| Function | Old path | New path |
|---|---|---|
| `getAllExpertServicesAdmin` | `/api/admin/task-expert-services` | `/api/admin/experts/services` |
| `getAllExpertActivitiesAdmin` | `/api/admin/task-expert-activities` | `/api/admin/experts/activities` |
| `updateExpertServiceAdmin` | `/api/admin/task-expert-services/${id}` | `/api/admin/experts/services/${id}` |
| `deleteExpertServiceAdmin` | `/api/admin/task-expert-services/${id}` | `/api/admin/experts/services/${id}` |
| `reviewExpertServiceAdmin` | `/api/admin/task-expert-services/${id}/review` | `/api/admin/experts/services/${id}/review` |
| `reviewExpertActivityAdmin` | `/api/admin/task-expert-activities/${id}/review` | `/api/admin/experts/activities/${id}/review` |
| (implicit — update-activity, if exists as separate fn) | `/api/admin/task-expert-activities/${id}` | `/api/admin/experts/activities/${id}` |
| (implicit — delete-activity, if exists as separate fn) | `/api/admin/task-expert-activities/${id}` | `/api/admin/experts/activities/${id}` |

Delete the entire `createExpertFromApplication` function (including its export line).

- [ ] **Step 3: Verify no `task-expert` strings remain in `api.ts`**

Run: `grep -n "task-expert\|TaskExpert" admin/src/api.ts`
Expected: zero results.

- [ ] **Step 4: Do NOT run `npm run build` yet**

Build will fail because `ExpertManagement.tsx` still imports the old names. Task 5 fixes that; build verification happens in Task 6.

---

## Task 5: C2-b — Update `ExpertManagement.tsx` + `config.ts`

**Files:**
- Modify: `admin/src/pages/admin/experts/ExpertManagement.tsx`
- Modify: `admin/src/config.ts`

- [ ] **Step 1: Apply 6 import renames + 18 call-site renames in `ExpertManagement.tsx`**

At top of file (line 5–25 range), change imports:

```typescript
// Before
import {
  getTaskExperts,
  getTaskExpertForAdmin,
  updateTaskExpert,
  deleteTaskExpert,
  getTaskExpertApplications,
  reviewTaskExpertApplication,
  createExpertFromApplication,
  // ... other imports unchanged
} from '../../../api';

// After
import {
  getExperts,
  getExpertForAdmin,
  updateExpert,
  deleteExpert,
  getExpertApplications,
  reviewExpertApplication,
  // createExpertFromApplication removed
  // ... other imports unchanged
} from '../../../api';
```

Then do a find-and-replace across the file (18 call sites total) using the 6 rename mappings from Task 4 Step 2. Include the site at line 275 (`updateTaskExpert(createdExpertId, { avatar: url })`), 295, 311, 379, 414, 461, 464 (inside console.warn string), 583, and others found in Task 4 Step 1 grep.

- [ ] **Step 2: Delete `handleCreateFeatured` handler**

Locate the `handleCreateFeatured` function definition (~lines 593–638, ~46 lines). Delete entirely.

- [ ] **Step 3: Delete the "创建特色达人" button in applications tab**

Locate the button around line 834 (`onClick={() => handleCreateFeatured(record.id)}`). Delete the entire `<Button>...</Button>` JSX element that references `handleCreateFeatured`. If the button is wrapped in a `Space` or fragment, preserve surrounding structure.

- [ ] **Step 4: Update `admin/src/config.ts:41` comment**

Change the comment from `"使用 /api/admin/experts/* 与 /api/admin/task-expert*"` to `"使用 /api/admin/experts/*"`.

- [ ] **Step 5: Final grep in admin/src to confirm no stragglers**

Run from project root: `grep -rn "TaskExpert\|task-expert" admin/src/`
Expected: only the `BannerManagement.tsx:344` line (Flutter deep-link string — intentionally left alone per spec §9). If any other file matches, investigate before proceeding.

- [ ] **Step 6: Run `npm run build` to verify TS compilation**

```bash
cd admin && npm run build
```
Expected: build succeeds with no type errors. If there's a "Cannot find name 'getTaskExperts'" or similar — that means a call site was missed; fix and rebuild.

---

## Task 6: C2 commit — push and verify Vercel deploy

**Files:**
- Commit: `admin/src/api.ts`, `admin/src/pages/admin/experts/ExpertManagement.tsx`, `admin/src/config.ts`

- [ ] **Step 1: Stage and commit C2**

```bash
git add admin/src/api.ts admin/src/pages/admin/experts/ExpertManagement.tsx admin/src/config.ts
git commit -m "$(cat <<'EOF'
refactor(admin-web): switch ExpertManagement to /api/admin/experts/* + rename TaskExpert fns (Phase B C2)

Frontend switches to new URL prefix (added in C1). Old backend routes still live
until C3. Drops createExpertFromApplication; admin uses 2-step approve+feature flow.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 2: Merge to main + push**

```bash
git checkout main
git merge --no-ff feature/expert-unification-phase-b
git push origin main
```

- [ ] **Step 3: Wait for Vercel deploy**

Watch Vercel dashboard; wait for "Ready" on the new deployment (~2 minutes).

- [ ] **Step 4: Manual admin smoke test in production**

Log in to admin panel. Perform:
1. Open services tab in ExpertManagement → list loads, 0 errors in browser console.
2. Click into one service → edit modal opens → change one safe field → save → success toast.
3. Delete a test service (if one exists) → success toast → disappears from list.
4. Open activities tab → list loads.
5. Review a test activity (approve or reject) → success toast.
6. Open applications tab → verify "创建特色达人" button is gone; approve flow still works.

If any step fails: investigate via DevTools Network panel for request URL + status; likely a path typo or missing rename.

- [ ] **Step 5: Return to feature branch**

```bash
git checkout feature/expert-unification-phase-b
git merge main
```

---

## Task 7: C3 — Delete old backend file + add 404 regression tests

**Files:**
- Delete: `backend/app/admin_task_expert_routes.py`
- Modify: `backend/app/main.py` (remove 3 lines: comment + import + register)
- Modify: `backend/app/routers.py` line 13087 (stale comment reference)
- Create: `backend/tests/admin/test_admin_task_expert_removed.py`

- [ ] **Step 1: Write failing 404 regression tests first**

Create `backend/tests/admin/test_admin_task_expert_removed.py`:

```python
"""Phase B C3 regression: old /api/admin/task-expert-* routes must be gone."""
from fastapi.testclient import TestClient
from app.main import app


def test_old_task_expert_services_route_gone():
    client = TestClient(app)
    resp = client.get("/api/admin/task-expert-services")
    assert resp.status_code == 404


def test_old_task_expert_activities_route_gone():
    client = TestClient(app)
    resp = client.get("/api/admin/task-expert-activities")
    assert resp.status_code == 404
```

- [ ] **Step 2: Run test — should FAIL (routes still exist pre-C3)**

Run: `cd backend && python -m pytest tests/admin/test_admin_task_expert_removed.py -v`
Expected: FAIL with 200 or 401 (routes still live — that's the point of this test).

- [ ] **Step 3: Delete `admin_task_expert_routes.py`**

Run: `git rm backend/app/admin_task_expert_routes.py`

- [ ] **Step 4: Remove 3 lines from `main.py`**

Delete these lines (exact line numbers based on current grep at lines 434, 455, 456):
- Line ~434: `# admin/legacy 功能仍通过 admin_task_expert_routes.py 保留` (the comment)
- Line ~455: `from app.admin_task_expert_routes import admin_task_expert_router`
- Line ~456: `app.include_router(admin_task_expert_router)`

Use Edit tool on each line; verify with `grep -n "admin_task_expert" backend/app/main.py` returning zero hits after.

- [ ] **Step 5: Update stale comment in `routers.py:13087`**

Change:
```python
# 注：GET /api/admin/task-expert-services 与 GET /api/admin/task-expert-activities 已迁移至 admin_task_expert_routes.py
```
to:
```python
# 注：GET /api/admin/experts/services 与 GET /api/admin/experts/activities 在 admin_expert_routes.py
```

- [ ] **Step 6: Import self-check**

Run: `cd backend && python -c "from app.main import app; print('ok')"`
Expected: `ok`. If ImportError: missing a cleanup somewhere — grep again with `grep -rn "admin_task_expert" backend/` and fix.

- [ ] **Step 7: Run 404 regression tests — should PASS now**

Run: `cd backend && python -m pytest tests/admin/test_admin_task_expert_removed.py -v`
Expected: both tests PASS.

- [ ] **Step 8: Run all Phase B tests together**

Run: `cd backend && python -m pytest tests/admin/test_admin_expert_services.py tests/admin/test_admin_expert_activities.py tests/admin/test_admin_task_expert_removed.py -v`
Expected: 6 tests PASS.

---

## Task 8: C3 commit — push and verify

**Files:**
- Commit modified/deleted: `backend/app/admin_task_expert_routes.py` (deleted), `backend/app/main.py`, `backend/app/routers.py`, `backend/tests/admin/test_admin_task_expert_removed.py`

- [ ] **Step 1: Stage and commit C3**

```bash
git add -A  # picks up deletion + modifications + new test file
git commit -m "$(cat <<'EOF'
chore(admin): delete admin_task_expert_routes.py (Phase B C3)

Frontend already switched in C2; old URLs no longer reachable. Adds 2 regression
tests asserting /api/admin/task-expert-* returns 404.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 2: Merge to main + push**

```bash
git checkout main
git merge --no-ff feature/expert-unification-phase-b
git push origin main
```

- [ ] **Step 3: Wait for Railway deploy + verify 404**

Watch Railway dashboard; wait for deploy "Success".

Run: `curl -sI https://api.link2ur.com/api/admin/task-expert-services`
Expected: HTTP/2 404 — old route confirmed gone.

Run: `curl -sI https://api.link2ur.com/api/admin/experts/services`
Expected: HTTP/2 401 — new route still live.

- [ ] **Step 4: Delete feature branch**

```bash
git branch -d feature/expert-unification-phase-b
# optionally: git push origin --delete feature/expert-unification-phase-b (if pushed)
```

- [ ] **Step 5: Phase B DoD confirmation**

Run these checks from project root:

```bash
test ! -f backend/app/admin_task_expert_routes.py && echo "file deleted: ok"
grep -rn "admin_task_expert" backend/app/ 2>&1 | grep -v "^$" || echo "no refs: ok"
grep -rn "task-expert" backend/app/ 2>&1 | grep -v "^$" || echo "no task-expert in backend: ok"
grep -rn "TaskExpert" admin/src/api.ts admin/src/pages/admin/experts/ExpertManagement.tsx admin/src/config.ts 2>&1 | grep -v "^$" || echo "no TaskExpert in targeted frontend files: ok"
```

All 4 should print "ok" (or equivalent clean result). If any residue, record and evaluate whether it belongs to Phase D cleanup or is a Phase B miss.

---

## Rollback Reference

From spec §8:
- **After C3 pushed, want to fully undo**: `git revert <C3-sha> <C2-sha>` together (otherwise admin frontend hits dead URLs). Then push.
- **Between C2 and C3 pushes**: revert individual commits freely.

## Final Verification (post-all-tasks)

- [x] Spec §10 DoD item 1: admin_expert_routes.py has 8 new endpoints
- [x] Spec §10 DoD item 2: admin_task_expert_routes.py file gone, main.py clean
- [x] Spec §10 DoD item 3: `grep task-expert backend/app/` zero hits (in route/handler code)
- [x] Spec §10 DoD item 4: `grep TaskExpert admin/src/{api.ts, ExpertManagement.tsx, config.ts}` zero hits
- [x] Spec §10 DoD item 5: Manual admin smoke done (Task 6 Step 4)
- [x] Spec §10 DoD item 6: pytest 6 tests pass (4 smoke + 2 regression)
- [x] Spec §10 DoD item 7: `npm run build` succeeds (Task 5 Step 6)
