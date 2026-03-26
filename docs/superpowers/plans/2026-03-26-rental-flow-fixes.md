# Rental Flow Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 6 issues in the flea market rental flow: overdue auto-detection with notifications, counter-offer price validation, rental detail owner role fix, duration unit display, pending_return auto-refund timeout, and rental request expiry notification.

**Architecture:** Add a scheduled task for overdue detection + pending_return timeout. Backend returns `seller_id` in rental detail for accurate role detection. Frontend fixes for duration unit display. All changes are backward-compatible.

**Tech Stack:** Python/FastAPI (backend), Flutter/BLoC (frontend), SQLAlchemy, TaskScheduler

---

### Task 1: Backend — Overdue auto-detection scheduled task with notifications

Add a new scheduled task that runs every hour, finds active rentals past `end_date`, marks them as `overdue`, and notifies both renter and seller.

**Files:**
- Create: `backend/app/rental_scheduled_tasks.py`
- Modify: `backend/app/task_scheduler.py:1167-1175` (register new task)

- [ ] **Step 1: Create `rental_scheduled_tasks.py`**

```python
"""
跳蚤市场租赁定时任务
- 检查逾期租赁（active → overdue）
- 检查 pending_return 超时（超过7天自动退押金并完成）
"""
import logging
from datetime import timedelta
from sqlalchemy.orm import Session
from sqlalchemy import and_, update, select

from app import models
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


def check_overdue_rentals(db: Session):
    """检查逾期租赁：active 状态且 end_date < now → 标记为 overdue，通知双方"""
    now = get_utc_time()

    overdue_rentals = db.query(models.FleaMarketRental).filter(
        and_(
            models.FleaMarketRental.status == "active",
            models.FleaMarketRental.end_date < now,
        )
    ).limit(200).all()

    if not overdue_rentals:
        return 0

    count = 0
    for rental in overdue_rentals:
        try:
            rental.status = "overdue"

            # 获取物品信息用于通知
            item = db.query(models.FleaMarketItem).filter(
                models.FleaMarketItem.id == rental.item_id
            ).first()

            item_title = item.title if item else f"物品#{rental.item_id}"
            seller_id = item.seller_id if item else None

            # 通知租客：租赁已逾期
            _create_notification_sync(
                db, rental.renter_id,
                "flea_market_rental_overdue",
                "租赁已逾期",
                f"您租借的「{item_title}」已超过租赁期限，请尽快归还。",
                str(rental.id),
            )

            # 通知物主：租赁已逾期
            if seller_id:
                _create_notification_sync(
                    db, seller_id,
                    "flea_market_rental_overdue",
                    "租赁已逾期",
                    f"「{item_title}」的租赁已超过期限，租客尚未归还。",
                    str(rental.id),
                )

            count += 1
        except Exception as e:
            logger.error(f"处理逾期租赁 {rental.id} 失败: {e}")

    if count > 0:
        db.commit()
        logger.info(f"标记 {count} 个租赁为逾期")

    return count


def check_pending_return_timeout(db: Session):
    """检查 pending_return 超时：超过7天物主未确认 → 自动完成归还并退押金

    注意：自动退押金需要 Stripe refund，这里只标记状态并通知，
    实际退押金通过异步接口由管理员或后续 webhook 处理。
    """
    now = get_utc_time()
    timeout_threshold = now - timedelta(days=7)

    # 查找超过7天的 pending_return 租赁
    timeout_rentals = db.query(models.FleaMarketRental).filter(
        and_(
            models.FleaMarketRental.status == "pending_return",
            models.FleaMarketRental.updated_at < timeout_threshold,
        )
    ).limit(100).all()

    if not timeout_rentals:
        return 0

    count = 0
    for rental in timeout_rentals:
        try:
            item = db.query(models.FleaMarketItem).filter(
                models.FleaMarketItem.id == rental.item_id
            ).first()
            item_title = item.title if item else f"物品#{rental.item_id}"
            seller_id = item.seller_id if item else None

            # 自动完成归还
            rental.status = "returned"
            rental.returned_at = now

            # 尝试退押金
            deposit_pence = int(float(rental.deposit_amount) * 100)
            if deposit_pence > 0 and rental.task_id:
                try:
                    task = db.query(models.Task).filter(models.Task.id == rental.task_id).first()
                    if task and task.payment_intent_id:
                        import stripe
                        refund = stripe.Refund.create(
                            payment_intent=task.payment_intent_id,
                            amount=deposit_pence,
                        )
                        rental.stripe_refund_id = refund.id
                        rental.deposit_status = "refunded"
                        logger.info(f"租赁 {rental.id} 自动退押金成功: {refund.id}")
                except Exception as e:
                    logger.error(f"租赁 {rental.id} 自动退押金失败: {e}")

            # 租金入账到物主钱包
            from decimal import Decimal
            gross_rent = Decimal(str(rental.total_rent))
            if gross_rent > 0 and seller_id:
                try:
                    from app.utils.fee_calculator import calculate_application_fee_decimal
                    fee_amount = calculate_application_fee_decimal(
                        gross_rent, task_source="flea_market_rental"
                    )
                    net_rent = gross_rent - fee_amount
                    from app.wallet_service import credit_wallet
                    credit_wallet(
                        db=db,
                        user_id=seller_id,
                        amount=net_rent,
                        source="flea_market_rental",
                        related_id=str(rental.id),
                        related_type="rental",
                        description=f"租赁 #{rental.id} 租金收入（自动确认）— {item_title}",
                        fee_amount=fee_amount,
                        gross_amount=gross_rent,
                        currency=rental.currency or "GBP",
                        idempotency_key=f"earning:rental:{rental.id}:owner:{seller_id}",
                    )
                except Exception as e:
                    logger.error(f"租赁 {rental.id} 自动租金入账失败: {e}")

            # 通知租客
            _create_notification_sync(
                db, rental.renter_id,
                "flea_market_rental_auto_returned",
                "租赁自动确认归还",
                f"物主超过7天未确认「{item_title}」的归还，系统已自动完成归还"
                + ("，押金已退还。" if rental.deposit_status == "refunded" else "。"),
                str(rental.id),
            )

            # 通知物主
            if seller_id:
                _create_notification_sync(
                    db, seller_id,
                    "flea_market_rental_auto_returned",
                    "租赁自动确认归还",
                    f"您超过7天未确认「{item_title}」的归还，系统已自动完成。",
                    str(rental.id),
                )

            count += 1
        except Exception as e:
            logger.error(f"处理 pending_return 超时租赁 {rental.id} 失败: {e}")

    if count > 0:
        db.commit()
        logger.info(f"自动确认归还 {count} 个超时租赁")

    return count


def _create_notification_sync(
    db: Session,
    user_id: str,
    notification_type: str,
    title: str,
    content: str,
    related_id: str,
):
    """同步创建通知（用于定时任务）"""
    try:
        notification = models.Notification(
            user_id=user_id,
            type=notification_type,
            title=title,
            content=content,
            related_id=related_id,
        )
        db.add(notification)
        db.flush()
    except Exception as e:
        logger.error(f"创建租赁通知失败: {e}")
```

