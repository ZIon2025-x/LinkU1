# 达人独立活动（抽奖/抢位）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow expert teams to create lottery and first-come activities without requiring a linked service, with optional pricing and auto/manual draw support.

**Architecture:** Extend `expert_activity_routes.py` to accept `lottery`/`first_come` activity types with optional `expert_service_id`. Reuse existing `OfficialActivityApplication` table and `official_activity_routes.py` apply endpoint. Extract shared draw logic from `admin_official_routes.py` into a reusable module, extend `official_draw_task.py` scan to cover all lottery activities. Add a new manual draw endpoint for expert teams.

**Tech Stack:** Python/FastAPI, SQLAlchemy (async+sync), PostgreSQL, existing task scheduler

**Spec:** `docs/superpowers/specs/2026-04-17-expert-independent-activities-design.md`

**Scope:** Backend only (9 tasks). Flutter frontend changes (发布入口、表单、详情页、管理页) will be a separate plan.

---

## File Structure

| Action | File | Responsibility |
|---|---|---|
| Migrate | `backend/migrations/205_add_draw_trigger_columns.sql` | Add `draw_trigger` + `draw_participant_count` columns |
| Modify | `backend/app/models.py:2208-2211` | Add 2 new columns to Activity model |
| Modify | `backend/app/expert_activity_routes.py` | Extend schema + route for lottery/first_come |
| Create | `backend/app/draw_logic.py` | Shared async draw function extracted from admin_official_routes |
| Modify | `backend/app/admin_official_routes.py:72-135` | Delegate to `draw_logic.py` |
| Modify | `backend/app/official_draw_task.py` | Expand scan, delegate to shared sync draw, handle by_count |
| Modify | `backend/app/official_activity_routes.py:44-95` | Add by_count trigger check after apply, add payment-required response |
| Create | `backend/tests/test_expert_independent_activity.py` | Tests for the new feature |

---

### Task 1: DB Migration — add `draw_trigger` + `draw_participant_count` columns

**Files:**
- Create: `backend/migrations/205_add_draw_trigger_columns.sql`

- [ ] **Step 1: Write the migration SQL**

```sql
-- 205_add_draw_trigger_columns.sql
-- Add draw trigger type and participant count threshold for lottery activities
-- draw_trigger: 'by_time' | 'by_count' | 'both' (NULL for non-auto or non-lottery)
-- draw_participant_count: threshold for by_count / both triggers

ALTER TABLE activities ADD COLUMN IF NOT EXISTS draw_trigger VARCHAR(10) DEFAULT NULL;
ALTER TABLE activities ADD COLUMN IF NOT EXISTS draw_participant_count INTEGER DEFAULT NULL;
```

- [ ] **Step 2: Commit**

```bash
git add backend/migrations/205_add_draw_trigger_columns.sql
git commit -m "migration(205): add draw_trigger and draw_participant_count to activities"
```

---

### Task 2: Model — add columns to Activity

**Files:**
- Modify: `backend/app/models.py:2211` (after `is_drawn` line)

- [ ] **Step 1: Add the two new columns to Activity model**

In `backend/app/models.py`, after line 2211 (`is_drawn = Column(Boolean, default=False, nullable=False)`), add:

```python
    draw_trigger = Column(String(10), nullable=True)        # by_time / by_count / both
    draw_participant_count = Column(Integer, nullable=True)  # threshold for by_count/both
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/models.py
git commit -m "feat: add draw_trigger and draw_participant_count to Activity model"
```

---

### Task 3: Extract shared draw logic into `draw_logic.py`

**Files:**
- Create: `backend/app/draw_logic.py`
- Modify: `backend/app/admin_official_routes.py:72-135`

The async `_perform_draw` in `admin_official_routes.py` (lines 72–135) and the sync `_perform_draw_sync` in `official_draw_task.py` (lines 41–99) are near-identical. Extract both into a shared module so the new expert manual-draw endpoint, the admin manual-draw, the scheduled auto-draw, and the by_count trigger can all reuse one implementation.

- [ ] **Step 1: Create `backend/app/draw_logic.py`**

