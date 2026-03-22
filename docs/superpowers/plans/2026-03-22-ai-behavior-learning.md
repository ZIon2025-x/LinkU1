# AI Behavior Learning System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let AI analyze user interests, skills, lifecycle stage, and preferences during chat, silently update user profiles, and track platform behavior (search/browse) — driving recommendations across the entire platform.

**Architecture:** AI appends hidden `<user_insights>` JSON to every reply. Backend extracts it, strips it before sending to frontend, and queues it in an in-memory BehaviorCollector. A background thread flushes events to DB every 30s and merges insights into UserDemand in real-time. Platform search/detail APIs piggyback behavior recording. A new onboarding flow collects user identity, city, and skills. The existing nightly demand_inference task is upgraded to use month+identity-based lifecycle stages.

**Tech Stack:** Python/FastAPI/SQLAlchemy (backend), Flutter/Dart/BLoC (frontend), PostgreSQL (database)

**Spec:** `docs/superpowers/specs/2026-03-22-ai-behavior-learning-design.md`

---

## File Structure

### Backend — New Files

| File | Responsibility |
|------|----------------|
| `backend/app/services/behavior_collector.py` | Singleton in-memory queue + daemon thread for batch DB writes + UserDemand merge |
| `backend/migrations/add_behavior_events_and_fields.sql` | New table + model field additions |

### Backend — Modified Files

| File | Change |
|------|--------|
| `backend/app/models.py` | Add `UserBehaviorEvent` model; modify `UserDemand` (user_stage→JSONB, add identity/inferred_skills/inferred_preferences); add `city` to `UserProfilePreference`; add `onboarding_completed` to `User` |
| `backend/app/services/ai_agent.py` | Add user insights instruction to system prompt; extract `<user_insights>` from AI reply before streaming to frontend; record events to BehaviorCollector |
| `backend/app/services/demand_inference.py` | Replace registration-day stage logic with month+identity logic; merge with existing UserDemand instead of overwriting |
| `backend/app/main.py` | Initialize BehaviorCollector singleton on startup |
| `backend/app/routes/user_profile.py` | Update onboarding endpoint schema (add identity, city); update preference/demand response schemas |
| `backend/app/services/user_profile_service.py` | Update onboarding to save identity and city; compute initial user_stages |
| `backend/app/async_routers.py` | Add behavior recording to task search (`get_tasks`) and task detail (`get_task_by_id`) endpoints |
| `backend/app/flea_market_routes.py` | Add behavior recording to flea market search and detail endpoints |

### Flutter — New Files

| File | Responsibility |
|------|----------------|
| `link2ur/lib/features/onboarding/views/identity_onboarding_view.dart` | 3-step onboarding UI (identity → city → skills) |
| `link2ur/lib/features/onboarding/bloc/identity_onboarding_bloc.dart` | Onboarding state management |

### Flutter — Modified Files

| File | Change |
|------|--------|
| `link2ur/lib/data/models/user_profile.dart` | Update `UserDemand` (userStage→List, add identity/inferredSkills/inferredPreferences); `UserProfilePreference` add city |
| `link2ur/lib/data/models/user.dart` | Add `onboardingCompleted` field |
| `link2ur/lib/data/repositories/user_profile_repository.dart` | Update onboarding submit (add identity, city) |
| `link2ur/lib/core/router/app_router.dart` | Add onboarding redirect check after login |
| `link2ur/lib/l10n/app_en.arb` | Onboarding text |
| `link2ur/lib/l10n/app_zh.arb` | Onboarding text |
| `link2ur/lib/l10n/app_zh_Hant.arb` | Onboarding text |

---

## Task 1: Database Migration + Models

**Files:**
- Create: `backend/migrations/add_behavior_events_and_fields.sql`
- Modify: `backend/app/models.py`

- [ ] **Step 1: Create migration SQL**

```sql
-- 用户行为事件表
CREATE TABLE IF NOT EXISTS user_behavior_events (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_type VARCHAR(32) NOT NULL,
    event_data JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_behavior_events_user_created
    ON user_behavior_events(user_id, created_at);

-- UserDemand 表改动
ALTER TABLE user_demands ALTER COLUMN user_stage TYPE JSONB USING to_jsonb(user_stage);
ALTER TABLE user_demands ADD COLUMN IF NOT EXISTS identity VARCHAR(16);
ALTER TABLE user_demands ADD COLUMN IF NOT EXISTS inferred_skills JSONB DEFAULT '[]';
ALTER TABLE user_demands ADD COLUMN IF NOT EXISTS inferred_preferences JSONB DEFAULT '{}';

-- UserProfilePreference 新增 city
ALTER TABLE user_profile_preferences ADD COLUMN IF NOT EXISTS city VARCHAR(64);

-- User 新增 onboarding_completed
ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE;
```

- [ ] **Step 2: Add `UserBehaviorEvent` model to `models.py`**

Add after `NearbyTaskPush` class (around line 3637):

```python
class UserBehaviorEvent(Base):
    __tablename__ = "user_behavior_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    event_type = Column(String(32), nullable=False)
    event_data = Column(JSON, nullable=False, default=dict)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)

    __table_args__ = (
        Index("ix_behavior_events_user_created", "user_id", "created_at"),
    )
```

- [ ] **Step 3: Modify `UserDemand` model**

In `models.py` at `UserDemand` class (lines 3591-3607):

