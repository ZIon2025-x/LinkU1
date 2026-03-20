# User Profile System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a four-dimension user profiling system (capability, preference, reliability, demand) with backend models, API endpoints, and Flutter UI.

**Architecture:** Backend-first approach — define SQLAlchemy models and FastAPI routes, then build Flutter models, repository, BLoCs, and views. Each dimension is an independent table. Event-driven reliability updates are hooks into existing task lifecycle. Demand inference is a standalone service with scheduled fallback.

**Tech Stack:** Python/FastAPI/SQLAlchemy (backend), Flutter/Dart/BLoC (frontend), PostgreSQL (database)

**Spec:** `docs/superpowers/specs/2026-03-20-user-profile-system-design.md`

---

## File Structure

### Backend — New Files
| File | Responsibility |
|------|---------------|
| `backend/app/routes/user_profile.py` | FastAPI routes for `/api/profile/*` endpoints |
| `backend/app/services/user_profile_service.py` | Business logic: CRUD, reliability calculation, demand inference |
| `backend/app/services/reliability_calculator.py` | Reliability score computation and event handlers |
| `backend/app/services/demand_inference.py` | Demand prediction engine (rules + behavior stats) |
| `backend/app/services/scheduled_profile_tasks.py` | Celery tasks for nightly demand + weekly reliability |
| `backend/tests/api/test_user_profile_api.py` | API integration tests |

### Backend — Modified Files
| File | Change |
|------|--------|
| `backend/app/models.py:~3451` | Add UserCapability, UserProfilePreference, UserReliability, UserDemand models (append to existing file) |
| `backend/app/main.py:~470` | Register `user_profile_router` |
| `backend/app/routes/user_skills.py` | Add `Deprecation` header to existing endpoints |

### Flutter — New Files
| File | Responsibility |
|------|---------------|
| `link2ur/lib/data/models/user_profile.dart` | Dart models: UserCapability, UserProfilePreference, UserReliability, UserDemand, UserProfileSummary |
| `link2ur/lib/data/repositories/user_profile_repository.dart` | API calls to `/api/profile/*` endpoints |
| `link2ur/lib/features/user_profile/bloc/user_profile_bloc.dart` | BLoC for profile viewing/editing (events + states as `part of`) |
| `link2ur/lib/features/user_profile/views/my_profile_view.dart` | Four-dimension summary page |
| `link2ur/lib/features/user_profile/views/capability_edit_view.dart` | Add/edit/delete skills with proficiency |
| `link2ur/lib/features/user_profile/views/preference_edit_view.dart` | Edit preference settings |
| `link2ur/lib/features/profile_setup/bloc/profile_setup_bloc.dart` | BLoC for onboarding flow (events + states as `part of`) |
| `link2ur/lib/features/profile_setup/views/profile_setup_view.dart` | Post-registration skill + preference selection |
| `link2ur/lib/features/home/widgets/demand_recommendation_card.dart` | Homepage "你可能需要" recommendation cards |
| `link2ur/test/features/user_profile/bloc/user_profile_bloc_test.dart` | BLoC unit tests |

### Flutter — Modified Files
| File | Change |
|------|--------|
| `link2ur/lib/core/constants/api_endpoints.dart:~509` | Add `/api/profile/*` endpoint constants |
| `link2ur/lib/app_providers.dart:~119` | Register UserProfileRepository |
| `link2ur/lib/core/router/app_routes.dart:~121` | Add route constants for profile pages |
| `link2ur/lib/core/router/routes/profile_routes.dart` | Add GoRouter routes for new views |
| `link2ur/lib/l10n/app_en.arb` | Add English localization strings |
| `link2ur/lib/l10n/app_zh.arb` | Add Chinese localization strings |
| `link2ur/lib/l10n/app_zh_Hant.arb` | Add Traditional Chinese localization strings |

---

## Task 1: Backend — Database Models

**Files:**
- Modify: `backend/app/models.py:~3451` (append after SkillLeaderboard model)

**Note:** All models go directly into the existing `models.py` file (not a subdirectory), because Python cannot have both `app/models.py` and `app/models/` simultaneously. The existing `Base` is defined at line ~33 of `models.py`.

- [ ] **Step 1: Append models to models.py**

Add the following at the end of `backend/app/models.py` (after the SkillLeaderboard model at ~line 3451):

```python
# ============================================================
# User Profile models (four-dimension profiling system)
# ============================================================
import enum as _profile_enum


class ProficiencyLevel(str, _profile_enum.Enum):
    beginner = "beginner"
    intermediate = "intermediate"
    expert = "expert"


class VerificationSource(str, _profile_enum.Enum):
    self_declared = "self_declared"
    task_verified = "task_verified"
    platform_verified = "platform_verified"


class TaskMode(str, _profile_enum.Enum):
    online = "online"
    offline = "offline"
    both = "both"


class DurationType(str, _profile_enum.Enum):
    one_time = "one_time"
    long_term = "long_term"
    both = "both"


class RewardPreference(str, _profile_enum.Enum):
    frequent_low = "frequent_low"
    rare_high = "rare_high"
    no_preference = "no_preference"


class UserStage(str, _profile_enum.Enum):
    new_arrival = "new_arrival"
    settling = "settling"
    established = "established"
    experienced = "experienced"


class UserCapability(Base):
    __tablename__ = "user_capabilities"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    category_id = Column(Integer, ForeignKey("skill_categories.id"), nullable=False)
    skill_name = Column(String(100), nullable=False)
    proficiency = Column(Enum(ProficiencyLevel), default=ProficiencyLevel.beginner, nullable=False)
    verification_source = Column(Enum(VerificationSource), default=VerificationSource.self_declared, nullable=False)
    verified_task_count = Column(Integer, default=0)
    last_used_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)

    user = relationship("User", backref="capabilities")
    category = relationship("SkillCategory")

    __table_args__ = (
        UniqueConstraint("user_id", "skill_name", name="uq_user_capability"),
        Index("ix_user_capabilities_user_id", "user_id"),
        Index("ix_user_capabilities_category_id", "category_id"),
    )


class UserProfilePreference(Base):
    __tablename__ = "user_profile_preferences"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    mode = Column(Enum(TaskMode), default=TaskMode.both, nullable=False)
    duration_type = Column(Enum(DurationType), default=DurationType.both, nullable=False)
    reward_preference = Column(Enum(RewardPreference), default=RewardPreference.no_preference, nullable=False)
    preferred_time_slots = Column(JSON, default=list)
    preferred_categories = Column(JSON, default=list)
    preferred_helper_types = Column(JSON, default=list)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)

    user = relationship("User", backref="profile_preference")

    __table_args__ = (
        Index("ix_user_profile_preferences_user_id", "user_id"),
    )


class UserReliability(Base):
    __tablename__ = "user_reliability"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    response_speed_avg = Column(Float, default=0.0)
    completion_rate = Column(Float, default=0.0)
    on_time_rate = Column(Float, default=0.0)
    complaint_rate = Column(Float, default=0.0)
    communication_score = Column(Float, default=0.0)
    repeat_rate = Column(Float, default=0.0)
    cancellation_rate = Column(Float, default=0.0)
    reliability_score = Column(Float, nullable=True)  # null when total_tasks_taken < 3
    total_tasks_taken = Column(Integer, default=0)
    last_calculated_at = Column(DateTime(timezone=True), default=get_utc_time)

    user = relationship("User", backref="reliability")

    __table_args__ = (
        Index("ix_user_reliability_user_id", "user_id"),
        Index("ix_user_reliability_score", "reliability_score"),
    )


class UserDemand(Base):
    __tablename__ = "user_demands"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    user_stage = Column(Enum(UserStage), default=UserStage.new_arrival, nullable=False)
    predicted_needs = Column(JSON, default=list)
    recent_interests = Column(JSON, default=dict)
    last_inferred_at = Column(DateTime(timezone=True), default=get_utc_time)
    inference_version = Column(String(20), default="v1.0")

    user = relationship("User", backref="demand")

    __table_args__ = (
        Index("ix_user_demands_user_id", "user_id"),
        Index("ix_user_demands_user_stage", "user_stage"),
    )
```

**Note:** `get_utc_time` is already imported at the top of `models.py` from `app.utils.time_utils`. `Base`, `Column`, `Integer`, `String`, `Float`, `Enum`, `DateTime`, `JSON`, `ForeignKey`, `UniqueConstraint`, `Index`, `relationship` are all already imported. The `_profile_enum` import alias avoids shadowing the existing `enum` imports.

- [ ] **Step 2: Verify models load without errors**

```bash
cd backend && python -c "from app.models import UserCapability, UserProfilePreference, UserReliability, UserDemand; print('Models loaded OK')"
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/models.py
git commit -m "feat(backend): add four-dimension user profile database models

Add UserCapability, UserProfilePreference, UserReliability, UserDemand
SQLAlchemy models with enums, indexes, and constraints."
```

---

## Task 2: Backend — UserProfileService (CRUD + Reliability Calculator)

**Files:**
- Create: `backend/app/services/user_profile_service.py`
- Create: `backend/app/services/reliability_calculator.py`

- [ ] **Step 1: Write reliability calculator**

Create `backend/app/services/reliability_calculator.py`:

```python
"""Reliability score calculator with event-driven incremental updates."""
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models import UserReliability

MINIMUM_TASKS_THRESHOLD = 3


def calculate_reliability_score(reliability: UserReliability) -> float | None:
    """Calculate composite reliability score (0-100). Returns None if insufficient data."""
    if reliability.total_tasks_taken < MINIMUM_TASKS_THRESHOLD:
        return None
    return (
        reliability.completion_rate * 30 +
        reliability.on_time_rate * 25 +
        (1 - reliability.cancellation_rate) * 20 +
        (reliability.communication_score / 5.0) * 15 +
        (1 - reliability.complaint_rate) * 10
    )


def get_or_create_reliability(db: Session, user_id: str) -> UserReliability:
    """Get existing reliability record or create a new one."""
    reliability = db.query(UserReliability).filter(
        UserReliability.user_id == user_id
    ).first()
    if not reliability:
        reliability = UserReliability(user_id=user_id)
        db.add(reliability)
        db.flush()
    return reliability


def on_task_completed(db: Session, user_id: str, was_on_time: bool):
    """Update reliability when a task is completed."""
    reliability = get_or_create_reliability(db, user_id)
    reliability.total_tasks_taken += 1

    # Incremental completion rate: (old_rate * old_count + 1) / new_count
    old_count = reliability.total_tasks_taken - 1
    reliability.completion_rate = (
        (reliability.completion_rate * old_count + 1.0) / reliability.total_tasks_taken
    )

    # Incremental on-time rate
    on_time_val = 1.0 if was_on_time else 0.0
    reliability.on_time_rate = (
        (reliability.on_time_rate * old_count + on_time_val) / reliability.total_tasks_taken
    )

    reliability.reliability_score = calculate_reliability_score(reliability)
    reliability.last_calculated_at = datetime.now(timezone.utc)


def on_task_cancelled(db: Session, user_id: str):
    """Update reliability when a task is cancelled by the taker."""
    reliability = get_or_create_reliability(db, user_id)
    reliability.total_tasks_taken += 1

    old_count = reliability.total_tasks_taken - 1
    # Completion rate decreases (cancelled = not completed)
    reliability.completion_rate = (
        (reliability.completion_rate * old_count) / reliability.total_tasks_taken
    )
    # Cancellation rate increases
    reliability.cancellation_rate = (
        (reliability.cancellation_rate * old_count + 1.0) / reliability.total_tasks_taken
    )

    reliability.reliability_score = calculate_reliability_score(reliability)
    reliability.last_calculated_at = datetime.now(timezone.utc)


def on_review_created(db: Session, user_id: str, communication_rating: float):
    """Update communication score when a review is received."""
    reliability = get_or_create_reliability(db, user_id)
    # Weighted average: give more weight to recent reviews
    if reliability.communication_score == 0.0:
        reliability.communication_score = communication_rating
    else:
        # Exponential moving average (alpha=0.3 for recent weight)
        reliability.communication_score = (
            0.7 * reliability.communication_score + 0.3 * communication_rating
        )

    reliability.reliability_score = calculate_reliability_score(reliability)
    reliability.last_calculated_at = datetime.now(timezone.utc)


def on_complaint_created(db: Session, user_id: str):
    """Update complaint rate when a complaint is filed."""
    reliability = get_or_create_reliability(db, user_id)
    if reliability.total_tasks_taken > 0:
        # Approximate: increment complaint count / total tasks
        current_complaints = reliability.complaint_rate * reliability.total_tasks_taken
        reliability.complaint_rate = (current_complaints + 1) / reliability.total_tasks_taken

    reliability.reliability_score = calculate_reliability_score(reliability)
    reliability.last_calculated_at = datetime.now(timezone.utc)


def on_application_responded(db: Session, user_id: str, response_seconds: float):
    """Update average response speed when a helper responds to an application."""
    reliability = get_or_create_reliability(db, user_id)
    if reliability.response_speed_avg == 0.0:
        reliability.response_speed_avg = response_seconds
    else:
        reliability.response_speed_avg = (
            0.7 * reliability.response_speed_avg + 0.3 * response_seconds
        )
    reliability.last_calculated_at = datetime.now(timezone.utc)


def on_task_assigned(db: Session, helper_user_id: str, poster_user_id: str):
    """Update repeat_rate when a task is assigned. Checks if poster previously selected this helper."""
    from app.models import Task
    reliability = get_or_create_reliability(db, helper_user_id)

    # Count how many times this poster has selected this helper
    times_selected = db.query(func.count(Task.id)).filter(
        Task.poster_id == poster_user_id,
        Task.taker_id == helper_user_id,
        Task.status.in_(["completed", "confirmed", "in_progress"])
    ).scalar() or 0

    if times_selected > 1:
        # This is a repeat selection
        total_assignments = db.query(func.count(Task.id)).filter(
            Task.taker_id == helper_user_id,
            Task.status.in_(["completed", "confirmed", "in_progress"])
        ).scalar() or 1
        # repeat_rate = assignments from repeat posters / total assignments
        repeat_assignments = db.query(func.count(Task.id)).filter(
            Task.taker_id == helper_user_id,
            Task.poster_id.in_(
                db.query(Task.poster_id).filter(
                    Task.taker_id == helper_user_id
                ).group_by(Task.poster_id).having(func.count(Task.id) > 1)
            )
        ).scalar() or 0
        reliability.repeat_rate = repeat_assignments / total_assignments

    reliability.last_calculated_at = datetime.now(timezone.utc)


def recalculate_all_reliability(db: Session, limit: int = 500):
    """Weekly full recalculation to fix incremental drift."""
    from app.models import Task, User
    users = db.query(User).filter(User.task_count > 0).limit(limit).all()
    for user in users:
        reliability = get_or_create_reliability(db, user.id)
        # Full recalculation from task history
        taken_tasks = db.query(Task).filter(Task.taker_id == user.id).all()
        total = len(taken_tasks)
        if total == 0:
            continue
        completed = sum(1 for t in taken_tasks if t.status in ("completed", "confirmed"))
        cancelled = sum(1 for t in taken_tasks if t.status == "cancelled" and t.taker_id == user.id)
        on_time = sum(1 for t in taken_tasks if t.status in ("completed", "confirmed")
                      and t.deadline and t.completed_at and t.completed_at <= t.deadline)

        reliability.total_tasks_taken = total
        reliability.completion_rate = completed / total
        reliability.cancellation_rate = cancelled / total
        reliability.on_time_rate = on_time / max(completed, 1)
        reliability.reliability_score = calculate_reliability_score(reliability)
        reliability.last_calculated_at = datetime.now(timezone.utc)
```

- [ ] **Step 3: Write UserProfileService**

Create `backend/app/services/user_profile_service.py`:

```python
"""User profile service: CRUD for all four dimensions."""
from datetime import datetime, timezone
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import func
from app.models import (
    UserCapability, UserProfilePreference, UserReliability, UserDemand,
    ProficiencyLevel, VerificationSource, TaskMode, DurationType,
    RewardPreference, UserStage
)


# --- Capability ---

def get_capabilities(db: Session, user_id: str) -> list[UserCapability]:
    return db.query(UserCapability).filter(
        UserCapability.user_id == user_id
    ).options(joinedload(UserCapability.category)).all()


def upsert_capabilities(db: Session, user_id: str, capabilities: list[dict]) -> list[UserCapability]:
    """Batch upsert capabilities. Each dict: {category_id, skill_name, proficiency?}"""
    results = []
    for cap_data in capabilities:
        existing = db.query(UserCapability).filter(
            UserCapability.user_id == user_id,
            UserCapability.skill_name == cap_data["skill_name"]
        ).first()

        if existing:
            existing.category_id = cap_data["category_id"]
            if "proficiency" in cap_data:
                existing.proficiency = cap_data["proficiency"]
            results.append(existing)
        else:
            cap = UserCapability(
                user_id=user_id,
                category_id=cap_data["category_id"],
                skill_name=cap_data["skill_name"],
                proficiency=cap_data.get("proficiency", ProficiencyLevel.beginner),
                verification_source=VerificationSource.self_declared,
            )
            db.add(cap)
            results.append(cap)
    db.flush()
    return results


def delete_capability(db: Session, user_id: str, capability_id: int) -> bool:
    cap = db.query(UserCapability).filter(
        UserCapability.id == capability_id,
        UserCapability.user_id == user_id
    ).first()
    if not cap:
        return False
    db.delete(cap)
    return True


# --- Preference ---

def get_preference(db: Session, user_id: str) -> UserProfilePreference | None:
    return db.query(UserProfilePreference).filter(
        UserProfilePreference.user_id == user_id
    ).first()


def upsert_preference(db: Session, user_id: str, data: dict) -> UserProfilePreference:
    """Create or update preference. data keys match model field names."""
    pref = get_preference(db, user_id)
    if not pref:
        pref = UserProfilePreference(user_id=user_id)
        db.add(pref)

    for key in ["mode", "duration_type", "reward_preference",
                "preferred_time_slots", "preferred_categories", "preferred_helper_types"]:
        if key in data:
            setattr(pref, key, data[key])
    db.flush()
    return pref


# --- Reliability ---

def get_reliability(db: Session, user_id: str) -> UserReliability | None:
    return db.query(UserReliability).filter(
        UserReliability.user_id == user_id
    ).first()


# --- Demand ---

def get_demand(db: Session, user_id: str) -> UserDemand | None:
    return db.query(UserDemand).filter(
        UserDemand.user_id == user_id
    ).first()


# --- Summary ---

def get_profile_summary(db: Session, user_id: str) -> dict:
    """Get all four dimensions in one call."""
    return {
        "capabilities": get_capabilities(db, user_id),
        "preference": get_preference(db, user_id),
        "reliability": get_reliability(db, user_id),
        "demand": get_demand(db, user_id),
    }


# --- Onboarding ---

def submit_onboarding(db: Session, user_id: str, data: dict) -> dict:
    """Handle onboarding submission: batch set capabilities + preference.
    data: {capabilities: [{category_id, skill_name}], mode: str, preferred_categories: [int]}
    """
    caps = []
    if "capabilities" in data:
        caps = upsert_capabilities(db, user_id, data["capabilities"])

    pref_data = {}
    if "mode" in data:
        pref_data["mode"] = data["mode"]
    if "preferred_categories" in data:
        pref_data["preferred_categories"] = data["preferred_categories"]
    pref = upsert_preference(db, user_id, pref_data) if pref_data else get_preference(db, user_id)

    return {"capabilities": caps, "preference": pref}
```

- [ ] **Step 4: Verify services load**

```bash
cd backend && python -c "from app.services.user_profile_service import get_profile_summary; from app.services.reliability_calculator import calculate_reliability_score; print('Services loaded OK')"
```

