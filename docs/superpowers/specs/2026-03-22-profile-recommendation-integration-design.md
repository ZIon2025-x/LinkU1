# Profile Data Integration into Recommendation & AI System

## Overview

User profile data (preferences, demand predictions, reliability scores) is currently collected but not consumed by the recommendation engine or AI chat system. This design integrates profile data into task recommendations and AI conversations, and refactors the recommendation engine into a modular scorer architecture.

## Scope

1. **Preference model consolidation** — Merge `UserPreferences` into `UserProfilePreference`
2. **Recommendation engine refactor** — Pluggable scorer architecture
3. **New scorers** — `profile_scorer` and `demand_scorer` for profile-aware recommendations
4. **AI chat personalization** — Profile-aware AI conversations with proactive suggestions

**Out of scope:** Discovery Feed personalization (deferred to Discovery Feed redesign).

---

## 1. Preference Model Consolidation

### Problem

Two preference models coexist:
- **UserPreferences** (old): `task_types`, `locations`, `task_levels`, `keywords`, `min_deadline_days` — consumed by recommendation engine
- **UserProfilePreference** (new): `mode`, `duration_type`, `reward_preference`, `preferred_time_slots`, `preferred_categories`, `preferred_helper_types`, `nearby_push_enabled`, `city` — only used for display and nearby push

### Solution

Merge `UserPreferences` fields into `UserProfilePreference`. After migration, delete `UserPreferences`.

**New fields on UserProfilePreference:**

| Field | Type | Source |
|---|---|---|
| `task_types` | JSON | Migrated from UserPreferences |
| `locations` | JSON | Migrated from UserPreferences |
| `task_levels` | JSON | Migrated from UserPreferences |
| `keywords` | JSON | Migrated from UserPreferences |
| `min_deadline_days` | Integer (default=1) | Migrated from UserPreferences |

**Migration strategy:**
1. Alembic migration adds columns to `user_profile_preferences` table (new JSON/JSONB columns for `task_types`, `locations`, `task_levels`, `keywords`; Integer for `min_deadline_days`)
2. Data migration: copy from `user_preferences` to `user_profile_preferences`, matching on `user_id`. Source columns are `Text` type (JSON-encoded strings), so the migration must `json.loads()` before inserting into JSONB columns. Handle malformed or null values gracefully (default to empty list/dict).
3. For the 5 migrated fields, always copy from `UserPreferences` (the only source). For semantic overlaps (e.g., `UserPreferences.locations` and `UserProfilePreference.city`), `UserProfilePreference.city` takes precedence — `locations` is supplementary.
4. Update all code references: `UserPreferences` → `UserProfilePreference`
5. Drop `user_preferences` table

**Affected API endpoints:**
- `GET/PUT /user/preferences` in `routers.py` — redirect to `UserProfilePreference`
- `_build_user_preference_vector` in `task_recommendation.py` — read from merged model
- Any other references found via code search for `UserPreferences`

**Merged UserProfilePreference fields (complete):**
```
# Original fields
mode, duration_type, reward_preference, preferred_time_slots,
preferred_categories, preferred_helper_types, nearby_push_enabled, city

# Migrated from UserPreferences
task_types, locations, task_levels, keywords, min_deadline_days
```

---

## 2. Recommendation Engine Refactor

### Problem

`task_recommendation.py` is 2100+ lines with 7 scoring factors mixed into one file. Adding new factors increases complexity and risk.

### Solution

Refactor into pluggable scorer modules.

### Directory Structure

```
backend/app/recommendation/
├── __init__.py
├── engine.py                  # HybridEngine: orchestrates scorers, merges scores
├── base_scorer.py             # BaseScorer abstract class
├── scorer_registry.py         # Register/discover scorers, manage weight config
├── scorers/
│   ├── __init__.py
│   ├── content_scorer.py      # Content matching (task_type, location, price, keywords)
│   ├── collaborative_scorer.py # Collaborative filtering (user behavior similarity)
│   ├── location_scorer.py     # Geographic (GPS distance, city matching)
│   ├── social_scorer.py       # Social (same school, high-rated users)
│   ├── time_scorer.py         # Time factors (deadline, active time slots)
│   ├── popularity_scorer.py   # Popular tasks
│   ├── newness_scorer.py      # New task boost
│   ├── profile_scorer.py      # [NEW] Profile preference matching
│   └── demand_scorer.py       # [NEW] AI demand prediction matching
├── user_vector.py             # Converts UserProfilePreference fields into normalized dict for content_scorer and profile_scorer consumption
├── cache.py                   # Cache logic (migrated from original file)
└── utils.py                   # Shared utilities (Haversine distance, etc.)
```

