# Expert Unification Phase B — Admin Routes & Frontend Migration

**Status:** Draft
**Date:** 2026-04-19
**Predecessor:** Phase A (`2026-04-19-expert-unification-design.md` v1.10) — merged to main `440472eac`
**Successors:** Phase C (DROP legacy DB tables + delete ORM classes), Phase D (Flutter/Web naming cleanup)

## 1. Background & Goal

After Phase A, the backend's user-facing read/write paths uniformly point to the new Expert team model. However, the **admin surface** is still split:

- `backend/app/admin_task_expert_routes.py` (527 lines, 9 endpoints) is mounted under the legacy `/api/admin/task-expert-*` URL prefix. Internally it already writes to new tables (`owner_type='expert'` filtered queries, `FeaturedExpertV2`), but the URL is misleading.
- `backend/app/admin_expert_routes.py` (643 lines, 11 endpoints) provides the new `/api/admin/experts/*` surface for Expert team CRUD, applications, profile updates, and feature toggling.
- The React admin (`admin/src/pages/admin/experts/ExpertManagement.tsx`, 2032 lines) calls **both** prefixes inconsistently — some functions use new URLs, others use legacy URLs.

**Goal**: Eliminate the `/api/admin/task-expert-*` URL prefix and the file behind it. Consolidate the entire admin Expert surface under `/api/admin/experts/*`. Rename the inconsistent admin frontend functions to the `Expert*` convention.

**Why now**: Continuation of "全面更新，不要新旧混合" directive. Reduces cognitive load (one admin surface, one naming scheme) before Phase C drops the legacy tables.

## 2. Decisions Locked Before This Spec

| ID | Decision | Rationale |
|---|---|---|
| D1 | Full retirement path (option 1 of brainstorm) | Aligns with "全面更新" stance; backend file already writes new tables, so cost is mostly cosmetic |
| D2 | `POST /api/admin/task-expert-applications/{id}/create-featured-expert` is **deleted, not replaced** | 1-person admin team accepts the 2-step UX (approve application → navigate to expert list → toggle feature) in exchange for smaller API surface |
| D3 | 3-commit sequenced rollout (additive backend → frontend switch → backend cleanup) | Avoids any 404 window during deploy gap between Railway and Vercel |
| D4 | Skip PR ceremony, push directly to main | 1-person team workflow consistent with Phase A |

## 3. Backend Changes

### 3.1 New endpoints — append to `backend/app/admin_expert_routes.py`

8 endpoints, all body-equivalent to the deleted `admin_task_expert_routes.py` originals. The data access layer needs no rewrite (already filters `owner_type='expert' + owner_id` against `TaskExpertService` / `Activity` tables, already uses `FeaturedExpertV2`).

| New endpoint | Old endpoint (deleted by C3) | Auth dep |
|---|---|---|
| `GET /api/admin/experts/services` | `GET /api/admin/task-expert-services` | `get_current_admin` |
| `GET /api/admin/experts/activities` | `GET /api/admin/task-expert-activities` | `get_current_admin` |
| `POST /api/admin/experts/services/{service_id}/review` | `POST /api/admin/task-expert-services/{id}/review` | `get_current_admin` |
| `POST /api/admin/experts/activities/{activity_id}/review` | `POST /api/admin/task-expert-activities/{id}/review` | `get_current_admin` |
| `PUT /api/admin/experts/services/{service_id}` | `PUT /api/admin/task-expert-services/{id}` | `get_current_admin` |
| `DELETE /api/admin/experts/services/{service_id}` | `DELETE /api/admin/task-expert-services/{id}` | `get_current_admin` |
| `PUT /api/admin/experts/activities/{activity_id}` | `PUT /api/admin/task-expert-activities/{id}` | `get_current_admin` |
| `DELETE /api/admin/experts/activities/{activity_id}` | `DELETE /api/admin/task-expert-activities/{id}` | `get_current_admin` |

