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
from app.forum_routes import assert_forum_visible, visible_forums
from app.utils.task_activity_display import (
    get_activity_display_title as _activity_title,
    get_activity_display_description as _activity_description,
    get_task_display_title as _task_title,
    get_task_display_description as _task_description,
)
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


class ToolExecutor:
    """安全执行 AI 请求的工具调用"""

    def __init__(self, db: AsyncSession, user: models.User):
        self.db = db
        self.user = user
        self._handlers = {
            "query_my_tasks": self._query_my_tasks,
            "get_task_detail": self._get_task_detail,
            "recommend_tasks": self._recommend_tasks,
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
            "get_activity_detail": self._get_activity_detail,
            "get_expert_detail": self._get_expert_detail,
            "get_forum_post_detail": self._get_forum_post_detail,
            "get_flea_market_item_detail": self._get_flea_market_item_detail,
            "list_my_applications": self._list_my_applications,
            "list_my_service_applications": self._list_my_service_applications,
            "list_my_activities": self._list_my_activities,
            "list_forum_categories": self._list_forum_categories,
            "get_task_reviews": self._get_task_reviews,
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

    @staticmethod
    def _forum_post_display_title(post: models.ForumPost, lang: str) -> str:
        """按 lang 取帖子标题（title_zh/title_en），缺则回退 title。"""
        col = getattr(post, "title_zh" if lang == "zh" else "title_en", None)
        return (col or "") if col else (post.title or "")

    @staticmethod
    def _notification_display_title(n: models.Notification, lang: str) -> str:
        """按 lang 取通知标题：zh 用 title，en 用 title_en 或 title。"""
        if lang == "zh":
            return n.title or ""
        return getattr(n, "title_en", None) or n.title or ""

    @staticmethod
    def _leaderboard_display_name_desc(lb: models.CustomLeaderboard, lang: str) -> tuple[str, str]:
        """按 lang 取排行榜 name/description（name_zh/name_en 等），缺则回退。"""
        name_col = getattr(lb, "name_zh" if lang == "zh" else "name_en", None)
        desc_col = getattr(lb, "description_zh" if lang == "zh" else "description_en", None)
        name = (name_col or "") if name_col else (lb.name or "")
        desc = (desc_col or "") if desc_col else (lb.description or "")
        return name, desc

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
        user_id = self.user.id

        # 主查询：poster / taker / originating_user
        main_conditions = [
            or_(
                models.Task.poster_id == user_id,
                models.Task.taker_id == user_id,
                models.Task.originating_user_id == user_id,
            )
        ]
        if status_filter != "all":
            main_conditions.append(models.Task.status == status_filter)

        main_q = select(models.Task).where(and_(*main_conditions))
        main_rows = (await self.db.execute(main_q)).scalars().all()

        # 参与者查询：TaskParticipant（多人任务）
        part_conditions = [
            models.TaskParticipant.user_id == user_id,
            models.Task.is_multi_participant == True,
        ]
        if status_filter != "all":
            part_conditions.append(models.Task.status == status_filter)

        part_q = (
            select(models.Task)
            .join(models.TaskParticipant, models.Task.id == models.TaskParticipant.task_id)
            .where(and_(*part_conditions))
        )
        part_rows = (await self.db.execute(part_q)).scalars().all()

        # 合并去重
        tasks_dict = {}
        for t in main_rows + part_rows:
            tasks_dict[t.id] = t
        all_tasks = sorted(tasks_dict.values(), key=lambda t: t.created_at or t.id, reverse=True)
        total = len(all_tasks)

        # 分页
        page_tasks = all_tasks[(page - 1) * page_size : page * page_size]

        lang = self._tool_lang()
        tasks = []
        for t in page_tasks:
            tasks.append({
                "id": t.id,
                "title": _task_title(t, lang),
                "status": t.status,
                "reward": t.reward,
                "currency": t.currency,
                "task_type": t.task_type,
                "is_poster": t.poster_id == user_id,
                "is_multi_participant": bool(t.is_multi_participant),
                "created_at": format_iso_utc(t.created_at) if t.created_at else None,
                "deadline": format_iso_utc(t.deadline) if t.deadline else None,
            })

        return {"tasks": tasks, "total": total, "page": page, "page_size": page_size}

    async def _recommend_tasks(self, input: dict) -> dict:
        """个性化任务推荐（调用平台推荐引擎）"""
        limit = min(20, max(1, input.get("limit", 10)))
        task_type = input.get("task_type")
        keyword = input.get("keyword")
        lang = self._tool_lang()

        def _sync_recommend(session):
            from app.task_recommendation import get_task_recommendations
            from app.utils.task_activity_display import get_task_display_title
            recs = get_task_recommendations(
                db=session,
                user_id=self.user.id,
                limit=limit,
                algorithm="hybrid",
                task_type=task_type,
                location=None,
                keyword=keyword,
                latitude=None,
                longitude=None,
            )
            tasks = []
            for item in recs:
                t = item.get("task")
                if not t:
                    continue
                tasks.append({
                    "id": t.id,
                    "title": get_task_display_title(t, lang),
                    "reward": t.reward,
                    "currency": t.currency,
                    "task_type": t.task_type,
                    "location": t.location,
                    "match_score": round(item.get("score", 0), 2),
                    "reason": item.get("reason", ""),
                    "created_at": format_iso_utc(t.created_at) if t.created_at else None,
                    "deadline": format_iso_utc(t.deadline) if t.deadline else None,
                })
            return tasks

        try:
            tasks = await self.db.run_sync(_sync_recommend)
        except Exception as e:
            logger.warning("recommend_tasks failed: %s", e)
            return {"tasks": [], "count": 0, "reason": str(e)}

        return {"tasks": tasks, "count": len(tasks)}

    async def _get_task_detail(self, input: dict) -> dict:
        msgs = _TOOL_ERRORS.get(self._tool_lang(), _TOOL_ERRORS["en"])
        task_id = input.get("task_id")
        if not task_id:
            return {"error": msgs["task_id_required"]}

        q = select(models.Task).where(models.Task.id == task_id)
        task = (await self.db.execute(q)).scalar_one_or_none()
        if not task:
            return {"error": msgs["task_not_found"]}

        user_id = self.user.id
        # 权限检查：公开任务 or poster/taker/originating_user/participant
        is_owner = (
            task.poster_id == user_id
            or task.taker_id == user_id
            or task.originating_user_id == user_id
        )
        if not is_owner:
            # 检查 TaskParticipant
            part_q = select(func.count()).select_from(models.TaskParticipant).where(
                and_(
                    models.TaskParticipant.task_id == task_id,
                    models.TaskParticipant.user_id == user_id,
                )
            )
            is_participant = (await self.db.execute(part_q)).scalar() or 0
            is_owner = is_participant > 0

        if not task.is_public and not is_owner:
            return {"error": msgs["task_no_permission"]}

        lang = self._tool_lang()
        # 解析 images
        images = []
        if task.images:
            try:
                images = json.loads(task.images) if isinstance(task.images, str) else task.images
            except (json.JSONDecodeError, TypeError):
                pass

        result = {
            "id": task.id,
            "title": _task_title(task, lang),
            "description": _task_description(task, lang),
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
            "images": images,
            "created_at": format_iso_utc(task.created_at) if task.created_at else None,
            "deadline": format_iso_utc(task.deadline) if task.deadline else None,
            "completed_at": format_iso_utc(task.completed_at) if task.completed_at else None,
        }

        # 仅 poster 可见申请数（普通任务申请，非达人服务预约）
        if task.poster_id == user_id:
            app_count_q = (
                select(func.count())
                .select_from(models.TaskApplication)
                .where(models.TaskApplication.task_id == task_id)
            )
            result["application_count"] = (await self.db.execute(app_count_q)).scalar() or 0

        return result

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

        lang = self._tool_lang()
        tasks = []
        for t in rows:
            tasks.append({
                "id": t.id,
                "title": _task_title(t, lang),
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

        lang = self._tool_lang()
        activities = []
        for a in rows:
            activities.append({
                "id": a.id,
                "title": _activity_title(a, lang),
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

        lang = self._tool_lang()
        recent = []
        for n in rows:
            recent.append({
                "type": n.type,
                "title": self._notification_display_title(n, lang),
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
            select(models.ForumPost, models.ForumCategory)
            .join(models.ForumCategory, models.ForumPost.category_id == models.ForumCategory.id)
            .where(and_(*conditions))
            .order_by(desc(models.ForumPost.created_at))
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.db.execute(q)).all()

        lang = self._tool_lang()
        lang_key = self._faq_lang_key()
        posts = []
        for post, cat in rows:
            name_col = getattr(cat, f"name_{lang_key}", None)
            category_name = name_col if name_col else cat.name
            posts.append({
                "id": post.id,
                "title": self._forum_post_display_title(post, lang),
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
            lb_name, lb_desc = self._leaderboard_display_name_desc(lb, self._tool_lang())
            return {"name": lb_name, "description": lb_desc, "items": items}

        # 所有活跃排行榜
        q = (
            select(models.CustomLeaderboard)
            .where(models.CustomLeaderboard.status == "active")
            .order_by(desc(models.CustomLeaderboard.vote_count))
            .limit(10)
        )
        rows = (await self.db.execute(q)).scalars().all()
        lang = self._tool_lang()
        leaderboards = []
        for lb in rows:
            lb_name, _ = self._leaderboard_display_name_desc(lb, lang)
            leaderboards.append({
                "id": lb.id,
                "name": lb_name,
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

    # ── 新增工具 ──────────────────────────────────────────────

    async def _get_activity_detail(self, input: dict) -> dict:
        """活动详情"""
        msgs = _TOOL_ERRORS.get(self._tool_lang(), _TOOL_ERRORS["en"])
        activity_id = input.get("activity_id")
        if not activity_id:
            return {"error": msgs["activity_not_found"]}

        q = select(models.Activity).where(models.Activity.id == activity_id)
        activity = (await self.db.execute(q)).scalar_one_or_none()
        if not activity:
            return {"error": msgs["activity_not_found"]}

        # 公开活动或用户是达人创建者
        if not activity.is_public and activity.expert_id != self.user.id:
            return {"error": msgs["activity_not_found"]}

        lang = self._tool_lang()

        # 获取达人名
        expert_name = None
        if activity.expert_id:
            expert_q = (
                select(models.TaskExpert.expert_name, models.User.name)
                .join(models.User, models.TaskExpert.id == models.User.id)
                .where(models.TaskExpert.id == activity.expert_id)
            )
            row = (await self.db.execute(expert_q)).first()
            if row:
                expert_name = row[0] or row[1]

        images = activity.images if isinstance(activity.images, list) else []

        return {
            "id": activity.id,
            "title": _activity_title(activity, lang),
            "description": _activity_description(activity, lang),
            "location": activity.location,
            "reward_type": activity.reward_type,
            "original_price": activity.original_price_per_participant,
            "discounted_price": activity.discounted_price_per_participant,
            "currency": activity.currency,
            "max_participants": activity.max_participants,
            "min_participants": activity.min_participants,
            "status": activity.status,
            "deadline": format_iso_utc(activity.deadline) if activity.deadline else None,
            "images": images,
            "expert_name": expert_name,
            "has_time_slots": bool(activity.has_time_slots),
            "created_at": format_iso_utc(activity.created_at) if activity.created_at else None,
        }

    async def _get_expert_detail(self, input: dict) -> dict:
        """达人详情 + 服务列表"""
        msgs = _TOOL_ERRORS.get(self._tool_lang(), _TOOL_ERRORS["en"])
        expert_id = input.get("expert_id")
        if not expert_id:
            return {"error": msgs["expert_not_found"]}

        q = (
            select(models.TaskExpert, models.User.name)
            .join(models.User, models.TaskExpert.id == models.User.id)
            .where(models.TaskExpert.id == expert_id)
        )
        row = (await self.db.execute(q)).first()
        if not row:
            return {"error": msgs["expert_not_found"]}

        expert, user_name = row

        # 服务列表
        svc_q = (
            select(models.TaskExpertService)
            .where(
                and_(
                    models.TaskExpertService.expert_id == expert_id,
                    models.TaskExpertService.status == "active",
                )
            )
            .order_by(models.TaskExpertService.display_order)
        )
        svc_rows = (await self.db.execute(svc_q)).scalars().all()
        services = []
        for s in svc_rows:
            services.append({
                "id": s.id,
                "service_name": s.service_name,
                "description": (s.description or "")[:200],
                "base_price": s.base_price,
                "currency": s.currency,
                "status": s.status,
                "has_time_slots": bool(s.has_time_slots),
            })

        return {
            "id": expert.id,
            "name": expert.expert_name or user_name,
            "bio": expert.bio,
            "rating": float(expert.rating) if expert.rating else 0,
            "completed_tasks": expert.completed_tasks,
            "total_services": expert.total_services,
            "status": expert.status,
            "services": services,
        }

    async def _get_forum_post_detail(self, input: dict) -> dict:
        """论坛帖子详情"""
        msgs = _TOOL_ERRORS.get(self._tool_lang(), _TOOL_ERRORS["en"])
        post_id = input.get("post_id")
        if not post_id:
            return {"error": msgs["post_not_found"]}

        q = (
            select(models.ForumPost, models.ForumCategory)
            .join(models.ForumCategory, models.ForumPost.category_id == models.ForumCategory.id)
            .where(
                and_(
                    models.ForumPost.id == post_id,
                    models.ForumPost.is_deleted == False,
                )
            )
        )
        row = (await self.db.execute(q)).first()
        if not row:
            return {"error": msgs["post_not_found"]}

        post, category = row
        # 风控隐藏：仅作者可见，与 get_post_with_permissions 一致
        if not post.is_visible and post.author_id != self.user.id:
            return {"error": msgs["post_not_found"]}
        # 板块可见性：学校板块需学生认证，与 assert_forum_visible 一致
        visible = await assert_forum_visible(self.user, post.category_id, self.db, raise_exception=False)
        if not visible:
            return {"error": msgs["post_not_found"]}
        # 板块已隐藏
        if not category.is_visible:
            return {"error": msgs["post_not_found"]}

        lang = self._tool_lang()
        lang_key = self._faq_lang_key()
        category_name = getattr(category, f"name_{lang_key}", None) or category.name or ""

        # 作者名
        author_name = None
        if post.author_id:
            author_q = select(models.User.name).where(models.User.id == post.author_id)
            author_name = (await self.db.execute(author_q)).scalar()

        # content 按语言
        content_col = getattr(post, f"content_{self._faq_lang_key()}", None)
        content = content_col if content_col else post.content

        images = post.images if isinstance(post.images, list) else []

        return {
            "id": post.id,
            "title": self._forum_post_display_title(post, lang),
            "content": (content or "")[:2000],
            "category_name": category_name,
            "author_name": author_name,
            "view_count": post.view_count,
            "reply_count": post.reply_count,
            "like_count": post.like_count,
            "images": images,
            "created_at": format_iso_utc(post.created_at) if post.created_at else None,
        }

    async def _get_flea_market_item_detail(self, input: dict) -> dict:
        """跳蚤商品详情"""
        msgs = _TOOL_ERRORS.get(self._tool_lang(), _TOOL_ERRORS["en"])
        item_id = input.get("item_id")
        if not item_id:
            return {"error": msgs["item_not_found"]}

        q = (
            select(models.FleaMarketItem, models.User.name)
            .join(models.User, models.FleaMarketItem.seller_id == models.User.id)
            .where(models.FleaMarketItem.id == item_id)
        )
        row = (await self.db.execute(q)).first()
        if not row:
            return {"error": msgs["item_not_found"]}

        item, seller_name = row
        if item.status not in ("active", "sold"):
            return {"error": msgs["item_not_found"]}

        # 解析 images
        images = []
        if item.images:
            try:
                images = json.loads(item.images) if isinstance(item.images, str) else item.images
            except (json.JSONDecodeError, TypeError):
                pass

        return {
            "id": item.id,
            "title": item.title,
            "description": (item.description or "")[:2000],
            "price": float(item.price),
            "currency": item.currency,
            "location": item.location,
            "category": item.category,
            "seller_name": seller_name,
            "images": images,
            "status": item.status,
            "view_count": item.view_count,
            "created_at": format_iso_utc(item.created_at) if item.created_at else None,
        }

    async def _list_my_applications(self, input: dict) -> dict:
        """我的任务申请（TaskApplication，与 /api/my-applications 一致）"""
        status_filter = input.get("status", "all")
        page = max(1, input.get("page", 1))
        page_size = 10
        lang = self._tool_lang()

        conditions = [models.TaskApplication.applicant_id == self.user.id]
        if status_filter != "all":
            conditions.append(models.TaskApplication.status == status_filter)

        count_q = (
            select(func.count())
            .select_from(models.TaskApplication)
            .where(and_(*conditions))
        )
        total = (await self.db.execute(count_q)).scalar() or 0

        q = (
            select(models.TaskApplication, models.Task)
            .join(models.Task, models.TaskApplication.task_id == models.Task.id)
            .where(and_(*conditions))
            .order_by(desc(models.TaskApplication.created_at))
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.db.execute(q)).all()

        applications = []
        for app, task in rows:
            applications.append({
                "id": app.id,
                "task_id": app.task_id,
                "task_title": _task_title(task, lang),
                "task_status": task.status,
                "task_reward": task.reward,
                "task_location": task.location,
                "status": app.status,
                "message": app.message,
                "negotiated_price": app.negotiated_price,
                "currency": app.currency,
                "created_at": format_iso_utc(app.created_at) if app.created_at else None,
            })

        return {"applications": applications, "total": total, "page": page, "page_size": page_size}

    async def _list_my_service_applications(self, input: dict) -> dict:
        """我的达人服务预约（ServiceApplication）"""
        status_filter = input.get("status", "all")
        page = max(1, input.get("page", 1))
        page_size = 10

        conditions = [models.ServiceApplication.applicant_id == self.user.id]
        if status_filter != "all":
            conditions.append(models.ServiceApplication.status == status_filter)

        count_q = (
            select(func.count())
            .select_from(models.ServiceApplication)
            .where(and_(*conditions))
        )
        total = (await self.db.execute(count_q)).scalar() or 0

        q = (
            select(
                models.ServiceApplication,
                models.TaskExpertService.service_name,
                models.TaskExpert.expert_name,
                models.User.name,
            )
            .join(
                models.TaskExpertService,
                models.ServiceApplication.service_id == models.TaskExpertService.id,
            )
            .join(
                models.TaskExpert,
                models.ServiceApplication.expert_id == models.TaskExpert.id,
            )
            .join(models.User, models.TaskExpert.id == models.User.id)
            .where(and_(*conditions))
            .order_by(desc(models.ServiceApplication.created_at))
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
        rows = (await self.db.execute(q)).all()

        applications = []
        for app, service_name, expert_name, user_name in rows:
            applications.append({
                "id": app.id,
                "service_name": service_name,
                "expert_name": expert_name or user_name,
                "status": app.status,
                "final_price": app.final_price,
                "negotiated_price": app.negotiated_price,
                "currency": app.currency,
                "created_at": format_iso_utc(app.created_at) if app.created_at else None,
            })

        return {"applications": applications, "total": total, "page": page, "page_size": page_size}

    async def _list_my_activities(self, input: dict) -> dict:
        """我参与/收藏的活动"""
        list_type = input.get("type", "participated")
        lang = self._tool_lang()

        if list_type == "favorited":
            q = (
                select(models.Activity)
                .join(
                    models.ActivityFavorite,
                    models.Activity.id == models.ActivityFavorite.activity_id,
                )
                .where(models.ActivityFavorite.user_id == self.user.id)
                .order_by(desc(models.ActivityFavorite.created_at))
                .limit(20)
            )
        else:
            # participated: 通过 TaskParticipant（user_id + activity_id），与后端 /my/activities?type=applied 一致
            q = (
                select(models.Activity)
                .join(
                    models.TaskParticipant,
                    and_(
                        models.TaskParticipant.activity_id == models.Activity.id,
                        models.TaskParticipant.user_id == self.user.id,
                    ),
                )
                .where(models.TaskParticipant.activity_id.isnot(None))
                .distinct()
                .order_by(desc(models.Activity.created_at))
                .limit(20)
            )

        rows = (await self.db.execute(q)).scalars().all()

        activities = []
        for a in rows:
            activities.append({
                "id": a.id,
                "title": _activity_title(a, lang),
                "status": a.status,
                "deadline": format_iso_utc(a.deadline) if a.deadline else None,
                "reward_type": a.reward_type,
            })

        return {"activities": activities, "count": len(activities), "type": list_type}

    async def _list_forum_categories(self, input: dict) -> dict:
        """论坛分类列表（按用户身份过滤：普通板块人人可见，学校板块仅 UK 学生可见）"""
        q = (
            select(models.ForumCategory)
            .where(models.ForumCategory.is_visible == True)
            .order_by(models.ForumCategory.sort_order.asc())
        )
        rows = (await self.db.execute(q)).scalars().all()

        visible_ids = await visible_forums(self.user, self.db)
        general_ids_q = select(models.ForumCategory.id).where(
            and_(
                models.ForumCategory.type == "general",
                models.ForumCategory.is_visible == True,
            )
        )
        general_ids = [r[0] for r in (await self.db.execute(general_ids_q)).all()]
        visible_ids = list(set(visible_ids) | set(general_ids))
        rows = [c for c in rows if c.id in visible_ids]

        lang = self._tool_lang()
        lang_key = self._faq_lang_key()
        categories = []
        for c in rows:
            name_col = getattr(c, f"name_{lang_key}", None)
            desc_col = getattr(c, f"description_{lang_key}", None)
            categories.append({
                "id": c.id,
                "name": name_col if name_col else c.name,
                "description": desc_col if desc_col else (c.description or ""),
                "post_count": c.post_count,
                "type": c.type,
            })

        return {"categories": categories, "count": len(categories)}

    async def _get_task_reviews(self, input: dict) -> dict:
        """任务评价"""
        msgs = _TOOL_ERRORS.get(self._tool_lang(), _TOOL_ERRORS["en"])
        task_id = input.get("task_id")
        if not task_id:
            return {"error": msgs["task_id_required"]}

        # 检查任务存在性和权限
        task_q = select(models.Task).where(models.Task.id == task_id)
        task = (await self.db.execute(task_q)).scalar_one_or_none()
        if not task:
            return {"error": msgs["task_not_found"]}

        user_id = self.user.id
        is_related = (
            task.poster_id == user_id
            or task.taker_id == user_id
            or task.originating_user_id == user_id
        )
        if not is_related:
            part_q = select(func.count()).select_from(models.TaskParticipant).where(
                and_(
                    models.TaskParticipant.task_id == task_id,
                    models.TaskParticipant.user_id == user_id,
                )
            )
            is_related = (await self.db.execute(part_q)).scalar() or 0
        if not task.is_public and not is_related:
            return {"error": msgs["task_no_permission"]}

        q = (
            select(models.Review, models.User.name)
            .join(models.User, models.Review.user_id == models.User.id)
            .where(models.Review.task_id == task_id)
            .order_by(desc(models.Review.created_at))
        )
        rows = (await self.db.execute(q)).all()

        reviews = []
        for review, reviewer_name in rows:
            reviews.append({
                "rating": review.rating,
                "comment": review.comment,
                "reviewer_name": reviewer_name if not review.is_anonymous else None,
                "is_anonymous": bool(review.is_anonymous),
                "created_at": format_iso_utc(review.created_at) if review.created_at else None,
            })

        return {"reviews": reviews, "count": len(reviews)}
