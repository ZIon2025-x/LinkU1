"""
AI 工具安全执行器 — 自动鉴权，只能访问当前用户有权限的数据
FAQ 答案从数据库 faq_sections / faq_items 读取，与 Web/iOS 一致。
"""

import json
import logging
from decimal import Decimal
from typing import Any

from sqlalchemy import select, and_, or_, func, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.utils.time_utils import format_iso_utc

logger = logging.getLogger(__name__)

# AI 本地 FAQ 主题 → 数据库 faq_sections.key
# 覆盖全部 20 个 faq_sections，每个 section 有唯一 topic
TOPIC_TO_SECTION_KEY = {
    "about": "about",
    "publish": "posting_taking",
    "accept": "task_flow",
    "payment": "payment_refunds",
    "fee": "payment_methods",
    "dispute": "confirmation_disputes",
    "account": "account_login",
    "wallet": "payment_methods",
    "cancel": "cancel_task",
    "report": "report_safety",
    "privacy": "privacy_security",
    "flea": "flea_market",
    "forum": "forum",
    "application": "task_application",
    "review": "reviews_reputation",
    "student": "student_verification",
    "expert": "task_experts",
    "activity": "activities",
    "coupon": "coupons_points",
    "notification": "notifications",
    "message_support": "messaging_support",
    "vip": "vip",
    "linker": "linker_ai",
}