**Note:** The `services/` directory already exists at `backend/app/services/`. Do NOT overwrite its `__init__.py`.
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/
git commit -m "feat(backend): add user profile service and reliability calculator

UserProfileService handles CRUD for all four profile dimensions.
ReliabilityCalculator provides event-driven incremental score updates."
```

---

## Task 3: Backend — Demand Inference Engine

**Files:**
- Create: `backend/app/services/demand_inference.py`

- [ ] **Step 1: Write demand inference engine**

Create `backend/app/services/demand_inference.py`:

```python
"""Demand inference engine: predicts user needs based on stage and behavior."""
from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models import UserDemand, UserStage
from app.models import User, UserTaskInteraction

INFERENCE_VERSION = "v1.0"

# Category-to-items mapping for predictions
STAGE_PREDICTIONS = {
    UserStage.new_arrival: [
        {"category": "settling", "confidence": 0.85, "items": ["接机", "搬家", "银行开户", "电话卡办理"], "reason": "new_arrival_pattern"},
        {"category": "orientation", "confidence": 0.7, "items": ["校园导览", "超市指引", "交通卡办理"], "reason": "new_arrival_pattern"},
    ],
    UserStage.settling: [
        {"category": "housing", "confidence": 0.7, "items": ["租房看房", "搬家", "家具组装"], "reason": "settling_pattern"},
        {"category": "daily_life", "confidence": 0.6, "items": ["代买代取", "取快递", "陪同办事"], "reason": "settling_pattern"},
    ],
    UserStage.established: [
        {"category": "daily_life", "confidence": 0.5, "items": ["代买代取", "取快递"], "reason": "general_needs"},
    ],
    UserStage.experienced: [],
}


def determine_user_stage(db: Session, user: User) -> UserStage:
    """Determine user's current stage based on registration time and activity."""
    now = datetime.now(timezone.utc)
    days_since_registration = (now - user.created_at).days if user.created_at else 0

    if days_since_registration <= 7:
        return UserStage.new_arrival
    elif days_since_registration <= 30:
        return UserStage.settling
    elif user.completed_task_count and user.completed_task_count > 10 and days_since_registration > 90:
        return UserStage.experienced
    elif days_since_registration > 30:
        return UserStage.established
    return UserStage.new_arrival


def analyze_recent_interests(db: Session, user_id: str) -> dict:
    """Analyze user's browsing/interaction patterns in the last 7 days."""
    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)

    interactions = db.query(
        UserTaskInteraction.interaction_type,
        func.count(UserTaskInteraction.id).label("count")
    ).filter(
        UserTaskInteraction.user_id == user_id,
        UserTaskInteraction.interaction_time >= seven_days_ago
    ).group_by(UserTaskInteraction.interaction_type).all()

    return {row.interaction_type: row.count for row in interactions}


def infer_demand(db: Session, user_id: str) -> UserDemand:
    """Run demand inference for a user. Creates or updates UserDemand record."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise ValueError(f"User {user_id} not found")

    stage = determine_user_stage(db, user)
    recent_interests = analyze_recent_interests(db, user_id)
    predicted_needs = list(STAGE_PREDICTIONS.get(stage, []))

    # Get or create demand record
    demand = db.query(UserDemand).filter(UserDemand.user_id == user_id).first()
    if not demand:
        demand = UserDemand(user_id=user_id)
        db.add(demand)

    demand.user_stage = stage
    demand.predicted_needs = predicted_needs
    demand.recent_interests = recent_interests
    demand.last_inferred_at = datetime.now(timezone.utc)
    demand.inference_version = INFERENCE_VERSION

    db.flush()
    return demand


def batch_infer_demands(db: Session, limit: int = 500):
    """Nightly batch: infer demands for all active users (7-day activity window)."""
    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)

    # Find active users by recent interactions
    active_user_ids = db.query(
        UserTaskInteraction.user_id.distinct()
    ).filter(
        UserTaskInteraction.interaction_time >= seven_days_ago
    ).limit(limit).all()

    results = []
    for (user_id,) in active_user_ids:
        try:
            demand = infer_demand(db, user_id)
            results.append(demand)
        except Exception:
            continue

    return results
```

- [ ] **Step 2: Verify import**

```bash
cd backend && python -c "from app.services.demand_inference import infer_demand, batch_infer_demands; print('Demand inference loaded OK')"
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/services/demand_inference.py
git commit -m "feat(backend): add demand inference engine

Rule-based demand prediction using user stage and interaction history.
Supports both single-user inference and nightly batch updates."
```

---

## Task 3.5: Backend — Scheduled Tasks (Celery)

**Files:**
- Create: `backend/app/services/scheduled_profile_tasks.py`

- [ ] **Step 1: Write scheduled tasks**

Create `backend/app/services/scheduled_profile_tasks.py`:

```python
"""Scheduled tasks for user profile system.

Wire these into the existing Celery beat schedule or cron:
- nightly_demand_inference: every day at 3:00 AM UTC
- weekly_reliability_calibration: every Monday at 4:00 AM UTC
"""
import logging
from app.database import SessionLocal
from app.services.demand_inference import batch_infer_demands
from app.services.reliability_calculator import recalculate_all_reliability

logger = logging.getLogger(__name__)


def nightly_demand_inference():
    """Run nightly at 3 AM: update demand profiles for active users."""
    db = SessionLocal()
    try:
        results = batch_infer_demands(db, limit=500)
        db.commit()
        logger.info(f"Nightly demand inference: updated {len(results)} users")
    except Exception as e:
        db.rollback()
        logger.error(f"Nightly demand inference failed: {e}")
    finally:
        db.close()


def weekly_reliability_calibration():
    """Run weekly on Monday at 4 AM: full recalculation of reliability scores."""
    db = SessionLocal()
    try:
        recalculate_all_reliability(db, limit=500)
        db.commit()
        logger.info("Weekly reliability calibration completed")
    except Exception as e:
        db.rollback()
        logger.error(f"Weekly reliability calibration failed: {e}")
    finally:
        db.close()
```

- [ ] **Step 2: Register in existing Celery beat or scheduler**

Check how the project registers scheduled tasks (look for Celery config or APScheduler in `backend/app/main.py` or `backend/app/celery_app.py`). Add the two tasks to the existing schedule configuration.

- [ ] **Step 3: Commit**

```bash
git add backend/app/services/scheduled_profile_tasks.py
git commit -m "feat(backend): add scheduled tasks for profile system

Nightly demand inference (3 AM) and weekly reliability calibration (Monday 4 AM)."
```

---

## Task 4: Backend — API Routes

**Files:**
- Create: `backend/app/routes/user_profile.py`
- Modify: `backend/app/main.py:~470`
- Modify: `backend/app/routes/user_skills.py`

- [ ] **Step 1: Write API routes**

Create `backend/app/routes/user_profile.py`:

```python
"""User profile API routes for four-dimension profiling system."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.deps import get_db, get_current_user_secure_sync_csrf
from app.services import user_profile_service as svc
from app.services.demand_inference import infer_demand

router = APIRouter(prefix="/api/profile", tags=["用户画像"])


# --- Schemas ---

class CapabilityItem(BaseModel):
    category_id: int
    skill_name: str
    proficiency: str = "beginner"

class CapabilityResponse(BaseModel):
    id: int
    category_id: int
    skill_name: str
    proficiency: str
    verification_source: str
    verified_task_count: int

    class Config:
        from_attributes = True

class PreferenceUpdate(BaseModel):
    mode: str | None = None
    duration_type: str | None = None
    reward_preference: str | None = None
    preferred_time_slots: list[str] | None = None
    preferred_categories: list[int] | None = None
    preferred_helper_types: list[str] | None = None

class OnboardingSubmit(BaseModel):
    capabilities: list[CapabilityItem] = []
    mode: str | None = None
    preferred_categories: list[int] = []


# --- Capability endpoints ---

@router.get("/capabilities")
async def get_capabilities(current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)):
    caps = svc.get_capabilities(db, current_user.id)
    return [{
        "id": c.id,
        "category_id": c.category_id,
        "category_name_zh": c.category.name_zh if c.category else None,
        "category_name_en": c.category.name_en if c.category else None,
        "skill_name": c.skill_name,
        "proficiency": c.proficiency.value,
        "verification_source": c.verification_source.value,
        "verified_task_count": c.verified_task_count,
    } for c in caps]


@router.put("/capabilities")
async def update_capabilities(
    items: list[CapabilityItem],
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    caps = svc.upsert_capabilities(db, current_user.id, [item.model_dump() for item in items])
    db.commit()
    return {"message": "ok", "count": len(caps)}


@router.delete("/capabilities/{capability_id}")
async def delete_capability(
    capability_id: int,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    if not svc.delete_capability(db, current_user.id, capability_id):
        raise HTTPException(status_code=404, detail="Capability not found")
    db.commit()
    return {"message": "ok"}


# --- Preference endpoints ---

@router.get("/preferences")
async def get_preferences(current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)):
    pref = svc.get_preference(db, current_user.id)
    if not pref:
        return {"mode": "both", "duration_type": "both", "reward_preference": "no_preference",
                "preferred_time_slots": [], "preferred_categories": [], "preferred_helper_types": []}
    return {
        "mode": pref.mode.value,
        "duration_type": pref.duration_type.value,
        "reward_preference": pref.reward_preference.value,
        "preferred_time_slots": pref.preferred_time_slots or [],
        "preferred_categories": pref.preferred_categories or [],
        "preferred_helper_types": pref.preferred_helper_types or [],
    }


@router.put("/preferences")
async def update_preferences(
    data: PreferenceUpdate,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    pref = svc.upsert_preference(db, current_user.id, data.model_dump(exclude_none=True))
    db.commit()
    return {"message": "ok"}


# --- Read-only endpoints ---

@router.get("/reliability")
async def get_reliability(current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)):
    rel = svc.get_reliability(db, current_user.id)
    if not rel:
        return {"reliability_score": None, "total_tasks_taken": 0, "insufficient_data": True}
    return {
        "response_speed_avg": rel.response_speed_avg,
        "completion_rate": rel.completion_rate,
        "on_time_rate": rel.on_time_rate,
        "complaint_rate": rel.complaint_rate,
        "communication_score": rel.communication_score,
        "repeat_rate": rel.repeat_rate,
        "cancellation_rate": rel.cancellation_rate,
        "reliability_score": rel.reliability_score,
        "total_tasks_taken": rel.total_tasks_taken,
        "insufficient_data": rel.total_tasks_taken < 3,
    }


@router.get("/demand")
async def get_demand(current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)):
    demand = svc.get_demand(db, current_user.id)
    if not demand:
        # Trigger first inference
        demand = infer_demand(db, current_user.id)
        db.commit()
    return {
        "user_stage": demand.user_stage.value,
        "predicted_needs": demand.predicted_needs or [],
        "recent_interests": demand.recent_interests or {},
        "last_inferred_at": demand.last_inferred_at.isoformat() if demand.last_inferred_at else None,
    }