```python
"""
Shared lottery draw logic — async and sync versions.

Consumers:
- admin_official_routes.py (admin manual draw) — async
- official_draw_task.py (scheduled auto draw) — sync
- expert_activity_routes.py (expert manual draw) — async
- official_activity_routes.py (by_count trigger) — async
"""
import random
import logging
from typing import List

from sqlalchemy import select
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.utils import get_utc_time

logger = logging.getLogger(__name__)


async def perform_draw_async(db: AsyncSession, activity: models.Activity) -> List[dict]:
    """Async draw: pick winners, update statuses, send notifications, commit.

    Works for all prize_type values:
    - voucher_code: assigns prize_index for code lookup
    - points / physical / in_person: winners list only, no extra distribution
    """
    from app.async_crud import AsyncNotificationCRUD

    apps_result = await db.execute(
        select(models.OfficialActivityApplication, models.User)
        .join(models.User, models.User.id == models.OfficialActivityApplication.user_id)
        .where(
            models.OfficialActivityApplication.activity_id == activity.id,
            models.OfficialActivityApplication.status == "pending",
        )
    )
    all_apps = apps_result.all()

    prize_count = activity.prize_count or 1
    selected = random.sample(all_apps, min(prize_count, len(all_apps)))
    selected_ids = {app.user_id for app, _ in selected}
    voucher_codes = activity.voucher_codes or []
    winners_data = []

    for i, (app, user) in enumerate(selected):
        app.status = "won"
        app.notified_at = get_utc_time()
        if activity.prize_type == "voucher_code" and i < len(voucher_codes):
            app.prize_index = i
        winners_data.append({
            "user_id": app.user_id,
            "name": user.name,
            "prize_index": app.prize_index,
        })

        prize_desc = activity.prize_description or "奖品"
        voucher_info = (
            f"\n您的优惠码：{voucher_codes[i]}"
            if app.prize_index is not None and i < len(voucher_codes)
            else ""
        )
        await AsyncNotificationCRUD.create_notification(
            db=db,
            user_id=app.user_id,
            notification_type="official_activity_won",
            title="🎉 恭喜中奖！",
            content=f"您参与的活动「{activity.title}」已开奖，您获得了{prize_desc}！{voucher_info}",
            related_id=str(activity.id),
        )

    for app, _ in all_apps:
        if app.user_id not in selected_ids:
            app.status = "lost"

    activity.is_drawn = True
    activity.drawn_at = get_utc_time()
    activity.winners = winners_data
    activity.status = "completed"

    await db.commit()
    return winners_data


def perform_draw_sync(db: Session, activity: models.Activity) -> List[dict]:
    """Sync draw: same logic for task-scheduler context."""
    from app.crud.notification import create_notification

    all_apps = db.execute(
        select(models.OfficialActivityApplication, models.User)
        .join(models.User, models.User.id == models.OfficialActivityApplication.user_id)
        .where(
            models.OfficialActivityApplication.activity_id == activity.id,
            models.OfficialActivityApplication.status == "pending",
        )
    ).all()

    prize_count = activity.prize_count or 1
    selected = random.sample(all_apps, min(prize_count, len(all_apps)))
    selected_ids = {app.user_id for app, _ in selected}
    voucher_codes = activity.voucher_codes or []
    winners_data = []

    for i, (app, user) in enumerate(selected):
        app.status = "won"
        app.notified_at = get_utc_time()
        if activity.prize_type == "voucher_code" and i < len(voucher_codes):
            app.prize_index = i
        winners_data.append({
            "user_id": app.user_id,
            "name": user.name,
            "prize_index": app.prize_index,
        })

        try:
            prize_desc = activity.prize_description or "奖品"
            voucher_info = (
                f"\n您的优惠码：{voucher_codes[i]}"
                if app.prize_index is not None and i < len(voucher_codes)
                else ""
            )
            create_notification(
                db=db,
                user_id=app.user_id,
                type="official_activity_won",
                title="🎉 恭喜中奖！",
                content=f"您参与的活动「{activity.title}」已开奖，您获得了{prize_desc}！{voucher_info}",
                related_id=str(activity.id),
                related_type="activity_id",
                auto_commit=False,
            )
        except Exception as e:
            logger.warning(f"Failed to send notification to {app.user_id}: {e}")

    for app, _ in all_apps:
        if app.user_id not in selected_ids:
            app.status = "lost"

    activity.is_drawn = True
    activity.drawn_at = get_utc_time()
    activity.winners = winners_data
    activity.status = "completed"
    db.commit()
    return winners_data
```

- [ ] **Step 2: Update `admin_official_routes.py` to import from `draw_logic`**

Replace the `_perform_draw` function body (lines 72–135) with a delegation:

```python
from app.draw_logic import perform_draw_async


async def _perform_draw(db: AsyncSession, activity: models.Activity) -> List[dict]:
    """Delegate to shared draw logic."""
    return await perform_draw_async(db, activity)
```

- [ ] **Step 3: Update `official_draw_task.py` to import from `draw_logic`**

Replace the `_perform_draw_sync` function body (lines 41–99) with a delegation:

```python
from app.draw_logic import perform_draw_sync


def _perform_draw_sync(db: Session, activity: models.Activity):
    """Delegate to shared draw logic."""
    perform_draw_sync(db, activity)
```

- [ ] **Step 4: Verify the app starts without import errors**

