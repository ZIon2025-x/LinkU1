# Public Application Display on Task Detail Page

**Date:** 2026-03-17
**Status:** Approved

## Overview

Add a public "application messages" section to the task detail page, showing all applicants' messages, quotes, and the poster's one-time reply. This creates a transparent "bidding" experience visible to all users (including unauthenticated).

## Requirements

1. All application messages and proposed prices are publicly visible on the task detail page
2. The task poster can reply once to each application (public reply)
3. Replies display indented below the corresponding application
4. The existing private chat system (application chat) remains unchanged

## Backend Changes

### 1. Database: Add poster reply fields to `task_applications` table

New columns on the `task_applications` table:
- `poster_reply` (Text, nullable) — the poster's public reply message
- `poster_reply_at` (DateTime, nullable) — when the reply was posted

Migration required.

### 2. Modify GET `/api/tasks/{task_id}/applications` — Public Mode

**Current behavior:** Non-poster users only see their own application. Auth dependency is `get_current_user_secure_async_csrf` (mandatory login). Query only filters `pending` and `chatting` statuses.

**Changes required:**
- **Auth:** Switch dependency from `get_current_user_secure_async_csrf` to `get_current_user_optional` (already exists in codebase). Handle `current_user is None` as unauthenticated path.
- **Query filter:** Add `approved` to the status filter (currently only `pending`, `chatting`).
- **Response formatting:** Create a `_format_public_application_item()` helper (or add a `public` flag to existing `_format_application_item()`).

**New behavior — three caller contexts:**
1. **Unauthenticated / unrelated user:** See all applications with status `pending`, `chatting`, or `approved`. Public fields: `id`, `task_id`, applicant name, avatar, user level, message, proposed price, currency, created_at, poster_reply, poster_reply_at, status. Private fields excluded: `applicant_id`, `unread_count`.
2. **Poster:** Full data (including applicant_id, unread_count) for management. Same query expansion to include `approved`.
3. **Applicant (own application):** Full data for their own application.

### 3. New Endpoint: POST `/api/tasks/{task_id}/applications/{application_id}/public-reply`

- **Auth:** Required, must be the task poster
- **Request body:** `{ "message": "string" }` (max 500 characters)
- **Validation:**
  - Task must exist and caller must be the poster
  - Application must exist and belong to this task
  - Application must not already have a `poster_reply` (one reply only)
- **Action:** Sets `poster_reply` and `poster_reply_at` on the application record
- **Response:** Updated application object
- **Notification:** Send push notification to the applicant that the poster replied

## Flutter Frontend Changes

### 1. TaskApplication Model

Add two fields:
- `posterReply` (String?) — parsed from `poster_reply`
- `posterReplyAt` (String?) — parsed from `poster_reply_at`

Update `fromJson` and `props`. Add `copyWith` method (does not exist yet). Note: `toJson` does not currently exist on this model and is not needed for this feature.

### 2. API Endpoints

Add constant:
- `ApiEndpoints.publicReplyApplication` = `'/api/tasks/{taskId}/applications/{applicationId}/public-reply'`

### 3. Task Repository

Add method:
- `publicReplyApplication(int taskId, int applicationId, String message)` — calls the new endpoint

### 4. TaskDetailBloc

New event:
- `TaskDetailPublicReply { applicationId: int, message: String }`

Handler:
- Calls repository method
- On success: updates the application in state with the reply data, sets actionMessage
- On error: sets errorMessage with error code string

**Error codes:**
- `public_reply_failed` — general failure
- `public_reply_already_replied` — 409 response (already replied)

Add corresponding cases in `ErrorLocalizer.localize()`.

### 4.1. Application Loading for Unauthenticated Users

Currently in `task_detail_view.dart`, application loading is guarded by `currentUserId != null`. This guard must be relaxed — applications should always be loaded for any visitor. When user is not logged in, pass `currentUserId` as null. The `ApiService` call should use the `skipAuth: true` extra flag for unauthenticated users.

### 5. Task Detail Page — New "Public Applications" Section

**Location:** Below the task description section, above the action buttons.

**Component: `_PublicApplicationsSection`**
- Header: localized "Application Messages (N)" with count
- Lists all applications from state
- Visible to ALL users (no auth check)

**Component: `_PublicApplicationCard`**
- Row: applicant avatar (40px circle) + name + user level badge + relative time
- Body: application message text
- Price tag: "Proposed: £XX.XX" if proposedPrice exists
- If `posterReply` exists: indented sub-card with "Poster Reply" label + reply text + reply time
- If current user is poster AND no posterReply: "Reply" text button → opens a dialog/bottom sheet with a TextField (max 500 chars) and submit button

### 6. Localization

New keys in all 3 ARB files (en, zh, zh_Hant):
- `applicationMessages` — section title
- `posterReply` — reply label
- `replyToApplication` — reply button text
- `replySubmitted` — success message
- `publicReplyPlaceholder` — text field hint
- `alreadyReplied` — error when trying to reply twice

## What Does NOT Change

- Private application chat system (application_chat_view.dart) — untouched
- Accept/Reject/Start Chat buttons — remain in the poster's management section only
- Application submission flow — unchanged
- Payment flow — unchanged

## Data Flow

```
Task Detail Page loads
  → TaskDetailLoaded dispatched
  → BLoC fetches task + applications (GET /api/tasks/{id}/applications)
  → Applications list now includes poster_reply fields
  → UI renders _PublicApplicationsSection for all users
  → Poster taps "Reply" on an application
  → Dialog opens, poster types reply
  → TaskDetailPublicReply event dispatched
  → BLoC calls POST .../public-reply
  → On success: application in state updated with reply
  → UI re-renders showing the reply under the application
```

## Edge Cases

- **No applications yet:** Show empty state text "No applications yet"
- **Rejected applications:** Not shown in the public section (only pending/chatting/approved)
- **Poster reply length:** Max 500 characters, validated on both client and server
- **Concurrent reply attempts:** Server enforces one reply per application; second attempt returns 409 error
- **`chatting` status in public view:** Display as-is — users can see that negotiation is underway, which adds transparency
- **Large number of applications:** Initially show all; if performance becomes an issue, add pagination later (YAGNI)
- **Application `id` field:** Always returned (needed for poster to send reply via URL path)
