"""
咨询公共业务逻辑

三种咨询类型(service / task / flea_market)共用的操作:
- 关闭咨询占位 Task + 同步应用状态 + 发送系统消息
- 解析服务/团队的 taker_id
- 幂等性检查
- 创建占位 Task(薄包装,接受任意 Task 字段,保持各路由原有字段集完整)

注意:
- `check_consultation_idempotency` 只处理 `subject_type="service"` 场景。
  task / flea_market 主体的幂等性查询字段不同(TaskApplication / FleaMarketPurchaseRequest
  + description metadata 等),由各路由保留原查询逻辑。本 helper 对非 service
  场景返回 None,调用方必须自行处理。
"""
from datetime import datetime, timezone
from typing import Literal, Optional

from sqlalchemy import select

from app import models

# ServiceApplication 的"进行中"状态集合 — 用于幂等性查询
_ACTIVE_CONSULTATION_STATUSES = (
    "consulting",
    "negotiating",
    "price_agreed",
    "pending",
)

SubjectType = Literal["service", "task", "flea_market_item"]


async def check_consultation_idempotency(
    db,
    *,
    applicant_id: str,
    subject_id,
    subject_type: SubjectType,
) -> Optional["models.ServiceApplication"]:
    """
    查询用户对同一 service 是否已有进行中咨询。
    返回已存在的 ServiceApplication,供路由返回而不是重复创建。
    仅处理 subject_type="service";其他类型返回 None(调用方保留原逻辑)。

    注意:团队咨询场景下,若未指定具体服务 (subject_id 为 expert_id),
    此 helper 不适用;调用方应保留原查询逻辑。
    """
    if subject_type != "service":
        return None
    stmt = select(models.ServiceApplication).where(
        models.ServiceApplication.applicant_id == applicant_id,
        models.ServiceApplication.service_id == subject_id,
        models.ServiceApplication.status.in_(_ACTIVE_CONSULTATION_STATUSES),
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def close_consultation_task(
    db,
    application,
    *,
    reason: str = "咨询已关闭",
    new_status: str = "closed",
) -> None:
    """
    关闭咨询占位 task,并发送系统消息告知对方。

    Side effects:
    - 设置 task.status = 'closed'
    - 在 messages 表插入一条 `message_type='system'`, `conversation_type='task'` 系统消息
    - 只有当 task.status == 'consulting' 时才会执行(幂等 guard)

    调用方:approve / reject / close_consultation 时触发。
    """
    if not getattr(application, "task_id", None):
        return
    task = await db.get(models.Task, application.task_id)
    if not task or task.status != "consulting":
        return
    task.status = new_status
    # 系统消息 — 与 flea_market_routes 保持一致
    receiver_id = (
        task.taker_id if task.taker_id != application.applicant_id else task.poster_id
    )
    system_msg = models.Message(
        sender_id=None,
        receiver_id=receiver_id,
        content=reason,
        task_id=task.id,
        message_type="system",
        conversation_type="task",
    )
    db.add(system_msg)


async def resolve_taker_from_service(db, service):
    """
    解析服务对应的 taker:
    - 个人服务 (owner_type='user'): (user_id, None)
    - 团队服务 (owner_type='expert'): (team_owner.user_id, expert_id)

    返回 (taker_id: str | None, taker_expert_id: str | None)。
    团队无 active owner 时,taker_id 为 None(与 expert_consultation_routes 原逻辑一致,
    调用方决定如何处理;抛异常会破坏现有 create_consultation 语义)。
    """
    if service.owner_type == "expert":
        from app.models_expert import ExpertMember

        stmt = select(ExpertMember.user_id).where(
            ExpertMember.expert_id == service.owner_id,
            ExpertMember.role == "owner",
            ExpertMember.status == "active",
        )
        result = await db.execute(stmt)
        row = result.first()
        return (row[0] if row else None), service.owner_id
    return service.owner_id, None


async def create_placeholder_task(
    db,
    *,
    consultation_type: Literal[
        "consultation", "task_consultation", "flea_market_consultation"
    ],
    title: str,
    applicant_id: str,
    taker_id: Optional[str],
    description: str = "",
    **extra_fields,
) -> "models.Task":
    """
    创建咨询占位 Task(status='consulting')。

    返回持久化后的 Task(已 flush,有 id)。
    `extra_fields` 透传到 Task 构造器,供各路由补充 reward/currency/location/
    task_type/task_level/title_zh/title_en/expert_service_id/is_flexible 等。
    """
    task = models.Task(
        title=title,
        description=description,
        poster_id=applicant_id,
        taker_id=taker_id,
        status="consulting",
        task_source=consultation_type,
        is_consultation_placeholder=True,
        **extra_fields,
    )
    db.add(task)
    await db.flush()
    return task