Change `user_stage` from Enum to JSON:
```python
    user_stage = Column(JSON, default=list)  # was: Column(Enum(UserStage))
```

Add new fields after `inference_version`:
```python
    identity = Column(String(16))  # "pre_arrival" or "in_uk"
    inferred_skills = Column(JSON, default=list)
    inferred_preferences = Column(JSON, default=dict)
```

- [ ] **Step 4: Add `city` to `UserProfilePreference`**

In `models.py` at `UserProfilePreference` class (around line 3564), add after `nearby_push_enabled`:

```python
    city = Column(String(64))
```

- [ ] **Step 5: Add `onboarding_completed` to `User`**

In `models.py` at `User` class (around line 178), add:

```python
    onboarding_completed = Column(Boolean, default=False, server_default="false", nullable=False)
```

- [ ] **Step 6: Commit**

```bash
git add backend/migrations/add_behavior_events_and_fields.sql backend/app/models.py
git commit -m "feat: add behavior events table and model field changes for AI learning"
```

---

## Task 2: BehaviorCollector — In-Memory Queue + Background Thread

**Files:**
- Create: `backend/app/services/behavior_collector.py`

- [ ] **Step 1: Create the BehaviorCollector**

```python
"""
In-memory behavior event queue with background thread for batch DB writes.
Events are queued with list.append() (zero-blocking for callers),
flushed every 30 seconds by a daemon thread.
"""
import threading
import time
import logging
from datetime import datetime, timezone
from typing import Optional

logger = logging.getLogger(__name__)


class BehaviorCollector:
    _instance: Optional["BehaviorCollector"] = None

    def __init__(self):
        self._queue: list = []
        self._lock = threading.Lock()
        self._running = False
        self._thread: Optional[threading.Thread] = None

    @classmethod
    def get_instance(cls) -> "BehaviorCollector":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def start(self):
        """Start the background flush thread."""
        if self._running:
            return
        self._running = True
        self._thread = threading.Thread(target=self._flush_loop, daemon=True)
        self._thread.start()
        logger.info("BehaviorCollector started")

    def stop(self):
        """Stop the background flush thread."""
        self._running = False

    def record(self, user_id: str, event_type: str, event_data: dict):
        """Queue a behavior event. Zero-blocking for callers."""
        event = {
            "user_id": user_id,
            "event_type": event_type,
            "event_data": event_data,
            "created_at": datetime.now(timezone.utc),
        }
        with self._lock:
            self._queue.append(event)

    def _flush_loop(self):
        """Background thread: flush every 30 seconds."""
        while self._running:
            time.sleep(30)
            try:
                self._flush()
            except Exception as e:
                logger.warning(f"BehaviorCollector flush failed: {e}")

    def _flush(self):
        """Drain queue, batch insert events, merge ai_insights into UserDemand."""
        with self._lock:
            if not self._queue:
                return
            events = self._queue.copy()
            self._queue.clear()

        from app.database import SessionLocal
        db = SessionLocal()
        try:
            self._batch_insert(db, events)
            self._merge_insights(db, events)
            db.commit()
        except Exception as e:
            db.rollback()
            logger.warning(f"BehaviorCollector DB write failed: {e}")
        finally:
            db.close()

    def _batch_insert(self, db, events: list):
        """Bulk insert all events into user_behavior_events table."""
        from app.models import UserBehaviorEvent
        objects = [
            UserBehaviorEvent(
                user_id=e["user_id"],
                event_type=e["event_type"],
                event_data=e["event_data"],
                created_at=e["created_at"],
            )
            for e in events
        ]
        db.bulk_save_objects(objects)

    def _merge_insights(self, db, events: list):
        """For ai_insight events, merge into UserDemand in real-time."""
        from app.models import UserDemand
        from datetime import datetime, timezone

        # Group insights by user
        user_insights: dict[str, list] = {}
        for e in events:
            if e["event_type"] == "ai_insight":
                uid = e["user_id"]
                if uid not in user_insights:
                    user_insights[uid] = []
                user_insights[uid].append(e["event_data"])

        for user_id, insights_list in user_insights.items():
            demand = db.query(UserDemand).filter(
                UserDemand.user_id == user_id
            ).first()
            if not demand:
                demand = UserDemand(user_id=user_id)
                db.add(demand)
                db.flush()

            # Merge interests
            existing_interests = demand.recent_interests or {}
            for insight in insights_list:
                for item in insight.get("interests", []):
                    topic = item.get("topic")
                    if not topic:
                        continue
                    existing = existing_interests.get(topic, {})
                    # Keep highest confidence and urgency
                    if item.get("confidence", 0) >= existing.get("confidence", 0):
                        existing_interests[topic] = {
                            "confidence": item.get("confidence", 0),
                            "urgency": item.get("urgency", "low"),
                            "updated_at": datetime.now(timezone.utc).isoformat(),
                        }
            demand.recent_interests = existing_interests

            # Merge inferred_skills
            existing_skills = {s["skill"]: s for s in (demand.inferred_skills or [])}
            for insight in insights_list:
                for item in insight.get("skills", []):
                    skill = item.get("skill")
                    if not skill:
                        continue
                    existing = existing_skills.get(skill, {})
                    if item.get("confidence", 0) >= existing.get("confidence", 0):
                        existing_skills[skill] = {
                            "skill": skill,
                            "confidence": item.get("confidence", 0),
                        }
            demand.inferred_skills = list(existing_skills.values())

            # Merge inferred_preferences
            existing_prefs = demand.inferred_preferences or {}
            for insight in insights_list:
                prefs = insight.get("preferences", {})
                if prefs:
                    existing_prefs.update(prefs)
            demand.inferred_preferences = existing_prefs

            # Merge stages with month+identity calculation
            ai_stages = set()
            for insight in insights_list:
                for stage in insight.get("stages", []):
                    ai_stages.add(stage)
            # Reuse shared stage logic from demand_inference
            from app.services.demand_inference import determine_user_stages
            month_stages = determine_user_stages(demand.identity)
            merged = list(set(month_stages) | ai_stages)
            demand.user_stage = merged

            demand.last_inferred_at = datetime.now(timezone.utc)
            demand.inference_version = "v2.0-realtime"
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/services/behavior_collector.py
git commit -m "feat: add BehaviorCollector with in-memory queue and real-time UserDemand merge"
```