```bash
cd backend && python -c "from app.draw_logic import perform_draw_async, perform_draw_sync; print('OK')"
```

Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add backend/app/draw_logic.py backend/app/admin_official_routes.py backend/app/official_draw_task.py
git commit -m "refactor: extract shared draw logic into draw_logic.py"
```

---

### Task 4: Extend `TeamActivityCreate` schema and route validation

**Files:**
- Modify: `backend/app/expert_activity_routes.py`
- Test: `backend/tests/test_expert_independent_activity.py`

- [ ] **Step 1: Write failing tests for the new schema validation**

Create `backend/tests/test_expert_independent_activity.py`:

```python
"""Tests for expert independent activities (lottery / first_come)."""
import pytest
from datetime import datetime, timezone, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi import HTTPException


class TestTeamActivityCreateSchema:
    """Test the updated TeamActivityCreate schema accepts new fields."""

    def test_lottery_schema_accepts_prize_fields(self):
        from app.expert_activity_routes import TeamActivityCreate

        body = TeamActivityCreate(
            title="Test Lottery",
            description="A test lottery activity",
            location="London",
            task_type="official",
            deadline=datetime.now(timezone.utc) + timedelta(days=7),
            activity_type="lottery",
            prize_type="physical",
            prize_count=3,
            draw_mode="auto",
            draw_trigger="by_time",
            draw_at=datetime.now(timezone.utc) + timedelta(days=7),
        )
        assert body.activity_type == "lottery"
        assert body.prize_type == "physical"
        assert body.draw_trigger == "by_time"
        assert body.expert_service_id is None

    def test_first_come_schema_accepts_prize_fields(self):
        from app.expert_activity_routes import TeamActivityCreate

        body = TeamActivityCreate(
            title="Test First Come",
            description="A test first-come activity",
            location="London",
            task_type="official",
            deadline=datetime.now(timezone.utc) + timedelta(days=7),
            activity_type="first_come",
            prize_type="in_person",
            prize_count=5,
        )
        assert body.activity_type == "first_come"
        assert body.expert_service_id is None

    def test_standard_still_requires_expert_service_id(self):
        """Standard activities should still work with expert_service_id."""
        from app.expert_activity_routes import TeamActivityCreate

        body = TeamActivityCreate(
            expert_service_id=1,
            title="Test Standard",
            description="A standard activity",
            location="London",
            task_type="tutoring",
            deadline=datetime.now(timezone.utc) + timedelta(days=7),
            max_participants=10,
        )
        assert body.activity_type == "standard"
        assert body.expert_service_id == 1

    def test_lottery_by_count_schema(self):
        from app.expert_activity_routes import TeamActivityCreate

        body = TeamActivityCreate(
            title="Lottery by count",
            description="Draw when full",
            location="London",
            task_type="official",
            deadline=datetime.now(timezone.utc) + timedelta(days=7),
            activity_type="lottery",
            prize_type="physical",
            prize_count=3,
            draw_mode="auto",
            draw_trigger="by_count",
            draw_participant_count=30,
        )
        assert body.draw_trigger == "by_count"
        assert body.draw_participant_count == 30
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd backend && python -m pytest tests/test_expert_independent_activity.py -v
```

Expected: FAIL — `TeamActivityCreate` does not accept `prize_type`, `draw_trigger`, etc.

- [ ] **Step 3: Update `TeamActivityCreate` schema in `expert_activity_routes.py`**

Replace the schema class (lines 25–72) with:

```python
class TeamActivityCreate(BaseModel):
    """Body for creating a team-owned activity.

    - standard: requires expert_service_id (existing flow)
    - lottery / first_come: expert_service_id is optional
    """
    expert_service_id: Optional[int] = None  # required for standard, optional for lottery/first_come
    title: str
    description: str
    location: str
    task_type: str
    deadline: datetime

    # Pricing (inherited from service for standard, manual for independent)
    original_price_per_participant: Optional[float] = Field(None, ge=0)
    discount_percentage: Optional[float] = Field(None, ge=0, le=100)
    discounted_price_per_participant: Optional[float] = Field(None, ge=0)
    currency: str = 'GBP'

    # Reward
    reward_type: str = 'cash'  # 'cash' | 'points' | 'both'
    points_reward: Optional[int] = None

    # Participants
    max_participants: Optional[int] = None  # auto-derived for lottery/first_come
    min_participants: int = 1

    # Activity behavior
    completion_rule: str = 'all'
    reward_distribution: str = 'equal'
    activity_type: str = 'standard'  # 'standard' | 'lottery' | 'first_come'
    is_public: bool = True
    visibility: str = 'public'
    activity_end_date: Optional[datetime] = None

    # Reward applicants
    reward_applicants: bool = False
    applicant_reward_amount: Optional[float] = None
    applicant_points_reward: Optional[int] = None

    # Images
    images: Optional[List[str]] = None

    # Location coordinates + radius
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    service_radius_km: Optional[Literal[0, 5, 10, 25, 50]] = None

    # ── Lottery / First-come fields ──
    prize_type: Optional[str] = None        # 'physical' | 'in_person' (expert-only)
    prize_description: Optional[str] = None
    prize_description_en: Optional[str] = None
    prize_count: Optional[int] = Field(None, gt=0)
    draw_mode: Optional[str] = None         # 'auto' | 'manual' (lottery only)
    draw_trigger: Optional[str] = None      # 'by_time' | 'by_count' | 'both' (auto only)
    draw_at: Optional[datetime] = None      # auto + by_time/both
    draw_participant_count: Optional[int] = Field(None, gt=0)  # auto + by_count/both
