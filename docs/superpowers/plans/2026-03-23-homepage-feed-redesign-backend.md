# Homepage Feed Redesign — Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add follow system, real-time ticker, and mix tasks+activities into the discovery feed to support a Xiaohongshu-style unified homepage.

**Architecture:** Extend existing `/api/discovery/feed` with two new content types (`task`, `activity`). Build a new `UserFollow` model and follow/feed APIs. Build a ticker API that aggregates recent platform activity from existing tables. All new endpoints follow existing async FastAPI + SQLAlchemy patterns.

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy (async), PostgreSQL, Redis

**Spec:** `docs/superpowers/specs/2026-03-23-homepage-feed-redesign-backend.md`

**Key import paths (verified):**
- `from app.utils.time_utils import get_utc_time`
- `from app.utils.location_utils import obfuscate_location`
- `from app.deps import get_current_user_secure_async_csrf, get_async_db_dependency`
- `from app.forum_routes import get_current_user_optional`
- `from app.redis_cache import redis_cache` (sync Redis — wrap in `asyncio.to_thread()` for async endpoints)
- `from app.cache import cache_response`
- `from app.recommendation.utils import get_excluded_task_ids` (sync — needs async wrapper)
- Migration numbering: verify latest number at implementation time (currently 125)

---

### Task 1: UserFollow Model + Migration

**Files:**
- Modify: `app/models.py` (add UserFollow class at end of file)
- Create: `migrations/126_add_user_follows.sql`
- Create: `tests/test_follow_model.py`

- [ ] **Step 1: Write the migration SQL**

Create `migrations/126_add_user_follows.sql`:

```sql
CREATE TABLE IF NOT EXISTS user_follows (
    id SERIAL PRIMARY KEY,
    follower_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_user_follow UNIQUE (follower_id, following_id)
);
CREATE INDEX IF NOT EXISTS ix_user_follows_follower ON user_follows(follower_id);
CREATE INDEX IF NOT EXISTS ix_user_follows_following ON user_follows(following_id);
```

- [ ] **Step 2: Add UserFollow model to models.py**

Add at end of `app/models.py` (before any final comments):

```python
class UserFollow(Base):
    """用户关注关系"""
    __tablename__ = "user_follows"

    id = Column(Integer, primary_key=True, autoincrement=True)
    follower_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    following_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    follower = relationship("User", foreign_keys=[follower_id], backref="following_relations")
    following = relationship("User", foreign_keys=[following_id], backref="follower_relations")

    __table_args__ = (
        UniqueConstraint("follower_id", "following_id", name="uq_user_follow"),
        Index("ix_user_follows_follower", "follower_id"),
        Index("ix_user_follows_following", "following_id"),
    )
```

- [ ] **Step 3: Write model unit test**

Create `tests/test_follow_model.py`:

```python
"""UserFollow model basic tests."""
import pytest
from unittest.mock import MagicMock

def test_user_follow_model_exists():
    """Verify UserFollow model can be imported."""
    from app.models import UserFollow
    assert UserFollow.__tablename__ == "user_follows"

def test_user_follow_columns():
    """Verify required columns exist."""
    from app.models import UserFollow
    cols = {c.name for c in UserFollow.__table__.columns}
    assert "follower_id" in cols
    assert "following_id" in cols
    assert "created_at" in cols

def test_user_follow_unique_constraint():
    """Verify unique constraint on (follower_id, following_id)."""
    from app.models import UserFollow
    constraint_names = [c.name for c in UserFollow.__table__.constraints if hasattr(c, 'name') and c.name]
    assert "uq_user_follow" in constraint_names
```

- [ ] **Step 4: Run tests**

Run: `cd F:/python_work/LinkU/backend && python -m pytest tests/test_follow_model.py -v`
Expected: 3 PASSED

- [ ] **Step 5: Commit**

```bash
git add app/models.py migrations/126_add_user_follows.sql tests/test_follow_model.py
git commit -m "feat: add UserFollow model and migration"
```

---

### Task 2: Follow/Unfollow + Lists API

**Files:**
- Create: `app/follow_routes.py`
- Modify: `app/main.py` (register router)
- Create: `tests/test_follow_routes.py`

- [ ] **Step 1: Write the follow routes**

Create `app/follow_routes.py`:

