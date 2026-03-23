# Personal Service Publishing — Design Spec

## Overview

Allow all registered users to publish services/skills, not just verified experts. Introduces a "personal service" tier alongside existing "expert service", with a unified publish flow.

## Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Publishing gate | Open to all — register and publish | Lowest friction, maximize supply |
| Display strategy | Mixed list, experts badged + ranked higher, "experts only" filter | Best discovery UX |
| Moderation | No pre-approval; rate limit + report flow | Matches open gate; basic abuse prevention |
| Feature scope | Slim v1: name, description, price, images | Differentiate from expert services; ship fast |
| Entry points | "+" publish sheet + profile "My Services" | Quick publish + full management |

## Data Model

### Extend existing `TaskExpertService` table

Add three columns:

```
service_type   VARCHAR(20)  DEFAULT 'expert'  NOT NULL  -- 'personal' | 'expert'
user_id        VARCHAR(36)  NULLABLE          FK → users.id ON DELETE CASCADE
pricing_type   VARCHAR(20)  DEFAULT 'fixed'   NOT NULL  -- 'fixed' | 'hourly' | 'negotiable'
```

**Critical: make `expert_id` nullable in the same migration.** Currently `expert_id` is `NOT NULL` with FK to `task_experts.id`. Personal services have no expert, so `expert_id` must become nullable. Existing rows all have valid `expert_id` so no data issue.

Add composite index: `(service_type, status)` for public listing filter performance.

#### Owner resolution

- **Expert services**: owner = `expert_id` → `task_experts.id` → `users.id`
- **Personal services**: owner = `user_id` → `users.id` directly
- Helper: `service.owner_user_id` property that resolves to the correct user ID regardless of type

#### ServiceApplication compatibility

`ServiceApplication.expert_id` is also `NOT NULL` with FK to `task_experts.id`. For personal services, this column cannot be populated. Two options:

**Chosen approach: make `ServiceApplication.expert_id` nullable, add `service_owner_id` column.**

- `service_owner_id VARCHAR(36) FK → users.id` — always populated (the person who owns the service)
- `expert_id` — populated only for expert services, nullable for personal services
- The `apply_for_service` endpoint sets `service_owner_id = service.owner_user_id` and `expert_id = service.expert_id` (which is None for personal)
- Self-apply guard checks `service.owner_user_id == current_user.id` (works for both types)

### Why extend vs new table

- Shared query for public listing (one table, one index)
- Shared `ServiceApplication` flow with minimal changes
- Avoids duplicating 80% identical schema
- `display_order` defaults to 0 for personal services — sort by `created_at` as tiebreaker

### User account deletion cascade

`user_id` FK uses `ON DELETE CASCADE` — when a user deletes their account, their personal services are removed automatically (same behavior as expert services via `expert_id` CASCADE).

## Backend API

### New endpoints (personal services)

