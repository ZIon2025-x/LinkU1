# Task Flow Redesign: Chat Before Payment

**Date:** 2026-03-16
**Status:** Draft

## Problem

Current flow: publish task → apply → accept application (creates payment) → pay → in_progress.

The poster has no chance to communicate with applicants before committing to payment. This leads to mismatched expectations and wasted payments.

## New Flow

```
publish(open) → apply(pending) → poster "agree to chat"(chatting)
→ 1-on-1 chat with price negotiation → poster "confirm & pay"(in_progress)
→ submit completion(pending_confirmation) → confirm(completed)
```

Everything after `in_progress` remains unchanged.

## New Task Status: `chatting`

Added between `open` and `in_progress`.

| Status | Meaning |
|--------|---------|
| `open` | Published, awaiting applications |
| `chatting` | Poster has opened chat with at least one applicant, no one selected yet |
| `in_progress` | Poster selected someone and payment succeeded |
| _(rest unchanged)_ | `pending_confirmation`, `completed`, `cancelled`, `disputed` |

**Transition rules:**
- `open` → `chatting`: when poster clicks "agree to chat" on any application
- `chatting` → `in_progress`: when poster pays for a selected applicant (via Stripe webhook)
- `chatting` → `open`: if all chatting applications are rejected/withdrawn and no `pending` applications remain. Checked automatically after each reject/withdraw operation.
- `open` → `in_progress`: NOT allowed (must go through chatting)

**New applications during `chatting`:** Allowed. Other users can still apply while the poster is chatting with existing applicants. The task remains visible and `canApply` returns true for `open` and `chatting` statuses.

**Removed from new flow:** `pending_acceptance` and `pending_payment` are no longer used for new tasks. Existing tasks in these states continue to work (backward compatible).

## Application Status Changes

| Status | Meaning |
|--------|---------|
| `pending` | Applied, waiting for poster response |
| `chatting` | Poster agreed to chat, chat channel open |
| `approved` | Poster selected this applicant and payment succeeded |
| `rejected` | Rejected manually, or auto-rejected when another applicant was selected |

**Transition rules:**
- `pending` → `chatting`: poster clicks "agree to chat"
- `pending` → `rejected`: poster rejects application
- `chatting` → `approved`: poster pays for this applicant
- `chatting` → `rejected`: poster rejects, or another applicant is selected and paid (auto-reject)
- `pending`/`chatting` → `withdrawn`: applicant withdraws

## Chat Channel Design

### One chat channel per application

Each application gets its own chat channel. Channel lifecycle:

1. **Created** when poster clicks "agree to chat" (application status → `chatting`)
2. **Active** while application is in `chatting` status — both parties can send messages
3. **Closed** when application is `approved`, `rejected`, or `withdrawn` — read-only, no new messages

### Chat channel data model

Reuse the existing task chat infrastructure (`/api/messages/task/{taskId}`), but scoped per application:

- Messages are tagged with `application_id` to separate conversations per applicant
- Poster sees a list of active chat channels (one per chatting applicant)
- Each channel shows the applicant's info, their proposed price, and message history

### Permissions

- Only the poster and the specific applicant can access a given application's chat channel
- Other applicants cannot see each other's conversations

## Price Negotiation

### In-chat price modification

Either party can propose a new price during the `chatting` phase:

- UI: a "modify quote" button in the chat interface
- Sends a special message type (`price_proposal`) that displays as a styled card
- The proposed price is stored on the application record as `negotiatedPrice`
- Each new proposal overwrites the previous `negotiatedPrice`
- The "confirm & pay" button uses the latest `negotiatedPrice` (or original `reward` if no negotiation)

### Price proposal message format

```json
{
  "type": "price_proposal",
  "content": "I suggest 50 GBP for this task",
  "metadata": {
    "proposedPrice": 50.00,
    "proposedBy": "user_id"
  }
}
```

Price is in pounds (DECIMAL, consistent with `Task.reward` and `TaskApplication.negotiated_price`). Conversion to pence happens only at the Stripe payment layer.

## UI Changes

### 1. Task Detail View — Application List

Current: "Accept" / "Reject" buttons per application.

New: "Agree to Chat" / "Reject" buttons for `pending` applications.

### 2. Application Chat View (new)

