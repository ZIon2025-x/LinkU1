"""
AI Agent 工具定义 + 执行器 — 装饰器注册，定义与实现统一

所有工具均为只读（Phase 1），自动鉴权只访问当前用户数据。
工具按 ToolCategory 分组，LLM 调用时按意图只发送相关子集。
"""

import json
import logging
from decimal import Decimal
from typing import Any

from sqlalchemy import select, and_, or_, func, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.services.ai_tool_registry import tool_registry, ToolCategory
from app.utils.task_activity_display import (
    get_activity_display_title as _activity_title,
    get_activity_display_description as _activity_description,
    get_task_display_title as _task_title,
    get_task_display_description as _task_description,
)
from app.utils.time_utils import format_iso_utc

logger = logging.getLogger(__name__)

# 兼容旧导入：TOOLS 现在从 registry 获取
TOOLS = None  # lazy; use tool_registry.get_all_tool_schemas()

# ── FAQ 映射 ──────────────────────────────────────────────
TOPIC_TO_SECTION_KEY = {
    "about": "about", "publish": "posting_taking", "accept": "task_flow",
    "payment": "payment_refunds", "fee": "payment_methods",
    "dispute": "confirmation_disputes", "account": "account_login",
    "wallet": "payment_methods", "cancel": "cancel_task",
    "report": "report_safety", "privacy": "privacy_security",
    "flea": "flea_market", "forum": "forum", "application": "task_application",
    "review": "reviews_reputation", "student": "student_verification",
    "expert": "task_experts", "activity": "activities",
    "coupon": "coupons_points", "notification": "notifications",
    "message_support": "messaging_support", "vip": "vip", "linker": "linker_ai",
}

_TOOL_ERRORS = {
    "zh": {
        "execution_failed": "工具执行失败，请稍后重试",
        "task_id_required": "需要提供 task_id",
        "task_not_found": "任务不存在",
        "task_no_permission": "无权查看此任务",
        "leaderboard_not_found": "排行榜不存在",
        "activity_not_found": "活动不存在",
        "expert_not_found": "达人不存在",
        "post_not_found": "帖子不存在",
        "item_not_found": "商品不存在",
    },
    "en": {
        "execution_failed": "Tool execution failed. Please try again later.",
        "task_id_required": "task_id is required",
        "task_not_found": "Task not found",
        "task_no_permission": "You do not have permission to view this task",
        "leaderboard_not_found": "Leaderboard not found",
        "activity_not_found": "Activity not found",
        "expert_not_found": "Expert not found",
        "post_not_found": "Post not found",
        "item_not_found": "Item not found",
    },
}


# ── 辅助函数 ──────────────────────────────────────────────

