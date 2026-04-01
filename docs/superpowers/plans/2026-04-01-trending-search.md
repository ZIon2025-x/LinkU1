# Trending Search (热搜榜) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a trending search feature that tracks user searches, clusters similar queries via jieba, and displays a Top 10 hot search list on the Discover page.

**Architecture:** Backend logs every search to `search_logs` table with jieba tokens. A TaskScheduler hourly task clusters similar queries (Jaccard > 0.5), computes 7-day weighted scores, aggregates content view counts, and caches the Top 10 in Redis. Flutter reads the cached result via a public API endpoint.

**Tech Stack:** Python (jieba, TaskScheduler, SQLAlchemy, Redis), PostgreSQL, Flutter (BLoC, Equatable)

**Spec:** `docs/superpowers/specs/2026-04-01-trending-search-design.md`

---

### Task 1: Database Migration — search_logs, trending_blacklist, trending_pinned

**Files:**
- Create: `backend/migrations/149_add_trending_search_tables.sql`

- [ ] **Step 1: Write migration SQL**

```sql
-- 149_add_trending_search_tables.sql
-- Trending search feature: search logs, blacklist, pinned

-- Search logs table
CREATE TABLE IF NOT EXISTS search_logs (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL,
    raw_query VARCHAR(200) NOT NULL,
    tokens JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_search_logs_created_at ON search_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_search_logs_user_id ON search_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_search_logs_raw_query ON search_logs(raw_query);

-- Trending blacklist table
CREATE TABLE IF NOT EXISTS trending_blacklist (
    id SERIAL PRIMARY KEY,
    keyword VARCHAR(100) NOT NULL UNIQUE,
    created_by INTEGER REFERENCES admin_users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trending pinned table
CREATE TABLE IF NOT EXISTS trending_pinned (
    id SERIAL PRIMARY KEY,
    keyword VARCHAR(200) NOT NULL,
    display_heat VARCHAR(50) NOT NULL DEFAULT '',
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_by INTEGER REFERENCES admin_users(id) ON DELETE SET NULL,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trending_pinned_expires_at ON trending_pinned(expires_at);
```

- [ ] **Step 2: Run migration**

Run against the dev database:
```bash
cd backend
python run_migrations.py
```

- [ ] **Step 3: Commit**

```bash
git add backend/migrations/149_add_trending_search_tables.sql
git commit -m "feat: add search_logs, trending_blacklist, trending_pinned tables"
```

---

### Task 2: Backend Models — SearchLog, TrendingBlacklist, TrendingPinned

**Files:**
- Modify: `backend/app/models.py` (append new models at end)

- [ ] **Step 1: Add models to models.py**

Append at the end of `backend/app/models.py`:

```python
class SearchLog(Base):
    """搜索日志 - 记录用户搜索行为"""
    __tablename__ = "search_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    raw_query = Column(String(200), nullable=False)
    tokens = Column(JSONB, nullable=False, default=list)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)


class TrendingBlacklist(Base):
    """热搜黑名单"""
    __tablename__ = "trending_blacklist"

    id = Column(Integer, primary_key=True, index=True)
    keyword = Column(String(100), nullable=False, unique=True)
    created_by = Column(Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)


class TrendingPinned(Base):
    """热搜置顶词"""
    __tablename__ = "trending_pinned"

    id = Column(Integer, primary_key=True, index=True)
    keyword = Column(String(200), nullable=False)
    display_heat = Column(String(50), nullable=False, default="")
    sort_order = Column(Integer, nullable=False, default=0)
    created_by = Column(Integer, ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
```

- [ ] **Step 2: Verify import**

Ensure `JSONB` is already imported at the top of `models.py`. It should be:
```python
from sqlalchemy.dialects.postgresql import JSONB, INET
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/models.py
git commit -m "feat: add SearchLog, TrendingBlacklist, TrendingPinned models"
```

---

### Task 3: Backend Schemas — Trending search Pydantic models

**Files:**
- Modify: `backend/app/schemas.py` (append new schemas at end)

- [ ] **Step 1: Add schemas to schemas.py**