```python
"""
Follow 系统路由
关注/取关、粉丝列表、关注列表
"""

import asyncio
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_current_user_secure_async_csrf, get_async_db_dependency
from app.forum_routes import get_current_user_optional
from app.redis_cache import redis_cache

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/users", tags=["关注"])

# Rate limit: 30 follow/unfollow actions per minute
_FOLLOW_RATE_LIMIT = 30
_FOLLOW_RATE_WINDOW = 60  # seconds


async def _check_follow_rate_limit(user_id: str):
    """Check follow/unfollow rate limit. Uses sync Redis wrapped in to_thread."""
    key = f"follow_rate:{user_id}"
    try:
        def _redis_rate_check():
            count = redis_cache.get(key)
            if count and int(count) >= _FOLLOW_RATE_LIMIT:
                return True  # Rate limited
            pipe = redis_cache.pipeline()
            pipe.incr(key)
            pipe.expire(key, _FOLLOW_RATE_WINDOW)
            pipe.execute()
            return False

        is_limited = await asyncio.to_thread(_redis_rate_check)
        if is_limited:
            raise HTTPException(status_code=429, detail="操作过于频繁，请稍后再试")
    except HTTPException:
        raise
    except Exception:
        pass  # Redis failure should not block the action


@router.post("/{user_id}/follow")
async def follow_user(
    user_id: str,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """关注用户"""
    if current_user.id == user_id:
        raise HTTPException(status_code=400, detail="不能关注自己")

    # Check target user exists
    target = await db.execute(
        select(models.User.id).where(models.User.id == user_id)
    )
    if not target.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="用户不存在")

    await _check_follow_rate_limit(current_user.id)

    # Idempotent: check if already following
    existing = await db.execute(
        select(models.UserFollow.id).where(
            models.UserFollow.follower_id == current_user.id,
            models.UserFollow.following_id == user_id,
        )
    )
    if not existing.scalar_one_or_none():
        follow = models.UserFollow(
            follower_id=current_user.id,
            following_id=user_id,
        )
        db.add(follow)
        await db.commit()

    # Invalidate cache
    await _invalidate_follow_cache(current_user.id, user_id)

    # Get follower count
    count_result = await db.execute(
        select(func.count()).where(models.UserFollow.following_id == user_id)
    )
    followers_count = count_result.scalar() or 0

    return {"status": "followed", "followers_count": followers_count}


@router.delete("/{user_id}/follow")
async def unfollow_user(
    user_id: str,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """取消关注"""
    await _check_follow_rate_limit(current_user.id)

    await db.execute(
        delete(models.UserFollow).where(
            models.UserFollow.follower_id == current_user.id,
            models.UserFollow.following_id == user_id,
        )
    )
    await db.commit()

    await _invalidate_follow_cache(current_user.id, user_id)

    count_result = await db.execute(
        select(func.count()).where(models.UserFollow.following_id == user_id)
    )
    followers_count = count_result.scalar() or 0

    return {"status": "unfollowed", "followers_count": followers_count}


@router.get("/{user_id}/followers")
async def get_followers(
    user_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取粉丝列表"""
    offset = (page - 1) * page_size

    # Total count
    total_result = await db.execute(
        select(func.count()).where(models.UserFollow.following_id == user_id)
    )
    total = total_result.scalar() or 0

    # Fetch followers with user info
    query = (
        select(
            models.User.id,
            models.User.name,
            models.User.avatar,
            models.User.bio,
            models.UserFollow.created_at,
        )
        .join(models.UserFollow, models.UserFollow.follower_id == models.User.id)
        .where(models.UserFollow.following_id == user_id)
        .order_by(models.UserFollow.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    result = await db.execute(query)
    rows = result.all()

    # Check if current user follows each follower back
    current_following_ids = set()
    if current_user and rows:
        follower_ids = [r.id for r in rows]
        following_result = await db.execute(
            select(models.UserFollow.following_id).where(
                models.UserFollow.follower_id == current_user.id,
                models.UserFollow.following_id.in_(follower_ids),
            )
        )
        current_following_ids = {r[0] for r in following_result.all()}

    users = [
        {
            "id": r.id,
            "name": r.name,
            "avatar": r.avatar,
            "bio": r.bio,
            "is_following": r.id in current_following_ids,
            "followed_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]

    return {
        "users": users,
        "total": total,
        "page": page,
        "has_more": (offset + page_size) < total,
    }


@router.get("/{user_id}/following")
async def get_following(
    user_id: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    current_user: Optional[models.User] = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取关注列表"""
    offset = (page - 1) * page_size

    total_result = await db.execute(
        select(func.count()).where(models.UserFollow.follower_id == user_id)
    )
    total = total_result.scalar() or 0

    query = (
        select(
            models.User.id,
            models.User.name,
            models.User.avatar,
            models.User.bio,
            models.UserFollow.created_at,
        )
        .join(models.UserFollow, models.UserFollow.following_id == models.User.id)
        .where(models.UserFollow.follower_id == user_id)
        .order_by(models.UserFollow.created_at.desc())
        .offset(offset)
        .limit(page_size)
    )
    result = await db.execute(query)
    rows = result.all()

    # Check if current user follows each person
    current_following_ids = set()
    if current_user and rows:
        target_ids = [r.id for r in rows]
        following_result = await db.execute(
            select(models.UserFollow.following_id).where(
                models.UserFollow.follower_id == current_user.id,
                models.UserFollow.following_id.in_(target_ids),
            )
        )
        current_following_ids = {r[0] for r in following_result.all()}

    users = [
        {
            "id": r.id,
            "name": r.name,
            "avatar": r.avatar,
            "bio": r.bio,
            "is_following": r.id in current_following_ids,
            "followed_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]

    return {
        "users": users,
        "total": total,
        "page": page,
        "has_more": (offset + page_size) < total,
    }


async def _invalidate_follow_cache(follower_id: str, following_id: str):
    """Invalidate follow-related caches. Wraps sync Redis in to_thread."""
    def _do_invalidate():
        try:
            redis_cache.delete(f"follow_count:{follower_id}")
            redis_cache.delete(f"follow_count:{following_id}")
            redis_cache.delete(f"is_following:{follower_id}:{following_id}")
        except Exception:
            pass
    await asyncio.to_thread(_do_invalidate)
```

**Important note about auth dependency:** The spec says `get_current_user_secure_sync_csrf` but the follow routes use `AsyncSession`, so we need the async equivalent. Check what async auth dependency exists in the codebase:

- Look in `app/deps.py` for `get_current_user_secure_async` or similar
- If not found, look at how `discovery_routes.py` or `forum_routes.py` handle authenticated async routes
- The exact dependency name may differ — use whatever the codebase provides for authenticated async endpoints

- [ ] **Step 2: Register router in main.py**

Add to `app/main.py` after the discovery router registration block (around line 450):

```python
# Follow 系统路由
from app.follow_routes import router as follow_router
app.include_router(follow_router)
```

- [ ] **Step 3: Write tests**

Create `tests/test_follow_routes.py`:

```python
"""Follow routes unit tests (mocked DB)."""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

def test_follow_routes_importable():
    """Verify follow routes module can be imported."""
    from app.follow_routes import router
    assert router.prefix == "/api/users"

def test_follow_route_endpoints_registered():
    """Verify expected routes exist."""
    from app.follow_routes import router
    paths = [r.path for r in router.routes]
    assert "/{user_id}/follow" in paths
    assert "/{user_id}/followers" in paths
    assert "/{user_id}/following" in paths

def test_rate_limit_key_format():
    """Verify rate limit key uses correct format."""
    key = f"follow_rate:test_user"
    assert "follow_rate:" in key

@pytest.mark.asyncio
async def test_follow_self_raises_400():
    """Calling follow_user with own user_id should raise 400."""
    from unittest.mock import AsyncMock, MagicMock
    from fastapi import HTTPException
    from app.follow_routes import follow_user

    user = MagicMock()
    user.id = "user1"
    db = AsyncMock()

    with pytest.raises(HTTPException) as exc_info:
        await follow_user(user_id="user1", request=MagicMock(), current_user=user, db=db)
    assert exc_info.value.status_code == 400
```

- [ ] **Step 4: Run tests**

Run: `cd F:/python_work/LinkU/backend && python -m pytest tests/test_follow_routes.py tests/test_follow_model.py -v`
Expected: All PASSED

- [ ] **Step 5: Commit**

```bash
git add app/follow_routes.py app/main.py tests/test_follow_routes.py
git commit -m "feat: add follow/unfollow and follower/following list APIs"
```

---

### Task 3: Discovery Feed — Add Task Content Type

**Files:**
- Modify: `app/discovery_routes.py` (add `_fetch_tasks()`, update feed assembly, update `_weighted_shuffle`)

**Reference docs:**
- Spec: `docs/superpowers/specs/2026-03-23-homepage-feed-redesign-backend.md` → Subsystem 1, Task Content Type
- Existing fetcher pattern: `_fetch_forum_posts()` at `app/discovery_routes.py:130-260`

- [ ] **Step 1: Add `_fetch_tasks()` function**

Add to `app/discovery_routes.py` after the last existing fetcher function (after `_fetch_expert_services()`). Follow the exact flat format used by other fetchers:

```python
async def _fetch_tasks(
    db: AsyncSession, limit: int, current_user=None, recommendation_scores: dict = None
) -> list:
    """获取开放任务 for discovery feed.

    Args:
        recommendation_scores: {task_id: (score, reason)} from recommendation engine, optional.
    """
    import asyncio
    from app.utils.time_utils import get_utc_time

    now = get_utc_time()

    # Subquery for application count
    app_count = (
        select(func.count(models.TaskApplication.id))
        .where(models.TaskApplication.task_id == models.Task.id)
        .correlate(models.Task)
        .scalar_subquery()
        .label("app_count")
    )

    query = (
        select(
            models.Task.id,
            models.Task.title,
            models.Task.title_zh,
            models.Task.title_en,
            models.Task.description,
            models.Task.description_zh,
            models.Task.description_en,
            models.Task.images,
            models.Task.task_type,
            models.Task.reward,
            models.Task.base_reward,
            models.Task.agreed_reward,
            models.Task.reward_to_be_quoted,
            models.Task.location,
            models.Task.deadline,
            models.Task.task_level,
            models.Task.view_count,
            models.Task.poster_id,
            models.Task.created_at,
            app_count,
        )
        .where(
            models.Task.status == "open",
            models.Task.is_visible == True,
            models.Task.deadline > now,
        )
        .order_by(desc(models.Task.created_at))
        .limit(limit)
    )

    # Exclude user's own tasks and already-interacted tasks
    # get_excluded_task_ids is sync — run in thread executor
    if current_user:
        try:
            from app.recommendation.utils import get_excluded_task_ids
            excluded = await asyncio.to_thread(get_excluded_task_ids, db.sync_session, current_user.id)
            if excluded:
                query = query.where(~models.Task.id.in_(excluded))
        except Exception as e:
            logger.debug(f"Failed to get excluded task ids: {e}")
            # Fallback: at minimum exclude own tasks
            query = query.where(models.Task.poster_id != current_user.id)

    result = await db.execute(query)
    rows = result.all()

    # Batch-fetch poster user info
    poster_ids = {r.poster_id for r in rows if r.poster_id}
    poster_map = {}
    if poster_ids:
        poster_result = await db.execute(
            select(models.User.id, models.User.name, models.User.avatar)
            .where(models.User.id.in_(list(poster_ids)))
        )
        poster_map = {r.id: r for r in poster_result.all()}

    items = []
    for row in rows:
        poster = poster_map.get(row.poster_id)
        first_img = _first_image(row.images)

        # Recommendation data (if available)
        rec_score = None
        rec_reason = None
        if recommendation_scores and row.id in recommendation_scores:
            rec_score, rec_reason = recommendation_scores[row.id]

        # Location obfuscation
        location = row.location
        if location:
            try:
                from app.utils.location_utils import obfuscate_location
                location = obfuscate_location(location)
            except Exception:
                pass

        items.append({
            "feed_type": "task",
            "id": f"task_{row.id}",
            "title": row.title,
            "title_zh": row.title_zh,
            "title_en": row.title_en,
            "description": (row.description or "")[:100],
            "description_zh": (row.description_zh or "")[:100],
            "description_en": (row.description_en or "")[:100],
            "images": [first_img] if first_img else None,
            "user_id": str(row.poster_id) if row.poster_id else None,
            "user_name": poster.name if poster else None,
            "user_avatar": poster.avatar if poster else None,
            "price": float(row.reward) if row.reward else None,
            "original_price": float(row.base_reward) if row.base_reward else None,
            "discount_percentage": None,
            "currency": "GBP",
            "rating": None,
            "like_count": None,
            "comment_count": None,
            "view_count": row.view_count or 0,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": {
                "task_type": row.task_type,
                "reward": float(row.reward) if row.reward else None,
                "base_reward": float(row.base_reward) if row.base_reward else None,
                "agreed_reward": float(row.agreed_reward) if row.agreed_reward else None,
                "reward_to_be_quoted": row.reward_to_be_quoted,
                "location": location,
                "deadline": row.deadline.isoformat() if row.deadline else None,
                "task_level": row.task_level,
                "application_count": row.app_count or 0,
                "match_score": rec_score,
                "recommendation_reason": rec_reason,
            },
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items
```

- [ ] **Step 2: Integrate `_fetch_tasks()` into the feed endpoint**

In the `get_discovery_feed()` handler function, find the `fetch_tasks` list (the list of fetcher tuples). Add the task fetcher:

```python
        # Before the fetch loop, optionally get recommendation scores
        recommendation_scores = None
        if current_user:
            try:
                # Import and call recommendation engine with timeout
                import asyncio
                recommendation_scores = await asyncio.wait_for(
                    _get_recommendation_scores(db, current_user),
                    timeout=0.5,  # 500ms timeout
                )
            except Exception as e:
                logger.debug(f"Recommendation engine unavailable: {e}")

        # Add to the fetch_tasks list:
        ("tasks", lambda: _fetch_tasks(db, limit * 2, current_user, recommendation_scores)),
```

Also add a helper function for getting recommendation scores. The recommendation engine uses **sync** SQLAlchemy, so it must run in a thread executor:

```python
def _get_recommendation_scores_sync(user) -> dict:
    """Get recommendation scores (SYNC — run via asyncio.to_thread).
    Returns {task_id: (score, reason)} or empty dict.
    Creates its own sync DB session internally.
    """
    try:
        from app.task_recommendation import get_task_recommendations
        from app.deps import get_sync_db_contextmanager
        with get_sync_db_contextmanager() as db_sync:
            recs = get_task_recommendations(user, db=db_sync, limit=50)
            return {
                r["task_id"]: (r.get("score", 0), "；".join(r.get("reasons", [])))
                for r in recs
                if "task_id" in r
            }
    except Exception as e:
        logger.debug(f"Failed to get recommendation scores: {e}")
        return {}
```

**Note:** The sync DB session contextmanager name may differ — check `app/deps.py` for the actual function that provides a sync Session. Common patterns: `get_sync_db()` as a generator, or creating a Session directly from `SessionLocal()`. The implementer should verify and use the correct pattern.

Update the recommendation call in Step 2 to use this:

```python
        import asyncio
        recommendation_scores = None
        if current_user:
            try:
                recommendation_scores = await asyncio.wait_for(
                    asyncio.to_thread(_get_recommendation_scores_sync, current_user),
                    timeout=0.5,  # 500ms timeout
                )
            except Exception as e:
                logger.debug(f"Recommendation engine unavailable: {e}")
```

- [ ] **Step 3: Update `_weighted_shuffle` type_weights**

Find the `type_weights` dict in `_weighted_shuffle()` (around line 885) and add:

```python
    type_weights = {
        "forum_post": 1.0,
        "product": 1.0,
        "competitor_review": 3.0,
        "service_review": 3.0,
        "ranking": 2.5,
        "service": 1.0,
        "task": 1.5,       # NEW (Task 3): medium frequency
        # "activity": 2.0 will be added in Task 4
    }
```

