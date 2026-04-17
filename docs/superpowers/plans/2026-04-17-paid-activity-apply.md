# Paid Activity Apply — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable Stripe payment for paid lottery/first_come activities: create PaymentIntent on apply, confirm via webhook, auto-create application, async transfer to expert team.

**Architecture:** Modify the apply endpoint to create a Stripe PaymentIntent when price > 0, returning `client_secret` for Flutter to present the payment sheet. Extend the existing webhook handler to recognize activity payments via metadata, create the application, and schedule a transfer. On Flutter, modify the repository to return response data and the BLoC to trigger payment when needed.

**Tech Stack:** Python/FastAPI, Stripe API, SQLAlchemy, existing webhook + PaymentTransfer infrastructure, Flutter Stripe SDK

**Spec:** `docs/superpowers/specs/2026-04-17-paid-activity-apply-design.md`

---

## File Structure

| Action | File | Responsibility |
|---|---|---|
| Create | `backend/migrations/206_activity_apply_payment_fields.sql` | Add columns + update CHECK constraint |
| Modify | `backend/app/models.py:2250-2270` | Add columns to OfficialActivityApplication model |
| Modify | `backend/app/official_activity_routes.py:44-141` | PaymentIntent creation in apply endpoint |
| Modify | `backend/app/routers.py:~7000` | Webhook handler for activity payments |
| Modify | `link2ur/lib/data/repositories/activity_repository.dart:232-243` | Return response data from apply |
| Modify | `link2ur/lib/features/activity/bloc/activity_bloc.dart:239-261,457-472` | Inject PaymentService, handle payment flow |

---

### Task 1: DB Migration — application payment fields + status update

**Files:**
- Create: `backend/migrations/206_activity_apply_payment_fields.sql`

- [ ] **Step 1: Write the migration**

```sql
-- 206_activity_apply_payment_fields.sql
-- Add payment fields to official_activity_applications
-- and extend status CHECK to include 'payment_pending' and 'refunded'

ALTER TABLE official_activity_applications
    ADD COLUMN IF NOT EXISTS payment_intent_id VARCHAR(255) DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS amount_paid INTEGER DEFAULT NULL;

-- Update CHECK constraint to include new statuses
ALTER TABLE official_activity_applications
    DROP CONSTRAINT IF EXISTS ck_official_app_status;
ALTER TABLE official_activity_applications
    ADD CONSTRAINT ck_official_app_status
    CHECK (status IN ('payment_pending', 'pending', 'won', 'lost', 'attending', 'refunded'));
```

- [ ] **Step 2: Commit**

```bash
git add backend/migrations/206_activity_apply_payment_fields.sql
git commit -m "migration(206): add payment fields to official_activity_applications"
```

---

### Task 2: Update OfficialActivityApplication model

**Files:**
- Modify: `backend/app/models.py:2250-2270`

- [ ] **Step 1: Add columns to OfficialActivityApplication model**

In `models.py`, find the `OfficialActivityApplication` class. After the `notified_at` column (line ~2260), add:

```python
    payment_intent_id = Column(String(255), nullable=True)
    amount_paid = Column(Integer, nullable=True)  # pence
```

- [ ] **Step 2: Update the CHECK constraint in `__table_args__`**

Replace the existing status CHECK:

```python
        CheckConstraint(
            "status IN ('payment_pending','pending','won','lost','attending','refunded')",
            name="ck_official_app_status"
        ),
```

- [ ] **Step 3: Verify import**

```bash
cd backend && python -c "from app.models import OfficialActivityApplication; print(OfficialActivityApplication.__table__.columns.keys())"
```

Expected: includes `payment_intent_id` and `amount_paid`

- [ ] **Step 4: Commit**

```bash
git add backend/app/models.py
git commit -m "feat: add payment_intent_id and amount_paid to OfficialActivityApplication"
```

---

### Task 3: Rewrite apply endpoint for payment support

**Files:**
- Modify: `backend/app/official_activity_routes.py`

This is the core backend change. The current apply endpoint (lines 44-141) needs to:
- For free activities: keep existing behavior (create application immediately)
- For paid activities: create PaymentIntent, create application with `payment_pending` status, return client_secret

- [ ] **Step 1: Read the current file**

Read `backend/app/official_activity_routes.py` fully.

- [ ] **Step 2: Replace the apply endpoint function**

Replace the `apply_official_activity` function (from `@official_activity_router.post("/{activity_id}/apply"` to the end of its return statement including the by_count trigger block) with:

```python
@official_activity_router.post("/{activity_id}/apply", response_model=dict)
async def apply_official_activity(
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """报名官方/达人活动（抽奖/抢位均用此接口）。

    免费活动：直接创建 application。
    付费活动：创建 Stripe PaymentIntent，返回 client_secret，
              webhook 确认后自动创建 application。
    """
    import stripe
    from app.stripe_config import stripe  as _  # ensure stripe.api_key is set

    result = await db.execute(
        select(models.Activity).where(
            models.Activity.id == activity_id,
            models.Activity.activity_type.in_(["lottery", "first_come"]),
            models.Activity.status == "open",
        )
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="活动不存在或已结束")

    # Check for duplicate application (any status except refunded)
    existing = await db.execute(
        select(models.OfficialActivityApplication).where(
            models.OfficialActivityApplication.activity_id == activity_id,
            models.OfficialActivityApplication.user_id == current_user.id,
            models.OfficialActivityApplication.status != 'refunded',
        )
    )
    existing_app = existing.scalar_one_or_none()

    # If already has a payment_pending application, return existing client_secret
    if existing_app and existing_app.status == 'payment_pending' and existing_app.payment_intent_id:
        try:
            pi = stripe.PaymentIntent.retrieve(existing_app.payment_intent_id)
            if pi.status in ('requires_payment_method', 'requires_confirmation', 'requires_action'):
                return {
                    "success": True,
                    "requires_payment": True,
                    "client_secret": pi.client_secret,
                    "payment_intent_id": pi.id,
                    "amount": pi.amount,
                    "currency": (activity.currency or "GBP").upper(),
                }
        except Exception:
            pass  # PI expired or invalid, will create new one below
        # Clean up stale payment_pending record
        await db.delete(existing_app)
        await db.commit()
        existing_app = None

    if existing_app:
        raise HTTPException(status_code=400, detail="您已报名此活动")

    price_pence = int(round(float(activity.original_price_per_participant or 0) * 100))
    is_paid = price_pence > 0

    # ── FREE activity: create application immediately ──
    if not is_paid:
        if activity.activity_type == "first_come":
            count_result = await db.execute(
                select(func.count()).select_from(models.OfficialActivityApplication).where(
                    models.OfficialActivityApplication.activity_id == activity_id,
                    models.OfficialActivityApplication.status == "attending",
                )
            )
            current_count = count_result.scalar() or 0
            if current_count >= (activity.prize_count or 0):
                raise HTTPException(status_code=400, detail="名额已满")
            app_status = "attending"
        else:
            app_status = "pending"

        application = models.OfficialActivityApplication(
            activity_id=activity_id,
            user_id=current_user.id,
            status=app_status,
        )
        db.add(application)
        await db.commit()

        # by_count trigger for free lottery
        await _check_by_count_trigger(db, activity, activity_id)

        return {
            "success": True,
            "requires_payment": False,
            "status": app_status,
            "message": "报名成功，等待开奖" if app_status == "pending" else "报名成功！",
        }

    # ── PAID activity: create PaymentIntent ──
    from app.utils.fee_calculator import calculate_application_fee_pence
    application_fee_pence = calculate_application_fee_pence(
        price_pence, task_source="expert_activity", task_type=activity.task_type
    )

    # Get or create Stripe Customer + EphemeralKey
    customer_id = None
    ephemeral_key_secret = None
    try:
        from app.utils.stripe_utils import get_or_create_stripe_customer
        from sqlalchemy.orm import Session as SyncSession
        # get_or_create_stripe_customer is sync; run in executor for async context
        import asyncio
        loop = asyncio.get_event_loop()
        customer_id = await loop.run_in_executor(
            None, lambda: get_or_create_stripe_customer(current_user)
        )
        ephemeral_key = stripe.EphemeralKey.create(
            customer=customer_id,
            stripe_version="2025-01-27.acacia",
        )
        ephemeral_key_secret = ephemeral_key.secret
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning(f"Stripe Customer/EphemeralKey failed: {e}")
        customer_id = None
        ephemeral_key_secret = None

    create_kw = {
        "amount": price_pence,
        "currency": (activity.currency or "GBP").lower(),
        "payment_method_types": ["card"],
        "metadata": {
            "activity_id": str(activity.id),
            "user_id": str(current_user.id),
            "activity_apply": "true",
            "application_fee": str(application_fee_pence),
            "expert_id": activity.owner_id or "",
            "expert_user_id": activity.expert_id or "",
        },
        "description": f"活动报名 #{activity.id} - {activity.title}",
    }
    if customer_id:
        create_kw["customer"] = customer_id

    payment_intent = stripe.PaymentIntent.create(**create_kw)

    # Create payment_pending application
    application = models.OfficialActivityApplication(
        activity_id=activity_id,
        user_id=current_user.id,
        status="payment_pending",
        payment_intent_id=payment_intent.id,
        amount_paid=price_pence,
    )
    db.add(application)
    await db.commit()

    return {
        "success": True,
        "requires_payment": True,
        "client_secret": payment_intent.client_secret,
        "payment_intent_id": payment_intent.id,
        "amount": price_pence,
        "currency": (activity.currency or "GBP").upper(),
        "customer_id": customer_id,
        "ephemeral_key_secret": ephemeral_key_secret,
    }


async def _check_by_count_trigger(db: AsyncSession, activity, activity_id: int):
    """Check and trigger by_count auto-draw if threshold reached."""
    if (
        activity.activity_type == "lottery"
        and activity.draw_mode == "auto"
        and activity.draw_trigger in ("by_count", "both")
        and not activity.is_drawn
        and activity.draw_participant_count
    ):
        count_result = await db.execute(
            select(func.count()).select_from(models.OfficialActivityApplication).where(
                models.OfficialActivityApplication.activity_id == activity_id,
                models.OfficialActivityApplication.status == "pending",
            )
        )
        pending_count = count_result.scalar() or 0
        if pending_count >= activity.draw_participant_count:
            locked_result = await db.execute(
                select(models.Activity)
                .where(models.Activity.id == activity_id)
                .with_for_update()
            )
            locked_activity = locked_result.scalar_one_or_none()
            if locked_activity and not locked_activity.is_drawn:
                from app.draw_logic import perform_draw_async
                try:
                    await perform_draw_async(db, locked_activity)
                except Exception:
                    import logging
                    logging.getLogger(__name__).error(
                        f"by_count auto-draw failed for activity {activity_id}", exc_info=True
                    )
```