- [ ] **Step 2: Register tasks in `task_scheduler.py`**

In `task_scheduler.py`, before the final `logger.info(...)` line (~line 1174), add:

```python
    # ========== 租赁定时任务 ==========

    # 检查逾期租赁 - 每小时
    def check_overdue_rentals_task():
        from app.rental_scheduled_tasks import check_overdue_rentals
        with_db(check_overdue_rentals)()

    scheduler.register_task(
        'check_overdue_rentals',
        check_overdue_rentals_task,
        interval_seconds=3600,  # 每小时
        description="检查逾期租赁并通知"
    )

    # 检查 pending_return 超时 - 每6小时
    def check_pending_return_timeout_task():
        from app.rental_scheduled_tasks import check_pending_return_timeout
        with_db(check_pending_return_timeout)()

    scheduler.register_task(
        'check_pending_return_timeout',
        check_pending_return_timeout_task,
        interval_seconds=21600,  # 每6小时
        description="检查租赁归还确认超时"
    )
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/rental_scheduled_tasks.py backend/app/task_scheduler.py
git commit -m "feat: add rental overdue detection and pending_return timeout scheduled tasks"
```

---

### Task 2: Backend — Counter-offer price validation

Add validation that `counter_rental_price > 0` in the counter-offer endpoint.

**Files:**
- Modify: `backend/app/flea_market_rental_routes.py:701-777`

