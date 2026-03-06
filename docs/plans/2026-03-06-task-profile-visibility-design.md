# Task Profile Visibility Design

## Problem

Users cannot control whether their completed tasks appear on their public profile page. The backend has `is_public` but only the poster can toggle it, and takers have no control at all.

## Solution

Poster and taker each independently control whether a completed task appears on their own profile page.

## Data Model

**New field on Task model:**
- `taker_public` (Integer, default=1) — taker's visibility preference

**Existing field (unchanged):**
- `is_public` (Integer, default=1) — poster's visibility preference

## Backend Changes

### 1. Migration: Add `taker_public` column
- `ALTER TABLE tasks ADD COLUMN taker_public INTEGER DEFAULT 1`

### 2. PATCH `/tasks/{task_id}/visibility`
- If caller is poster → update `is_public`
- If caller is taker → update `taker_public`
- Otherwise → 403

### 3. Public profile recent_tasks query
Current: `WHERE (poster_id = uid OR taker_id = uid) AND is_public = 1`

New:
```sql
WHERE status = 'completed' AND (
  (poster_id = :uid AND is_public = 1)
  OR (taker_id = :uid AND taker_public = 1)
)
```

## Flutter Changes

### 1. Task model
Add `isPublic` and `takerPublic` fields (int, from JSON `is_public` / `taker_public`).

### 2. Task detail page (completed tasks only)
Show a "Show on my profile" SwitchListTile. Read/write the appropriate field based on whether the current user is poster or taker.

### 3. TaskDetailBloc
Add `TaskToggleProfileVisibility` event → calls existing `taskRepository.updateTaskVisibility()`.

### 4. Task repository
Existing `updateTaskVisibility()` method already sends `PATCH /tasks/{task_id}/visibility` with `{is_public: bool}`. Keep as-is — backend determines which field to update based on caller identity.

## Out of Scope

- Bulk visibility toggle
- Visibility toggle in "My Tasks" list
- Changes to task creation flow
