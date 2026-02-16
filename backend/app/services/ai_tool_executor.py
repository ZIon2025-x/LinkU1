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
        "zh": "发布任务流程：1. 点击首页'发布任务'按钮 2. 填写任务标题、描述、报酬、截止日期 3. 选择任务类型和位置 4. 提交后预付款项到平台托管 5. 等待接单者接单",
        "en": "How to post a task: 1. Click 'Post Task' on the home page 2. Fill in title, description, reward, deadline 3. Select task type and location 4. Submit and prepay to platform escrow 5. Wait for someone to accept",
    },
    "accept": {
        "zh": "接受任务流程：1. 浏览任务列表或搜索感兴趣的任务 2. 查看任务详情 3. 点击'接受任务'按钮 4. 完成任务后标记完成 5. 等待发布者确认后获得报酬",
        "en": "How to accept a task: 1. Browse task list or search 2. View task details 3. Click 'Accept Task' 4. Mark as completed after finishing 5. Wait for poster to confirm, then receive payment",
    },
    "payment": {
        "zh": "支付流程：平台使用 Stripe 安全支付。发布任务时预付报酬到平台托管，任务确认完成后自动转账给接单者。平台收取服务费。退款需通过客服处理。",
        "en": "Payment: The platform uses Stripe for secure payments. Reward is pre-paid to platform escrow when posting. After task confirmation, funds are automatically transferred to the task taker. A service fee applies. Refunds are handled by customer support.",
    },
    "fee": {
        "zh": "费用说明：平台对每笔交易收取服务费（具体比例见发布页面显示）。服务费从任务报酬中扣除。接单者收到的金额 = 报酬 - 服务费。",
        "en": "Fees: The platform charges a service fee per transaction (see the posting page for rates). The fee is deducted from the task reward. Taker receives = reward - service fee.",
    },
    "dispute": {
        "zh": "争议处理：如对任务结果有异议，可在任务详情页提交争议申请。平台客服将在48小时内介入处理。争议期间资金保持托管状态。",
        "en": "Disputes: If you have an issue with task results, submit a dispute on the task detail page. Customer support will intervene within 48 hours. Funds remain in escrow during disputes.",
    },
    "account": {
        "zh": "账户管理：可在个人中心修改头像、昵称、个人简介。邮箱和手机号可用于登录。支持修改密码和绑定 Stripe 收款账户。",
        "en": "Account: You can update your avatar, name, and bio in your profile. Email and phone can be used for login. You can change your password and link a Stripe payout account.",
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

        # 关键词匹配
        matches = []
        keyword_map = {
            "publish": ["发布", "post", "create", "创建"],
            "accept": ["接单", "接受", "accept", "take"],
            "payment": ["支付", "付款", "pay", "payment", "转账", "transfer"],
            "fee": ["费用", "fee", "charge", "服务费", "cost", "price"],
            "dispute": ["争议", "dispute", "投诉", "complain", "refund", "退款"],
            "account": ["账户", "account", "profile", "个人", "密码", "password"],
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