Append at the end of `backend/app/schemas.py`:

```python
# ==================== 热搜榜 Schemas ====================

class TrendingSearchItem(BaseModel):
    """热搜榜单项"""
    rank: int
    keyword: str
    heat_display: str  # e.g. "2.3w浏览"
    tag: Optional[str] = None  # "hot", "new", "up", or null

class TrendingSearchResponse(BaseModel):
    """热搜榜响应"""
    items: List[TrendingSearchItem]
    updated_at: Optional[str] = None

class TrendingBlacklistCreate(BaseModel):
    """添加黑名单"""
    keyword: str = Field(..., min_length=1, max_length=100)

class TrendingBlacklistItem(BaseModel):
    """黑名单项"""
    id: int
    keyword: str
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class TrendingPinnedCreate(BaseModel):
    """添加置顶词"""
    keyword: str = Field(..., min_length=1, max_length=200)
    display_heat: str = Field(default="", max_length=50)
    sort_order: int = Field(default=0)
    expires_at: Optional[datetime] = None

class TrendingPinnedItem(BaseModel):
    """置顶词项"""
    id: int
    keyword: str
    display_heat: str
    sort_order: int
    expires_at: Optional[datetime] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True
```

- [ ] **Step 2: Commit**

```bash
git add backend/app/schemas.py
git commit -m "feat: add trending search Pydantic schemas"
```

---

### Task 4: Search Logging — Record searches with jieba tokenization

**Files:**
- Create: `backend/app/trending_search.py`

This file contains the search logging function and the core trending computation logic.

- [ ] **Step 1: Install jieba**

```bash
cd backend
pip install jieba
```

Add `jieba` to `requirements.txt`.

- [ ] **Step 2: Create trending_search.py with log function**

Create `backend/app/trending_search.py`:

```python
"""热搜榜 - 搜索日志记录 & 热搜计算"""

import json
import logging
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Dict, Any

import jieba
from sqlalchemy import select, func, distinct, or_, text
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

# jieba 停用词（搜索中无意义的词）
STOP_WORDS = {
    "的", "了", "在", "是", "我", "有", "和", "就", "不", "人", "都",
    "一", "一个", "上", "也", "很", "到", "说", "要", "去", "你",
    "会", "着", "没有", "看", "好", "自己", "这", "他", "她", "它",
    "们", "那", "被", "从", "把", "让", "用", "为", "什么", "怎么",
    "如何", "哪里", "哪个", "可以", "吗", "呢", "吧", "啊",
    "找", "求", "想", "需要", "推荐", "请问", "有没有", "谁",
    "the", "a", "an", "is", "are", "was", "were", "be", "been",
    "being", "have", "has", "had", "do", "does", "did", "will",
    "would", "could", "should", "may", "might", "can", "shall",
    "to", "of", "in", "for", "on", "with", "at", "by", "from",
    "and", "or", "but", "not", "this", "that", "it", "i", "you",
    "he", "she", "we", "they", "me", "him", "her", "us", "them",
    "my", "your", "his", "its", "our", "their", "what", "which",
    "who", "how", "where", "when", "why",
}

# 最短有效 token 长度
MIN_TOKEN_LEN = 2


def tokenize_query(query: str) -> List[str]:
    """用 jieba 分词并过滤停用词，返回有意义的 token 列表"""
    words = jieba.lcut(query.strip().lower())
    tokens = [
        w.strip()
        for w in words
        if w.strip()
        and len(w.strip()) >= MIN_TOKEN_LEN
        and w.strip() not in STOP_WORDS
    ]
    return tokens


async def log_search(
    db: AsyncSession,
    raw_query: str,
    user_id: Optional[str] = None,
) -> None:
    """记录一次搜索（异步写入 search_logs）"""
    query = raw_query.strip()
    if not query or len(query) < 2:
        return

    tokens = tokenize_query(query)
    if not tokens:
        return

    log_entry = models.SearchLog(
        user_id=user_id,
        raw_query=query,
        tokens=tokens,
    )
    db.add(log_entry)
    # 不单独 commit，由调用方统一 commit 或依赖 session 自动管理
    try:
        await db.flush()
    except Exception as e:
        logger.warning(f"Failed to log search: {e}")
        await db.rollback()
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/trending_search.py backend/requirements.txt
git commit -m "feat: add search logging with jieba tokenization"
```