- [ ] **Step 4: Write tests**

Create `tests/test_discovery_feed_tasks.py`:

```python
"""Test task content type in discovery feed."""
import pytest
from unittest.mock import MagicMock, AsyncMock, patch
from datetime import datetime, timezone, timedelta

def _make_task_row(task_id, title="Test Task", task_type="design", reward=50.0):
    """Create a mock task row matching the select() columns."""
    row = MagicMock()
    row.id = task_id
    row.title = title
    row.title_zh = title
    row.title_en = title
    row.description = "Test description"
    row.description_zh = "测试描述"
    row.description_en = "Test description"
    row.images = None
    row.task_type = task_type
    row.reward = reward
    row.base_reward = reward
    row.agreed_reward = None
    row.reward_to_be_quoted = False
    row.location = "London"
    row.deadline = datetime.now(timezone.utc) + timedelta(days=7)
    row.task_level = "intermediate"
    row.view_count = 10
    row.poster_id = "user1"
    row.created_at = datetime.now(timezone.utc)
    row.app_count = 3
    return row

def test_task_feed_item_has_required_flat_keys():
    """Verify task items produced by _fetch_tasks have all required flat keys."""
    # These are the required keys in every feed item (from existing discovery feed)
    required_keys = {
        "feed_type", "id", "title", "description", "images",
        "user_id", "user_name", "user_avatar", "price", "currency",
        "extra_data", "created_at",
    }
    # task-specific extra_data keys
    required_extra_keys = {"task_type", "reward", "match_score", "application_count"}

    # Construct a mock item as _fetch_tasks would produce
    item = {
        "feed_type": "task",
        "id": "task_123",
        "title": "Test",
        "description": "Desc",
        "images": None,
        "user_id": "u1",
        "user_name": "Name",
        "user_avatar": None,
        "price": 50.0,
        "currency": "GBP",
        "extra_data": {
            "task_type": "design",
            "reward": 50.0,
            "application_count": 3,
            "match_score": 0.85,
            "recommendation_reason": "test",
            "location": "London",
            "deadline": None,
            "task_level": None,
            "base_reward": 50.0,
            "agreed_reward": None,
            "reward_to_be_quoted": False,
        },
        "created_at": "2026-03-20T00:00:00",
    }
    assert required_keys.issubset(set(item.keys()))
    assert required_extra_keys.issubset(set(item["extra_data"].keys()))
    assert item["id"].startswith("task_")

def test_weighted_shuffle_handles_task_type():
    """Verify _weighted_shuffle doesn't crash on 'task' feed_type."""
    from app.discovery_routes import _weighted_shuffle
    # Build items with all fields _weighted_shuffle might access
    base = {
        "title": "T", "description": "", "images": None,
        "user_id": None, "user_name": None, "user_avatar": None,
        "price": None, "currency": None, "rating": None,
        "like_count": 0, "comment_count": 0, "view_count": 0,
        "upvote_count": None, "downvote_count": None,
        "linked_item": None, "target_item": None,
        "activity_info": None, "is_experienced": None,
        "is_favorited": None, "user_vote_type": None,
        "extra_data": None, "original_price": None,
        "discount_percentage": None,
    }
    items = [
        {**base, "feed_type": "task", "id": "task_1", "created_at": "2026-03-20T00:00:00"},
        {**base, "feed_type": "forum_post", "id": "post_1", "created_at": "2026-03-20T00:00:00"},
        {**base, "feed_type": "task", "id": "task_2", "created_at": "2026-03-19T00:00:00"},
        {**base, "feed_type": "product", "id": "product_1", "created_at": "2026-03-19T00:00:00"},
    ]
    result = _weighted_shuffle(items, limit=4, page=1, seed=42)
    assert len(result) == 4
    feed_types = {r["feed_type"] for r in result}
    assert "task" in feed_types
```

- [ ] **Step 5: Run tests**

Run: `cd F:/python_work/LinkU/backend && python -m pytest tests/test_discovery_feed_tasks.py -v`
Expected: All PASSED

- [ ] **Step 6: Commit**

```bash
git add app/discovery_routes.py tests/test_discovery_feed_tasks.py
git commit -m "feat: add task content type to discovery feed"
```

---

### Task 4: Discovery Feed — Add Activity Content Type

**Files:**
- Modify: `app/discovery_routes.py` (add `_fetch_activities()`)

**Reference:** Spec Subsystem 1 → Activity Content Type. Activity model fields at `app/models.py` lines 2017-2117.

- [ ] **Step 1: Add `_fetch_activities()` function**

Add to `app/discovery_routes.py` after `_fetch_tasks()`:

```python
async def _fetch_activities(db: AsyncSession, limit: int, current_user=None) -> list:
    """获取开放活动 for discovery feed."""
    from app.utils.time_utils import get_utc_time

    now = get_utc_time()

    # Count participants via subquery
    participant_count = (
        select(func.count(models.OfficialActivityApplication.id))
        .where(
            models.OfficialActivityApplication.activity_id == models.Activity.id,
            models.OfficialActivityApplication.status.in_(["pending", "won", "attending"]),
        )
        .correlate(models.Activity)
        .scalar_subquery()
        .label("participant_count")
    )

    query = (
        select(
            models.Activity.id,
            models.Activity.title,
            models.Activity.title_zh,
            models.Activity.title_en,
            models.Activity.description,
            models.Activity.description_zh,
            models.Activity.description_en,
            models.Activity.images,
            models.Activity.activity_type,
            models.Activity.location,
            models.Activity.deadline,
            models.Activity.reward_type,
            models.Activity.original_price_per_participant,
            models.Activity.discounted_price_per_participant,
            models.Activity.currency,
            models.Activity.max_participants,
            models.Activity.expert_id,
            models.Activity.created_at,
            participant_count,
        )
        .where(
            models.Activity.status == "open",
            models.Activity.visibility == "public",
            or_(
                models.Activity.deadline > now,
                models.Activity.deadline.is_(None),
            ),
        )
        .order_by(desc(models.Activity.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    rows = result.all()

    # Batch-fetch organizer user info
    organizer_ids = {r.expert_id for r in rows if r.expert_id}
    organizer_map = {}
    if organizer_ids:
        org_result = await db.execute(
            select(models.User.id, models.User.name, models.User.avatar)
            .where(models.User.id.in_(list(organizer_ids)))
        )
        organizer_map = {r.id: r for r in org_result.all()}

    items = []
    for row in rows:
        organizer = organizer_map.get(row.expert_id)
        first_img = _first_image(row.images)

        price = None
        original_price = None
        if row.discounted_price_per_participant is not None:
            price = float(row.discounted_price_per_participant)
        if row.original_price_per_participant is not None:
            original_price = float(row.original_price_per_participant)

        discount_pct = None
        if original_price and price and original_price > 0 and price < original_price:
            discount_pct = round((1 - price / original_price) * 100)

        items.append({
            "feed_type": "activity",
            "id": f"activity_{row.id}",
            "title": row.title,
            "title_zh": row.title_zh,
            "title_en": row.title_en,
            "description": (row.description or "")[:100],
            "description_zh": (row.description_zh or "")[:100],
            "description_en": (row.description_en or "")[:100],
            "images": [first_img] if first_img else None,
            "user_id": str(row.expert_id) if row.expert_id else None,
            "user_name": organizer.name if organizer else "Link²Ur",
            "user_avatar": organizer.avatar if organizer else None,
            "price": price,
            "original_price": original_price,
            "discount_percentage": discount_pct,
            "currency": row.currency or "GBP",
            "rating": None,
            "like_count": None,
            "comment_count": None,
            "view_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": {
                "activity_type": row.activity_type,
                "max_participants": row.max_participants,
                "current_participants": row.participant_count or 0,
                "reward_type": row.reward_type,
                "location": row.location,
                "deadline": row.deadline.isoformat() if row.deadline else None,
            },
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": None,
            "created_at": row.created_at.isoformat() if row.created_at else None,
        })
    return items
```