### BaseScorer Interface

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass

@dataclass
class ScoredTask:
    score: float        # 0.0 - 1.0
    reason: str         # Human-readable recommendation reason

class BaseScorer(ABC):
    name: str
    default_weight: float

    @abstractmethod
    def score(self, user, tasks: list, context: dict) -> dict[int, ScoredTask]:
        """Return {task_id: ScoredTask} for relevant tasks."""

    def get_weight(self, user) -> float:
        """Return this scorer's weight for this user. Supports dynamic adjustment."""
        return self.default_weight
```

### ScorerRegistry

Scorers are registered via explicit `registry.register(scorer)` calls in `recommendation/__init__.py`. The registry manages weight configuration:

```python
class ScorerRegistry:
    def register(self, scorer: BaseScorer):
        """Register a scorer instance."""

    def get_active_scorers(self) -> list[BaseScorer]:
        """Return all registered scorers."""

    def normalize_weights(self, user) -> dict[str, float]:
        """Get weights for all scorers, normalized to sum to 1.0.
        Calls each scorer's get_weight(user), then scales proportionally."""
```

Weight normalization ensures total always equals 1.0 regardless of dynamic adjustments.

### HybridEngine Orchestration

```python
class HybridEngine:
    def __init__(self, registry: ScorerRegistry):
        self.registry = registry

    def recommend(self, user, limit: int, filters: dict = None) -> list[Recommendation]:
        # Candidate selection reuses existing task filtering logic:
        # active tasks, not owned by user, within deadline.
        # Default candidate pool: 500 most recent eligible tasks.
        candidate_tasks = self._get_candidates(filters)
        context = self._build_context(user)

        # Get normalized weights (sum to 1.0) from registry
        weights = self.registry.normalize_weights(user)
        aggregated = {}  # task_id -> {total_score, reasons[]}
        for scorer in self.registry.get_active_scorers():
            weight = weights[scorer.name]
            if weight <= 0:
                continue
            results = scorer.score(user, candidate_tasks, context)
            for task_id, scored in results.items():
                if task_id not in aggregated:
                    aggregated[task_id] = {"score": 0.0, "reasons": []}
                aggregated[task_id]["score"] += scored.score * weight
                if scored.reason:
                    aggregated[task_id]["reasons"].append(scored.reason)

        # Normalize: registry ensures weights sum to 1.0
        # Sort and return top N
        ranked = sorted(aggregated.items(), key=lambda x: x[1]["score"], reverse=True)
        return [self._to_recommendation(task_id, data) for task_id, data in ranked[:limit]]