---

### Task 5: Embed Search Logging into Existing Search Endpoint

**Files:**
- Modify: `backend/app/forum_routes.py` (the `/search` endpoint around line 5356)

- [ ] **Step 1: Add import at top of forum_routes.py**

Add near other imports at top of `backend/app/forum_routes.py`:

```python
from app.trending_search import log_search
```

- [ ] **Step 2: Add logging call in search endpoint**

In the `search_posts` function (around line 5356), add the logging call right after the query parameter validation, before the search logic:

Find this code block inside `search_posts`:
```python
    """搜索帖子（使用 pg_trgm 相似度搜索，支持中文）"""
```

Add after the function docstring, before the search logic:

```python
    # 记录搜索日志（热搜榜数据源）
    try:
        await log_search(
            db=db,
            raw_query=q,
            user_id=current_user.id if current_user else None,
        )
    except Exception:
        pass  # 日志记录失败不影响搜索
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/forum_routes.py
git commit -m "feat: log searches in forum search endpoint for trending"
```

---

### Task 6: Trending Computation — TaskScheduler Hourly Task

**Files:**
- Modify: `backend/app/trending_search.py` (add computation functions)
- Modify: `backend/app/task_scheduler.py` (register hourly task)

- [ ] **Step 1: Add computation logic to trending_search.py**

Append to `backend/app/trending_search.py`:

