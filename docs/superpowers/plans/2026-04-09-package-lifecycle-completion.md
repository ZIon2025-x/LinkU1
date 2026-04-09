# Package Lifecycle Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the UserServicePackage subsystem (release mechanism, refund, expiry, reviews, disputes) so money correctly flows from buyer to expert team and buyers have protection.

**Architecture:** Extend existing `payment_transfer_service` / `refund_service` / `task_disputes` / `reviews` infrastructure to support `package_id` branch alongside existing `task_id` branch. Add new `package_settlement.py` module for split/release calculations. Two new scheduled jobs for expiry handling. Proactive refund endpoint with cooldown/pro-rata logic. Cover all state transitions via `UserServicePackage.status` 8-value enum.

**Tech Stack:** Python 3.11 / FastAPI / SQLAlchemy 2.x (sync + async mix) / PostgreSQL / Stripe Connect / pytest / Flutter (minor UI)

**Reference Spec:** `docs/superpowers/specs/2026-04-09-package-lifecycle-completion-design.md`

---

## Prelude: Worktree + Branch Setup

- [ ] **Prelude Step 1: Verify working directory clean**

Run: `git status`
Expected: `working tree clean` or only unrelated changes

- [ ] **Prelude Step 2: Create feature branch**

Run:
```bash
git checkout -b feat/package-lifecycle-completion
```

- [ ] **Prelude Step 3: Read the full spec once before starting**

Read: `docs/superpowers/specs/2026-04-09-package-lifecycle-completion-design.md`

This plan assumes you've read Sections 3 (decisions), 4 (state machine), 5 (data model), and 6 (core logic) of the spec.

---

## Task 1: Migration 189 — UserServicePackage lifecycle fields

**Files:**
- Create: `backend/migrations/189_package_lifecycle_fields.sql`

- [ ] **Step 1: Write the migration SQL**

```sql
-- backend/migrations/189_package_lifecycle_fields.sql
-- Add lifecycle fields to UserServicePackage, remove dead task_id column,
-- and enforce status enum via CHECK constraint.

BEGIN;

-- 1. Add new columns (all nullable for safe in-place migration)
ALTER TABLE user_service_packages
  ADD COLUMN IF NOT EXISTS cooldown_until TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS released_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS released_amount_pence INTEGER NULL,
  ADD COLUMN IF NOT EXISTS platform_fee_pence INTEGER NULL,
  ADD COLUMN IF NOT EXISTS refunded_amount_pence INTEGER NULL,
  ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS unit_price_pence_snapshot INTEGER NULL;

-- 2. Drop dead task_id column (never written or read by any code path)
-- Guard: if the column is gone already (re-run), this is a no-op.
ALTER TABLE user_service_packages DROP COLUMN IF EXISTS task_id;

-- 3. Status enum CHECK constraint
-- Drop first if re-running (IF EXISTS for idempotence)
ALTER TABLE user_service_packages
  DROP CONSTRAINT IF EXISTS user_service_packages_status_check;

ALTER TABLE user_service_packages
  ADD CONSTRAINT user_service_packages_status_check
  CHECK (status IN (
    'active','exhausted','expired','released',
    'refunded','partially_refunded','disputed','cancelled'
  ));

-- 4. Indexes for scheduled jobs
CREATE INDEX IF NOT EXISTS ix_user_packages_status_expires
  ON user_service_packages (status, expires_at);

CREATE INDEX IF NOT EXISTS ix_user_packages_cooldown
  ON user_service_packages (cooldown_until)
  WHERE cooldown_until IS NOT NULL;

COMMIT;
```

- [ ] **Step 2: Verify SQL syntax locally (optional, if psql available)**

Run: `psql -f backend/migrations/189_package_lifecycle_fields.sql --dry-run` (or visually inspect)

Expected: no syntax errors

- [ ] **Step 3: Commit**

```bash
git add backend/migrations/189_package_lifecycle_fields.sql
git commit -m "feat(package): migration 189 - add lifecycle fields to user_service_packages"
```

---

## Task 2: Migration 190 — payment_transfers.package_id

**Files:**
- Create: `backend/migrations/190_payment_transfers_add_package.sql`

- [ ] **Step 1: Write the migration**

```sql
-- backend/migrations/190_payment_transfers_add_package.sql
-- Add package_id nullable FK to payment_transfers, enforce task_id/package_id
-- mutual exclusivity via CHECK constraint.

BEGIN;

ALTER TABLE payment_transfers
  ADD COLUMN IF NOT EXISTS package_id INTEGER NULL
  REFERENCES user_service_packages(id) ON DELETE SET NULL;

ALTER TABLE payment_transfers
  DROP CONSTRAINT IF EXISTS payment_transfers_target_check;

ALTER TABLE payment_transfers
  ADD CONSTRAINT payment_transfers_target_check
  CHECK ((task_id IS NULL) != (package_id IS NULL));

CREATE INDEX IF NOT EXISTS ix_payment_transfers_package
  ON payment_transfers(package_id)
  WHERE package_id IS NOT NULL;

COMMIT;
```

- [ ] **Step 2: Commit**

```bash
git add backend/migrations/190_payment_transfers_add_package.sql
git commit -m "feat(package): migration 190 - add package_id to payment_transfers"
```

---

## Task 3: Migration 191 — refund_requests.package_id

**Files:**
- Create: `backend/migrations/191_refund_requests_add_package.sql`

- [ ] **Step 1: Write the migration**

```sql
-- backend/migrations/191_refund_requests_add_package.sql
-- Add package_id nullable FK to refund_requests, enforce mutual exclusivity.

BEGIN;

ALTER TABLE refund_requests
  ADD COLUMN IF NOT EXISTS package_id INTEGER NULL
  REFERENCES user_service_packages(id) ON DELETE SET NULL;

ALTER TABLE refund_requests
  DROP CONSTRAINT IF EXISTS refund_requests_target_check;

ALTER TABLE refund_requests
  ADD CONSTRAINT refund_requests_target_check
  CHECK ((task_id IS NULL) != (package_id IS NULL));

CREATE INDEX IF NOT EXISTS ix_refund_requests_package
  ON refund_requests(package_id)
  WHERE package_id IS NOT NULL;

COMMIT;
```

- [ ] **Step 2: Commit**

```bash
git add backend/migrations/191_refund_requests_add_package.sql
git commit -m "feat(package): migration 191 - add package_id to refund_requests"
```

---

## Task 4: Migration 192 — reviews.package_id

**Files:**
- Create: `backend/migrations/192_reviews_add_package.sql`

- [ ] **Step 1: Write the migration**

```sql
-- backend/migrations/192_reviews_add_package.sql
-- Add package_id nullable FK to reviews, enforce mutual exclusivity with task_id.

BEGIN;

ALTER TABLE reviews
  ADD COLUMN IF NOT EXISTS package_id INTEGER NULL
  REFERENCES user_service_packages(id) ON DELETE SET NULL;

ALTER TABLE reviews
  DROP CONSTRAINT IF EXISTS reviews_target_check;

ALTER TABLE reviews
  ADD CONSTRAINT reviews_target_check
  CHECK ((task_id IS NULL) != (package_id IS NULL));

CREATE INDEX IF NOT EXISTS ix_reviews_package
  ON reviews(package_id)
  WHERE package_id IS NOT NULL;

COMMIT;
```

- [ ] **Step 2: Commit**

```bash
git add backend/migrations/192_reviews_add_package.sql
git commit -m "feat(package): migration 192 - add package_id to reviews"
```

---

## Task 5: Migration 193 — task_disputes.package_id

**Files:**
- Create: `backend/migrations/193_task_disputes_add_package.sql`

- [ ] **Step 1: Write the migration**

```sql
-- backend/migrations/193_task_disputes_add_package.sql
-- Add package_id nullable FK to task_disputes, enforce mutual exclusivity with task_id.
-- This reuses the existing dispute infrastructure for package disputes (lightweight extension).

BEGIN;

ALTER TABLE task_disputes
  ADD COLUMN IF NOT EXISTS package_id INTEGER NULL
  REFERENCES user_service_packages(id) ON DELETE SET NULL;

ALTER TABLE task_disputes
  DROP CONSTRAINT IF EXISTS task_disputes_target_check;

ALTER TABLE task_disputes
  ADD CONSTRAINT task_disputes_target_check
  CHECK ((task_id IS NULL) != (package_id IS NULL));

CREATE INDEX IF NOT EXISTS ix_task_disputes_package
  ON task_disputes(package_id)
  WHERE package_id IS NOT NULL;

COMMIT;
```

- [ ] **Step 2: Commit**

```bash
git add backend/migrations/193_task_disputes_add_package.sql
git commit -m "feat(package): migration 193 - add package_id to task_disputes"
```

---

## Task 6: Update SQLAlchemy models — UserServicePackage new columns

**Files:**
- Modify: `backend/app/models_expert.py` (UserServicePackage class)

- [ ] **Step 1: Locate the current UserServicePackage class definition**

Read: `backend/app/models_expert.py:289-330` (approximately)

- [ ] **Step 2: Add new columns to match migration 189**

Replace the column block (lines ~293-311) with the following. Preserve existing columns, add the new ones, and **remove** `task_id`.

```python
class UserServicePackage(Base):
    """用户购买的服务套餐"""
    __tablename__ = "user_service_packages"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    service_id = Column(Integer, ForeignKey("task_expert_services.id", ondelete="CASCADE"), nullable=False)
    expert_id = Column(String(8), ForeignKey("experts.id", ondelete="SET NULL"), nullable=True)
    total_sessions = Column(Integer, nullable=False)
    used_sessions = Column(Integer, nullable=False, default=0)
    status = Column(String(20), nullable=False, default="active")
    purchased_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=True)

    # ── Removed: task_id (dead field, dropped in migration 189) ──

    # A1 套餐购买流程字段
    payment_intent_id = Column(String(255), nullable=True)
    paid_amount = Column(Float, nullable=True)
    currency = Column(String(3), nullable=True, default="GBP")
    bundle_breakdown = Column(JSON, nullable=True)
    last_redeemed_at = Column(DateTime(timezone=True), nullable=True)

    # ── NEW: lifecycle fields (migration 189) ──
    # 24h 冷静期到期时间 (purchased_at + 24h)
    cooldown_until = Column(DateTime(timezone=True), nullable=True)
    # 释放记录 (filled when payment_transfer_service completes transfer)
    released_at = Column(DateTime(timezone=True), nullable=True)
    released_amount_pence = Column(Integer, nullable=True)
    platform_fee_pence = Column(Integer, nullable=True)
    # 退款记录 (filled when refund_service completes refund)
    refunded_amount_pence = Column(Integer, nullable=True)
    refunded_at = Column(DateTime(timezone=True), nullable=True)
    # multi 套餐的单价快照 (bundle 的单价存在 bundle_breakdown 里)
    unit_price_pence_snapshot = Column(Integer, nullable=True)

    user = relationship("User", backref="service_packages")
```

- [ ] **Step 3: Verify the model has no `task_id` reference**

Run: `grep -n "task_id" backend/app/models_expert.py`
Expected: no matches in `UserServicePackage` class (there may be other matches in other classes, those are fine)

- [ ] **Step 4: Commit**

```bash
git add backend/app/models_expert.py
git commit -m "feat(package): add lifecycle fields to UserServicePackage model"
```

---

## Task 7: Update SQLAlchemy models — PaymentTransfer.package_id, RefundRequest.package_id, Review.package_id, TaskDispute.package_id

**Files:**
- Modify: `backend/app/models.py` (PaymentTransfer, RefundRequest, Review, TaskDispute)

- [ ] **Step 1: Locate each class definition**

Run: `grep -n "class PaymentTransfer\|class RefundRequest\|class Review\|class TaskDispute" backend/app/models.py`