**Implementation rule**: copy-paste each function body from `admin_task_expert_routes.py`, change only the `@router` decorator path. Do not refactor logic. This minimizes regression surface.

### 3.2 Deletions (C3 commit)

- Delete the entire file `backend/app/admin_task_expert_routes.py` (527 lines).
- Delete the import + router registration in `backend/app/main.py` (the `admin_task_expert_router` lines, ~3 lines).
- The `POST /api/admin/task-expert-applications/{id}/create-featured-expert` endpoint disappears with the file. No replacement.

### 3.3 Models, schemas, migrations

**No changes**. No DB migration. ORM classes (`TaskExpert`, `FeaturedTaskExpert`, etc.) remain — Phase C handles those.

## 4. Frontend Changes

All in `admin/`. Total surface: ~45 occurrences across 3 relevant files (`api.ts`, `ExpertManagement.tsx`, `config.ts`). `BannerManagement.tsx:344` references the **Flutter deep link** `/task-experts/intro` which is a runtime route on the mobile app and is **out of scope** for Phase B.

### 4.1 `admin/src/api.ts` (~26 occurrences)

**Path replacements** (8 functions): `/api/admin/task-expert-services*` → `/api/admin/experts/services*`; activities analogous.

**Function renames**:
- `getTaskExperts` → `getExperts`
- `getTaskExpertForAdmin` → `getExpertForAdmin`
- `updateTaskExpert` → `updateExpert`
- `deleteTaskExpert` → `deleteExpert`
- `getTaskExpertApplications` → `getExpertApplications`
- `reviewTaskExpertApplication` → `reviewExpertApplication`

**Functions kept as-is** (already `Expert`-named, only path swap): `getAllExpertServicesAdmin`, `getAllExpertActivitiesAdmin`, `updateExpertServiceAdmin`, `deleteExpertServiceAdmin`, `reviewExpertServiceAdmin`, `reviewExpertActivityAdmin`.

**Function deleted**: `createExpertFromApplication`.

### 4.2 `admin/src/pages/admin/experts/ExpertManagement.tsx` (~17 occurrences + handler removal)

- Update imports + 18 call sites to match the renames in 4.1.
- Delete `handleCreateFeatured` handler (lines ~593–638, ~46 lines).
- Delete the "创建特色达人" button in the applications-tab table column (around line 834).
- **Do not rename**: file name, component name, internal state types, Chinese UI labels (`达人管理` etc. stay).

Net diff: ~50 lines removed, ~17 lines modified.

### 4.3 `admin/src/config.ts:41`

Update one comment line: `"使用 /api/admin/experts/* 与 /api/admin/task-expert*"` → `"使用 /api/admin/experts/*"`.

## 5. Rollout (3 commits, sequenced)

| Commit | Touches | Wait condition before next commit |
|---|---|---|
| **C1** backend additive | `admin_expert_routes.py` only (8 new endpoints) | Railway deploy completes (~3 min); `curl https://api.link2ur.com/api/admin/experts/services` returns 401 (auth required, route exists) |
| **C2** frontend switch | `api.ts`, `ExpertManagement.tsx`, `config.ts` (no backend changes) | Vercel deploy completes; admin operator manually clicks through services tab + activities tab + executes one review/edit/delete on each, all succeed |
| **C3** backend cleanup | Delete `admin_task_expert_routes.py` + `main.py` import/register lines | Railway deploy completes; `curl https://api.link2ur.com/api/admin/task-expert-services` returns 404 |

Each commit pushed directly to `main`. Total elapsed time ~15–20 min if no manual issues.

## 6. Testing

**Backend**:
- 4 pytest happy-path smoke tests for the 4 most-used new endpoints (list services, list activities, review service, delete service). Use existing `backend/tests/conftest.py` `db` fixture (real PG, rollback isolation).
- 2 pytest regression-404 tests after C3 (GET old paths return 404).
- Run `python -c "import app.main"` locally before pushing C3 to catch missing-import startup crash.