@router.get("/summary")
async def get_summary(current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)):
    summary = svc.get_profile_summary(db, current_user.id)
    caps = [{
        "id": c.id, "category_id": c.category_id, "skill_name": c.skill_name,
        "proficiency": c.proficiency.value, "verification_source": c.verification_source.value,
    } for c in summary["capabilities"]]

    pref = summary["preference"]
    pref_data = {"mode": "both", "duration_type": "both", "reward_preference": "no_preference",
                 "preferred_time_slots": [], "preferred_categories": [], "preferred_helper_types": []} if not pref else {
        "mode": pref.mode.value, "duration_type": pref.duration_type.value,
        "reward_preference": pref.reward_preference.value,
        "preferred_time_slots": pref.preferred_time_slots or [],
        "preferred_categories": pref.preferred_categories or [],
        "preferred_helper_types": pref.preferred_helper_types or [],
    }

    rel = summary["reliability"]
    rel_data = {"reliability_score": None, "insufficient_data": True} if not rel else {
        "reliability_score": rel.reliability_score,
        "total_tasks_taken": rel.total_tasks_taken,
        "insufficient_data": rel.total_tasks_taken < 3,
    }

    demand = summary["demand"]
    demand_data = {"user_stage": "new_arrival", "predicted_needs": []} if not demand else {
        "user_stage": demand.user_stage.value,
        "predicted_needs": demand.predicted_needs or [],
    }

    return {
        "capabilities": caps,
        "preference": pref_data,
        "reliability": rel_data,
        "demand": demand_data,
    }


# --- Onboarding ---