def _decimal_to_float(obj: Any) -> Any:
    """递归转换 Decimal 为 float，使结果可 JSON 序列化"""
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, dict):
        return {k: _decimal_to_float(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_decimal_to_float(i) for i in obj]
    return obj


_TOOL_ERRORS = {
    "zh": {
        "execution_failed": "工具执行失败，请稍后重试",
        "task_id_required": "需要提供 task_id",
        "task_not_found": "任务不存在",
        "task_no_permission": "无权查看此任务",
        "leaderboard_not_found": "排行榜不存在",
    },
    "en": {
        "execution_failed": "Tool execution failed. Please try again later.",
        "task_id_required": "task_id is required",
        "task_not_found": "Task not found",
        "task_no_permission": "You do not have permission to view this task",
        "leaderboard_not_found": "Leaderboard not found",
    },
}


class ToolExecutor:
    """安全执行 AI 请求的工具调用"""

    def __init__(self, db: AsyncSession, user: models.User):
        self.db = db
        self.user = user
        self._handlers = {
            "query_my_tasks": self._query_my_tasks,
            "get_task_detail": self._get_task_detail,
            "search_tasks": self._search_tasks,
            "get_my_profile": self._get_my_profile,
            "get_platform_faq": self._get_platform_faq,
            "check_cs_availability": self._check_cs_availability,
            "get_my_points_and_coupons": self._get_my_points_and_coupons,
            "list_activities": self._list_activities,
            "get_my_notifications_summary": self._get_my_notifications_summary,
            "list_my_forum_posts": self._list_my_forum_posts,
            "search_flea_market": self._search_flea_market,
            "get_leaderboard_summary": self._get_leaderboard_summary,
            "list_task_experts": self._list_task_experts,
        }

    def _tool_lang(self) -> str:
        """当前请求的回复语言。优先 request_lang（由 agent 按用户消息推断传入），否则按用户偏好，空/未设则默认英文。"""
        if getattr(self, "_request_lang", None) is not None:
            return self._request_lang
        pref = (self.user.language_preference or "").strip().lower()
        return "zh" if pref.startswith("zh") else "en"

    async def execute(self, tool_name: str, tool_input: dict, request_lang: str | None = None) -> dict:
        """执行工具，返回结果（自动鉴权）。request_lang 由 agent 按用户消息推断传入时，工具返回内容语种与其一致。"""
        handler = self._handlers.get(tool_name)
        self._request_lang = request_lang
        try:
            msgs = _TOOL_ERRORS.get(self._tool_lang(), _TOOL_ERRORS["en"])
            if not handler:
                return {"error": f"Unknown tool: {tool_name}"}
            try:
                result = await handler(tool_input)
                return _decimal_to_float(result)
            except Exception as e:
                logger.error(f"Tool execution error: {tool_name} — {e}")
                return {"error": msgs["execution_failed"]}
        finally:
            self._request_lang = None

    def _faq_lang_key(self) -> str:
        """与 _tool_lang 一致，供 FAQ 等按语言取字段。"""
        return "en" if self._tool_lang() == "en" else "zh"

    async def get_faq_for_agent(self, topic: str, lang: str) -> str | None:
        """按 AI 主题从数据库取该分类下所有 FAQ，拼接为结构化回答。"""
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
        # 多条时拼接：Q: ... A: ...
        parts = []
        for row in rows:
            question = getattr(row, f"question_{lang_key}")
            answer = getattr(row, f"answer_{lang_key}")
            parts.append(f"**{question}**\n{answer}")
        return "\n\n".join(parts)

    async def get_faq_by_message(self, message: str, lang: str) -> str | None:
        """按用户消息在 faq_items 的 question 中模糊匹配，返回第一条答案。"""
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

    async def _query_my_tasks(self, input: dict) -> dict:
        status_filter = input.get("status", "all")
        page = max(1, input.get("page", 1))
        page_size = 10

        conditions = [
            or_(
                models.Task.poster_id == self.user.id,
                models.Task.taker_id == self.user.id,
            )
        ]
        if status_filter != "all":
            conditions.append(models.Task.status == status_filter)

        # Count
        count_q = select(func.count()).select_from(models.Task).where(and_(*conditions))
        total = (await self.db.execute(count_q)).scalar() or 0

        # Query
        q = (
            select(models.Task)
            .where(and_(*conditions))
            .order_by(desc(models.Task.created_at))
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.db.execute(q)).scalars().all()

        tasks = []
        for t in rows:
            tasks.append({
                "id": t.id,
                "title": t.title,
                "status": t.status,
                "reward": t.reward,
                "currency": t.currency,
                "task_type": t.task_type,
                "is_poster": t.poster_id == self.user.id,
                "created_at": format_iso_utc(t.created_at) if t.created_at else None,
                "deadline": format_iso_utc(t.deadline) if t.deadline else None,
            })

        return {"tasks": tasks, "total": total, "page": page, "page_size": page_size}

    async def _get_task_detail(self, input: dict) -> dict:
        msgs = _TOOL_ERRORS.get(self._tool_lang(), _TOOL_ERRORS["en"])
        task_id = input.get("task_id")
        if not task_id:
            return {"error": msgs["task_id_required"]}

        q = select(models.Task).where(models.Task.id == task_id)
        task = (await self.db.execute(q)).scalar_one_or_none()
        if not task:
            return {"error": msgs["task_not_found"]}

        # 权限检查：公开任务或自己的任务
        is_owner = task.poster_id == self.user.id or task.taker_id == self.user.id
        if not task.is_public and not is_owner:
            return {"error": msgs["task_no_permission"]}

        return {
            "id": task.id,
            "title": task.title,
            "description": task.description,
            "status": task.status,
            "reward": task.reward,
            "currency": task.currency,
            "task_type": task.task_type,
            "location": task.location,
            "is_poster": task.poster_id == self.user.id,
            "is_taker": task.taker_id == self.user.id,
            "is_paid": bool(task.is_paid),
            "is_confirmed": bool(task.is_confirmed),
            "created_at": format_iso_utc(task.created_at) if task.created_at else None,
            "deadline": format_iso_utc(task.deadline) if task.deadline else None,
            "completed_at": format_iso_utc(task.completed_at) if task.completed_at else None,
        }

    async def _search_tasks(self, input: dict) -> dict:
        keyword = input.get("keyword", "")
        task_type = input.get("task_type")
        min_reward = input.get("min_reward")
        max_reward = input.get("max_reward")

        conditions = [
            models.Task.is_public == 1,
            models.Task.status == "open",
        ]
        if keyword:
            like_kw = f"%{keyword}%"
            conditions.append(
                or_(
                    models.Task.title.ilike(like_kw),
                    models.Task.description.ilike(like_kw),
                )
            )
        if task_type:
            conditions.append(models.Task.task_type == task_type)
        if min_reward is not None:
            conditions.append(models.Task.reward >= min_reward)
        if max_reward is not None:
            conditions.append(models.Task.reward <= max_reward)

        q = (
            select(models.Task)
            .where(and_(*conditions))
            .order_by(desc(models.Task.created_at))
            .limit(10)
        )
        rows = (await self.db.execute(q)).scalars().all()

        tasks = []
        for t in rows:
            tasks.append({
                "id": t.id,
                "title": t.title,
                "reward": t.reward,
                "currency": t.currency,
                "task_type": t.task_type,
                "location": t.location,
                "created_at": format_iso_utc(t.created_at) if t.created_at else None,
                "deadline": format_iso_utc(t.deadline) if t.deadline else None,
            })

        return {"tasks": tasks, "count": len(tasks)}

    async def _get_my_profile(self, input: dict) -> dict:
        u = self.user

        # 积分余额
        pa_q = select(models.PointsAccount.balance).where(
            models.PointsAccount.user_id == u.id
        )
        points_balance = (await self.db.execute(pa_q)).scalar() or 0

        # 可用优惠券数量
        from app.utils.time_utils import get_utc_time
        now = get_utc_time()
        coupon_count_q = (
            select(func.count())
            .select_from(models.UserCoupon)
            .join(models.Coupon, models.UserCoupon.coupon_id == models.Coupon.id)
            .where(and_(
                models.UserCoupon.user_id == u.id,
                models.UserCoupon.status == "unused",
                models.Coupon.valid_until > now,
            ))
        )
        available_coupons_count = (await self.db.execute(coupon_count_q)).scalar() or 0

        return {
            "id": u.id,
            "name": u.name,
            "email": u.email,
            "avatar": u.avatar,
            "user_level": u.user_level,
            "task_count": u.task_count,
            "completed_task_count": u.completed_task_count,
            "avg_rating": u.avg_rating,
            "is_verified": bool(u.is_verified),
            "language_preference": u.language_preference,
            "points_balance": int(points_balance),
            "available_coupons_count": available_coupons_count,
            "note": "余额请在 App 钱包页查看 / Check wallet page for balance",
            "created_at": format_iso_utc(u.created_at) if u.created_at else None,
        }

    async def _get_platform_faq(self, input: dict) -> dict:
        """从数据库 faq_items 按问题关键词匹配或返回全部分类首条。"""
        question = (input.get("question") or "").strip().lower()
        lang_key = self._faq_lang_key()
        question_col = getattr(models.FaqItem, f"question_{lang_key}")

        if question and len(question) >= 2:
            pattern = f"%{question[:100]}%"
            q = (
                select(models.FaqItem, models.FaqSection.key)
                .join(models.FaqSection, models.FaqItem.section_id == models.FaqSection.id)
                .where(question_col.ilike(pattern))
                .order_by(models.FaqSection.sort_order, models.FaqItem.sort_order)
                .limit(10)
            )
            rows = (await self.db.execute(q)).all()
            matches = [{"topic": key, "answer": getattr(item, f"answer_{lang_key}")} for item, key in rows]
        else:
            q_sec = select(models.FaqSection).order_by(models.FaqSection.sort_order.asc())
            sections = (await self.db.execute(q_sec)).scalars().all()
            matches = []
            for sec in sections:
                q_item = (
                    select(models.FaqItem)
                    .where(models.FaqItem.section_id == sec.id)
                    .order_by(models.FaqItem.sort_order.asc())
                    .limit(1)
                )
                item = (await self.db.execute(q_item)).scalar_one_or_none()
                if item:
                    matches.append({"topic": sec.key, "answer": getattr(item, f"answer_{lang_key}")})

        return {"faq": matches}

    async def _check_cs_availability(self, input: dict) -> dict:
        """检查是否有人工客服在线"""
        from sqlalchemy import cast, Integer
        count_q = select(func.count(models.CustomerService.id)).where(
            cast(models.CustomerService.is_online, Integer) == 1
        )
        online_count = (await self.db.execute(count_q)).scalar() or 0
        return {"available": online_count > 0, "online_count": online_count}

    async def _get_my_points_and_coupons(self, input: dict) -> dict:
        """积分余额 + 可用优惠券列表"""
        from app.utils.time_utils import get_utc_time
        now = get_utc_time()

        # 积分账户
        pa_q = select(models.PointsAccount).where(
            models.PointsAccount.user_id == self.user.id
        )
        pa = (await self.db.execute(pa_q)).scalar_one_or_none()
        points = {
            "balance": int(pa.balance) if pa else 0,
            "total_earned": int(pa.total_earned) if pa else 0,
            "total_spent": int(pa.total_spent) if pa else 0,
        }

        # 可用优惠券
        coupon_q = (
            select(models.UserCoupon, models.Coupon)
            .join(models.Coupon, models.UserCoupon.coupon_id == models.Coupon.id)
            .where(and_(
                models.UserCoupon.user_id == self.user.id,
                models.UserCoupon.status == "unused",
                models.Coupon.valid_until > now,
            ))
            .order_by(models.Coupon.valid_until.asc())
            .limit(10)
        )
        rows = (await self.db.execute(coupon_q)).all()
        coupons = []
        for uc, c in rows:
            coupons.append({
                "name": c.name,
                "type": c.type,
                "discount_value": int(c.discount_value) if c.discount_value else 0,
                "currency": c.currency,
                "valid_until": format_iso_utc(c.valid_until) if c.valid_until else None,
            })

        return {"points": points, "coupons": coupons}

    async def _list_activities(self, input: dict) -> dict:
        """进行中的公开活动"""
        keyword = input.get("keyword", "")
        conditions = [
            models.Activity.status == "open",
            models.Activity.is_public == True,
        ]
        if keyword:
            like_kw = f"%{keyword}%"
            conditions.append(
                or_(
                    models.Activity.title.ilike(like_kw),
                    models.Activity.description.ilike(like_kw),
                )
            )

        q = (
            select(models.Activity)
            .where(and_(*conditions))
            .order_by(desc(models.Activity.created_at))
            .limit(10)
        )
        rows = (await self.db.execute(q)).scalars().all()

        activities = []
        for a in rows:
            activities.append({
                "id": a.id,
                "title": a.title,
                "location": a.location,
                "max_participants": a.max_participants,
                "reward_type": a.reward_type,
                "deadline": format_iso_utc(a.deadline) if a.deadline else None,
                "created_at": format_iso_utc(a.created_at) if a.created_at else None,
            })

        return {"activities": activities, "count": len(activities)}

    async def _get_my_notifications_summary(self, input: dict) -> dict:
        """未读通知数 + 最近 5 条通知"""
        # 未读数
        unread_q = (
            select(func.count())
            .select_from(models.Notification)
            .where(and_(
                models.Notification.user_id == self.user.id,
                models.Notification.is_read == 0,
            ))
        )
        unread_count = (await self.db.execute(unread_q)).scalar() or 0

        # 最近 5 条
        recent_q = (
            select(models.Notification)
            .where(models.Notification.user_id == self.user.id)
            .order_by(desc(models.Notification.created_at))
            .limit(5)
        )
        rows = (await self.db.execute(recent_q)).scalars().all()

        recent = []
        for n in rows:
            recent.append({
                "type": n.type,
                "title": n.title or "",
                "title_en": n.title_en or "",
                "is_read": bool(n.is_read),
                "created_at": format_iso_utc(n.created_at) if n.created_at else None,
            })

        return {"unread_count": unread_count, "recent": recent}

    async def _list_my_forum_posts(self, input: dict) -> dict:
        """用户发布的论坛帖子"""
        page = max(1, input.get("page", 1))
        page_size = 10

        conditions = [
            models.ForumPost.author_id == self.user.id,
            models.ForumPost.is_deleted == False,
        ]

        count_q = (
            select(func.count())
            .select_from(models.ForumPost)
            .where(and_(*conditions))
        )
        total = (await self.db.execute(count_q)).scalar() or 0

        q = (
            select(models.ForumPost, models.ForumCategory.name)
            .join(models.ForumCategory, models.ForumPost.category_id == models.ForumCategory.id)
            .where(and_(*conditions))
            .order_by(desc(models.ForumPost.created_at))
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.db.execute(q)).all()

        posts = []
        for post, category_name in rows:
            posts.append({
                "id": post.id,
                "title": post.title,
                "category_name": category_name,
                "view_count": post.view_count,
                "reply_count": post.reply_count,
                "created_at": format_iso_utc(post.created_at) if post.created_at else None,
            })

        return {"posts": posts, "total": total}

    async def _search_flea_market(self, input: dict) -> dict:
        """搜索跳蚤市场商品"""
        keyword = input.get("keyword", "")
        category = input.get("category")
        min_price = input.get("min_price")
        max_price = input.get("max_price")

        conditions = [models.FleaMarketItem.status == "active"]
        if keyword:
            like_kw = f"%{keyword}%"
            conditions.append(
                or_(
                    models.FleaMarketItem.title.ilike(like_kw),
                    models.FleaMarketItem.description.ilike(like_kw),
                )
            )
        if category:
            conditions.append(models.FleaMarketItem.category == category)
        if min_price is not None:
            conditions.append(models.FleaMarketItem.price >= min_price)
        if max_price is not None:
            conditions.append(models.FleaMarketItem.price <= max_price)

        q = (
            select(models.FleaMarketItem)
            .where(and_(*conditions))
            .order_by(desc(models.FleaMarketItem.created_at))
            .limit(10)
        )
        rows = (await self.db.execute(q)).scalars().all()

        items = []
        for item in rows:
            items.append({
                "id": item.id,
                "title": item.title,
                "price": float(item.price),
                "currency": item.currency,
                "location": item.location,
                "category": item.category,
                "created_at": format_iso_utc(item.created_at) if item.created_at else None,
            })

        return {"items": items, "count": len(items)}

    async def _get_leaderboard_summary(self, input: dict) -> dict:
        """排行榜概览或单榜详情"""
        leaderboard_id = input.get("leaderboard_id")

        if leaderboard_id:
            # 单个排行榜详情
            lb_q = select(models.CustomLeaderboard).where(
                models.CustomLeaderboard.id == leaderboard_id
            )
            lb = (await self.db.execute(lb_q)).scalar_one_or_none()
            if not lb:
                msgs = _TOOL_ERRORS.get(self._tool_lang(), _TOOL_ERRORS["en"])
                return {"error": msgs["leaderboard_not_found"]}

            items_q = (
                select(models.LeaderboardItem)
                .where(models.LeaderboardItem.leaderboard_id == leaderboard_id)
                .order_by(desc(models.LeaderboardItem.net_votes))
                .limit(10)
            )
            rows = (await self.db.execute(items_q)).scalars().all()
            items = []
            for item in rows:
                items.append({
                    "name": item.name,
                    "description": item.description,
                    "net_votes": item.net_votes,
                })
            return {"name": lb.name, "description": lb.description, "items": items}

        # 所有活跃排行榜
        q = (
            select(models.CustomLeaderboard)
            .where(models.CustomLeaderboard.status == "active")
            .order_by(desc(models.CustomLeaderboard.vote_count))
            .limit(10)
        )
        rows = (await self.db.execute(q)).scalars().all()
        leaderboards = []
        for lb in rows:
            leaderboards.append({
                "id": lb.id,
                "name": lb.name,
                "location": lb.location,
                "item_count": lb.item_count,
                "vote_count": lb.vote_count,
            })
        return {"leaderboards": leaderboards}

    async def _list_task_experts(self, input: dict) -> dict:
        """活跃达人列表"""
        keyword = input.get("keyword", "")

        conditions = [models.TaskExpert.status == "active"]
        if keyword:
            like_kw = f"%{keyword}%"
            conditions.append(
                or_(
                    models.TaskExpert.expert_name.ilike(like_kw),
                    models.TaskExpert.bio.ilike(like_kw),
                )
            )

        q = (
            select(models.TaskExpert, models.User.name)
            .join(models.User, models.TaskExpert.id == models.User.id)
            .where(and_(*conditions))
            .order_by(desc(models.TaskExpert.rating))
            .limit(10)
        )
        rows = (await self.db.execute(q)).all()

        experts = []
        for expert, user_name in rows:
            experts.append({
                "id": expert.id,
                "name": expert.expert_name or user_name,
                "bio": (expert.bio or "")[:100],
                "rating": float(expert.rating) if expert.rating else 0,
                "completed_tasks": expert.completed_tasks,
            })

        return {"experts": experts, "count": len(experts)}