- [ ] **Step 2: Add `package_id` column to each**

For each class, add this column near the existing `task_id` column:

```python
# PaymentTransfer class
package_id = Column(Integer, ForeignKey("user_service_packages.id", ondelete="SET NULL"), nullable=True)

# RefundRequest class
package_id = Column(Integer, ForeignKey("user_service_packages.id", ondelete="SET NULL"), nullable=True)

# Review class
package_id = Column(Integer, ForeignKey("user_service_packages.id", ondelete="SET NULL"), nullable=True)

# TaskDispute class
package_id = Column(Integer, ForeignKey("user_service_packages.id", ondelete="SET NULL"), nullable=True)
```

- [ ] **Step 3: Make task_id nullable in each class (if not already)**

The CHECK constraint `(task_id IS NULL) != (package_id IS NULL)` requires task_id to be nullable. Verify each class's `task_id` column has `nullable=True`. If any is `nullable=False`, change it to `nullable=True`.

- [ ] **Step 4: Commit**

```bash
git add backend/app/models.py
git commit -m "feat(package): add package_id FK to PaymentTransfer/RefundRequest/Review/TaskDispute"
```

---

## Task 8: Create `package_settlement.py` with `compute_package_split` (TDD)

**Files:**
- Create: `backend/app/services/package_settlement.py`
- Test: `backend/tests/test_package_settlement.py`

- [ ] **Step 1: Write the failing test for bundle_weighted case**

Create `backend/tests/test_package_settlement.py`:

```python
"""Unit tests for package_settlement module."""
import pytest
from unittest.mock import MagicMock


class TestComputePackageSplit:
    """Test the core bundle/multi split calculation."""

    def _make_package(
        self,
        paid_amount: float,
        total_sessions: int = 0,
        used_sessions: int = 0,
        bundle_breakdown: dict | None = None,
        unit_price_pence_snapshot: int | None = None,
    ):
        pkg = MagicMock()
        pkg.paid_amount = paid_amount
        pkg.total_sessions = total_sessions
        pkg.used_sessions = used_sessions
        pkg.bundle_breakdown = bundle_breakdown
        pkg.unit_price_pence_snapshot = unit_price_pence_snapshot
        return pkg

    def test_bundle_weighted_partial_consumption(self):
        """Bundle A×3 (£10) + B×2 (£20) + C×1 (£30), paid £80 (20% discount).
        Consumed: 2A + 1B + 0C.
        Expected:
          consumed_fair = £80 * 40/100 = £32 = 3200 pence
          unconsumed_fair = 4800 pence
          fee = 3200 * 0.08 = 256 pence
          transfer = 3200 - 256 = 2944 pence
        """
        from app.services.package_settlement import compute_package_split

        pkg = self._make_package(
            paid_amount=80.0,
            bundle_breakdown={
                "1": {"total": 3, "used": 2, "unit_price_pence": 1000},
                "2": {"total": 2, "used": 1, "unit_price_pence": 2000},
                "3": {"total": 1, "used": 0, "unit_price_pence": 3000},
            },
        )

        result = compute_package_split(pkg)

        assert result["paid_total_pence"] == 8000
        assert result["consumed_value_pence"] == 3200
        assert result["unconsumed_value_pence"] == 4800
        assert result["fee_pence"] == 256
        assert result["transfer_pence"] == 2944
        assert result["refund_pence"] == 0
        assert result["calculation_mode"] == "bundle_weighted"
```

- [ ] **Step 2: Run test to verify it fails with ImportError**

Run: `cd backend && pytest tests/test_package_settlement.py::TestComputePackageSplit::test_bundle_weighted_partial_consumption -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.package_settlement'`

- [ ] **Step 3: Create `backend/app/services/__init__.py` if it doesn't exist**

Run:
```bash
test -f backend/app/services/__init__.py || touch backend/app/services/__init__.py
```

- [ ] **Step 4: Create `package_settlement.py` with minimal `compute_package_split`**

Create `backend/app/services/package_settlement.py`:

```python
"""Package settlement module: split/release calculations for UserServicePackage.

All monetary values in pence (int) unless otherwise noted.
"""
from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from app.models_expert import UserServicePackage


def compute_package_split(package: "UserServicePackage") -> dict:
    """Compute the fair-value split for a UserServicePackage.

    Returns a dict with:
        paid_total_pence:       Original paid amount in pence
        consumed_value_pence:   Fair value of consumed sessions (bundle-weighted or uniform)
        unconsumed_value_pence: Fair value of unconsumed sessions (sum == paid_total)
        fee_pence:              Platform service fee (8% on consumed, min 50p)
        transfer_pence:         Amount to send to expert (consumed - fee)
        refund_pence:           Default 0, caller fills based on scenario
        calculation_mode:       "bundle_weighted" | "multi_uniform" | "legacy_equal"
    """
    paid = int(round(float(package.paid_amount) * 100))

    if package.bundle_breakdown:
        has_new_format = all(
            isinstance(item, dict) and "unit_price_pence" in item
            for item in package.bundle_breakdown.values()
        )
        if has_new_format:
            unbundled_total = sum(
                int(item["total"]) * int(item["unit_price_pence"])
                for item in package.bundle_breakdown.values()
            )
            consumed_list = sum(
                int(item["used"]) * int(item["unit_price_pence"])
                for item in package.bundle_breakdown.values()
            )
            mode = "bundle_weighted"
        else:
            # Legacy fallback: equal weight per session
            total_count = sum(int(item["total"]) for item in package.bundle_breakdown.values())
            used_count = sum(int(item["used"]) for item in package.bundle_breakdown.values())
            unbundled_total = total_count
            consumed_list = used_count
            mode = "legacy_equal"
    elif package.unit_price_pence_snapshot:
        # multi 模式: uniform price per session
        unbundled_total = package.total_sessions * package.unit_price_pence_snapshot
        consumed_list = package.used_sessions * package.unit_price_pence_snapshot
        mode = "multi_uniform"
    else:
        # Legacy fallback: pro-rata by session count
        unbundled_total = package.total_sessions
        consumed_list = package.used_sessions
        mode = "legacy_equal"

    if unbundled_total == 0:
        # Defensive: refund everything to buyer
        return {
            "paid_total_pence": paid,
            "consumed_value_pence": 0,
            "unconsumed_value_pence": paid,
            "fee_pence": 0,
            "transfer_pence": 0,
            "refund_pence": paid,
            "calculation_mode": mode,
        }

    consumed_fair = paid * consumed_list // unbundled_total
    unconsumed_fair = paid - consumed_fair  # Preserve sum == paid (no rounding loss)

    from app.utils.fee_calculator import calculate_application_fee_pence
    fee = calculate_application_fee_pence(consumed_fair, "expert_service", None)
    transfer = consumed_fair - fee

    return {
        "paid_total_pence": paid,
        "consumed_value_pence": consumed_fair,
        "unconsumed_value_pence": unconsumed_fair,
        "fee_pence": fee,
        "transfer_pence": transfer,
        "refund_pence": 0,
        "calculation_mode": mode,
    }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && pytest tests/test_package_settlement.py::TestComputePackageSplit::test_bundle_weighted_partial_consumption -v`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/__init__.py backend/app/services/package_settlement.py backend/tests/test_package_settlement.py
git commit -m "feat(package): add compute_package_split bundle-weighted logic"
```

---

## Task 9: Extend `compute_package_split` tests to cover all branches

**Files:**
- Modify: `backend/tests/test_package_settlement.py`

- [ ] **Step 1: Add tests for multi_uniform, zero-consumed, all-consumed, legacy, and zero-unbundled**

Append to `TestComputePackageSplit`:

```python
    def test_multi_uniform_partial_consumption(self):
        """Multi 10 × £1 = £10, used 3 → consumed=£3, unconsumed=£7, fee=50p (min), transfer=£2.50."""
        from app.services.package_settlement import compute_package_split

        pkg = self._make_package(
            paid_amount=10.0,
            total_sessions=10,
            used_sessions=3,
            bundle_breakdown=None,
            unit_price_pence_snapshot=100,
        )

        result = compute_package_split(pkg)

        assert result["paid_total_pence"] == 1000
        assert result["consumed_value_pence"] == 300
        assert result["unconsumed_value_pence"] == 700
        # 300p * 8% = 24p, but min fee is 50p → fee = 50p
        assert result["fee_pence"] == 50
        assert result["transfer_pence"] == 250
        assert result["calculation_mode"] == "multi_uniform"

    def test_all_consumed_multi(self):
        """Multi 10 × £1 = £10, all used → consumed=£10, unconsumed=0."""
        from app.services.package_settlement import compute_package_split

        pkg = self._make_package(
            paid_amount=10.0,
            total_sessions=10,
            used_sessions=10,
            unit_price_pence_snapshot=100,
        )

        result = compute_package_split(pkg)

        assert result["consumed_value_pence"] == 1000
        assert result["unconsumed_value_pence"] == 0
        # 1000p * 8% = 80p, > 50p min → fee = 80p
        assert result["fee_pence"] == 80
        assert result["transfer_pence"] == 920

    def test_zero_consumed_multi(self):
        """Multi 10 × £1 = £10, used 0 → consumed=0, fee=0, transfer=0, refund caller fills."""
        from app.services.package_settlement import compute_package_split

        pkg = self._make_package(
            paid_amount=10.0,
            total_sessions=10,
            used_sessions=0,
            unit_price_pence_snapshot=100,
        )

        result = compute_package_split(pkg)

        assert result["consumed_value_pence"] == 0
        assert result["unconsumed_value_pence"] == 1000
        assert result["fee_pence"] == 0
        assert result["transfer_pence"] == 0

    def test_legacy_bundle_no_unit_price(self):
        """Bundle breakdown without unit_price_pence falls back to equal weight."""
        from app.services.package_settlement import compute_package_split

        pkg = self._make_package(
            paid_amount=60.0,
            bundle_breakdown={
                "1": {"total": 3, "used": 2},  # No unit_price_pence
                "2": {"total": 3, "used": 1},
            },
        )

        result = compute_package_split(pkg)

        # 6 total sessions, 3 used → consumed = £60 * 3/6 = £30
        assert result["consumed_value_pence"] == 3000
        assert result["unconsumed_value_pence"] == 3000
        assert result["calculation_mode"] == "legacy_equal"

    def test_zero_unbundled_total_defensive_full_refund(self):
        """Defensive case: if unbundled_total somehow calculates to 0, refund everything."""
        from app.services.package_settlement import compute_package_split

        pkg = self._make_package(
            paid_amount=10.0,
            total_sessions=0,
            used_sessions=0,
            unit_price_pence_snapshot=None,
        )

        result = compute_package_split(pkg)

        assert result["consumed_value_pence"] == 0
        assert result["unconsumed_value_pence"] == 1000
        assert result["fee_pence"] == 0
        assert result["transfer_pence"] == 0
        assert result["refund_pence"] == 1000

    def test_sum_invariant_bundle(self):
        """consumed + unconsumed must always equal paid_total (no rounding loss)."""
        from app.services.package_settlement import compute_package_split

        # Tricky numbers: paid 9.99, bundle with primes
        pkg = self._make_package(
            paid_amount=9.99,
            bundle_breakdown={
                "1": {"total": 7, "used": 3, "unit_price_pence": 137},
                "2": {"total": 5, "used": 2, "unit_price_pence": 211},
            },
        )

        result = compute_package_split(pkg)

        assert (
            result["consumed_value_pence"] + result["unconsumed_value_pence"]
            == result["paid_total_pence"]
        )
```

- [ ] **Step 2: Run all tests**

Run: `cd backend && pytest tests/test_package_settlement.py::TestComputePackageSplit -v`
Expected: all 6 tests PASS (1 from Task 8 + 5 new)

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_package_settlement.py
git commit -m "test(package): cover all compute_package_split branches"
```