- [ ] **Step 3: Add `stripe_config` import at the top of the file**

At the top of `official_activity_routes.py`, add:

```python
import stripe
from app.stripe_config import stripe as _stripe_configured  # noqa: F401 — side-effect import sets stripe.api_key
```

- [ ] **Step 4: Verify the file parses**

```bash
cd backend && python -c "from app.official_activity_routes import official_activity_router; print('OK')"
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/official_activity_routes.py
git commit -m "feat: create PaymentIntent for paid activity apply, keep free flow unchanged"
```

---

### Task 4: Extend webhook handler for activity payments

**Files:**
- Modify: `backend/app/routers.py` (in the `payment_intent.succeeded` handler section, around line 7000)

- [ ] **Step 1: Read the webhook handler**

Read `backend/app/routers.py` around lines 6990-7150 to find the `payment_intent.succeeded` handler.

- [ ] **Step 2: Add activity payment handling after the existing task payment block**

After the existing `if task_id:` block ends (and before any `else` or next event type), add a new block:

```python
        # ── Activity apply payment ──
        activity_apply = metadata.get("activity_apply")
        if activity_apply == "true" and not task_id:
            _activity_id = _safe_int_metadata(payment_intent, "activity_id")
            _user_id = metadata.get("user_id")
            _expert_id = metadata.get("expert_id")
            _expert_user_id = metadata.get("expert_user_id")

            if _activity_id and _user_id:
                try:
                    # Find the payment_pending application
                    app_query = select(models.OfficialActivityApplication).where(
                        models.OfficialActivityApplication.activity_id == _activity_id,
                        models.OfficialActivityApplication.user_id == _user_id,
                        models.OfficialActivityApplication.payment_intent_id == payment_intent_id,
                        models.OfficialActivityApplication.status == "payment_pending",
                    ).with_for_update()
                    app_row = db.execute(app_query).scalar_one_or_none()

                    if app_row:
                        # Load activity
                        act = db.execute(
                            select(models.Activity).where(models.Activity.id == _activity_id).with_for_update()
                        ).scalar_one_or_none()

                        if act and act.activity_type == "first_come":
                            # Check slots
                            from sqlalchemy import func as sa_func
                            attending_count = db.execute(
                                select(sa_func.count()).select_from(models.OfficialActivityApplication).where(
                                    models.OfficialActivityApplication.activity_id == _activity_id,
                                    models.OfficialActivityApplication.status == "attending",
                                )
                            ).scalar() or 0
                            if attending_count >= (act.prize_count or 0):
                                # Full — refund
                                try:
                                    stripe.Refund.create(payment_intent=payment_intent_id)
                                    app_row.status = "refunded"
                                    logger.info(f"Activity {_activity_id} full, refunded PI {payment_intent_id}")
                                except Exception as refund_err:
                                    logger.error(f"Refund failed for PI {payment_intent_id}: {refund_err}")
                                    app_row.status = "refunded"  # mark anyway, manual reconciliation
                            else:
                                app_row.status = "attending"
                        elif act and act.activity_type == "lottery":
                            app_row.status = "pending"
                        else:
                            app_row.status = "pending"

                        app_row.amount_paid = payment_intent.get("amount")

                        # Create PaymentHistory
                        from app.utils.fee_calculator import calculate_application_fee_pence
                        amount_pence = payment_intent.get("amount", 0)
                        application_fee_pence = calculate_application_fee_pence(
                            amount_pence,
                            task_source="expert_activity",
                            task_type=getattr(act, "task_type", None) if act else None,
                        )
                        taker_amount_pence = max(0, amount_pence - application_fee_pence)

                        import uuid
                        order_no = f"ACT{_activity_id}-{uuid.uuid4().hex[:12]}"
                        payment_history = models.PaymentHistory(
                            order_no=order_no,
                            user_id=_user_id,
                            payment_intent_id=payment_intent_id,
                            payment_method="stripe",
                            total_amount=amount_pence,
                            stripe_amount=amount_pence,
                            final_amount=amount_pence,
                            currency=(act.currency if act else "GBP") or "GBP",
                            status="succeeded",
                            application_fee=application_fee_pence,
                            escrow_amount=taker_amount_pence / 100.0,
                            extra_metadata={"activity_id": _activity_id, "activity_apply": True},
                        )
                        db.add(payment_history)

                        # Create PaymentTransfer for async payout to expert team
                        if app_row.status != "refunded" and _expert_id and taker_amount_pence > 0:
                            transfer_record = models.PaymentTransfer(
                                taker_id=_expert_user_id or _user_id,
                                taker_expert_id=_expert_id,
                                poster_id=_user_id,
                                amount=taker_amount_pence / 100.0,
                                currency=(act.currency if act else "GBP") or "GBP",
                                status="pending",
                                idempotency_key=f"act-{_activity_id}-{payment_intent_id}",
                                extra_metadata={"activity_id": _activity_id, "payment_intent_id": payment_intent_id},
                            )
                            db.add(transfer_record)

                        db.commit()
                        logger.info(f"Activity payment confirmed: activity={_activity_id}, user={_user_id}, status={app_row.status}")

                        # by_count trigger check (sync version for webhook context)
                        if (
                            act and act.activity_type == "lottery"
                            and act.draw_mode == "auto"
                            and act.draw_trigger in ("by_count", "both")
                            and not act.is_drawn
                            and act.draw_participant_count
                        ):
                            pending_count = db.execute(
                                select(sa_func.count()).select_from(models.OfficialActivityApplication).where(
                                    models.OfficialActivityApplication.activity_id == _activity_id,
                                    models.OfficialActivityApplication.status == "pending",
                                )
                            ).scalar() or 0
                            if pending_count >= act.draw_participant_count:
                                from app.draw_logic import perform_draw_sync
                                try:
                                    perform_draw_sync(db, act)
                                    logger.info(f"by_count auto-draw triggered for activity {_activity_id}")
                                except Exception as draw_err:
                                    logger.error(f"by_count auto-draw failed: {draw_err}")

                except Exception as e:
                    logger.error(f"Activity payment webhook error: activity={_activity_id}, error={e}", exc_info=True)
                    try:
                        db.rollback()
                    except Exception:
                        pass
```