```python
def jaccard_similarity(tokens_a: List[str], tokens_b: List[str]) -> float:
    """计算两个 token 列表的 Jaccard 相似度"""
    set_a = set(tokens_a)
    set_b = set(tokens_b)
    if not set_a or not set_b:
        return 0.0
    intersection = set_a & set_b
    union = set_a | set_b
    return len(intersection) / len(union)


def cluster_queries(
    query_data: List[Dict[str, Any]],
    threshold: float = 0.5,
) -> List[Dict[str, Any]]:
    """
    将相似搜索词聚类。
    query_data: [{"raw_query": str, "tokens": list, "weighted_count": float, "user_count": int}]
    返回: [{"keyword": str, "total_count": float, "members": list}]
    """
    # 按 weighted_count 降序排列，高频词优先成为簇中心
    sorted_data = sorted(query_data, key=lambda x: x["weighted_count"], reverse=True)
    clusters: List[Dict[str, Any]] = []
    used = set()

    for i, item in enumerate(sorted_data):
        if i in used:
            continue
        # 新建一个簇，以当前词为中心
        cluster = {
            "keyword": item["raw_query"],
            "total_count": item["weighted_count"],
            "members": [item["raw_query"]],
        }
        used.add(i)

        for j, other in enumerate(sorted_data):
            if j in used:
                continue
            sim = jaccard_similarity(item["tokens"], other["tokens"])
            if sim >= threshold:
                cluster["total_count"] += other["weighted_count"]
                cluster["members"].append(other["raw_query"])
                used.add(j)

        clusters.append(cluster)

    # 按合并后的总热度降序
    clusters.sort(key=lambda x: x["total_count"], reverse=True)
    return clusters


def format_heat_display(view_count: int) -> str:
    """将数字格式化为热度展示文案，如 '2.3w浏览'"""
    if view_count >= 10000:
        val = view_count / 10000
        if val == int(val):
            return f"{int(val)}w浏览"
        return f"{val:.1f}w浏览"
    elif view_count >= 1000:
        val = view_count / 1000
        if val == int(val):
            return f"{int(val)}k浏览"
        return f"{val:.1f}k浏览"
    else:
        return f"{view_count}浏览"


def compute_trending(db: "Session") -> List[Dict[str, Any]]:
    """
    同步版本：计算热搜榜 Top10。供 TaskScheduler with_db 调用。
    返回: [{"rank": 1, "keyword": "...", "heat_display": "...", "tag": "hot"|"new"|"up"|null, "search_count": int}]
    """
    now = get_utc_time()
    db_session = db
    seven_days_ago = now - timedelta(days=7)
    fourteen_days_ago = now - timedelta(days=14)

    # ---- Step 1: 取最近7天搜索日志，按 raw_query 分组 ----
    current_window_rows = db_session.execute(
        select(
            models.SearchLog.raw_query,
            models.SearchLog.tokens,
            func.count().label("search_count"),
            func.count(distinct(models.SearchLog.user_id)).label("user_count"),
            # 按天加权：提取天数差，权重 = 8 - 天数差
            func.sum(
                8 - func.extract("day", now - models.SearchLog.created_at)
            ).label("weighted_count"),
        )
        .where(models.SearchLog.created_at >= seven_days_ago)
        .group_by(models.SearchLog.raw_query, models.SearchLog.tokens)
        .having(func.count(distinct(models.SearchLog.user_id)) >= 3)
    ).all()

    if not current_window_rows:
        return []

    query_data = []
    for row in current_window_rows:
        tokens = row.tokens if isinstance(row.tokens, list) else json.loads(row.tokens)
        query_data.append({
            "raw_query": row.raw_query,
            "tokens": tokens,
            "weighted_count": float(row.weighted_count or 0),
            "user_count": row.user_count,
        })

    # ---- Step 2: 聚类合并 ----
    clusters = cluster_queries(query_data, threshold=0.5)

    # ---- Step 3: 过滤黑名单 ----
    blacklist_rows = db_session.execute(
        select(models.TrendingBlacklist.keyword)
    ).all()
    blacklist_words = {row.keyword.lower() for row in blacklist_rows}

    filtered = []
    for c in clusters:
        keyword_lower = c["keyword"].lower()
        if any(bw in keyword_lower for bw in blacklist_words):
            continue
        filtered.append(c)

    # ---- Step 4: 计算浏览量（相关内容 view_count 总和）----
    for c in filtered[:10]:
        tokens = tokenize_query(c["keyword"])
        total_views = 0

        # 搜索 forum_posts 标题匹配
        for token in tokens:
            like_pattern = f"%{token}%"
            result = db_session.execute(
                select(func.coalesce(func.sum(models.ForumPost.view_count), 0))
                .where(
                    models.ForumPost.is_deleted == False,
                    or_(
                        models.ForumPost.title.ilike(like_pattern),
                        models.ForumPost.title_zh.ilike(like_pattern),
                        models.ForumPost.title_en.ilike(like_pattern),
                    )
                )
            ).scalar()
            total_views += int(result or 0)

        # 搜索 tasks 标题匹配
        for token in tokens:
            like_pattern = f"%{token}%"
            result = db_session.execute(
                select(func.coalesce(func.sum(models.Task.view_count), 0))
                .where(
                    or_(
                        models.Task.title.ilike(like_pattern),
                        models.Task.title_zh.ilike(like_pattern),
                        models.Task.title_en.ilike(like_pattern),
                    )
                )
            ).scalar()
            total_views += int(result or 0)

        c["view_count"] = total_views
        c["heat_display"] = format_heat_display(total_views)

    # ---- Step 5: 涨跌标签 ----
    # 取上一周期的 Top10 (从 Redis)
    from app.redis_pool import get_client
    redis_client = get_client(decode_responses=True)
    previous_top10 = []
    if redis_client:
        prev_data = redis_client.get("trending:previous")
        if prev_data:
            previous_top10 = json.loads(prev_data)

    prev_keywords = {item["keyword"] for item in previous_top10}
    prev_top3 = {item["keyword"] for item in previous_top10[:3]}
    prev_counts = {item["keyword"]: item.get("search_count", 0) for item in previous_top10}

    results = []
    for i, c in enumerate(filtered[:10]):
        rank = i + 1
        keyword = c["keyword"]

        # 判断标签
        tag = None
        if rank <= 3 and keyword in prev_top3:
            tag = "hot"
        elif keyword not in prev_keywords:
            tag = "new"
        else:
            prev_count = prev_counts.get(keyword, 0)
            if prev_count > 0 and c["total_count"] > prev_count * 1.5:
                tag = "up"

        results.append({
            "rank": rank,
            "keyword": keyword,
            "heat_display": c.get("heat_display", "0浏览"),
            "tag": tag,
            "search_count": int(c["total_count"]),
        })

    # ---- Step 6: 插入置顶词 ----
    pinned_rows = db_session.execute(
        select(models.TrendingPinned)
        .where(
            or_(
                models.TrendingPinned.expires_at == None,
                models.TrendingPinned.expires_at > now,
            )
        )
        .order_by(models.TrendingPinned.sort_order)
    ).scalars().all()

    for pinned in reversed(pinned_rows):
        pinned_item = {
            "rank": 0,  # will be reassigned
            "keyword": pinned.keyword,
            "heat_display": pinned.display_heat or "置顶",
            "tag": None,
            "search_count": 0,
        }
        results.insert(0, pinned_item)

    # 截取 Top10 并重新编号
    results = results[:10]
    for i, item in enumerate(results):
        item["rank"] = i + 1

    # ---- Step 7: 写入 Redis ----
    if redis_client:
        # 先把当前的存为 previous
        current_data = redis_client.get("trending:current")
        if current_data:
            redis_client.set("trending:previous", current_data, ex=604800)  # 7 days

        redis_client.set(
            "trending:current",
            json.dumps(results, ensure_ascii=False),
            ex=4200,  # 70 minutes
        )

        # 存 updated_at
        redis_client.set(
            "trending:updated_at",
            now.isoformat(),
            ex=4200,
        )

    # ---- Step 8: 清理30天前的 search_logs ----
    thirty_days_ago = now - timedelta(days=30)
    db_session.execute(
        models.SearchLog.__table__.delete().where(
            models.SearchLog.created_at < thirty_days_ago
        )
    )
    db_session.commit()

    return results
```