---

## Task 10: Add `trigger_package_release` + tests

**Files:**
- Modify: `backend/app/services/package_settlement.py`
- Modify: `backend/tests/test_package_settlement.py`

- [ ] **Step 1: Write failing test for trigger_package_release**

Append to `backend/tests/test_package_settlement.py`:

```python
class TestTriggerPackageRelease:
    """Test the release trigger that creates PaymentTransfer rows."""

    def _make_package_exhausted(self, paid_amount=10.0, pkg_id=42):
        pkg = MagicMock()
        pkg.id = pkg_id
        pkg.status = "exhausted"
        pkg.paid_amount = paid_amount
        pkg.expert_id = "78682901"
        pkg.user_id = "16668888"
        pkg.currency = "GBP"
        pkg.released_amount_pence = None  # Not yet released
        pkg.platform_fee_pence = None
        return pkg

    def test_release_creates_payment_transfer_and_sets_fee(self):
        """Exhausted £10 package: transfer 920p (after 80p fee)."""
        from app.services.package_settlement import trigger_package_release

        pkg = self._make_package_exhausted(paid_amount=10.0)
        db = MagicMock()

        trigger_package_release(db, pkg, reason="exhausted")

        # Platform fee should be set on package
        assert pkg.platform_fee_pence == 80  # 10£ * 8%
        # db.add must be called once with a PaymentTransfer-like object
        assert db.add.call_count == 1
        transfer_arg = db.add.call_args[0][0]
        assert transfer_arg.package_id == 42
        assert transfer_arg.task_id is None
        assert transfer_arg.taker_expert_id == "78682901"
        assert transfer_arg.poster_id == "16668888"
        assert transfer_arg.amount == pytest.approx(9.20)
        assert transfer_arg.currency == "GBP"
        assert transfer_arg.status == "pending"
        assert transfer_arg.idempotency_key == "pkg_42_exhausted"

    def test_release_idempotent_when_already_released(self):
        """If released_amount_pence is already set, trigger_package_release is a no-op."""
        from app.services.package_settlement import trigger_package_release

        pkg = self._make_package_exhausted()
        pkg.released_amount_pence = 920  # Already released
        db = MagicMock()

        trigger_package_release(db, pkg, reason="exhausted")

        # db.add must NOT be called
        assert db.add.call_count == 0

    def test_release_rejects_invalid_status(self):
        """trigger_package_release only works for exhausted / expired status."""
        from app.services.package_settlement import trigger_package_release

        pkg = self._make_package_exhausted()
        pkg.status = "active"
        db = MagicMock()

        with pytest.raises(ValueError, match="Invalid status"):
            trigger_package_release(db, pkg, reason="exhausted")

    def test_release_expired_reason_idempotency_key(self):
        """Expired reason produces distinct idempotency key."""
        from app.services.package_settlement import trigger_package_release

        pkg = self._make_package_exhausted(pkg_id=99)
        pkg.status = "expired"
        db = MagicMock()

        trigger_package_release(db, pkg, reason="expired")

        transfer_arg = db.add.call_args[0][0]
        assert transfer_arg.idempotency_key == "pkg_99_expired"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && pytest tests/test_package_settlement.py::TestTriggerPackageRelease -v`
Expected: FAIL with `ImportError: cannot import name 'trigger_package_release'`

- [ ] **Step 3: Implement `trigger_package_release`**

Append to `backend/app/services/package_settlement.py`:

```python
def trigger_package_release(db, pkg, reason: str) -> None:
    """Trigger the release of a package's held funds to the expert team.

    Creates a PaymentTransfer row in 'pending' state. The existing
    payment_transfer_service cron will pick it up and execute the Stripe Transfer.

    Args:
        db: SQLAlchemy session (sync or async both work — only uses db.add)
        pkg: UserServicePackage instance, must have status in ('exhausted', 'expired')
        reason: "exhausted" | "expired" | "partial_transfer" — becomes idempotency key suffix

    Raises:
        ValueError: if pkg.status is not in allowed set

    Idempotency:
        If pkg.released_amount_pence is already set, this is a no-op.
        The idempotency_key on PaymentTransfer ensures Stripe-level retry safety.
    """
    if pkg.status not in ("exhausted", "expired"):
        raise ValueError(f"Invalid status for release: {pkg.status}")

    if pkg.released_amount_pence is not None:
        # Already processed — skip
        return

    from app.utils.fee_calculator import calculate_application_fee_pence
    from app import models

    paid_pence = int(round(float(pkg.paid_amount) * 100))
    fee = calculate_application_fee_pence(paid_pence, "expert_service", None)
    transfer_pence = paid_pence - fee

    pkg.platform_fee_pence = fee
    # Note: released_amount_pence and released_at are written by payment_transfer_service
    # after the Stripe Transfer succeeds.

    db.add(models.PaymentTransfer(
        task_id=None,
        package_id=pkg.id,
        taker_id=None,
        taker_expert_id=pkg.expert_id,
        poster_id=pkg.user_id,
        amount=transfer_pence / 100.0,
        currency=pkg.currency or "GBP",
        status="pending",
        idempotency_key=f"pkg_{pkg.id}_{reason}",
    ))
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && pytest tests/test_package_settlement.py::TestTriggerPackageRelease -v`
Expected: all 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/package_settlement.py backend/tests/test_package_settlement.py
git commit -m "feat(package): add trigger_package_release with idempotency"
```

---

## Task 11: Update `_build_bundle_breakdown` to snapshot unit prices

**Files:**
- Modify: `backend/app/package_purchase_routes.py` (function `_build_bundle_breakdown`)

- [ ] **Step 1: Locate the current function**

Read: `backend/app/package_purchase_routes.py:52-73`

- [ ] **Step 2: Replace with snapshotting version**

Replace the function body with:

```python
def _build_bundle_breakdown(bundle_service_ids, db):
    """Parse service.bundle_service_ids into UserServicePackage.bundle_breakdown new format.

    Args:
        bundle_service_ids: List from TaskExpertService.bundle_service_ids. Supports two formats:
            - [A, B, C]                                — legacy "each once"
            - [{"service_id": A, "count": 5}, ...]     — explicit count per service
        db: SQLAlchemy Session (sync only — called from webhook context in routers.py)

    Returns:
        New format dict:
            {"<sid>": {"total": N, "used": 0, "unit_price_pence": P}, ...}
        Or None if bundle_service_ids is empty/invalid.
    """
    if not bundle_service_ids:
        return None

    # Aggregate counts per service_id
    sid_counts = {}
    for item in bundle_service_ids:
        if isinstance(item, int):
            sid_counts[item] = sid_counts.get(item, 0) + 1
        elif isinstance(item, dict):
            sid = item.get("service_id")
            cnt = item.get("count", 1)
            if sid is not None:
                sid_counts[sid] = sid_counts.get(sid, 0) + int(cnt)

    if not sid_counts:
        return None

    # Snapshot unit prices at purchase time (protect against later service price changes)
    from app import models
    sids = list(sid_counts.keys())
    sub_services = db.query(models.TaskExpertService).filter(
        models.TaskExpertService.id.in_(sids)
    ).all()
    price_map = {
        s.id: int(round(float(s.base_price) * 100))
        for s in sub_services
    }

    breakdown = {}
    for sid, total in sid_counts.items():
        breakdown[str(sid)] = {
            "total": total,
            "used": 0,
            "unit_price_pence": price_map.get(sid, 0),  # 0 fallback for missing service
        }
    return breakdown
```

- [ ] **Step 3: Find all callers of `_build_bundle_breakdown` and update to pass `db`**

Run: `grep -rn "_build_bundle_breakdown" backend/app/`

Expected callers:
- `routers.py:7780` (webhook) — already has `db` in scope
- `package_purchase_routes.py` itself if called from purchase endpoint

Update each caller to pass `db` as second arg:
```python
# Before
breakdown = _build_bundle_breakdown(service_obj.bundle_service_ids)

# After
breakdown = _build_bundle_breakdown(service_obj.bundle_service_ids, db)
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/package_purchase_routes.py backend/app/routers.py
git commit -m "feat(package): snapshot unit prices in bundle_breakdown at purchase time"
```

---

## Task 12: Update webhook package_purchase branch to write new fields

**Files:**
- Modify: `backend/app/routers.py` (webhook package_purchase branch around line 7795)

- [ ] **Step 1: Locate the UserServicePackage instantiation**

Read: `backend/app/routers.py:7780-7810`

- [ ] **Step 2: Add `cooldown_until` and `unit_price_pence_snapshot` fields**

Find the `new_pkg = UserServicePackage(...)` call. Replace with:

```python
# Ensure timedelta imported at top of file; if not, import inside branch
from datetime import timedelta as _td

# Determine unit_price_pence_snapshot for multi packages
unit_snapshot = None
if package_type_meta == "multi" and service_obj is not None:
    unit_snapshot = int(round(float(service_obj.base_price) * 100))

new_pkg = UserServicePackage(
    user_id=buyer_id,
    service_id=int(service_id_meta),
    expert_id=expert_id_meta,
    total_sessions=final_total,
    used_sessions=0,
    status="active",
    purchased_at=get_utc_time(),
    cooldown_until=get_utc_time() + _td(hours=24),
    expires_at=exp_at,
    payment_intent_id=payment_intent_id,
    paid_amount=package_price_meta,
    currency="GBP",
    bundle_breakdown=breakdown,
    unit_price_pence_snapshot=unit_snapshot,
)
```

- [ ] **Step 3: Verify the file compiles (Python syntax check)**

Run: `python -m py_compile backend/app/routers.py`
Expected: no output (success)

- [ ] **Step 4: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat(package): webhook writes cooldown_until + unit_price_pence_snapshot"
```

---

## Task 13: Redemption endpoints trigger release on exhausted

**Files:**
- Modify: `backend/app/package_purchase_routes.py` (around line 623)
- Modify: `backend/app/expert_package_routes.py` (around line 115)

**Note:** Both files must be changed in sync (tech debt: `memory/project_package_redemption_dup.md`).

- [ ] **Step 1: Modify `package_purchase_routes.py` redeem endpoint**

Locate the block at around line 620-625:

```python
# Existing code:
pkg.used_sessions = pkg.used_sessions + 1
pkg.last_redeemed_at = get_utc_time()
if pkg.used_sessions >= pkg.total_sessions:
    pkg.status = "exhausted"
```

Change to:

```python
# Existing code:
pkg.used_sessions = pkg.used_sessions + 1
pkg.last_redeemed_at = get_utc_time()
if pkg.used_sessions >= pkg.total_sessions:
    pkg.status = "exhausted"
    # NEW: trigger release (creates PaymentTransfer for async job)
    from app.services.package_settlement import trigger_package_release
    trigger_package_release(db, pkg, reason="exhausted")
```

- [ ] **Step 2: Modify `expert_package_routes.py` use_package_session endpoint**

Locate the block at around line 113-115:

```python
# Existing code:
await db.refresh(package)
if package.used_sessions >= package.total_sessions:
    package.status = "exhausted"
```

Change to:

```python
# Existing code:
await db.refresh(package)
if package.used_sessions >= package.total_sessions:
    package.status = "exhausted"
    # NEW: trigger release
    from app.services.package_settlement import trigger_package_release
    trigger_package_release(db, package, reason="exhausted")
```

- [ ] **Step 3: Verify both files compile**

Run:
```bash
python -m py_compile backend/app/package_purchase_routes.py
python -m py_compile backend/app/expert_package_routes.py
```
Expected: no output

- [ ] **Step 4: Commit**

```bash
git add backend/app/package_purchase_routes.py backend/app/expert_package_routes.py
git commit -m "feat(package): trigger release on exhausted (both redemption endpoints)"
```

---