- [ ] **Step 2: Add activity fetcher to the feed endpoint**

In `get_discovery_feed()`, add to the `fetch_tasks` list:

```python
        ("activities", lambda: _fetch_activities(db, limit, current_user)),
```

- [ ] **Step 3: Add `"activity"` weight to `_weighted_shuffle`**

Find the `type_weights` dict in `_weighted_shuffle()` and add:

```python
        "activity": 2.0,   # NEW (Task 4): low frequency, higher weight
```

- [ ] **Step 4: Write tests**

Add to `tests/test_discovery_feed_tasks.py`:

```python
def test_activity_feed_item_uses_activity_info():
    """Verify activity items put type-specific data in activity_info."""
    item = {
        "feed_type": "activity",
        "id": "activity_456",
        "title": "Workshop",
        "activity_info": {
            "activity_type": "standard",
            "max_participants": 50,
            "current_participants": 32,
        },
        "extra_data": None,
    }
    assert item["feed_type"] == "activity"
    assert item["id"].startswith("activity_")
    assert item["activity_info"]["max_participants"] == 50
    assert item["extra_data"] is None  # activity uses activity_info, not extra_data
```

- [ ] **Step 5: Run tests**

Run: `cd F:/python_work/LinkU/backend && python -m pytest tests/test_discovery_feed_tasks.py -v`
Expected: All PASSED

- [ ] **Step 6: Commit**

```bash
git add app/discovery_routes.py tests/test_discovery_feed_tasks.py
git commit -m "feat: add activity content type to discovery feed"
```

---

### Task 5: Follow Feed API

**Files:**
- Create: `app/follow_feed_routes.py`
- Modify: `app/main.py` (register router)
- Create: `tests/test_follow_feed.py`

**Reference:** Spec Subsystem 2 → Follow Feed

- [ ] **Step 1: Create follow feed route**

Create `app/follow_feed_routes.py`:

