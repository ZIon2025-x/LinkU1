# Ticker 新增 5 类实时数据源

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为首页 ticker 滚动公告栏新增 5 类实时数据源，让公告内容更丰富、更有吸引力。

**Architecture:** 在现有 `backend/app/ticker_routes.py` 中新增 5 个 `_fetch_*` 函数，遵循已有模式（查询 DB → 构建双语文本 → 返回 item 列表）。在主接口 `get_ticker` 中聚合所有数据源，并调整最终混合与排序策略。

**Tech Stack:** FastAPI, SQLAlchemy async, 现有 models

---

## 文件变更

- **Modify:** `backend/app/ticker_routes.py` — 新增 5 个数据源函数 + 更新主接口聚合逻辑

---

### Task 1: 新发布任务 `_fetch_new_tasks`

**Files:**
- Modify: `backend/app/ticker_routes.py`

- [ ] **Step 1: 在 `_fetch_activity_spots` 之后添加 `_fetch_new_tasks` 函数**

```python
async def _fetch_new_tasks(db: AsyncSession) -> list:
    """数据源4：最近6小时新发布的任务"""
    try:
        now = get_utc_time()
        since = now - timedelta(hours=6)

        stmt = (
            select(
                models.Task.id,
                models.Task.title,
                models.Task.title_en,
                models.Task.task_type,
                models.Task.reward,
                models.Task.currency,
                models.User.name.label("poster_name"),
            )
            .join(models.User, models.Task.poster_id == models.User.id)
            .where(
                models.Task.status == "open",
                models.Task.created_at >= since,
            )
            .order_by(desc(models.Task.created_at))
            .limit(5)
        )

        result = await db.execute(stmt)
        rows = result.all()

        items = []
        for row in rows:
            title_zh = row.title
            title_en = row.title_en or row.title
            reward = int(row.reward) if row.reward == int(row.reward) else row.reward
            currency = row.currency or "GBP"
            symbol = "€" if currency == "EUR" else "£"

            items.append(
                {
                    "text_zh": f"📝 {row.poster_name} 发布了新任务「{title_zh}」赏金{symbol}{reward}",
                    "text_en": f"📝 {row.poster_name} posted a new task \"{title_en}\" — {symbol}{reward}",
                    "link_type": "task",
                    "link_id": str(row.id),
                }
            )

        return items
    except Exception as e:
        logger.warning(f"Ticker: failed to fetch new tasks: {e}")
        return []
```

- [ ] **Step 2: 验证语法正确**

Run: `cd F:/python_work/LinkU && python -c "import ast; ast.parse(open('backend/app/ticker_routes.py').read()); print('OK')"`
Expected: `OK`

---

### Task 2: 热门论坛帖子 `_fetch_trending_posts`

**Files:**
- Modify: `backend/app/ticker_routes.py`

- [ ] **Step 1: 添加 `_fetch_trending_posts` 函数**

```python
async def _fetch_trending_posts(db: AsyncSession) -> list:
    """数据源5：最近24小时内点赞数较高的论坛帖子"""
    try:
        now = get_utc_time()
        since = now - timedelta(hours=24)

        stmt = (
            select(
                models.ForumPost.id,
                models.ForumPost.title,
                models.ForumPost.title_en,
                models.ForumPost.like_count,
                models.User.name.label("author_name"),
            )
            .join(models.User, models.ForumPost.author_id == models.User.id)
            .where(
                models.ForumPost.is_visible == True,
                models.ForumPost.created_at >= since,
                models.ForumPost.like_count >= 3,
            )
            .order_by(desc(models.ForumPost.like_count))
            .limit(3)
        )

        result = await db.execute(stmt)
        rows = result.all()

        items = []
        for row in rows:
            title_zh = row.title
            title_en = row.title_en or row.title
            likes = row.like_count

            items.append(
                {
                    "text_zh": f"🔥 {row.author_name} 的帖子「{title_zh}」获得了 {likes} 个点赞",
                    "text_en": f"🔥 {row.author_name}'s post \"{title_en}\" got {likes} likes",
                    "link_type": "forum_post",
                    "link_id": str(row.id),
                }
            )

        return items
    except Exception as e:
        logger.warning(f"Ticker: failed to fetch trending posts: {e}")
        return []
```

- [ ] **Step 2: 验证语法正确**

Run: `cd F:/python_work/LinkU && python -c "import ast; ast.parse(open('backend/app/ticker_routes.py').read()); print('OK')"`
Expected: `OK`

---