## Task 14: Extend `payment_transfer_service` with package_id branch

**Files:**
- Modify: `backend/app/payment_transfer_service.py`

- [ ] **Step 1: Locate the PaymentTransfer processing loop**

Read: `backend/app/payment_transfer_service.py` — find the function that processes a pending `PaymentTransfer` row (around lines 150-300).

- [ ] **Step 2: Add package_id branch — resolve destination from UserServicePackage**

Find where `destination = taker_stripe_account_id` is resolved (typically from Task via `task.taker_expert_id`). Add a branch:

```python
# Resolve destination account: task branch vs package branch
if transfer_record.package_id is not None:
    # Package branch: destination = expert team's stripe_account_id
    from app.models_expert import UserServicePackage, Expert
    pkg = db.query(UserServicePackage).filter(
        UserServicePackage.id == transfer_record.package_id
    ).first()
    if not pkg:
        logger.error(f"PaymentTransfer {transfer_record.id} references non-existent package {transfer_record.package_id}")
        transfer_record.status = "failed"
        transfer_record.last_error = "package_not_found"
        return False, None, "package_not_found"

    expert = db.query(Expert).filter(Expert.id == pkg.expert_id).first()
    if not expert or not expert.stripe_account_id:
        transfer_record.status = "failed"
        transfer_record.last_error = "expert_stripe_account_missing"
        return False, None, "expert_stripe_account_missing"

    taker_stripe_account_id = expert.stripe_account_id
    # Skip the 90-day Stripe Transfer window check for packages
    # (packages have their own expires_at limit)
else:
    # Existing task branch (unchanged)
    # ... (existing task.taker_expert_id resolution)
    pass
```

- [ ] **Step 3: Add package success callback after Transfer.create succeeds**

Find where `transfer_record.status = "succeeded"` is set. Add package-specific post-processing:

```python
# After marking transfer_record as succeeded:
if transfer_record.package_id is not None:
    # Package branch: update UserServicePackage with release info
    from app.models_expert import UserServicePackage
    pkg = db.query(UserServicePackage).filter(
        UserServicePackage.id == transfer_record.package_id
    ).first()
    if pkg:
        pkg.released_at = get_utc_time()
        pkg.released_amount_pence = int(round(float(transfer_record.amount) * 100))
        # Only transition exhausted/expired → released
        # (partially_refunded stays at partially_refunded, it's a terminal state)
        if pkg.status in ("exhausted", "expired"):
            pkg.status = "released"
```

- [ ] **Step 4: Update the Transfer.create metadata to include package_id**

Find the `_stripe_create_kwargs = dict(...)` block. Add to metadata:

```python
"package_id": str(transfer_record.package_id) if transfer_record.package_id else "",
"transfer_type": "package_release" if transfer_record.package_id else "task_reward",
```

- [ ] **Step 5: Verify file compiles**

Run: `python -m py_compile backend/app/payment_transfer_service.py`
Expected: no output

- [ ] **Step 6: Commit**

```bash
git add backend/app/payment_transfer_service.py
git commit -m "feat(package): extend payment_transfer_service to handle package branch"
```

---

## Task 15: Extend `refund_service` with package_id branch

**Files:**
- Modify: `backend/app/refund_service.py`

- [ ] **Step 1: Locate the RefundRequest processing function**

Read: `backend/app/refund_service.py` — find where RefundRequest rows are processed and Stripe Refund is created.

- [ ] **Step 2: Add package_id branch — resolve payment_intent_id**

Find where `payment_intent_id` is resolved (typically from `refund.task.payment_intent_id`). Add a branch:

```python
# Resolve payment_intent_id: task branch vs package branch
if refund_request.package_id is not None:
    from app.models_expert import UserServicePackage
    pkg = db.query(UserServicePackage).filter(
        UserServicePackage.id == refund_request.package_id
    ).first()
    if not pkg or not pkg.payment_intent_id:
        refund_request.status = "failed"
        refund_request.last_error = "package_payment_intent_missing"
        return False
    payment_intent_id = pkg.payment_intent_id
else:
    # Existing task branch
    # ...
    pass
```

- [ ] **Step 3: Add package success callback**

Find where Stripe `refund.create()` succeeds. Add:

```python
if refund_request.package_id is not None:
    from app.models_expert import UserServicePackage
    pkg = db.query(UserServicePackage).filter(
        UserServicePackage.id == refund_request.package_id
    ).first()
    if pkg:
        pkg.refunded_at = get_utc_time()
        pkg.refunded_amount_pence = int(round(float(refund_request.amount) * 100))
        # Do NOT change pkg.status here — refunded / partially_refunded are terminal states
        # set synchronously when the refund endpoint was called
```

- [ ] **Step 4: Verify file compiles**

Run: `python -m py_compile backend/app/refund_service.py`
Expected: no output

- [ ] **Step 5: Commit**

```bash
git add backend/app/refund_service.py
git commit -m "feat(package): extend refund_service to handle package branch"
```

---

## Task 16: Add `check_expired_packages` scheduled task

**Files:**
- Modify: `backend/app/scheduled_tasks.py`

- [ ] **Step 1: Add the function**

Append to `backend/app/scheduled_tasks.py`:

```python
def check_expired_packages(db) -> dict:
    """Scheduled task: find expired UserServicePackages and trigger release.

    Runs every 3600s. Scans for:
        status IN ('active', 'expired') AND expires_at < now AND released_at IS NULL
    Marks them as expired and creates PaymentTransfer rows.
    """
    from app.models_expert import UserServicePackage
    from app.services.package_settlement import trigger_package_release
    from app.utils.time_utils import get_utc_time
    import logging
    logger = logging.getLogger(__name__)

    now = get_utc_time()

    expired_pkgs = db.query(UserServicePackage).filter(
        UserServicePackage.status.in_(["active", "expired"]),
        UserServicePackage.expires_at < now,
        UserServicePackage.released_at.is_(None),
    ).limit(500).all()

    processed = 0
    failed = 0
    for pkg in expired_pkgs:
        try:
            if pkg.status == "active":
                pkg.status = "expired"
            trigger_package_release(db, pkg, reason="expired")
            processed += 1
        except Exception as e:
            logger.error(f"Failed to process expired package {pkg.id}: {e}", exc_info=True)
            failed += 1
            continue

    if processed > 0 or failed > 0:
        try:
            db.commit()
            logger.info(f"check_expired_packages: processed={processed}, failed={failed}")
        except Exception as commit_err:
            logger.error(f"check_expired_packages commit failed: {commit_err}")
            db.rollback()

    return {"processed": processed, "failed": failed}
```

- [ ] **Step 2: Register in task_scheduler**

Modify `backend/app/task_scheduler.py`. Find the section where other tasks are registered (search for `register_task` or similar). Add:

```python
register_task(
    name="check_expired_packages",
    interval_seconds=3600,
    func=check_expired_packages,
)
```

- [ ] **Step 3: Verify files compile**

Run:
```bash
python -m py_compile backend/app/scheduled_tasks.py
python -m py_compile backend/app/task_scheduler.py
```
Expected: no output

- [ ] **Step 4: Commit**

```bash
git add backend/app/scheduled_tasks.py backend/app/task_scheduler.py
git commit -m "feat(package): add check_expired_packages scheduled task"
```

---

## Task 17: Add `send_package_expiry_reminders` scheduled task

**Files:**
- Modify: `backend/app/scheduled_tasks.py`
- Modify: `backend/app/task_scheduler.py`

- [ ] **Step 1: Add the function**

Append to `backend/app/scheduled_tasks.py`:

```python
def send_package_expiry_reminders(db) -> dict:
    """Scheduled task: send expiry reminders at 7d/3d/1d before expires_at.

    Runs every 3600s. For each reminder window, scans packages where
    expires_at is within (window_start, window_end), status=active, has unused sessions,
    and no reminder of the same key has been sent to this package yet.
    """
    from datetime import timedelta
    from app.models_expert import UserServicePackage
    from app import models, crud
    from app.utils.time_utils import get_utc_time
    from app.utils.notification_templates import get_notification_texts
    import logging
    logger = logging.getLogger(__name__)

    now = get_utc_time()
    sent = 0

    for days, reminder_key in [(7, "7d"), (3, "3d"), (1, "1d")]:
        window_start = now + timedelta(days=days, hours=-12)
        window_end = now + timedelta(days=days, hours=12)

        due = db.query(UserServicePackage).filter(
            UserServicePackage.status == "active",
            UserServicePackage.expires_at.between(window_start, window_end),
            UserServicePackage.used_sessions < UserServicePackage.total_sessions,
        ).all()

        notif_type = f"package_expiry_reminder_{reminder_key}"
        for pkg in due:
            # Dedup: skip if we've already sent this reminder for this package
            existing = db.query(models.Notification).filter(
                models.Notification.user_id == pkg.user_id,
                models.Notification.related_id == str(pkg.id),
                models.Notification.type == notif_type,
            ).first()
            if existing:
                continue

            try:
                remaining = pkg.total_sessions - pkg.used_sessions
                title_zh, content_zh, title_en, content_en = get_notification_texts(
                    notif_type,
                    days=days,
                    remaining=remaining,
                )
                crud.create_notification(
                    db=db,
                    user_id=pkg.user_id,
                    type=notif_type,
                    title=title_zh,
                    content=content_zh,
                    title_en=title_en,
                    content_en=content_en,
                    related_id=str(pkg.id),
                    related_type="package",
                    auto_commit=False,
                )
                sent += 1
            except Exception as e:
                logger.error(f"Failed to send reminder for package {pkg.id}: {e}")
                continue

    if sent > 0:
        try:
            db.commit()
            logger.info(f"send_package_expiry_reminders: sent {sent}")
        except Exception as commit_err:
            logger.error(f"expiry reminders commit failed: {commit_err}")
            db.rollback()

    return {"sent": sent}
```

- [ ] **Step 2: Register in task_scheduler**

Add to `backend/app/task_scheduler.py`:

```python
register_task(
    name="send_package_expiry_reminders",
    interval_seconds=3600,
    func=send_package_expiry_reminders,
)
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/scheduled_tasks.py backend/app/task_scheduler.py
git commit -m "feat(package): add send_package_expiry_reminders scheduled task"
```

---

## Task 18: Add notification templates

**Files:**
- Modify: `backend/app/utils/notification_templates.py`

- [ ] **Step 1: Locate the template registry**

Read: `backend/app/utils/notification_templates.py` — find where templates are defined (typically a dict or function).

- [ ] **Step 2: Add 9 new package-related templates**

Append to the template definitions:

```python
# ==================== Package Lifecycle Templates ====================

PACKAGE_TEMPLATES = {
    "package_exhausted_released": {
        "title_zh": "套餐已完成结算",
        "content_zh": "服务 {service_name} 的套餐已全部使用完毕,款项已转账到团队账户",
        "title_en": "Package Settled",
        "content_en": "All sessions of {service_name} package have been used; payment transferred to team account",
    },
    "package_expired_released": {
        "title_zh": "套餐已过期",
        "content_zh": "服务 {service_name} 的套餐已过期",
        "title_en": "Package Expired",
        "content_en": "The {service_name} package has expired",
    },
    "package_expiry_reminder_7d": {
        "title_zh": "套餐 7 天后过期",
        "content_zh": "您购买的 {service_name} 还剩 {remaining} 次未使用,将于 7 天后过期",
        "title_en": "Package Expires in 7 Days",
        "content_en": "Your {service_name} package has {remaining} unused sessions and expires in 7 days",
    },
    "package_expiry_reminder_3d": {
        "title_zh": "套餐 3 天后过期",
        "content_zh": "您购买的 {service_name} 还剩 {remaining} 次未使用,将于 3 天后过期",
        "title_en": "Package Expires in 3 Days",
        "content_en": "Your {service_name} package has {remaining} unused sessions and expires in 3 days",
    },
    "package_expiry_reminder_1d": {
        "title_zh": "套餐明天过期",
        "content_zh": "您购买的 {service_name} 还剩 {remaining} 次未使用,将于明天过期",
        "title_en": "Package Expires Tomorrow",
        "content_en": "Your {service_name} package has {remaining} unused sessions and expires tomorrow",
    },
    "package_refunded_full": {
        "title_zh": "套餐已全额退款",
        "content_zh": "您的 {service_name} 套餐已全额退款",
        "title_en": "Package Fully Refunded",
        "content_en": "Your {service_name} package has been fully refunded",
    },
    "package_refunded_partial": {
        "title_zh": "套餐部分退款",
        "content_zh": "您的 {service_name} 套餐已按比例退款",
        "title_en": "Package Partially Refunded",
        "content_en": "Your {service_name} package has been partially refunded (pro-rata)",
    },
    "package_dispute_opened": {
        "title_zh": "套餐争议已开启",
        "content_zh": "套餐 {service_name} 的争议已提交,管理员将尽快处理",
        "title_en": "Package Dispute Opened",
        "content_en": "A dispute has been opened for {service_name}; admins will review shortly",
    },
    "package_dispute_resolved": {
        "title_zh": "套餐争议已裁决",
        "content_zh": "套餐 {service_name} 的争议已处理完毕",
        "title_en": "Package Dispute Resolved",
        "content_en": "The dispute for {service_name} has been resolved",
    },
}
```

- [ ] **Step 3: Wire `get_notification_texts` to handle package keys**

Find the `get_notification_texts` function. Ensure it can look up keys from the `PACKAGE_TEMPLATES` dict. If the function already has a generic dispatcher, add a lookup for `PACKAGE_TEMPLATES`:

```python
def get_notification_texts(notif_type: str, **kwargs):
    """Return (title_zh, content_zh, title_en, content_en) tuple."""
    # ... existing lookups ...

    if notif_type in PACKAGE_TEMPLATES:
        t = PACKAGE_TEMPLATES[notif_type]
        return (
            t["title_zh"].format(**kwargs),
            t["content_zh"].format(**kwargs),
            t["title_en"].format(**kwargs),
            t["content_en"].format(**kwargs),
        )

    # ... existing fallback ...
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/utils/notification_templates.py
git commit -m "feat(package): add 9 package lifecycle notification templates"
```

---

## Task 19: Implement refund endpoint — full refund helper

**Files:**
- Modify: `backend/app/package_purchase_routes.py` (add new handlers + helper)

- [ ] **Step 1: Add import + helper at top of file**

Find the existing imports in `backend/app/package_purchase_routes.py`. Add:

```python
from datetime import timedelta
from app import crud
from app.services.package_settlement import compute_package_split, trigger_package_release
```

- [ ] **Step 2: Add `_load_package_for_update` helper**

Append after existing helper functions:

```python
async def _load_package_for_update(
    db: AsyncSession, package_id: int, user_id: str
) -> "UserServicePackage":
    """Load a package row with SELECT FOR UPDATE, verify ownership."""
    result = await db.execute(
        select(UserServicePackage)
        .where(
            and_(
                UserServicePackage.id == package_id,
                UserServicePackage.user_id == user_id,
            )
        )
        .with_for_update()
    )
    pkg = result.scalar_one_or_none()
    if not pkg:
        raise HTTPException(
            status_code=404,
            detail={"error_code": "package_not_found", "message": "套餐不存在"},
        )
    return pkg
```

- [ ] **Step 3: Add `_process_full_refund` helper**

```python
async def _process_full_refund(db, pkg, reason: str) -> dict:
    """Process a full refund: sets status='refunded', creates RefundRequest row."""
    from app import models

    paid_pence = int(round(float(pkg.paid_amount) * 100))
    pkg.status = "refunded"
    pkg.refunded_amount_pence = paid_pence

    db.add(models.RefundRequest(
        task_id=None,
        package_id=pkg.id,
        requester_id=pkg.user_id,
        amount=paid_pence / 100.0,
        reason=reason or "cooldown_full_refund",
        status="approved_auto",
        payment_intent_id=pkg.payment_intent_id,
    ))
    await db.commit()

    # Best-effort notifications
    try:
        await _notify_package_refunded(db, pkg, full=True)
    except Exception as e:
        logger.warning(f"Failed to send package refund notification: {e}")

    return {
        "refund_type": "full",
        "status": "refunded",
        "refund_amount_pence": paid_pence,
        "transfer_amount_pence": 0,
        "platform_fee_pence": 0,
    }
```

- [ ] **Step 4: Commit (partial — keep in-progress)**

```bash
git add backend/app/package_purchase_routes.py
git commit -m "feat(package): refund endpoint helpers (WIP)"
```

---

## Task 20: Implement refund endpoint — partial refund helper + main endpoint

**Files:**
- Modify: `backend/app/package_purchase_routes.py`

- [ ] **Step 1: Add `_process_partial_refund` helper**

Append to `backend/app/package_purchase_routes.py`:

```python
async def _process_partial_refund(db, pkg, reason: str) -> dict:
    """Process a pro-rata refund: consumed → expert, unconsumed → buyer."""
    from app import models

    split = compute_package_split(pkg)

    if split["consumed_value_pence"] == 0:
        # Scenario C1: past cooldown but never used → behaves as full refund
        return await _process_full_refund(db, pkg, reason)

    if split["unconsumed_value_pence"] == 0:
        # Defensive: caller should check this before calling
        raise HTTPException(
            400,
            {"error_code": "package_already_exhausted", "message": "套餐已用完"},
        )

    pkg.status = "partially_refunded"
    pkg.released_amount_pence = split["transfer_pence"]
    pkg.platform_fee_pence = split["fee_pence"]
    pkg.refunded_amount_pence = split["unconsumed_value_pence"]

    db.add(models.PaymentTransfer(
        task_id=None,
        package_id=pkg.id,
        taker_expert_id=pkg.expert_id,
        poster_id=pkg.user_id,
        amount=split["transfer_pence"] / 100.0,
        currency=pkg.currency or "GBP",
        status="pending",
        idempotency_key=f"pkg_{pkg.id}_partial_transfer",
    ))
    db.add(models.RefundRequest(
        task_id=None,
        package_id=pkg.id,
        requester_id=pkg.user_id,
        amount=split["unconsumed_value_pence"] / 100.0,
        reason=reason or "user_cancel_partial",
        status="approved_auto",
        payment_intent_id=pkg.payment_intent_id,
    ))
    await db.commit()

    try:
        await _notify_package_refunded(db, pkg, full=False, split=split)
    except Exception as e:
        logger.warning(f"Failed to send partial refund notification: {e}")

    return {
        "refund_type": "pro_rata",
        "status": "partially_refunded",
        "refund_amount_pence": split["unconsumed_value_pence"],
        "transfer_amount_pence": split["transfer_pence"],
        "platform_fee_pence": split["fee_pence"],
    }


async def _notify_package_refunded(db, pkg, full: bool, split: dict | None = None):
    """Best-effort notification to buyer + expert team admins."""
    from app import models, crud
    from app.utils.notification_templates import get_notification_texts
    from app.models_expert import ExpertMember

    # Look up service name for the template
    service_obj = db.query(models.TaskExpertService).filter(
        models.TaskExpertService.id == pkg.service_id
    ).first()
    service_name = service_obj.service_name if service_obj else ""

    notif_type = "package_refunded_full" if full else "package_refunded_partial"
    t_zh, c_zh, t_en, c_en = get_notification_texts(notif_type, service_name=service_name)

    # Buyer
    crud.create_notification(
        db=db, user_id=pkg.user_id, type=notif_type,
        title=t_zh, content=c_zh, title_en=t_en, content_en=c_en,
        related_id=str(pkg.id), related_type="package", auto_commit=False,
    )

    # Expert team admins
    managers = db.query(ExpertMember.user_id).filter(
        ExpertMember.expert_id == pkg.expert_id,
        ExpertMember.status == "active",
        ExpertMember.role.in_(["owner", "admin"]),
    ).all()
    for (mid,) in managers:
        crud.create_notification(
            db=db, user_id=mid, type=notif_type,
            title=t_zh, content=c_zh, title_en=t_en, content_en=c_en,
            related_id=str(pkg.id), related_type="package", auto_commit=False,
        )

    try:
        db.commit()
    except Exception:
        db.rollback()
```

- [ ] **Step 2: Add the main refund endpoint**

Append to `backend/app/package_purchase_routes.py`:

```python
@package_purchase_router.post("/api/my/packages/{package_id}/refund")
async def request_package_refund(
    package_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """Buyer requests refund for a package.

    Dispatches to full refund (scenario A/C1) or pro-rata (scenario B/C2)
    based on cooldown state and usage.
    """
    pkg = await _load_package_for_update(db, package_id, current_user.id)

    # State guard
    if pkg.status != "active":
        error_code_map = {
            "exhausted": "package_already_exhausted",
            "expired": "package_expired",
            "disputed": "package_disputed",
            "refunded": "package_already_refunded",
            "partially_refunded": "package_already_refunded",
            "released": "package_already_released",
            "cancelled": "package_cancelled",
        }
        error_code = error_code_map.get(pkg.status, "package_not_active")
        raise HTTPException(
            400,
            {"error_code": error_code, "message": f"Package status is {pkg.status}"},
        )

    now = get_utc_time()

    # Lazy expiry check
    if pkg.expires_at:
        expires = pkg.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires < now:
            pkg.status = "expired"
            trigger_package_release(db, pkg, reason="expired")
            await db.commit()
            raise HTTPException(
                400,
                {"error_code": "package_expired", "message": "套餐已过期"},
            )

    in_cooldown = pkg.cooldown_until and now < (
        pkg.cooldown_until.replace(tzinfo=timezone.utc)
        if pkg.cooldown_until.tzinfo is None
        else pkg.cooldown_until
    )
    never_used = pkg.used_sessions == 0
    reason = (body or {}).get("reason", "").strip()[:500]

    if in_cooldown and never_used:
        return await _process_full_refund(db, pkg, reason)
    else:
        return await _process_partial_refund(db, pkg, reason)
```

- [ ] **Step 3: Verify file compiles**

Run: `python -m py_compile backend/app/package_purchase_routes.py`
Expected: no output

- [ ] **Step 4: Commit**

```bash
git add backend/app/package_purchase_routes.py
git commit -m "feat(package): add POST /api/my/packages/{id}/refund endpoint"
```

---

## Task 21: Tests for refund endpoint — all 6 scenarios

**Files:**
- Create: `backend/tests/test_package_refund_endpoint.py`

- [ ] **Step 1: Write scenario A test (cooldown + never used = full refund)**

Create `backend/tests/test_package_refund_endpoint.py`:

```python
"""Unit tests for the package refund endpoint logic."""
import pytest
from unittest.mock import MagicMock, AsyncMock, patch
from datetime import datetime, timezone, timedelta


class TestRefundScenarios:
    """Test the 6 refund scenarios: A, B, C1, C2, expired-rejected, exhausted-rejected."""

    def _make_package(
        self,
        pkg_id=42,
        status="active",
        used_sessions=0,
        total_sessions=10,
        paid_amount=10.0,
        cooldown_until: datetime | None = None,
        expires_at: datetime | None = None,
    ):
        pkg = MagicMock()
        pkg.id = pkg_id
        pkg.status = status
        pkg.user_id = "16668888"
        pkg.expert_id = "78682901"
        pkg.service_id = 7
        pkg.used_sessions = used_sessions
        pkg.total_sessions = total_sessions
        pkg.paid_amount = paid_amount
        pkg.payment_intent_id = "pi_test"
        pkg.currency = "GBP"
        pkg.unit_price_pence_snapshot = 100
        pkg.bundle_breakdown = None
        pkg.cooldown_until = cooldown_until
        pkg.expires_at = expires_at
        return pkg

    @pytest.mark.asyncio
    async def test_scenario_a_cooldown_never_used_full_refund(self):
        """< 24h + 0 used → full refund."""
        from app.package_purchase_routes import _process_full_refund

        now = datetime.now(timezone.utc)
        pkg = self._make_package(
            used_sessions=0,
            cooldown_until=now + timedelta(hours=12),
        )
        db = MagicMock()
        db.commit = AsyncMock()
        db.add = MagicMock()
        db.query = MagicMock()
        db.query.return_value.filter.return_value.first.return_value = None  # service lookup

        result = await _process_full_refund(db, pkg, reason="test")

        assert result["refund_type"] == "full"
        assert result["status"] == "refunded"
        assert result["refund_amount_pence"] == 1000
        assert pkg.status == "refunded"
        assert pkg.refunded_amount_pence == 1000

    @pytest.mark.asyncio
    async def test_scenario_b_cooldown_used_pro_rata(self):
        """< 24h + 3 used → pro-rata."""
        from app.package_purchase_routes import _process_partial_refund

        pkg = self._make_package(used_sessions=3)
        db = MagicMock()
        db.commit = AsyncMock()
        db.add = MagicMock()
        db.query.return_value.filter.return_value.first.return_value = None

        result = await _process_partial_refund(db, pkg, reason="test")

        assert result["refund_type"] == "pro_rata"
        assert result["status"] == "partially_refunded"
        # consumed = 300p, fee = 50p (min), transfer = 250p, refund = 700p
        assert result["refund_amount_pence"] == 700
        assert result["transfer_amount_pence"] == 250
        assert pkg.status == "partially_refunded"

    @pytest.mark.asyncio
    async def test_scenario_c1_past_cooldown_never_used_full_refund(self):
        """≥ 24h + 0 used → falls through to full refund."""
        from app.package_purchase_routes import _process_partial_refund

        pkg = self._make_package(used_sessions=0)
        db = MagicMock()
        db.commit = AsyncMock()
        db.add = MagicMock()
        db.query.return_value.filter.return_value.first.return_value = None

        result = await _process_partial_refund(db, pkg, reason="test")

        # Should behave as full refund
        assert result["refund_type"] == "full"
        assert result["status"] == "refunded"
        assert pkg.status == "refunded"

    @pytest.mark.asyncio
    async def test_scenario_c2_past_cooldown_used_pro_rata(self):
        """≥ 24h + 5 used → pro-rata."""
        from app.package_purchase_routes import _process_partial_refund

        pkg = self._make_package(used_sessions=5)
        db = MagicMock()
        db.commit = AsyncMock()
        db.add = MagicMock()
        db.query.return_value.filter.return_value.first.return_value = None

        result = await _process_partial_refund(db, pkg, reason="test")

        assert result["refund_type"] == "pro_rata"
        assert result["status"] == "partially_refunded"
        # consumed = 500p, fee = 50p (min), transfer = 450p, refund = 500p
        assert result["refund_amount_pence"] == 500
        assert result["transfer_amount_pence"] == 450
```

- [ ] **Step 2: Run tests**

Run: `cd backend && pytest tests/test_package_refund_endpoint.py -v`
Expected: 4 tests PASS

- [ ] **Step 3: Commit**

```bash
git add backend/tests/test_package_refund_endpoint.py
git commit -m "test(package): cover refund scenarios A/B/C1/C2"
```

---

## Task 22: Add review endpoint

**Files:**
- Modify: `backend/app/package_purchase_routes.py`

- [ ] **Step 1: Add review endpoint**

Append to `backend/app/package_purchase_routes.py`:

```python
@package_purchase_router.post("/api/my/packages/{package_id}/review")
async def review_package(
    package_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """Buyer submits a review for a package.

    Allowed statuses: exhausted, expired, released, partially_refunded
    (any state where at least some service was rendered).
    """
    rating = body.get("rating")
    comment = (body.get("comment") or "").strip()[:2000]
    images = body.get("images") or []

    if not isinstance(rating, int) or not (1 <= rating <= 5):
        raise HTTPException(
            400,
            {"error_code": "invalid_rating", "message": "评分必须是 1-5 的整数"},
        )

    pkg = await _load_package_for_update(db, package_id, current_user.id)

    allowed_statuses = ("exhausted", "expired", "released", "partially_refunded")
    if pkg.status not in allowed_statuses:
        raise HTTPException(
            400,
            {"error_code": "package_not_reviewable", "message": "当前状态不允许评价"},
        )

    # Check duplicate
    existing = db.query(models.Review).filter(
        models.Review.package_id == package_id,
        models.Review.reviewer_id == current_user.id,
    ).first()
    if existing:
        raise HTTPException(
            400,
            {"error_code": "review_already_exists", "message": "您已评价过该套餐"},
        )

    import json as _json
    review = models.Review(
        task_id=None,
        package_id=package_id,
        reviewer_id=current_user.id,
        rating=rating,
        comment=comment,
        images=_json.dumps(images) if images else None,
    )
    db.add(review)
    await db.commit()
    await db.refresh(review)

    return {
        "review_id": review.id,
        "package_id": package_id,
        "rating": rating,
        "status": "submitted",
    }
```

- [ ] **Step 2: Update expert rating aggregation to include package reviews**

Find the function that calculates an expert team's rating (grep for `rating` in `backend/app/expert_routes.py` or `crud/`). Look for something like `get_expert_rating` or a query that aggregates `Review.rating WHERE task_id = ...`.

Extend the query to UNION reviews linked via `package_id` → `UserServicePackage.expert_id`:

```python
# Example extension (adapt to actual location):
task_reviews = db.query(Review).join(Task).filter(Task.taker_expert_id == expert_id)
package_reviews = db.query(Review).join(
    UserServicePackage, Review.package_id == UserServicePackage.id
).filter(UserServicePackage.expert_id == expert_id)

all_ratings = [r.rating for r in task_reviews] + [r.rating for r in package_reviews]
avg_rating = sum(all_ratings) / len(all_ratings) if all_ratings else 0.0
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/package_purchase_routes.py backend/app/expert_routes.py
git commit -m "feat(package): add review endpoint + include package reviews in expert rating"
```

---

## Task 23: Add dispute endpoint + admin resolution branch

**Files:**
- Modify: `backend/app/package_purchase_routes.py`
- Modify: `backend/app/admin_dispute_routes.py`

- [ ] **Step 1: Add dispute endpoint in `package_purchase_routes.py`**

```python
@package_purchase_router.post("/api/my/packages/{package_id}/dispute")
async def open_package_dispute(
    package_id: int,
    body: dict,
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """Buyer opens a dispute for an active package with at least 1 usage."""
    reason = (body.get("reason") or "").strip()[:2000]
    evidence_files = body.get("evidence_files") or []

    if not reason:
        raise HTTPException(
            400,
            {"error_code": "reason_required", "message": "必须填写争议原因"},
        )

    pkg = await _load_package_for_update(db, package_id, current_user.id)

    if pkg.status != "active":
        raise HTTPException(
            400,
            {"error_code": "package_not_active", "message": "仅 active 套餐可发起争议"},
        )

    if pkg.used_sessions == 0:
        raise HTTPException(
            400,
            {
                "error_code": "package_never_used_use_refund",
                "message": "未使用的套餐请走退款流程",
            },
        )

    import json as _json
    dispute = models.TaskDispute(
        task_id=None,
        package_id=pkg.id,
        initiator_id=current_user.id,
        reason=reason,
        evidence_files=_json.dumps(evidence_files) if evidence_files else None,
        status="open",
    )
    db.add(dispute)

    pkg.status = "disputed"

    # Freeze any pending PaymentTransfer for this package
    pending_transfers = db.query(models.PaymentTransfer).filter(
        models.PaymentTransfer.package_id == pkg.id,
        models.PaymentTransfer.status == "pending",
    ).all()
    for t in pending_transfers:
        t.status = "on_hold"

    await db.commit()

    # Best-effort notifications (buyer + expert team + admin channel)
    try:
        await _notify_package_dispute_opened(db, pkg, dispute)
    except Exception as e:
        logger.warning(f"Failed to send dispute notification: {e}")

    return {
        "dispute_id": dispute.id,
        "status": "open",
        "package_status": "disputed",
    }
```

- [ ] **Step 2: Add `_notify_package_dispute_opened` helper**

```python
async def _notify_package_dispute_opened(db, pkg, dispute):
    """Notify expert team admins when a buyer opens a package dispute."""
    from app.utils.notification_templates import get_notification_texts
    from app.models_expert import ExpertMember

    service_obj = db.query(models.TaskExpertService).filter(
        models.TaskExpertService.id == pkg.service_id
    ).first()
    service_name = service_obj.service_name if service_obj else ""

    t_zh, c_zh, t_en, c_en = get_notification_texts(
        "package_dispute_opened", service_name=service_name
    )

    managers = db.query(ExpertMember.user_id).filter(
        ExpertMember.expert_id == pkg.expert_id,
        ExpertMember.status == "active",
        ExpertMember.role.in_(["owner", "admin"]),
    ).all()
    for (mid,) in managers:
        crud.create_notification(
            db=db, user_id=mid, type="package_dispute_opened",
            title=t_zh, content=c_zh, title_en=t_en, content_en=c_en,
            related_id=str(pkg.id), related_type="package_dispute", auto_commit=False,
        )
    db.commit()
```

- [ ] **Step 3: Extend admin_dispute_routes.py to handle package branch**

Read: `backend/app/admin_dispute_routes.py` — find `resolve_dispute` or similar.

Add package branch to the existing resolution logic:

```python
# In resolve_dispute, after loading the dispute:
if dispute.package_id is not None:
    from app.models_expert import UserServicePackage
    from app.services.package_settlement import compute_package_split, trigger_package_release

    pkg = db.query(UserServicePackage).filter(
        UserServicePackage.id == dispute.package_id
    ).first()
    if not pkg:
        raise HTTPException(404, "Package not found")

    verdict = body.get("verdict")  # "favor_buyer" | "favor_expert" | "compromise"

    # Unfreeze previously held transfers
    pending = db.query(models.PaymentTransfer).filter(
        models.PaymentTransfer.package_id == pkg.id,
        models.PaymentTransfer.status == "on_hold",
    ).all()
    for t in pending:
        t.status = "cancelled"  # Superseded by the resolution outcome below

    if verdict == "favor_buyer":
        # Full refund to buyer, nothing to expert
        paid_pence = int(round(float(pkg.paid_amount) * 100))
        pkg.status = "refunded"
        pkg.refunded_amount_pence = paid_pence
        db.add(models.RefundRequest(
            task_id=None,
            package_id=pkg.id,
            requester_id=pkg.user_id,
            amount=paid_pence / 100.0,
            reason=f"admin_dispute_favor_buyer: {dispute.id}",
            status="approved_auto",
            payment_intent_id=pkg.payment_intent_id,
        ))
    elif verdict == "favor_expert":
        # Full release to expert
        pkg.status = "exhausted"  # Treated as "service rendered"
        trigger_package_release(db, pkg, reason=f"dispute_{dispute.id}_favor_expert")
    elif verdict == "compromise":
        # Pro-rata split using compute_package_split
        split = compute_package_split(pkg)
        pkg.status = "partially_refunded"
        pkg.released_amount_pence = split["transfer_pence"]
        pkg.platform_fee_pence = split["fee_pence"]
        pkg.refunded_amount_pence = split["unconsumed_value_pence"]

        if split["transfer_pence"] > 0:
            db.add(models.PaymentTransfer(
                task_id=None,
                package_id=pkg.id,
                taker_expert_id=pkg.expert_id,
                poster_id=pkg.user_id,
                amount=split["transfer_pence"] / 100.0,
                currency=pkg.currency or "GBP",
                status="pending",
                idempotency_key=f"pkg_{pkg.id}_dispute_{dispute.id}_transfer",
            ))
        if split["unconsumed_value_pence"] > 0:
            db.add(models.RefundRequest(
                task_id=None,
                package_id=pkg.id,
                requester_id=pkg.user_id,
                amount=split["unconsumed_value_pence"] / 100.0,
                reason=f"admin_dispute_compromise: {dispute.id}",
                status="approved_auto",
                payment_intent_id=pkg.payment_intent_id,
            ))

    dispute.status = "resolved"
    dispute.verdict = verdict
    dispute.resolved_at = get_utc_time()
    db.commit()

    return {"status": "resolved", "package_status": pkg.status}

# ... existing task branch continues below
```