- [ ] **Step 1: Add validation after `counter_rental_price` parameter**

In `counter_offer_rental_request()`, after the status check (`if rental_request.status != "pending"`) block (~line 726), add:

```python
        # 还价金额必须大于0
        if counter_rental_price <= 0:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="还价金额必须大于0"
            )
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/flea_market_rental_routes.py
git commit -m "fix: validate counter_rental_price > 0 in rental counter-offer"
```

---

### Task 3: Backend — Return `seller_id` in rental detail API

Add `seller_id` to `FleaMarketRentalResponse` and populate it in the rental detail and my-rentals endpoints, so the frontend can accurately determine the owner.

**Files:**
- Modify: `backend/app/schemas.py:2932-2951` (add `seller_id` field)
- Modify: `backend/app/flea_market_rental_routes.py:1186-1204` (detail endpoint)
- Modify: `backend/app/flea_market_rental_routes.py:1291-1307` (my-rentals endpoint)

- [ ] **Step 1: Add `seller_id` to schema**

In `FleaMarketRentalResponse` class, add after `renter_avatar`:

```python
    seller_id: Optional[str] = None
```

- [ ] **Step 2: Populate `seller_id` in rental detail endpoint**

In `get_rental_detail()`, the `FleaMarketRentalResponse(...)` call (~line 1186), add:

```python
            seller_id=item.seller_id if item else None,
```

- [ ] **Step 3: Populate `seller_id` in my-rentals endpoint**

In `get_my_rentals()`, the `FleaMarketRentalResponse(...)` call (~line 1291), add:

```python
                    seller_id=item_info_map.get(r.item_id, {}).get("seller_id"),
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/schemas.py backend/app/flea_market_rental_routes.py
git commit -m "feat: return seller_id in rental detail API for accurate owner detection"
```

---

### Task 4: Backend — Add `updated_at` column to FleaMarketRental model

The `pending_return` timeout check needs `updated_at` to know when the status last changed. Currently the model lacks this field.

**Files:**
- Modify: `backend/app/models.py:1937-1973` (add `updated_at` column)
- Create: `backend/migrations/XXX_add_rental_updated_at.sql`

- [ ] **Step 1: Add `updated_at` to FleaMarketRental model**

In `FleaMarketRental` class, after the `created_at` line (~line 1958), add:

```python
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)
```

- [ ] **Step 2: Find next migration number**

Check existing migrations directory for the next sequence number.

- [ ] **Step 3: Create migration SQL**

```sql
-- Add updated_at column to flea_market_rentals for tracking status change time
ALTER TABLE flea_market_rentals
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Backfill: set updated_at = created_at for existing rows
UPDATE flea_market_rentals SET updated_at = created_at WHERE updated_at IS NULL;
```

- [ ] **Step 4: Also update `updated_at` in `renter_confirm_return`**

In `renter_confirm_return()` (~line 948), add `updated_at` to the values dict so the timeout check works:

Change:
```python
            .values(status="pending_return")
```
To:
```python
            .values(status="pending_return", updated_at=now)
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/models.py backend/migrations/XXX_add_rental_updated_at.sql backend/app/flea_market_rental_routes.py
git commit -m "feat: add updated_at to FleaMarketRental for pending_return timeout tracking"
```

---

### Task 5: Frontend — Fix rental detail owner role detection

Use `seller_id` from the backend instead of guessing based on `renterId`.

**Files:**
- Modify: `link2ur/lib/data/models/flea_market_rental.dart:60-130` (add `sellerId` field)
- Modify: `link2ur/lib/features/flea_market/views/rental_detail_view.dart:111-119` (fix role logic)

- [ ] **Step 1: Add `sellerId` to FleaMarketRental model**

In `FleaMarketRental` class, add field:
```dart
  final String? sellerId;
```

Add to constructor, `fromJson`, and `props`.

- [ ] **Step 2: Fix role detection in `rental_detail_view.dart`**

Change (~line 118):
```dart
    final isOwner = currentUserId != null && currentUserId != rental.renterId;
```
To:
```dart
    final isOwner = currentUserId != null && rental.sellerId != null && currentUserId == rental.sellerId;
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/data/models/flea_market_rental.dart link2ur/lib/features/flea_market/views/rental_detail_view.dart
git commit -m "fix: use seller_id for accurate owner detection in rental detail view"
```

---