Entry point: poster taps "Agree to Chat" or taps an existing `chatting` application.

Layout:
- Header: applicant info, current proposed price
- Chat message list (with price proposal cards inline)
- Message input bar
- Bottom action bar: "Modify Quote" button + "Confirm & Pay" button
- "Confirm & Pay" triggers Stripe payment sheet with the current negotiated price

### 3. Applicant Side

- Application status shows "Chatting" with link to open chat
- Applicant can send messages and propose prices
- Applicant sees "Confirm & Pay" button is poster-only (greyed out / hidden for applicant)

### 4. Messages Tab

Active application chats appear in the messages list, distinguishable from regular chats.

## Backend API Changes

### New endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/tasks/{taskId}/applications/{appId}/start-chat` | Poster agrees to chat, opens channel |
| POST | `/api/tasks/{taskId}/applications/{appId}/propose-price` | Either party proposes new price |
| POST | `/api/tasks/{taskId}/applications/{appId}/confirm-and-pay` | Poster initiates payment for this applicant |

### Modified endpoints

| Endpoint | Change |
|----------|--------|
| `GET /api/tasks/{taskId}/applications` | Include `chatting` status, unread message count |
| `GET /api/messages/task/{taskId}` | Support `application_id` query param to scope messages |
| `POST /api/messages/task/{taskId}` | Accept `application_id` to post to specific application chat |

### Kept for backward compatibility

- `POST /api/tasks/{taskId}/applications/{appId}/accept` — still used for multi-participant tasks and existing tasks in old-flow statuses. New single-participant tasks use `start-chat` + `confirm-and-pay` instead.

### Payment flow detail

`confirm-and-pay` works in two phases:
1. **Create PaymentIntent**: Backend creates Stripe PaymentIntent, returns `clientSecret` to Flutter. Application stays `chatting`.
2. **Stripe webhook confirms payment**: On `payment_intent.succeeded`, backend marks application as `approved`, auto-rejects others, sets task to `in_progress`.

This is consistent with the existing Stripe webhook pattern used elsewhere in the codebase.

### Real-time notifications

Reuse the existing WebSocket infrastructure for chat events:
- New message in application chat → WebSocket event to the other party
- "Agree to chat" → push notification + WebSocket event to applicant
- Auto-reject → push notification to rejected applicants
- Price proposal → displayed as a styled card in chat, delivered via same message WebSocket channel

### Auto-reject logic (in Stripe webhook handler)

When poster pays for applicant X:
1. Mark applicant X as `approved`
2. Find all other applications with status `chatting` or `pending`
3. Set their status to `rejected`
4. Send system message to each rejected application's chat: "The poster has selected another applicant"
5. Close all rejected chat channels (read-only)
6. Task status → `in_progress`

## Multi-Participant Tasks

The new chat-before-payment flow does **NOT** apply to multi-participant tasks (`isMultiParticipant = true`). These continue to use the existing flow (accept → pay directly) since multiple applicants can be approved.

## Migration & Backward Compatibility

- Existing tasks in `pending_acceptance`/`pending_payment` status continue to work with old flow
- The old `accept` endpoint remains operational for existing tasks and multi-participant tasks
- New single-participant tasks created after deployment use the new flow
- No database migration needed for task status — `chatting` is a new string value in existing status field
- Application `chatting` status is a new string value in existing status field

### Required database migration

- Add nullable `application_id` (FK → `task_applications.id`) column to `messages` table
- Add index on `(task_id, application_id)` for query performance
- Add `application_id` to `MessageReadCursor` table for per-channel read tracking
- Existing messages have `application_id = NULL` (legacy task chat, unaffected)

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Poster tries to pay but Stripe fails | Show error, application stays `chatting`, poster can retry |
| Applicant withdraws while poster is paying | Use `SELECT FOR UPDATE` on application row to prevent race. If PaymentIntent already confirmed, issue refund. If not yet confirmed, cancel PaymentIntent. Poster notified either way. |
| Poster has no active `chatting` applications | "Confirm & Pay" button disabled |
| Task cancelled while chats are active | All applications rejected, all channels closed, system messages sent |

## Out of Scope

- Group chat (all applicants in one room) — not needed per design decision
- Chat before application (users must apply first)
- File/image sharing in application chat — uses existing chat attachment support
- Video/voice calls in chat
