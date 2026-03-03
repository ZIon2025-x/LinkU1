# Cancel Task Refund Fix Design

## Problem

Two issues with the current task cancellation flow for paid in-progress tasks:

1. **Funds stuck in escrow**: When a paid `in_progress` task is cancelled via CS review, `cancel_task()` sets status to `cancelled` but never triggers a Stripe refund. The refund system only works for `pending_confirmation` tasks, so funds become permanently stuck.

2. **Misleading UI feedback**: Flutter shows "Task cancelled" when the user submits a cancel request for an `in_progress` task, but the backend only created a review request — the task is not yet cancelled.

## Fix 1: Auto-refund on cancel (Backend)

**File**: `backend/app/crud/task.py` — `cancel_task()`

After setting `task.status = "cancelled"`, when `is_admin_review=True`:
1. Check `task.is_paid == 1` and `task.payment_intent_id` exists
2. Call Stripe refund (full amount based on `escrow_amount`)
3. On success: set `is_paid=0`, `payment_intent_id=None`, `escrow_amount=0`
4. On failure: log error, do NOT block the cancellation — admin handles manually

## Fix 2: Distinguish cancel vs review-submitted (Flutter)

**Files**: `task_repository.dart`, `task_detail_bloc.dart`, `task_detail_view.dart`, ARB files

1. `cancelTask()` returns a result indicating whether the task was directly cancelled or a review request was submitted
2. BLoC emits `'task_cancelled'` vs `'cancel_request_submitted'`
3. UI maps `'cancel_request_submitted'` to localized "Cancel request submitted, awaiting review"
4. Add l10n keys in en/zh/zh_Hant ARB files