- [ ] **Step 2: Register task in task_scheduler.py**

In `backend/app/task_scheduler.py`, inside the `setup_scheduled_tasks()` function, add the import and registration. Place it in the low-frequency section (near other hourly tasks):

```python
    from app.trending_search import compute_trending

    # 热搜榜 - 每小时计算
    scheduler.register_task(
        'compute_trending_searches',
        with_db(compute_trending),
        interval_seconds=3600,
        description="计算热搜榜",
    )
```

Note: `compute_trending` accepts a `db: Session` parameter, which matches the `with_db` wrapper pattern that calls `func(db)`.

- [ ] **Step 3: Commit**

```bash
git add backend/app/trending_search.py backend/app/task_scheduler.py
git commit -m "feat: add hourly trending search computation task"
```

---

### Task 7: Backend API — Public Trending Endpoint + Admin Endpoints

**Files:**
- Create: `backend/app/trending_routes.py`
- Modify: `backend/app/main.py` (register router)

- [ ] **Step 1: Create trending_routes.py**

Create `backend/app/trending_routes.py`:

```python
"""热搜榜 API 路由"""

import json
import logging
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app import models, schemas
from app.database import get_async_db_dependency
from app.redis_pool import get_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/trending", tags=["热搜榜"])


# ==================== 公开接口 ====================

@router.get("/searches", response_model=schemas.TrendingSearchResponse)
async def get_trending_searches():
    """获取热搜榜 Top10（公开，读 Redis 缓存）"""
    redis_client = get_client(decode_responses=True)
    if not redis_client:
        return schemas.TrendingSearchResponse(items=[], updated_at=None)

    data = redis_client.get("trending:current")
    updated_at = redis_client.get("trending:updated_at")

    if not data:
        return schemas.TrendingSearchResponse(items=[], updated_at=updated_at)

    items_raw = json.loads(data)
    items = [
        schemas.TrendingSearchItem(
            rank=item["rank"],
            keyword=item["keyword"],
            heat_display=item["heat_display"],
            tag=item.get("tag"),
        )
        for item in items_raw
    ]

    return schemas.TrendingSearchResponse(items=items, updated_at=updated_at)


# ==================== 管理员接口 ====================

async def _get_admin(request, db):
    """获取当前管理员"""
    from app.forum_routes import get_current_admin_async
    return await get_current_admin_async(request, db)


@router.get("/admin/blacklist", response_model=List[schemas.TrendingBlacklistItem])
async def list_blacklist(
    request=None,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """查看所有黑名单词"""
    await _get_admin(request, db)
    result = await db.execute(
        select(models.TrendingBlacklist).order_by(models.TrendingBlacklist.created_at.desc())
    )
    return result.scalars().all()


@router.post("/admin/blacklist", response_model=schemas.TrendingBlacklistItem, status_code=201)
async def add_blacklist(
    body: schemas.TrendingBlacklistCreate,
    request=None,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """添加黑名单词"""
    admin = await _get_admin(request, db)

    # 检查是否已存在
    existing = await db.execute(
        select(models.TrendingBlacklist).where(
            models.TrendingBlacklist.keyword == body.keyword
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Keyword already in blacklist")

    entry = models.TrendingBlacklist(
        keyword=body.keyword,
        created_by=admin.id,
    )
    db.add(entry)
    await db.commit()
    await db.refresh(entry)
    return entry


@router.delete("/admin/blacklist/{item_id}", status_code=204)
async def remove_blacklist(
    item_id: int,
    request=None,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """删除黑名单词"""
    await _get_admin(request, db)
    result = await db.execute(
        select(models.TrendingBlacklist).where(models.TrendingBlacklist.id == item_id)
    )
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Not found")
    await db.delete(entry)
    await db.commit()


@router.get("/admin/pinned", response_model=List[schemas.TrendingPinnedItem])
async def list_pinned(
    request=None,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """查看所有置顶词"""
    await _get_admin(request, db)
    result = await db.execute(
        select(models.TrendingPinned).order_by(models.TrendingPinned.sort_order)
    )
    return result.scalars().all()


@router.post("/admin/pinned", response_model=schemas.TrendingPinnedItem, status_code=201)
async def add_pinned(
    body: schemas.TrendingPinnedCreate,
    request=None,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """添加置顶词"""
    admin = await _get_admin(request, db)
    entry = models.TrendingPinned(
        keyword=body.keyword,
        display_heat=body.display_heat,
        sort_order=body.sort_order,
        created_by=admin.id,
        expires_at=body.expires_at,
    )
    db.add(entry)
    await db.commit()
    await db.refresh(entry)
    return entry


@router.delete("/admin/pinned/{item_id}", status_code=204)
async def remove_pinned(
    item_id: int,
    request=None,
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """删除置顶词"""
    await _get_admin(request, db)
    result = await db.execute(
        select(models.TrendingPinned).where(models.TrendingPinned.id == item_id)
    )
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Not found")
    await db.delete(entry)
    await db.commit()
```