### Task 3: 跳蚤市场动态 `_fetch_flea_market_activity`

**Files:**
- Modify: `backend/app/ticker_routes.py`

- [ ] **Step 1: 添加 `_fetch_flea_market_activity` 函数**

```python
async def _fetch_flea_market_activity(db: AsyncSession) -> list:
    """数据源6：跳蚤市场 — 新上架商品 + 最近售出"""
    try:
        now = get_utc_time()
        since = now - timedelta(hours=12)
        items = []

        # 新上架
        new_stmt = (
            select(
                models.FleaMarketItem.id,
                models.FleaMarketItem.title,
                models.FleaMarketItem.price,
                models.FleaMarketItem.currency,
                models.User.name.label("seller_name"),
            )
            .join(models.User, models.FleaMarketItem.seller_id == models.User.id)
            .where(
                models.FleaMarketItem.status == "active",
                models.FleaMarketItem.is_visible == True,
                models.FleaMarketItem.created_at >= since,
            )
            .order_by(desc(models.FleaMarketItem.created_at))
            .limit(3)
        )

        new_result = await db.execute(new_stmt)
        for row in new_result.all():
            price = int(row.price) if row.price == int(row.price) else row.price
            currency = row.currency or "GBP"
            symbol = "€" if currency == "EUR" else "£"
            items.append(
                {
                    "text_zh": f"🛒 {row.seller_name} 刚上架了「{row.title}」{symbol}{price}",
                    "text_en": f"🛒 {row.seller_name} listed \"{row.title}\" for {symbol}{price}",
                    "link_type": "flea_market",
                    "link_id": str(row.id),
                }
            )

        # 最近售出
        sold_stmt = (
            select(
                models.FleaMarketItem.id,
                models.FleaMarketItem.title,
                models.User.name.label("seller_name"),
            )
            .join(models.User, models.FleaMarketItem.seller_id == models.User.id)
            .where(
                models.FleaMarketItem.status == "sold",
                models.FleaMarketItem.updated_at >= since,
            )
            .order_by(desc(models.FleaMarketItem.updated_at))
            .limit(2)
        )

        sold_result = await db.execute(sold_stmt)
        for row in sold_result.all():
            items.append(
                {
                    "text_zh": f"🎉 {row.seller_name} 的「{row.title}」已售出",
                    "text_en": f"🎉 {row.seller_name}'s \"{row.title}\" just sold",
                    "link_type": "flea_market",
                    "link_id": str(row.id),
                }
            )

        return items
    except Exception as e:
        logger.warning(f"Ticker: failed to fetch flea market activity: {e}")
        return []
```

- [ ] **Step 2: 验证语法正确**

Run: `cd F:/python_work/LinkU && python -c "import ast; ast.parse(open('backend/app/ticker_routes.py').read()); print('OK')"`
Expected: `OK`

---

### Task 4: 学生认证动态 `_fetch_student_verifications`

**Files:**
- Modify: `backend/app/ticker_routes.py`

- [ ] **Step 1: 添加 `_fetch_student_verifications` 函数**

```python
async def _fetch_student_verifications(db: AsyncSession) -> list:
    """数据源7：最近7天按学校聚合的学生认证数"""
    try:
        now = get_utc_time()
        since = now - timedelta(days=7)

        stmt = (
            select(
                models.University.name,
                models.University.name_cn,
                func.count(models.StudentVerification.id).label("count"),
            )
            .join(
                models.University,
                models.StudentVerification.university_id == models.University.id,
            )
            .where(
                models.StudentVerification.status == "verified",
                models.StudentVerification.verified_at >= since,
            )
            .group_by(models.University.id, models.University.name, models.University.name_cn)
            .order_by(desc(func.count(models.StudentVerification.id)))
            .limit(3)
        )

        result = await db.execute(stmt)
        rows = result.all()

        items = []
        for row in rows:
            count = row.count
            name_en = row.name
            name_zh = row.name_cn or row.name

            items.append(
                {
                    "text_zh": f"🎓 本周有 {count} 位 {name_zh} 同学完成了学生认证",
                    "text_en": f"🎓 {count} student(s) from {name_en} verified this week",
                    "link_type": None,
                    "link_id": None,
                }
            )

        return items
    except Exception as e:
        logger.warning(f"Ticker: failed to fetch student verifications: {e}")
        return []
```

- [ ] **Step 2: 验证语法正确**

Run: `cd F:/python_work/LinkU && python -c "import ast; ast.parse(open('backend/app/ticker_routes.py').read()); print('OK')"`
Expected: `OK`