```

- [ ] **Step 4: Run schema tests to verify they pass**

```bash
cd backend && python -m pytest tests/test_expert_independent_activity.py::TestTeamActivityCreateSchema -v
```

Expected: all 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/expert_activity_routes.py backend/tests/test_expert_independent_activity.py
git commit -m "feat: extend TeamActivityCreate schema for lottery/first_come fields"
```

---

### Task 5: Update route validation logic in `create_team_activity`

**Files:**
- Modify: `backend/app/expert_activity_routes.py:75-231`
- Test: `backend/tests/test_expert_independent_activity.py`

- [ ] **Step 1: Write failing tests for route validation**

Append to `backend/tests/test_expert_independent_activity.py`:

```python
class TestCreateTeamActivityValidation:
    """Test the validation logic inside the route handler."""

    def test_standard_without_service_id_raises(self):
        """standard activity_type must have expert_service_id."""
        from app.expert_activity_routes import _validate_lottery_first_come_fields
        from fastapi import HTTPException

        body = MagicMock()
        body.activity_type = "standard"
        body.expert_service_id = None
        with pytest.raises(HTTPException) as exc_info:
            _validate_lottery_first_come_fields(body)
        assert exc_info.value.status_code == 422

    def test_lottery_without_prize_type_raises(self):
        body = MagicMock()
        body.activity_type = "lottery"
        body.prize_type = None
        with pytest.raises(HTTPException):
            _validate_lottery_first_come_fields(body)

    def test_lottery_invalid_prize_type_raises(self):
        body = MagicMock()
        body.activity_type = "lottery"
        body.prize_type = "points"
        body.prize_count = 3
        body.draw_mode = "manual"
        with pytest.raises(HTTPException) as exc_info:
            _validate_lottery_first_come_fields(body)
        assert "physical" in str(exc_info.value.detail) or "in_person" in str(exc_info.value.detail)

    def test_lottery_auto_by_time_without_draw_at_raises(self):
        body = MagicMock()
        body.activity_type = "lottery"
        body.prize_type = "physical"
        body.prize_count = 3
        body.draw_mode = "auto"
        body.draw_trigger = "by_time"
        body.draw_at = None
        body.draw_participant_count = None
        with pytest.raises(HTTPException):
            _validate_lottery_first_come_fields(body)

    def test_lottery_auto_by_count_without_count_raises(self):
        body = MagicMock()
        body.activity_type = "lottery"
        body.prize_type = "physical"
        body.prize_count = 3
        body.draw_mode = "auto"
        body.draw_trigger = "by_count"
        body.draw_at = None
        body.draw_participant_count = None
        with pytest.raises(HTTPException):
            _validate_lottery_first_come_fields(body)

    def test_max_participants_auto_derived_first_come(self):
        from app.expert_activity_routes import _derive_max_participants

        body = MagicMock()
        body.activity_type = "first_come"
        body.prize_count = 5
        body.max_participants = None
        body.draw_trigger = None
        body.draw_participant_count = None
        result = _derive_max_participants(body)
        assert result == 5

    def test_max_participants_auto_derived_lottery_by_count(self):
        from app.expert_activity_routes import _derive_max_participants

        body = MagicMock()
        body.activity_type = "lottery"
        body.prize_count = 3
        body.max_participants = None
        body.draw_trigger = "by_count"
        body.draw_participant_count = 30
        result = _derive_max_participants(body)
        assert result == 30

    def test_max_participants_auto_derived_lottery_by_time(self):
        from app.expert_activity_routes import _derive_max_participants

        body = MagicMock()
        body.activity_type = "lottery"
        body.prize_count = 3
        body.max_participants = None
        body.draw_trigger = "by_time"
        body.draw_participant_count = None
        result = _derive_max_participants(body)
        assert result == 30  # prize_count * 10
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd backend && python -m pytest tests/test_expert_independent_activity.py::TestCreateTeamActivityValidation -v
```