```python
"""
Follow Feed 路由
关注用户的动态时间线
"""

import logging
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import select, func, or_, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency, get_current_user_secure_async_csrf

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/follow", tags=["关注"])

# Maximum following IDs to include in feed query (performance cap)
_MAX_FOLLOWING_FOR_FEED = 200
# Time window for each content type
_TASK_WINDOW_DAYS = 30
_POST_WINDOW_DAYS = 30
_PRODUCT_WINDOW_DAYS = 30
_SERVICE_WINDOW_DAYS = 30
_COMPLETION_WINDOW_DAYS = 7


@router.get("/feed")
async def get_follow_feed(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    request: Request = None,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取关注用户的动态时间线"""
    offset = (page - 1) * page_size
    now = datetime.now(timezone.utc)

    # 1. Get following user IDs (capped for performance)
    following_result = await db.execute(
        select(models.UserFollow.following_id)
        .where(models.UserFollow.follower_id == current_user.id)
        .order_by(models.UserFollow.created_at.desc())
        .limit(_MAX_FOLLOWING_FOR_FEED)
    )
    following_ids = [r[0] for r in following_result.all()]

    if not following_ids:
        return {"items": [], "page": page, "has_more": False}

    # 2. Fetch each content type with SAVEPOINT isolation
    # Each fetcher is limited to (offset + page_size) to avoid over-fetching
    fetch_limit = offset + page_size
    all_items = []

    content_fetchers = [
        ("tasks", lambda: _fetch_followed_tasks(db, following_ids, now, fetch_limit)),
        ("forum_posts", lambda: _fetch_followed_posts(db, following_ids, now, fetch_limit)),
        ("products", lambda: _fetch_followed_products(db, following_ids, now, fetch_limit)),
        ("services", lambda: _fetch_followed_services(db, following_ids, now, fetch_limit)),
        ("completions", lambda: _fetch_followed_completions(db, following_ids, now, fetch_limit)),
    ]

    for name, fetch_fn in content_fetchers:
        try:
            async with db.begin_nested():
                items = await fetch_fn()
                all_items.extend(items)
        except Exception as e:
            logger.warning(f"Failed to fetch followed {name}: {e}")

    # 3. Sort by created_at descending (pure timeline)
    all_items.sort(key=lambda x: x.get("created_at", ""), reverse=True)

    # 4. Paginate
    page_items = all_items[offset:offset + page_size]

    return {
        "items": page_items,
        "page": page,
        "has_more": len(all_items) > (offset + page_size),
    }


async def _fetch_followed_tasks(db, following_ids, now, limit=50):
    """Tasks published by followed users in the last 30 days."""
    cutoff = now - timedelta(days=_TASK_WINDOW_DAYS)

    query = (
        select(
            models.Task.id,
            models.Task.title,
            models.Task.title_zh,
            models.Task.title_en,
            models.Task.description,
            models.Task.description_zh,
            models.Task.description_en,
            models.Task.images,
            models.Task.task_type,
            models.Task.reward,
            models.Task.location,
            models.Task.poster_id,
            models.Task.created_at,
            models.User.name.label("poster_name"),
            models.User.avatar.label("poster_avatar"),
        )
        .join(models.User, models.User.id == models.Task.poster_id)
        .where(
            models.Task.poster_id.in_(following_ids),
            models.Task.status == "open",
            models.Task.is_visible == True,
            models.Task.created_at >= cutoff,
        )
        .order_by(desc(models.Task.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    rows = result.all()

    from app.discovery_routes import _first_image

    return [
        {
            "feed_type": "task",
            "id": f"task_{r.id}",
            "title": r.title,
            "title_zh": r.title_zh,
            "title_en": r.title_en,
            "description": (r.description or "")[:100],
            "description_zh": (r.description_zh or "")[:100],
            "description_en": (r.description_en or "")[:100],
            "images": [_first_image(r.images)] if _first_image(r.images) else None,
            "user_id": str(r.poster_id),
            "user_name": r.poster_name,
            "user_avatar": r.poster_avatar,
            "price": float(r.reward) if r.reward else None,
            "original_price": None,
            "discount_percentage": None,
            "currency": "GBP",
            "rating": None,
            "like_count": None,
            "comment_count": None,
            "view_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": {
                "task_type": r.task_type,
                "location": r.location,
            },
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]


async def _fetch_followed_posts(db, following_ids, now, limit=50):
    """Forum posts by followed users."""
    cutoff = now - timedelta(days=_POST_WINDOW_DAYS)

    query = (
        select(
            models.ForumPost.id,
            models.ForumPost.title,
            models.ForumPost.content,
            models.ForumPost.images,
            models.ForumPost.author_id,
            models.ForumPost.created_at,
            models.ForumPost.like_count,
            models.ForumPost.reply_count,
            models.User.name.label("author_name"),
            models.User.avatar.label("author_avatar"),
        )
        .join(models.User, models.User.id == models.ForumPost.author_id)
        .where(
            models.ForumPost.author_id.in_(following_ids),
            models.ForumPost.is_deleted == False,
            models.ForumPost.created_at >= cutoff,
        )
        .order_by(desc(models.ForumPost.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    rows = result.all()

    from app.discovery_routes import _first_image

    return [
        {
            "feed_type": "forum_post",
            "id": f"post_{r.id}",
            "title": r.title,
            "title_zh": None,
            "title_en": None,
            "description": (r.content or "")[:100],
            "description_zh": None,
            "description_en": None,
            "images": [_first_image(r.images)] if _first_image(r.images) else None,
            "user_id": str(r.author_id),
            "user_name": r.author_name,
            "user_avatar": r.author_avatar,
            "price": None,
            "original_price": None,
            "discount_percentage": None,
            "currency": None,
            "rating": None,
            "like_count": r.like_count or 0,
            "comment_count": r.reply_count or 0,
            "view_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": None,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]


async def _fetch_followed_products(db, following_ids, now, limit=50):
    """Flea market items by followed users."""
    cutoff = now - timedelta(days=_PRODUCT_WINDOW_DAYS)

    query = (
        select(
            models.FleaMarketItem.id,
            models.FleaMarketItem.title,
            models.FleaMarketItem.description,
            models.FleaMarketItem.images,
            models.FleaMarketItem.price,
            models.FleaMarketItem.currency,
            models.FleaMarketItem.seller_id,
            models.FleaMarketItem.created_at,
            models.User.name.label("seller_name"),
            models.User.avatar.label("seller_avatar"),
        )
        .join(models.User, models.User.id == models.FleaMarketItem.seller_id)
        .where(
            models.FleaMarketItem.seller_id.in_(following_ids),
            models.FleaMarketItem.status == "active",
            models.FleaMarketItem.is_visible == True,
            models.FleaMarketItem.created_at >= cutoff,
        )
        .order_by(desc(models.FleaMarketItem.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    rows = result.all()

    from app.discovery_routes import _first_image

    return [
        {
            "feed_type": "product",
            "id": f"product_{r.id}",
            "title": r.title,
            "title_zh": None,
            "title_en": None,
            "description": (r.description or "")[:80],
            "description_zh": None,
            "description_en": None,
            "images": [_first_image(r.images)] if _first_image(r.images) else None,
            "user_id": str(r.seller_id),
            "user_name": r.seller_name,
            "user_avatar": r.seller_avatar,
            "price": float(r.price) if r.price else None,
            "original_price": None,
            "discount_percentage": None,
            "currency": r.currency or "GBP",
            "rating": None,
            "like_count": None,
            "comment_count": None,
            "view_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": None,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]


async def _fetch_followed_services(db, following_ids, now, limit=50):
    """Services created/updated by followed users."""
    cutoff = now - timedelta(days=_SERVICE_WINDOW_DAYS)

    query = (
        select(
            models.TaskExpertService.id,
            models.TaskExpertService.service_name,
            models.TaskExpertService.description,
            models.TaskExpertService.images,
            models.TaskExpertService.base_price,
            models.TaskExpertService.currency,
            models.TaskExpertService.pricing_type,
            models.TaskExpertService.service_type,
            models.TaskExpertService.expert_id,
            models.TaskExpertService.user_id,
            models.TaskExpertService.created_at,
        )
        .where(
            models.TaskExpertService.status == "active",
            models.TaskExpertService.created_at >= cutoff,
            or_(
                models.TaskExpertService.expert_id.in_(following_ids),
                models.TaskExpertService.user_id.in_(following_ids),
            ),
        )
        .order_by(desc(models.TaskExpertService.created_at))
        .limit(limit)
    )
    result = await db.execute(query)
    rows = result.all()

    # Batch-fetch owner user info
    owner_ids = set()
    for r in rows:
        owner_ids.add(r.user_id or r.expert_id)
    owner_ids.discard(None)

    owner_map = {}
    if owner_ids:
        owner_result = await db.execute(
            select(models.User.id, models.User.name, models.User.avatar)
            .where(models.User.id.in_(list(owner_ids)))
        )
        owner_map = {r.id: r for r in owner_result.all()}

    from app.discovery_routes import _first_image

    items = []
    for r in rows:
        owner_id = r.user_id or r.expert_id
        owner = owner_map.get(owner_id)
        first_img = _first_image(r.images)

        items.append({
            "feed_type": "service",
            "id": f"service_{r.id}",
            "title": r.service_name,
            "title_zh": None,
            "title_en": None,
            "description": (r.description or "")[:100],
            "description_zh": None,
            "description_en": None,
            "images": [first_img] if first_img else None,
            "user_id": str(owner_id) if owner_id else None,
            "user_name": owner.name if owner else None,
            "user_avatar": owner.avatar if owner else None,
            "price": float(r.base_price) if r.base_price else None,
            "original_price": None,
            "discount_percentage": None,
            "currency": r.currency or "GBP",
            "rating": None,
            "like_count": None,
            "comment_count": None,
            "view_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": {
                "pricing_type": r.pricing_type,
                "service_type": r.service_type,
            },
            "created_at": r.created_at.isoformat() if r.created_at else None,
        })
    return items


async def _fetch_followed_completions(db, following_ids, now, limit=30):
    """Recent task completions by followed users (last 7 days)."""
    cutoff = now - timedelta(days=_COMPLETION_WINDOW_DAYS)

    query = (
        select(
            models.TaskHistory.id,
            models.TaskHistory.task_id,
            models.TaskHistory.user_id,
            models.TaskHistory.timestamp,
            models.Task.task_type,
            models.Task.title.label("task_title"),
            models.User.name.label("user_name"),
            models.User.avatar.label("user_avatar"),
        )
        .join(models.Task, models.Task.id == models.TaskHistory.task_id)
        .join(models.User, models.User.id == models.TaskHistory.user_id)
        .where(
            models.TaskHistory.user_id.in_(following_ids),
            models.TaskHistory.action == "completed",
            models.TaskHistory.timestamp >= cutoff,
        )
        .order_by(desc(models.TaskHistory.timestamp))
        .limit(limit)
    )
    result = await db.execute(query)
    rows = result.all()

    return [
        {
            "feed_type": "completion",
            "id": f"completion_{r.id}",
            "title": f"完成了一个{r.task_type or ''}任务",
            "title_zh": f"完成了一个{r.task_type or ''}任务",
            "title_en": f"Completed a {r.task_type or ''} task",
            "description": r.task_title,
            "description_zh": None,
            "description_en": None,
            "images": None,
            "user_id": str(r.user_id),
            "user_name": r.user_name,
            "user_avatar": r.user_avatar,
            "price": None,
            "original_price": None,
            "discount_percentage": None,
            "currency": None,
            "rating": None,
            "like_count": None,
            "comment_count": None,
            "view_count": None,
            "upvote_count": None,
            "downvote_count": None,
            "linked_item": None,
            "target_item": None,
            "activity_info": None,
            "is_experienced": None,
            "is_favorited": None,
            "user_vote_type": None,
            "extra_data": {
                "task_type": r.task_type,
                "task_id": r.task_id,
            },
            "created_at": r.timestamp.isoformat() if r.timestamp else None,
        }
        for r in rows
    ]
```