```

The `HybridEngine` fetches all normalized weights upfront via `registry.normalize_weights(user)`, ensuring they always sum to 1.0 after dynamic adjustments.

### Backward Compatibility

- Old `task_recommendation.py` becomes a thin wrapper importing from `recommendation/engine.py`
- API endpoint (`GET /recommendations`) unchanged — same request/response format
- Existing caching modules (`recommendation_cache_strategy.py`, etc.) remain unchanged, integrated via `cache.py`

### Migrating Existing Scorers

All 7 existing scoring factors are extracted as-is into individual scorer files. Logic unchanged, only file organization changes:

| Original function | New scorer file | Default weight (existing users) |
|---|---|---|
| `_calculate_content_match_score` | `content_scorer.py` | 0.30 |
| `_collaborative_recommend` | `collaborative_scorer.py` | 0.25 |
| `_location_recommend` | `location_scorer.py` | 0.10 |
| `_social_recommend` | `social_scorer.py` | 0.15 |
| `_time_recommend` | `time_scorer.py` | 0.08 |
| `_popular_recommend` | `popularity_scorer.py` | 0.02 |
| `_new_task_boost` | `newness_scorer.py` | 0.10 |

---

## 3. New Scorers

### profile_scorer — User Profile Preference Matching

Reads `UserProfilePreference` fields and matches against task attributes.

**Note:** The Task model does not have `mode` (online/offline) or `duration_type` (one_time/long_term) fields. These are user-side preferences only. The profile_scorer uses heuristics to infer task characteristics from existing fields:
- **mode inference:** If task has a physical `location`, it's likely `offline`; if location is empty/null, it's likely `online`.
- **duration_type inference:** If task has `is_flexible=True` or description contains long-term keywords, it's likely `long_term`; otherwise `one_time`.

| Profile field | Match logic | Sub-weight |
|---|---|---|
| `mode` (online/offline/both) | Inferred task mode matches user preference | 0.10 |
| `duration_type` (one_time/long_term/both) | Inferred task duration matches | 0.10 |
| `preferred_time_slots` | Task deadline falls within preferred slots | 0.20 |
| `preferred_categories` | Task type in preferred categories | 0.30 |
| `reward_preference` | Task reward range matches preference | 0.15 |
| `city` | Task location city matches | 0.15 |

**"both" handling:** If user sets `mode=both` or `duration_type=both`, that dimension scores 1.0 for all tasks (no preference = match everything).

**Future improvement:** Consider adding `mode` and `duration_type` fields to the Task model for more accurate matching. This is out of scope for this phase.

**Default weight in hybrid:** 0.10 (supplements content_scorer which covers similar but different fields).

### demand_scorer — AI Demand Prediction Matching

Reads `UserDemand` AI-inferred data and matches against tasks.

| Demand field | Match logic | Sub-weight |
|---|---|---|
| `predicted_needs` | Task type/keywords in predicted needs list | 0.35 |
| `inferred_skills` | Task required skills intersect with user skills | 0.30 |
| `inferred_preferences` | Similar to profile_scorer but AI-inferred source | 0.20 |
| `recent_interests` | Task keywords intersect with recent interests | 0.15 |

**Smart weight switching (user maturity):**

```python
def get_weight(self, user) -> float:
    interaction_count = self._get_interaction_count(user)
    if interaction_count < 10:       # New user — sparse behavioral data
        return 0.20                  # AI inference weight high
    elif interaction_count < 50:     # Moderate activity
        return 0.12
    else:                            # Mature user — rich behavioral data
        return 0.05                  # AI inference becomes supplementary
```

Weight normalization is handled by `ScorerRegistry.normalize_weights()` — all scorers report their raw `get_weight()` values, and the registry scales them proportionally to sum to 1.0. No manual rebalancing needed.

**Null safety:** If `UserDemand` doesn't exist for a user, demand_scorer returns empty results (score 0 for all tasks). The scorer is effectively skipped.

---

## 4. AI Chat Personalization

### Profile Context Injection

Build a user profile summary and inject into AI system prompt when starting a conversation.

**Backend function:**

```python
def build_user_profile_context(user_id: str, db: Session) -> str:
    pref = db.query(UserProfilePreference).filter_by(user_id=user_id).first()
    demand = db.query(UserDemand).filter_by(user_id=user_id).first()
    reliability = db.query(UserReliability).filter_by(user_id=user_id).first()

    sections = []
    if pref:
        sections.append(f"偏好模式: {pref.mode}, 时段: {pref.preferred_time_slots}")
        sections.append(f"城市: {pref.city}")
    if demand:
        sections.append(f"兴趣领域: {demand.recent_interests}")
        sections.append(f"推断技能: {demand.inferred_skills}")
        sections.append(f"预测需求: {demand.predicted_needs}")
    if reliability:
        sections.append(f"可靠度评分: {reliability.reliability_score}")

    return "用户画像:\n" + "\n".join(sections) if sections else ""