Expected: FAIL — `_validate_lottery_first_come_fields` and `_derive_max_participants` not found

- [ ] **Step 3: Implement validation helpers in `expert_activity_routes.py`**

Add these helper functions before the route handler (after the schema class):

```python
def _validate_lottery_first_come_fields(body: TeamActivityCreate):
    """Validate fields specific to lottery / first_come activity types.

    Raises HTTPException on invalid input.
    Called for ALL activity types — standard just checks expert_service_id.
    """
    if body.activity_type == 'standard':
        if body.expert_service_id is None:
            raise HTTPException(status_code=422, detail={
                "error_code": "service_required_for_standard",
                "message": "Standard activities require expert_service_id",
            })
        return  # standard: no further lottery/first_come checks

    if body.activity_type not in ('lottery', 'first_come'):
        raise HTTPException(status_code=422, detail={
            "error_code": "activity_type_invalid",
            "message": "activity_type must be 'standard', 'lottery', or 'first_come'",
        })

    # Prize fields required for lottery / first_come
    if not body.prize_type:
        raise HTTPException(status_code=422, detail={
            "error_code": "prize_type_required",
            "message": "prize_type is required for lottery/first_come activities",
        })
    if body.prize_type not in ('physical', 'in_person'):
        raise HTTPException(status_code=422, detail={
            "error_code": "prize_type_invalid",
            "message": "Expert activities only support 'physical' or 'in_person' prize types",
        })
    if not body.prize_count or body.prize_count < 1:
        raise HTTPException(status_code=422, detail={
            "error_code": "prize_count_required",
            "message": "prize_count is required and must be > 0",
        })

    # Lottery-specific
    if body.activity_type == 'lottery':
        if body.draw_mode not in ('auto', 'manual'):
            raise HTTPException(status_code=422, detail={
                "error_code": "draw_mode_required",
                "message": "Lottery activities require draw_mode ('auto' or 'manual')",
            })
        if body.draw_mode == 'auto':
            if body.draw_trigger not in ('by_time', 'by_count', 'both'):
                raise HTTPException(status_code=422, detail={
                    "error_code": "draw_trigger_required",
                    "message": "Auto lottery requires draw_trigger ('by_time', 'by_count', or 'both')",
                })
            if body.draw_trigger in ('by_time', 'both') and not body.draw_at:
                raise HTTPException(status_code=422, detail={
                    "error_code": "draw_at_required",
                    "message": "draw_at is required for by_time/both trigger",
                })
            if body.draw_trigger in ('by_count', 'both'):
                if not body.draw_participant_count or body.draw_participant_count <= body.prize_count:
                    raise HTTPException(status_code=422, detail={
                        "error_code": "draw_participant_count_required",
                        "message": "draw_participant_count is required and must be > prize_count",
                    })


def _derive_max_participants(body: TeamActivityCreate) -> int:
    """Auto-derive max_participants based on activity type and draw trigger.

    Rules:
    - first_come: max_participants = prize_count
    - lottery + by_count/both: max_participants = draw_participant_count
    - lottery + by_time/manual: user value or prize_count * 10
    """
    if body.activity_type == 'first_come':
        return body.prize_count

    if body.activity_type == 'lottery':
        if body.draw_trigger in ('by_count', 'both'):
            return body.draw_participant_count
        return body.max_participants or (body.prize_count * 10)

    # standard — use provided value
    return body.max_participants
```

- [ ] **Step 4: Run validation helper tests**

```bash
cd backend && python -m pytest tests/test_expert_independent_activity.py::TestCreateTeamActivityValidation -v
```

Expected: all tests PASS

- [ ] **Step 5: Rewrite `create_team_activity` route handler**

Replace the route handler body (lines 75–231) with branching logic:

```python
@router.post("/{expert_id}/activities")
async def create_team_activity(
    expert_id: str,
    body: TeamActivityCreate,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """Create a team-owned activity.

    Supports three activity types:
    - standard: requires expert_service_id, full service validation
    - lottery: optional service, prize fields required, draw config required
    - first_come: optional service, prize fields required
    """
    # ── Role check ──
    await _get_member_or_403(
        db, expert_id, current_user.id, required_roles=['owner', 'admin']
    )

    expert = await db.get(Expert, expert_id)
    if not expert:
        raise HTTPException(status_code=404, detail="Expert team not found")

    if (body.currency or 'GBP').upper() != 'GBP':
        raise HTTPException(status_code=409, detail={
            "error_code": "expert_currency_unsupported",
            "message": "Team activities only support GBP currently",
        })

    # ── Validate lottery / first_come specific fields ──
    _validate_lottery_first_come_fields(body)

    # ── Derive max_participants ──
    max_participants = _derive_max_participants(body)

    # ── Service validation (required for standard, optional for lottery/first_come) ──
    service = None
    if body.expert_service_id is not None:
        service_result = await db.execute(
            select(TaskExpertService).where(TaskExpertService.id == body.expert_service_id)
        )
        service = service_result.scalar_one_or_none()
        if not service:
            raise HTTPException(status_code=404, detail={
                "error_code": "service_not_found",
                "message": "Service not found",
            })
        if service.owner_type != 'expert' or service.owner_id != expert_id:
            raise HTTPException(status_code=403, detail={
                "error_code": "service_not_owned_by_team",
                "message": "This service does not belong to your team",
            })
        if service.status != 'active':
            raise HTTPException(status_code=400, detail={
                "error_code": "service_inactive",
                "message": "Cannot create activity from inactive service",
            })

    # ── Stripe onboarding check ──
    is_paid = (body.original_price_per_participant or 0) > 0
    needs_stripe = (body.activity_type == 'standard') or is_paid
    if needs_stripe and not expert.stripe_onboarding_complete:
        raise HTTPException(status_code=409, detail={
            "error_code": "expert_stripe_not_ready",
            "message": "Team must complete Stripe onboarding before publishing paid activities",
        })

    # ── Package price validation (standard + package service only) ──
    if service and body.activity_type == 'standard':
        is_package = service.package_type in ("multi", "bundle")
        if is_package:
            pkg_price = float(service.package_price) if service.package_price else None
            if not pkg_price or pkg_price <= 0:
                raise HTTPException(status_code=422, detail={
                    "error_code": "package_price_missing",
                    "message": "套餐服务必须设置 package_price 才能发布活动",
                })
            body.original_price_per_participant = pkg_price
            if body.discounted_price_per_participant is not None:
                if body.discounted_price_per_participant < pkg_price * 0.5:
                    raise HTTPException(status_code=422, detail={
                        "error_code": "discount_too_deep",
                        "message": f"折扣价不能低于套餐原价的 50%（最低 £{pkg_price * 0.5:.2f}）",
                    })
                if body.discounted_price_per_participant >= pkg_price:
                    raise HTTPException(status_code=422, detail={
                        "error_code": "discount_not_lower",
                        "message": "折扣价必须低于套餐原价",
                    })

    # ── Resolve team owner ──
    result = await db.execute(
        select(ExpertMember).where(
            ExpertMember.expert_id == expert.id,
            ExpertMember.role == 'owner',
            ExpertMember.status == 'active',
        ).limit(1)
    )
    owner = result.scalar_one_or_none()
    if not owner:
        raise HTTPException(status_code=500, detail={
            "error_code": "expert_owner_missing",
            "message": "Team has no active owner",
        })

    # ── Build Activity ──
    activity = models.Activity(
        expert_service_id=service.id if service else None,
        title=body.title,
        description=body.description,
        location=body.location,
        task_type=body.task_type,
        reward_type=body.reward_type,
        original_price_per_participant=(
            body.original_price_per_participant
            if body.original_price_per_participant is not None
            else (float(service.base_price) if service else None)
        ),
        discount_percentage=body.discount_percentage,
        discounted_price_per_participant=body.discounted_price_per_participant,
        currency=body.currency,
        points_reward=body.points_reward,
        max_participants=max_participants,
        min_participants=body.min_participants,
        completion_rule=body.completion_rule,
        reward_distribution=body.reward_distribution,
        activity_type=body.activity_type,
        visibility=body.visibility,
        activity_end_date=body.activity_end_date,
        deadline=body.deadline,
        images=body.images if body.images else (service.images if service else None),
        has_time_slots=service.has_time_slots if service else False,
        reward_applicants=body.reward_applicants,
        applicant_reward_amount=body.applicant_reward_amount,
        applicant_points_reward=body.applicant_points_reward,
        expert_id=owner.user_id,
        latitude=body.latitude,
        longitude=body.longitude,
        service_radius_km=body.service_radius_km,
        owner_type='expert',
        owner_id=expert.id,
        status='open',
        is_public=body.is_public,
        # Lottery / first_come fields
        prize_type=body.prize_type,
        prize_description=body.prize_description,
        prize_description_en=body.prize_description_en,
        prize_count=body.prize_count,
        draw_mode=body.draw_mode,
        draw_trigger=body.draw_trigger,
        draw_at=body.draw_at if body.activity_type == 'lottery' else None,
        draw_participant_count=body.draw_participant_count,
    )
    db.add(activity)
    await db.commit()
    await db.refresh(activity)

    return {
        "id": activity.id,
        "owner_type": "expert",
        "owner_id": expert.id,
    }
```