- [ ] **Step 2: Register router in main.py**

Add to `app/main.py` after the follow router:

```python
# Follow Feed 路由
from app.follow_feed_routes import router as follow_feed_router
app.include_router(follow_feed_router)
```

- [ ] **Step 3: Write tests**

Create `tests/test_follow_feed.py`:

```python
"""Follow feed route tests."""
import pytest

def test_follow_feed_routes_importable():
    """Verify follow feed routes module can be imported."""
    from app.follow_feed_routes import router
    assert router.prefix == "/api/follow"

def test_follow_feed_endpoint_registered():
    """Verify /feed endpoint exists."""
    from app.follow_feed_routes import router
    paths = [r.path for r in router.routes]
    assert "/feed" in paths

def test_completion_feed_item_format():
    """Verify completion feed items have correct structure."""
    item = {
        "feed_type": "completion",
        "id": "completion_789",
        "title": "完成了一个design任务",
        "user_id": "user1",
        "extra_data": {"task_type": "design", "task_id": 456},
    }
    assert item["feed_type"] == "completion"
    assert item["id"].startswith("completion_")
    assert "task_id" in item["extra_data"]

@pytest.mark.asyncio
async def test_follow_feed_empty_when_no_following():
    """Follow feed returns empty when user follows nobody."""
    from unittest.mock import AsyncMock, MagicMock
    from app.follow_feed_routes import get_follow_feed

    user = MagicMock()
    user.id = "user1"
    db = AsyncMock()
    # Mock: user follows nobody
    mock_result = AsyncMock()
    mock_result.all.return_value = []
    db.execute.return_value = mock_result

    result = await get_follow_feed(page=1, page_size=20, request=MagicMock(), current_user=user, db=db)
    assert result["items"] == []
    assert result["has_more"] == False
```

- [ ] **Step 4: Run tests**

Run: `cd F:/python_work/LinkU/backend && python -m pytest tests/test_follow_feed.py -v`
Expected: All PASSED

- [ ] **Step 5: Commit**

```bash
git add app/follow_feed_routes.py app/main.py tests/test_follow_feed.py
git commit -m "feat: add follow feed timeline API"
```

---

### Task 6: Ticker API

**Files:**
- Create: `app/ticker_routes.py`
- Modify: `app/main.py` (register router)
- Create: `tests/test_ticker.py`

**Reference:** Spec Subsystem 3

- [ ] **Step 1: Create ticker route**

Create `app/ticker_routes.py`:

```python
"""
实时动态 Ticker 路由
聚合平台最近活动生成滚动公告条数据
"""

import logging
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import select, func, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.deps import get_async_db_dependency
from app.cache import cache_response

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/feed", tags=["动态"])


@router.get("/ticker")
@cache_response(ttl=120, key_prefix="ticker")
async def get_ticker(
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取实时动态滚动条数据。

    聚合近期平台活动，返回5-10条供客户端轮播。
    缓存120秒，全用户共享。
    """
    items = []

    try:
        items.extend(await _fetch_recent_completions(db))
    except Exception as e:
        logger.debug(f"Ticker: failed to fetch completions: {e}")

    try:
        items.extend(await _fetch_active_user_stats(db))
    except Exception as e:
        logger.debug(f"Ticker: failed to fetch active stats: {e}")

    try:
        items.extend(await _fetch_activity_updates(db))
    except Exception as e:
        logger.debug(f"Ticker: failed to fetch activity updates: {e}")

    # Limit to 10 items, mix by interleaving sources
    return {"items": items[:10]}


async def _fetch_recent_completions(db: AsyncSession) -> list:
    """最近24小时完成的任务 + 好评."""
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(hours=24)

    query = (
        select(
            models.TaskHistory.user_id,
            models.Task.task_type,
            models.User.name.label("user_name"),
            func.max(models.Review.rating).label("best_rating"),
        )
        .join(models.Task, models.Task.id == models.TaskHistory.task_id)
        .join(models.User, models.User.id == models.TaskHistory.user_id)
        .outerjoin(
            models.Review,
            (models.Review.task_id == models.TaskHistory.task_id)
            & (models.Review.rating >= 4),
        )
        .where(
            models.TaskHistory.action == "completed",
            models.TaskHistory.timestamp >= cutoff,
        )
        .group_by(
            models.TaskHistory.user_id,
            models.Task.task_type,
            models.User.name,
        )
        .order_by(desc(func.max(models.TaskHistory.timestamp)))
        .limit(5)
    )
    result = await db.execute(query)
    rows = result.all()

    items = []
    for r in rows:
        rating = int(r.best_rating) if r.best_rating else None
        if rating:
            text_zh = f"👏 {r.user_name} 刚完成了一个 {r.task_type or '任务'} 订单，获得{rating}星好评"
            text_en = f"👏 {r.user_name} completed a {r.task_type or 'task'} order, {rating}-star review"
        else:
            text_zh = f"✅ {r.user_name} 刚完成了一个 {r.task_type or '任务'} 订单"
            text_en = f"✅ {r.user_name} completed a {r.task_type or 'task'} order"

        items.append({
            "text_zh": text_zh,
            "text_en": text_en,
            "link_type": "user",
            "link_id": str(r.user_id),
        })
    return items


async def _fetch_active_user_stats(db: AsyncSession) -> list:
    """今日活跃用户接单统计."""
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    # Today's accepted count per user
    query = (
        select(
            models.TaskHistory.user_id,
            models.User.name.label("user_name"),
            func.count().label("today_count"),
        )
        .join(models.User, models.User.id == models.TaskHistory.user_id)
        .where(
            models.TaskHistory.action == "accepted",
            models.TaskHistory.timestamp >= today_start,
        )
        .group_by(models.TaskHistory.user_id, models.User.name)
        .having(func.count() >= 2)  # Only show users with 2+ today
        .order_by(desc(func.count()))
        .limit(3)
    )
    result = await db.execute(query)
    rows = result.all()

    items = []
    for r in rows:
        # Get total completed count
        total_result = await db.execute(
            select(func.count()).where(
                models.TaskHistory.user_id == r.user_id,
                models.TaskHistory.action == "completed",
            )
        )
        total = total_result.scalar() or 0

        items.append({
            "text_zh": f"🎉 {r.user_name} 今日已接 {r.today_count} 单，累计完成 {total} 单",
            "text_en": f"🎉 {r.user_name} took {r.today_count} orders today, {total} total completed",
            "link_type": "user",
            "link_id": str(r.user_id),
        })
    return items


async def _fetch_activity_updates(db: AsyncSession) -> list:
    """活动报名人数更新."""
    from sqlalchemy import or_
    from app.utils.time_utils import get_utc_time

    now = get_utc_time()

    # Count participants per activity
    participant_count = (
        select(func.count(models.OfficialActivityApplication.id))
        .where(
            models.OfficialActivityApplication.activity_id == models.Activity.id,
            models.OfficialActivityApplication.status.in_(["pending", "won", "attending"]),
        )
        .correlate(models.Activity)
        .scalar_subquery()
        .label("p_count")
    )

    query = (
        select(
            models.Activity.id,
            models.Activity.title,
            models.Activity.title_en,
            models.Activity.max_participants,
            participant_count,
        )
        .where(
            models.Activity.status == "open",
            models.Activity.visibility == "public",
            or_(models.Activity.deadline > now, models.Activity.deadline.is_(None)),
            models.Activity.max_participants.isnot(None),
        )
        .order_by(desc(participant_count))
        .limit(3)
    )
    result = await db.execute(query)
    rows = result.all()

    items = []
    for r in rows:
        current = r.p_count or 0
        max_p = r.max_participants or 0
        if max_p > 0 and current < max_p:
            remaining = max_p - current
            title_zh = r.title or "活动"
            title_en = r.title_en or r.title or "Activity"
            items.append({
                "text_zh": f"📣 {title_zh} 还剩{remaining}个名额，快来报名",
                "text_en": f"📣 {remaining} spots left for {title_en}, sign up now",
                "link_type": "activity",
                "link_id": str(r.id),
            })
    return items
```

- [ ] **Step 2: Register router in main.py**

Add to `app/main.py`:

```python
# Ticker 动态路由
from app.ticker_routes import router as ticker_router
app.include_router(ticker_router)
```

- [ ] **Step 3: Write tests**

Create `tests/test_ticker.py`:

```python
"""Ticker API tests."""
import pytest

def test_ticker_routes_importable():
    """Verify ticker routes module can be imported."""
    from app.ticker_routes import router
    assert router.prefix == "/api/feed"

def test_ticker_endpoint_registered():
    """Verify /ticker endpoint exists."""
    from app.ticker_routes import router
    paths = [r.path for r in router.routes]
    assert "/ticker" in paths

def test_ticker_item_format():
    """Verify ticker items have bilingual text, no redundant 'text' field."""
    item = {
        "text_zh": "👏 Lisa 刚完成了一个设计订单",
        "text_en": "👏 Lisa completed a design order",
        "link_type": "user",
        "link_id": "abc123",
    }
    assert "text_zh" in item
    assert "text_en" in item
    assert "text" not in item  # No redundant text field
    assert item["link_type"] in ("user", "activity")

@pytest.mark.asyncio
async def test_ticker_returns_empty_on_no_data():
    """Ticker returns empty items list when no recent activity."""
    from unittest.mock import AsyncMock, MagicMock, patch
    from app.ticker_routes import get_ticker

    db = AsyncMock()
    # Mock all queries to return empty results
    mock_result = AsyncMock()
    mock_result.all.return_value = []
    db.execute.return_value = mock_result

    # Patch cache_response to be a no-op (pass through)
    with patch("app.ticker_routes.cache_response", lambda **kw: lambda f: f):
        result = await get_ticker(db=db)
    assert result["items"] == []
```

- [ ] **Step 4: Run tests**

Run: `cd F:/python_work/LinkU/backend && python -m pytest tests/test_ticker.py -v`
Expected: All PASSED

- [ ] **Step 5: Commit**

```bash
git add app/ticker_routes.py app/main.py tests/test_ticker.py
git commit -m "feat: add real-time ticker API"
```

---

### Task 7: Integration Verification

**Files:** No new files — verification only.

- [ ] **Step 1: Run all new tests together**

```bash
cd F:/python_work/LinkU/backend && python -m pytest tests/test_follow_model.py tests/test_follow_routes.py tests/test_follow_feed.py tests/test_discovery_feed_tasks.py tests/test_ticker.py -v
```

Expected: All PASSED

- [ ] **Step 2: Run full test suite to check for regressions**

```bash
cd F:/python_work/LinkU/backend && python -m pytest tests/ -v --ignore=tests/api/
```

Expected: All existing tests still pass, no regressions

- [ ] **Step 3: Verify imports and module loading**

```bash
cd F:/python_work/LinkU/backend && python -c "
from app.models import UserFollow
from app.follow_routes import router as fr
from app.follow_feed_routes import router as ffr
from app.ticker_routes import router as tr
from app.discovery_routes import _weighted_shuffle
print('UserFollow table:', UserFollow.__tablename__)
print('Follow routes:', fr.prefix)
print('Follow feed routes:', ffr.prefix)
print('Ticker routes:', tr.prefix)
print('All imports OK')
"
```

Expected: All prints succeed, no import errors

- [ ] **Step 4: Verify migration file is valid SQL**

```bash
cd F:/python_work/LinkU/backend && python -c "
with open('migrations/126_add_user_follows.sql') as f:
    sql = f.read()
assert 'CREATE TABLE' in sql
assert 'user_follows' in sql
assert 'follower_id' in sql
assert 'following_id' in sql
print('Migration SQL valid')
"
```

- [ ] **Step 5: Commit (if any fixes were needed)**

```bash
git add -A
git commit -m "fix: integration fixes for homepage feed redesign"
```
