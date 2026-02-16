"""
AI 工具安全执行器 — 自动鉴权，只能访问当前用户有权限的数据
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

# 平台 FAQ 数据（静态，后续可迁移到数据库/Redis）
PLATFORM_FAQ = {
    "publish": {
        "zh": "发布任务流程：1. 点击首页「发布任务」 2. 填写标题、描述、报酬、截止日期 3. 选择任务类型和位置 4. 提交后预付款到平台托管 5. 等待接单者接单。",
        "en": "How to post a task: 1. Click 'Post Task' on the home page 2. Fill in title, description, reward, deadline 3. Select task type and location 4. Submit and prepay to platform escrow 5. Wait for someone to accept.",
    },
    "accept": {
        "zh": "接单流程：1. 浏览或搜索任务 2. 查看任务详情 3. 点击「接受任务」 4. 完成后标记完成 5. 发布者确认后报酬自动到账。",
        "en": "How to accept a task: 1. Browse or search tasks 2. View task details 3. Click 'Accept Task' 4. Mark as completed when done 5. After poster confirms, payment is transferred automatically.",
    },
    "payment": {
        "zh": "支付与收款：平台使用 Stripe。发布时预付到托管，任务确认后自动转给接单者。接单者需在个人中心绑定 Stripe 收款账户才能提现。退款联系客服。",
        "en": "Payment: The platform uses Stripe. Reward is pre-paid to escrow when posting; after confirmation it is transferred to the taker. Link a Stripe payout account in your profile to receive funds. Refunds via customer support.",
    },
    "fee": {
        "zh": "费用说明：平台对每笔交易收取服务费（比例见发布页）。接单者实收 = 报酬 - 服务费。",
        "en": "Fees: A service fee is charged per transaction (see posting page for rates). Taker receives reward minus the service fee.",
    },
    "dispute": {
        "zh": "争议处理：在任务详情页提交争议，客服会在约 48 小时内介入。争议期间款项保持托管。",
        "en": "Disputes: Submit a dispute on the task detail page. Support will step in within about 48 hours. Funds stay in escrow during the dispute.",
    },
    "account": {
        "zh": "账户管理：个人中心可修改头像、昵称、简介、密码，以及绑定 Stripe 收款账户。邮箱/手机可用于登录。",
        "en": "Account: In your profile you can update avatar, name, bio, password, and link a Stripe payout account. Email or phone can be used to log in.",
    },
    "wallet": {
        "zh": "钱包与提现：任务确认完成后，款项会自动转入接单方。需在个人中心绑定 Stripe 收款账户才能提现到银行卡。平台不直接打款到支付宝/微信。",
        "en": "Wallet & withdrawal: After task confirmation, funds are transferred to the taker. You must link a Stripe payout account in your profile to withdraw to your bank. The platform does not pay out to Alipay/WeChat.",
    },
    "coupon": {
        "zh": "优惠券与积分：可通过活动或奖励获得优惠券和积分，支付时可选可用优惠券抵扣。具体规则见活动说明或「我的优惠券」页面。",
        "en": "Coupons & points: You can earn coupons and points through activities or rewards. Apply eligible coupons at checkout. See activity details or 'My Coupons' for rules.",
    },
    "activity": {
        "zh": "活动：平台不定期推出活动，可在首页或活动专区查看。参与活动可获得奖励、优惠券或积分。",
        "en": "Activities: The platform runs activities from time to time. Check the home page or activity section. Joining can earn rewards, coupons, or points.",
    },
    "flea": {
        "zh": "跳蚤市场：可发布二手闲置或求购信息，流程类似任务（填写信息、支付托管、交易完成后结算）。在「跳蚤市场」入口发布或浏览。",
        "en": "Flea market: You can list second-hand items or wanted posts. Flow is similar to tasks (list details, pay to escrow, settle after completion). Use the Flea Market section to post or browse.",
    },
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
        }

    async def execute(self, tool_name: str, tool_input: dict) -> dict:
        """执行工具，返回结果（自动鉴权）"""
        handler = self._handlers.get(tool_name)
        if not handler:
            return {"error": f"Unknown tool: {tool_name}"}
        try:
            result = await handler(tool_input)
            return _decimal_to_float(result)
        except Exception as e:
            logger.error(f"Tool execution error: {tool_name} — {e}")
            return {"error": "工具执行失败，请稍后重试"}

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
        task_id = input.get("task_id")
        if not task_id:
            return {"error": "task_id is required"}

        q = select(models.Task).where(models.Task.id == task_id)
        task = (await self.db.execute(q)).scalar_one_or_none()
        if not task:
            return {"error": "任务不存在"}

        # 权限检查：公开任务或自己的任务
        is_owner = task.poster_id == self.user.id or task.taker_id == self.user.id
        if not task.is_public and not is_owner:
            return {"error": "无权查看此任务"}

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
            "created_at": format_iso_utc(u.created_at) if u.created_at else None,
        }

    async def _get_platform_faq(self, input: dict) -> dict:
        question = (input.get("question") or "").lower()
        lang = self.user.language_preference or "zh"
        lang_key = "en" if lang.startswith("en") else "zh"

        # 关键词匹配（与 ai_agent._FAQ_KEYWORDS 对应）
        matches = []
        keyword_map = {
            "publish": ["发布", "post", "create", "创建", "发任务"],
            "accept": ["接单", "接受", "accept", "take", "接任务"],
            "payment": ["支付", "付款", "pay", "payment", "转账", "transfer", "收款", "到账"],
            "fee": ["费用", "fee", "charge", "服务费", "cost", "price", "费率"],
            "dispute": ["争议", "dispute", "投诉", "complain", "refund", "退款", "纠纷", "申诉"],
            "account": ["账户", "account", "profile", "个人", "密码", "password", "绑定账户"],
            "wallet": ["钱包", "提现", "withdraw", "payout", "收款账户", "绑定收款"],
            "coupon": ["优惠券", "coupon", "积分", "points", "抵扣", "折扣"],
            "activity": ["活动", "activity", "活动专区", "参与活动"],
            "flea": ["跳蚤", "二手", "flea", "闲置", "求购", "卖东西"],
        }

        for topic, keywords in keyword_map.items():
            if any(kw in question for kw in keywords):
                matches.append({
                    "topic": topic,
                    "answer": PLATFORM_FAQ[topic][lang_key],
                })

        # 如果没有匹配，返回所有 FAQ
        if not matches:
            matches = [
                {"topic": topic, "answer": data[lang_key]}
                for topic, data in PLATFORM_FAQ.items()
            ]

        return {"faq": matches}

    async def _check_cs_availability(self, input: dict) -> dict:
        """检查是否有人工客服在线"""
        from sqlalchemy import cast, Integer
        count_q = select(func.count(models.CustomerService.id)).where(
            cast(models.CustomerService.is_online, Integer) == 1
        )
        online_count = (await self.db.execute(count_q)).scalar() or 0
        return {"available": online_count > 0, "online_count": online_count}
