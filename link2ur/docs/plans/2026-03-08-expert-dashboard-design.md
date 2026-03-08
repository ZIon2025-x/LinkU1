# Expert Dashboard Design — 2026-03-08

## Overview

Add a full expert management centre to the Flutter app, gated to users with `isExpert == true`. Covers dashboard stats, service CRUD, time slot management, closed-date scheduling, application management, and profile update request.

---

## Scope

### New screens
| Screen | Route | Description |
|--------|-------|-------------|
| Expert Dashboard | `/expert-dashboard` | 5-tab hub for all expert management |
| Expert Profile Edit | `/expert-profile-edit` | Submit name/bio/avatar update request |

### Tab layout inside `/expert-dashboard`
| Index | Label | Content |
|-------|-------|---------|
| 0 | 看板 | Stats cards |
| 1 | 我的服务 | Service CRUD |
| 2 | 申请管理 | Incoming applications (reuse existing logic) |
| 3 | 时间段 | Time slot management per service |
| 4 | 日程 | Closed-date calendar |

### Existing changes
- Profile menu "达人管理" entry → points to `/expert-dashboard` (already gated by `isExpert`)
- Route guard on `/expert-dashboard`: non-experts redirected away
- `MyServiceApplicationsView`: show "查看任务" button when `status == approved && task_id != null`

### Small fixes
- Extract expert category list to `lib/core/constants/expert_constants.dart`
- `expert.officialBadge ?? '官方'` → l10n key `expertOfficialBadge`
- Add sort options to expert search (rating / completion count / newest)

---

## Architecture

### BLoC

**New: `ExpertDashboardBloc`** (page-level, created when dashboard mounts)

Handles all write-heavy expert operations to avoid polluting the existing `TaskExpertBloc` (which handles consumer-side browse/search/apply flows).

Events:
- `ExpertDashboardLoadStats`
- `ExpertDashboardLoadMyServices`
- `ExpertDashboardCreateService` / `UpdateService` / `DeleteService`
- `ExpertDashboardLoadTimeSlots(serviceId)`
- `ExpertDashboardCreateTimeSlot` / `DeleteTimeSlot`
- `ExpertDashboardLoadClosedDates`
- `ExpertDashboardCreateClosedDate` / `DeleteClosedDate`
- `ExpertDashboardSubmitProfileUpdate`

State fields:
- `stats`, `services`, `timeSlots`, `closedDates`
- `status` enum: initial / loading / loaded / submitting / error
- `errorMessage`, `actionMessage` (for snackbar feedback)

**Extended: `TaskExpertBloc`** — no changes needed; application management already works.

### Repository additions (TaskExpertRepository)

New methods calling existing API endpoints:
```
updateMyExpertProfile(name, bio, avatar)         PUT  /api/task-experts/me
submitProfileUpdateRequest(name, bio, avatar)    POST /api/task-experts/me/profile-update-request
getMyServices()                                  GET  /api/task-experts/me/services
createService(data)                              POST /api/task-experts/me/services
updateService(id, data)                          PUT  /api/task-experts/me/services/{id}
deleteService(id)                                DELETE /api/task-experts/me/services/{id}
getMyServiceTimeSlots(serviceId)                 GET  /api/task-experts/me/services/{id}/time-slots
createServiceTimeSlot(serviceId, data)           POST /api/task-experts/me/services/{id}/time-slots
deleteServiceTimeSlot(serviceId, slotId)         DELETE /api/task-experts/me/services/{id}/time-slots/{slotId}
createClosedDate(date, reason)                   POST /api/task-experts/me/closed-dates
deleteClosedDate(id)                             DELETE /api/task-experts/me/closed-dates/{id}
deleteClosedDateByDate(date)                     DELETE /api/task-experts/me/closed-dates/by-date
```

### Routes

Add to `task_expert_routes.dart`:
```
GoRoute(path: '/expert-dashboard', builder: ExpertDashboardView)
GoRoute(path: '/expert-profile-edit', builder: ExpertProfileEditView)
```

Redirect guard in `app_router.dart`: if `!user.isExpert` on `/expert-dashboard` → push `/task-experts/intro`.

---

## UI Detail

### Stats Tab
2-column grid of stat cards:
- Total Services / Active Services
- Total Applications / Pending Applications
- Upcoming Time Slots (full width)

### Services Tab
- ListView of service cards (name, price, status badge, first image thumbnail)
- FAB to create service
- Swipe-to-reveal Edit / Delete actions
- Create/Edit via `showAdaptiveModalBottomSheet`:
  - service_name (zh + en)
  - description (zh + en)
  - base_price + currency picker (GBP / CNY / USD)
  - images (up to 4, via upload API `POST /api/v2/upload/image?category=service_image`)
  - Submit → status becomes `pending`, show "已提交审核" snackbar

### Time Slots Tab
- Dropdown to select service
- List of time slots for selected service (date, time range, price, spots left)
- FAB → bottom sheet: date picker + start/end time pickers + price + max participants
- Swipe-to-delete individual slot

### Schedule Tab (Closed Dates)
- Month calendar; closed dates marked red
- Tap a date → dialog: "设为休息日" (with optional reason input) or "取消休息日"

### Profile Edit Page
- Avatar with tap-to-change (image picker → upload API)
- Name text field
- Bio text field (multiline)
- Submit button → POST profile-update-request → show "已提交，等待管理员审核"

### My Service Applications (existing page patch)
- For applications with `status == 'approved'` and non-null `task_id`: show "查看任务" `TextButton` → `context.goToTaskDetail(taskId)`

---

## Review Submission

No new UI needed. Service reviews and task reviews share the same `Review` table. When an application is approved, the backend creates a task with `expert_service_id` set. The user reviews via the existing task review flow (`ReviewBottomSheet` on task detail page). "查看任务" button above provides the entry point.

---

## Localisation

New ARB keys needed (add to en, zh, zh_Hant):
- `expertOfficialBadge` — fallback for `officialBadge` field
- All dashboard tab labels, stat card labels, form field labels, action messages

---

## Small Fixes

### Category constants
Create `lib/core/constants/expert_constants.dart`:
```dart
const List<String> kExpertCategoryKeys = [
  'all', 'programming', 'translation', 'tutoring', 'food',
  'beverage', 'cake', 'errand_transport', 'social_entertainment',
  'beauty_skincare', 'handicraft',
];
```
Replace hardcoded lists in `task_expert_list_view.dart` and `task_expert_search_view.dart`.

### Official badge fallback
Replace `expert.officialBadge ?? '官方'` with `expert.officialBadge ?? context.l10n.expertOfficialBadge`.

### Search sort
Add `sort` parameter to `getExperts()` call; add sort dropdown to search view UI (rating_desc / completed_desc / newest).

---

## Out of Scope

- Service image hosting / CDN setup (assume upload API already works)
- Multi-participant activity creation (separate feature)
- Advanced schedule recurrence (weekly patterns) — single-date closed dates only