**Frontend**:
- No automated tests added (admin has no test suite).
- Manual click-through during C2 wait condition: services tab, activities tab, applications tab, each happy path once.
- `npm run build` locally before pushing C2 to catch TS/ESLint errors.

**No tests for**:
- CRUD write field mappings (logic unchanged from old file).
- Auth dependencies (FastAPI `Depends(get_current_admin)` is a copy, not a rewrite).
- Removal of `createExpertFromApplication` (testing absence is gross overkill for 1-person admin).

## 7. Risks (probability descending)

| ID | Risk | Trigger | Mitigation |
|---|---|---|---|
| B1 | Backend startup crash on missing-import after C3 | Forgot a `from app.admin_task_expert_routes import ...` in `main.py` or elsewhere | Local `python -c "import app.main"` self-check before C3 push; Railway logs after deploy |
| B2 | New route returns 404 due to prefix typo | Wrong `@router` path string | C2 manual smoke covers all 4 GET paths and 4 mutating paths via UI |
| B3 | Vercel build fails on dangling `createExpertFromApplication` import | Rename leftover | Local `npm run build` before C2 push |
| B4 | A second caller of `getTaskExpert*` exists outside `ExpertManagement.tsx` | Audit missed it | Final grep `TaskExpert\|task-expert` across `admin/src/` before C2 push |
| B5 | C2 deployed before C1 finishes Railway rollout → admin temporarily 404 | Operator clicks push too fast | Discipline: wait for Railway dashboard "Deploy succeeded" before C2 push |
| B6 | Backend grep still finds "task expert" in comments / docstrings / test fixtures | Out of scope | Defer to Phase D |

## 8. Rollback

- **C3 deployed, want to undo**: `git revert <C3>` → file restored, router re-registered. No data effect.
- **C2 deployed, want to undo**: `git revert <C2>` → admin frontend reverts to old URLs. Safe **only if C3 not yet pushed** (old routes still alive).
- **C1 deployed, want to undo**: `git revert <C1>` → drops the 8 new endpoints. Safe **only if C2 not yet pushed**.
- **After C3 pushed**: revert needs to be `git revert C3 C2` together (otherwise admin frontend calls dead URLs).

## 9. Non-goals

- DROP `task_experts` / `featured_task_experts` / `task_expert_applications` / `task_expert_profile_update_requests` tables → Phase C
- Delete `TaskExpert` / `FeaturedTaskExpert` ORM model classes → Phase C
- Rename Flutter app code (`TaskExpert*` widgets, routes, BLoCs) → Phase D
- Clean up `task expert` strings in backend comments / docstrings → Phase D
- Touch `BannerManagement.tsx:344` (Flutter deep link `/task-experts/intro`, not admin API)
- Rename `ExpertManagement.tsx` file or component name (already correctly named)
- Refactor logic inside the 8 endpoint bodies (copy-rename only)

## 10. Definition of Done

1. `backend/app/admin_expert_routes.py` contains the 8 new endpoints; total line count grows from 643 to ~1100.
2. `backend/app/admin_task_expert_routes.py` does not exist; `main.py` no longer imports or registers `admin_task_expert_router`.
3. `grep -r "task-expert" backend/app/` returns zero hits in route/handler code (comments may remain — Phase D).
4. `grep -r "TaskExpert" admin/src/api.ts admin/src/pages/admin/experts/ExpertManagement.tsx admin/src/config.ts` returns zero hits.
5. Admin operator successfully completes one full session (open services tab, edit one service, delete one service, open activities tab, review one activity) using production admin without errors.
6. Backend pytest suite passes including 4 new smoke tests + 2 new 404 regression tests.
7. `npm run build` succeeds in `admin/`.

## 11. Revision History

- 2026-04-19: v1.0 — Initial draft after 3-section brainstorm with user.