```

**Injection point:** Added to the system prompt in the AI chat SSE endpoint, before sending the first message to the LLM.

### Recommendation Enhancement

Modify the existing `_recommend_tasks` AI tool:
- Pass user profile context to the recommendation engine call
- AI response can reference profile data to explain recommendations (e.g., "你擅长翻译，这个任务很适合你")

### Proactive Suggestions — Backend-Triggered Context

**Trigger:** When user opens AI chat, the backend checks for high-match tasks before the first LLM call.

**Logic:**
1. Backend calls recommendation engine with user profile
2. Filter results with match_score > 0.8 and created_at within 24h
3. If matches found, prepend a "proactive suggestions" section to the system prompt with task summaries and match reasons
4. The system prompt instructs the AI to mention these matches naturally in its greeting

**Implementation:**
- Logic added to the AI chat SSE endpoint (not a separate tool)
- Before constructing the LLM request, query recommendations and append high-match results to system prompt
- No new AI tool needed — this is a system prompt enrichment, not a tool call

**Example system prompt addition:**
```
最近有以下高匹配任务值得推荐给用户：
1. [任务标题] - 匹配原因：你擅长翻译，报酬符合偏好 (匹配度: 0.85)
请在回复中自然地向用户推荐这些任务。
```

### What does NOT change
- SSE streaming protocol unchanged
- Frontend AI chat UI unchanged
- Profile data only injected via system prompt, not exposed as separate API

---

## Weight Rebalancing Summary

Each scorer reports a raw `default_weight` via `get_weight(user)`. The `ScorerRegistry` normalizes all weights to sum to 1.0. The tables below show the **raw weights** (before normalization) and the approximate **effective weights** (after normalization).

### New User (< 10 interactions)

| Scorer | Raw Weight | Effective |
|---|---|---|
| content | 0.20 | 0.18 |
| collaborative | 0.05 | 0.05 |
| location | 0.10 | 0.09 |
| social | 0.15 | 0.14 |
| time | 0.07 | 0.06 |
| popularity | 0.08 | 0.07 |
| newness | 0.15 | 0.14 |
| **profile** | **0.10** | **0.09** |
| **demand** | **0.20** | **0.18** (AI high) |
| **Total** | **1.10** | **1.00** |

### Moderate User (10-50 interactions)

| Scorer | Raw Weight | Effective |
|---|---|---|
| content | 0.25 | 0.23 |
| collaborative | 0.18 | 0.17 |
| location | 0.10 | 0.09 |
| social | 0.13 | 0.12 |
| time | 0.08 | 0.07 |
| popularity | 0.04 | 0.04 |
| newness | 0.08 | 0.07 |
| **profile** | **0.10** | **0.09** |
| **demand** | **0.12** | **0.11** (AI moderate) |
| **Total** | **1.08** | **~1.00** |

### Mature User (50+ interactions)

| Scorer | Raw Weight | Effective |
|---|---|---|
| content | 0.30 | 0.28 |
| collaborative | 0.25 | 0.24 |
| location | 0.10 | 0.09 |
| social | 0.12 | 0.11 |
| time | 0.08 | 0.08 |
| popularity | 0.02 | 0.02 |
| newness | 0.05 | 0.05 |
| **profile** | **0.10** | **0.09** |
| **demand** | **0.05** | **0.04** (AI low) |
| **Total** | **1.07** | **1.00** |

---

## Data Flow Summary

```
UserProfilePreference (merged) ──→ profile_scorer ──→ HybridEngine ──→ GET /recommendations
UserDemand (AI inferred)       ──→ demand_scorer  ──→ HybridEngine ──→ GET /recommendations
UserReliability                ──→ (display only, no scorer yet)
All three                      ──→ build_user_profile_context() ──→ AI system prompt
BehaviorCollector              ──→ UserDemand (existing pipeline unchanged)
```

---

## Flutter Changes

No Flutter changes required for this phase:
- Recommendation reasons are already returned in the existing `recommendation_reason` API field and displayed by existing UI components
- AI chat personalization is entirely backend-side (system prompt injection)
- The merged preference model does not change the Flutter-side `UserProfilePreference` Dart model (it already has all user-facing fields; the migrated fields `task_types`, `locations`, etc. are backend-only recommendation data)

---

## Testing Strategy

- **Unit tests:** Each scorer independently testable with mock user/task data
- **Integration tests:** HybridEngine with all scorers, verify score aggregation
- **Regression:** Ensure existing recommendation quality doesn't degrade — compare old vs new engine output on sample users
- **AI tests:** Verify profile context appears in system prompt, proactive suggestion triggers correctly

## Migration & Rollback

- **Feature flag:** `USE_NEW_RECOMMENDATION_ENGINE` in AppConfig — allows switching between old and new engine
- **Gradual rollout:** New engine for 10% users first, compare metrics, then expand
- **Rollback:** Feature flag off → old `task_recommendation.py` handles all requests