All use `Depends(get_current_user)` — no expert check.

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/services/me` | Create personal service (`status='active'`) |
| `GET` | `/api/services/me` | List my personal services |
| `PUT` | `/api/services/me/{service_id}` | Update my personal service |
| `DELETE` | `/api/services/me/{service_id}` | Delete my personal service |

#### Create request schema (`PersonalServiceCreate`)

```python
service_name: str          # required, max 100
description: str           # required, max 2000
base_price: Decimal(12,2)  # required, > 0 (in pounds, e.g. 25.50 — matches existing DECIMAL column)
currency: str              # default 'GBP'
pricing_type: str          # 'fixed' | 'hourly' | 'negotiable', default 'fixed'
images: list[str]          # optional, max 6
```

No time slots, no bilingual fields, no `display_order` — slim v1.

#### Ownership guard

All personal service endpoints verify `service.user_id == current_user.id`. Returns 403 otherwise.

#### Rate limit

Max **10 active personal services per user**. Checked on create — returns 429 if limit reached. Prevents spam flooding.

### New endpoint: public service listing

**`GET /api/services/browse`** — this is a **new** endpoint (no existing "browse all services" endpoint exists).

Query parameters:
- `type`: `all` | `expert` | `personal` (default `all`)
- `category`: optional category filter
- `q`: optional text search (service name + description)
- `sort`: `recommended` | `newest` | `price_asc` | `price_desc` (default `recommended`)
- `page`, `page_size`: pagination (default page_size=20)

Response includes `service_type`, `is_expert_verified`, owner user info (avatar, name, rating).

Sort logic for `recommended`: expert services get +1000 base score, then sorted by rating × completed_tasks. Personal services sorted by created_at.

### Unchanged

- All existing `/api/task-experts/me/services/*` endpoints — untouched
- `GET /api/task-experts/{expert_id}/services` — untouched (per-expert listing)
- `GET /api/task-experts/services/{service_id}` — untouched (single detail, works for both types already)
- Expert application flow — untouched
- `get_current_expert` dependency — untouched

## Frontend Changes

### 1. Publish sheet (bottom sheet from "+" button)

Based on `option_A_publish.html` design — bottom sheet with grid options:

```
┌──────────────────────────────────┐
│          发布什么？               │
│                                  │
│  📋 发布任务    🎯 发布服务  NEW │
│  📸 发帖分享    🛒 闲置出售      │
│  🎪 创建活动    ❓ 发起提问      │
│                                  │
│  🤖 不知道怎么写？问 AI          │
│                                  │
│          取消                     │
└──────────────────────────────────┘
```

"发布服务" is the new entry. Tapping it opens the slim service form.

### 2. Personal service form (new page)

Slim form with 4 fields:

- **服务名称** — text input (required)
- **服务描述** — textarea (required)
- **价格** — price input (Decimal, in pounds) with pricing_type toggle (固定价/时薪/面议)
- **图片** — image picker (max 6)

No time slots, no bilingual fields. AI-assisted description generation button (reuse existing AI chat integration).

### 3. Profile page — "我的服务" menu item

Add to "我的内容" section in `profile_menu_widgets.dart`:

```
📋 我的任务
🎯 我的服务  ← NEW (visible to all users)
📦 我的商品
📝 我的帖子
...
```

Tapping opens a list of user's personal services with edit/delete/create actions.

### 4. Service list display

In the unified service browsing view:

- **Expert services**: show "认证达人" badge, verified checkmark, expert stats
- **Personal services**: show user avatar + name, no badge
- **Sort order**: expert services weighted higher by default
- **Filter**: "仅看达人" toggle switch filters to `type=expert`

### 5. Dart model changes

`TaskExpertService.fromJson` currently does `expertId: json['expert_id']?.toString() ?? ''`. For personal services `expert_id` is null, so `expertId` will be `''`. Add:
- `serviceType` field (`personal` | `expert`)
- `userId` field (nullable)
- `pricingType` field
- `ownerName`, `ownerAvatar` from joined response
- UI code that navigates to expert profile must check `serviceType == 'expert'` before using `expertId`

### 6. Router changes

- Add routes: `/services/my`, `/services/create`, `/services/edit/:id`
- Expert dashboard routes remain guarded by `isExpert`
- No existing route guards change

## File Change Summary

### Backend (~5 files + migration)

| File | Change |
|---|---|
| `app/models.py` | Add `service_type`, `user_id`, `pricing_type` to `TaskExpertService`; make `expert_id` nullable; make `ServiceApplication.expert_id` nullable, add `service_owner_id`; add `owner_user_id` property |
| `app/personal_service_routes.py` | **New file** — CRUD + rate limit for personal services |
| `app/service_browse_routes.py` | **New file** — public browse endpoint with unified listing |
| `app/schemas.py` (or `schema_modules/`) | Add `PersonalServiceCreate`, `PersonalServiceUpdate`, `ServiceBrowseResponse` schemas |
| `app/task_expert_routes.py` | Update `apply_for_service` to handle personal services (self-apply guard, nullable expert_id) |
| `alembic/versions/xxx_add_personal_services.py` | Migration: add columns, make expert_id nullable, add index |
| `app/main.py` | Register new routers |

### Frontend (~7 files + new directory)

| File | Change |
|---|---|
| `lib/data/repositories/personal_service_repository.dart` | **New file** — API calls for personal services |
| `lib/data/models/task_expert.dart` | Add `serviceType`, `userId`, `pricingType` fields; handle nullable `expertId` in `fromJson` |
| `lib/features/personal_service/` | **New directory** — bloc + views for personal service CRUD |
| `lib/features/profile/views/profile_menu_widgets.dart` | Add "我的服务" menu item (all users) |
| `lib/features/publish/views/publish_view.dart` | Add "发布服务" option to publish sheet |
| `lib/core/router/app_router.dart` | Add personal service routes |
| `lib/core/constants/api_endpoints.dart` | Add personal service + browse endpoints |
| `lib/app_providers.dart` | Register `PersonalServiceRepository` |

## Not In Scope (v1)

- Time slot management for personal services
- Bilingual fields (service_name_en, description_en)
- Service promotion/boost
- Converting personal service → expert service on expert approval
- Service reviews separate from task reviews
- Service analytics/stats dashboard for personal users
- Content moderation AI (v1 relies on user reports + manual admin review)

## Migration Safety

- `service_type` defaults to `'expert'` — all existing rows auto-tagged correctly
- `expert_id` becomes nullable — existing rows all have valid values, no data loss
- `user_id` is nullable — existing expert services don't need it
- `ServiceApplication.expert_id` becomes nullable — existing rows all have valid values
- `ServiceApplication.service_owner_id` is nullable initially — backfill from `expert_id → task_experts.id` (same user)
- New index `(service_type, status)` added — no impact on writes
- No existing endpoint signatures change
- No existing frontend routes change
- Fully backward-compatible