Note: The webhook handler in `routers.py` uses **sync** DB session (`Session`, not `AsyncSession`), so we use `db.execute()` directly (no `await`). The `perform_draw_sync` is the correct function here.

- [ ] **Step 3: Verify the metadata helper exists**

Check that `_safe_int_metadata` is defined in the webhook handler scope. It should be — it's used for `task_id` already.

- [ ] **Step 4: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat: handle activity payment in webhook — create application, PaymentHistory, PaymentTransfer"
```

---

### Task 5: Flutter — modify repository and BLoC for payment flow

**Files:**
- Modify: `link2ur/lib/data/repositories/activity_repository.dart:232-243`
- Modify: `link2ur/lib/features/activity/bloc/activity_bloc.dart:239-261,457-472`

- [ ] **Step 1: Change `applyOfficialActivity` to return response data**

In `activity_repository.dart`, replace the `applyOfficialActivity` method:

```dart
  /// 申请官方/达人活动（抽奖/先到先得）
  /// 返回 response data，可能包含 requires_payment + client_secret
  Future<Map<String, dynamic>> applyOfficialActivity(int activityId) async {
    final response = await _apiService.post(
      ApiEndpoints.officialActivityApply(activityId),
    );
    if (!response.isSuccess) {
      final msg = (response.message ?? '').toLowerCase();
      if (msg.contains('已满') || msg.contains('full') || msg.contains('no more')) {
        throw const ActivityFullException();
      }
      throw ActivityException(
        response.errorCode ?? response.message ?? 'activity_official_apply_failed',
        code: response.errorCode,
      );
    }
    return response.data as Map<String, dynamic>? ?? {'success': true};
  }