- [ ] **Step 2: Register router in main.py**

Add in `backend/app/main.py` near other router imports:

```python
from app.trending_routes import router as trending_router
```

Add near other `app.include_router` calls:

```python
app.include_router(trending_router)
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/trending_routes.py backend/app/main.py
git commit -m "feat: add trending search API endpoints (public + admin)"
```

---

### Task 8: Flutter — TrendingSearch Model + API Endpoint

**Files:**
- Create: `link2ur/lib/data/models/trending_search.dart`
- Modify: `link2ur/lib/core/constants/api_endpoints.dart`

- [ ] **Step 1: Create TrendingSearch model**

Create `link2ur/lib/data/models/trending_search.dart`:

```dart
import 'package:equatable/equatable.dart';

class TrendingSearchItem extends Equatable {
  final int rank;
  final String keyword;
  final String heatDisplay;
  final String? tag; // "hot", "new", "up", or null

  const TrendingSearchItem({
    required this.rank,
    required this.keyword,
    required this.heatDisplay,
    this.tag,
  });

  factory TrendingSearchItem.fromJson(Map<String, dynamic> json) {
    return TrendingSearchItem(
      rank: json['rank'] as int? ?? 0,
      keyword: json['keyword'] as String? ?? '',
      heatDisplay: json['heat_display'] as String? ?? '',
      tag: json['tag'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'keyword': keyword,
    'heat_display': heatDisplay,
    'tag': tag,
  };

  @override
  List<Object?> get props => [rank, keyword, heatDisplay, tag];
}

class TrendingSearchResponse extends Equatable {
  final List<TrendingSearchItem> items;
  final String? updatedAt;

  const TrendingSearchResponse({
    required this.items,
    this.updatedAt,
  });

  factory TrendingSearchResponse.fromJson(Map<String, dynamic> json) {
    return TrendingSearchResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => TrendingSearchItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      updatedAt: json['updated_at'] as String?,
    );
  }

  @override
  List<Object?> get props => [items, updatedAt];
}
```