---

## Task 3: Initialize BehaviorCollector on App Startup

**Files:**
- Modify: `backend/app/main.py`

- [ ] **Step 1: Add BehaviorCollector initialization**

Find the startup section in `main.py` (around line 926, after Prometheus init). Add:

```python
    # 启动行为采集器
    try:
        from app.services.behavior_collector import BehaviorCollector
        behavior_collector = BehaviorCollector.get_instance()
        behavior_collector.start()
        logger.info("✅ BehaviorCollector 已启动")
    except Exception as e:
        logger.warning(f"⚠️  BehaviorCollector 启动失败: {e}")
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/main.py
git commit -m "feat: initialize BehaviorCollector on app startup"
```

---

## Task 4: AI Agent — System Prompt + Insights Extraction

**Files:**
- Modify: `backend/app/services/ai_agent.py`

- [ ] **Step 1: Add user insights instruction to system prompt**

In `ai_agent.py`, find `_DEFAULT_SYSTEM_PROMPT` (line 421). Add the following to the end of the system prompt string (before the closing `"""`):

```python
"""

## 用户行为分析

在你的每条回复末尾，添加一段 <user_insights> 标签，用 JSON 格式分析用户的行为信号。

分析维度：
- interests: 用户表达的需求或兴趣（如"我想找人帮搬家"→ topic: 搬家）
- skills: 用户透露的技能或经验（如"我以前做过家教"→ skill: 教学）
- stages: 用户当前的生命周期阶段信号（如频繁问租房→ house_hunting）
- preferences: 用户的偏好（线上/线下、价格敏感等）

判断 confidence 和 urgency 时，关注用户的语气和行为模式：
- "我马上就要搬家了" → high urgency, high confidence（紧迫且明确）
- "搬家一般怎么收费？" → medium urgency, medium confidence（在了解）
- "我朋友想问问搬家的事" → low urgency, low confidence（不是自己的需求）
- 用户问了一个问题后持续追问细节 → 提升 confidence

如果这条消息没有任何有价值的信号，输出空 JSON: <user_insights>{}</user_insights>

不要告诉用户你在做分析。<user_insights> 标签对用户不可见。
"""
```

- [ ] **Step 2: Add insights extraction function**

Add a helper function near the top of `ai_agent.py` (after imports):

```python
import re
import json as _json

_USER_INSIGHTS_PATTERN = re.compile(
    r"<user_insights>\s*(.*?)\s*</user_insights>",
    re.DOTALL,
)


def _extract_user_insights(text: str) -> tuple[str, dict | None]:
    """Extract and remove <user_insights> JSON from AI reply.
    Returns (cleaned_text, insights_dict_or_None).
    """
    match = _USER_INSIGHTS_PATTERN.search(text)
    if not match:
        return text, None
    raw = match.group(1).strip()
    cleaned = _USER_INSIGHTS_PATTERN.sub("", text).rstrip()
    if not raw or raw == "{}":
        return cleaned, None
    try:
        data = _json.loads(raw)
        if not isinstance(data, dict) or not data:
            return cleaned, None
        return cleaned, data
    except _json.JSONDecodeError:
        return cleaned, None
```

- [ ] **Step 3: Integrate extraction into the LLM pipeline**

In `_step_llm()` (around line 882, after the assistant message is saved), add insights extraction and recording:

Find where the final assistant message text is assembled (after tool loop completes and full response is built). Add after the message is saved to DB:

```python
            # Extract user insights from AI reply
            try:
                cleaned_text, insights = _extract_user_insights(full_response_text)
                if insights:
                    from app.services.behavior_collector import BehaviorCollector
                    collector = BehaviorCollector.get_instance()
                    collector.record(ctx.user_id, "ai_insight", insights)
                # Update the saved message with cleaned text (without insights tag)
                if cleaned_text != full_response_text:
                    ctx.assistant_message.content = cleaned_text
                    db.commit()
            except Exception as e:
                logger.warning(f"Failed to extract user insights: {e}")
```

- [ ] **Step 4: Record intent and tool_call events**

In `_step_llm()`, after intent classification (around line 895), add:

```python
            # Record intent event
            try:
                from app.services.behavior_collector import BehaviorCollector
                collector = BehaviorCollector.get_instance()
                collector.record(ctx.user_id, "ai_intent", {
                    "intent": ctx.intent.value if ctx.intent else "unknown",
                    "message_preview": ctx.user_message[:100] if ctx.user_message else "",
                })
            except Exception:
                pass
```

