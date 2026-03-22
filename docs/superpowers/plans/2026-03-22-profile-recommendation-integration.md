# Profile Data Integration into Recommendation & AI System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate user profile data (preferences, demand predictions) into the task recommendation engine and AI chat system, refactoring the engine into a modular scorer architecture.

**Architecture:** Refactor the monolithic `task_recommendation.py` (2100+ lines) into a pluggable scorer system under `backend/app/recommendation/`. Merge the old `UserPreferences` model into `UserProfilePreference`. Add two new scorers (profile_scorer, demand_scorer) and inject user profile context into AI chat.

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy, Alembic, Redis, pytest

**Spec:** `docs/superpowers/specs/2026-03-22-profile-recommendation-integration-design.md`

---

## File Structure

### New Files (Create)

```
backend/app/recommendation/
├── __init__.py                    # Package init; register all scorers
├── engine.py                      # HybridEngine: orchestrates scorers, merges scores
├── base_scorer.py                 # BaseScorer ABC + ScoredTask dataclass
├── scorer_registry.py             # ScorerRegistry: register/discover scorers, normalize weights
├── user_vector.py                 # Build user preference vector from merged UserProfilePreference
├── cache.py                       # Cache logic extracted from task_recommendation.py
├── utils.py                       # Shared utilities (Haversine, excluded task IDs, etc.)
├── scorers/
│   ├── __init__.py
│   ├── content_scorer.py          # Extracted from _content_based_recommend + _calculate_content_match_score
│   ├── collaborative_scorer.py    # Extracted from _collaborative_filtering_recommend
│   ├── location_scorer.py         # Extracted from _location_based_recommend
│   ├── social_scorer.py           # Extracted from _social_based_recommend
│   ├── time_scorer.py             # Extracted from _time_based_recommend
│   ├── popularity_scorer.py       # Extracted from _popular_tasks_recommend
│   ├── newness_scorer.py          # Extracted from _new_task_boost_recommend
│   ├── profile_scorer.py          # [NEW] Profile preference matching
│   └── demand_scorer.py           # [NEW] AI demand prediction matching

backend/tests/
├── test_base_scorer.py
├── test_scorer_registry.py
├── test_engine.py
├── test_profile_scorer.py
├── test_demand_scorer.py
├── test_ai_profile_context.py

backend/alembic/versions/
└── xxxx_merge_user_preferences.py  # Alembic migration
```

### Modified Files

```
backend/app/task_recommendation.py          # Thin wrapper delegating to recommendation/engine.py
backend/app/models.py                       # Add columns to UserProfilePreference
backend/app/routers.py                      # Update /user-preferences endpoints
backend/app/services/ai_agent.py            # Inject profile context into system prompt
backend/app/services/ai_agent.py            # Inject profile context + proactive suggestions into _step_llm
```

---

## Task 1: BaseScorer and ScoredTask

**Files:**
- Create: `backend/app/recommendation/__init__.py`
- Create: `backend/app/recommendation/base_scorer.py`
- Create: `backend/app/recommendation/scorers/__init__.py`
- Test: `backend/tests/test_base_scorer.py`

- [ ] **Step 1: Create package structure**

```bash
mkdir -p backend/app/recommendation/scorers
```

- [ ] **Step 2: Write the test**

```python
# backend/tests/test_base_scorer.py
import pytest
from app.recommendation.base_scorer import BaseScorer, ScoredTask


class DummyScorer(BaseScorer):
    name = "dummy"
    default_weight = 0.5

    def score(self, user, tasks, context):
        return {1: ScoredTask(score=0.8, reason="test reason")}


def test_scored_task_creation():
    st = ScoredTask(score=0.75, reason="matched interests")
    assert st.score == 0.75
    assert st.reason == "matched interests"


def test_scored_task_score_clamped():
    st = ScoredTask(score=1.5, reason="over")
    assert st.clamped_score == 1.0
    st2 = ScoredTask(score=-0.1, reason="under")
    assert st2.clamped_score == 0.0


def test_base_scorer_default_weight():
    scorer = DummyScorer()
    assert scorer.get_weight(None) == 0.5


def test_base_scorer_score_returns_dict():
    scorer = DummyScorer()
    result = scorer.score(None, [], {})
    assert isinstance(result, dict)
    assert 1 in result
    assert result[1].score == 0.8
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd backend && python -m pytest tests/test_base_scorer.py -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'app.recommendation'`

- [ ] **Step 4: Implement BaseScorer and ScoredTask**

```python
# backend/app/recommendation/__init__.py
"""Task recommendation engine with pluggable scorer architecture."""

# backend/app/recommendation/scorers/__init__.py
"""Individual scorer implementations."""

# backend/app/recommendation/base_scorer.py
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Dict, List, Any


@dataclass
class ScoredTask:
    """A task with a relevance score and human-readable reason."""
    score: float        # 0.0 - 1.0 (raw, may exceed bounds)
    reason: str         # Human-readable recommendation reason

    @property
    def clamped_score(self) -> float:
        """Score clamped to [0.0, 1.0]."""
        return max(0.0, min(1.0, self.score))


class BaseScorer(ABC):
    """Abstract base class for all recommendation scorers."""
    name: str
    default_weight: float

    @abstractmethod
    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        """Score tasks for a user.

        Args:
            user: SQLAlchemy User object
            tasks: List of candidate Task objects
            context: Shared context dict (db session, caches, GPS coords, etc.)

        Returns:
            Dict mapping task_id -> ScoredTask for relevant tasks.
            Tasks not in the dict receive score 0.
        """

    def get_weight(self, user) -> float:
        """Return this scorer's weight for the given user.

        Override in subclasses for dynamic weight adjustment (e.g., demand_scorer).
        """
        return self.default_weight
```

- [ ] **Step 5: Run test to verify it passes**

```bash
cd backend && python -m pytest tests/test_base_scorer.py -v
```

Expected: PASS (4 tests)

- [ ] **Step 6: Commit**

```bash
git add backend/app/recommendation/ backend/tests/test_base_scorer.py
git commit -m "feat: add BaseScorer and ScoredTask for pluggable recommendation architecture"
```

---

## Task 2: ScorerRegistry

**Files:**
- Create: `backend/app/recommendation/scorer_registry.py`
- Test: `backend/tests/test_scorer_registry.py`

- [ ] **Step 1: Write the test**

```python
# backend/tests/test_scorer_registry.py
import pytest
from app.recommendation.base_scorer import BaseScorer, ScoredTask
from app.recommendation.scorer_registry import ScorerRegistry


class MockScorerA(BaseScorer):
    name = "scorer_a"
    default_weight = 0.6

    def score(self, user, tasks, context):
        return {}


class MockScorerB(BaseScorer):
    name = "scorer_b"
    default_weight = 0.4

    def score(self, user, tasks, context):
        return {}


class DynamicScorer(BaseScorer):
    name = "dynamic"
    default_weight = 0.2

    def get_weight(self, user):
        # Simulate dynamic weight based on user
        if user and getattr(user, "interaction_count", 0) > 50:
            return 0.05
        return 0.20

    def score(self, user, tasks, context):
        return {}


def test_register_and_get_scorers():
    reg = ScorerRegistry()
    a = MockScorerA()
    b = MockScorerB()
    reg.register(a)
    reg.register(b)
    scorers = reg.get_active_scorers()
    assert len(scorers) == 2
    assert a in scorers
    assert b in scorers


def test_duplicate_registration_raises():
    reg = ScorerRegistry()
    reg.register(MockScorerA())
    with pytest.raises(ValueError, match="already registered"):
        reg.register(MockScorerA())


def test_normalize_weights_sum_to_one():
    reg = ScorerRegistry()
    reg.register(MockScorerA())  # 0.6
    reg.register(MockScorerB())  # 0.4
    weights = reg.normalize_weights(user=None)
    assert abs(sum(weights.values()) - 1.0) < 0.001
    assert abs(weights["scorer_a"] - 0.6) < 0.001
    assert abs(weights["scorer_b"] - 0.4) < 0.001


def test_normalize_weights_with_dynamic_scorer():
    reg = ScorerRegistry()
    reg.register(MockScorerA())  # 0.6
    reg.register(DynamicScorer())  # 0.2 for new user

    # New user (no interaction_count attr)
    weights = reg.normalize_weights(user=None)
    total = weights["scorer_a"] + weights["dynamic"]
    assert abs(total - 1.0) < 0.001

    # Mature user
    class FakeUser:
        interaction_count = 100
    weights2 = reg.normalize_weights(user=FakeUser())
    # dynamic weight should be much lower
    assert weights2["dynamic"] < weights["dynamic"]


def test_normalize_weights_zero_total_returns_equal():
    """Edge case: all scorers return weight 0."""
    class ZeroScorer(BaseScorer):
        name = "zero"
        default_weight = 0.0
        def score(self, user, tasks, context): return {}

    reg = ScorerRegistry()
    reg.register(ZeroScorer())
    weights = reg.normalize_weights(user=None)
    assert weights["zero"] == 0.0
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd backend && python -m pytest tests/test_scorer_registry.py -v
```