```

- [ ] **Step 2: Inject PaymentService into ActivityBloc**

In `activity_bloc.dart`, modify the constructor:

```dart
class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  ActivityBloc({
    required ActivityRepository activityRepository,
    TaskExpertRepository? taskExpertRepository,
    PaymentService? paymentService,
  })  : _activityRepository = activityRepository,
        _taskExpertRepository = taskExpertRepository,
        _paymentService = paymentService,
        super(const ActivityState()) {
```

Add the field:

```dart
  final PaymentService? _paymentService;
```

Add the import at the top:

```dart
import '../../../data/services/payment_service.dart';
```

- [ ] **Step 3: Rewrite `_onApplyOfficial` to handle payment**

Replace the `_onApplyOfficial` method:

```dart
  Future<void> _onApplyOfficial(
    ActivityApplyOfficial event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.applying));
    try {
      final result = await _activityRepository.applyOfficialActivity(event.activityId);

      // Check if payment is required
      if (result['requires_payment'] == true) {
        final clientSecret = result['client_secret'] as String?;
        if (clientSecret == null || _paymentService == null) {
          emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.error));
          return;
        }

        final paid = await _paymentService!.presentPaymentSheet(
          clientSecret: clientSecret,
          customerId: result['customer_id'] as String?,
          ephemeralKeySecret: result['ephemeral_key_secret'] as String?,
        );

        if (paid) {
          // Payment succeeded — webhook will create application on backend
          emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.applied));
          add(ActivityLoadDetail(event.activityId));
        } else {
          // User cancelled payment
          emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.idle));
        }
        return;
      }

      // Free activity — already applied
      emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.applied));
      add(ActivityLoadDetail(event.activityId));
    } on ActivityFullException {
      emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.full));
    } on Exception {
      emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.error));
    }
  }
```

- [ ] **Step 4: Update ActivityBloc instantiation to pass PaymentService**

Find where `ActivityBloc` is instantiated. It's likely in a route builder or the activity detail view. Search for `ActivityBloc(` and add `paymentService: PaymentService()` (or get it from context if it's provided). The `PaymentService` is a singleton — check if it's `PaymentService()` or `PaymentService.instance` or from a RepositoryProvider.

Search the codebase: `grep -rn "ActivityBloc(" link2ur/lib/`

Add `paymentService:` parameter wherever ActivityBloc is constructed.

- [ ] **Step 5: Verify compilation**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze lib/features/activity/ lib/data/repositories/activity_repository.dart
```

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/data/repositories/activity_repository.dart link2ur/lib/features/activity/
git commit -m "feat(flutter): handle paid activity apply — present Stripe sheet, confirm via webhook"
```

---

### Task 6: Verify full stack + smoke test

- [ ] **Step 1: Backend import verification**

```bash
cd backend && python -c "
from app.official_activity_routes import official_activity_router, _check_by_count_trigger
from app.models import OfficialActivityApplication
print('Backend OK')
"
```

- [ ] **Step 2: Flutter analyze**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze
```

- [ ] **Step 3: Cross-layer verification**

Verify the chain:
- Backend `apply` returns `{requires_payment, client_secret, payment_intent_id, amount, currency, customer_id, ephemeral_key_secret}` ✓
- Flutter `applyOfficialActivity` returns `Map<String, dynamic>` with these keys ✓
- BLoC checks `result['requires_payment']` and calls `PaymentService.presentPaymentSheet` ✓
- Webhook handler checks `metadata['activity_apply'] == 'true'` and creates application ✓
- `payment_pending` status is in both model CHECK constraint and migration ✓

- [ ] **Step 4: Commit any fixes**

```bash
git add -A && git commit -m "fix: resolve issues from paid activity apply verification"
```