In the tool execution section (around line 830, after each tool result is received), add:

```python
                # Record tool call event
                try:
                    collector = BehaviorCollector.get_instance()
                    collector.record(ctx.user_id, "ai_tool_call", {
                        "tool": tool_name,
                        "params": tool_input,
                    })
                    # Record specific events for key tools
                    if tool_name == "prepare_task_draft":
                        collector.record(ctx.user_id, "ai_task_draft", tool_input)
                except Exception:
                    pass
```

In the CS transfer step (where `ctx.terminated = True` after detecting transfer intent), add:

```python
            # Record CS transfer event
            try:
                from app.services.behavior_collector import BehaviorCollector
                collector = BehaviorCollector.get_instance()
                collector.record(ctx.user_id, "ai_cs_transfer", {
                    "message_preview": ctx.user_message[:100] if ctx.user_message else "",
                })
            except Exception:
                pass
```

For `draft_confirmed` and `draft_abandoned`: these happen on the **Flutter side** when the user taps confirm/dismiss on the task draft card. The implementer should add a lightweight API call or piggyback on the task creation endpoint to record these. Alternatively, `draft_confirmed` is implicitly recorded when a task is created (the task creation already exists in DB), and `draft_abandoned` can be deferred to a future iteration.

- [ ] **Step 5: Handle SSE streaming — strip insights before sending to frontend**

The AI response is streamed via SSE. The `<user_insights>` tag will appear at the end of the stream. We need to buffer the last part of the stream to strip it.

In the SSE streaming section of `_step_llm()`, find where `text_delta` events are yielded. The extraction in Step 3 handles the saved message; for streaming, we need to ensure the `<user_insights>` block is not sent to the frontend.

Add a post-processing step: after all tokens are streamed and the full response is assembled, if insights were found, send a final `text_replace` event or simply ensure the frontend message is updated. Since the frontend reads `streamingContent` token by token, the simplest approach is:

**Option: Let the tag stream through, then strip it.** Since `<user_insights>` appears at the very end of the reply, and the frontend will display it briefly, we should instead buffer the tail of the stream.

Add a buffer mechanism in the token streaming:

```python
            # Before streaming tokens, initialize buffer
            _insights_buffer = ""
            _in_insights_tag = False
```

In the token yield loop, modify to detect and suppress the insights tag:

```python
                # Check if we're entering the insights tag
                _insights_buffer += token_text
                if "<user_insights>" in _insights_buffer:
                    _in_insights_tag = True
                    # Send any text before the tag
                    pre_tag = _insights_buffer.split("<user_insights>")[0]
                    if pre_tag:
                        yield _sse_event("text_delta", {"content": pre_tag})
                    _insights_buffer = "<user_insights>" + _insights_buffer.split("<user_insights>", 1)[1]
                    continue
                if _in_insights_tag:
                    # Accumulate until we find closing tag
                    if "</user_insights>" in _insights_buffer:
                        _in_insights_tag = False
                        # Extract insights from buffer
                        _, insights = _extract_user_insights(_insights_buffer)
                        if insights:
                            from app.services.behavior_collector import BehaviorCollector
                            collector = BehaviorCollector.get_instance()
                            collector.record(ctx.user_id, "ai_insight", insights)
                        # Send any text after closing tag
                        post_tag = _insights_buffer.split("</user_insights>", 1)[1]
                        if post_tag.strip():
                            yield _sse_event("text_delta", {"content": post_tag})
                        _insights_buffer = ""
                    continue
                # Normal token — flush buffer and yield
                if len(_insights_buffer) > 200 and "<" not in _insights_buffer:
                    yield _sse_event("text_delta", {"content": _insights_buffer})
                    _insights_buffer = ""
                elif "<" not in _insights_buffer[-1:]:
                    yield _sse_event("text_delta", {"content": _insights_buffer})
                    _insights_buffer = ""
```

Note: The exact integration depends on how tokens are currently yielded. The implementer should read the existing streaming code (lines 734-882) and adapt this buffering logic to fit the existing pattern. The key requirement is: **`<user_insights>...</user_insights>` must never reach the frontend SSE stream.**

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/ai_agent.py
git commit -m "feat: add user insights extraction from AI replies with behavior recording"
```

---

## Task 5: Platform Behavior Tracking (Search/Browse)

**Files:**
- Modify: `backend/app/async_routers.py`
- Modify: `backend/app/flea_market_routes.py`

- [ ] **Step 1: Add behavior recording to task search endpoint**

In `async_routers.py`, find `async def get_tasks()` (line 108). After the response is built and before returning, add:

```python
    # Record search behavior
    if keyword and current_user:
        try:
            from app.services.behavior_collector import BehaviorCollector
            collector = BehaviorCollector.get_instance()
            collector.record(current_user.id, "search", {
                "keyword": keyword,
                "source": "tasks",
                "result_count": total,
            })
        except Exception:
            pass
```

- [ ] **Step 2: Add behavior recording to task detail endpoint**

In `async_routers.py`, find `async def get_task_by_id()` (line 378). After the task is fetched successfully and before returning, add:

```python
    # Record browse behavior
    if current_user and task:
        try:
            from app.services.behavior_collector import BehaviorCollector
            collector = BehaviorCollector.get_instance()
            collector.record(current_user.id, "browse", {
                "target": "task",
                "target_id": task_id,
                "category": getattr(task, 'task_type', None),
            })
        except Exception:
            pass