- [ ] **Step 4: Verify files compile**

Run:
```bash
python -m py_compile backend/app/package_purchase_routes.py
python -m py_compile backend/app/admin_dispute_routes.py
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/package_purchase_routes.py backend/app/admin_dispute_routes.py
git commit -m "feat(package): add dispute endpoint + admin resolution package branch"
```

---

## Task 24: Extend GET `/api/my/packages` response

**Files:**
- Modify: `backend/app/expert_package_routes.py` (the `get_my_packages` endpoint)
- Modify: `backend/app/package_purchase_routes.py` (the `get_my_package_detail` endpoint)

- [ ] **Step 1: Add helper to compute `can_*` flags**

Add a helper to `backend/app/services/package_settlement.py`:

```python
def compute_package_action_flags(pkg, now) -> dict:
    """Return the UI action flags for a package.

    Returns dict with:
        in_cooldown: bool
        can_refund_full: bool  (in_cooldown AND never_used)
        can_refund_partial: bool  (active AND used > 0)
        can_review: bool  (status in set)
        can_dispute: bool  (active AND used > 0)
        status_display: str  (i18n key, let frontend i18n it)
    """
    # Normalize tzinfo
    cooldown_until = pkg.cooldown_until
    if cooldown_until and cooldown_until.tzinfo is None:
        from datetime import timezone
        cooldown_until = cooldown_until.replace(tzinfo=timezone.utc)

    in_cooldown = cooldown_until is not None and now < cooldown_until
    never_used = pkg.used_sessions == 0
    has_used = pkg.used_sessions > 0

    can_refund_full = pkg.status == "active" and in_cooldown and never_used
    can_refund_partial = pkg.status == "active" and (
        (not in_cooldown and has_used) or (in_cooldown and has_used)
    )
    can_review = pkg.status in ("exhausted", "expired", "released", "partially_refunded")
    can_dispute = pkg.status == "active" and has_used

    return {
        "in_cooldown": in_cooldown,
        "can_refund_full": can_refund_full,
        "can_refund_partial": can_refund_partial,
        "can_review": can_review,
        "can_dispute": can_dispute,
        "status_display": f"package_status_{pkg.status}",  # Frontend i18n key
    }
```

- [ ] **Step 2: Update `get_my_packages` response serialization**

Modify `backend/app/expert_package_routes.py:21-52`. Replace the dict comprehension:

```python
@expert_package_router.get("/api/my/packages")
async def get_my_packages(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """获取我购买的套餐列表"""
    from app.services.package_settlement import compute_package_action_flags
    from app.utils.time_utils import get_utc_time

    result = await db.execute(
        select(UserServicePackage)
        .where(UserServicePackage.user_id == current_user.id)
        .order_by(UserServicePackage.purchased_at.desc())
    )
    packages = result.scalars().all()
    now = get_utc_time()

    out = []
    for p in packages:
        flags = compute_package_action_flags(p, now)
        out.append({
            "id": p.id,
            "service_id": p.service_id,
            "expert_id": p.expert_id,
            "total_sessions": p.total_sessions,
            "used_sessions": p.used_sessions,
            "remaining_sessions": p.total_sessions - p.used_sessions,
            "status": p.status,
            "status_display": flags["status_display"],
            "purchased_at": p.purchased_at.isoformat() if p.purchased_at else None,
            "cooldown_until": p.cooldown_until.isoformat() if p.cooldown_until else None,
            "in_cooldown": flags["in_cooldown"],
            "expires_at": p.expires_at.isoformat() if p.expires_at else None,
            "payment_intent_id": p.payment_intent_id,
            "paid_amount": float(p.paid_amount) if p.paid_amount is not None else None,
            "currency": p.currency,
            "bundle_breakdown": p.bundle_breakdown,
            "released_amount_pence": p.released_amount_pence,
            "refunded_amount_pence": p.refunded_amount_pence,
            "platform_fee_pence": p.platform_fee_pence,
            "released_at": p.released_at.isoformat() if p.released_at else None,
            "refunded_at": p.refunded_at.isoformat() if p.refunded_at else None,
            "can_refund_full": flags["can_refund_full"],
            "can_refund_partial": flags["can_refund_partial"],
            "can_review": flags["can_review"],
            "can_dispute": flags["can_dispute"],
        })
    return out
```

- [ ] **Step 3: Same extension to `get_my_package_detail`**

Apply the same flag computation + new fields to `package_purchase_routes.py:318-390` in `get_my_package_detail`.

- [ ] **Step 4: Commit**

```bash
git add backend/app/services/package_settlement.py backend/app/expert_package_routes.py backend/app/package_purchase_routes.py
git commit -m "feat(package): GET /api/my/packages exposes lifecycle fields and action flags"
```

---

## Task 25: Update Flutter `UserServicePackage` model

**Files:**
- Modify: `link2ur/lib/data/models/user_service_package.dart` (or wherever the model lives)

- [ ] **Step 1: Locate the model file**

Run: `grep -rn "class UserServicePackage\|class ServicePackage" link2ur/lib/data/models/`

If the model doesn't exist yet, locate how `expert_team_bloc.dart:596` parses `getMyPackages()` results (currently as `Map<String, dynamic>`). Create a proper model.

- [ ] **Step 2: Add new fields**

Extend the model:

```dart
class UserServicePackage {
  final int id;
  final int serviceId;
  final String? expertId;
  final int totalSessions;
  final int usedSessions;
  final int remainingSessions;
  final String status;
  final String statusDisplay;
  final DateTime? purchasedAt;
  final DateTime? cooldownUntil;
  final bool inCooldown;
  final DateTime? expiresAt;
  final String? paymentIntentId;
  final double? paidAmount;
  final String? currency;
  final Map<String, dynamic>? bundleBreakdown;
  final int? releasedAmountPence;
  final int? refundedAmountPence;
  final int? platformFeePence;
  final DateTime? releasedAt;
  final DateTime? refundedAt;
  final bool canRefundFull;
  final bool canRefundPartial;
  final bool canReview;
  final bool canDispute;

  UserServicePackage({
    required this.id,
    required this.serviceId,
    this.expertId,
    required this.totalSessions,
    required this.usedSessions,
    required this.remainingSessions,
    required this.status,
    required this.statusDisplay,
    this.purchasedAt,
    this.cooldownUntil,
    required this.inCooldown,
    this.expiresAt,
    this.paymentIntentId,
    this.paidAmount,
    this.currency,
    this.bundleBreakdown,
    this.releasedAmountPence,
    this.refundedAmountPence,
    this.platformFeePence,
    this.releasedAt,
    this.refundedAt,
    required this.canRefundFull,
    required this.canRefundPartial,
    required this.canReview,
    required this.canDispute,
  });

  factory UserServicePackage.fromJson(Map<String, dynamic> json) {
    return UserServicePackage(
      id: json['id'] as int,
      serviceId: json['service_id'] as int,
      expertId: json['expert_id'] as String?,
      totalSessions: json['total_sessions'] as int,
      usedSessions: json['used_sessions'] as int,
      remainingSessions: json['remaining_sessions'] as int,
      status: json['status'] as String,
      statusDisplay: json['status_display'] as String? ?? 'package_status_unknown',
      purchasedAt: json['purchased_at'] != null
          ? DateTime.parse(json['purchased_at'] as String)
          : null,
      cooldownUntil: json['cooldown_until'] != null
          ? DateTime.parse(json['cooldown_until'] as String)
          : null,
      inCooldown: json['in_cooldown'] as bool? ?? false,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      paymentIntentId: json['payment_intent_id'] as String?,
      paidAmount: (json['paid_amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      bundleBreakdown: json['bundle_breakdown'] as Map<String, dynamic>?,
      releasedAmountPence: json['released_amount_pence'] as int?,
      refundedAmountPence: json['refunded_amount_pence'] as int?,
      platformFeePence: json['platform_fee_pence'] as int?,
      releasedAt: json['released_at'] != null
          ? DateTime.parse(json['released_at'] as String)
          : null,
      refundedAt: json['refunded_at'] != null
          ? DateTime.parse(json['refunded_at'] as String)
          : null,
      canRefundFull: json['can_refund_full'] as bool? ?? false,
      canRefundPartial: json['can_refund_partial'] as bool? ?? false,
      canReview: json['can_review'] as bool? ?? false,
      canDispute: json['can_dispute'] as bool? ?? false,
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/data/models/user_service_package.dart
git commit -m "feat(flutter): UserServicePackage model with lifecycle fields"
```

---

## Task 26: Extend Flutter `PackagePurchaseRepository`

**Files:**
- Modify: `link2ur/lib/data/repositories/package_purchase_repository.dart`

- [ ] **Step 1: Add three new methods**

```dart
/// Request a refund for a package.
/// Backend decides full vs pro-rata based on cooldown + usage state.
Future<Map<String, dynamic>> requestRefund(int packageId, {String? reason}) async {
  final res = await _api.post<Map<String, dynamic>>(
    '/api/my/packages/$packageId/refund',
    data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
  );
  if (!res.isSuccess || res.data == null) {
    throw Exception(res.errorCode ?? res.message ?? 'refund_failed');
  }
  return res.data!;
}

/// Submit a review for a completed package.
Future<Map<String, dynamic>> submitReview(
  int packageId, {
  required int rating,
  required String comment,
  List<String>? images,
}) async {
  final res = await _api.post<Map<String, dynamic>>(
    '/api/my/packages/$packageId/review',
    data: {
      'rating': rating,
      'comment': comment,
      if (images != null && images.isNotEmpty) 'images': images,
    },
  );
  if (!res.isSuccess || res.data == null) {
    throw Exception(res.errorCode ?? res.message ?? 'review_failed');
  }
  return res.data!;
}

/// Open a dispute for an active package (must have at least 1 usage).
Future<Map<String, dynamic>> openDispute(
  int packageId, {
  required String reason,
  List<String>? evidenceFiles,
}) async {
  final res = await _api.post<Map<String, dynamic>>(
    '/api/my/packages/$packageId/dispute',
    data: {
      'reason': reason,
      if (evidenceFiles != null && evidenceFiles.isNotEmpty)
        'evidence_files': evidenceFiles,
    },
  );
  if (!res.isSuccess || res.data == null) {
    throw Exception(res.errorCode ?? res.message ?? 'dispute_failed');
  }
  return res.data!;
}
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/data/repositories/package_purchase_repository.dart
git commit -m "feat(flutter): repository methods for refund/review/dispute"
```

---

## Task 27: Update Flutter package detail view with action buttons

**Files:**
- Modify: `link2ur/lib/features/expert_team/views/expert_packages_view.dart` (or the package detail view location)

- [ ] **Step 1: Locate the detail view**

Run: `grep -rn "expert_packages_view\|package_detail_view" link2ur/lib/features/`

- [ ] **Step 2: Add three conditional action buttons and a banner**

In the detail view's build method, after the existing package info section, add:

```dart
// Cooldown banner
if (package.inCooldown) ...[
  Container(
    padding: const EdgeInsets.all(12),
    color: Colors.blue.shade50,
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(context.l10n.packageCooldownBanner),
        ),
      ],
    ),
  ),
  const SizedBox(height: 12),
],

// Expiry warning banner (within 7 days)
if (package.expiresAt != null &&
    package.expiresAt!.difference(DateTime.now()).inDays <= 7 &&
    package.expiresAt!.isAfter(DateTime.now()) &&
    package.usedSessions < package.totalSessions) ...[
  Container(
    padding: const EdgeInsets.all(12),
    color: Colors.orange.shade50,
    child: Row(
      children: [
        const Icon(Icons.warning_amber, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(context.l10n.packageExpirySoonBanner),
        ),
      ],
    ),
  ),
  const SizedBox(height: 12),
],

// Action buttons row
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    if (package.canRefundFull || package.canRefundPartial)
      ElevatedButton.icon(
        icon: const Icon(Icons.money_off),
        label: Text(context.l10n.packageActionRefund),
        onPressed: () => _confirmRefund(context, package),
      ),
    if (package.canReview)
      ElevatedButton.icon(
        icon: const Icon(Icons.rate_review),
        label: Text(context.l10n.packageActionReview),
        onPressed: () => _openReviewDialog(context, package),
      ),
    if (package.canDispute)
      ElevatedButton.icon(
        icon: const Icon(Icons.gavel),
        label: Text(context.l10n.packageActionDispute),
        onPressed: () => _openDisputeDialog(context, package),
      ),
  ],
),
```

- [ ] **Step 3: Implement `_confirmRefund` / `_openReviewDialog` / `_openDisputeDialog` handlers**

Add to the same file:

```dart
Future<void> _confirmRefund(BuildContext context, UserServicePackage package) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.l10n.packageRefundConfirmTitle),
      content: Text(
        package.canRefundFull
            ? context.l10n.packageRefundConfirmFullContent
            : context.l10n.packageRefundConfirmPartialContent,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(context.l10n.commonConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    final repo = context.read<PackagePurchaseRepository>();
    final result = await repo.requestRefund(package.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.packageRefundSuccess)),
    );
    // Refresh list
    context.read<ExpertTeamBloc>().add(ExpertTeamLoadMyPackages());
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.localizeError(e.toString()))),
    );
  }
}

Future<void> _openReviewDialog(BuildContext context, UserServicePackage package) async {
  // Simplified: show rating slider + text field, call repo.submitReview
  // (Detailed UI is left to designer; the data flow is: collect, call repo, snackbar)
}

Future<void> _openDisputeDialog(BuildContext context, UserServicePackage package) async {
  // Simplified: show text field for reason, call repo.openDispute
}
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/expert_team/views/expert_packages_view.dart
git commit -m "feat(flutter): add refund/review/dispute buttons + cooldown banner to package view"
```

---

## Task 28: Add Flutter i18n keys

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: Add keys to app_en.arb**

```json
{
  "packageCooldownBanner": "24-hour cooldown period: full refund available if no sessions used",
  "packageExpirySoonBanner": "This package expires soon. Please use your remaining sessions.",
  "packageActionRefund": "Refund",
  "packageActionReview": "Review",
  "packageActionDispute": "Dispute",
  "packageRefundConfirmTitle": "Confirm Refund",
  "packageRefundConfirmFullContent": "You will receive a full refund. Continue?",
  "packageRefundConfirmPartialContent": "You will receive a pro-rata refund based on unused sessions. Continue?",
  "packageRefundSuccess": "Refund request submitted",
  "packageStatusActive": "Active",
  "packageStatusExhausted": "All sessions used",
  "packageStatusExpired": "Expired",
  "packageStatusReleased": "Settled",
  "packageStatusRefunded": "Refunded",
  "packageStatusPartiallyRefunded": "Partially refunded",
  "packageStatusDisputed": "In dispute",
  "packageStatusCancelled": "Cancelled"
}
```

- [ ] **Step 2: Add matching keys to app_zh.arb**

```json
{
  "packageCooldownBanner": "24 小时冷静期内,未使用可申请全额退款",
  "packageExpirySoonBanner": "套餐即将过期,请及时使用剩余次数",
  "packageActionRefund": "申请退款",
  "packageActionReview": "评价",
  "packageActionDispute": "发起争议",
  "packageRefundConfirmTitle": "确认退款",
  "packageRefundConfirmFullContent": "您将获得全额退款,是否继续?",
  "packageRefundConfirmPartialContent": "您将按未使用次数比例获得退款,是否继续?",
  "packageRefundSuccess": "退款申请已提交",
  "packageStatusActive": "使用中",
  "packageStatusExhausted": "已用完",
  "packageStatusExpired": "已过期",
  "packageStatusReleased": "已结算",
  "packageStatusRefunded": "已退款",
  "packageStatusPartiallyRefunded": "部分退款",
  "packageStatusDisputed": "争议中",
  "packageStatusCancelled": "已取消"
}
```

- [ ] **Step 3: Add matching keys to app_zh_Hant.arb**

```json
{
  "packageCooldownBanner": "24 小時冷靜期內,未使用可申請全額退款",
  "packageExpirySoonBanner": "套餐即將過期,請及時使用剩餘次數",
  "packageActionRefund": "申請退款",
  "packageActionReview": "評價",
  "packageActionDispute": "發起爭議",
  "packageRefundConfirmTitle": "確認退款",
  "packageRefundConfirmFullContent": "您將獲得全額退款,是否繼續?",
  "packageRefundConfirmPartialContent": "您將按未使用次數比例獲得退款,是否繼續?",
  "packageRefundSuccess": "退款申請已提交",
  "packageStatusActive": "使用中",
  "packageStatusExhausted": "已用完",
  "packageStatusExpired": "已過期",
  "packageStatusReleased": "已結算",
  "packageStatusRefunded": "已退款",
  "packageStatusPartiallyRefunded": "部分退款",
  "packageStatusDisputed": "爭議中",
  "packageStatusCancelled": "已取消"
}
```

- [ ] **Step 4: Regenerate localization files**

Run:
```bash
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter gen-l10n
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/l10n/
git commit -m "feat(flutter): add package lifecycle i18n keys (en/zh/zh_Hant)"
```

---

## Task 29: Run full test suite + flutter analyze

**Files:** (no changes, verification only)

- [ ] **Step 1: Run all backend unit tests**

Run: `cd backend && pytest tests/test_package_settlement.py tests/test_package_refund_endpoint.py -v`
Expected: all tests PASS

- [ ] **Step 2: Run the full backend test suite**

Run: `cd backend && pytest -x`
Expected: no regressions in other tests

- [ ] **Step 3: Run flutter analyze**

Run:
```bash
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter analyze
```
Expected: no errors (warnings OK)

- [ ] **Step 4: If all pass, commit (no-op if no changes)**

```bash
# Only if any adjustments were needed during verification
git status
git add -A
git commit -m "test: verify full suite passes" || echo "no changes"
```

---

## Task 30: Deployment + smoke test

**Files:** (no changes, deployment steps)

- [ ] **Step 1: Push feature branch**

```bash
git push -u origin feat/package-lifecycle-completion
```

- [ ] **Step 2: Create PR or merge to main**

Either open a PR on GitHub or (if solo workflow) merge locally and push main:

```bash
git checkout main
git merge --no-ff feat/package-lifecycle-completion
git push origin main
```

- [ ] **Step 3: Deploy backend to Railway**

Railway auto-deploys on push to main. Watch the deploy logs until `INFO: Application startup complete`.

- [ ] **Step 4: Verify migrations ran**

Check Railway logs for:
```
app.db_migrations: ✅ 迁移 189 执行成功
app.db_migrations: ✅ 迁移 190 执行成功
app.db_migrations: ✅ 迁移 191 执行成功
app.db_migrations: ✅ 迁移 192 执行成功
app.db_migrations: ✅ 迁移 193 执行成功
```

- [ ] **Step 5: Deploy Flutter build**

Run:
```bash
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"
flutter build ios
# or flutter build apk
```

- [ ] **Step 6: Run smoke test (see spec Section 11.3)**

Execute the 9 smoke-test paths from `docs/superpowers/specs/2026-04-09-package-lifecycle-completion-design.md:1026-1044`. Document any failures.

| # | Step | Expected |
|---|---|---|
| 1 | Buy multi £10 (10×£1) | DB row has `cooldown_until` and `unit_price_pence_snapshot` |
| 2 | Immediate refund (0 used, <24h) | Full refund £10, status='refunded', RefundRequest row |
| 3 | Buy, redeem 1, refund | Pro-rata: expert £0.92, buyer £9, status='partially_refunded' |
| 4 | Buy, redeem 10 times | Auto exhausted → released, expert £9.20 within minutes |
| 5 | Buy, `UPDATE expires_at = past`, wait 1h | Cron triggers expired → released |
| 6 | Bundle (A×2 £5 + B×3 £10, paid £40), redeem A×1+B×1, refund | Consumed fair = £15, expert £13.80, buyer £25 |
| 7 | Buy, redeem all, review | Review row has package_id, expert rating includes it |
| 8 | Buy, redeem 1, open dispute | status='disputed', pending transfers on_hold |
| 9 | Admin resolve dispute (3 verdicts) | Each verdict produces correct financial outcome |

- [ ] **Step 7: Final commit with any fixes discovered during smoke test**

```bash
git add -A
git commit -m "fix(package): smoke test fixes" || echo "no changes"
git push origin main
```

---

## Plan Self-Review Notes

### Spec coverage map

| Spec section | Task(s) |
|---|---|
| Section 5.1 UserServicePackage migration | Task 1, Task 6 |
| Section 5.2 payment_transfers.package_id | Task 2, Task 7 |
| Section 5.3 refund_requests.package_id | Task 3, Task 7 |
| Section 5.4 reviews.package_id | Task 4, Task 7 |
| Section 5.5 task_disputes.package_id | Task 5, Task 7 |
| Section 5.6 bundle_breakdown format upgrade | Task 11 |
| Section 6.1 compute_package_split | Task 8, Task 9 |
| Section 6.2 trigger_package_release | Task 10 |
| Section 6.3 refund endpoint | Tasks 19, 20, 21 |
| Section 6.4 redemption endpoint changes | Task 13 |
| Section 6.5 webhook changes | Task 12 |
| Section 6.6 _build_bundle_breakdown | Task 11 |
| Section 6.7 payment_transfer_service | Task 14 |
| Section 6.8 refund_service | Task 15 |
| Section 7.1 check_expired_packages | Task 16 |
| Section 7.2 send_package_expiry_reminders | Task 17 |
| Section 8 endpoints (refund/review/dispute) | Tasks 20, 22, 23 |
| Section 8.3 GET /api/my/packages response | Task 24 |
| Section 9 notification templates | Task 18 |
| Section 10 Flutter changes | Tasks 25, 26, 27, 28 |
| Section 11 deployment | Task 30 |
| Section 12 testing | Tasks 9, 10, 21, 29 |

### No gaps identified.

### Known simplifications in the plan

1. **Task 22 expert rating extension**: The exact code location depends on where the rating aggregation currently lives. The plan describes the extension pattern; the engineer will need to grep for `expert rating` or `avg_rating` to find it.

2. **Task 23 dispute admin resolution**: The package branch is inserted into `resolve_dispute`; the exact insertion point depends on the existing function structure. The plan describes the logic; the engineer will fit it to the existing code style.

3. **Task 27 review/dispute dialogs**: Left as stubs (marked explicitly). These are simple form UI and can be implemented following the app's existing dialog patterns.

4. **Integration tests** deferred to smoke test (Task 30). For the scope and user base, unit tests + manual smoke test is sufficient.