- [ ] **Step 2: Add endpoint constant**

In `link2ur/lib/core/constants/api_endpoints.dart`, add near forum endpoints:

```dart
  static const String trendingSearches = '/api/trending/searches';
```

- [ ] **Step 3: Commit**

```bash
git add link2ur/lib/data/models/trending_search.dart link2ur/lib/core/constants/api_endpoints.dart
git commit -m "feat: add TrendingSearch model and API endpoint constant"
```

---

### Task 9: Flutter — TrendingSearch Repository

**Files:**
- Create: `link2ur/lib/data/repositories/trending_search_repository.dart`

- [ ] **Step 1: Create repository**

Create `link2ur/lib/data/repositories/trending_search_repository.dart`:

```dart
import '../models/trending_search.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

class TrendingSearchRepository {
  final ApiService _apiService;

  TrendingSearchRepository({required ApiService apiService})
      : _apiService = apiService;

  Future<TrendingSearchResponse> getTrendingSearches() async {
    final response = await _apiService.get(
      ApiEndpoints.trendingSearches,
      extra: {'skipAuth': true},
    );
    return TrendingSearchResponse.fromJson(response.data);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add link2ur/lib/data/repositories/trending_search_repository.dart
git commit -m "feat: add TrendingSearchRepository"
```

---

### Task 10: Flutter — Integrate Trending Data into HomeBloc

**Files:**
- Modify: `link2ur/lib/features/home/bloc/home_bloc.dart` (add event, state field, handler)
- Modify: `link2ur/lib/app_providers.dart` (register repository)

This task adds trending search data loading to the existing HomeBloc rather than creating a new BLoC, since the trending list is just one section on the home/discover page.

- [ ] **Step 1: Add state field and event**

In the HomeBloc file, add a new event:

```dart
class HomeLoadTrendingSearches extends HomeEvent {
  const HomeLoadTrendingSearches();
}
```

Add to HomeState:

```dart
final List<TrendingSearchItem> trendingSearches;
```

With default `const []` in constructor and included in `copyWith`.

- [ ] **Step 2: Add repository to HomeBloc constructor and handler**

Add `TrendingSearchRepository` as a parameter to HomeBloc. Add handler:

```dart
Future<void> _onLoadTrendingSearches(
  HomeLoadTrendingSearches event,
  Emitter<HomeState> emit,
) async {
  try {
    final response = await _trendingSearchRepository.getTrendingSearches();
    emit(state.copyWith(trendingSearches: response.items));
  } catch (e) {
    // 热搜加载失败不影响主页其他内容
    AppLogger.error('Failed to load trending searches', e);
  }
}
```

- [ ] **Step 3: Register repository in app_providers.dart**

In `app_providers.dart`, create `TrendingSearchRepository` instance and pass it to HomeBloc:

```dart
final trendingSearchRepository = TrendingSearchRepository(apiService: apiService);
```

- [ ] **Step 4: Dispatch event on home load**

In the existing `_onLoadRequested` handler (or wherever `HomeLoadRequested` is handled), add:

```dart
add(const HomeLoadTrendingSearches());
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/home/bloc/home_bloc.dart link2ur/lib/app_providers.dart
git commit -m "feat: integrate trending search loading into HomeBloc"
```