Expected: FAIL — `ModuleNotFoundError`

- [ ] **Step 3: Implement ScorerRegistry**

```python
# backend/app/recommendation/scorer_registry.py
import logging
from typing import Dict, List, Optional

from .base_scorer import BaseScorer

logger = logging.getLogger(__name__)


class ScorerRegistry:
    """Manages scorer registration and weight normalization."""

    def __init__(self):
        self._scorers: Dict[str, BaseScorer] = {}

    def register(self, scorer: BaseScorer) -> None:
        """Register a scorer instance. Raises ValueError on duplicate name."""
        if scorer.name in self._scorers:
            raise ValueError(f"Scorer '{scorer.name}' already registered")
        self._scorers[scorer.name] = scorer
        logger.info(f"Registered scorer: {scorer.name} (default_weight={scorer.default_weight})")

    def get_active_scorers(self) -> List[BaseScorer]:
        """Return all registered scorers."""
        return list(self._scorers.values())

    def get_scorer(self, name: str) -> Optional[BaseScorer]:
        """Get a scorer by name."""
        return self._scorers.get(name)

    def normalize_weights(self, user) -> Dict[str, float]:
        """Get weights for all scorers, normalized to sum to 1.0.

        Calls each scorer's get_weight(user) for dynamic adjustment,
        then scales proportionally.
        """
        raw_weights = {}
        for name, scorer in self._scorers.items():
            raw_weights[name] = scorer.get_weight(user)

        total = sum(raw_weights.values())
        if total <= 0:
            # All weights are zero; return zeros
            return {name: 0.0 for name in raw_weights}

        return {name: w / total for name, w in raw_weights.items()}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd backend && python -m pytest tests/test_scorer_registry.py -v
```

Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add backend/app/recommendation/scorer_registry.py backend/tests/test_scorer_registry.py
git commit -m "feat: add ScorerRegistry with weight normalization"
```

---

## Task 3: Utility functions and cache extraction

**Files:**
- Create: `backend/app/recommendation/utils.py`
- Create: `backend/app/recommendation/cache.py`
- Modify: `backend/app/task_recommendation.py` (read lines 1076-1108 for Haversine, lines 85-121 for cache)

- [ ] **Step 1: Extract utility functions**

Read `backend/app/task_recommendation.py` lines 1076-1108 (`_calculate_distance`) and other shared helpers. Create `utils.py` with these functions extracted as module-level functions.

```python
# backend/app/recommendation/utils.py
"""Shared utilities for recommendation scorers."""
import math
import logging
from typing import Optional, Set
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate distance in meters between two GPS coordinates using Haversine formula.

    Returns float('inf') if coordinates are invalid.
    """
    # Validate coordinates
    if not (-90 <= lat1 <= 90 and -90 <= lat2 <= 90 and
            -180 <= lon1 <= 180 and -180 <= lon2 <= 180):
        return float('inf')

    R = 6371000  # Earth radius in meters
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)

    a = (math.sin(dphi / 2) ** 2 +
         math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    return R * c


def get_excluded_task_ids(db: Session, user_id: str) -> Set[int]:
    """Get task IDs that should be excluded from recommendations.

    Excludes: user's own tasks, tasks user already applied to,
    tasks user completed, tasks user was assigned to.
    """
    from app.models import Task, TaskApplication

    excluded = set()

    # User's own tasks
    own_tasks = db.query(Task.id).filter(Task.poster_id == user_id).all()
    excluded.update(t.id for t in own_tasks)

    # Tasks user applied to
    applied = db.query(TaskApplication.task_id).filter(
        TaskApplication.applicant_id == user_id
    ).all()
    excluded.update(t.task_id for t in applied)

    # Tasks user is taker of
    taken = db.query(Task.id).filter(Task.taker_id == user_id).all()
    excluded.update(t.id for t in taken)

    return excluded


def is_new_user(user, days: int = 7) -> bool:
    """Check if user registered within the last N days."""
    if not user or not user.created_at:
        return True
    from app.crud import get_utc_time
    return (get_utc_time() - user.created_at).days <= days
```

- [ ] **Step 2: Extract cache logic**

Read `backend/app/task_recommendation.py` lines 85-121 for cache strategy. Create `cache.py` that wraps the existing multi-level cache.

```python
# backend/app/recommendation/cache.py
"""Recommendation caching with multi-level fallback."""
import json
import logging
from typing import Optional, List, Dict

logger = logging.getLogger(__name__)

# Try to import cache modules (may not all be available)
try:
    from app.recommendation_cache_strategy import SmartCacheStrategy
    _smart_cache = SmartCacheStrategy()
except Exception:
    _smart_cache = None

try:
    from app.recommendation_cache import RecommendationCache
    _opt_cache = RecommendationCache()
except Exception:
    _opt_cache = None

try:
    from app.redis_cache import redis_cache
    _redis = redis_cache
except Exception:
    _redis = None


def get_cached_recommendations(user_id: str, algorithm: str, limit: int) -> Optional[List[Dict]]:
    """Try to get cached recommendations from multi-level cache."""
    cache_key = f"rec:{user_id}:{algorithm}:{limit}"

    # Level 1: Smart cache strategy
    if _smart_cache:
        try:
            cached = _smart_cache.get(cache_key)
            if cached:
                return cached
        except Exception:
            pass

    # Level 2: Optimized cache
    if _opt_cache:
        try:
            cached = _opt_cache.get(cache_key)
            if cached:
                return cached
        except Exception:
            pass

    # Level 3: Raw Redis
    if _redis:
        try:
            cached = _redis.get(cache_key)
            if cached:
                return json.loads(cached) if isinstance(cached, str) else cached
        except Exception:
            pass

    return None


def set_cached_recommendations(user_id: str, algorithm: str, limit: int,
                                recommendations: List[Dict], ttl: int = 1800) -> None:
    """Cache recommendations with TTL (default 30 minutes)."""
    cache_key = f"rec:{user_id}:{algorithm}:{limit}"

    if _smart_cache:
        try:
            _smart_cache.set(cache_key, recommendations, ttl=ttl)
            return
        except Exception:
            pass

    if _redis:
        try:
            _redis.setex(cache_key, ttl, json.dumps(recommendations, default=str))
        except Exception:
            pass
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/recommendation/utils.py backend/app/recommendation/cache.py
git commit -m "feat: extract recommendation utils and cache into recommendation package"
```

---

## Task 4: Extract existing scorers (content, collaborative, location)

**Files:**
- Create: `backend/app/recommendation/scorers/content_scorer.py`
- Create: `backend/app/recommendation/scorers/collaborative_scorer.py`
- Create: `backend/app/recommendation/scorers/location_scorer.py`
- Create: `backend/app/recommendation/user_vector.py`
- Read: `backend/app/task_recommendation.py` lines 320-532, 904-1108, 1662-1851

This is the largest extraction task. Each scorer must preserve the exact logic from the monolith.

**CRITICAL: No `NotImplementedError` stubs allowed.** The implementer MUST read the specified line ranges from `task_recommendation.py` and copy the complete logic into each scorer. The code snippets below show the interface/structure; the body of each `score()` method and helper must be fully implemented by copying from the original. A task is NOT complete until all `raise NotImplementedError` are replaced with working code.

- [ ] **Step 1: Create user_vector.py**

Extract `_build_user_preference_vector` (lines 1662-1801) and `_get_user_preferences` (line 1500), `_get_user_task_history` (line 1506), `_get_user_view_history` (line 1517), `_get_user_search_keywords` (line 1559) into a standalone module.

```python
# backend/app/recommendation/user_vector.py
"""Build user preference vectors from UserProfilePreference + behavior data."""
import json
import logging
from typing import Dict, List, Optional, Any

from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)


def build_user_preference_vector(
    db: Session,
    user,
    preferences=None,
    history=None,
    view_history=None,
    search_keywords=None,
    skipped_tasks=None,
) -> Dict[str, Any]:
    """Build a user preference vector from explicit preferences + behavioral data.

    This is a direct extraction of TaskRecommendationEngine._build_user_preference_vector.
    Read the original at task_recommendation.py:1662-1801 and replicate the exact logic.

    Returns dict with keys:
        task_types, task_types_from_preference, locations, locations_from_preference,
        price_range, price_range_from_history, task_levels, keywords, negative_task_types
    """
    # NOTE TO IMPLEMENTER:
    # Read backend/app/task_recommendation.py lines 1662-1801 carefully.
    # Copy the EXACT logic from _build_user_preference_vector.
    # The function reads UserPreferences (task_types, locations, task_levels, keywords)
    # and enriches from TaskHistory + UserTaskInteraction data.
    #
    # After Task 7 (model merge), this will read from UserProfilePreference instead.
    # For now, keep reading from UserPreferences for backward compatibility.
    raise NotImplementedError("Extract from task_recommendation.py:1662-1801")


def get_user_preferences(db: Session, user_id: str):
    """Load user preferences from database."""
    from app.models import UserPreferences
    return db.query(UserPreferences).filter_by(user_id=user_id).first()


def get_user_task_history(db: Session, user_id: str, limit: int = 50):
    """Load recent task history."""
    from app.models import TaskHistory
    return (db.query(TaskHistory)
            .filter_by(user_id=user_id)
            .order_by(TaskHistory.created_at.desc())
            .limit(limit)
            .all())
```

**IMPORTANT:** The implementer MUST read `task_recommendation.py` lines 1662-1801 and extract the complete logic. The stub above shows the interface; the body must replicate the original exactly.

- [ ] **Step 2: Create content_scorer.py**

Extract `_content_based_recommend` (lines 320-432) and `_calculate_content_match_score` (lines 1803-1851).

```python
# backend/app/recommendation/scorers/content_scorer.py
"""Content-based recommendation scorer."""
import logging
from typing import Dict, List, Any

from ..base_scorer import BaseScorer, ScoredTask
from ..user_vector import build_user_preference_vector, get_user_preferences, get_user_task_history

logger = logging.getLogger(__name__)


class ContentScorer(BaseScorer):
    """Scores tasks by matching against user preference vector.

    Scoring weights (sub-weights within this scorer):
    - Task type match: 0.3
    - Location match: 0.25
    - Price range match: 0.2
    - Task level match: 0.15
    - Keyword match: 0.1
    - Negative feedback penalty: -0.1 (applied first)
    """
    name = "content"
    default_weight = 0.30

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        db = context["db"]

        # Build user preference vector
        preferences = get_user_preferences(db, user.id)
        history = get_user_task_history(db, user.id)
        user_vector = build_user_preference_vector(db, user, preferences, history)

        results = {}
        for task in tasks:
            score = self._calculate_content_match(user_vector, task)
            if score > 0:
                reason = self._generate_reason(user_vector, task)
                results[task.id] = ScoredTask(score=score, reason=reason)

        return results

    def _calculate_content_match(self, user_vector: dict, task) -> float:
        """Calculate content match score. Extract from task_recommendation.py:1803-1851."""
        # NOTE TO IMPLEMENTER:
        # Read backend/app/task_recommendation.py lines 1803-1851.
        # Copy the EXACT scoring logic from _calculate_content_match_score.
        raise NotImplementedError("Extract from task_recommendation.py:1803-1851")

    def _generate_reason(self, user_vector: dict, task) -> str:
        """Generate human-readable recommendation reason."""
        reasons = []
        if task.task_type in (user_vector.get("task_types") or []):
            reasons.append(f"匹配您偏好的任务类型")
        if reasons:
            return "；".join(reasons)
        return "内容匹配"
```

- [ ] **Step 3: Create collaborative_scorer.py**

Extract `_collaborative_filtering_recommend` (lines 434-532), `_find_similar_users` (line 1866), `_get_user_liked_tasks` (line 1913).

```python
# backend/app/recommendation/scorers/collaborative_scorer.py
"""Collaborative filtering recommendation scorer."""
import logging
from typing import Dict, List, Any

from ..base_scorer import BaseScorer, ScoredTask

logger = logging.getLogger(__name__)


class CollaborativeScorer(BaseScorer):
    """Scores tasks using collaborative filtering (Jaccard similarity).

    Finds users with similar interaction patterns and recommends
    tasks they liked but the current user hasn't seen.

    Falls back to empty results if user has < 3 interactions.
    """
    name = "collaborative"
    default_weight = 0.25

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        # NOTE TO IMPLEMENTER:
        # Read backend/app/task_recommendation.py lines 434-532.
        # Copy the EXACT logic from _collaborative_filtering_recommend.
        # Key functions to also extract:
        #   _find_similar_users (line 1866) - Jaccard similarity
        #   _get_user_liked_tasks (line 1913) - get tasks liked by similar users
        # Return empty dict if user has < 3 interactions (fallback handled by engine).
        raise NotImplementedError("Extract from task_recommendation.py:434-532")
```

- [ ] **Step 4: Create location_scorer.py**

Extract `_location_based_recommend` (lines 904-1108), `_get_user_frequent_locations` (line 997), `_get_user_preferred_cities` (line 1053).

```python
# backend/app/recommendation/scorers/location_scorer.py
"""Location-based recommendation scorer."""
import logging
from typing import Dict, List, Any

from ..base_scorer import BaseScorer, ScoredTask
from ..utils import haversine_distance

logger = logging.getLogger(__name__)


class LocationScorer(BaseScorer):
    """Scores tasks by geographic proximity.

    Uses: user residence_city, frequent locations, preferred cities, GPS coordinates.
    Score range: 0.5-1.0 based on distance.
    Distance scoring:
      ≤ 10km: score = 1.0 - (distance / 10000)
      > 10km: score = 0.5
      No GPS: score = 0.8 (fallback to city match)
    """
    name = "location"
    default_weight = 0.10

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        # NOTE TO IMPLEMENTER:
        # Read backend/app/task_recommendation.py lines 904-1108.
        # Copy the EXACT logic from _location_based_recommend.
        # Use context["latitude"] and context["longitude"] for GPS coords.
        # Also extract:
        #   _get_user_frequent_locations (line 997)
        #   _get_user_preferred_cities (line 1053)
        raise NotImplementedError("Extract from task_recommendation.py:904-1108")
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/recommendation/user_vector.py backend/app/recommendation/scorers/
git commit -m "feat: extract content, collaborative, location scorers from monolith"
```

---

## Task 5: Extract remaining scorers (social, time, popularity, newness)

**Files:**
- Create: `backend/app/recommendation/scorers/social_scorer.py`
- Create: `backend/app/recommendation/scorers/time_scorer.py`
- Create: `backend/app/recommendation/scorers/popularity_scorer.py`
- Create: `backend/app/recommendation/scorers/newness_scorer.py`
- Read: `backend/app/task_recommendation.py` lines 1110-1498

- [ ] **Step 1: Create social_scorer.py**

```python
# backend/app/recommendation/scorers/social_scorer.py
"""Social-based recommendation scorer."""
import logging
from typing import Dict, List, Any

from ..base_scorer import BaseScorer, ScoredTask

logger = logging.getLogger(__name__)


class SocialScorer(BaseScorer):
    """Scores tasks posted by socially relevant users.

    Three sub-strategies:
    1. School users (same university, weight 0.4)
    2. High-rated users (avg_rating ≥ 4.5, completed ≥ 5, weight 0.3)
    3. Local high-rated users (same city, rating ≥ 4.0, completed ≥ 3, weight 0.3)
    """
    name = "social"
    default_weight = 0.15

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        # NOTE TO IMPLEMENTER:
        # Read backend/app/task_recommendation.py lines 1110-1261.
        # Copy the EXACT logic from _social_based_recommend.
        raise NotImplementedError("Extract from task_recommendation.py:1110-1261")
```

- [ ] **Step 2: Create time_scorer.py**

```python
# backend/app/recommendation/scorers/time_scorer.py
"""Time-based recommendation scorer."""
import logging
from typing import Dict, List, Any

from ..base_scorer import BaseScorer, ScoredTask

logger = logging.getLogger(__name__)


class TimeScorer(BaseScorer):
    """Scores tasks by deadline proximity and user activity patterns.

    Base score: 0.7 for all future-deadline tasks.
    Bonuses: +0.2 deadline in active hours, +0.1 active day,
             +0.1 currently active, +0.2 deadline < 24h, +0.1 deadline 24-72h.
    Max capped at 1.0.
    """
    name = "time"
    default_weight = 0.08

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        # NOTE TO IMPLEMENTER:
        # Read backend/app/task_recommendation.py lines 1286-1357.
        # Copy the EXACT logic from _time_based_recommend.
        # Also extract _get_user_active_time_slots (line 1292).
        raise NotImplementedError("Extract from task_recommendation.py:1286-1357")
```

- [ ] **Step 3: Create popularity_scorer.py**

```python
# backend/app/recommendation/scorers/popularity_scorer.py
"""Popular tasks recommendation scorer."""
import logging
from typing import Dict, List, Any

from ..base_scorer import BaseScorer, ScoredTask

logger = logging.getLogger(__name__)


class PopularityScorer(BaseScorer):
    """Scores popular tasks (created in last 24 hours).

    Fixed score of 0.8 for all qualifying tasks.
    """
    name = "popularity"
    default_weight = 0.02

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        # NOTE TO IMPLEMENTER:
        # Read backend/app/task_recommendation.py lines 1263-1284.
        # Copy the EXACT logic from _popular_tasks_recommend.
        raise NotImplementedError("Extract from task_recommendation.py:1263-1284")
```

- [ ] **Step 4: Create newness_scorer.py**

```python
# backend/app/recommendation/scorers/newness_scorer.py
"""New task boost recommendation scorer."""
import logging
from typing import Dict, List, Any

from ..base_scorer import BaseScorer, ScoredTask
from ..utils import is_new_user

logger = logging.getLogger(__name__)


class NewnessScorer(BaseScorer):
    """Boosts recently created tasks (within 24 hours).

    Score = max(0, 1.0 - hours_old / 24).
    Extra +0.3 boost if task posted by a new user.
    """
    name = "newness"
    default_weight = 0.10

    def get_weight(self, user) -> float:
        """New users get higher newness weight."""
        if is_new_user(user):
            return 0.15
        return self.default_weight

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        # NOTE TO IMPLEMENTER:
        # Read backend/app/task_recommendation.py lines 1418-1498.
        # Copy the EXACT logic from _new_task_boost_recommend.
        raise NotImplementedError("Extract from task_recommendation.py:1418-1498")
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/recommendation/scorers/
git commit -m "feat: extract social, time, popularity, newness scorers from monolith"
```

---

## Task 6: HybridEngine — orchestrate all scorers

**Files:**
- Create: `backend/app/recommendation/engine.py`
- Test: `backend/tests/test_engine.py`
- Modify: `backend/app/task_recommendation.py` (make thin wrapper)
- Modify: `backend/app/recommendation/__init__.py` (register all scorers)

- [ ] **Step 1: Write the test**

```python
# backend/tests/test_engine.py
import pytest
from unittest.mock import MagicMock, patch
from app.recommendation.base_scorer import BaseScorer, ScoredTask
from app.recommendation.scorer_registry import ScorerRegistry
from app.recommendation.engine import HybridEngine


class FakeScorerHigh(BaseScorer):
    name = "high"
    default_weight = 0.7

    def score(self, user, tasks, context):
        return {1: ScoredTask(score=0.9, reason="high match")}


class FakeScorerLow(BaseScorer):
    name = "low"
    default_weight = 0.3

    def score(self, user, tasks, context):
        return {
            1: ScoredTask(score=0.5, reason="low match"),
            2: ScoredTask(score=0.8, reason="good match"),
        }


def test_engine_aggregates_scores():
    reg = ScorerRegistry()
    reg.register(FakeScorerHigh())
    reg.register(FakeScorerLow())

    engine = HybridEngine(registry=reg)
    # Mock _get_candidates to return fake tasks
    task1 = MagicMock(id=1)
    task2 = MagicMock(id=2)
    engine._get_candidates = lambda filters, context: [task1, task2]

    results = engine.recommend(user=None, limit=10, context={"db": None})

    # Task 1 should score: high(0.9*0.7) + low(0.5*0.3) = 0.63 + 0.15 = 0.78
    # Task 2 should score: low(0.8*0.3) = 0.24
    # But after normalization, weights are 0.7 and 0.3 (already sum to 1.0)
    assert len(results) == 2
    assert results[0]["task_id"] == 1  # Higher score first
    assert results[0]["score"] > results[1]["score"]


def test_engine_respects_limit():
    reg = ScorerRegistry()
    reg.register(FakeScorerLow())

    engine = HybridEngine(registry=reg)
    engine._get_candidates = lambda filters, context: [MagicMock(id=i) for i in range(100)]

    results = engine.recommend(user=None, limit=5, context={"db": None})
    assert len(results) <= 5


def test_engine_empty_scorers():
    reg = ScorerRegistry()
    engine = HybridEngine(registry=reg)
    engine._get_candidates = lambda filters, context: [MagicMock(id=1)]

    results = engine.recommend(user=None, limit=10, context={"db": None})
    assert len(results) == 0
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd backend && python -m pytest tests/test_engine.py -v
```

Expected: FAIL — `ModuleNotFoundError`

- [ ] **Step 3: Implement HybridEngine**

```python
# backend/app/recommendation/engine.py
"""HybridEngine: orchestrates all scorers and aggregates results."""
import logging
from typing import List, Dict, Any, Optional

from .scorer_registry import ScorerRegistry

logger = logging.getLogger(__name__)


class HybridEngine:
    """Recommendation engine that orchestrates pluggable scorers.

    Usage:
        registry = ScorerRegistry()
        registry.register(ContentScorer())
        registry.register(ProfileScorer())
        engine = HybridEngine(registry=registry)
        results = engine.recommend(user=user, limit=20, context={"db": db})
    """

    def __init__(self, registry: ScorerRegistry):
        self.registry = registry

    def recommend(
        self,
        user,
        limit: int = 20,
        context: Optional[Dict[str, Any]] = None,
        filters: Optional[Dict[str, Any]] = None,
    ) -> List[Dict]:
        """Run all scorers, aggregate weighted scores, return top N recommendations.

        Args:
            user: SQLAlchemy User object (or None for anonymous)
            limit: Max results to return
            context: Shared context (must include "db" key with SQLAlchemy Session)
            filters: Optional task filters (task_type, location, keyword)

        Returns:
            List of dicts: [{"task_id": int, "score": float, "reasons": [str], "task": Task}]
        """
        context = context or {}
        filters = filters or {}

        candidate_tasks = self._get_candidates(filters, context)
        if not candidate_tasks:
            return []

        # Get normalized weights
        weights = self.registry.normalize_weights(user)

        # Aggregate scores from all scorers
        aggregated: Dict[int, Dict] = {}
        task_map = {t.id: t for t in candidate_tasks}

        for scorer in self.registry.get_active_scorers():
            weight = weights.get(scorer.name, 0)
            if weight <= 0:
                continue

            try:
                results = scorer.score(user, candidate_tasks, context)
                for task_id, scored in results.items():
                    if task_id not in aggregated:
                        aggregated[task_id] = {"score": 0.0, "reasons": []}
                    aggregated[task_id]["score"] += scored.clamped_score * weight
                    if scored.reason:
                        aggregated[task_id]["reasons"].append(scored.reason)
            except Exception as e:
                logger.error(f"Scorer {scorer.name} failed: {e}", exc_info=True)
                continue

        # Sort by score descending, take top N
        ranked = sorted(aggregated.items(), key=lambda x: x[1]["score"], reverse=True)

        return [
            {
                "task_id": task_id,
                "score": round(data["score"], 4),
                "reasons": data["reasons"],
                "task": task_map.get(task_id),
            }
            for task_id, data in ranked[:limit]
            if task_map.get(task_id) is not None
        ]

    def _get_candidates(self, filters: Dict, context: Dict) -> List:
        """Get candidate tasks from database.

        Reuses existing filtering: active tasks, not completed, within deadline.
        Default pool: 500 most recent eligible tasks.
        """
        db = context.get("db")
        if not db:
            return []

        from app.models import Task
        from app.crud import get_utc_time

        query = db.query(Task).filter(
            Task.status == "open",
            Task.is_visible == True,
            Task.deadline > get_utc_time(),
        )

        # Apply filters
        if filters.get("task_type"):
            query = query.filter(Task.task_type == filters["task_type"])
        if filters.get("location"):
            query = query.filter(Task.location.ilike(f"%{filters['location']}%"))
        if filters.get("keyword"):
            kw = f"%{filters['keyword']}%"
            query = query.filter(
                (Task.title.ilike(kw)) | (Task.description.ilike(kw)) |
                (Task.title_zh.ilike(kw)) | (Task.title_en.ilike(kw))
            )

        return query.order_by(Task.created_at.desc()).limit(500).all()
```

- [ ] **Step 4: Update `__init__.py` to register all scorers**

```python
# backend/app/recommendation/__init__.py
"""Task recommendation engine with pluggable scorer architecture."""
from .engine import HybridEngine
from .scorer_registry import ScorerRegistry
from .base_scorer import BaseScorer, ScoredTask


def create_engine() -> HybridEngine:
    """Create and configure the recommendation engine with all scorers."""
    from .scorers.content_scorer import ContentScorer
    from .scorers.collaborative_scorer import CollaborativeScorer
    from .scorers.location_scorer import LocationScorer
    from .scorers.social_scorer import SocialScorer
    from .scorers.time_scorer import TimeScorer
    from .scorers.popularity_scorer import PopularityScorer
    from .scorers.newness_scorer import NewnessScorer

    registry = ScorerRegistry()
    registry.register(ContentScorer())
    registry.register(CollaborativeScorer())
    registry.register(LocationScorer())
    registry.register(SocialScorer())
    registry.register(TimeScorer())
    registry.register(PopularityScorer())
    registry.register(NewnessScorer())

    return HybridEngine(registry=registry)
```

- [ ] **Step 5: Run tests**

```bash
cd backend && python -m pytest tests/test_engine.py -v
```

Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add backend/app/recommendation/ backend/tests/test_engine.py
git commit -m "feat: add HybridEngine with scorer orchestration and candidate selection"
```

---

## Task 7: Database migration — merge UserPreferences into UserProfilePreference

**Files:**
- Create: `backend/alembic/versions/xxxx_merge_user_preferences.py`
- Modify: `backend/app/models.py:3547-3567` (add new columns to UserProfilePreference)
- Modify: `backend/app/recommendation/user_vector.py` (read from merged model)

- [ ] **Step 1: Add new columns to UserProfilePreference model**

Read `backend/app/models.py` lines 3547-3567 (UserProfilePreference) and lines 869-891 (UserPreferences).

Add to `UserProfilePreference` class:

```python
# Add after existing columns in UserProfilePreference (models.py around line 3559)
    # Migrated from UserPreferences
    task_types = Column(JSON, nullable=True)          # Previously Text in UserPreferences
    locations = Column(JSON, nullable=True)            # Previously Text in UserPreferences
    task_levels = Column(JSON, nullable=True)          # Previously Text in UserPreferences
    keywords = Column(JSON, nullable=True)             # Previously Text in UserPreferences
    min_deadline_days = Column(Integer, default=1)     # From UserPreferences
```

- [ ] **Step 2: Create Alembic migration**

```bash
cd backend && alembic revision --autogenerate -m "merge user_preferences into user_profile_preferences"
```

Then edit the generated migration to add data migration logic:

```python
# In the generated migration's upgrade() function, after adding columns:
def upgrade():
    # Step 1: Add columns
    op.add_column('user_profile_preferences', sa.Column('task_types', sa.JSON(), nullable=True))
    op.add_column('user_profile_preferences', sa.Column('locations', sa.JSON(), nullable=True))
    op.add_column('user_profile_preferences', sa.Column('task_levels', sa.JSON(), nullable=True))
    op.add_column('user_profile_preferences', sa.Column('keywords', sa.JSON(), nullable=True))
    op.add_column('user_profile_preferences', sa.Column('min_deadline_days', sa.Integer(), nullable=True, server_default='1'))

    # Step 2: Data migration — copy from user_preferences
    connection = op.get_bind()
    rows = connection.execute(sa.text(
        "SELECT user_id, task_types, locations, task_levels, keywords, min_deadline_days "
        "FROM user_preferences"
    )).fetchall()

    for row in rows:
        user_id = row[0]
        # Parse Text→JSON (handle malformed data)
        import json
        def safe_parse(val):
            if not val:
                return None
            try:
                return json.loads(val) if isinstance(val, str) else val
            except (json.JSONDecodeError, TypeError):
                return None

        task_types = safe_parse(row[1])
        locations = safe_parse(row[2])
        task_levels = safe_parse(row[3])
        keywords = safe_parse(row[4])
        min_deadline_days = row[5]

        # Upsert: only set if target doesn't already have data
        connection.execute(sa.text("""
            UPDATE user_profile_preferences
            SET task_types = COALESCE(task_types, :task_types),
                locations = COALESCE(locations, :locations),
                task_levels = COALESCE(task_levels, :task_levels),
                keywords = COALESCE(keywords, :keywords),
                min_deadline_days = COALESCE(min_deadline_days, :min_deadline_days)
            WHERE user_id = :user_id
        """), {
            "user_id": user_id,
            "task_types": json.dumps(task_types) if task_types else None,
            "locations": json.dumps(locations) if locations else None,
            "task_levels": json.dumps(task_levels) if task_levels else None,
            "keywords": json.dumps(keywords) if keywords else None,
            "min_deadline_days": min_deadline_days,
        })

        # If user has no UserProfilePreference row yet, insert one
        existing = connection.execute(sa.text(
            "SELECT 1 FROM user_profile_preferences WHERE user_id = :uid"
        ), {"uid": user_id}).fetchone()
        if not existing:
            connection.execute(sa.text("""
                INSERT INTO user_profile_preferences (user_id, task_types, locations, task_levels, keywords, min_deadline_days)
                VALUES (:user_id, :task_types, :locations, :task_levels, :keywords, :min_deadline_days)
            """), {
                "user_id": user_id,
                "task_types": json.dumps(task_types) if task_types else None,
                "locations": json.dumps(locations) if locations else None,
                "task_levels": json.dumps(task_levels) if task_levels else None,
                "keywords": json.dumps(keywords) if keywords else None,
                "min_deadline_days": min_deadline_days,
            })

    # Step 3: Do NOT drop user_preferences yet (keep for rollback safety)
```

- [ ] **Step 3: Run migration**

```bash
cd backend && alembic upgrade head
```

- [ ] **Step 4: Update user_vector.py to read from merged model**

Update `get_user_preferences()` in `user_vector.py` to read from `UserProfilePreference` instead of `UserPreferences`.

- [ ] **Step 5: Update routers.py — /user-preferences endpoints**

Read `backend/app/routers.py` around line 10370. Update `GET /user-preferences` and `POST /user-preferences` to read/write `UserProfilePreference` instead of `UserPreferences`.

- [ ] **Step 6: Search and replace remaining UserPreferences references**

```bash
cd backend && grep -rn "UserPreferences" app/ --include="*.py" | grep -v "__pycache__"
```

Update all remaining references to use `UserProfilePreference`.

- [ ] **Step 7: Commit**

```bash
git add backend/app/models.py backend/alembic/ backend/app/recommendation/user_vector.py backend/app/routers.py
git commit -m "feat: merge UserPreferences into UserProfilePreference with data migration"
```

---

## Task 8: profile_scorer — new scorer for user profile matching

**Files:**
- Create: `backend/app/recommendation/scorers/profile_scorer.py`
- Test: `backend/tests/test_profile_scorer.py`
- Modify: `backend/app/recommendation/__init__.py` (register new scorer)

- [ ] **Step 1: Write the test**

```python
# backend/tests/test_profile_scorer.py
import pytest
from unittest.mock import MagicMock
from app.recommendation.scorers.profile_scorer import ProfileScorer
from app.recommendation.base_scorer import ScoredTask


def _make_task(task_id, task_type="translation", location="London", reward=50,
               deadline=None, is_flexible=False):
    task = MagicMock()
    task.id = task_id
    task.task_type = task_type
    task.location = location
    task.reward = reward
    task.deadline = deadline
    task.is_flexible = is_flexible
    task.description = ""
    task.description_zh = ""
    return task


def _make_pref(mode="both", duration_type="both", preferred_categories=None,
               preferred_time_slots=None, reward_preference="no_preference", city=None):
    pref = MagicMock()
    pref.mode = MagicMock()
    pref.mode.value = mode
    pref.duration_type = MagicMock()
    pref.duration_type.value = duration_type
    pref.preferred_categories = preferred_categories or []
    pref.preferred_time_slots = preferred_time_slots or []
    pref.reward_preference = MagicMock()
    pref.reward_preference.value = reward_preference
    pref.city = city
    return pref


def test_category_match_scores_high():
    scorer = ProfileScorer()
    task = _make_task(1, task_type="translation")
    pref = _make_pref(preferred_categories=["translation", "tutoring"])

    db = MagicMock()
    db.query.return_value.filter_by.return_value.first.return_value = pref
    context = {"db": db}
    user = MagicMock(id="u1")

    results = scorer.score(user, [task], context)
    assert 1 in results
    assert results[1].score > 0


def test_no_preference_gives_neutral_score():
    scorer = ProfileScorer()
    task = _make_task(1)
    pref = _make_pref()  # all "both" / "no_preference"

    db = MagicMock()
    db.query.return_value.filter_by.return_value.first.return_value = pref
    context = {"db": db}
    user = MagicMock(id="u1")

    results = scorer.score(user, [task], context)
    # "both" mode means match everything → should still produce some score
    if 1 in results:
        assert results[1].score >= 0


def test_city_match_boosts_score():
    scorer = ProfileScorer()
    task = _make_task(1, location="London, UK")
    pref = _make_pref(city="London")

    db = MagicMock()
    db.query.return_value.filter_by.return_value.first.return_value = pref
    context = {"db": db}
    user = MagicMock(id="u1")

    results = scorer.score(user, [task], context)
    assert 1 in results
    assert results[1].score > 0


def test_no_pref_returns_empty():
    scorer = ProfileScorer()
    task = _make_task(1)

    db = MagicMock()
    db.query.return_value.filter_by.return_value.first.return_value = None
    context = {"db": db}
    user = MagicMock(id="u1")

    results = scorer.score(user, [task], context)
    assert len(results) == 0
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd backend && python -m pytest tests/test_profile_scorer.py -v
```

Expected: FAIL

- [ ] **Step 3: Implement profile_scorer**

```python
# backend/app/recommendation/scorers/profile_scorer.py
"""Profile preference matching scorer."""
import logging
from typing import Dict, List, Any

from ..base_scorer import BaseScorer, ScoredTask

logger = logging.getLogger(__name__)


class ProfileScorer(BaseScorer):
    """Scores tasks by matching against user profile preferences.

    Sub-weights:
    - mode (online/offline) inference: 0.10
    - duration_type inference: 0.10
    - preferred_time_slots: 0.20
    - preferred_categories: 0.30
    - reward_preference: 0.15
    - city: 0.15
    """
    name = "profile"
    default_weight = 0.10

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        db = context["db"]
        from app.models import UserProfilePreference

        pref = db.query(UserProfilePreference).filter_by(user_id=user.id).first()
        if not pref:
            return {}

        results = {}
        for task in tasks:
            score, reasons = self._score_task(pref, task)
            if score > 0:
                results[task.id] = ScoredTask(
                    score=min(1.0, score),
                    reason="；".join(reasons) if reasons else "画像匹配"
                )
        return results

    def _score_task(self, pref, task) -> tuple:
        """Score a single task against user preferences."""
        score = 0.0
        reasons = []

        # 1. Mode matching (0.10) — infer from task location
        mode = pref.mode.value if pref.mode else "both"
        if mode == "both":
            score += 0.10
        else:
            task_is_online = not task.location or task.location.strip() == ""
            if (mode == "online" and task_is_online) or (mode == "offline" and not task_is_online):
                score += 0.10
                reasons.append("匹配您的协作方式偏好")

        # 2. Duration type matching (0.10) — infer from task flexibility
        dur = pref.duration_type.value if pref.duration_type else "both"
        if dur == "both":
            score += 0.10
        else:
            task_is_long = getattr(task, 'is_flexible', False)
            if (dur == "long_term" and task_is_long) or (dur == "one_time" and not task_is_long):
                score += 0.10

        # 3. Preferred time slots (0.20)
        slots = pref.preferred_time_slots or []
        if not slots or "anytime" in slots:
            score += 0.20
        elif task.deadline:
            hour = task.deadline.hour
            weekday = task.deadline.weekday()
            matched = False
            if "weekday_daytime" in slots and weekday < 5 and 8 <= hour < 18:
                matched = True
            if "weekday_evening" in slots and weekday < 5 and hour >= 18:
                matched = True
            if "weekend" in slots and weekday >= 5:
                matched = True
            if matched:
                score += 0.20
                reasons.append("匹配您的可用时段")

        # 4. Preferred categories (0.30)
        categories = pref.preferred_categories or []
        if not categories:
            score += 0.15  # No preference — partial score
        elif task.task_type in categories:
            score += 0.30
            reasons.append(f"匹配您偏好的任务类型")

        # 5. Reward preference (0.15)
        rew = pref.reward_preference.value if pref.reward_preference else "no_preference"
        if rew == "no_preference":
            score += 0.15
        else:
            reward = float(task.reward or 0)
            if rew == "high_freq_low_amount" and reward <= 3000:  # ≤£30 (in pence)
                score += 0.15
            elif rew == "low_freq_high_amount" and reward > 3000:
                score += 0.15
                reasons.append("匹配您的报酬偏好")

        # 6. City matching (0.15)
        if not pref.city:
            score += 0.075  # No city preference — partial score
        elif task.location and pref.city.lower() in task.location.lower():
            score += 0.15
            reasons.append(f"位于您所在的城市")

        return score, reasons
```

- [ ] **Step 4: Register in `__init__.py`**

Add to `create_engine()`:

```python
    from .scorers.profile_scorer import ProfileScorer
    registry.register(ProfileScorer())
```

- [ ] **Step 5: Run tests**

```bash
cd backend && python -m pytest tests/test_profile_scorer.py -v
```

Expected: PASS (4 tests)

- [ ] **Step 6: Commit**

```bash
git add backend/app/recommendation/scorers/profile_scorer.py backend/tests/test_profile_scorer.py backend/app/recommendation/__init__.py
git commit -m "feat: add profile_scorer for user preference matching in recommendations"
```

---

## Task 9: demand_scorer — AI demand prediction matching

**Files:**
- Create: `backend/app/recommendation/scorers/demand_scorer.py`
- Test: `backend/tests/test_demand_scorer.py`
- Modify: `backend/app/recommendation/__init__.py` (register new scorer)

- [ ] **Step 1: Write the test**

```python
# backend/tests/test_demand_scorer.py
import pytest
from unittest.mock import MagicMock
from app.recommendation.scorers.demand_scorer import DemandScorer


def _make_task(task_id, task_type="translation", title="Help translate",
               description="Need English translation"):
    task = MagicMock()
    task.id = task_id
    task.task_type = task_type
    task.title = title
    task.title_zh = title
    task.description = description
    task.description_zh = description
    return task


def _make_demand(predicted_needs=None, inferred_skills=None,
                 inferred_preferences=None, recent_interests=None):
    demand = MagicMock()
    demand.predicted_needs = predicted_needs or []
    demand.inferred_skills = inferred_skills or {}
    demand.inferred_preferences = inferred_preferences or {}
    demand.recent_interests = recent_interests or {}
    return demand


def test_predicted_needs_match():
    scorer = DemandScorer()
    task = _make_task(1, task_type="translation")
    demand = _make_demand(predicted_needs=["translation", "tutoring"])

    db = MagicMock()
    db.query.return_value.filter_by.return_value.first.return_value = demand
    # Mock interaction count
    db.query.return_value.filter.return_value.count.return_value = 5

    context = {"db": db}
    user = MagicMock(id="u1")

    results = scorer.score(user, [task], context)
    assert 1 in results
    assert results[1].score > 0


def test_no_demand_returns_empty():
    scorer = DemandScorer()
    task = _make_task(1)

    db = MagicMock()
    db.query.return_value.filter_by.return_value.first.return_value = None
    context = {"db": db}
    user = MagicMock(id="u1")

    results = scorer.score(user, [task], context)
    assert len(results) == 0


def test_smart_weight_new_user():
    scorer = DemandScorer()
    db = MagicMock()
    db.query.return_value.filter.return_value.count.return_value = 5  # < 10

    user = MagicMock(id="u1")
    # Need to set up the scorer to access db for interaction count
    weight = scorer.get_weight(user)
    # Default weight without db context
    assert weight == scorer.default_weight  # Falls back to default


def test_inferred_skills_match():
    scorer = DemandScorer()
    task = _make_task(1, task_type="translation", description="需要翻译技能")
    demand = _make_demand(
        inferred_skills={"translation": 0.8, "writing": 0.6}
    )

    db = MagicMock()
    db.query.return_value.filter_by.return_value.first.return_value = demand
    db.query.return_value.filter.return_value.count.return_value = 5
    context = {"db": db}
    user = MagicMock(id="u1")

    results = scorer.score(user, [task], context)
    assert 1 in results
    assert results[1].score > 0
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd backend && python -m pytest tests/test_demand_scorer.py -v
```

Expected: FAIL

- [ ] **Step 3: Implement demand_scorer**

```python
# backend/app/recommendation/scorers/demand_scorer.py
"""AI demand prediction matching scorer."""
import logging
from typing import Dict, List, Any

from ..base_scorer import BaseScorer, ScoredTask

logger = logging.getLogger(__name__)


class DemandScorer(BaseScorer):
    """Scores tasks by matching against AI-inferred user demand predictions.

    Sub-weights:
    - predicted_needs match: 0.35
    - inferred_skills match: 0.30
    - inferred_preferences match: 0.20
    - recent_interests match: 0.15

    Dynamic weight: decreases as user accumulates more interactions
    (from 0.20 for new users to 0.05 for mature users).
    """
    name = "demand"
    default_weight = 0.12  # Middle tier default

    def get_weight(self, user) -> float:
        """Dynamic weight based on user interaction count.

        New users (<10 interactions): 0.20 (AI inference weight high)
        Moderate users (10-50): 0.12
        Mature users (50+): 0.05 (behavioral data is sufficient)
        """
        # Note: interaction_count may be cached on user object or set by engine
        count = getattr(user, '_interaction_count', None)
        if count is None:
            return self.default_weight
        if count < 10:
            return 0.20
        elif count < 50:
            return 0.12
        else:
            return 0.05

    def score(self, user, tasks: List, context: Dict[str, Any]) -> Dict[int, ScoredTask]:
        db = context["db"]
        from app.models import UserDemand, UserTaskInteraction

        demand = db.query(UserDemand).filter_by(user_id=user.id).first()
        if not demand:
            return {}

        # Cache interaction count on user for get_weight
        try:
            count = db.query(UserTaskInteraction).filter(
                UserTaskInteraction.user_id == user.id
            ).count()
            user._interaction_count = count
        except Exception:
            pass

        results = {}
        for task in tasks:
            score, reasons = self._score_task(demand, task)
            if score > 0:
                results[task.id] = ScoredTask(
                    score=min(1.0, score),
                    reason="；".join(reasons) if reasons else "AI预测匹配"
                )
        return results

    def _score_task(self, demand, task) -> tuple:
        """Score a single task against AI demand predictions."""
        score = 0.0
        reasons = []

        # 1. Predicted needs (0.35)
        predicted = demand.predicted_needs or []
        if isinstance(predicted, dict):
            predicted = list(predicted.keys())
        if predicted and task.task_type in predicted:
            score += 0.35
            reasons.append("匹配您的预测需求")

        # 2. Inferred skills (0.30)
        skills = demand.inferred_skills or {}
        if isinstance(skills, list):
            skills = {s: 1.0 for s in skills}
        if skills:
            # Check if task type or keywords match any inferred skill
            task_text = f"{task.task_type} {task.title or ''} {task.description or ''}".lower()
            matched_skills = [s for s in skills if s.lower() in task_text]
            if matched_skills:
                # Weight by skill confidence
                max_conf = max(skills.get(s, 0.5) for s in matched_skills)
                score += 0.30 * min(1.0, max_conf)
                reasons.append(f"匹配您的技能：{', '.join(matched_skills[:2])}")

        # 3. Inferred preferences (0.20)
        inf_prefs = demand.inferred_preferences or {}
        if inf_prefs:
            # Check if task type matches inferred preference categories
            pref_cats = inf_prefs.get("categories", [])
            if task.task_type in pref_cats:
                score += 0.20

        # 4. Recent interests (0.15)
        interests = demand.recent_interests or {}
        if isinstance(interests, list):
            interests = {i: 1.0 for i in interests}
        if interests:
            task_text = f"{task.task_type} {task.title or ''} {task.description or ''}".lower()
            matched = [k for k in interests if k.lower() in task_text]
            if matched:
                score += 0.15
                reasons.append("匹配您的近期兴趣")

        return score, reasons
```

- [ ] **Step 4: Register in `__init__.py`**

Add to `create_engine()`:

```python
    from .scorers.demand_scorer import DemandScorer
    registry.register(DemandScorer())
```

- [ ] **Step 5: Run tests**

```bash
cd backend && python -m pytest tests/test_demand_scorer.py -v
```

Expected: PASS (4 tests)

- [ ] **Step 6: Commit**

```bash
git add backend/app/recommendation/scorers/demand_scorer.py backend/tests/test_demand_scorer.py backend/app/recommendation/__init__.py
git commit -m "feat: add demand_scorer for AI prediction matching with smart weight switching"
```

---

## Task 10: Make task_recommendation.py a thin wrapper

**Files:**
- Modify: `backend/app/task_recommendation.py` (add wrapper at top, keep old code for feature flag)

- [ ] **Step 1: Add feature flag and wrapper**

At the top of `backend/app/task_recommendation.py`, add a feature flag that delegates to the new engine:

```python
# Add near the top of task_recommendation.py, after imports (around line 20)
import os

USE_NEW_ENGINE = os.environ.get("USE_NEW_RECOMMENDATION_ENGINE", "false").lower() == "true"

# Singleton engine instance (avoid re-creating on every request)
_engine_instance = None

def _get_engine():
    global _engine_instance
    if _engine_instance is None:
        from app.recommendation import create_engine
        _engine_instance = create_engine()
    return _engine_instance


def get_task_recommendations(
    db,
    user_id,
    limit=20,
    algorithm="hybrid",
    task_type=None,
    location=None,
    keyword=None,
    latitude=None,
    longitude=None
):
    """Top-level entry point. Delegates to new or old engine based on feature flag."""
    if USE_NEW_ENGINE:
        return _new_engine_recommend(
            db, user_id, limit, algorithm, task_type, location, keyword, latitude, longitude
        )
    # Fall through to existing implementation
    return _old_engine_recommend(
        db, user_id, limit, algorithm, task_type, location, keyword, latitude, longitude
    )


def _new_engine_recommend(db, user_id, limit, algorithm, task_type, location, keyword, latitude, longitude):
    """Delegate to the new pluggable scorer engine."""
    from app.models import User

    user = db.query(User).filter_by(id=user_id).first()
    if not user:
        return []

    engine = _get_engine()
    context = {
        "db": db,
        "latitude": latitude,
        "longitude": longitude,
    }
    filters = {}
    if task_type:
        filters["task_type"] = task_type
    if location:
        filters["location"] = location
    if keyword:
        filters["keyword"] = keyword

    results = engine.recommend(user=user, limit=limit, context=context, filters=filters)

    # Convert to the existing API response format
    from app.recommendation.utils import get_excluded_task_ids
    excluded = get_excluded_task_ids(db, user_id)

    recommendations = []
    for r in results:
        task = r["task"]
        if not task or task.id in excluded:
            continue
        recommendations.append({
            "id": task.id,
            "task_id": task.id,
            "title": task.title,
            "title_en": getattr(task, "title_en", None),
            "title_zh": getattr(task, "title_zh", None),
            "description": task.description,
            "task_type": task.task_type,
            "location": task.location,
            "reward": float(task.reward) if task.reward else None,
            "base_reward": float(task.base_reward) if getattr(task, "base_reward", None) else None,
            "agreed_reward": float(task.agreed_reward) if getattr(task, "agreed_reward", None) else None,
            "reward_to_be_quoted": getattr(task, "reward_to_be_quoted", False),
            "deadline": task.deadline.isoformat() if task.deadline else None,
            "task_level": task.task_level,
            "match_score": r["score"],
            "recommendation_reason": "；".join(r["reasons"]) if r["reasons"] else "",
            "created_at": task.created_at.isoformat() if task.created_at else None,
            "images": task.images if hasattr(task, "images") else [],
        })

    return recommendations
```

Then rename the existing `get_task_recommendations` function (around line 2078) to `_old_engine_recommend`.

- [ ] **Step 2: Verify old engine still works**

```bash
cd backend && python -m pytest tests/test_task_recommendation.py -v
```

Expected: PASS (existing tests still pass with old engine)

- [ ] **Step 3: Test with feature flag on**

```bash
cd backend && USE_NEW_RECOMMENDATION_ENGINE=true python -m pytest tests/test_task_recommendation.py -v
```

Note: Some existing tests may fail because scorer implementations are stubs. This is expected — full extraction happens when implementing the `NotImplementedError` stubs in Tasks 4-5.

- [ ] **Step 4: Commit**

```bash
git add backend/app/task_recommendation.py
git commit -m "feat: add feature flag for new recommendation engine with backward-compatible wrapper"
```

---

## Task 11: AI chat — profile context injection + proactive suggestions

**IMPORTANT: async/sync context.** The AI agent (`ai_agent.py`) uses `AsyncSession` throughout. The `_PipelineContext.db` is an `AsyncSession` (line 592). All DB queries in this task MUST use async SQLAlchemy patterns: `await db.execute(select(Model).where(...))`, NOT `db.query(Model).filter_by(...)`.

The recommendation engine (`get_task_recommendations`) is synchronous. When calling it from async context, wrap with `asyncio.to_thread()`.

**Files:**
- Modify: `backend/app/services/ai_agent.py` (add profile context + proactive suggestions + inject in `_step_llm`)
- Test: `backend/tests/test_ai_profile_context.py`

- [ ] **Step 1: Write the test**

```python
# backend/tests/test_ai_profile_context.py
import pytest
from unittest.mock import MagicMock, AsyncMock
import asyncio


def test_build_user_profile_context_with_full_data():
    from app.services.ai_agent import build_user_profile_context

    db = AsyncMock()

    # Mock UserProfilePreference
    pref = MagicMock()
    pref.mode = MagicMock(value="online")
    pref.preferred_time_slots = ["weekday_evening", "weekend"]
    pref.city = "London"

    # Mock UserDemand
    demand = MagicMock()
    demand.recent_interests = {"translation": 3, "tutoring": 2}
    demand.inferred_skills = {"English": 0.9, "Writing": 0.7}
    demand.predicted_needs = ["translation"]

    # Mock UserReliability
    reliability = MagicMock()
    reliability.reliability_score = 0.85

    # Set up async db.execute to return different models
    async def execute_side_effect(stmt):
        result = MagicMock()
        stmt_str = str(stmt)
        if 'user_profile_preference' in stmt_str.lower():
            result.scalars.return_value.first.return_value = pref
        elif 'user_demand' in stmt_str.lower():
            result.scalars.return_value.first.return_value = demand
        elif 'user_reliability' in stmt_str.lower():
            result.scalars.return_value.first.return_value = reliability
        else:
            result.scalars.return_value.first.return_value = None
        return result

    db.execute.side_effect = execute_side_effect

    result = asyncio.run(build_user_profile_context("u1", db))
    assert "用户画像" in result
    assert "London" in result
    assert "translation" in result


def test_build_user_profile_context_no_data():
    from app.services.ai_agent import build_user_profile_context

    db = AsyncMock()
    null_result = MagicMock()
    null_result.scalars.return_value.first.return_value = None
    db.execute.return_value = null_result

    result = asyncio.run(build_user_profile_context("u1", db))
    assert result == ""
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd backend && python -m pytest tests/test_ai_profile_context.py -v
```

Expected: FAIL — `ImportError` (function doesn't exist yet)

- [ ] **Step 3: Add `build_user_profile_context` (async) to ai_agent.py**

Add to `backend/app/services/ai_agent.py`:

```python
async def build_user_profile_context(user_id: str, db) -> str:
    """Build a user profile summary for AI system prompt injection.

    Uses async SQLAlchemy queries (db is AsyncSession).
    Reads UserProfilePreference, UserDemand, UserReliability.
    """
    from sqlalchemy import select
    from app.models import UserProfilePreference, UserDemand, UserReliability

    try:
        pref_result = await db.execute(
            select(UserProfilePreference).where(UserProfilePreference.user_id == user_id)
        )
        pref = pref_result.scalars().first()
        demand_result = await db.execute(
            select(UserDemand).where(UserDemand.user_id == user_id)
        )
        demand = demand_result.scalars().first()
        reliability_result = await db.execute(
            select(UserReliability).where(UserReliability.user_id == user_id)
        )
        reliability = reliability_result.scalars().first()
    except Exception as e:
        logger.warning(f"Failed to load user profile for AI context: {e}")
        return ""

    sections = []
    if pref:
        mode_val = pref.mode.value if pref.mode else "不限"
        sections.append(f"- 偏好模式: {mode_val}")
        if pref.preferred_time_slots:
            sections.append(f"- 可用时段: {', '.join(pref.preferred_time_slots)}")
        if pref.city:
            sections.append(f"- 所在城市: {pref.city}")
    if demand:
        if demand.recent_interests:
            interests = demand.recent_interests
            if isinstance(interests, dict):
                interests = list(interests.keys())
            sections.append(f"- 兴趣领域: {', '.join(str(i) for i in interests[:5])}")
        if demand.inferred_skills:
            skills = demand.inferred_skills
            if isinstance(skills, dict):
                skills = list(skills.keys())
            sections.append(f"- 推断技能: {', '.join(str(s) for s in skills[:5])}")
        if demand.predicted_needs:
            needs = demand.predicted_needs
            if isinstance(needs, dict):
                needs = list(needs.keys())
            sections.append(f"- 预测需求: {', '.join(str(n) for n in needs[:5])}")
    if reliability:
        sections.append(f"- 可靠度评分: {reliability.reliability_score}")

    if sections:
        return "用户画像:\n" + "\n".join(sections)
    return ""
```

- [ ] **Step 4: Add `get_proactive_suggestions` (async) to ai_agent.py**

```python
async def get_proactive_suggestions(user_id: str, db) -> str:
    """Check for high-match tasks (>0.8 score, last 24h) for proactive AI suggestion.

    Calls the sync recommendation engine via asyncio.to_thread().
    """
    import asyncio
    from datetime import datetime, timedelta
    from app.crud import get_utc_time

    try:
        from app.task_recommendation import get_task_recommendations
        from app.database import get_sync_db

        def _get_recs():
            sync_db = next(get_sync_db())
            try:
                return get_task_recommendations(
                    db=sync_db, user_id=user_id, limit=5, algorithm="hybrid"
                )
            finally:
                sync_db.close()

        recs = await asyncio.to_thread(_get_recs)
        cutoff = get_utc_time() - timedelta(hours=24)
        high_matches = []
        for rec in recs:
            score = rec.get("match_score", 0)
            created = rec.get("created_at")
            if score >= 0.8 and created:
                if isinstance(created, str):
                    try:
                        created = datetime.fromisoformat(created.replace("Z", "+00:00"))
                    except ValueError:
                        continue
                if created >= cutoff:
                    high_matches.append({
                        "title": rec.get("title_zh") or rec.get("title") or "",
                        "reason": rec.get("recommendation_reason", ""),
                        "score": score,
                    })
        if high_matches:
            lines = ["最近有以下高匹配任务值得推荐给用户："]
            for i, m in enumerate(high_matches[:3], 1):
                lines.append(f"{i}. {m['title']} - {m['reason']} (匹配度: {m['score']:.2f})")
            lines.append("请在回复中自然地向用户推荐这些任务。")
            return "\n".join(lines)
    except Exception as e:
        logger.warning(f"Failed to get proactive suggestions: {e}")
    return ""
```

- [ ] **Step 5: Inject into `_step_llm` in ai_agent.py**

Read `backend/app/services/ai_agent.py` around `_step_llm` (line ~800). Find where `_build_system_prompt()` returns. Do NOT modify `_build_system_prompt` signature. Append after it returns, using `ctx.db` and `ctx.user.id`:

```python
# In _step_llm, after system_prompt = _build_system_prompt(template, user, lang):
profile_context = await build_user_profile_context(ctx.user.id, ctx.db)
if profile_context:
    system_prompt += f"\n\n{profile_context}\n请根据以上用户画像信息提供个性化的回答和推荐。"

# Proactive suggestions on first message only
history = await self._load_history(ctx)
if not history:  # First message in conversation
    suggestions = await get_proactive_suggestions(ctx.user.id, ctx.db)
    if suggestions:
        system_prompt += f"\n\n{suggestions}"
```

**Note:** The implementer must read `_step_llm` to find the exact insertion point.

- [ ] **Step 6: Run tests**

```bash
cd backend && python -m pytest tests/test_ai_profile_context.py -v
```

Expected: PASS (2 tests)

- [ ] **Step 7: Commit**

```bash
git add backend/app/services/ai_agent.py backend/tests/test_ai_profile_context.py
git commit -m "feat: inject user profile context and proactive suggestions into AI chat"
```

---

## Task 12: Integration testing and verification

**Files:**
- All files from Tasks 1-12

- [ ] **Step 1: Run all existing tests**

```bash
cd backend && python -m pytest tests/ -v
```

Verify no regressions.

- [ ] **Step 2: Test with feature flag**

```bash
cd backend && USE_NEW_RECOMMENDATION_ENGINE=true python -m pytest tests/ -v
```

- [ ] **Step 3: Manual verification — old engine**

```bash
cd backend && python -c "
from app.models import get_db_session
db = next(get_db_session())
from app.task_recommendation import get_task_recommendations
recs = get_task_recommendations(db, 'test_user_id', limit=5)
print(f'Old engine: {len(recs)} recommendations')
for r in recs:
    print(f'  {r[\"title\"]}: score={r[\"match_score\"]}')
"
```

- [ ] **Step 4: Manual verification — new engine**

```bash
cd backend && USE_NEW_RECOMMENDATION_ENGINE=true python -c "
from app.models import get_db_session
db = next(get_db_session())
from app.task_recommendation import get_task_recommendations
recs = get_task_recommendations(db, 'test_user_id', limit=5)
print(f'New engine: {len(recs)} recommendations')
for r in recs:
    print(f'  {r[\"title\"]}: score={r[\"match_score\"]}, reason={r[\"recommendation_reason\"]}')
"
```

- [ ] **Step 5: Compare old vs new engine output**

Ensure both engines produce similar quality results. The new engine should include profile-based and demand-based scoring that the old engine lacks.

- [ ] **Step 6: Final commit**

```bash
git add -A
git commit -m "test: integration tests and verification for new recommendation engine"
```