- [ ] **Step 6: Commit**

```bash
git add backend/app/expert_activity_routes.py backend/tests/test_expert_independent_activity.py
git commit -m "feat: support lottery/first_come in create_team_activity with validation"
```

---

### Task 6: Expand auto-draw scan + add by_count trigger in apply endpoint

**Files:**
- Modify: `backend/app/official_draw_task.py:22-30`
- Modify: `backend/app/official_activity_routes.py:44-95`

- [ ] **Step 1: Expand `official_draw_task.py` scan to include `draw_trigger`**

Replace lines 22–30 in `official_draw_task.py`:

```python
def run_auto_draws(db: Session):
    """
    定时检查需要自动开奖的活动（每 60 秒执行一次）。
    Scans ALL lottery activities (official + expert) with auto draw mode.
    Only triggers for by_time/both where draw_at has passed.
    """
    from app.draw_logic import perform_draw_sync

    now = get_utc_time()
    activities = db.execute(
        select(models.Activity).where(
            models.Activity.activity_type == "lottery",
            models.Activity.draw_mode == "auto",
            models.Activity.is_drawn == False,
            models.Activity.status == "open",
            models.Activity.draw_at <= now,
            # Only by_time and both have draw_at set; by_count triggers in apply endpoint
            # NULL draw_trigger means legacy official activities (treat as by_time)
            models.Activity.draw_trigger.in_(["by_time", "both", None]),
        )
    ).scalars().all()

    for activity in activities:
        try:
            perform_draw_sync(db, activity)
            logger.info(f"Auto draw completed for activity {activity.id}")
        except Exception as e:
            logger.error(f"Auto draw failed for activity {activity.id}: {e}")
            db.rollback()
```

- [ ] **Step 2: Add by_count trigger in apply endpoint**

In `official_activity_routes.py`, after the successful apply commit (line 90 `await db.commit()`), add the by_count check:

```python
    db.add(application)
    await db.commit()

    # ── by_count / both trigger: check if threshold reached ──
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
            from app.draw_logic import perform_draw_async
            try:
                await perform_draw_async(db, activity)
            except Exception:
                import logging
                logging.getLogger(__name__).error(
                    f"by_count auto-draw failed for activity {activity_id}", exc_info=True
                )

    return {
        "success": True,
        "status": app_status,
        "message": "报名成功，等待开奖" if app_status == "pending" else "报名成功！",
    }
```

- [ ] **Step 3: Add payment-required check in apply endpoint**

In `official_activity_routes.py`, before creating the application (before the `if activity.activity_type == "first_come":` block at line 71), add:

```python
    # ── Payment check for paid activities ──
    if (activity.original_price_per_participant or 0) > 0:
        return {
            "success": False,
            "requires_payment": True,
            "amount": float(activity.original_price_per_participant),
            "currency": activity.currency or "GBP",
            "message": "此活动需要支付参与费",
        }
```

> Note: This is a simple gate for now. Full payment integration will require a separate task to wire up Stripe payment intent creation and confirmation before apply. For MVP, the endpoint signals `requires_payment: true` and the frontend can handle it.

- [ ] **Step 4: Commit**

```bash
git add backend/app/official_draw_task.py backend/app/official_activity_routes.py
git commit -m "feat: expand auto-draw scan to all lottery activities, add by_count trigger"
```

---

### Task 7: Expert manual draw endpoint

**Files:**
- Modify: `backend/app/expert_activity_routes.py`
- Test: `backend/tests/test_expert_independent_activity.py`

- [ ] **Step 1: Write failing test for manual draw**

Append to `backend/tests/test_expert_independent_activity.py`:

```python
import pytest
from unittest.mock import AsyncMock, MagicMock, patch


class TestExpertManualDraw:
    """Test the expert manual draw endpoint validation."""

    @pytest.mark.asyncio
    async def test_draw_rejects_non_lottery(self):
        """Should reject draw on non-lottery activity."""
        from app.expert_activity_routes import _validate_draw_request

        activity = MagicMock()
        activity.activity_type = "standard"
        activity.is_drawn = False

        with pytest.raises(HTTPException) as exc_info:
            _validate_draw_request(activity)
        assert exc_info.value.status_code == 400

    @pytest.mark.asyncio
    async def test_draw_rejects_already_drawn(self):
        from app.expert_activity_routes import _validate_draw_request

        activity = MagicMock()
        activity.activity_type = "lottery"
        activity.is_drawn = True

        with pytest.raises(HTTPException) as exc_info:
            _validate_draw_request(activity)
        assert exc_info.value.status_code == 400
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd backend && python -m pytest tests/test_expert_independent_activity.py::TestExpertManualDraw -v
```