---

### Task 11: Flutter — Trending Search UI Widget on Discover Page

**Files:**
- Modify: `link2ur/lib/features/forum/views/forum_view.dart` (add trending section to discover page)

- [ ] **Step 1: Add trending search list widget**

In `forum_view.dart`, add a `_TrendingSearchSection` widget that reads `HomeBloc` state and renders the trending list. It should match the mockup layout:

```dart
class _TrendingSearchSection extends StatelessWidget {
  const _TrendingSearchSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (prev, curr) => prev.trendingSearches != curr.trendingSearches,
      builder: (context, state) {
        final items = state.trendingSearches;
        if (items.isEmpty) return const SizedBox.shrink();

        return Container(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title
              Row(
                children: [
                  const Text('🔥 ', style: TextStyle(fontSize: 17)),
                  Text(
                    context.l10n.trendingSearchTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 6),
              // Trending items
              ...items.map((item) => _TrendingItem(item: item)),
            ],
          ),
        );
      },
    );
  }
}

class _TrendingItem extends StatelessWidget {
  final TrendingSearchItem item;
  const _TrendingItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTop3 = item.rank <= 3;

    return InkWell(
      onTap: () {
        // 点击跳转搜索结果页
        context.push('/search', extra: item.keyword);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 24,
              child: Text(
                '${item.rank}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isTop3 ? AppColors.error : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Keyword
            Expanded(
              child: Text(
                item.keyword,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Tag badge
            if (item.tag != null) ...[
              const SizedBox(width: 8),
              _TagBadge(tag: item.tag!),
            ],
            const SizedBox(width: 8),
            // Heat display
            Text(
              item.heatDisplay,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final String tag;
  const _TagBadge({required this.tag});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bgColor;
    Color textColor;

    switch (tag) {
      case 'hot':
        label = '🔥 热';
        bgColor = const Color(0xFFFFF0F0);
        textColor = const Color(0xFFFF2D55);
        break;
      case 'new':
        label = 'NEW';
        bgColor = const Color(0xFFEBF2FF);
        textColor = const Color(0xFF007AFF);
        break;
      case 'up':
        label = '↑ 升';
        bgColor = const Color(0xFFE8F8EF);
        textColor = const Color(0xFF26BF73);
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Insert section into the forum/discover page**

Place `_TrendingSearchSection()` in the forum view's scrollable content, before the forum categories list.

- [ ] **Step 3: Add l10n strings**

Add to all three ARB files:

```json
"trendingSearchTitle": "热搜榜"
```

English: `"Trending Searches"`, Traditional Chinese: `"熱搜榜"`

- [ ] **Step 4: Run gen-l10n**

```bash
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter gen-l10n
```

- [ ] **Step 5: Commit**

```bash
git add link2ur/lib/features/forum/views/forum_view.dart link2ur/lib/l10n/
git commit -m "feat: add trending search section to discover page UI"
```

---

### Task 12: Verify End-to-End

- [ ] **Step 1: Run flutter analyze**

```bash
cd link2ur
$env:PATH = "F:\flutter\bin;" + $env:PATH; $env:PUB_CACHE = "F:\DevCache\.pub-cache"; flutter analyze
```

Fix any issues.

- [ ] **Step 2: Verify backend starts**

```bash
cd backend
python -c "from app.trending_search import tokenize_query, compute_trending; print('Import OK')"
python -c "from app.trending_routes import router; print('Router OK')"
```

- [ ] **Step 3: Test jieba tokenization**

```bash
cd backend
python -c "
from app.trending_search import tokenize_query, jaccard_similarity
t1 = tokenize_query('毕业照跟拍 伦敦')
t2 = tokenize_query('伦敦毕业照')
print(f'Tokens 1: {t1}')
print(f'Tokens 2: {t2}')
print(f'Jaccard: {jaccard_similarity(t1, t2)}')
"
```

Expected: Jaccard > 0.5, confirming the two queries would be clustered together.

- [ ] **Step 4: Final commit if any fixes**

```bash
git add -A
git commit -m "fix: address trending search integration issues"
```
