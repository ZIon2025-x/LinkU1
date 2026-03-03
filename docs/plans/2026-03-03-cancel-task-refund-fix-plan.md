# Cancel Task Refund Fix — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix two bugs: (1) auto-refund when a paid in-progress task is cancelled via CS review, (2) show correct UI feedback when a cancel request is submitted vs directly cancelled.

**Architecture:** Backend `cancel_task()` gains Stripe refund logic for paid tasks. Flutter `cancelTask()` returns whether the task was directly cancelled or a review request was submitted, and the UI shows the appropriate message.

**Tech Stack:** Python/FastAPI (backend), Stripe API, Flutter/Dart + BLoC (frontend)

---

### Task 1: Backend — Auto-refund in `cancel_task()` when paid task is cancelled

**Files:**
- Modify: `backend/app/crud/task.py:478-624` (`cancel_task` function)

**Step 1: Add refund logic after `task.status = "cancelled"`**

In `backend/app/crud/task.py`, after line 509 (`task.status = "cancelled"`), add a block that handles Stripe refund for paid tasks when `is_admin_review=True`:

```python
    task.status = "cancelled"

    # Auto-refund for paid tasks cancelled via admin/CS review
    if is_admin_review and getattr(task, 'is_paid', 0) == 1 and task.payment_intent_id:
        try:
            import stripe
            from decimal import Decimal
            import hashlib

            if stripe.api_key:
                charges = stripe.Charge.list(payment_intent=task.payment_intent_id, limit=1)
                if charges.data:
                    charge_id = charges.data[0].id
                    escrow = Decimal(str(task.escrow_amount)) if task.escrow_amount else Decimal('0')
                    refund_amount_pence = int(escrow * 100)

                    if refund_amount_pence > 0:
                        idempotency_key = hashlib.sha256(
                            f"cancel_refund_{task.id}_{refund_amount_pence}".encode()
                        ).hexdigest()

                        refund = stripe.Refund.create(
                            charge=charge_id,
                            amount=refund_amount_pence,
                            reason="requested_by_customer",
                            idempotency_key=idempotency_key,
                            metadata={
                                "task_id": str(task.id),
                                "cancel_refund": "true",
                                "poster_id": str(task.poster_id),
                            }
                        )
                        task.is_paid = 0
                        task.payment_intent_id = None
                        task.escrow_amount = 0.0
                        logger.info(f"Auto-refund on cancel: task={task.id}, refund={refund.id}, amount={refund_amount_pence}p")
                    else:
                        logger.warning(f"Task {task.id} is_paid=1 but escrow_amount=0, skipping refund")
                else:
                    logger.warning(f"No charges found for PaymentIntent {task.payment_intent_id}, cannot refund")
            else:
                logger.warning(f"Stripe API key not configured, cannot auto-refund task {task.id}")
        except Exception as e:
            logger.error(f"Auto-refund failed for task {task.id}: {e}", exc_info=True)
            # Do NOT block cancellation — admin can handle refund manually
```

Key design decisions:
- Only triggers when `is_admin_review=True` (CS/admin approved the cancel request)
- Uses `escrow_amount` as refund amount (this is the actual held amount after platform fee)
- Idempotency key prevents duplicate refunds
- Failure is logged but does NOT prevent the cancellation from going through
- Clears `is_paid`, `payment_intent_id`, `escrow_amount` on success

**Step 2: Verify no import issues**

The file already imports `logger` at module level. `stripe`, `Decimal`, and `hashlib` are imported inline to avoid adding top-level imports to a file that doesn't currently use them.

**Step 3: Commit**

```bash
git add backend/app/crud/task.py
git commit -m "fix(backend): auto-refund when paid task is cancelled via CS review"
```

---

### Task 2: Flutter — Repository returns cancel result type

**Files:**
- Modify: `link2ur/lib/data/repositories/task_repository.dart:498-512`

**Step 1: Change `cancelTask()` to return whether it was a direct cancel or review request**

Change from `Future<void>` to `Future<bool>` — returns `true` if directly cancelled, `false` if a review request was submitted.

```dart
  /// 取消任务
  /// Returns true if task was directly cancelled, false if cancel request was submitted for review
  Future<bool> cancelTask(int taskId, {String? reason}) async {
    final response = await _apiService.post(
      ApiEndpoints.cancelTask(taskId),
      data: {
        if (reason != null) 'reason': reason,
      },
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '取消任务失败');
    }

    await _cache.invalidateTaskDetailCache(taskId);
    await _cache.invalidateAllTasksCache();

    // Backend returns {message, request_id} for review requests
    // and a task object for direct cancellations
    final data = response.data;
    if (data is Map && data.containsKey('request_id')) {
      return false; // Review request submitted
    }
    return true; // Directly cancelled
  }
```

**Step 2: Commit**

```bash
git add link2ur/lib/data/repositories/task_repository.dart
git commit -m "fix(flutter): cancelTask returns direct-cancel vs review-submitted"
```

---

### Task 3: Flutter — BLoC emits correct action message

**Files:**
- Modify: `link2ur/lib/features/tasks/bloc/task_detail_bloc.dart:765-790`

**Step 1: Update `_onCancelRequested` to use the return value**

```dart
  Future<void> _onCancelRequested(
    TaskDetailCancelRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      final directlyCancelled = await _taskRepository.cancelTask(
        _taskId!,
        reason: event.reason,
      );
      final task = await _refreshTask();
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: directlyCancelled ? 'task_cancelled' : 'cancel_request_submitted',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'cancel_failed',
        errorMessage: e.toString(),
      ));
    }
  }
```

**Step 2: Commit**

```bash
git add link2ur/lib/features/tasks/bloc/task_detail_bloc.dart
git commit -m "fix(flutter): BLoC distinguishes cancel vs review-submitted"
```

---

### Task 4: Flutter — Add l10n strings and UI mapping

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb:4012`
- Modify: `link2ur/lib/l10n/app_zh.arb:3930`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb:3869`
- Modify: `link2ur/lib/features/tasks/views/task_detail_view.dart:162`

**Step 1: Add l10n key in all three ARB files**

In `app_en.arb`, after line 4012 (`"actionTaskCancelled": "Task cancelled",`):
```json
  "actionCancelRequestSubmitted": "Cancel request submitted, awaiting review",
```

In `app_zh.arb`, after line 3930 (`"actionTaskCancelled": "任务已取消",`):
```json
  "actionCancelRequestSubmitted": "取消申请已提交，等待审核",
```

In `app_zh_Hant.arb`, after line 3869 (`"actionTaskCancelled": "任務已取消",`):
```json
  "actionCancelRequestSubmitted": "取消申請已提交，等待審核",
```

**Step 2: Run gen-l10n to regenerate dart files**

```powershell
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter gen-l10n
```

**Step 3: Add the new action message case in `task_detail_view.dart`**

In the `switch (state.actionMessage)` block at line 162, after `'task_cancelled' => l10n.actionTaskCancelled,`:

```dart
            'cancel_request_submitted' => l10n.actionCancelRequestSubmitted,
```

**Step 4: Commit**

```bash
git add link2ur/lib/l10n/ link2ur/lib/features/tasks/views/task_detail_view.dart
git commit -m "fix(flutter): show correct message for cancel request vs direct cancel"
```

---

### Task 5: Verify and final commit

**Step 1: Run flutter analyze**

```powershell
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze
```

Expected: no new errors.

**Step 2: Run existing tests**

```powershell
cd link2ur && $env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter test
```

Expected: all existing tests pass.