Expected: FAIL — `_validate_draw_request` not found

- [ ] **Step 3: Add manual draw endpoint and validation to `expert_activity_routes.py`**

Append to the file:

```python
from app.draw_logic import perform_draw_async


def _validate_draw_request(activity: models.Activity):
    """Validate that an activity can be drawn."""
    if activity.activity_type != "lottery":
        raise HTTPException(status_code=400, detail={
            "error_code": "not_lottery",
            "message": "Only lottery activities can be drawn",
        })
    if activity.is_drawn:
        raise HTTPException(status_code=400, detail={
            "error_code": "already_drawn",
            "message": "This activity has already been drawn",
        })


@router.post("/{expert_id}/activities/{activity_id}/draw")
async def expert_manual_draw(
    expert_id: str,
    activity_id: int,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
):
    """Manually trigger lottery draw for an expert team activity."""
    await _get_member_or_403(
        db, expert_id, current_user.id, required_roles=['owner', 'admin']
    )

    result = await db.execute(
        select(models.Activity).where(
            models.Activity.id == activity_id,
            models.Activity.owner_type == 'expert',
            models.Activity.owner_id == expert_id,
        )
    )
    activity = result.scalar_one_or_none()
    if not activity:
        raise HTTPException(status_code=404, detail="Activity not found")

    _validate_draw_request(activity)

    winners = await perform_draw_async(db, activity)
    return {
        "success": True,
        "winner_count": len(winners),
        "winners": winners,
    }
```

- [ ] **Step 4: Run tests**

```bash
cd backend && python -m pytest tests/test_expert_independent_activity.py::TestExpertManualDraw -v
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/expert_activity_routes.py backend/tests/test_expert_independent_activity.py
git commit -m "feat: add expert manual draw endpoint POST /experts/{id}/activities/{id}/draw"
```

---

### Task 8: Register router and verify imports

**Files:**
- Verify: `backend/app/main.py` (expert_activity_routes router already registered)

- [ ] **Step 1: Verify expert_activity_routes router is already registered in main.py**

The router should already be registered from the existing standard activity feature. Verify:

```bash
cd backend && grep -n "expert_activity" app/main.py
```

Expected: a line like `from app.expert_activity_routes import router as expert_activity_router` and `app.include_router(expert_activity_router)`.

If NOT found, add the registration:

```python
from app.expert_activity_routes import router as expert_activity_router
app.include_router(expert_activity_router)
```

- [ ] **Step 2: Verify the app starts without errors**

```bash
cd backend && python -c "from app.main import app; print('App loaded OK')"
```

Expected: `App loaded OK`

- [ ] **Step 3: Run all tests**

```bash
cd backend && python -m pytest tests/test_expert_independent_activity.py -v
```

Expected: all tests PASS

- [ ] **Step 4: Commit (if any changes were needed)**

```bash
git add backend/app/main.py
git commit -m "chore: verify expert activity router registration"
```

---

### Task 9: End-to-end smoke test

- [ ] **Step 1: Run the full test suite to ensure no regressions**

```bash
cd backend && python -m pytest tests/ -v --timeout=30
```

Expected: no new failures

- [ ] **Step 2: Manual smoke test checklist (if running locally)**

1. Create a lottery activity with `draw_trigger=by_time`:
   ```
   POST /api/experts/{expert_id}/activities
   {
     "title": "Test Lottery",
     "description": "Test",
     "location": "London",
     "task_type": "official",
     "deadline": "2026-04-24T00:00:00Z",
     "activity_type": "lottery",
     "prize_type": "physical",
     "prize_count": 2,
     "draw_mode": "auto",
     "draw_trigger": "by_time",
     "draw_at": "2026-04-24T00:00:00Z"
   }
   ```
   Expected: 200, returns `{id, owner_type, owner_id}`

2. Create a first_come activity:
   ```
   POST /api/experts/{expert_id}/activities
   {
     "title": "Test First Come",
     "description": "Test",
     "location": "London",
     "task_type": "official",
     "deadline": "2026-04-24T00:00:00Z",
     "activity_type": "first_come",
     "prize_type": "in_person",
     "prize_count": 5
   }
   ```
   Expected: 200, returns `{id, owner_type, owner_id}`

3. Verify standard activity still requires `expert_service_id`:
   ```
   POST /api/experts/{expert_id}/activities
   {
     "title": "Test Standard",
     "description": "Test",
     "location": "London",
     "task_type": "tutoring",
     "deadline": "2026-04-24T00:00:00Z",
     "activity_type": "standard"
   }
   ```
   Expected: 422, `service_required_for_standard`

- [ ] **Step 3: Commit any test fixes**

```bash
git add -A && git commit -m "test: add end-to-end smoke tests for expert independent activities"
```