def _decimal_to_float(obj: Any) -> Any:
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, dict):
        return {k: _decimal_to_float(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_decimal_to_float(i) for i in obj]
    return obj


def _truncate(text: str | None, max_len: int = 200) -> str:
    """截断长文本，节省 token"""
    if not text:
        return ""
    return text[:max_len] + ("..." if len(text) > max_len else "")


def _slim_images(images: Any, max_count: int = 3) -> int | list[str]:
    """图片列表 → 仅返回数量（避免 URL 占 token），如果需要 URL 则最多 max_count"""
    if not images:
        return 0
    if isinstance(images, str):
        try:
            images = json.loads(images)
        except (json.JSONDecodeError, TypeError):
            return 0
    if isinstance(images, list):
        return len(images)
    return 0


def _forum_post_display_title(post: models.ForumPost, lang: str) -> str:
    col = getattr(post, "title_zh" if lang == "zh" else "title_en", None)
    return (col or "") if col else (post.title or "")


def _notification_display_title(n: models.Notification, lang: str) -> str:
    if lang == "zh":
        return n.title or ""
    return getattr(n, "title_en", None) or n.title or ""


def _leaderboard_display_name_desc(lb: models.CustomLeaderboard, lang: str) -> tuple[str, str]:
    name_col = getattr(lb, "name_zh" if lang == "zh" else "name_en", None)
    desc_col = getattr(lb, "description_zh" if lang == "zh" else "description_en", None)
    name = (name_col or "") if name_col else (lb.name or "")
    description = (desc_col or "") if desc_col else (lb.description or "")
    return name, description


# ── ToolExecutor（安全执行器）──────────────────────────────

class ToolExecutor:
    """安全执行 AI 请求的工具调用 — handler 通过 registry 查找"""

    def __init__(self, db: AsyncSession, user: models.User):
        self.db = db
        self.user = user
        self._request_lang: str | None = None

    def _tool_lang(self) -> str:
        if self._request_lang is not None:
            return self._request_lang
        pref = (self.user.language_preference or "").strip().lower()
        return "zh" if pref.startswith("zh") else "en"

    def _faq_lang_key(self) -> str:
        return "en" if self._tool_lang() == "en" else "zh"

    async def execute(self, tool_name: str, tool_input: dict, request_lang: str | None = None) -> dict:
        self._request_lang = request_lang
        try:
            msgs = _TOOL_ERRORS.get(self._tool_lang(), _TOOL_ERRORS["en"])
            handler = tool_registry.get_handler(tool_name)
            if not handler:
                return {"error": f"Unknown tool: {tool_name}"}
            try:
                result = await handler(self, tool_input)
                return _decimal_to_float(result)
            except Exception as e:
                logger.error(f"Tool execution error: {tool_name} — {e}")
                return {"error": msgs["execution_failed"]}
        finally:
            self._request_lang = None

    # ── FAQ 辅助（供 agent 直接调用） ──

    async def get_faq_for_agent(self, topic: str, lang: str) -> str | None:
        section_key = TOPIC_TO_SECTION_KEY.get(topic)
        if not section_key:
            return None
        lang_key = "en" if lang.startswith("en") else "zh"
        q = (
            select(models.FaqItem)
            .join(models.FaqSection, models.FaqItem.section_id == models.FaqSection.id)
            .where(models.FaqSection.key == section_key)
            .order_by(models.FaqItem.sort_order.asc())
            .limit(8)
        )
        rows = (await self.db.execute(q)).scalars().all()
        if not rows:
            return None
        if len(rows) == 1:
            return getattr(rows[0], f"answer_{lang_key}")
        parts = []
        for row in rows:
            question = getattr(row, f"question_{lang_key}")
            answer = getattr(row, f"answer_{lang_key}")
            parts.append(f"**{question}**\n{answer}")
        return "\n\n".join(parts)

    async def get_faq_by_message(self, message: str, lang: str) -> str | None:
        if not message or len(message.strip()) < 2:
            return None
        lang_key = "en" if lang.startswith("en") else "zh"
        q_col = getattr(models.FaqItem, f"question_{lang_key}")
        pattern = f"%{message.strip()[:80]}%"
        q = (
            select(models.FaqItem)
            .where(q_col.ilike(pattern))
            .order_by(models.FaqItem.sort_order.asc())
            .limit(1)
        )
        row = (await self.db.execute(q)).scalar_one_or_none()
        if not row:
            return None
        return getattr(row, f"answer_{lang_key}")


# =====================================================================
# 工具注册（装饰器：name + schema + categories + handler 统一声明）
# =====================================================================

@tool_registry.register(
    name="query_my_tasks",
    description="查询当前用户的任务列表，支持按状态筛选。Query the current user's task list, with optional status filter.",
    input_schema={
        "type": "object",
        "properties": {
            "status": {
                "type": "string",
                "enum": ["all", "open", "in_progress", "completed", "cancelled"],
                "description": "任务状态筛选，默认 all",
            },
            "page": {"type": "integer", "description": "页码，默认 1", "default": 1},
        },
    },
    categories=[ToolCategory.TASK],
)
async def _query_my_tasks(executor: ToolExecutor, input: dict) -> dict:
    status_filter = input.get("status", "all")
    page = max(1, input.get("page", 1))
    page_size = 10
    user_id = executor.user.id

    main_conditions = [
        or_(
            models.Task.poster_id == user_id,
            models.Task.taker_id == user_id,
            models.Task.originating_user_id == user_id,
        )
    ]
    if status_filter != "all":
        main_conditions.append(models.Task.status == status_filter)

    main_rows = (await executor.db.execute(
        select(models.Task).where(and_(*main_conditions))
    )).scalars().all()

    part_conditions = [
        models.TaskParticipant.user_id == user_id,
        models.Task.is_multi_participant == True,
    ]
    if status_filter != "all":
        part_conditions.append(models.Task.status == status_filter)
    part_rows = (await executor.db.execute(
        select(models.Task)
        .join(models.TaskParticipant, models.Task.id == models.TaskParticipant.task_id)
        .where(and_(*part_conditions))
    )).scalars().all()

    tasks_dict = {}
    for t in main_rows + part_rows:
        tasks_dict[t.id] = t
    all_tasks = sorted(tasks_dict.values(), key=lambda t: t.created_at or t.id, reverse=True)
    total = len(all_tasks)
    page_tasks = all_tasks[(page - 1) * page_size: page * page_size]

    lang = executor._tool_lang()
    tasks = [{
        "id": t.id,
        "title": _task_title(t, lang),
        "status": t.status,
        "reward": t.reward,
        "currency": t.currency,
        "task_type": t.task_type,
        "is_poster": t.poster_id == user_id,
        "created_at": format_iso_utc(t.created_at) if t.created_at else None,
        "deadline": format_iso_utc(t.deadline) if t.deadline else None,
    } for t in page_tasks]

    return {"tasks": tasks, "total": total, "page": page, "page_size": page_size}


@tool_registry.register(
    name="get_task_detail",
    description="查询单个任务的详细信息。Get detailed info for a specific task.",
    input_schema={
        "type": "object",
        "properties": {
            "task_id": {"type": "integer", "description": "任务 ID"},
        },
        "required": ["task_id"],
    },
    categories=[ToolCategory.TASK],
)
async def _get_task_detail(executor: ToolExecutor, input: dict) -> dict:
    msgs = _TOOL_ERRORS.get(executor._tool_lang(), _TOOL_ERRORS["en"])
    task_id = input.get("task_id")
    if not task_id:
        return {"error": msgs["task_id_required"]}

    task = (await executor.db.execute(
        select(models.Task).where(models.Task.id == task_id)
    )).scalar_one_or_none()
    if not task:
        return {"error": msgs["task_not_found"]}

    user_id = executor.user.id
    is_owner = (
        task.poster_id == user_id
        or task.taker_id == user_id
        or task.originating_user_id == user_id
    )
    if not is_owner:
        is_participant = (await executor.db.execute(
            select(func.count()).select_from(models.TaskParticipant).where(and_(
                models.TaskParticipant.task_id == task_id,
                models.TaskParticipant.user_id == user_id,
            ))
        )).scalar() or 0
        is_owner = is_participant > 0
    if not task.is_public and not is_owner:
        return {"error": msgs["task_no_permission"]}

    lang = executor._tool_lang()
    result = {
        "id": task.id,
        "title": _task_title(task, lang),
        "description": _truncate(_task_description(task, lang), 300),
        "status": task.status,
        "reward": task.reward,
        "currency": task.currency,
        "task_type": task.task_type,
        "location": task.location,
        "is_poster": task.poster_id == user_id,
        "is_taker": task.taker_id == user_id,
        "is_paid": bool(task.is_paid),
        "is_confirmed": bool(task.is_confirmed),
        "is_multi_participant": bool(task.is_multi_participant),
        "max_participants": task.max_participants,
        "current_participants": task.current_participants,
        "image_count": _slim_images(task.images),
        "created_at": format_iso_utc(task.created_at) if task.created_at else None,
        "deadline": format_iso_utc(task.deadline) if task.deadline else None,
        "completed_at": format_iso_utc(task.completed_at) if task.completed_at else None,
    }

    if task.poster_id == user_id:
        app_count = (await executor.db.execute(
            select(func.count()).select_from(models.TaskApplication)
            .where(models.TaskApplication.task_id == task_id)
        )).scalar() or 0
        result["application_count"] = app_count

    return result


@tool_registry.register(
    name="recommend_tasks",
    description="获取为当前用户个性化推荐的任务。Get personalized task recommendations for the current user.",
    input_schema={
        "type": "object",
        "properties": {
            "limit": {"type": "integer", "description": "返回数量，默认 10，最大 20", "default": 10},
            "task_type": {"type": "string", "description": "任务类型筛选（可选）"},
            "keyword": {"type": "string", "description": "关键词筛选（可选）"},
        },
    },
    categories=[ToolCategory.TASK],
)
async def _recommend_tasks(executor: ToolExecutor, input: dict) -> dict:
    limit = min(20, max(1, input.get("limit", 10)))
    task_type = input.get("task_type")
    keyword = input.get("keyword")
    lang = executor._tool_lang()

    def _sync_recommend(session):
        from app.task_recommendation import get_task_recommendations
        recs = get_task_recommendations(
            db=session, user_id=executor.user.id, limit=limit,
            algorithm="hybrid", task_type=task_type, location=None,
            keyword=keyword, latitude=None, longitude=None,
        )
        tasks = []
        for item in recs:
            t = item.get("task")
            if not t:
                continue
            tasks.append({
                "id": t.id,
                "title": _task_title(t, lang),
                "reward": t.reward,
                "currency": t.currency,
                "task_type": t.task_type,
                "location": t.location,
                "match_score": round(item.get("score", 0), 2),
                "deadline": format_iso_utc(t.deadline) if t.deadline else None,
            })
        return tasks

    try:
        tasks = await executor.db.run_sync(_sync_recommend)
    except Exception as e:
        logger.warning("recommend_tasks failed: %s", e)
        return {"tasks": [], "count": 0}

    return {"tasks": tasks, "count": len(tasks)}


@tool_registry.register(
    name="search_tasks",
    description="搜索平台上的公开任务。Search public tasks on the platform.",
    input_schema={
        "type": "object",
        "properties": {
            "keyword": {"type": "string", "description": "搜索关键词"},
            "task_type": {"type": "string", "description": "任务类型筛选"},
            "min_reward": {"type": "number", "description": "最低报酬（GBP）"},
            "max_reward": {"type": "number", "description": "最高报酬（GBP）"},
        },
    },
    categories=[ToolCategory.TASK],
)
async def _search_tasks(executor: ToolExecutor, input: dict) -> dict:
    keyword = input.get("keyword", "")
    task_type = input.get("task_type")
    min_reward = input.get("min_reward")
    max_reward = input.get("max_reward")

    conditions = [models.Task.is_public == 1, models.Task.status == "open"]
    if keyword:
        like_kw = f"%{keyword}%"
        conditions.append(or_(
            models.Task.title.ilike(like_kw),
            models.Task.description.ilike(like_kw),
        ))
    if task_type:
        conditions.append(models.Task.task_type == task_type)
    if min_reward is not None:
        conditions.append(models.Task.reward >= min_reward)
    if max_reward is not None:
        conditions.append(models.Task.reward <= max_reward)

    rows = (await executor.db.execute(
        select(models.Task).where(and_(*conditions))
        .order_by(desc(models.Task.created_at)).limit(10)
    )).scalars().all()

    lang = executor._tool_lang()
    tasks = [{
        "id": t.id, "title": _task_title(t, lang),
        "reward": t.reward, "currency": t.currency,
        "task_type": t.task_type, "location": t.location,
        "deadline": format_iso_utc(t.deadline) if t.deadline else None,
    } for t in rows]

    return {"tasks": tasks, "count": len(tasks)}


@tool_registry.register(
    name="get_my_profile",
    description="获取当前用户的个人资料、评分、任务统计。Get the current user's profile, rating, and task stats.",
    input_schema={"type": "object", "properties": {}},
    categories=[ToolCategory.PROFILE],
)
async def _get_my_profile(executor: ToolExecutor, input: dict) -> dict:
    u = executor.user
    points_balance = (await executor.db.execute(
        select(models.PointsAccount.balance).where(models.PointsAccount.user_id == u.id)
    )).scalar() or 0

    from app.utils.time_utils import get_utc_time
    now = get_utc_time()
    available_coupons_count = (await executor.db.execute(
        select(func.count()).select_from(models.UserCoupon)
        .join(models.Coupon, models.UserCoupon.coupon_id == models.Coupon.id)
        .where(and_(
            models.UserCoupon.user_id == u.id,
            models.UserCoupon.status == "unused",
            models.Coupon.valid_until > now,
        ))
    )).scalar() or 0

    return {
        "name": u.name, "user_level": u.user_level,
        "task_count": u.task_count,
        "completed_task_count": u.completed_task_count,
        "avg_rating": u.avg_rating,
        "is_verified": bool(u.is_verified),
        "points_balance": int(points_balance),
        "available_coupons_count": available_coupons_count,
    }


@tool_registry.register(
    name="get_platform_faq",
    description="查询平台常见问题解答。Query platform FAQ.",
    input_schema={
        "type": "object",
        "properties": {
            "question": {"type": "string", "description": "用户的问题关键词"},
        },
    },
    categories=[ToolCategory.FAQ, ToolCategory.GENERAL],
)
async def _get_platform_faq(executor: ToolExecutor, input: dict) -> dict:
    question = (input.get("question") or "").strip().lower()
    lang_key = executor._faq_lang_key()
    question_col = getattr(models.FaqItem, f"question_{lang_key}")

    if question and len(question) >= 2:
        pattern = f"%{question[:100]}%"
        q = (
            select(models.FaqItem, models.FaqSection.key)
            .join(models.FaqSection, models.FaqItem.section_id == models.FaqSection.id)
            .where(question_col.ilike(pattern))
            .order_by(models.FaqSection.sort_order, models.FaqItem.sort_order)
            .limit(5)
        )
        rows = (await executor.db.execute(q)).all()
        matches = [{"topic": key, "answer": _truncate(getattr(item, f"answer_{lang_key}"), 400)} for item, key in rows]
    else:
        q_sec = select(models.FaqSection).order_by(models.FaqSection.sort_order.asc())
        sections = (await executor.db.execute(q_sec)).scalars().all()
        matches = []
        for sec in sections:
            item = (await executor.db.execute(
                select(models.FaqItem).where(models.FaqItem.section_id == sec.id)
                .order_by(models.FaqItem.sort_order.asc()).limit(1)
            )).scalar_one_or_none()
            if item:
                matches.append({"topic": sec.key, "answer": _truncate(getattr(item, f"answer_{lang_key}"), 400)})

    return {"faq": matches}


@tool_registry.register(
    name="check_cs_availability",
    description="检查是否有人工客服在线。Check if human customer service agents are online.",
    input_schema={"type": "object", "properties": {}},
    categories=[ToolCategory.GENERAL],
)
async def _check_cs_availability(executor: ToolExecutor, input: dict) -> dict:
    from sqlalchemy import cast, Integer
    online_count = (await executor.db.execute(
        select(func.count(models.CustomerService.id)).where(
            cast(models.CustomerService.is_online, Integer) == 1
        )
    )).scalar() or 0
    return {"available": online_count > 0, "online_count": online_count}


@tool_registry.register(
    name="get_my_points_and_coupons",
    description="查询当前用户的积分余额和可用优惠券列表。Get user's points balance and available coupons.",
    input_schema={"type": "object", "properties": {}},
    categories=[ToolCategory.PROFILE],
)
async def _get_my_points_and_coupons(executor: ToolExecutor, input: dict) -> dict:
    from app.utils.time_utils import get_utc_time
    now = get_utc_time()

    pa = (await executor.db.execute(
        select(models.PointsAccount).where(models.PointsAccount.user_id == executor.user.id)
    )).scalar_one_or_none()
    points = {
        "balance": int(pa.balance) if pa else 0,
        "total_earned": int(pa.total_earned) if pa else 0,
        "total_spent": int(pa.total_spent) if pa else 0,
    }

    rows = (await executor.db.execute(
        select(models.UserCoupon, models.Coupon)
        .join(models.Coupon, models.UserCoupon.coupon_id == models.Coupon.id)
        .where(and_(
            models.UserCoupon.user_id == executor.user.id,
            models.UserCoupon.status == "unused",
            models.Coupon.valid_until > now,
        ))
        .order_by(models.Coupon.valid_until.asc()).limit(10)
    )).all()
    coupons = [{
        "name": c.name, "type": c.type,
        "discount_value": int(c.discount_value) if c.discount_value else 0,
        "currency": c.currency,
        "valid_until": format_iso_utc(c.valid_until) if c.valid_until else None,
    } for uc, c in rows]

    return {"points": points, "coupons": coupons}


@tool_registry.register(
    name="list_activities",
    description="浏览平台进行中的公开活动。List active public activities.",
    input_schema={
        "type": "object",
        "properties": {
            "keyword": {"type": "string", "description": "搜索关键词（匹配标题/描述）"},
        },
    },
    categories=[ToolCategory.PLATFORM],
)
async def _list_activities(executor: ToolExecutor, input: dict) -> dict:
    keyword = input.get("keyword", "")
    conditions = [models.Activity.status == "open", models.Activity.is_public == True]
    if keyword:
        like_kw = f"%{keyword}%"
        conditions.append(or_(
            models.Activity.title.ilike(like_kw),
            models.Activity.description.ilike(like_kw),
        ))

    rows = (await executor.db.execute(
        select(models.Activity).where(and_(*conditions))
        .order_by(desc(models.Activity.created_at)).limit(10)
    )).scalars().all()

    lang = executor._tool_lang()
    activities = [{
        "id": a.id, "title": _activity_title(a, lang),
        "location": a.location, "max_participants": a.max_participants,
        "reward_type": a.reward_type,
        "deadline": format_iso_utc(a.deadline) if a.deadline else None,
    } for a in rows]

    return {"activities": activities, "count": len(activities)}


@tool_registry.register(
    name="get_my_notifications_summary",
    description="获取当前用户的未读通知数和最近通知。Get user's unread notification count and recent notifications.",
    input_schema={"type": "object", "properties": {}},
    categories=[ToolCategory.NOTIFICATION],
)
async def _get_my_notifications_summary(executor: ToolExecutor, input: dict) -> dict:
    unread_count = (await executor.db.execute(
        select(func.count()).select_from(models.Notification)
        .where(and_(
            models.Notification.user_id == executor.user.id,
            models.Notification.is_read == 0,
        ))
    )).scalar() or 0

    rows = (await executor.db.execute(
        select(models.Notification)
        .where(models.Notification.user_id == executor.user.id)
        .order_by(desc(models.Notification.created_at)).limit(5)
    )).scalars().all()

    lang = executor._tool_lang()
    recent = [{
        "type": n.type,
        "title": _notification_display_title(n, lang),
        "is_read": bool(n.is_read),
        "created_at": format_iso_utc(n.created_at) if n.created_at else None,
    } for n in rows]

    return {"unread_count": unread_count, "recent": recent}


@tool_registry.register(
    name="list_my_forum_posts",
    description="查询当前用户发布的论坛帖子。List the current user's forum posts.",
    input_schema={
        "type": "object",
        "properties": {
            "page": {"type": "integer", "description": "页码，默认 1", "default": 1},
        },
    },
    categories=[ToolCategory.PLATFORM],
)
async def _list_my_forum_posts(executor: ToolExecutor, input: dict) -> dict:
    page = max(1, input.get("page", 1))
    page_size = 10
    conditions = [
        models.ForumPost.author_id == executor.user.id,
        models.ForumPost.is_deleted == False,
    ]
    total = (await executor.db.execute(
        select(func.count()).select_from(models.ForumPost).where(and_(*conditions))
    )).scalar() or 0

    rows = (await executor.db.execute(
        select(models.ForumPost, models.ForumCategory)
        .join(models.ForumCategory, models.ForumPost.category_id == models.ForumCategory.id)
        .where(and_(*conditions))
        .order_by(desc(models.ForumPost.created_at))
        .offset((page - 1) * page_size).limit(page_size)
    )).all()

    lang = executor._tool_lang()
    lang_key = executor._faq_lang_key()
    posts = [{
        "id": post.id,
        "title": _forum_post_display_title(post, lang),
        "category_name": getattr(cat, f"name_{lang_key}", None) or cat.name,
        "view_count": post.view_count,
        "reply_count": post.reply_count,
        "created_at": format_iso_utc(post.created_at) if post.created_at else None,
    } for post, cat in rows]

    return {"posts": posts, "total": total}


@tool_registry.register(
    name="search_flea_market",
    description="搜索跳蚤市场商品。Search flea market items.",
    input_schema={
        "type": "object",
        "properties": {
            "keyword": {"type": "string", "description": "搜索关键词"},
            "category": {"type": "string", "description": "商品分类"},
            "min_price": {"type": "number", "description": "最低价格（GBP）"},
            "max_price": {"type": "number", "description": "最高价格（GBP）"},
        },
    },
    categories=[ToolCategory.PLATFORM],
)
async def _search_flea_market(executor: ToolExecutor, input: dict) -> dict:
    keyword = input.get("keyword", "")
    category = input.get("category")
    min_price = input.get("min_price")
    max_price = input.get("max_price")

    conditions = [models.FleaMarketItem.status == "active"]
    if keyword:
        like_kw = f"%{keyword}%"
        conditions.append(or_(
            models.FleaMarketItem.title.ilike(like_kw),
            models.FleaMarketItem.description.ilike(like_kw),
        ))
    if category:
        conditions.append(models.FleaMarketItem.category == category)
    if min_price is not None:
        conditions.append(models.FleaMarketItem.price >= min_price)
    if max_price is not None:
        conditions.append(models.FleaMarketItem.price <= max_price)

    rows = (await executor.db.execute(
        select(models.FleaMarketItem).where(and_(*conditions))
        .order_by(desc(models.FleaMarketItem.created_at)).limit(10)
    )).scalars().all()

    items = [{
        "id": item.id, "title": item.title,
        "price": float(item.price), "currency": item.currency,
        "location": item.location, "category": item.category,
    } for item in rows]

    return {"items": items, "count": len(items)}


@tool_registry.register(
    name="get_leaderboard_summary",
    description="查看排行榜概览或单个排行榜详情。View leaderboard overview or details.",
    input_schema={
        "type": "object",
        "properties": {
            "leaderboard_id": {"type": "integer", "description": "排行榜 ID（不传则返回所有活跃排行榜列表）"},
        },
    },
    categories=[ToolCategory.PLATFORM],
)
async def _get_leaderboard_summary(executor: ToolExecutor, input: dict) -> dict:
    leaderboard_id = input.get("leaderboard_id")

    if leaderboard_id:
        lb = (await executor.db.execute(
            select(models.CustomLeaderboard).where(models.CustomLeaderboard.id == leaderboard_id)
        )).scalar_one_or_none()
        if not lb:
            msgs = _TOOL_ERRORS.get(executor._tool_lang(), _TOOL_ERRORS["en"])
            return {"error": msgs["leaderboard_not_found"]}

        items_rows = (await executor.db.execute(
            select(models.LeaderboardItem)
            .where(models.LeaderboardItem.leaderboard_id == leaderboard_id)
            .order_by(desc(models.LeaderboardItem.net_votes)).limit(10)
        )).scalars().all()
        items = [{"name": i.name, "net_votes": i.net_votes} for i in items_rows]
        lb_name, lb_desc = _leaderboard_display_name_desc(lb, executor._tool_lang())
        return {"name": lb_name, "description": _truncate(lb_desc, 200), "items": items}

    rows = (await executor.db.execute(
        select(models.CustomLeaderboard)
        .where(models.CustomLeaderboard.status == "active")
        .order_by(desc(models.CustomLeaderboard.vote_count)).limit(10)
    )).scalars().all()
    lang = executor._tool_lang()
    leaderboards = [{
        "id": lb.id,
        "name": _leaderboard_display_name_desc(lb, lang)[0],
        "item_count": lb.item_count, "vote_count": lb.vote_count,
    } for lb in rows]
    return {"leaderboards": leaderboards}


@tool_registry.register(
    name="list_task_experts",
    description="浏览平台活跃的任务达人。List active task experts.",
    input_schema={
        "type": "object",
        "properties": {
            "keyword": {"type": "string", "description": "搜索关键词（匹配姓名/简介）"},
        },
    },
    categories=[ToolCategory.PLATFORM],
)
async def _list_task_experts(executor: ToolExecutor, input: dict) -> dict:
    keyword = input.get("keyword", "")
    conditions = [models.TaskExpert.status == "active"]
    if keyword:
        like_kw = f"%{keyword}%"
        conditions.append(or_(
            models.TaskExpert.expert_name.ilike(like_kw),
            models.TaskExpert.bio.ilike(like_kw),
        ))

    rows = (await executor.db.execute(
        select(models.TaskExpert, models.User.name)
        .join(models.User, models.TaskExpert.id == models.User.id)
        .where(and_(*conditions))
        .order_by(desc(models.TaskExpert.rating)).limit(10)
    )).all()

    experts = [{
        "id": expert.id,
        "name": expert.expert_name or user_name,
        "bio": _truncate(expert.bio, 80),
        "rating": float(expert.rating) if expert.rating else 0,
        "completed_tasks": expert.completed_tasks,
    } for expert, user_name in rows]

    return {"experts": experts, "count": len(experts)}


# ── Phase 2 工具 ──────────────────────────────────────────

@tool_registry.register(
    name="get_activity_detail",
    description="查询单个活动的详细信息。Get detailed info for a specific activity.",
    input_schema={
        "type": "object",
        "properties": {"activity_id": {"type": "integer", "description": "活动 ID"}},
        "required": ["activity_id"],
    },
    categories=[ToolCategory.PLATFORM],
)
async def _get_activity_detail(executor: ToolExecutor, input: dict) -> dict:
    msgs = _TOOL_ERRORS.get(executor._tool_lang(), _TOOL_ERRORS["en"])
    activity_id = input.get("activity_id")
    if not activity_id:
        return {"error": msgs["activity_not_found"]}

    activity = (await executor.db.execute(
        select(models.Activity).where(models.Activity.id == activity_id)
    )).scalar_one_or_none()
    if not activity:
        return {"error": msgs["activity_not_found"]}
    if not activity.is_public and activity.expert_id != executor.user.id:
        return {"error": msgs["activity_not_found"]}

    lang = executor._tool_lang()
    expert_name = None
    if activity.expert_id:
        row = (await executor.db.execute(
            select(models.TaskExpert.expert_name, models.User.name)
            .join(models.User, models.TaskExpert.id == models.User.id)
            .where(models.TaskExpert.id == activity.expert_id)
        )).first()
        if row:
            expert_name = row[0] or row[1]

    return {
        "id": activity.id,
        "title": _activity_title(activity, lang),
        "description": _truncate(_activity_description(activity, lang), 300),
        "location": activity.location,
        "reward_type": activity.reward_type,
        "original_price": activity.original_price_per_participant,
        "discounted_price": activity.discounted_price_per_participant,
        "currency": activity.currency,
        "max_participants": activity.max_participants,
        "status": activity.status,
        "deadline": format_iso_utc(activity.deadline) if activity.deadline else None,
        "image_count": _slim_images(activity.images),
        "expert_name": expert_name,
    }


@tool_registry.register(
    name="get_expert_detail",
    description="查询达人详情及其服务列表。Get expert profile and services.",
    input_schema={
        "type": "object",
        "properties": {"expert_id": {"type": "string", "description": "达人 ID"}},
        "required": ["expert_id"],
    },
    categories=[ToolCategory.PLATFORM],
)
async def _get_expert_detail(executor: ToolExecutor, input: dict) -> dict:
    msgs = _TOOL_ERRORS.get(executor._tool_lang(), _TOOL_ERRORS["en"])
    expert_id = input.get("expert_id")
    if not expert_id:
        return {"error": msgs["expert_not_found"]}

    row = (await executor.db.execute(
        select(models.TaskExpert, models.User.name)
        .join(models.User, models.TaskExpert.id == models.User.id)
        .where(models.TaskExpert.id == expert_id)
    )).first()
    if not row:
        return {"error": msgs["expert_not_found"]}

    expert, user_name = row
    svc_rows = (await executor.db.execute(
        select(models.TaskExpertService).where(and_(
            models.TaskExpertService.expert_id == expert_id,
            models.TaskExpertService.status == "active",
        )).order_by(models.TaskExpertService.display_order)
    )).scalars().all()
    services = [{
        "id": s.id, "service_name": s.service_name,
        "description": _truncate(s.description, 150),
        "base_price": s.base_price, "currency": s.currency,
    } for s in svc_rows]

    return {
        "id": expert.id, "name": expert.expert_name or user_name,
        "bio": _truncate(expert.bio, 200),
        "rating": float(expert.rating) if expert.rating else 0,
        "completed_tasks": expert.completed_tasks,
        "services": services,
    }


@tool_registry.register(
    name="get_forum_post_detail",
    description="查询论坛帖子详情。Get forum post details.",
    input_schema={
        "type": "object",
        "properties": {"post_id": {"type": "integer", "description": "帖子 ID"}},
        "required": ["post_id"],
    },
    categories=[ToolCategory.PLATFORM],
)
async def _get_forum_post_detail(executor: ToolExecutor, input: dict) -> dict:
    from app.forum_routes import assert_forum_visible
    msgs = _TOOL_ERRORS.get(executor._tool_lang(), _TOOL_ERRORS["en"])
    post_id = input.get("post_id")
    if not post_id:
        return {"error": msgs["post_not_found"]}

    row = (await executor.db.execute(
        select(models.ForumPost, models.ForumCategory)
        .join(models.ForumCategory, models.ForumPost.category_id == models.ForumCategory.id)
        .where(and_(models.ForumPost.id == post_id, models.ForumPost.is_deleted == False))
    )).first()
    if not row:
        return {"error": msgs["post_not_found"]}

    post, category = row
    if not post.is_visible and post.author_id != executor.user.id:
        return {"error": msgs["post_not_found"]}
    visible = await assert_forum_visible(executor.user, post.category_id, executor.db, raise_exception=False)
    if not visible or not category.is_visible:
        return {"error": msgs["post_not_found"]}

    lang = executor._tool_lang()
    lang_key = executor._faq_lang_key()
    content_col = getattr(post, f"content_{lang_key}", None)
    content = content_col if content_col else post.content

    author_name = None
    if post.author_id:
        author_name = (await executor.db.execute(
            select(models.User.name).where(models.User.id == post.author_id)
        )).scalar()

    return {
        "id": post.id,
        "title": _forum_post_display_title(post, lang),
        "content": _truncate(content, 500),
        "category_name": getattr(category, f"name_{lang_key}", None) or category.name or "",
        "author_name": author_name,
        "view_count": post.view_count,
        "reply_count": post.reply_count,
        "like_count": post.like_count,
        "image_count": _slim_images(post.images),
    }


@tool_registry.register(
    name="get_flea_market_item_detail",
    description="查询跳蚤市场商品详情。Get flea market item details.",
    input_schema={
        "type": "object",
        "properties": {"item_id": {"type": "integer", "description": "商品 ID"}},
        "required": ["item_id"],
    },
    categories=[ToolCategory.PLATFORM],
)
async def _get_flea_market_item_detail(executor: ToolExecutor, input: dict) -> dict:
    msgs = _TOOL_ERRORS.get(executor._tool_lang(), _TOOL_ERRORS["en"])
    item_id = input.get("item_id")
    if not item_id:
        return {"error": msgs["item_not_found"]}

    row = (await executor.db.execute(
        select(models.FleaMarketItem, models.User.name)
        .join(models.User, models.FleaMarketItem.seller_id == models.User.id)
        .where(models.FleaMarketItem.id == item_id)
    )).first()
    if not row:
        return {"error": msgs["item_not_found"]}

    item, seller_name = row
    if item.status not in ("active", "sold"):
        return {"error": msgs["item_not_found"]}

    return {
        "id": item.id, "title": item.title,
        "description": _truncate(item.description, 300),
        "price": float(item.price), "currency": item.currency,
        "location": item.location, "category": item.category,
        "seller_name": seller_name,
        "image_count": _slim_images(item.images),
        "status": item.status,
    }


@tool_registry.register(
    name="list_my_applications",
    description="查询当前用户的任务申请列表。List the current user's task applications.",
    input_schema={
        "type": "object",
        "properties": {
            "status": {
                "type": "string",
                "enum": ["all", "pending", "approved", "rejected"],
                "description": "申请状态筛选，默认 all",
            },
            "page": {"type": "integer", "description": "页码，默认 1", "default": 1},
        },
    },
    categories=[ToolCategory.TASK],
)
async def _list_my_applications(executor: ToolExecutor, input: dict) -> dict:
    status_filter = input.get("status", "all")
    page = max(1, input.get("page", 1))
    page_size = 10
    lang = executor._tool_lang()

    conditions = [models.TaskApplication.applicant_id == executor.user.id]
    if status_filter != "all":
        conditions.append(models.TaskApplication.status == status_filter)

    total = (await executor.db.execute(
        select(func.count()).select_from(models.TaskApplication).where(and_(*conditions))
    )).scalar() or 0

    rows = (await executor.db.execute(
        select(models.TaskApplication, models.Task)
        .join(models.Task, models.TaskApplication.task_id == models.Task.id)
        .where(and_(*conditions))
        .order_by(desc(models.TaskApplication.created_at))
        .offset((page - 1) * page_size).limit(page_size)
    )).all()

    applications = [{
        "id": app.id, "task_id": app.task_id,
        "task_title": _task_title(task, lang),
        "task_status": task.status,
        "status": app.status,
        "negotiated_price": app.negotiated_price,
        "currency": app.currency,
        "created_at": format_iso_utc(app.created_at) if app.created_at else None,
    } for app, task in rows]

    return {"applications": applications, "total": total, "page": page}


@tool_registry.register(
    name="list_my_service_applications",
    description="查询当前用户的达人服务预约列表。List the current user's expert service applications.",
    input_schema={
        "type": "object",
        "properties": {
            "status": {
                "type": "string",
                "enum": ["all", "pending", "negotiating", "price_agreed", "approved", "rejected", "cancelled"],
                "description": "预约状态筛选，默认 all",
            },
            "page": {"type": "integer", "description": "页码，默认 1", "default": 1},
        },
    },
    categories=[ToolCategory.TASK],
)
async def _list_my_service_applications(executor: ToolExecutor, input: dict) -> dict:
    status_filter = input.get("status", "all")
    page = max(1, input.get("page", 1))
    page_size = 10

    conditions = [models.ServiceApplication.applicant_id == executor.user.id]
    if status_filter != "all":
        conditions.append(models.ServiceApplication.status == status_filter)

    total = (await executor.db.execute(
        select(func.count()).select_from(models.ServiceApplication).where(and_(*conditions))
    )).scalar() or 0

    rows = (await executor.db.execute(
        select(
            models.ServiceApplication,
            models.TaskExpertService.service_name,
            models.TaskExpert.expert_name,
            models.User.name,
        )
        .join(models.TaskExpertService, models.ServiceApplication.service_id == models.TaskExpertService.id)
        .join(models.TaskExpert, models.ServiceApplication.expert_id == models.TaskExpert.id)
        .join(models.User, models.TaskExpert.id == models.User.id)
        .where(and_(*conditions))
        .order_by(desc(models.ServiceApplication.created_at))
        .offset((page - 1) * page_size).limit(page_size)
    )).all()

    applications = [{
        "id": app.id, "service_name": service_name,
        "expert_name": expert_name or user_name,
        "status": app.status,
        "final_price": app.final_price,
        "negotiated_price": app.negotiated_price,
        "currency": app.currency,
    } for app, service_name, expert_name, user_name in rows]

    return {"applications": applications, "total": total, "page": page}


@tool_registry.register(
    name="list_my_activities",
    description="查询当前用户参与或收藏的活动。List activities the user participated in or favorited.",
    input_schema={
        "type": "object",
        "properties": {
            "type": {
                "type": "string", "enum": ["participated", "favorited"],
                "description": "查询类型，默认 participated",
            },
        },
    },
    categories=[ToolCategory.PLATFORM],
)
async def _list_my_activities(executor: ToolExecutor, input: dict) -> dict:
    list_type = input.get("type", "participated")
    lang = executor._tool_lang()

    if list_type == "favorited":
        q = (
            select(models.Activity)
            .join(models.ActivityFavorite, models.Activity.id == models.ActivityFavorite.activity_id)
            .where(models.ActivityFavorite.user_id == executor.user.id)
            .order_by(desc(models.ActivityFavorite.created_at)).limit(20)
        )
    else:
        q = (
            select(models.Activity)
            .join(models.TaskParticipant, and_(
                models.TaskParticipant.activity_id == models.Activity.id,
                models.TaskParticipant.user_id == executor.user.id,
            ))
            .where(models.TaskParticipant.activity_id.isnot(None))
            .distinct()
            .order_by(desc(models.Activity.created_at)).limit(20)
        )

    rows = (await executor.db.execute(q)).scalars().all()
    activities = [{
        "id": a.id, "title": _activity_title(a, lang),
        "status": a.status, "reward_type": a.reward_type,
        "deadline": format_iso_utc(a.deadline) if a.deadline else None,
    } for a in rows]

    return {"activities": activities, "count": len(activities), "type": list_type}


@tool_registry.register(
    name="list_forum_categories",
    description="获取论坛分类列表。Get the list of forum categories.",
    input_schema={"type": "object", "properties": {}},
    categories=[ToolCategory.PLATFORM],
)
async def _list_forum_categories(executor: ToolExecutor, input: dict) -> dict:
    from app.forum_routes import visible_forums
    rows = (await executor.db.execute(
        select(models.ForumCategory)
        .where(models.ForumCategory.is_visible == True)
        .order_by(models.ForumCategory.sort_order.asc())
    )).scalars().all()

    visible_ids = await visible_forums(executor.user, executor.db)
    general_ids = [r[0] for r in (await executor.db.execute(
        select(models.ForumCategory.id).where(and_(
            models.ForumCategory.type == "general",
            models.ForumCategory.is_visible == True,
        ))
    )).all()]
    visible_set = set(visible_ids) | set(general_ids)
    rows = [c for c in rows if c.id in visible_set]

    lang_key = executor._faq_lang_key()
    categories = [{
        "id": c.id,
        "name": getattr(c, f"name_{lang_key}", None) or c.name,
        "post_count": c.post_count,
        "type": c.type,
    } for c in rows]

    return {"categories": categories, "count": len(categories)}


@tool_registry.register(
    name="get_task_reviews",
    description="查询任务的评价列表。Get reviews for a specific task.",
    input_schema={
        "type": "object",
        "properties": {"task_id": {"type": "integer", "description": "任务 ID"}},
        "required": ["task_id"],
    },
    categories=[ToolCategory.TASK],
)
async def _get_task_reviews(executor: ToolExecutor, input: dict) -> dict:
    msgs = _TOOL_ERRORS.get(executor._tool_lang(), _TOOL_ERRORS["en"])
    task_id = input.get("task_id")
    if not task_id:
        return {"error": msgs["task_id_required"]}

    task = (await executor.db.execute(
        select(models.Task).where(models.Task.id == task_id)
    )).scalar_one_or_none()
    if not task:
        return {"error": msgs["task_not_found"]}

    user_id = executor.user.id
    is_related = (
        task.poster_id == user_id or task.taker_id == user_id
        or task.originating_user_id == user_id
    )
    if not is_related:
        is_related = (await executor.db.execute(
            select(func.count()).select_from(models.TaskParticipant).where(and_(
                models.TaskParticipant.task_id == task_id,
                models.TaskParticipant.user_id == user_id,
            ))
        )).scalar() or 0
    if not task.is_public and not is_related:
        return {"error": msgs["task_no_permission"]}

    rows = (await executor.db.execute(
        select(models.Review, models.User.name)
        .join(models.User, models.Review.user_id == models.User.id)
        .where(models.Review.task_id == task_id)
        .order_by(desc(models.Review.created_at))
    )).all()

    reviews = [{
        "rating": review.rating,
        "comment": _truncate(review.comment, 200),
        "reviewer_name": reviewer_name if not review.is_anonymous else None,
        "is_anonymous": bool(review.is_anonymous),
    } for review, reviewer_name in rows]

    return {"reviews": reviews, "count": len(reviews)}


# =====================================================================
# Phase 3: 补齐缺失的只读查询工具
# =====================================================================

@tool_registry.register(
    name="get_my_wallet_summary",
    description="查询当前用户的钱包概况：积分余额、收款账户状态、最近支付记录。Get user's wallet summary: points, payout account status, recent payments.",
    input_schema={"type": "object", "properties": {}},
    categories=[ToolCategory.PROFILE],
)
async def _get_my_wallet_summary(executor: ToolExecutor, input: dict) -> dict:
    user = executor.user

    pa = (await executor.db.execute(
        select(models.PointsAccount).where(models.PointsAccount.user_id == user.id)
    )).scalar_one_or_none()
    points_balance = int(pa.balance) if pa else 0

    has_stripe_account = bool(user.stripe_account_id and user.stripe_account_id.startswith("acct_"))

    recent_payments = (await executor.db.execute(
        select(models.PaymentHistory)
        .where(models.PaymentHistory.user_id == user.id)
        .order_by(desc(models.PaymentHistory.created_at))
        .limit(5)
    )).scalars().all()

    payments = [{
        "order_no": p.order_no,
        "total_amount": round(p.total_amount / 100, 2) if p.total_amount else 0,
        "final_amount": round(p.final_amount / 100, 2) if p.final_amount else 0,
        "currency": p.currency,
        "status": p.status,
        "payment_method": p.payment_method,
        "created_at": format_iso_utc(p.created_at) if p.created_at else None,
    } for p in recent_payments]

    lang = executor._tool_lang()
    return {
        "points_balance": points_balance,
        "has_payout_account": has_stripe_account,
        "payout_account_hint": ("如需查看详细余额和提现，请前往 App 钱包页面" if lang == "zh"
                                else "For detailed balance and payouts, please visit the Wallet page in the app"),
        "recent_payments": payments,
        "recent_payments_count": len(payments),
    }


@tool_registry.register(
    name="get_my_messages_summary",
    description="查询当前用户的私聊消息摘要：未读消息数和最近联系人。Get user's chat summary: unread count and recent contacts.",
    input_schema={"type": "object", "properties": {}},
    categories=[ToolCategory.NOTIFICATION],
)
async def _get_my_messages_summary(executor: ToolExecutor, input: dict) -> dict:
    user_id = executor.user.id

    unread_count = (await executor.db.execute(
        select(func.count()).select_from(models.Message)
        .where(and_(
            models.Message.receiver_id == user_id,
            models.Message.is_read == 0,
            models.Message.conversation_type == "task",
        ))
    )).scalar() or 0

    recent_msgs = (await executor.db.execute(
        select(models.Message)
        .where(or_(
            models.Message.sender_id == user_id,
            models.Message.receiver_id == user_id,
        ))
        .order_by(desc(models.Message.created_at))
        .limit(10)
    )).scalars().all()

    seen_contacts = set()
    contacts = []
    for msg in recent_msgs:
        contact_id = msg.receiver_id if msg.sender_id == user_id else msg.sender_id
        if not contact_id or contact_id in seen_contacts:
            continue
        seen_contacts.add(contact_id)
        contact_name = (await executor.db.execute(
            select(models.User.name).where(models.User.id == contact_id)
        )).scalar()
        contacts.append({
            "user_id": contact_id,
            "name": contact_name or "Unknown",
            "last_message_preview": _truncate(msg.content, 50),
            "last_message_at": format_iso_utc(msg.created_at) if msg.created_at else None,
        })
        if len(contacts) >= 5:
            break

    return {
        "unread_count": unread_count,
        "recent_contacts": contacts,
    }


@tool_registry.register(
    name="get_my_vip_status",
    description="查询当前用户的 VIP 会员状态。Get the current user's VIP membership status.",
    input_schema={"type": "object", "properties": {}},
    categories=[ToolCategory.PROFILE],
)
async def _get_my_vip_status(executor: ToolExecutor, input: dict) -> dict:
    user = executor.user
    lang = executor._tool_lang()

    vip = (await executor.db.execute(
        select(models.VIPSubscription)
        .where(and_(
            models.VIPSubscription.user_id == user.id,
            models.VIPSubscription.status.in_(["active", "grace_period"]),
        ))
        .order_by(desc(models.VIPSubscription.expires_date))
        .limit(1)
    )).scalar_one_or_none()

    if not vip:
        return {
            "is_vip": False,
            "message": "你当前不是 VIP 会员" if lang == "zh" else "You are not currently a VIP member",
        }

    return {
        "is_vip": True,
        "product_id": vip.product_id,
        "status": vip.status,
        "purchase_date": format_iso_utc(vip.purchase_date) if vip.purchase_date else None,
        "expires_date": format_iso_utc(vip.expires_date) if vip.expires_date else None,
        "auto_renew": bool(vip.auto_renew_status),
        "is_trial": bool(vip.is_trial_period),
    }


@tool_registry.register(
    name="get_my_student_verification",
    description="查询当前用户的学生认证状态。Get the current user's student verification status.",
    input_schema={"type": "object", "properties": {}},
    categories=[ToolCategory.PROFILE],
)
async def _get_my_student_verification(executor: ToolExecutor, input: dict) -> dict:
    user = executor.user
    lang = executor._tool_lang()

    sv = (await executor.db.execute(
        select(models.StudentVerification, models.University.name, models.University.name_cn)
        .join(models.University, models.StudentVerification.university_id == models.University.id)
        .where(models.StudentVerification.user_id == user.id)
        .order_by(desc(models.StudentVerification.created_at))
        .limit(1)
    )).first()

    if not sv:
        return {
            "is_verified": False,
            "message": "你尚未进行学生认证" if lang == "zh" else "You have not completed student verification",
        }

    verification, uni_name_en, uni_name_cn = sv
    uni_name = uni_name_cn if lang == "zh" and uni_name_cn else uni_name_en

    return {
        "is_verified": verification.status == "verified",
        "status": verification.status,
        "university": uni_name,
        "email": verification.email,
        "verified_at": format_iso_utc(verification.verified_at) if verification.verified_at else None,
        "expires_at": format_iso_utc(verification.expires_at) if verification.expires_at else None,
    }


@tool_registry.register(
    name="get_my_checkin_status",
    description="查询当前用户的签到状态和奖励信息。Get the current user's check-in status and rewards.",
    input_schema={"type": "object", "properties": {}},
    categories=[ToolCategory.PROFILE],
)
async def _get_my_checkin_status(executor: ToolExecutor, input: dict) -> dict:
    from datetime import date, datetime, timezone
    user_id = executor.user.id
    today = datetime.now(timezone.utc).date()

    today_checkin = (await executor.db.execute(
        select(models.CheckIn).where(and_(
            models.CheckIn.user_id == user_id,
            models.CheckIn.check_in_date == today,
        ))
    )).scalar_one_or_none()

    latest_checkin = (await executor.db.execute(
        select(models.CheckIn).where(models.CheckIn.user_id == user_id)
        .order_by(desc(models.CheckIn.check_in_date))
        .limit(1)
    )).scalar_one_or_none()

    consecutive_days = latest_checkin.consecutive_days if latest_checkin else 0

    next_reward = (await executor.db.execute(
        select(models.CheckInReward)
        .where(and_(
            models.CheckInReward.is_active == True,
            models.CheckInReward.consecutive_days > consecutive_days,
        ))
        .order_by(models.CheckInReward.consecutive_days.asc())
        .limit(1)
    )).scalar_one_or_none()

    result = {
        "checked_in_today": today_checkin is not None,
        "consecutive_days": consecutive_days,
    }
    if today_checkin:
        result["today_reward"] = {
            "type": today_checkin.reward_type,
            "points": today_checkin.points_reward,
            "description": today_checkin.reward_description,
        }
    if next_reward:
        result["next_milestone"] = {
            "days_needed": next_reward.consecutive_days,
            "reward_type": next_reward.reward_type,
            "points_reward": next_reward.points_reward,
            "description": next_reward.reward_description,
        }

    return result


@tool_registry.register(
    name="get_my_flea_market_items",
    description="查询当前用户的跳蚤市场商品、收藏和购买记录。Get user's flea market items, favorites, and purchase records.",
    input_schema={
        "type": "object",
        "properties": {
            "type": {
                "type": "string",
                "enum": ["my_items", "favorites", "purchases"],
                "description": "查询类型：my_items（我卖的）、favorites（收藏）、purchases（购买记录），默认 my_items",
            },
        },
    },
    categories=[ToolCategory.PLATFORM],
)
async def _get_my_flea_market_items(executor: ToolExecutor, input: dict) -> dict:
    query_type = input.get("type", "my_items")
    user_id = executor.user.id

    if query_type == "favorites":
        rows = (await executor.db.execute(
            select(models.FleaMarketItem)
            .join(models.FleaMarketFavorite, models.FleaMarketItem.id == models.FleaMarketFavorite.item_id)
            .where(models.FleaMarketFavorite.user_id == user_id)
            .order_by(desc(models.FleaMarketFavorite.created_at))
            .limit(10)
        )).scalars().all()
        items = [{
            "id": item.id, "title": item.title,
            "price": float(item.price), "currency": item.currency,
            "status": item.status,
        } for item in rows]
        return {"items": items, "count": len(items), "type": "favorites"}

    if query_type == "purchases":
        rows = (await executor.db.execute(
            select(models.FleaMarketPurchaseRequest, models.FleaMarketItem.title, models.FleaMarketItem.price)
            .join(models.FleaMarketItem, models.FleaMarketPurchaseRequest.item_id == models.FleaMarketItem.id)
            .where(models.FleaMarketPurchaseRequest.buyer_id == user_id)
            .order_by(desc(models.FleaMarketPurchaseRequest.created_at))
            .limit(10)
        )).all()
        purchases = [{
            "item_title": title,
            "item_price": float(price),
            "proposed_price": float(req.proposed_price) if req.proposed_price else None,
            "status": req.status,
            "created_at": format_iso_utc(req.created_at) if req.created_at else None,
        } for req, title, price in rows]
        return {"purchases": purchases, "count": len(purchases), "type": "purchases"}

    # my_items (default)
    rows = (await executor.db.execute(
        select(models.FleaMarketItem)
        .where(models.FleaMarketItem.seller_id == user_id)
        .order_by(desc(models.FleaMarketItem.created_at))
        .limit(10)
    )).scalars().all()
    items = [{
        "id": item.id, "title": item.title,
        "price": float(item.price), "currency": item.currency,
        "status": item.status, "view_count": item.view_count,
    } for item in rows]
    return {"items": items, "count": len(items), "type": "my_items"}


@tool_registry.register(
    name="search_forum_posts",
    description="搜索论坛帖子或查看热帖/我的收藏/我的回复。Search forum posts, view hot posts, my favorites, or my replies.",
    input_schema={
        "type": "object",
        "properties": {
            "type": {
                "type": "string",
                "enum": ["search", "hot", "my_favorites", "my_replies"],
                "description": "查询类型：search（搜索）、hot（热帖）、my_favorites（我的收藏）、my_replies（我的回复），默认 search",
            },
            "keyword": {
                "type": "string",
                "description": "搜索关键词（type=search 时使用）",
            },
        },
    },
    categories=[ToolCategory.PLATFORM],
)
async def _search_forum_posts(executor: ToolExecutor, input: dict) -> dict:
    from app.forum_routes import visible_forums
    query_type = input.get("type", "search")
    user_id = executor.user.id
    lang = executor._tool_lang()

    visible_ids = await visible_forums(executor.user, executor.db)
    general_ids = [r[0] for r in (await executor.db.execute(
        select(models.ForumCategory.id).where(and_(
            models.ForumCategory.type == "general",
            models.ForumCategory.is_visible == True,
        ))
    )).all()]
    allowed_cat_ids = list(set(visible_ids) | set(general_ids))

    if query_type == "my_favorites":
        rows = (await executor.db.execute(
            select(models.ForumPost)
            .join(models.ForumFavorite, models.ForumPost.id == models.ForumFavorite.post_id)
            .where(and_(
                models.ForumFavorite.user_id == user_id,
                models.ForumPost.is_deleted == False,
                models.ForumPost.category_id.in_(allowed_cat_ids),
            ))
            .order_by(desc(models.ForumFavorite.created_at))
            .limit(10)
        )).scalars().all()
        posts = [{
            "id": p.id, "title": _forum_post_display_title(p, lang),
            "view_count": p.view_count, "reply_count": p.reply_count,
        } for p in rows]
        return {"posts": posts, "count": len(posts), "type": "my_favorites"}

    if query_type == "my_replies":
        rows = (await executor.db.execute(
            select(
                models.ForumReply.id,
                models.ForumReply.content,
                models.ForumReply.created_at,
                models.ForumPost.id.label("post_id"),
                models.ForumPost.title,
            )
            .join(models.ForumPost, models.ForumReply.post_id == models.ForumPost.id)
            .where(and_(
                models.ForumReply.author_id == user_id,
                models.ForumReply.is_deleted == False,
                models.ForumPost.is_deleted == False,
                models.ForumPost.category_id.in_(allowed_cat_ids),
            ))
            .order_by(desc(models.ForumReply.created_at))
            .limit(10)
        )).all()
        replies = [{
            "reply_id": r.id,
            "post_id": r.post_id,
            "post_title": r.title or "",
            "content_preview": _truncate(r.content, 100),
            "created_at": format_iso_utc(r.created_at) if r.created_at else None,
        } for r in rows]
        return {"replies": replies, "count": len(replies), "type": "my_replies"}

    if query_type == "hot":
        rows = (await executor.db.execute(
            select(models.ForumPost)
            .where(and_(
                models.ForumPost.is_deleted == False,
                models.ForumPost.is_visible == True,
                models.ForumPost.category_id.in_(allowed_cat_ids),
            ))
            .order_by(desc(models.ForumPost.view_count))
            .limit(10)
        )).scalars().all()
        posts = [{
            "id": p.id, "title": _forum_post_display_title(p, lang),
            "view_count": p.view_count, "reply_count": p.reply_count,
            "like_count": p.like_count,
        } for p in rows]
        return {"posts": posts, "count": len(posts), "type": "hot"}

    # search (default)
    keyword = input.get("keyword", "")
    if not keyword or len(keyword.strip()) < 2:
        return {"posts": [], "count": 0, "type": "search", "message": "请提供搜索关键词"}

    like_kw = f"%{keyword.strip()[:80]}%"
    rows = (await executor.db.execute(
        select(models.ForumPost)
        .where(and_(
            models.ForumPost.is_deleted == False,
            models.ForumPost.is_visible == True,
            models.ForumPost.category_id.in_(allowed_cat_ids),
            or_(
                models.ForumPost.title.ilike(like_kw),
                models.ForumPost.content.ilike(like_kw),
            ),
        ))
        .order_by(desc(models.ForumPost.created_at))
        .limit(10)
    )).scalars().all()
    posts = [{
        "id": p.id, "title": _forum_post_display_title(p, lang),
        "view_count": p.view_count, "reply_count": p.reply_count,
    } for p in rows]
    return {"posts": posts, "count": len(posts), "type": "search"}