```

- [ ] **Step 3: Add behavior recording to flea market search/detail**

In `flea_market_routes.py`, find the search endpoint. After results are fetched, add:

```python
    # Record search behavior
    if keyword and current_user:
        try:
            from app.services.behavior_collector import BehaviorCollector
            collector = BehaviorCollector.get_instance()
            collector.record(current_user.id, "search", {
                "keyword": keyword,
                "source": "flea_market",
                "result_count": len(items),
            })
        except Exception:
            pass
```

In the detail endpoint, add:

```python
    # Record browse behavior
    if current_user:
        try:
            from app.services.behavior_collector import BehaviorCollector
            collector = BehaviorCollector.get_instance()
            collector.record(current_user.id, "browse", {
                "target": "flea_market",
                "target_id": item_id,
                "category": getattr(item, 'category', None),
            })
        except Exception:
            pass
```

The implementer should find the exact function names and parameters by reading the file. The pattern is the same: add a try/except block after the main query succeeds.

- [ ] **Step 4: Commit**

```bash
git add backend/app/async_routers.py backend/app/flea_market_routes.py
git commit -m "feat: add behavior tracking to task and flea market search/detail endpoints"
```

---

## Task 6: Upgrade Demand Inference (Month + Identity Stages)

**Files:**
- Modify: `backend/app/services/demand_inference.py`

- [ ] **Step 1: Replace `determine_user_stage()` with month+identity logic**

Replace the existing function (lines 29-47) with:

```python
# Lifecycle stage definitions by month
STAGE_MAP_PRE_ARRIVAL = {
    5: ["pre_arrival"], 6: ["pre_arrival"], 7: ["pre_arrival"],
    8: ["pre_arrival", "new_arrival"], 9: ["new_arrival"],
}
STAGE_MAP_IN_UK = {
    1: ["settled"], 2: ["settled"],
    3: ["settled", "easter_break"], 4: ["settled", "easter_break"],
    5: ["exam_season"], 6: ["exam_season", "graduation", "house_hunting", "moving"],
    7: ["graduation", "house_hunting", "moving", "returning"],
    8: ["house_hunting", "moving", "returning"],
    9: ["settled", "returning"],
    10: ["settled"], 11: ["settled"],
    12: ["settled", "christmas_break"],
}


def determine_user_stages(identity: str | None) -> list[str]:
    """Determine lifecycle stages based on identity and current month."""
    from datetime import datetime, timezone
    month = datetime.now(timezone.utc).month
    if identity == "pre_arrival":
        return STAGE_MAP_PRE_ARRIVAL.get(month, ["pre_arrival"])
    elif identity == "in_uk":
        return STAGE_MAP_IN_UK.get(month, ["settled"])
    else:
        return ["settled"]
```

- [ ] **Step 2: Update `STAGE_PREDICTIONS` to use new stage keys**

Replace the existing dict (lines 13-26) with predictions for all 10 stages:

```python
STAGE_PREDICTIONS = {
    "pre_arrival": [
        {"category": "arrival_prep", "confidence": 0.9, "items": ["接机", "住宿", "行李"], "reason": "行前准备阶段"},
    ],
    "new_arrival": [
        {"category": "settling", "confidence": 0.85, "items": ["银行卡", "电话卡", "注册"], "reason": "新生入学阶段"},
        {"category": "orientation", "confidence": 0.7, "items": ["校园", "超市", "交通"], "reason": "熟悉环境"},
    ],
    "exam_season": [
        {"category": "academic", "confidence": 0.8, "items": ["论文", "打印", "复习"], "reason": "期末阶段"},
    ],
    "graduation": [
        {"category": "graduation", "confidence": 0.85, "items": ["毕业照", "签证", "PSW"], "reason": "毕业阶段"},
    ],
    "house_hunting": [
        {"category": "housing", "confidence": 0.9, "items": ["租房", "合同", "看房"], "reason": "找房阶段"},
    ],
    "moving": [
        {"category": "moving", "confidence": 0.9, "items": ["搬家", "家具", "清洁"], "reason": "搬家阶段"},
    ],
    "returning": [
        {"category": "returning", "confidence": 0.85, "items": ["退租", "行李海运", "闲置转让"], "reason": "回国阶段"},
    ],
    "settled": [
        {"category": "daily", "confidence": 0.6, "items": ["代购", "代取", "日常"], "reason": "日常生活"},
    ],
    "christmas_break": [
        {"category": "travel", "confidence": 0.7, "items": ["旅游搭子", "短租", "寄存"], "reason": "圣诞假期"},
    ],
    "easter_break": [
        {"category": "travel", "confidence": 0.7, "items": ["旅游搭子", "短途出行"], "reason": "复活节假期"},
    ],
}
```

- [ ] **Step 3: Update `infer_demand()` to merge instead of overwrite**

Replace the existing function (lines 63-81) with:

```python
def infer_demand(db: Session, user_id: str) -> UserDemand:
    """Infer or update user demand. Merges with existing data instead of overwriting."""
    from app.models import User, UserDemand

    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        return None

    demand = db.query(UserDemand).filter(UserDemand.user_id == user_id).first()
    if not demand:
        demand = UserDemand(user_id=user_id)
        db.add(demand)

    # Compute stages from month + identity
    stages = determine_user_stages(demand.identity)

    # Merge with existing stages (may include AI-inferred stages)
    existing_stages = demand.user_stage if isinstance(demand.user_stage, list) else []
    merged_stages = list(set(stages) | set(existing_stages))
    demand.user_stage = merged_stages

    # Build predicted_needs from all active stages
    needs = []
    seen_categories = set()
    for stage in merged_stages:
        for need in STAGE_PREDICTIONS.get(stage, []):
            if need["category"] not in seen_categories:
                needs.append(need)
                seen_categories.add(need["category"])
    demand.predicted_needs = needs

    # Merge recent interests from task behavior (don't overwrite AI interests)
    task_interests = analyze_recent_interests(db, user_id)
    existing_interests = demand.recent_interests or {}
    for topic, data in task_interests.items():
        if topic not in existing_interests:
            existing_interests[topic] = data
        else:
            # Keep whichever has higher confidence
            if data.get("confidence", 0) > existing_interests[topic].get("confidence", 0):
                existing_interests[topic] = data
    demand.recent_interests = existing_interests

    demand.last_inferred_at = datetime.now(timezone.utc)
    demand.inference_version = "v2.0"
    db.flush()
    return demand
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/services/demand_inference.py
git commit -m "feat: upgrade demand inference with month+identity stages and merge logic"
```

---

## Task 7: Update Onboarding Backend (Identity + City)

**Files:**
- Modify: `backend/app/routes/user_profile.py`
- Modify: `backend/app/services/user_profile_service.py`

- [ ] **Step 1: Update `OnboardingSubmit` schema**

In `user_profile.py`, find `OnboardingSubmit` (line 67). Add:

```python
class OnboardingSubmit(BaseModel):
    capabilities: list[CapabilityItem] = []
    mode: str | None = None
    preferred_categories: list[int] | None = None
    identity: str | None = None  # "pre_arrival" or "in_uk"
    city: str | None = None