### Task 6: Frontend — Fix rental request duration unit display

Show the rental unit (天/周/月) alongside the duration number in `_RentalRequestItem`.

**Files:**
- Modify: `link2ur/lib/features/flea_market/views/flea_market_detail_view.dart:2804-2810,2934-2936`

- [ ] **Step 1: Pass `rentalUnit` to `_RentalRequestsCard` and `_RentalRequestItem`**

Add `rentalUnit` parameter to `_RentalRequestsCard`:
```dart
class _RentalRequestsCard extends StatelessWidget {
  const _RentalRequestsCard({
    required this.itemId,
    required this.isDark,
    this.rentalUnit,
  });
  final String itemId;
  final bool isDark;
  final String? rentalUnit;
```

Pass it from the call site (~line 480):
```dart
  _RentalRequestsCard(
    itemId: item.id,
    isDark: isDark,
    rentalUnit: item.rentalUnit,
  ),
```

Pass it through to `_RentalRequestItem`:
```dart
class _RentalRequestItem extends StatelessWidget {
  const _RentalRequestItem({
    required this.request,
    required this.isDark,
    required this.itemId,
    this.rentalUnit,
  });
  final FleaMarketRentalRequest request;
  final bool isDark;
  final String itemId;
  final String? rentalUnit;
```

- [ ] **Step 2: Fix duration display**

Change the `unitLabel` switch (~line 2934):
```dart
    final unitLabel = switch (request.rentalDuration) {
      _ => '${request.rentalDuration}',
    };
```

To a proper label using `rentalUnit`:
```dart
    final unitSuffix = switch (rentalUnit) {
      'week' => l10n.fleaMarketRentalUnitWeek,
      'month' => l10n.fleaMarketRentalUnitMonth,
      _ => l10n.fleaMarketRentalUnitDay,
    };
    final unitLabel = '${request.rentalDuration} $unitSuffix';
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/flea_market/views/flea_market_detail_view.dart
git commit -m "fix: display rental unit (day/week/month) alongside duration in request list"
```

---

### Task 7: Backend — Send notification when approved rental request expires

When a 24-hour payment window expires, notify the renter so they know their approved request is no longer valid.

**Files:**
- Modify: `backend/app/rental_scheduled_tasks.py` (add function)
- Modify: `backend/app/task_scheduler.py` (register task)

- [ ] **Step 1: Add `check_expired_rental_approvals` function to `rental_scheduled_tasks.py`**

```python
def check_expired_rental_approvals(db: Session):
    """检查过期的已批准租赁申请：approved 且 payment_expires_at < now → expired，通知租客"""
    now = get_utc_time()

    expired_requests = db.query(models.FleaMarketRentalRequest).filter(
        and_(
            models.FleaMarketRentalRequest.status == "approved",
            models.FleaMarketRentalRequest.payment_expires_at < now,
        )
    ).limit(200).all()

    if not expired_requests:
        return 0

    count = 0
    for req in expired_requests:
        try:
            req.status = "expired"

            item = db.query(models.FleaMarketItem).filter(
                models.FleaMarketItem.id == req.item_id
            ).first()
            item_title = item.title if item else f"物品#{req.item_id}"

            _create_notification_sync(
                db, req.renter_id,
                "flea_market_rental_approval_expired",
                "租赁申请已过期",
                f"您对「{item_title}」的租赁申请因24小时内未支付已过期，请重新申请。",
                str(req.item_id),
            )

            count += 1
        except Exception as e:
            logger.error(f"处理过期租赁申请 {req.id} 失败: {e}")

    if count > 0:
        db.commit()
        logger.info(f"标记 {count} 个租赁申请为过期")

    return count
```

- [ ] **Step 2: Register task in `task_scheduler.py`**

```python
    # 检查租赁申请支付过期 - 每30分钟
    def check_expired_rental_approvals_task():
        from app.rental_scheduled_tasks import check_expired_rental_approvals
        with_db(check_expired_rental_approvals)()

    scheduler.register_task(
        'check_expired_rental_approvals',
        check_expired_rental_approvals_task,
        interval_seconds=1800,  # 每30分钟
        description="检查租赁申请支付过期"
    )
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/rental_scheduled_tasks.py backend/app/task_scheduler.py
git commit -m "feat: notify renter when approved rental request payment window expires"
```