---

### Task 5: 排行榜动态 `_fetch_leaderboard_updates`

**Files:**
- Modify: `backend/app/ticker_routes.py`

- [ ] **Step 1: 添加 `_fetch_leaderboard_updates` 函数**

```python
async def _fetch_leaderboard_updates(db: AsyncSession) -> list:
    """数据源8：排行榜上近期投票热度最高的条目"""
    try:
        now = get_utc_time()
        since = now - timedelta(days=3)

        stmt = (
            select(
                models.LeaderboardItem.id,
                models.LeaderboardItem.name.label("item_name"),
                models.LeaderboardItem.net_votes,
                models.CustomLeaderboard.id.label("lb_id"),
                models.CustomLeaderboard.name.label("lb_name"),
                models.CustomLeaderboard.name_zh.label("lb_name_zh"),
            )
            .join(
                models.CustomLeaderboard,
                models.LeaderboardItem.leaderboard_id == models.CustomLeaderboard.id,
            )
            .where(
                models.CustomLeaderboard.status == "active",
                models.LeaderboardItem.status == "approved",
                models.LeaderboardItem.updated_at >= since,
                models.LeaderboardItem.net_votes >= 3,
            )
            .order_by(desc(models.LeaderboardItem.net_votes))
            .limit(3)
        )

        result = await db.execute(stmt)
        rows = result.all()

        items = []
        for row in rows:
            lb_name_zh = row.lb_name_zh or row.lb_name
            lb_name_en = row.lb_name
            votes = row.net_votes

            items.append(
                {
                    "text_zh": f"🏆 「{row.item_name}」在「{lb_name_zh}」排行榜获得 {votes} 票",
                    "text_en": f"🏆 \"{row.item_name}\" got {votes} votes on \"{lb_name_en}\" leaderboard",
                    "link_type": "leaderboard",
                    "link_id": str(row.lb_id),
                }
            )

        return items
    except Exception as e:
        logger.warning(f"Ticker: failed to fetch leaderboard updates: {e}")
        return []
```

- [ ] **Step 2: 验证语法正确**

Run: `cd F:/python_work/LinkU && python -c "import ast; ast.parse(open('backend/app/ticker_routes.py').read()); print('OK')"`
Expected: `OK`

---

### Task 6: 更新主接口聚合逻辑

**Files:**
- Modify: `backend/app/ticker_routes.py` — `get_ticker` 函数

- [ ] **Step 1: 用 `asyncio.gather` 并行调用所有 8 个数据源，替换原来的顺序调用**

需要在文件顶部添加 `import asyncio` 和 `import random`。

将 `get_ticker` 函数替换为：

```python
@router.get("/ticker")
@cache_response(ttl=120, key_prefix="ticker")
async def get_ticker(
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取首页滚动公告栏动态数据（公开接口，无需登录）

    聚合八类平台活动：
    - 最近24小时完成的好评订单
    - 今日活跃接单用户统计
    - 有剩余名额的公开活动
    - 最近6小时新发布的任务
    - 热门论坛帖子
    - 跳蚤市场新上架/售出
    - 近一周学生认证统计
    - 排行榜热门条目
    """
    (
        completions,
        active_users,
        activities,
        new_tasks,
        trending_posts,
        flea_market,
        verifications,
        leaderboard,
    ) = await asyncio.gather(
        _fetch_recent_completions(db),
        _fetch_active_user_stats(db),
        _fetch_activity_spots(db),
        _fetch_new_tasks(db),
        _fetch_trending_posts(db),
        _fetch_flea_market_activity(db),
        _fetch_student_verifications(db),
        _fetch_leaderboard_updates(db),
    )

    # 每类最多取 2 条，确保类型多样性
    sources = [
        completions, active_users, activities, new_tasks,
        trending_posts, flea_market, verifications, leaderboard,
    ]
    all_items = []
    for source in sources:
        all_items.extend(source[:2])

    # 打散顺序，避免同类扎堆
    random.shuffle(all_items)

    return {"items": all_items[:12]}
```

- [ ] **Step 2: 验证语法正确**

Run: `cd F:/python_work/LinkU && python -c "import ast; ast.parse(open('backend/app/ticker_routes.py').read()); print('OK')"`
Expected: `OK`

- [ ] **Step 3: 提交**

```bash
git add backend/app/ticker_routes.py
git commit -m "feat(ticker): add 5 new real-time data sources for homepage ticker"
```
