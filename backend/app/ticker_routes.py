"""
Ticker 动态路由
为首页滚动公告栏提供实时平台活动聚合数据
"""

import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import select, func, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.deps import get_async_db_dependency
from app.cache import cache_response
from app import models
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/feed", tags=["动态"])


# ==================== 数据源函数 ====================


async def _fetch_recent_completions(db: AsyncSession) -> list:
    """数据源1：最近24小时内有好评的完成订单"""
    try:
        now = get_utc_time()
        since = now - timedelta(hours=24)

        # TaskHistory(completed) JOIN Task JOIN User LEFT JOIN Review(rating>=4)
        stmt = (
            select(
                models.User.id.label("user_id"),
                models.User.name.label("user_name"),
                models.Task.task_type,
                func.max(models.Review.rating).label("rating"),
            )
            .select_from(models.TaskHistory)
            .join(models.Task, models.TaskHistory.task_id == models.Task.id)
            .join(models.User, models.TaskHistory.user_id == models.User.id)
            .outerjoin(
                models.Review,
                (models.Review.task_id == models.Task.id)
                & (models.Review.rating >= 4),
            )
            .where(
                models.TaskHistory.action == "completed",
                models.TaskHistory.timestamp >= since,
            )
            .group_by(
                models.User.id,
                models.User.name,
                models.Task.task_type,
            )
            .order_by(desc(func.max(models.TaskHistory.timestamp)))
            .limit(5)
        )

        result = await db.execute(stmt)
        rows = result.all()

        items = []
        for row in rows:
            user_id = row.user_id
            user_name = row.user_name
            task_type = row.task_type or "未知"
            rating = row.rating

            if rating:
                rating_int = int(rating)
                text_zh = f"👏 {user_name} 刚完成了一个 {task_type} 订单，获得{rating_int}星好评"
                text_en = f"👏 {user_name} completed a {task_type} order with a {rating_int}-star review"
            else:
                text_zh = f"✅ {user_name} 刚完成了一个 {task_type} 订单"
                text_en = f"✅ {user_name} just completed a {task_type} order"

            items.append(
                {
                    "text_zh": text_zh,
                    "text_en": text_en,
                    "link_type": "user",
                    "link_id": user_id,
                }
            )

        return items
    except Exception as e:
        logger.warning(f"Ticker: failed to fetch recent completions: {e}")
        return []


async def _fetch_active_user_stats(db: AsyncSession) -> list:
    """数据源2：今日活跃用户统计（今日接单>=2单的用户）"""
    try:
        now = get_utc_time()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

        # 今日接单>=2的用户及其今日接单数
        accepted_stmt = (
            select(
                models.TaskHistory.user_id,
                func.count(models.TaskHistory.id).label("today_count"),
            )
            .where(
                models.TaskHistory.action == "accepted",
                models.TaskHistory.timestamp >= today_start,
                models.TaskHistory.user_id.isnot(None),
            )
            .group_by(models.TaskHistory.user_id)
            .having(func.count(models.TaskHistory.id) >= 2)
            .order_by(desc(func.count(models.TaskHistory.id)))
            .limit(3)
        )

        accepted_result = await db.execute(accepted_stmt)
        accepted_rows = accepted_result.all()

        if not accepted_rows:
            return []

        user_ids = [row.user_id for row in accepted_rows]
        today_counts = {row.user_id: row.today_count for row in accepted_rows}

        # 获取用户名
        users_stmt = select(models.User.id, models.User.name).where(
            models.User.id.in_(user_ids)
        )
        users_result = await db.execute(users_stmt)
        user_names = {row.id: row.name for row in users_result.all()}

        # 获取每个用户的累计完成数
        total_stmt = (
            select(
                models.TaskHistory.user_id,
                func.count(models.TaskHistory.id).label("total_count"),
            )
            .where(
                models.TaskHistory.action == "completed",
                models.TaskHistory.user_id.in_(user_ids),
            )
            .group_by(models.TaskHistory.user_id)
        )
        total_result = await db.execute(total_stmt)
        total_counts = {row.user_id: row.total_count for row in total_result.all()}

        items = []
        for user_id in user_ids:
            user_name = user_names.get(user_id, user_id)
            count = today_counts[user_id]
            total = total_counts.get(user_id, 0)

            items.append(
                {
                    "text_zh": f"🎉 {user_name} 今日已接 {count} 单，累计完成 {total} 单",
                    "text_en": f"🎉 {user_name} has accepted {count} orders today, {total} completed in total",
                    "link_type": "user",
                    "link_id": user_id,
                }
            )

        return items
    except Exception as e:
        logger.warning(f"Ticker: failed to fetch active user stats: {e}")
        return []


async def _fetch_activity_spots(db: AsyncSession) -> list:
    """数据源3：有剩余名额的公开活动"""
    try:
        now = get_utc_time()

        # 参与人数子查询
        participant_subq = (
            select(
                models.OfficialActivityApplication.activity_id,
                func.count(models.OfficialActivityApplication.id).label(
                    "participant_count"
                ),
            )
            .where(
                models.OfficialActivityApplication.status.in_(
                    ["pending", "attending", "won"]
                )
            )
            .group_by(models.OfficialActivityApplication.activity_id)
            .subquery()
        )

        stmt = (
            select(
                models.Activity.id,
                models.Activity.title,
                models.Activity.title_en,
                models.Activity.max_participants,
                func.coalesce(participant_subq.c.participant_count, 0).label(
                    "participant_count"
                ),
            )
            .outerjoin(
                participant_subq,
                models.Activity.id == participant_subq.c.activity_id,
            )
            .where(
                models.Activity.status == "open",
                models.Activity.visibility == "public",
                (models.Activity.deadline.is_(None))
                | (models.Activity.deadline > now),
            )
            .order_by(desc(models.Activity.created_at))
            .limit(10)
        )

        result = await db.execute(stmt)
        rows = result.all()

        items = []
        for row in rows:
            remaining = row.max_participants - row.participant_count
            if remaining <= 0:
                continue

            title_zh = row.title
            title_en = row.title_en or row.title

            items.append(
                {
                    "text_zh": f"📣 {title_zh} 还剩{remaining}个名额，快来报名",
                    "text_en": f"📣 {title_en} has {remaining} spot(s) left — sign up now",
                    "link_type": "activity",
                    "link_id": str(row.id),
                }
            )

            if len(items) >= 3:
                break

        return items
    except Exception as e:
        logger.warning(f"Ticker: failed to fetch activity spots: {e}")
        return []


# ==================== 主接口 ====================


@router.get("/ticker")
@cache_response(ttl=120, key_prefix="ticker")
async def get_ticker(
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取首页滚动公告栏动态数据（公开接口，无需登录）

    聚合三类平台活动：
    - 最近24小时完成的好评订单
    - 今日活跃接单用户统计
    - 有剩余名额的公开活动
    """
    completions = await _fetch_recent_completions(db)
    active_users = await _fetch_active_user_stats(db)
    activities = await _fetch_activity_spots(db)

    all_items = completions + active_users + activities

    return {"items": all_items[:10]}