```

- [ ] **Step 2: Update onboarding endpoint**

In `user_profile.py`, find the onboarding endpoint (line 272). Update to save identity, city, and set `onboarding_completed`:

```python
@router.post("/onboarding")
async def submit_onboarding(
    data: OnboardingSubmit,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    svc.submit_onboarding(db, current_user.id, data)

    # Save identity to UserDemand
    if data.identity:
        from app.models import UserDemand
        demand = db.query(UserDemand).filter(UserDemand.user_id == current_user.id).first()
        if not demand:
            demand = UserDemand(user_id=current_user.id)
            db.add(demand)
        demand.identity = data.identity
        # Compute initial stages
        from app.services.demand_inference import determine_user_stages
        demand.user_stage = determine_user_stages(data.identity)
        db.flush()

    # Save city to preferences
    if data.city:
        from app.models import UserProfilePreference
        pref = db.query(UserProfilePreference).filter(
            UserProfilePreference.user_id == current_user.id
        ).first()
        if pref:
            pref.city = data.city
        else:
            pref = UserProfilePreference(user_id=current_user.id, city=data.city)
            db.add(pref)

    # Mark onboarding complete
    current_user.onboarding_completed = True

    # Run demand inference
    infer_demand(db, current_user.id)
    db.commit()
    return {"message": "ok"}
```

- [ ] **Step 3: Add `onboarding_completed` to user info response**

Find the user info/summary endpoint that returns user data to Flutter. Add `onboarding_completed` to the response so the Flutter app can check it. Look for where `User` fields are serialized and add:

```python
    "onboarding_completed": current_user.onboarding_completed,
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/routes/user_profile.py backend/app/services/user_profile_service.py
git commit -m "feat: update onboarding endpoint with identity, city, and completion flag"
```

---

## Task 8: Flutter — Update Models

**Files:**
- Modify: `link2ur/lib/data/models/user_profile.dart`

- [ ] **Step 1: Update `UserDemand` model**

In `user_profile.dart`, find `UserDemand` class (line 166). Update:

```dart
class UserDemand extends Equatable {
  final List<String> userStages;  // was: String userStage
  final List<PredictedNeed> predictedNeeds;
  final Map<String, dynamic> recentInterests;
  final String? lastInferredAt;
  final String? identity;  // "pre_arrival" or "in_uk"
  final List<Map<String, dynamic>> inferredSkills;
  final Map<String, dynamic> inferredPreferences;

  const UserDemand({
    this.userStages = const [],
    this.predictedNeeds = const [],
    this.recentInterests = const {},
    this.lastInferredAt,
    this.identity,
    this.inferredSkills = const [],
    this.inferredPreferences = const {},
  });

  factory UserDemand.fromJson(Map<String, dynamic> json) {
    final stageRaw = json['user_stage'];
    final stages = stageRaw is List
        ? stageRaw.map((e) => e.toString()).toList()
        : stageRaw is String
            ? [stageRaw]
            : <String>[];
    return UserDemand(
      userStages: stages,
      predictedNeeds: (json['predicted_needs'] as List?)
              ?.map((e) => PredictedNeed.fromJson(e))
              .toList() ??
          [],
      recentInterests:
          Map<String, dynamic>.from(json['recent_interests'] as Map? ?? {}),
      lastInferredAt: json['last_inferred_at'] as String?,
      identity: json['identity'] as String?,
      inferredSkills: (json['inferred_skills'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      inferredPreferences:
          Map<String, dynamic>.from(json['inferred_preferences'] as Map? ?? {}),
    );
  }

  @override
  List<Object?> get props => [
        userStages, predictedNeeds, recentInterests, lastInferredAt,
        identity, inferredSkills, inferredPreferences,
      ];
}
```

- [ ] **Step 2: Add `city` to `UserProfilePreference`**

In `UserProfilePreference` class (line 54), add field:

```dart
  final String? city;
```

Update constructor, `fromJson`, `toJson`, `copyWith`, and `props` accordingly.

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/data/models/user_profile.dart
git commit -m "feat: update Flutter models for behavior learning (UserDemand, preferences)"
```

---

## Task 9: Flutter — Onboarding View

**Files:**
- Create: `link2ur/lib/features/onboarding/views/identity_onboarding_view.dart`
- Create: `link2ur/lib/features/onboarding/bloc/identity_onboarding_bloc.dart`
- Modify: `link2ur/lib/l10n/app_en.arb`, `app_zh.arb`, `app_zh_Hant.arb`

- [ ] **Step 1: Add l10n keys**

In `app_zh.arb`:
```json
"onboardingIdentityTitle": "你的身份",
"onboardingIdentityPreArrival": "准备来英国的留学生",
"onboardingIdentityInUk": "已经在英国读书",
"onboardingCityTitle": "你在哪个城市",
"onboardingCityHint": "选择或输入城市",
"onboardingSkillsTitle": "你擅长什么",
"onboardingSkillsSkip": "跳过",
"onboardingNext": "下一步",
"onboardingComplete": "完成"
```

In `app_en.arb`:
```json
"onboardingIdentityTitle": "About You",
"onboardingIdentityPreArrival": "Planning to come to the UK",
"onboardingIdentityInUk": "Already studying in the UK",
"onboardingCityTitle": "Your City",
"onboardingCityHint": "Select or type a city",
"onboardingSkillsTitle": "Your Skills",
"onboardingSkillsSkip": "Skip",
"onboardingNext": "Next",
"onboardingComplete": "Done"
```

In `app_zh_Hant.arb`:
```json
"onboardingIdentityTitle": "你的身份",
"onboardingIdentityPreArrival": "準備來英國的留學生",
"onboardingIdentityInUk": "已經在英國讀書",
"onboardingCityTitle": "你在哪個城市",
"onboardingCityHint": "選擇或輸入城市",
"onboardingSkillsTitle": "你擅長什麼",
"onboardingSkillsSkip": "跳過",
"onboardingNext": "下一步",
"onboardingComplete": "完成"
```

- [ ] **Step 2: Run `flutter gen-l10n`**

```bash
cd link2ur && flutter gen-l10n
```

- [ ] **Step 3: Create onboarding BLoC**

Create `link2ur/lib/features/onboarding/bloc/identity_onboarding_bloc.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/user_profile_repository.dart';

// Events
abstract class IdentityOnboardingEvent extends Equatable {
  const IdentityOnboardingEvent();
  @override
  List<Object?> get props => [];
}

class OnboardingSetIdentity extends IdentityOnboardingEvent {
  const OnboardingSetIdentity(this.identity);
  final String identity; // "pre_arrival" or "in_uk"
  @override
  List<Object?> get props => [identity];
}

class OnboardingSetCity extends IdentityOnboardingEvent {
  const OnboardingSetCity(this.city);
  final String city;
  @override
  List<Object?> get props => [city];
}

class OnboardingSetSkills extends IdentityOnboardingEvent {
  const OnboardingSetSkills(this.skills);
  final List<Map<String, dynamic>> skills;
  @override
  List<Object?> get props => [skills];
}

class OnboardingSubmit extends IdentityOnboardingEvent {
  const OnboardingSubmit();
}

// State
class IdentityOnboardingState extends Equatable {
  const IdentityOnboardingState({
    this.identity,
    this.city,
    this.skills = const [],
    this.currentStep = 0,
    this.isSubmitting = false,
    this.isComplete = false,
    this.errorMessage,
  });

  final String? identity;
  final String? city;
  final List<Map<String, dynamic>> skills;
  final int currentStep;
  final bool isSubmitting;
  final bool isComplete;
  final String? errorMessage;

  IdentityOnboardingState copyWith({
    String? identity,
    String? city,
    List<Map<String, dynamic>>? skills,
    int? currentStep,
    bool? isSubmitting,
    bool? isComplete,
    String? errorMessage,
  }) {
    return IdentityOnboardingState(
      identity: identity ?? this.identity,
      city: city ?? this.city,
      skills: skills ?? this.skills,
      currentStep: currentStep ?? this.currentStep,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isComplete: isComplete ?? this.isComplete,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [identity, city, skills, currentStep, isSubmitting, isComplete, errorMessage];
}

// BLoC
class IdentityOnboardingBloc extends Bloc<IdentityOnboardingEvent, IdentityOnboardingState> {
  IdentityOnboardingBloc({required UserProfileRepository repository})
      : _repository = repository,
        super(const IdentityOnboardingState()) {
    on<OnboardingSetIdentity>((event, emit) {
      emit(state.copyWith(identity: event.identity, currentStep: 1));
    });
    on<OnboardingSetCity>((event, emit) {
      emit(state.copyWith(city: event.city, currentStep: 2));
    });
    on<OnboardingSetSkills>((event, emit) {
      emit(state.copyWith(skills: event.skills));
    });
    on<OnboardingSubmit>(_onSubmit);
  }

  final UserProfileRepository _repository;

  Future<void> _onSubmit(
    OnboardingSubmit event,
    Emitter<IdentityOnboardingState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.submitOnboarding(
        state.skills.map((s) => {
          return {
            'category_id': s['category_id'],
            'skill_name': s['skill_name'],
            'proficiency': s['proficiency'] ?? 'beginner',
          };
        }).toList(),
        identity: state.identity,
        city: state.city,
      );
      emit(state.copyWith(isSubmitting: false, isComplete: true));
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }
}
```

- [ ] **Step 4: Create onboarding view**

Create `link2ur/lib/features/onboarding/views/identity_onboarding_view.dart`:

A 3-step PageView with:
- Step 1: Two large cards — "准备来英国" / "已经在英国" (tap to select, go to next)
- Step 2: City selection — list of UK cities (London, Manchester, Birmingham, Edinburgh, Glasgow, Leeds, Bristol, Sheffield, Liverpool, Nottingham, Cambridge, Oxford) + text input for custom
- Step 3: Skill selection — reuse pattern from `capability_edit_view.dart`, with a "Skip" button

On complete, dispatch `OnboardingSubmit`, then navigate to main app.

The implementer should build this view following existing design patterns in `link2ur/lib/core/design/` (colors, typography, spacing, radius).

- [ ] **Step 5: Update `UserProfileRepository.submitOnboarding()`**

In `user_profile_repository.dart`, update the method to accept identity and city:

Add named parameters `identity` and `city` to the existing method signature (keep `capabilities` as named):

```dart
  Future<void> submitOnboarding({
    required List<Map<String, dynamic>> capabilities,
    String? mode,
    List<int> preferredCategories = const [],
    String? identity,
    String? city,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.profileOnboarding,
      data: {
        'capabilities': capabilities,
        if (mode != null) 'mode': mode,
        if (preferredCategories.isNotEmpty) 'preferred_categories': preferredCategories,
        if (identity != null) 'identity': identity,
        if (city != null) 'city': city,
      },
    );
    if (!response.isSuccess) {
      throw UserProfileException(response.message ?? 'Onboarding failed');
    }
  }
```

- [ ] **Step 6: Commit**

```bash
git add link2ur/lib/features/onboarding/ link2ur/lib/data/repositories/user_profile_repository.dart link2ur/lib/l10n/
git commit -m "feat: add identity onboarding flow (3-step: identity, city, skills)"
```

---

## Task 10: Flutter — Router Integration (Onboarding Gate)

**Files:**
- Modify: `link2ur/lib/core/router/app_router.dart`
- Modify: `link2ur/lib/core/router/app_routes.dart`

- [ ] **Step 1: Add onboarding route**

In `app_routes.dart`, add:

```dart
static const String identityOnboarding = '/onboarding/identity';
```

- [ ] **Step 2: Add route definition**

In the router configuration, add a route for the onboarding view:

```dart
GoRoute(
  path: AppRoutes.identityOnboarding,
  name: 'identityOnboarding',
  builder: (context, state) => BlocProvider(
    create: (context) => IdentityOnboardingBloc(
      repository: context.read<UserProfileRepository>(),
    ),
    child: const IdentityOnboardingView(),
  ),
),
```

- [ ] **Step 3: Add onboarding redirect in router**

In `app_router.dart`, find the redirect logic (lines 59-104). Add after the authenticated check:

```dart
        // Check onboarding
        if (authState.status == AuthStatus.authenticated) {
          final user = authState.user;
          if (user != null &&
              !(user.onboardingCompleted ?? false) &&
              !state.matchedLocation.startsWith('/onboarding')) {
            return AppRoutes.identityOnboarding;
          }
        }
```

- [ ] **Step 4: Update User model to include `onboardingCompleted`**

Check the User model in Flutter (likely in `lib/data/models/user.dart`) and add the field:

```dart
final bool? onboardingCompleted;
```

Update `fromJson` to read `onboarding_completed`.

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/core/router/ link2ur/lib/data/models/
git commit -m "feat: add onboarding route and redirect gate for new users"
```

---

## Task 11: Integration Verification

- [ ] **Step 1: Run backend — verify migration**

```bash
cd backend && python -c "from app.models import UserBehaviorEvent, UserDemand; print('Models OK')"
```

- [ ] **Step 2: Run Flutter analyze**

```bash
cd link2ur && flutter analyze
```

Expected: No errors in modified files.

- [ ] **Step 3: Fix any analysis issues**

```bash
git add -A && git commit -m "fix: resolve analysis issues"
```

- [ ] **Step 4: Test BehaviorCollector manually**

```python
from app.services.behavior_collector import BehaviorCollector
c = BehaviorCollector.get_instance()
c.record("test123", "ai_insight", {"interests": [{"topic": "搬家", "confidence": 0.9, "urgency": "high"}]})
c._flush()  # Manual flush to verify DB write
```

- [ ] **Step 5: Test AI insights extraction**

```python
from app.services.ai_agent import _extract_user_insights
text = 'Hello!\n\n<user_insights>{"interests": [{"topic": "test"}]}</user_insights>'
cleaned, data = _extract_user_insights(text)
assert cleaned == "Hello!"
assert data["interests"][0]["topic"] == "test"
print("Extraction OK")
```