@router.post("/onboarding")
async def submit_onboarding(
    data: OnboardingSubmit,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    result = svc.submit_onboarding(db, current_user.id, data.model_dump())
    # Trigger initial demand inference
    infer_demand(db, current_user.id)
    db.commit()
    return {"message": "ok"}
```

- [ ] **Step 2: Register routes in main.py**

Add after the existing user_skills_router registration (~line 471 in `backend/app/main.py`):

```python
from app.routes.user_profile import router as user_profile_router
app.include_router(user_profile_router)
```

- [ ] **Step 3: Add deprecation header to old skill endpoints**

In `backend/app/routes/user_skills.py`, add to each endpoint function:

```python
from fastapi import Response

# Add to each endpoint's parameters: response: Response
# Add to each endpoint's body:
response.headers["Deprecation"] = "true"
response.headers["Sunset"] = "2026-04-20"
response.headers["Link"] = '</api/profile/capabilities>; rel="successor-version"'
```

- [ ] **Step 4: Test routes manually**

```bash
cd backend && python -c "from app.routes.user_profile import router; print(f'Routes: {len(router.routes)}'); [print(f'  {r.methods} {r.path}') for r in router.routes]"
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/routes/user_profile.py backend/app/main.py backend/app/routes/user_skills.py
git commit -m "feat(backend): add user profile API routes

9 endpoints under /api/profile/* for capabilities, preferences,
reliability, demand, summary, and onboarding.
Add deprecation headers to old /api/skills/* endpoints."
```

---

## Task 5: Backend — API Tests

**Files:**
- Create: `backend/tests/api/test_user_profile_api.py`

- [ ] **Step 1: Write API integration tests**

Create `backend/tests/api/test_user_profile_api.py`:

```python
"""Tests for user profile API endpoints."""
import pytest
from httpx import Client

TEST_API_URL = "http://localhost:8000"
REQUEST_TIMEOUT = 10


@pytest.fixture(scope="class")
def auth_client(request):
    """Authenticated client fixture — reuses conftest pattern."""
    from tests.api.conftest import auth_client as _auth_client
    return _auth_client(request)


@pytest.mark.api
class TestUserProfileCapabilities:
    def test_get_capabilities_empty(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/capabilities")
        assert r.status_code == 200
        assert isinstance(r.json(), list)

    def test_put_capabilities_batch(self, auth_client):
        r = auth_client.put(f"{TEST_API_URL}/api/profile/capabilities", json=[
            {"category_id": 1, "skill_name": "英语沟通", "proficiency": "intermediate"},
            {"category_id": 1, "skill_name": "中文翻译", "proficiency": "expert"},
        ])
        assert r.status_code == 200
        assert r.json()["count"] == 2

    def test_get_capabilities_after_add(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/capabilities")
        assert r.status_code == 200
        caps = r.json()
        assert len(caps) >= 2
        names = [c["skill_name"] for c in caps]
        assert "英语沟通" in names

    def test_delete_capability(self, auth_client):
        # Get first, then delete
        r = auth_client.get(f"{TEST_API_URL}/api/profile/capabilities")
        caps = r.json()
        if caps:
            cap_id = caps[0]["id"]
            r = auth_client.delete(f"{TEST_API_URL}/api/profile/capabilities/{cap_id}")
            assert r.status_code == 200

    def test_delete_nonexistent_capability(self, auth_client):
        r = auth_client.delete(f"{TEST_API_URL}/api/profile/capabilities/99999")
        assert r.status_code == 404


@pytest.mark.api
class TestUserProfilePreferences:
    def test_get_preferences_default(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/preferences")
        assert r.status_code == 200
        data = r.json()
        assert "mode" in data

    def test_put_preferences(self, auth_client):
        r = auth_client.put(f"{TEST_API_URL}/api/profile/preferences", json={
            "mode": "online",
            "preferred_categories": [1, 2],
            "preferred_time_slots": ["weekday_evening", "weekend"],
        })
        assert r.status_code == 200

    def test_get_preferences_after_update(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/preferences")
        assert r.status_code == 200
        data = r.json()
        assert data["mode"] == "online"
        assert 1 in data["preferred_categories"]


@pytest.mark.api
class TestUserProfileReadOnly:
    def test_get_reliability(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/reliability")
        assert r.status_code == 200
        data = r.json()
        assert "reliability_score" in data
        assert "insufficient_data" in data

    def test_get_demand(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/demand")
        assert r.status_code == 200
        data = r.json()
        assert "user_stage" in data
        assert "predicted_needs" in data

    def test_get_summary(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/summary")
        assert r.status_code == 200
        data = r.json()
        assert "capabilities" in data
        assert "preference" in data
        assert "reliability" in data
        assert "demand" in data


@pytest.mark.api
class TestOnboarding:
    def test_submit_onboarding(self, auth_client):
        r = auth_client.post(f"{TEST_API_URL}/api/profile/onboarding", json={
            "capabilities": [
                {"category_id": 1, "skill_name": "英语沟通"},
                {"category_id": 3, "skill_name": "搬家"},
            ],
            "mode": "offline",
            "preferred_categories": [1, 3],
        })
        assert r.status_code == 200

    def test_onboarding_creates_demand(self, auth_client):
        r = auth_client.get(f"{TEST_API_URL}/api/profile/demand")
        assert r.status_code == 200
        data = r.json()
        assert data["user_stage"] is not None
```

- [ ] **Step 2: Commit**

```bash
git add backend/tests/api/test_user_profile_api.py
git commit -m "test(backend): add user profile API integration tests

17 tests covering capabilities CRUD, preferences, reliability,
demand, summary, and onboarding endpoints."
```

---

## Task 6: Flutter — Data Models

**Files:**
- Create: `link2ur/lib/data/models/user_profile.dart`

- [ ] **Step 1: Write Dart models**

Create `link2ur/lib/data/models/user_profile.dart`:

```dart
import 'package:equatable/equatable.dart';

/// 能力画像
class UserCapability extends Equatable {
  final int id;
  final int categoryId;
  final String? categoryNameZh;
  final String? categoryNameEn;
  final String skillName;
  final String proficiency; // beginner, intermediate, expert
  final String verificationSource; // self_declared, task_verified, platform_verified
  final int verifiedTaskCount;

  const UserCapability({
    required this.id,
    required this.categoryId,
    this.categoryNameZh,
    this.categoryNameEn,
    required this.skillName,
    required this.proficiency,
    required this.verificationSource,
    this.verifiedTaskCount = 0,
  });

  factory UserCapability.fromJson(Map<String, dynamic> json) {
    return UserCapability(
      id: json['id'] as int,
      categoryId: json['category_id'] as int,
      categoryNameZh: json['category_name_zh'] as String?,
      categoryNameEn: json['category_name_en'] as String?,
      skillName: json['skill_name'] as String,
      proficiency: json['proficiency'] as String? ?? 'beginner',
      verificationSource: json['verification_source'] as String? ?? 'self_declared',
      verifiedTaskCount: json['verified_task_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'category_id': categoryId,
    'skill_name': skillName,
    'proficiency': proficiency,
  };

  String displayCategoryName(String locale) {
    if (locale.startsWith('en')) return categoryNameEn ?? categoryNameZh ?? '';
    return categoryNameZh ?? categoryNameEn ?? '';
  }

  @override
  List<Object?> get props => [id, categoryId, skillName, proficiency, verificationSource, verifiedTaskCount];
}

/// 偏好画像
class UserProfilePreference extends Equatable {
  final String mode; // online, offline, both
  final String durationType; // one_time, long_term, both
  final String rewardPreference; // frequent_low, rare_high, no_preference
  final List<String> preferredTimeSlots;
  final List<int> preferredCategories;
  final List<String> preferredHelperTypes;

  const UserProfilePreference({
    this.mode = 'both',
    this.durationType = 'both',
    this.rewardPreference = 'no_preference',
    this.preferredTimeSlots = const [],
    this.preferredCategories = const [],
    this.preferredHelperTypes = const [],
  });

  factory UserProfilePreference.fromJson(Map<String, dynamic> json) {
    return UserProfilePreference(
      mode: json['mode'] as String? ?? 'both',
      durationType: json['duration_type'] as String? ?? 'both',
      rewardPreference: json['reward_preference'] as String? ?? 'no_preference',
      preferredTimeSlots: (json['preferred_time_slots'] as List?)?.cast<String>() ?? [],
      preferredCategories: (json['preferred_categories'] as List?)?.cast<int>() ?? [],
      preferredHelperTypes: (json['preferred_helper_types'] as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'duration_type': durationType,
    'reward_preference': rewardPreference,
    'preferred_time_slots': preferredTimeSlots,
    'preferred_categories': preferredCategories,
    'preferred_helper_types': preferredHelperTypes,
  };

  UserProfilePreference copyWith({
    String? mode,
    String? durationType,
    String? rewardPreference,
    List<String>? preferredTimeSlots,
    List<int>? preferredCategories,
    List<String>? preferredHelperTypes,
  }) {
    return UserProfilePreference(
      mode: mode ?? this.mode,
      durationType: durationType ?? this.durationType,
      rewardPreference: rewardPreference ?? this.rewardPreference,
      preferredTimeSlots: preferredTimeSlots ?? this.preferredTimeSlots,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      preferredHelperTypes: preferredHelperTypes ?? this.preferredHelperTypes,
    );
  }

  @override
  List<Object?> get props => [mode, durationType, rewardPreference, preferredTimeSlots, preferredCategories, preferredHelperTypes];
}

/// 可靠度画像
class UserReliability extends Equatable {
  final double responseSpeedAvg;
  final double completionRate;
  final double onTimeRate;
  final double complaintRate;
  final double communicationScore;
  final double repeatRate;
  final double cancellationRate;
  final double? reliabilityScore; // null when insufficient data
  final int totalTasksTaken;
  final bool insufficientData;

  const UserReliability({
    this.responseSpeedAvg = 0,
    this.completionRate = 0,
    this.onTimeRate = 0,
    this.complaintRate = 0,
    this.communicationScore = 0,
    this.repeatRate = 0,
    this.cancellationRate = 0,
    this.reliabilityScore,
    this.totalTasksTaken = 0,
    this.insufficientData = true,
  });

  factory UserReliability.fromJson(Map<String, dynamic> json) {
    return UserReliability(
      responseSpeedAvg: (json['response_speed_avg'] as num?)?.toDouble() ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0,
      onTimeRate: (json['on_time_rate'] as num?)?.toDouble() ?? 0,
      complaintRate: (json['complaint_rate'] as num?)?.toDouble() ?? 0,
      communicationScore: (json['communication_score'] as num?)?.toDouble() ?? 0,
      repeatRate: (json['repeat_rate'] as num?)?.toDouble() ?? 0,
      cancellationRate: (json['cancellation_rate'] as num?)?.toDouble() ?? 0,
      reliabilityScore: (json['reliability_score'] as num?)?.toDouble(),
      totalTasksTaken: json['total_tasks_taken'] as int? ?? 0,
      insufficientData: json['insufficient_data'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [responseSpeedAvg, completionRate, onTimeRate, complaintRate,
    communicationScore, repeatRate, cancellationRate, reliabilityScore, totalTasksTaken];
}

/// 需求画像
class UserDemand extends Equatable {
  final String userStage; // new_arrival, settling, established, experienced
  final List<PredictedNeed> predictedNeeds;
  final Map<String, dynamic> recentInterests;
  final String? lastInferredAt;

  const UserDemand({
    this.userStage = 'new_arrival',
    this.predictedNeeds = const [],
    this.recentInterests = const {},
    this.lastInferredAt,
  });

  factory UserDemand.fromJson(Map<String, dynamic> json) {
    return UserDemand(
      userStage: json['user_stage'] as String? ?? 'new_arrival',
      predictedNeeds: (json['predicted_needs'] as List?)
          ?.map((e) => PredictedNeed.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      recentInterests: json['recent_interests'] as Map<String, dynamic>? ?? {},
      lastInferredAt: json['last_inferred_at'] as String?,
    );
  }

  @override
  List<Object?> get props => [userStage, predictedNeeds, recentInterests, lastInferredAt];
}

class PredictedNeed extends Equatable {
  final String category;
  final double confidence;
  final List<String> items;
  final String reason;

  const PredictedNeed({
    required this.category,
    required this.confidence,
    this.items = const [],
    this.reason = '',
  });

  factory PredictedNeed.fromJson(Map<String, dynamic> json) {
    return PredictedNeed(
      category: json['category'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      items: (json['items'] as List?)?.cast<String>() ?? [],
      reason: json['reason'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [category, confidence, items, reason];
}

/// 四维画像汇总
class UserProfileSummary extends Equatable {
  final List<UserCapability> capabilities;
  final UserProfilePreference preference;
  final UserReliability reliability;
  final UserDemand demand;

  const UserProfileSummary({
    this.capabilities = const [],
    this.preference = const UserProfilePreference(),
    this.reliability = const UserReliability(),
    this.demand = const UserDemand(),
  });

  factory UserProfileSummary.fromJson(Map<String, dynamic> json) {
    return UserProfileSummary(
      capabilities: (json['capabilities'] as List?)
          ?.map((e) => UserCapability.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      preference: json['preference'] != null
          ? UserProfilePreference.fromJson(json['preference'] as Map<String, dynamic>)
          : const UserProfilePreference(),
      reliability: json['reliability'] != null
          ? UserReliability.fromJson(json['reliability'] as Map<String, dynamic>)
          : const UserReliability(),
      demand: json['demand'] != null
          ? UserDemand.fromJson(json['demand'] as Map<String, dynamic>)
          : const UserDemand(),
    );
  }

  @override
  List<Object?> get props => [capabilities, preference, reliability, demand];
}
```

- [ ] **Step 2: Verify no analysis errors**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze lib/data/models/user_profile.dart
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/data/models/user_profile.dart
git commit -m "feat(flutter): add user profile data models

Dart models for UserCapability, UserProfilePreference, UserReliability,
UserDemand, PredictedNeed, and UserProfileSummary with Equatable."
```

---

## Task 7: Flutter — Repository + API Endpoints

**Files:**
- Create: `link2ur/lib/data/repositories/user_profile_repository.dart`
- Modify: `link2ur/lib/core/constants/api_endpoints.dart:~509`
- Modify: `link2ur/lib/app_providers.dart:~119`

- [ ] **Step 1: Add API endpoint constants**

Add after line ~509 in `link2ur/lib/core/constants/api_endpoints.dart`:

```dart
// User Profile
static const String profileCapabilities = '/api/profile/capabilities';
static const String profilePreferences = '/api/profile/preferences';
static const String profileReliability = '/api/profile/reliability';
static const String profileDemand = '/api/profile/demand';
static const String profileSummary = '/api/profile/summary';
static const String profileOnboarding = '/api/profile/onboarding';
```

- [ ] **Step 2: Write UserProfileRepository**

Create `link2ur/lib/data/repositories/user_profile_repository.dart`:

```dart
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

class UserProfileException implements Exception {
  final String message;
  const UserProfileException(this.message);
  @override
  String toString() => message;
}

class UserProfileRepository {
  final ApiService _apiService;

  UserProfileRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  // --- Capabilities ---

  Future<List<UserCapability>> getCapabilities() async {
    final response = await _apiService.get(ApiEndpoints.profileCapabilities);
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to load capabilities');
    }
    return (response.data as List)
        .map((e) => UserCapability.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateCapabilities(List<Map<String, dynamic>> capabilities) async {
    final response = await _apiService.put(
      ApiEndpoints.profileCapabilities,
      data: capabilities,
    );
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to update capabilities');
    }
  }

  Future<void> deleteCapability(int id) async {
    final response = await _apiService.delete(
      '${ApiEndpoints.profileCapabilities}/$id',
    );
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to delete capability');
    }
  }

  // --- Preferences ---

  Future<UserProfilePreference> getPreferences() async {
    final response = await _apiService.get(ApiEndpoints.profilePreferences);
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to load preferences');
    }
    return UserProfilePreference.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updatePreferences(Map<String, dynamic> data) async {
    final response = await _apiService.put(
      ApiEndpoints.profilePreferences,
      data: data,
    );
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to update preferences');
    }
  }

  // --- Read-only ---

  Future<UserReliability> getReliability() async {
    final response = await _apiService.get(ApiEndpoints.profileReliability);
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to load reliability');
    }
    return UserReliability.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserDemand> getDemand() async {
    final response = await _apiService.get(ApiEndpoints.profileDemand);
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to load demand');
    }
    return UserDemand.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserProfileSummary> getSummary() async {
    final response = await _apiService.get(ApiEndpoints.profileSummary);
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to load profile summary');
    }
    return UserProfileSummary.fromJson(response.data as Map<String, dynamic>);
  }

  // --- Onboarding ---

  Future<void> submitOnboarding({
    required List<Map<String, dynamic>> capabilities,
    String? mode,
    List<int> preferredCategories = const [],
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.profileOnboarding,
      data: {
        'capabilities': capabilities,
        if (mode != null) 'mode': mode,
        'preferred_categories': preferredCategories,
      },
    );
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Failed to submit onboarding');
    }
  }
}
```

- [ ] **Step 3: Register repository in app_providers.dart**

Add after line ~119 in `link2ur/lib/app_providers.dart`:

```dart
RepositoryProvider<UserProfileRepository>(
  create: (_) => UserProfileRepository(),
),
```

Add import at top:
```dart
import 'data/repositories/user_profile_repository.dart';
```

- [ ] **Step 4: Verify no analysis errors**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze lib/data/repositories/user_profile_repository.dart
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/data/repositories/user_profile_repository.dart link2ur/lib/core/constants/api_endpoints.dart link2ur/lib/app_providers.dart
git commit -m "feat(flutter): add user profile repository and API endpoints

UserProfileRepository with methods for capabilities, preferences,
reliability, demand, summary, and onboarding."
```

---

## Task 8: Flutter — UserProfileBloc

**Files:**
- Create: `link2ur/lib/features/user_profile/bloc/user_profile_bloc.dart`
- Test: `link2ur/test/features/user_profile/bloc/user_profile_bloc_test.dart`

- [ ] **Step 1: Write BLoC test file**

Create `link2ur/test/features/user_profile/bloc/user_profile_bloc_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:link2ur/data/models/user_profile.dart';
import 'package:link2ur/data/repositories/user_profile_repository.dart';
import 'package:link2ur/features/user_profile/bloc/user_profile_bloc.dart';

class MockUserProfileRepository extends Mock implements UserProfileRepository {}

void main() {
  late MockUserProfileRepository mockRepo;

  setUp(() {
    mockRepo = MockUserProfileRepository();
  });

  group('UserProfileBloc', () {
    final testSummary = UserProfileSummary(
      capabilities: [
        const UserCapability(
          id: 1, categoryId: 1, skillName: '英语沟通',
          proficiency: 'intermediate', verificationSource: 'self_declared',
        ),
      ],
      preference: const UserProfilePreference(mode: 'online'),
      reliability: const UserReliability(reliabilityScore: 85, totalTasksTaken: 10, insufficientData: false),
      demand: const UserDemand(userStage: 'settling'),
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'emits [loading, loaded] when LoadSummary succeeds',
      build: () {
        when(() => mockRepo.getSummary()).thenAnswer((_) async => testSummary);
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const UserProfileLoadSummary()),
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        UserProfileState(status: UserProfileStatus.loaded, summary: testSummary),
      ],
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'emits [loading, error] when LoadSummary fails',
      build: () {
        when(() => mockRepo.getSummary()).thenThrow(
          const UserProfileException('Network error'),
        );
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const UserProfileLoadSummary()),
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        const UserProfileState(status: UserProfileStatus.error, errorMessage: 'Network error'),
      ],
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'emits [loading, loaded] when UpdateCapabilities succeeds',
      build: () {
        when(() => mockRepo.updateCapabilities(any())).thenAnswer((_) async {});
        when(() => mockRepo.getSummary()).thenAnswer((_) async => testSummary);
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const UserProfileUpdateCapabilities(
        capabilities: [{'category_id': 1, 'skill_name': '开车', 'proficiency': 'beginner'}],
      )),
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        UserProfileState(status: UserProfileStatus.loaded, summary: testSummary),
      ],
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'emits [loading, loaded] when UpdatePreferences succeeds',
      build: () {
        when(() => mockRepo.updatePreferences(any())).thenAnswer((_) async {});
        when(() => mockRepo.getSummary()).thenAnswer((_) async => testSummary);
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const UserProfileUpdatePreferences(
        preferences: {'mode': 'offline'},
      )),
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        UserProfileState(status: UserProfileStatus.loaded, summary: testSummary),
      ],
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'emits [loading, loaded] when DeleteCapability succeeds',
      build: () {
        when(() => mockRepo.deleteCapability(1)).thenAnswer((_) async {});
        when(() => mockRepo.getSummary()).thenAnswer((_) async => testSummary);
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const UserProfileDeleteCapability(capabilityId: 1)),
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        UserProfileState(status: UserProfileStatus.loaded, summary: testSummary),
      ],
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter test test/features/user_profile/bloc/user_profile_bloc_test.dart
```

Expected: FAIL (UserProfileBloc not found)

- [ ] **Step 3: Write UserProfileBloc**

Create `link2ur/lib/features/user_profile/bloc/user_profile_bloc.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/user_profile_repository.dart';

part 'user_profile_event.dart';
part 'user_profile_state.dart';

class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState> {
  final UserProfileRepository repository;

  UserProfileBloc({required this.repository}) : super(const UserProfileState()) {
    on<UserProfileLoadSummary>(_onLoadSummary);
    on<UserProfileUpdateCapabilities>(_onUpdateCapabilities);
    on<UserProfileDeleteCapability>(_onDeleteCapability);
    on<UserProfileUpdatePreferences>(_onUpdatePreferences);
  }

  Future<void> _onLoadSummary(
    UserProfileLoadSummary event,
    Emitter<UserProfileState> emit,
  ) async {
    emit(state.copyWith(status: UserProfileStatus.loading));
    try {
      final summary = await repository.getSummary();
      emit(state.copyWith(status: UserProfileStatus.loaded, summary: summary));
    } on UserProfileException catch (_) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: 'user_profile_load_failed'));
    } catch (e) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdateCapabilities(
    UserProfileUpdateCapabilities event,
    Emitter<UserProfileState> emit,
  ) async {
    emit(state.copyWith(status: UserProfileStatus.loading));
    try {
      await repository.updateCapabilities(event.capabilities);
      final summary = await repository.getSummary();
      emit(state.copyWith(status: UserProfileStatus.loaded, summary: summary));
    } on UserProfileException catch (_) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: 'user_profile_load_failed'));
    } catch (e) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleteCapability(
    UserProfileDeleteCapability event,
    Emitter<UserProfileState> emit,
  ) async {
    emit(state.copyWith(status: UserProfileStatus.loading));
    try {
      await repository.deleteCapability(event.capabilityId);
      final summary = await repository.getSummary();
      emit(state.copyWith(status: UserProfileStatus.loaded, summary: summary));
    } on UserProfileException catch (_) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: 'user_profile_load_failed'));
    } catch (e) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdatePreferences(
    UserProfileUpdatePreferences event,
    Emitter<UserProfileState> emit,
  ) async {
    emit(state.copyWith(status: UserProfileStatus.loading));
    try {
      await repository.updatePreferences(event.preferences);
      final summary = await repository.getSummary();
      emit(state.copyWith(status: UserProfileStatus.loaded, summary: summary));
    } on UserProfileException catch (_) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: 'user_profile_load_failed'));
    } catch (e) {
      emit(state.copyWith(status: UserProfileStatus.error, errorMessage: e.toString()));
    }
  }
}
```

Create `link2ur/lib/features/user_profile/bloc/user_profile_event.dart`:

```dart
part of 'user_profile_bloc.dart';

abstract class UserProfileEvent extends Equatable {
  const UserProfileEvent();
  @override
  List<Object?> get props => [];
}

class UserProfileLoadSummary extends UserProfileEvent {
  const UserProfileLoadSummary();
}

class UserProfileUpdateCapabilities extends UserProfileEvent {
  final List<Map<String, dynamic>> capabilities;
  const UserProfileUpdateCapabilities({required this.capabilities});
  @override
  List<Object?> get props => [capabilities];
}

class UserProfileDeleteCapability extends UserProfileEvent {
  final int capabilityId;
  const UserProfileDeleteCapability({required this.capabilityId});
  @override
  List<Object?> get props => [capabilityId];
}

class UserProfileUpdatePreferences extends UserProfileEvent {
  final Map<String, dynamic> preferences;
  const UserProfileUpdatePreferences({required this.preferences});
  @override
  List<Object?> get props => [preferences];
}
```

Create `link2ur/lib/features/user_profile/bloc/user_profile_state.dart`:

```dart
part of 'user_profile_bloc.dart';

enum UserProfileStatus { initial, loading, loaded, error }

class UserProfileState extends Equatable {
  final UserProfileStatus status;
  final UserProfileSummary? summary;
  final String? errorMessage;

  const UserProfileState({
    this.status = UserProfileStatus.initial,
    this.summary,
    this.errorMessage,
  });

  UserProfileState copyWith({
    UserProfileStatus? status,
    UserProfileSummary? summary,
    String? errorMessage,
  }) {
    return UserProfileState(
      status: status ?? this.status,
      summary: summary ?? this.summary,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, summary, errorMessage];
}
```

- [ ] **Step 4: Run tests to verify they pass**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter test test/features/user_profile/bloc/user_profile_bloc_test.dart
```

Expected: 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/user_profile/ link2ur/test/features/user_profile/
git commit -m "feat(flutter): add UserProfileBloc with tests

BLoC for loading profile summary, updating capabilities/preferences,
and deleting capabilities. 5 passing tests."
```

---

## Task 9: Flutter — ProfileSetupBloc (Onboarding)

**Files:**
- Create: `link2ur/lib/features/profile_setup/bloc/profile_setup_bloc.dart`

- [ ] **Step 1: Write ProfileSetupBloc**

Create `link2ur/lib/features/profile_setup/bloc/profile_setup_bloc.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/user_profile_repository.dart';

part 'profile_setup_event.dart';
part 'profile_setup_state.dart';

class ProfileSetupBloc extends Bloc<ProfileSetupEvent, ProfileSetupState> {
  final UserProfileRepository repository;

  ProfileSetupBloc({required this.repository}) : super(const ProfileSetupState()) {
    on<ProfileSetupSelectCategory>(_onSelectCategory);
    on<ProfileSetupSetMode>(_onSetMode);
    on<ProfileSetupAddSkill>(_onAddSkill);
    on<ProfileSetupRemoveSkill>(_onRemoveSkill);
    on<ProfileSetupSubmit>(_onSubmit);
  }

  void _onSelectCategory(ProfileSetupSelectCategory event, Emitter<ProfileSetupState> emit) {
    final categories = List<int>.from(state.selectedCategories);
    if (categories.contains(event.categoryId)) {
      categories.remove(event.categoryId);
    } else {
      categories.add(event.categoryId);
    }
    emit(state.copyWith(selectedCategories: categories));
  }

  void _onSetMode(ProfileSetupSetMode event, Emitter<ProfileSetupState> emit) {
    emit(state.copyWith(mode: event.mode));
  }

  void _onAddSkill(ProfileSetupAddSkill event, Emitter<ProfileSetupState> emit) {
    final skills = List<Map<String, dynamic>>.from(state.selectedSkills);
    skills.add({'category_id': event.categoryId, 'skill_name': event.skillName});
    emit(state.copyWith(selectedSkills: skills));
  }

  void _onRemoveSkill(ProfileSetupRemoveSkill event, Emitter<ProfileSetupState> emit) {
    final skills = List<Map<String, dynamic>>.from(state.selectedSkills);
    skills.removeWhere((s) => s['skill_name'] == event.skillName);
    emit(state.copyWith(selectedSkills: skills));
  }

  Future<void> _onSubmit(ProfileSetupSubmit event, Emitter<ProfileSetupState> emit) async {
    emit(state.copyWith(status: ProfileSetupStatus.submitting));
    try {
      await repository.submitOnboarding(
        capabilities: state.selectedSkills,
        mode: state.mode,
        preferredCategories: state.selectedCategories,
      );
      emit(state.copyWith(status: ProfileSetupStatus.success));
    } on UserProfileException catch (e) {
      emit(state.copyWith(status: ProfileSetupStatus.error, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(status: ProfileSetupStatus.error, errorMessage: e.toString()));
    }
  }
}
```

Create `link2ur/lib/features/profile_setup/bloc/profile_setup_event.dart`:

```dart
part of 'profile_setup_bloc.dart';

abstract class ProfileSetupEvent extends Equatable {
  const ProfileSetupEvent();
  @override
  List<Object?> get props => [];
}

class ProfileSetupSelectCategory extends ProfileSetupEvent {
  final int categoryId;
  const ProfileSetupSelectCategory({required this.categoryId});
  @override
  List<Object?> get props => [categoryId];
}

class ProfileSetupSetMode extends ProfileSetupEvent {
  final String mode;
  const ProfileSetupSetMode({required this.mode});
  @override
  List<Object?> get props => [mode];
}

class ProfileSetupAddSkill extends ProfileSetupEvent {
  final int categoryId;
  final String skillName;
  const ProfileSetupAddSkill({required this.categoryId, required this.skillName});
  @override
  List<Object?> get props => [categoryId, skillName];
}

class ProfileSetupRemoveSkill extends ProfileSetupEvent {
  final String skillName;
  const ProfileSetupRemoveSkill({required this.skillName});
  @override
  List<Object?> get props => [skillName];
}

class ProfileSetupSubmit extends ProfileSetupEvent {
  const ProfileSetupSubmit();
}
```

Create `link2ur/lib/features/profile_setup/bloc/profile_setup_state.dart`:

```dart
part of 'profile_setup_bloc.dart';

enum ProfileSetupStatus { initial, submitting, success, error }

class ProfileSetupState extends Equatable {
  final ProfileSetupStatus status;
  final List<int> selectedCategories;
  final List<Map<String, dynamic>> selectedSkills;
  final String mode;
  final String? errorMessage;

  const ProfileSetupState({
    this.status = ProfileSetupStatus.initial,
    this.selectedCategories = const [],
    this.selectedSkills = const [],
    this.mode = 'both',
    this.errorMessage,
  });

  ProfileSetupState copyWith({
    ProfileSetupStatus? status,
    List<int>? selectedCategories,
    List<Map<String, dynamic>>? selectedSkills,
    String? mode,
    String? errorMessage,
  }) {
    return ProfileSetupState(
      status: status ?? this.status,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedSkills: selectedSkills ?? this.selectedSkills,
      mode: mode ?? this.mode,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, selectedCategories, selectedSkills, mode, errorMessage];
}
```

- [ ] **Step 2: Verify no analysis errors**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze lib/features/profile_setup/
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/profile_setup/
git commit -m "feat(flutter): add ProfileSetupBloc for onboarding

Manages category/skill selection and mode preference during
post-registration profile setup flow."
```

---

## Task 10: Flutter — Views (My Profile + Capability Edit + Preference Edit)

**Files:**
- Create: `link2ur/lib/features/user_profile/views/my_profile_view.dart`
- Create: `link2ur/lib/features/user_profile/views/capability_edit_view.dart`
- Create: `link2ur/lib/features/user_profile/views/preference_edit_view.dart`

- [ ] **Step 1: Write my_profile_view.dart**

Create `link2ur/lib/features/user_profile/views/my_profile_view.dart` — four-dimension summary page showing capabilities, preference, reliability, and demand as card sections. Each section has an edit/view button. Use `BlocProvider` to create `UserProfileBloc` at page level, dispatch `UserProfileLoadSummary` in `initState`. Use existing design system widgets from `core/design/` and `core/widgets/`.

Key structure:
- AppBar with title "我的画像" / "My Profile"
- `BlocBuilder<UserProfileBloc, UserProfileState>` for content
- Loading → `LoadingIndicator`, Error → `ErrorStateView` with retry
- Loaded → `SingleChildScrollView` with 4 cards:
  - Capabilities card: chip list of skills with proficiency badges
  - Preference card: mode, categories, time slots summary
  - Reliability card: score gauge (or "数据不足" if insufficient), key metrics
  - Demand card: user stage badge, predicted needs list

- [ ] **Step 2: Write capability_edit_view.dart**

Create `link2ur/lib/features/user_profile/views/capability_edit_view.dart` — skill management page. Two-layer selection: first pick category, then add skills under it with proficiency selector.

Key structure:
- AppBar with title "管理技能" / "Manage Skills"
- Current skills list with delete (swipe/icon) and proficiency edit
- "Add Skill" FAB → bottom sheet with category tabs and skill chips
- Save button dispatches `UserProfileUpdateCapabilities`

- [ ] **Step 3: Write preference_edit_view.dart**

Create `link2ur/lib/features/user_profile/views/preference_edit_view.dart` — preference editing form.

Key structure:
- AppBar with title "偏好设置" / "Preference Settings"
- Mode selector (online/offline/both) — segmented control
- Duration type selector — segmented control
- Reward preference selector — segmented control
- Time slots — multi-select chips
- Categories — multi-select chips
- Save button dispatches `UserProfileUpdatePreferences`

- [ ] **Step 4: Verify no analysis errors**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze lib/features/user_profile/views/
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/user_profile/views/
git commit -m "feat(flutter): add user profile views

MyProfileView (four-dimension summary), CapabilityEditView (skill management),
PreferenceEditView (preference settings form)."
```

---

## Task 11: Flutter — ProfileSetupView (Onboarding)

**Files:**
- Create: `link2ur/lib/features/profile_setup/views/profile_setup_view.dart`

- [ ] **Step 1: Write profile_setup_view.dart**

Create `link2ur/lib/features/profile_setup/views/profile_setup_view.dart` — post-registration profile setup with 2 steps.

Key structure:
- `PageView` with 2 pages:
  - Page 1: "你擅长什么？" — category chips (multi-select, max 5) + skill chips per selected category
  - Page 2: "你更喜欢？" — mode selector (online/offline/both)
- Bottom: "下一步"/"完成" button + "跳过" skip link
- On complete: dispatch `ProfileSetupSubmit`, then navigate to home
- On skip: navigate to home directly
- Use `BlocProvider` to create `ProfileSetupBloc` at page level

- [ ] **Step 2: Verify no analysis errors**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze lib/features/profile_setup/views/
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/features/profile_setup/views/
git commit -m "feat(flutter): add ProfileSetupView for post-registration onboarding

Two-step wizard: skill category/skill selection, then mode preference.
Supports skip and submit with ProfileSetupBloc."
```

---

## Task 12: Flutter — Routing + Localization

**Files:**
- Modify: `link2ur/lib/core/router/app_routes.dart:~121`
- Modify: `link2ur/lib/core/router/routes/profile_routes.dart`
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb`

- [ ] **Step 1: Add route constants**

In `link2ur/lib/core/router/app_routes.dart`, add route constants:

```dart
static const String myProfile = '/my-profile';
static const String capabilityEdit = '/my-profile/capabilities';
static const String preferenceEdit = '/my-profile/preferences';
static const String profileSetup = '/profile-setup';
```

Add `myProfile`, `capabilityEdit`, `preferenceEdit` to `authRequiredRoutes` set.

- [ ] **Step 2: Add GoRouter routes**

In `link2ur/lib/core/router/routes/profile_routes.dart`, add routes:

```dart
GoRoute(
  path: AppRoutes.myProfile,
  builder: (context, state) => const MyProfileView(),
  routes: [
    GoRoute(
      path: 'capabilities',
      builder: (context, state) => const CapabilityEditView(),
    ),
    GoRoute(
      path: 'preferences',
      builder: (context, state) => const PreferenceEditView(),
    ),
  ],
),
```

Add `profileSetup` route in `misc_routes.dart`.

- [ ] **Step 3: Add localization strings**

Add to all three ARB files (app_en.arb, app_zh.arb, app_zh_Hant.arb):

Key strings needed:
- `myProfileTitle` — "My Profile" / "我的画像" / "我的畫像"
- `capabilityTitle` — "Skills" / "能力" / "能力"
- `preferenceTitle` — "Preferences" / "偏好" / "偏好"
- `reliabilityTitle` — "Reliability" / "可靠度" / "可靠度"
- `demandTitle` — "Predicted Needs" / "需求预测" / "需求預測"
- `insufficientData` — "Insufficient data" / "数据不足" / "數據不足"
- `manageSkills` — "Manage Skills" / "管理技能" / "管理技能"
- `preferenceSettings` — "Preference Settings" / "偏好设置" / "偏好設定"
- `profileSetupTitle` — "Set Up Profile" / "设置画像" / "設置畫像"
- `profileSetupSkillQuestion` — "What are you good at?" / "你擅长什么？" / "你擅長什麼？"
- `profileSetupModeQuestion` — "What do you prefer?" / "你更喜欢？" / "你更喜歡？"
- `modeOnline` — "Online" / "线上" / "線上"
- `modeOffline` — "Offline" / "线下" / "線下"
- `modeBoth` — "Both" / "都可以" / "都可以"
- `skip` — "Skip" / "跳过" / "跳過"
- `proficiencyBeginner` — "Beginner" / "入门" / "入門"
- `proficiencyIntermediate` — "Intermediate" / "熟练" / "熟練"
- `proficiencyExpert` — "Expert" / "精通" / "精通"

- [ ] **Step 4: Generate l10n files**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter gen-l10n
```

- [ ] **Step 5: Verify full analysis passes**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze
```

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/core/router/ link2ur/lib/l10n/
git commit -m "feat(flutter): add routing and localization for user profile

Routes for MyProfile, CapabilityEdit, PreferenceEdit, ProfileSetup.
Localization strings in en/zh/zh_Hant for all profile UI."
```

---

## Task 13: Integration — Wire Profile Entry Points

**Files:**
- Modify: `link2ur/lib/features/profile/views/profile_view.dart`
- Modify: `link2ur/lib/features/onboarding/views/onboarding_view.dart`

- [ ] **Step 1: Add "我的画像" entry in profile_view.dart**

Add a menu item/card in the profile page that navigates to `AppRoutes.myProfile`. Place it near "任务偏好" (task_preferences_view) since they're related.

```dart
// In the profile menu section, add:
ListTile(
  leading: const Icon(Icons.person_outline),
  title: Text(context.l10n.myProfileTitle),
  trailing: const Icon(Icons.chevron_right),
  onTap: () => context.push(AppRoutes.myProfile),
),
```

- [ ] **Step 2: Add profile setup trigger after onboarding**

In `link2ur/lib/features/onboarding/views/onboarding_view.dart`, after the existing onboarding flow completes (when user taps the final "开始" button), check if the user has completed profile setup. If not, navigate to `AppRoutes.profileSetup` instead of directly to home.

```dart
// After onboarding completion:
// Check if profile setup needed (e.g., no capabilities saved yet)
context.go(AppRoutes.profileSetup);
// ProfileSetupView handles skip → home navigation
```

- [ ] **Step 3: Verify no analysis errors**

```powershell
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; cd link2ur; flutter analyze
```

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/profile/ link2ur/lib/features/onboarding/
git commit -m "feat(flutter): wire user profile entry points

Add 'My Profile' menu item in profile page.
Trigger profile setup after onboarding completion."
```

---

## Task 14: Backend — Data Migration Script

**Files:**
- Create: `backend/scripts/migrate_user_skills.py`

- [ ] **Step 1: Write migration script**

Create `backend/scripts/migrate_user_skills.py`:

```python
"""Migrate data from UserSkill to UserCapability.

Usage: python -m scripts.migrate_user_skills [--dry-run]
"""
import sys
from sqlalchemy.orm import Session
from app.database import SessionLocal
from app.models import UserSkill, SkillCategory, User
from app.models import (
    UserCapability, UserReliability, ProficiencyLevel, VerificationSource
)


def build_category_map(db: Session) -> dict[str, int]:
    """Map category name strings to SkillCategory IDs."""
    categories = db.query(SkillCategory).filter(SkillCategory.is_active == True).all()
    mapping = {}
    for cat in categories:
        if cat.name_zh:
            mapping[cat.name_zh.lower()] = cat.id
        if cat.name_en:
            mapping[cat.name_en.lower()] = cat.id
    return mapping


def migrate_skills(db: Session, dry_run: bool = False) -> dict:
    """Migrate UserSkill records to UserCapability."""
    category_map = build_category_map(db)
    stats = {"migrated": 0, "skipped_duplicate": 0, "skipped_no_category": 0}

    # Get or create "其他" category for unmatched
    other_cat = db.query(SkillCategory).filter(SkillCategory.name_zh == "其他").first()
    if not other_cat and not dry_run:
        other_cat = SkillCategory(name_zh="其他", name_en="Other", is_active=True, display_order=99)
        db.add(other_cat)
        db.flush()
    other_cat_id = other_cat.id if other_cat else None

    skills = db.query(UserSkill).all()
    for skill in skills:
        # Check if already migrated
        existing = db.query(UserCapability).filter(
            UserCapability.user_id == skill.user_id,
            UserCapability.skill_name == skill.skill_name,
        ).first()
        if existing:
            stats["skipped_duplicate"] += 1
            continue

        # Map category
        cat_id = category_map.get(skill.skill_category.lower()) if skill.skill_category else None
        if not cat_id:
            cat_id = other_cat_id
        if not cat_id:
            stats["skipped_no_category"] += 1
            continue

        if not dry_run:
            cap = UserCapability(
                user_id=skill.user_id,
                category_id=cat_id,
                skill_name=skill.skill_name,
                proficiency=ProficiencyLevel.beginner,
                verification_source=VerificationSource.self_declared,
            )
            db.add(cap)
        stats["migrated"] += 1

    return stats


def init_reliability(db: Session, dry_run: bool = False) -> int:
    """Initialize UserReliability for all users with task history."""
    users = db.query(User).filter(User.task_count > 0).all()
    count = 0
    for user in users:
        existing = db.query(UserReliability).filter(
            UserReliability.user_id == user.id
        ).first()
        if existing:
            continue

        if not dry_run:
            rel = UserReliability(
                user_id=user.id,
                total_tasks_taken=user.completed_task_count or 0,
                completion_rate=(user.completed_task_count or 0) / max(user.task_count, 1),
                communication_score=user.avg_rating or 0.0,
            )
            db.add(rel)
        count += 1
    return count


def main():
    dry_run = "--dry-run" in sys.argv
    if dry_run:
        print("=== DRY RUN MODE ===")

    db = SessionLocal()
    try:
        print("Migrating skills...")
        stats = migrate_skills(db, dry_run)
        print(f"  Skills: {stats}")

        print("Initializing reliability...")
        rel_count = init_reliability(db, dry_run)
        print(f"  Reliability records created: {rel_count}")

        if not dry_run:
            db.commit()
            print("Migration committed.")
        else:
            db.rollback()
            print("Dry run complete, no changes made.")
    finally:
        db.close()


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Commit**

```bash
git add backend/scripts/migrate_user_skills.py
git commit -m "feat(backend): add data migration script for user skills

Migrates UserSkill to UserCapability with category mapping.
Initializes UserReliability from existing user stats.
Supports --dry-run mode."
```

---

## Task 13.5: Flutter — Homepage Demand Recommendation Cards

**Files:**
- Create: `link2ur/lib/features/home/widgets/demand_recommendation_card.dart`
- Modify: Home page view (wherever the home feed is rendered)

- [ ] **Step 1: Write demand recommendation card widget**

Create `link2ur/lib/features/home/widgets/demand_recommendation_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../l10n/app_localizations.dart';

class DemandRecommendationCard extends StatefulWidget {
  const DemandRecommendationCard({super.key});

  @override
  State<DemandRecommendationCard> createState() => _DemandRecommendationCardState();
}

class _DemandRecommendationCardState extends State<DemandRecommendationCard> {
  UserDemand? _demand;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDemand();
  }

  Future<void> _loadDemand() async {
    try {
      final repo = context.read<UserProfileRepository>();
      final demand = await repo.getDemand();
      if (mounted) setState(() { _demand = demand; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _demand == null) return const SizedBox.shrink();

    // Filter to confidence >= 0.5 (card threshold), max 3
    final needs = _demand!.predictedNeeds
        .where((n) => n.confidence >= 0.5)
        .take(3)
        .toList();
    if (needs.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.youMightNeed, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: needs.expand((need) => need.items.map((item) =>
                ActionChip(
                  label: Text(item),
                  onPressed: () {
                    // Navigate to task publish or search with this item pre-filled
                    // context.goToPublishTask(prefill: item);
                  },
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Add to home page**

In the home page view, add `DemandRecommendationCard()` after the existing content (e.g., below the banner or discovery feed). It self-manages its loading state and hides when there's no data.

- [ ] **Step 3: Add localization string**

Add to all 3 ARB files:
- `youMightNeed`: "You might need" / "你可能需要" / "你可能需要"

- [ ] **Step 4: Commit**

```bash
git add link2ur/lib/features/home/widgets/demand_recommendation_card.dart
git commit -m "feat(flutter): add demand recommendation cards on homepage

Shows 'you might need' suggestions based on demand profile.
Filters by confidence >= 0.5, max 3 items. Self-loading widget."
```

---

## Summary

| Task | Component | Description |
|------|-----------|-------------|
| 1 | Backend Models | 4 SQLAlchemy models + enums (appended to models.py) |
| 2 | Backend Services | UserProfileService CRUD + ReliabilityCalculator |
| 3 | Backend Services | Demand inference engine |
| 3.5 | Backend Services | Scheduled tasks (nightly demand + weekly reliability) |
| 4 | Backend Routes | 9 API endpoints under `/api/profile/*` |
| 5 | Backend Tests | 17 API integration tests |
| 6 | Flutter Models | Dart models for all 4 dimensions |
| 7 | Flutter Repository | UserProfileRepository + API endpoints + DI |
| 8 | Flutter BLoC | UserProfileBloc with 5 tests |
| 9 | Flutter BLoC | ProfileSetupBloc for onboarding |
| 10 | Flutter Views | MyProfile + CapabilityEdit + PreferenceEdit |
| 11 | Flutter Views | ProfileSetupView (onboarding wizard) |
| 12 | Flutter Routing | Routes + localization (3 locales) |
| 13 | Flutter Integration | Wire entry points in profile + onboarding |
| 13.5 | Flutter Widget | Homepage demand recommendation cards |
| 14 | Backend Migration | Data migration script (UserSkill → UserCapability) |
