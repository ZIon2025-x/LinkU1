"""
任务聊天功能API路由
实现任务聊天相关的所有接口
"""

import json
import logging
from datetime import datetime, timezone, timedelta
from typing import List, Optional

from fastapi import (
    APIRouter,
    Body,
    Depends,
    HTTPException,
    Query,
    Request,
    status,
)
from sqlalchemy import and_, func, or_, select, text, exists, desc, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app import models, schemas
from app.consultation import error_codes
from app.deps import get_async_db_dependency
from app.error_handlers import raise_http_error_with_code
from app.utils.time_utils import get_utc_time, parse_iso_utc, format_iso_utc
from app.push_notification_service import send_push_notification_async_safe

logger = logging.getLogger(__name__)

# 创建任务聊天路由器
task_chat_router = APIRouter()


async def _is_team_member_of_application(
    db: AsyncSession, application: models.ServiceApplication, user_id: str
) -> bool:
    """检查用户是否为该申请关联团队的 active owner/admin/member"""
    expert_id = getattr(application, 'new_expert_id', None)
    if not expert_id:
        return False
    from app.models_expert import ExpertMember
    result = await db.execute(
        select(ExpertMember.id).where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.user_id == user_id,
                ExpertMember.status == "active",
            )
        ).limit(1)
    )
    return result.scalar_one_or_none() is not None


async def _check_is_service_owner(
    db: AsyncSession, task: models.Task, user_id: str
) -> bool:
    """检查用户是否为该任务关联服务的所有者或团队成员。

    两条反查路径:
    1. task.expert_service_id → TaskExpertService.user_id / expert_id
    2. ServiceApplication.task_id → service_owner_id / new_expert_id
    """
    from app.models_expert import ExpertMember

    # 路径 1: 通过 task.expert_service_id
    if task.expert_service_id:
        svc_result = await db.execute(
            select(
                models.TaskExpertService.user_id,
                models.TaskExpertService.expert_id,
            ).where(models.TaskExpertService.id == task.expert_service_id)
        )
        svc_row = svc_result.first()
        if svc_row:
            svc_user_id, svc_expert_id = svc_row
            if svc_user_id and str(svc_user_id) == user_id:
                return True
            if svc_expert_id:
                member = await db.execute(
                    select(ExpertMember.id).where(
                        and_(
                            ExpertMember.expert_id == svc_expert_id,
                            ExpertMember.user_id == user_id,
                            ExpertMember.status == "active",
                        )
                    ).limit(1)
                )
                if member.scalar_one_or_none() is not None:
                    return True

    # 路径 2: 通过 ServiceApplication.task_id 反查（兼容旧数据没有 expert_service_id 的情况）
    app_result = await db.execute(
        select(
            models.ServiceApplication.service_owner_id,
            models.ServiceApplication.new_expert_id,
        ).where(models.ServiceApplication.task_id == task.id).limit(1)
    )
    app_row = app_result.first()
    if app_row:
        svc_owner_id, new_expert_id = app_row
        if svc_owner_id and str(svc_owner_id) == user_id:
            return True
        if new_expert_id:
            member = await db.execute(
                select(ExpertMember.id).where(
                    and_(
                        ExpertMember.expert_id == new_expert_id,
                        ExpertMember.user_id == user_id,
                        ExpertMember.status == "active",
                    )
                ).limit(1)
            )
            if member.scalar_one_or_none() is not None:
                return True

    return False


# 认证依赖（复用现有的认证逻辑）
async def get_current_user_secure_async_csrf(
    request: Request,
    db: AsyncSession = Depends(get_async_db_dependency),
) -> models.User:
    """
    CSRF保护的安全用户认证（异步版本）
    直接使用 validate_session 进行认证，避免 cookie_bearer 对 GET 请求的影响
    """
    from app.secure_auth import validate_session
    
    session = validate_session(request)
    if session:
        from app import async_crud
        user = await async_crud.async_user_crud.get_user_by_id(db, session.user_id)
        if user:
            # 检查用户状态
            if hasattr(user, "is_suspended") and user.is_suspended:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被暂停"
                )
            if hasattr(user, "is_banned") and user.is_banned:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, detail="账户已被封禁"
                )
            return user
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED, detail="未提供有效的认证信息"
    )


def _payment_method_types_for_currency(currency: str) -> list:
    """根据货币动态返回 Stripe 支持的支付方式列表

    Alipay 只支持 cny, gbp（Stripe 账户限制）
    """
    c = currency.lower()
    methods = ["card"]
    if c in ("gbp", "cny"):
        methods.extend(["wechat_pay", "alipay"])
    return methods


async def _create_customer_and_ephemeral_key(stripe_module, user_obj, db_session):
    """
    为支付方创建/获取 Stripe Customer，并生成 Ephemeral Key（用于客户端保存/复用支付方式）。
    优先使用数据库缓存的 stripe_customer_id，避免 Stripe Search API 索引延迟导致重复创建。
    失败时返回 (None, None)，不阻塞支付流程。
    """
    customer_id = None
    ephemeral_key_secret = None
    try:
        from app.utils.stripe_utils import get_or_create_stripe_customer
        customer_id = get_or_create_stripe_customer(user_obj)
        if customer_id and user_obj and (not user_obj.stripe_customer_id or user_obj.stripe_customer_id != customer_id):
            await db_session.execute(
                update(models.User)
                .where(models.User.id == user_obj.id)
                .values(stripe_customer_id=customer_id)
            )

        ephemeral_key = stripe_module.EphemeralKey.create(
            customer=customer_id,
            stripe_version="2025-01-27.acacia",
        )
        ephemeral_key_secret = ephemeral_key.secret
    except Exception as e:
        logger.warning(f"无法创建 Stripe Customer 或 Ephemeral Key: {e}")
        customer_id = None
        ephemeral_key_secret = None

    return customer_id, ephemeral_key_secret


def _build_participants(
    task, task_participants_dict: dict, users_dict: dict, current_user_id: str
) -> list:
    """构建任务参与者列表（排除当前用户），用于聊天列表显示头像/名字"""
    seen_ids = set()
    participants = []

    # 收集所有相关用户ID（poster + taker + expert_creator + TaskParticipants）
    candidate_ids = []
    if task.poster_id:
        candidate_ids.append(task.poster_id)
    if task.taker_id:
        candidate_ids.append(task.taker_id)
    if hasattr(task, 'expert_creator_id') and task.expert_creator_id:
        candidate_ids.append(task.expert_creator_id)
    # 多人任务参与者
    for uid in task_participants_dict.get(task.id, []):
        candidate_ids.append(uid)

    for uid in candidate_ids:
        if uid == current_user_id or uid in seen_ids:
            continue
        seen_ids.add(uid)
        user = users_dict.get(uid)
        if user:
            participants.append({
                "id": user.id,
                "name": user.name,
                "avatar": user.avatar,
            })

    return participants


@task_chat_router.get("/messages/tasks")
async def get_task_chat_list(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    获取任务聊天列表
    返回当前用户作为发布者或接受者的所有任务，包含未读计数和最后消息
    """
    try:
        # Redis 缓存：用户维度，TTL 30 秒
        from app.redis_cache import get_user_cache, set_user_cache
        cache_params = {"limit": limit, "offset": offset}
        cached = get_user_cache("task_chats", current_user.id, params=cache_params)
        if cached is not None:
            return cached

        # 查询用户相关的任务（作为发布者、接受者或多人任务参与者）
        # 获取所有相关的任务ID
        task_ids_set = set()
        
        # 1. 作为发布者或接受者的任务（排除已取消的任务）
        tasks_query_1 = select(models.Task.id).where(
            and_(
                or_(
                    models.Task.poster_id == current_user.id,
                    models.Task.taker_id == current_user.id
                ),
                models.Task.status != 'cancelled'
            )
        )
        result_1 = await db.execute(tasks_query_1)
        task_ids_set.update([row[0] for row in result_1.all()])
        
        # 1b. 多人任务：作为任务达人创建者（单独查询，避免在 or_() 中使用 and_() 导致的问题）
        expert_creator_query = select(models.Task.id).where(
            and_(
                models.Task.is_multi_participant.is_(True),
                models.Task.created_by_expert.is_(True),
                models.Task.expert_creator_id == current_user.id
            )
        )
        expert_creator_result = await db.execute(expert_creator_query)
        task_ids_set.update([row[0] for row in expert_creator_result.all()])
        
        # 2. 作为多人任务参与者的任务
        # 先查询参与者任务ID，然后过滤出多人任务（避免在join中使用布尔字段比较）
        # ⚠️ 修复：状态过滤需与全局未读数(crud.get_unread_messages)一致，包含 "completed"
        # 否则 completed 参与者的任务不出现在列表，但全局未读数会计入，造成"有未读找不到"
        participant_tasks_query = select(models.TaskParticipant.task_id).where(
            and_(
                models.TaskParticipant.user_id == current_user.id,
                models.TaskParticipant.status.in_(["accepted", "in_progress", "completed"])
            )
        )
        participant_result = await db.execute(participant_tasks_query)
        participant_task_ids = [row[0] for row in participant_result.all()]
        
        if participant_task_ids:
            # 查询这些任务中哪些是多人任务
            multi_participant_query = select(models.Task.id).where(
                and_(
                    models.Task.id.in_(participant_task_ids),
                    models.Task.is_multi_participant.is_(True)
                )
            )
            result_2 = await db.execute(multi_participant_query)
            task_ids_set.update([row[0] for row in result_2.all()])

        # 3. 作为团队成员的 consultation 任务
        from app.models_expert import ExpertMember
        sa_team_query = (
            select(models.ServiceApplication.task_id)
            .join(
                ExpertMember,
                and_(
                    ExpertMember.expert_id == models.ServiceApplication.new_expert_id,
                    ExpertMember.user_id == current_user.id,
                    ExpertMember.status == "active",
                ),
            )
            .where(
                and_(
                    models.ServiceApplication.new_expert_id.isnot(None),
                    models.ServiceApplication.task_id.isnot(None),
                )
            )
        )
        sa_team_result = await db.execute(sa_team_query)
        task_ids_set.update([row[0] for row in sa_team_result.all()])

        if not task_ids_set:
            return {
                "tasks": [],
                "total": 0
            }
        
        # 先批量查询所有任务的最后消息时间（用于排序）
        # 使用 LEFT JOIN 确保即使没有消息的任务也会被包含
        last_message_time_subquery = (
            select(
                models.Message.task_id,
                func.max(models.Message.created_at).label('last_message_time')
            )
            .where(
                and_(
                    models.Message.task_id.in_(list(task_ids_set)),
                    models.Message.conversation_type == 'task',
                )
            )
            .group_by(models.Message.task_id)
            .subquery()
        )
        
        # 查询所有相关任务，按最后消息时间排序（如果没有消息则按创建时间）
        sort_time_expr = func.coalesce(
            last_message_time_subquery.c.last_message_time,
            models.Task.created_at
        )
        
        tasks_query = (
            select(models.Task)
            .outerjoin(
                last_message_time_subquery,
                models.Task.id == last_message_time_subquery.c.task_id
            )
            .where(models.Task.id.in_(list(task_ids_set)))
            .order_by(desc(sort_time_expr))
        )
        
        # 分页
        tasks_query = tasks_query.offset(offset).limit(limit)
        result = await db.execute(tasks_query)
        tasks = result.scalars().all()
        
        # 总数就是去重后的任务ID数量
        total = len(task_ids_set)
        task_ids_list = list(task_ids_set)

        # 任务双语标题从任务表列读取（title_zh, title_en）
        # 批量查询所有游标（优化性能）
        cursors_query = select(models.MessageReadCursor).where(
            and_(
                models.MessageReadCursor.task_id.in_(task_ids_list),
                models.MessageReadCursor.user_id == current_user.id
            )
        )
        cursors_result = await db.execute(cursors_query)
        cursors_dict = {c.task_id: c for c in cursors_result.scalars().all()}
        
        # 批量查询所有最后消息（优化性能）
        last_messages_subquery = (
            select(
                models.Message.task_id,
                models.Message.id,
                models.Message.content,
                models.Message.sender_id,
                models.Message.created_at,
                func.row_number().over(
                    partition_by=models.Message.task_id,
                    order_by=[desc(models.Message.created_at), desc(models.Message.id)]
                ).label('rn')
            )
            .where(
                and_(
                    models.Message.task_id.in_(task_ids_list),
                    models.Message.conversation_type == 'task',
                )
            )
            .subquery()
        )
        
        last_messages_query = select(last_messages_subquery).where(
            last_messages_subquery.c.rn == 1
        )
        last_messages_result = await db.execute(last_messages_query)
        last_messages_dict = {}
        sender_ids_for_last_messages = set()
        
        for row in last_messages_result.all():
            task_id = row.task_id
            last_messages_dict[task_id] = {
                "id": row.id,
                "content": row.content,
                "sender_id": row.sender_id,
                "created_at": row.created_at
            }
            if row.sender_id:
                sender_ids_for_last_messages.add(row.sender_id)
        
        # 收集所有需要查询的用户ID（发送者 + 参与者）
        all_user_ids = set(sender_ids_for_last_messages)

        # 收集任务的 poster/taker/expert_creator ID
        for task in tasks:
            if task.poster_id:
                all_user_ids.add(task.poster_id)
            if task.taker_id:
                all_user_ids.add(task.taker_id)
            if hasattr(task, 'expert_creator_id') and task.expert_creator_id:
                all_user_ids.add(task.expert_creator_id)

        # 批量查询多人任务的 TaskParticipant
        multi_task_ids = [t.id for t in tasks if getattr(t, 'is_multi_participant', False)]
        task_participants_dict = {}  # task_id -> [user_id, ...]
        if multi_task_ids:
            tp_query = select(
                models.TaskParticipant.task_id,
                models.TaskParticipant.user_id
            ).where(
                and_(
                    models.TaskParticipant.task_id.in_(multi_task_ids),
                    models.TaskParticipant.status.in_(["accepted", "in_progress", "completed"])
                )
            )
            tp_result = await db.execute(tp_query)
            for row in tp_result.all():
                task_participants_dict.setdefault(row.task_id, []).append(row.user_id)
                all_user_ids.add(row.user_id)

        # 批量查询 consultation 任务的 ServiceApplication ID
        consultation_task_ids = [t.id for t in tasks if getattr(t, 'task_source', '') == 'consultation']
        service_app_map = {}
        if consultation_task_ids:
            sa_query = select(
                models.ServiceApplication.task_id,
                models.ServiceApplication.id
            ).where(
                models.ServiceApplication.task_id.in_(consultation_task_ids)
            )
            sa_result = await db.execute(sa_query)
            service_app_map = {row[0]: row[1] for row in sa_result.all()}

        # 批量查询 flea_market_consultation 任务的 FleaMarketPurchaseRequest ID
        flea_consultation_task_ids = [t.id for t in tasks if getattr(t, 'task_source', '') == 'flea_market_consultation']
        flea_app_map = {}
        if flea_consultation_task_ids:
            flea_query = select(
                models.FleaMarketPurchaseRequest.task_id,
                models.FleaMarketPurchaseRequest.id
            ).where(
                models.FleaMarketPurchaseRequest.task_id.in_(flea_consultation_task_ids)
            )
            flea_result = await db.execute(flea_query)
            flea_app_map = {row[0]: row[1] for row in flea_result.all()}

        # 批量查询 task consultation 的 TaskApplication ID
        task_consult_ids = [t.id for t in tasks if getattr(t, 'task_source', 'normal') not in ('consultation', 'flea_market_consultation')]
        task_app_map = {}
        if task_consult_ids:
            ta_query = select(
                models.TaskApplication.task_id,
                models.TaskApplication.id
            ).where(
                models.TaskApplication.task_id.in_(task_consult_ids),
                models.TaskApplication.status.in_(["consulting", "negotiating", "price_agreed"]),
            )
            ta_result = await db.execute(ta_query)
            for row in ta_result.all():
                if row[0] not in task_app_map:
                    task_app_map[row[0]] = row[1]

        # 一次查询所有用户信息
        if all_user_ids:
            users_query = select(models.User).where(
                models.User.id.in_(list(all_user_ids))
            )
            users_result = await db.execute(users_query)
            senders_dict = {u.id: u for u in users_result.scalars().all()}
        else:
            senders_dict = {}

        # 为每个任务计算未读数和最后消息
        task_list = []
        for task in tasks:
            # 计算未读数（排除自己发送的消息）
            cursor = cursors_dict.get(task.id)
            
            if cursor and cursor.last_read_message_id is not None:
                # 使用游标计算未读数
                # 排除系统消息，与 crud.get_unread_messages 保持一致
                unread_query = select(func.count(models.Message.id)).where(
                    and_(
                        models.Message.task_id == task.id,
                        models.Message.id > cursor.last_read_message_id,
                        models.Message.sender_id != current_user.id,
                        models.Message.sender_id.notin_(['system', 'SYSTEM']),  # 排除系统消息
                        models.Message.message_type != 'system',  # 排除系统类型消息
                        models.Message.conversation_type == 'task',
                    )
                )
            else:
                # 没有游标或游标为None，使用 message_reads 表兜底
                # 排除系统消息，与 crud.get_unread_messages 保持一致
                unread_query = select(func.count(models.Message.id)).where(
                    and_(
                        models.Message.task_id == task.id,
                        models.Message.sender_id != current_user.id,
                        models.Message.sender_id.notin_(['system', 'SYSTEM']),  # 排除系统消息
                        models.Message.message_type != 'system',  # 排除系统类型消息
                        models.Message.conversation_type == 'task',
                        ~exists(
                            select(1).where(
                                and_(
                                    models.MessageRead.message_id == models.Message.id,
                                    models.MessageRead.user_id == current_user.id
                                )
                            )
                        )
                    )
                )
            
            unread_result = await db.execute(unread_query)
            unread_count = unread_result.scalar() or 0
            
            # 获取最后一条消息（从批量查询结果中获取）
            last_message_data = None
            if task.id in last_messages_dict:
                last_msg = last_messages_dict[task.id]
                sender = senders_dict.get(last_msg["sender_id"])
                
                last_message_data = {
                    "id": last_msg["id"],
                    "content": last_msg["content"],
                    "sender_id": last_msg["sender_id"],
                    "sender_name": sender.name if sender else None,
                    "created_at": format_iso_utc(last_msg["created_at"]) if last_msg["created_at"] else None
                }
            
            # 解析任务图片（JSON字符串转数组）
            images_list = []
            if task.images:
                try:
                    if isinstance(task.images, str):
                        images_list = json.loads(task.images)
                    elif isinstance(task.images, list):
                        images_list = task.images
                except (json.JSONDecodeError, TypeError):
                    images_list = []
            
            title_en = getattr(task, "title_en", None)
            title_zh = getattr(task, "title_zh", None)
            task_data = {
                "id": task.id,
                "title": task.title,
                "title_en": title_en,
                "title_zh": title_zh,
                "task_type": task.task_type,
                "images": images_list,
                "poster_id": task.poster_id,
                "status": task.status,
                "taker_id": task.taker_id,
                "completed_at": format_iso_utc(task.completed_at) if task.completed_at else None,
                "unread_count": unread_count,
                "last_message": last_message_data,
                "reward": float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0,
                "base_reward": float(task.base_reward) if task.base_reward else None,
                "agreed_reward": float(task.agreed_reward) if task.agreed_reward else None,
                "reward_to_be_quoted": getattr(task, "reward_to_be_quoted", False),
                # 多人任务相关字段
                "is_multi_participant": bool(task.is_multi_participant) if hasattr(task, 'is_multi_participant') else False,
                "expert_creator_id": task.expert_creator_id if hasattr(task, 'expert_creator_id') else None,
                "created_by_expert": bool(task.created_by_expert) if hasattr(task, 'created_by_expert') else False,
                "task_source": getattr(task, 'task_source', 'normal'),  # 任务来源
                "service_application_id": service_app_map.get(task.id) or flea_app_map.get(task.id) or task_app_map.get(task.id),  # consultation/task consultation 任务对应的申请ID
                # 参与者信息（排除当前用户自己）
                "participants": _build_participants(
                    task, task_participants_dict, senders_dict, current_user.id
                ),
            }
            task_list.append(task_data)
        
        result = {
            "tasks": task_list,
            "total": total
        }
        set_user_cache("task_chats", current_user.id, result, ttl=30, params=cache_params)
        return result
    
    except Exception as e:
        logger.error(f"获取任务聊天列表失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取任务聊天列表失败，请稍后重试"
        )


@task_chat_router.get("/messages/tasks/unread/count")
async def get_task_chat_unread_count(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    获取任务聊天消息的总未读数量
    返回当前用户所有任务聊天消息的未读总数
    """
    try:
        # Redis 缓存：用户维度，TTL 30 秒
        from app.redis_cache import get_user_cache, set_user_cache
        cached = get_user_cache("task_chats_unread", current_user.id)
        if cached is not None:
            return cached

        from app.task_chat_business_logic import UnreadCountLogic
        
        # 查询用户相关的任务（作为发布者、接受者或多人任务参与者）
        # ⚠️ 修复：排除已取消的任务，与前端/聊天列表逻辑一致
        task_ids_set = set()
        
        # 1. 作为发布者或接受者的任务（排除已取消的任务）
        tasks_query_1 = select(models.Task.id).where(
            and_(
                or_(
                    models.Task.poster_id == current_user.id,
                    models.Task.taker_id == current_user.id
                ),
                models.Task.status != 'cancelled'
            )
        )
        result_1 = await db.execute(tasks_query_1)
        task_ids_set.update([row[0] for row in result_1.all()])
        
        # 1b. 多人任务：作为任务达人创建者（排除已取消的任务）
        expert_creator_query = select(models.Task.id).where(
            and_(
                models.Task.is_multi_participant.is_(True),
                models.Task.created_by_expert.is_(True),
                models.Task.expert_creator_id == current_user.id,
                models.Task.status != 'cancelled'
            )
        )
        expert_creator_result = await db.execute(expert_creator_query)
        task_ids_set.update([row[0] for row in expert_creator_result.all()])
        
        # 2. 作为多人任务参与者的任务
        # 先查询参与者任务ID，然后过滤出多人任务（避免在join中使用布尔字段比较）
        # ⚠️ 修复：状态过滤需与全局未读数(crud.get_unread_messages)一致，包含 "completed"
        participant_tasks_query = select(models.TaskParticipant.task_id).where(
            and_(
                models.TaskParticipant.user_id == current_user.id,
                models.TaskParticipant.status.in_(["accepted", "in_progress", "completed"])
            )
        )
        participant_result = await db.execute(participant_tasks_query)
        participant_task_ids = [row[0] for row in participant_result.all()]
        
        if participant_task_ids:
            # 查询这些任务中哪些是多人任务（排除已取消的任务）
            multi_participant_query = select(models.Task.id).where(
                and_(
                    models.Task.id.in_(participant_task_ids),
                    models.Task.is_multi_participant.is_(True),
                    models.Task.status != 'cancelled'
                )
            )
            result_2 = await db.execute(multi_participant_query)
            task_ids_set.update([row[0] for row in result_2.all()])
        
        if not task_ids_set:
            return {"unread_count": 0}
        
        # 批量计算所有任务的未读数量（优化：避免 N+1 查询）
        task_ids_list = list(task_ids_set)
        unread_counts = await UnreadCountLogic.get_batch_unread_count(
            db=db,
            task_ids=task_ids_list,
            user_id=current_user.id
        )
        total_unread = sum(unread_counts.values())
        
        result = {"unread_count": total_unread}
        set_user_cache("task_chats_unread", current_user.id, result, ttl=30)
        return result
    
    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        logger.error(f"获取任务聊天未读数量失败: {e}\n{error_trace}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取任务聊天未读数量失败，请稍后重试"
        )


@task_chat_router.get("/messages/task/{task_id}")
async def get_task_messages(
    task_id: int,
    limit: int = Query(20, ge=1, le=100),
    cursor: Optional[str] = Query(None),
    application_id: Optional[int] = Query(None, description="按申请ID筛选消息（预付费聊天频道）"),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    获取任务聊天消息（游标分页）
    返回指定任务的所有聊天消息，包含用户信息和附件
    """
    try:
        # 检查任务是否存在
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="任务不存在"
            )
        
        # 权限检查：必须是任务的参与者
        # 对于多人任务，需要检查 TaskParticipant
        is_poster = task.poster_id == current_user.id
        is_taker = task.taker_id == current_user.id
        is_participant = False
        
        # 如果是多人任务，检查是否是参与者
        if task.is_multi_participant:
            # 检查是否是任务达人（创建者）
            if task.created_by_expert and task.expert_creator_id == current_user.id:
                is_participant = True
            else:
                # 检查是否是TaskParticipant
                participant_query = select(models.TaskParticipant).where(
                    and_(
                        models.TaskParticipant.task_id == task_id,
                        models.TaskParticipant.user_id == current_user.id,
                        models.TaskParticipant.status.in_(["accepted", "in_progress"])
                    )
                )
                participant_result = await db.execute(participant_query)
                is_participant = participant_result.scalar_one_or_none() is not None
        
        # 咨询/服务类任务：服务所有者不是 poster/taker，需要反查
        is_service_owner = False
        if not is_poster and not is_taker and not is_participant:
            is_service_owner = await _check_is_service_owner(db, task, current_user.id)

        if not is_poster and not is_taker and not is_participant and not is_service_owner:
            # 如果提供了 application_id，允许该申请的申请者访问
            if not application_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="无权限查看该任务的消息"
                )

        # 如果提供了 application_id，验证申请存在且调用者有权限
        if application_id:
            app_query = select(models.TaskApplication).where(
                and_(
                    models.TaskApplication.id == application_id,
                    models.TaskApplication.task_id == task_id
                )
            )
            app_result = await db.execute(app_query)
            application = app_result.scalar_one_or_none()

            if not application:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="申请不存在"
                )

            # 任务发布者、接受者、申请者、或关联团队成员可以查看该申请的消息
            if not (task.poster_id == current_user.id or task.taker_id == current_user.id
                    or application.applicant_id == current_user.id
                    or await _is_team_member_of_application(db, application, current_user.id)):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="无权限查看该申请的消息"
                )

        # 构建消息查询
        messages_query = select(models.Message).where(
            and_(
                models.Message.task_id == task_id,
                models.Message.conversation_type == 'task'
            )
        )

        # 按 application_id 筛选消息
        if application_id:
            messages_query = messages_query.where(
                models.Message.application_id == application_id
            )
        else:
            # 不带 application_id 时只返回主任务聊天（不含申请频道私聊）
            messages_query = messages_query.where(
                models.Message.application_id.is_(None)
            )
        
        # 游标分页处理
        if cursor:
            # 解析游标：格式为 "2024-01-01T12:00:00Z_123"
            try:
                cursor_parts = cursor.split('_', 1)
                if len(cursor_parts) == 2:
                    cursor_time_str, cursor_id_str = cursor_parts
                    cursor_time = parse_iso_utc(cursor_time_str.replace('Z', '+00:00') if cursor_time_str.endswith('Z') else cursor_time_str)
                    cursor_id = int(cursor_id_str)
                    
                    # 查询更旧的消息：created_at < cursor_time OR (created_at = cursor_time AND id < cursor_id)
                    messages_query = messages_query.where(
                        or_(
                            models.Message.created_at < cursor_time,
                            and_(
                                models.Message.created_at == cursor_time,
                                models.Message.id < cursor_id
                            )
                        )
                    )
            except (ValueError, IndexError) as e:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="无效的游标格式"
                )
        
        # 排序：最新→更旧
        messages_query = messages_query.order_by(
            models.Message.created_at.desc(),
            models.Message.id.desc()
        ).limit(limit + 1)  # 多查一条用于判断是否有更多
        
        messages_result = await db.execute(messages_query)
        messages = messages_result.scalars().all()
        
        # 判断是否有更多消息
        has_more = len(messages) > limit
        if has_more:
            messages = messages[:limit]
        
        # 生成 next_cursor
        next_cursor = None
        if has_more and messages:
            last_message = messages[-1]
            if last_message.created_at:
                # 转换为 UTC ISO8601 格式
                utc_time = last_message.created_at
                if utc_time.tzinfo is None:
                    utc_time = utc_time.replace(tzinfo=timezone.utc)
                else:
                    utc_time = utc_time.astimezone(timezone.utc)
                next_cursor = f"{utc_time.strftime('%Y-%m-%dT%H:%M:%SZ')}_{last_message.id}"
        
        # 获取用户ID列表用于批量查询
        sender_ids = list(set([msg.sender_id for msg in messages if msg.sender_id]))
        
        # 批量查询用户信息
        users_query = select(models.User).where(models.User.id.in_(sender_ids))
        users_result = await db.execute(users_query)
        users = {user.id: user for user in users_result.scalars().all()}
        
        # 获取消息ID列表用于查询已读状态和附件
        message_ids = [msg.id for msg in messages]
        
        # 批量查询已读状态
        read_query = select(models.MessageRead).where(
            and_(
                models.MessageRead.message_id.in_(message_ids),
                models.MessageRead.user_id == current_user.id
            )
        )
        read_result = await db.execute(read_query)
        read_message_ids = {read.message_id for read in read_result.scalars().all()}
        
        # 构建聊天参与者列表，用于私密图片 URL 重新生成（避免 IMAGE_ACCESS_SECRET 变更后旧 token 403）
        participants: List[str] = []
        if task.poster_id:
            participants.append(str(task.poster_id))
        if task.taker_id:
            tid = str(task.taker_id)
            if tid not in participants:
                participants.append(tid)
        if getattr(task, "is_multi_participant", False):
            if getattr(task, "expert_creator_id", None):
                eid = str(task.expert_creator_id)
                if eid not in participants:
                    participants.append(eid)
            tp_query = select(models.TaskParticipant).where(
                and_(
                    models.TaskParticipant.task_id == task_id,
                    models.TaskParticipant.status.in_(["accepted", "in_progress"]),
                )
            )
            tp_result = await db.execute(tp_query)
            for p in tp_result.scalars().all():
                if p.user_id:
                    uid = str(p.user_id)
                    if uid not in participants:
                        participants.append(uid)
        # 额外查 chat_participants 表（多人聊天扩展）
        try:
            from app.models_expert import ChatParticipant
            cp_query = select(ChatParticipant.user_id).where(ChatParticipant.task_id == task_id)
            cp_result = await db.execute(cp_query)
            for uid_row in cp_result.scalars().all():
                uid = str(uid_row)
                if uid not in participants:
                    participants.append(uid)
        except Exception:
            pass  # chat_participants 表不存在时静默跳过

        cuid = str(current_user.id)
        if cuid not in participants:
            participants.append(cuid)
        if not participants:
            participants = [cuid]

        # 批量查询附件
        attachments_query = select(models.MessageAttachment).where(
            models.MessageAttachment.message_id.in_(message_ids)
        )
        attachments_result = await db.execute(attachments_query)
        attachments_by_message = {}
        for attachment in attachments_result.scalars().all():
            if attachment.message_id not in attachments_by_message:
                attachments_by_message[attachment.message_id] = []
            
            attachment_data = {
                "id": attachment.id,
                "attachment_type": attachment.attachment_type,
                "url": attachment.url,
                "blob_id": attachment.blob_id,
            }
            
            # 解析 meta JSON
            if attachment.meta:
                try:
                    attachment_data["meta"] = json.loads(attachment.meta)
                except Exception:
                    attachment_data["meta"] = {}
            else:
                attachment_data["meta"] = {}

            # 私密图片：按当前密钥重新生成 URL，避免 IMAGE_ACCESS_SECRET 变更后旧 token 导致 403
            if (
                attachment.attachment_type == "image"
                and attachment.blob_id
                and participants
            ):
                try:
                    from app.image_system import private_image_system
                    new_url = private_image_system.generate_image_url(
                        attachment.blob_id,
                        cuid,
                        participants,
                    )
                    attachment_data["url"] = new_url
                except Exception as e:
                    logger.warning(
                        "Failed to regenerate private-image URL for blob_id=%s: %s",
                        attachment.blob_id,
                        e,
                    )
            
            attachments_by_message[attachment.message_id].append(attachment_data)
        
        # 构建返回数据
        messages_data = []
        for msg in messages:
            sender = users.get(msg.sender_id)
            
            # 判断是否已读（排除自己发送的消息）
            is_read = False
            if msg.sender_id != current_user.id:
                is_read = msg.id in read_message_ids
            
            message_data = {
                "id": msg.id,
                "sender_id": msg.sender_id,
                "sender_name": sender.name if sender else None,
                "sender_avatar": sender.avatar if sender and hasattr(sender, 'avatar') else None,
                "content": msg.content,
                "message_type": msg.message_type,
                "task_id": msg.task_id,
                "created_at": format_iso_utc(msg.created_at) if msg.created_at else None,
                "is_read": is_read,
                "attachments": attachments_by_message.get(msg.id, []),
                "meta": msg.meta,
            }
            messages_data.append(message_data)
        
        # 解析任务图片（JSON字符串转数组）
        images_list = []
        if task.images:
            try:
                if isinstance(task.images, str):
                    images_list = json.loads(task.images)
                elif isinstance(task.images, list):
                    images_list = task.images
            except (json.JSONDecodeError, TypeError):
                images_list = []
        
        title_en = getattr(task, "title_en", None)
        title_zh = getattr(task, "title_zh", None)
        task_data = {
            "id": task.id,
            "title": task.title,
            "title_en": title_en,
            "title_zh": title_zh,
            "task_type": task.task_type,
            "images": images_list,
            "poster_id": task.poster_id,
            "taker_id": task.taker_id,
            "status": task.status,
            "completed_at": format_iso_utc(task.completed_at) if task.completed_at else None,
            "reward": float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0,
            "base_reward": float(task.base_reward) if task.base_reward else None,
            "agreed_reward": float(task.agreed_reward) if task.agreed_reward else None,
            "reward_to_be_quoted": getattr(task, "reward_to_be_quoted", False),
            "currency": task.currency or "GBP",
            # 多人任务相关字段
            "is_multi_participant": bool(task.is_multi_participant) if hasattr(task, 'is_multi_participant') else False,
            "expert_creator_id": task.expert_creator_id if hasattr(task, 'expert_creator_id') else None,
            "created_by_expert": bool(task.created_by_expert) if hasattr(task, 'created_by_expert') else False,
            "task_source": getattr(task, 'task_source', 'normal')  # 任务来源
        }
        
        return {
            "messages": messages_data,
            "task": task_data,
            "next_cursor": next_cursor,
            "has_more": has_more
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务消息失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取任务消息失败，请稍后重试"
        )


# Pydantic 模型定义
from pydantic import BaseModel, Field, field_validator, model_validator
from typing import Dict, Any


class SendMessageRequest(BaseModel):
    """发送消息请求体"""
    content: str = Field(..., min_length=1, max_length=5000)
    meta: Optional[Dict[str, Any]] = Field(None, description="JSON格式元数据")
    attachments: List[Dict[str, Any]] = Field(default_factory=list, description="附件数组")
    application_id: Optional[int] = Field(None, description="申请ID（预付费聊天频道）")
    
    @field_validator('meta')
    @classmethod
    def validate_meta(cls, v):
        if v is not None:
            # 检查大小（4KB限制）
            meta_str = json.dumps(v)
            if len(meta_str.encode('utf-8')) > 4096:
                raise ValueError("meta字段大小不能超过4KB")
        return v


class MarkReadRequest(BaseModel):
    """标记已读请求体"""
    upto_message_id: Optional[int] = None
    message_ids: Optional[List[int]] = None
    application_id: Optional[int] = Field(None, description="申请ID（预付费聊天频道）")

    @model_validator(mode='after')
    def validate_at_least_one(self):
        """验证至少提供一个字段"""
        upto_id = self.upto_message_id
        msg_ids = self.message_ids
        if not upto_id and not msg_ids:
            raise ValueError("必须提供 upto_message_id 或 message_ids 之一")
        return self


# GET /api/tasks/{task_id}/applications 由 async_routers.get_task_applications 统一处理（先注册），此处不重复定义


@task_chat_router.post("/messages/task/{task_id}/send")
async def send_task_message(
    task_id: int,
    request: SendMessageRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    发送任务消息
    支持附件和元数据
    """
    try:
        # 检查任务是否存在
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="任务不存在"
            )
        
        # 权限检查：必须是任务的参与者
        # 对于多人任务，需要检查 TaskParticipant
        is_poster = task.poster_id == current_user.id
        is_taker = task.taker_id == current_user.id
        is_participant = False
        
        # 如果是多人任务，检查是否是参与者
        if task.is_multi_participant:
            participant_query = select(models.TaskParticipant).where(
                and_(
                    models.TaskParticipant.task_id == task_id,
                    models.TaskParticipant.user_id == current_user.id,
                    models.TaskParticipant.status.in_(["accepted", "in_progress"])
                )
            )
            participant_result = await db.execute(participant_query)
            is_participant = participant_result.scalar_one_or_none() is not None
        
        # 对于多人任务，还需要检查是否是任务达人（创建者）
        is_expert_creator = False
        if task.is_multi_participant and task.created_by_expert:
            is_expert_creator = task.expert_creator_id == current_user.id
        
        # 如果提供了 application_id，验证申请并覆盖权限检查
        application = None
        application_receiver_id = None
        if request.application_id:
            app_query = select(models.TaskApplication).where(
                and_(
                    models.TaskApplication.id == request.application_id,
                    models.TaskApplication.task_id == task_id
                )
            )
            app_result = await db.execute(app_query)
            application = app_result.scalar_one_or_none()

            if not application:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="申请不存在"
                )

            if application.status not in ("chatting", "consulting", "negotiating", "price_agreed", "pending"):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="该申请当前不在聊天状态"
                )

            # 发布者、接受者、申请者、或关联团队成员可以在该频道发送消息
            if not (task.poster_id == current_user.id or task.taker_id == current_user.id
                    or application.applicant_id == current_user.id
                    or await _is_team_member_of_application(db, application, current_user.id)):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="无权限在该申请频道发送消息"
                )

            # 确定接收者为对方
            if current_user.id == task.poster_id:
                application_receiver_id = task.taker_id or application.applicant_id
            elif current_user.id == task.taker_id:
                application_receiver_id = task.poster_id
            else:
                application_receiver_id = task.poster_id
        else:
            # Consultation tasks: allow team members even without application_id
            is_consultation_team_member = False
            if not request.application_id and not (is_poster or is_taker or is_participant or is_expert_creator):
                task_source = getattr(task, 'task_source', None)
                if task_source in ('consultation', 'task_consultation'):
                    sa_query = select(models.ServiceApplication).where(
                        models.ServiceApplication.task_id == task_id
                    )
                    sa_result = await db.execute(sa_query)
                    sa = sa_result.scalar_one_or_none()
                    if sa:
                        is_consultation_team_member = await _is_team_member_of_application(db, sa, current_user.id)

            if not request.application_id and not (is_poster or is_taker or is_participant or is_expert_creator or is_consultation_team_member):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="无权限发送消息"
                )

        # For consultation tasks without application_id, determine receiver
        if not request.application_id and getattr(task, 'task_source', None) in ('consultation', 'task_consultation'):
            if current_user.id == task.poster_id:
                application_receiver_id = task.taker_id
            else:
                application_receiver_id = task.poster_id

        # 任务状态检查：仅拒绝「已结束」状态（已完成、已取消、已关闭、已过期），其余状态（含待确认、待支付、进行中等）均可发
        _ended_statuses = ("completed", "cancelled", "closed", "expired")
        if task.status in _ended_statuses:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="任务已结束，无法发送消息"
            )
        # 说明类消息（任务开始前说明）仅允许在 open 且为发布者时发送
        can_send_prenote = task.status == "open" and is_poster

        # 如果是说明类消息，检查频率限制
        is_prenote = False
        if request.meta and request.meta.get("is_prestart_note"):
            is_prenote = True
            if not can_send_prenote:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="只有发布者可以在任务开始前发送说明类消息"
                )
            
            # 频率限制检查（1条/分钟，日上限20条）
            from datetime import timedelta
            now = get_utc_time()
            one_minute_ago = now - timedelta(minutes=1)
            today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            
            # 检查1分钟内是否发送过
            recent_query = select(func.count(models.Message.id)).where(
                and_(
                    models.Message.task_id == task_id,
                    models.Message.sender_id == current_user.id,
                    models.Message.created_at >= one_minute_ago,
                    models.Message.meta.like('%"is_prestart_note": true%')
                )
            )
            recent_result = await db.execute(recent_query)
            recent_count = recent_result.scalar() or 0
            
            if recent_count > 0:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="说明类消息发送频率限制：最多1条/分钟"
                )
            
            # 检查今日是否超过20条
            today_query = select(func.count(models.Message.id)).where(
                and_(
                    models.Message.task_id == task_id,
                    models.Message.sender_id == current_user.id,
                    models.Message.created_at >= today_start,
                    models.Message.meta.like('%"is_prestart_note": true%')
                )
            )
            today_result = await db.execute(today_query)
            today_count = today_result.scalar() or 0
            
            if today_count >= 20:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="说明类消息日上限：最多20条/天"
                )
        
        # 验证附件（简化版，实际需要更严格的验证）
        if request.attachments:
            for att in request.attachments:
                if "attachment_type" not in att:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail="附件必须包含 attachment_type 字段"
                    )
                # 检查 url 和 blob_id 必须二选一（转为 bool，避免 has_url 为 str 时 has_url ^ has_blob_id 报错）
                has_url = ("url" in att) and bool(att.get("url"))
                has_blob_id = ("blob_id" in att) and bool(att.get("blob_id"))
                if not (has_url ^ has_blob_id):
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail="附件必须提供 url 或 blob_id 之一，且不能同时提供"
                    )
        
        # 获取当前时间
        current_time = get_utc_time()
        
        # 创建消息
        meta_str = json.dumps(request.meta) if request.meta else None
        
        # 消息类型：用户只能发送 normal 消息，system 消息由服务端内部创建
        message_type = "normal"
        sender_id = current_user.id
        
        new_message = models.Message(
            sender_id=sender_id,
            receiver_id=application_receiver_id,  # 申请频道消息设置接收者，普通任务消息为 None
            content=request.content,
            task_id=task_id,
            message_type=message_type,
            conversation_type="task",
            meta=meta_str,
            created_at=current_time,
            application_id=request.application_id,
        )
        
        db.add(new_message)
        await db.flush()  # 获取消息ID
        
        # 创建附件
        attachments_data = []
        if request.attachments:
            for att in request.attachments:
                attachment_meta = json.dumps(att.get("meta", {})) if att.get("meta") else None
                new_attachment = models.MessageAttachment(
                    message_id=new_message.id,
                    attachment_type=att["attachment_type"],
                    url=att.get("url"),
                    blob_id=att.get("blob_id"),
                    meta=attachment_meta,
                    created_at=current_time
                )
                db.add(new_attachment)
                attachments_data.append({
                    "id": new_attachment.id,
                    "attachment_type": new_attachment.attachment_type,
                    "url": new_attachment.url,
                    "blob_id": new_attachment.blob_id,
                    "meta": json.loads(attachment_meta) if attachment_meta else {}
                })
        
        await db.commit()
        await db.refresh(new_message)
        
        # 通过WebSocket广播消息给所有参与者
        try:
            from app.websocket_manager import get_ws_manager
            ws_manager = get_ws_manager()

            # 获取所有参与者ID
            participant_ids = set()

            if request.application_id and application:
                # Application-scoped chat: poster, taker, and the specific applicant
                if task.poster_id:
                    participant_ids.add(task.poster_id)
                if task.taker_id:
                    participant_ids.add(task.taker_id)
                if application.applicant_id:
                    participant_ids.add(application.applicant_id)
            else:
                # General task chat: all participants
                # 添加发布者
                if task.poster_id:
                    participant_ids.add(task.poster_id)

                # 添加接受者（如果是单人任务）
                if task.taker_id:
                    participant_ids.add(task.taker_id)

                # 如果是多人任务，添加所有参与者
                if task.is_multi_participant:
                    # 添加任务达人（创建者）
                    if task.expert_creator_id:
                        participant_ids.add(task.expert_creator_id)

                    # 添加所有TaskParticipant
                    participants_query = select(models.TaskParticipant).where(
                        and_(
                            models.TaskParticipant.task_id == task_id,
                            models.TaskParticipant.status.in_(["accepted", "in_progress"])
                        )
                    )
                    participants_result = await db.execute(participants_query)
                    participants = participants_result.scalars().all()
                    for participant in participants:
                        if participant.user_id:
                            participant_ids.add(participant.user_id)

                # 额外查 chat_participants 表（多人聊天扩展）
                try:
                    from app.models_expert import ChatParticipant
                    cp_query = select(ChatParticipant.user_id).where(ChatParticipant.task_id == task_id)
                    cp_result = await db.execute(cp_query)
                    for uid_row in cp_result.scalars().all():
                        participant_ids.add(str(uid_row))
                except Exception:
                    pass

            # For consultation tasks: also broadcast to team members
            task_source = getattr(task, 'task_source', None)
            if task_source in ('consultation', 'task_consultation') and not request.application_id:
                sa_query = select(models.ServiceApplication).where(
                    models.ServiceApplication.task_id == task_id
                )
                sa_result = await db.execute(sa_query)
                sa = sa_result.scalar_one_or_none()
                if sa and sa.new_expert_id:
                    from app.models_expert import ExpertMember
                    members_result = await db.execute(
                        select(ExpertMember.user_id).where(
                            ExpertMember.expert_id == sa.new_expert_id,
                            ExpertMember.status == "active",
                        )
                    )
                    for row in members_result.all():
                        participant_ids.add(row[0])

            # 构建消息响应
            message_response = {
                "type": "task_message",
                "message": {
                    "id": new_message.id,
                    "sender_id": new_message.sender_id,
                    "sender_name": current_user.name,
                    "sender_avatar": getattr(current_user, 'avatar', None),
                    "content": new_message.content,
                    "task_id": new_message.task_id,
                    "message_type": new_message.message_type,
                    "created_at": format_iso_utc(new_message.created_at) if new_message.created_at else None,
                    "attachments": attachments_data
                }
            }
            
            # 向所有参与者（除了发送者）广播消息并发送推送通知
            for participant_id in participant_ids:
                if participant_id != current_user.id:
                    # 尝试通过WebSocket发送（实时通知）
                    success = await ws_manager.send_to_user(participant_id, message_response)
                    if success:
                        logger.debug(f"Task message broadcasted to participant {participant_id} via WebSocket (user is in app, skipping push notification)")
                    else:
                        # WebSocket发送失败，说明用户不在app中，需要发送推送通知
                        logger.debug(f"Task message WebSocket failed for participant {participant_id} (user is not in app, sending push notification)")
                        try:
                            # 截取消息内容（最多50个字符），图片/附件等无文本内容时使用描述性占位
                            raw_content = (new_message.content or "").strip()
                            if raw_content:
                                message_preview = raw_content[:50] + ("..." if len(raw_content) > 50 else "")
                            elif getattr(new_message, 'message_type', 'normal') == 'image':
                                message_preview = "[图片]"
                            else:
                                message_preview = None  # 由 get_push_notification_text 使用兜底文案
                            send_push_notification_async_safe(
                                async_db=db,
                                user_id=participant_id,
                                title=None,  # 从模板生成（会根据用户语言偏好）
                                body=None,  # 从模板生成（会根据用户语言偏好）
                                notification_type="task_message",
                                data={
                                    "task_id": task_id,
                                    "sender_id": current_user.id
                                },
                                template_vars={
                                    "sender_name": current_user.name or f"用户{current_user.id}",
                                    "message": message_preview,
                                    "task_title": task.title,  # 原始标题，会在 send_push_notification 中根据用户语言从翻译表获取
                                    "task_id": task_id  # 传递 task_id 以便获取翻译
                                }
                            )
                        except Exception as e:
                            logger.warning(f"发送任务消息推送通知失败（用户 {participant_id}）: {e}")
        except Exception as e:
            # WebSocket广播失败不应该影响消息发送
            logger.error(f"Failed to broadcast task message via WebSocket: {e}", exc_info=True)
        
        # 失效所有参与者的聊天列表 + 未读数缓存
        from app.redis_cache import invalidate_task_chat_cache
        for pid in participant_ids:
            invalidate_task_chat_cache(pid)
        invalidate_task_chat_cache(current_user.id)

        return {
            "id": new_message.id,
            "sender_id": str(new_message.sender_id) if new_message.sender_id is not None else None,
            "sender_name": current_user.name if new_message.sender_id else None,
            "sender_avatar": getattr(current_user, "avatar", None) if new_message.sender_id else None,
            "content": new_message.content,
            "message_type": new_message.message_type or "normal",
            "task_id": new_message.task_id,
            "created_at": format_iso_utc(new_message.created_at) if new_message.created_at else None,
            "is_read": False,
            "attachments": attachments_data
        }
    
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"发送任务消息失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="发送任务消息失败，请稍后重试"
        )


@task_chat_router.post("/messages/task/{task_id}/read")
async def mark_messages_read(
    task_id: int,
    request: MarkReadRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    标记消息为已读
    支持两种方式：upto_message_id 或 message_ids
    """
    try:
        # 检查任务是否存在
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="任务不存在"
            )
        
        # 权限检查：必须是任务的参与者
        # 对于多人任务，需要检查 TaskParticipant
        is_poster = task.poster_id == current_user.id
        is_taker = task.taker_id == current_user.id
        is_participant = False
        
        # 如果是多人任务，检查是否是参与者
        if task.is_multi_participant:
            # 检查是否是任务达人（创建者）
            if task.created_by_expert and task.expert_creator_id == current_user.id:
                is_participant = True
            else:
                # 检查是否是TaskParticipant
                participant_query = select(models.TaskParticipant).where(
                    and_(
                        models.TaskParticipant.task_id == task_id,
                        models.TaskParticipant.user_id == current_user.id,
                        models.TaskParticipant.status.in_(["accepted", "in_progress"])
                    )
                )
                participant_result = await db.execute(participant_query)
                is_participant = participant_result.scalar_one_or_none() is not None
        
        if not is_poster and not is_taker and not is_participant:
            # 如果提供了 application_id，允许该申请的申请者访问
            if not request.application_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="无权限标记该任务的消息"
                )

        # 如果提供了 application_id，验证申请存在且调用者有权限
        if request.application_id:
            app_query = select(models.TaskApplication).where(
                and_(
                    models.TaskApplication.id == request.application_id,
                    models.TaskApplication.task_id == task_id
                )
            )
            app_result = await db.execute(app_query)
            application = app_result.scalar_one_or_none()

            if not application:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="申请不存在"
                )

            if not (task.poster_id == current_user.id or application.applicant_id == current_user.id
                    or await _is_team_member_of_application(db, application, current_user.id)):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="无权限标记该申请的消息"
                )

        # 获取当前时间
        current_time = get_utc_time()

        marked_count = 0

        if request.upto_message_id:
            # 方式1：标记到指定消息ID为止的所有消息
            # 先获取该消息的 created_at 和 id
            upto_msg_query = select(models.Message).where(
                and_(
                    models.Message.id == request.upto_message_id,
                    models.Message.task_id == task_id
                )
            )
            upto_msg_result = await db.execute(upto_msg_query)
            upto_message = upto_msg_result.scalar_one_or_none()
            
            if not upto_message:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="指定的消息不存在"
                )
            
            # 查询需要标记的消息（排除自己发送的消息）
            mark_filters = [
                models.Message.task_id == task_id,
                models.Message.sender_id != current_user.id,
                or_(
                    models.Message.created_at < upto_message.created_at,
                    and_(
                        models.Message.created_at == upto_message.created_at,
                        models.Message.id <= upto_message.id
                    )
                )
            ]
            if request.application_id:
                mark_filters.append(models.Message.application_id == request.application_id)
            messages_to_mark_query = select(models.Message).where(and_(*mark_filters))
            messages_to_mark_result = await db.execute(messages_to_mark_query)
            messages_to_mark = messages_to_mark_result.scalars().all()
            
            # 批量查询已存在的已读记录（优化性能）
            message_ids_to_mark = [msg.id for msg in messages_to_mark]
            existing_reads_query = select(models.MessageRead).where(
                and_(
                    models.MessageRead.message_id.in_(message_ids_to_mark),
                    models.MessageRead.user_id == current_user.id
                )
            )
            existing_reads_result = await db.execute(existing_reads_query)
            existing_read_message_ids = {read.message_id for read in existing_reads_result.scalars().all()}
            
            # 批量标记为已读（只插入不存在的记录）
            new_reads = []
            for msg in messages_to_mark:
                if msg.id not in existing_read_message_ids:
                    new_read = models.MessageRead(
                        message_id=msg.id,
                        user_id=current_user.id,
                        read_at=current_time
                    )
                    new_reads.append(new_read)
                    marked_count += 1
            
            # 批量插入
            if new_reads:
                db.add_all(new_reads)
            
            # 更新或创建游标（按 application_id 区分）
            cursor_filters = [
                models.MessageReadCursor.task_id == task_id,
                models.MessageReadCursor.user_id == current_user.id,
            ]
            if request.application_id:
                cursor_filters.append(models.MessageReadCursor.application_id == request.application_id)
            else:
                cursor_filters.append(models.MessageReadCursor.application_id.is_(None))

            cursor_query = select(models.MessageReadCursor).where(and_(*cursor_filters))
            cursor_result = await db.execute(cursor_query)
            cursor = cursor_result.scalar_one_or_none()

            if cursor:
                # 只有当新游标大于等于当前游标时才更新（防止游标回退）
                # 如果游标为 NULL（消息被删除后），也需要更新
                if cursor.last_read_message_id is None or upto_message.id >= cursor.last_read_message_id:
                    cursor.last_read_message_id = upto_message.id
                    cursor.updated_at = current_time
            else:
                new_cursor = models.MessageReadCursor(
                    task_id=task_id,
                    user_id=current_user.id,
                    application_id=request.application_id,
                    last_read_message_id=upto_message.id,
                    updated_at=current_time
                )
                db.add(new_cursor)

        elif request.message_ids:
            # 方式2：标记指定消息ID列表
            # 查询这些消息（排除自己发送的消息）
            messages_to_mark_query = select(models.Message).where(
                and_(
                    models.Message.id.in_(request.message_ids),
                    models.Message.task_id == task_id,
                    models.Message.sender_id != current_user.id
                )
            )
            messages_to_mark_result = await db.execute(messages_to_mark_query)
            messages_to_mark = messages_to_mark_result.scalars().all()
            
            # 批量查询已存在的已读记录（优化性能）
            message_ids_to_mark = [msg.id for msg in messages_to_mark]
            existing_reads_query = select(models.MessageRead).where(
                and_(
                    models.MessageRead.message_id.in_(message_ids_to_mark),
                    models.MessageRead.user_id == current_user.id
                )
            )
            existing_reads_result = await db.execute(existing_reads_query)
            existing_read_message_ids = {read.message_id for read in existing_reads_result.scalars().all()}
            
            # 批量标记为已读（只插入不存在的记录）
            new_reads = []
            for msg in messages_to_mark:
                if msg.id not in existing_read_message_ids:
                    new_read = models.MessageRead(
                        message_id=msg.id,
                        user_id=current_user.id,
                        read_at=current_time
                    )
                    new_reads.append(new_read)
                    marked_count += 1
            
            # 批量插入
            if new_reads:
                db.add_all(new_reads)
            
            # 更新游标（使用最大的消息ID，按 application_id 区分）
            if messages_to_mark:
                max_message_id = max([msg.id for msg in messages_to_mark])

                cursor_filters = [
                    models.MessageReadCursor.task_id == task_id,
                    models.MessageReadCursor.user_id == current_user.id,
                ]
                if request.application_id:
                    cursor_filters.append(models.MessageReadCursor.application_id == request.application_id)
                else:
                    cursor_filters.append(models.MessageReadCursor.application_id.is_(None))

                cursor_query = select(models.MessageReadCursor).where(and_(*cursor_filters))
                cursor_result = await db.execute(cursor_query)
                cursor = cursor_result.scalar_one_or_none()

                if cursor:
                    # 处理游标为 NULL 的情况（消息被删除后游标可能为 NULL）
                    if cursor.last_read_message_id is None or max_message_id > cursor.last_read_message_id:
                        cursor.last_read_message_id = max_message_id
                        cursor.updated_at = current_time
                else:
                    new_cursor = models.MessageReadCursor(
                        task_id=task_id,
                        user_id=current_user.id,
                        application_id=request.application_id,
                        last_read_message_id=max_message_id,
                        updated_at=current_time
                    )
                    db.add(new_cursor)
        
        await db.commit()
        
        # 失效当前用户的聊天列表 + 未读数缓存
        from app.redis_cache import invalidate_task_chat_cache
        invalidate_task_chat_cache(current_user.id)
        
        return {
            "marked_count": marked_count,
            "task_id": task_id
        }
    
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"标记消息已读失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="标记消息已读失败，请稍后重试"
        )


# 申请相关接口
class ApplyTaskRequest(BaseModel):
    """申请任务请求体"""
    message: Optional[str] = Field(None, max_length=1000)
    negotiated_price: Optional[float] = Field(None, ge=0.01, le=50000.0)
    currency: Optional[str] = Field(None, max_length=3)


class NegotiateRequest(BaseModel):
    """再次议价请求体"""
    negotiated_price: float = Field(..., ge=0.01, le=50000.0)
    message: Optional[str] = Field(None, max_length=1000)


class RespondNegotiationRequest(BaseModel):
    """处理再次议价请求体"""
    action: str = Field(..., description="accept 或 reject")
    token: str = Field(..., description="一次性签名token")


class SendApplicationMessageRequest(BaseModel):
    """发送申请留言请求体"""
    message: str = Field(..., max_length=1000, description="留言内容")
    negotiated_price: Optional[float] = Field(None, ge=0.01, le=50000.0, description="议价金额（可选）")


class ReplyApplicationMessageRequest(BaseModel):
    """回复申请留言请求体"""
    message: str = Field(..., max_length=1000, description="回复内容")
    notification_id: int = Field(..., description="原始通知ID")


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/accept")
async def accept_application(
    task_id: int,
    application_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    接受申请
    使用事务锁防止并发，支持幂等性
    """
    try:
        # 补差价变量（在 is_paid==1 且 new_price > original_paid 时设置）
        top_up_pence = 0
        top_up_original_paid = 0.0

        # 检查任务是否存在
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()

        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="任务不存在"
            )

        # 权限检查：必须是发布者
        if task.poster_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只有发布者可以接受申请"
            )
        
        # 检查申请是否存在且属于该任务
        application_query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id
            )
        )
        application_result = await db.execute(application_query)
        application = application_result.scalar_one_or_none()
        
        if not application:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="申请不存在"
            )

        # 申请必须是可接受的状态
        if application.status not in ("pending", "chatting", "approved", "price_agreed"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"申请当前状态为 {application.status}，无法接受"
            )

        # 使用 SELECT FOR UPDATE 锁定任务行（防止并发）
        from sqlalchemy import update
        locked_task_query = select(models.Task).where(
            models.Task.id == task_id
        ).with_for_update()
        locked_task_result = await db.execute(locked_task_query)
        locked_task = locked_task_result.scalar_one_or_none()

        # 幂等性检查：如果申请已经是 approved，检查是否有待支付的 PaymentIntent
        if application.status == "approved":
            logger.info(f"⚠️ 申请 {application_id} 已经是 approved 状态，检查是否有待支付的 PaymentIntent")
            
            # 如果任务已支付，直接返回已接受的消息
            if locked_task.is_paid == 1:
                logger.info(f"✅ 申请 {application_id} 已批准，任务已支付")
                return {
                    "message": "申请已被接受，任务已支付",
                    "application_id": application_id,
                    "task_id": task_id,
                    "is_paid": True
                }
            
            # ⚠️ 新流程：如果任务有 payment_intent_id 且状态是 open 或 pending_payment，返回支付信息
            # open 状态：新流程，任务保持 open 状态等待支付
            # pending_payment 状态：兼容旧流程
            if locked_task.payment_intent_id and locked_task.status in ["open", "pending_payment"]:
                try:
                    import stripe
                    import os
                    payment_intent = stripe.PaymentIntent.retrieve(locked_task.payment_intent_id)
                    
                    # ⚠️ 安全验证：验证 PaymentIntent 是否属于当前申请者
                    payment_intent_application_id = payment_intent.get("metadata", {}).get("application_id")
                    if payment_intent_application_id and str(payment_intent_application_id) != str(application_id):
                        logger.warning(
                            f"⚠️ PaymentIntent 申请者不匹配: "
                            f"PaymentIntent metadata.application_id={payment_intent_application_id}, "
                            f"当前请求的 application_id={application_id}, "
                            f"payment_intent_id={locked_task.payment_intent_id}"
                        )
                        # 如果 PaymentIntent 不属于当前申请者，清除它并抛出异常，让调用方重新创建
                        locked_task.payment_intent_id = None
                        await db.commit()
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail=f"PaymentIntent 不属于申请者 {application_id}。请重新批准该申请者。"
                        )
                    elif payment_intent_application_id:
                        logger.info(f"✅ PaymentIntent 申请者验证通过: application_id={application_id}")
                    else:
                        # PaymentIntent 没有 application_id metadata（可能是旧数据）
                        logger.warning(
                            f"⚠️ PaymentIntent 缺少 application_id metadata: "
                            f"payment_intent_id={locked_task.payment_intent_id}, "
                            f"当前请求的 application_id={application_id}"
                        )
                        # 为了安全，清除它并抛出异常
                        locked_task.payment_intent_id = None
                        await db.commit()
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail="PaymentIntent 缺少申请者信息，无法验证。请重新批准该申请者。"
                        )

                    # 为支付方创建/获取 Customer + EphemeralKey（用于保存卡）
                    customer_id, ephemeral_key_secret = await _create_customer_and_ephemeral_key(
                        stripe_module=stripe,
                        user_obj=current_user,
                        db_session=db,
                    )
                    
                    # 检查 PaymentIntent 状态
                    if payment_intent.status == "succeeded":
                        logger.info(f"✅ PaymentIntent 已成功，但任务状态未更新，可能是 webhook 延迟")
                        # 返回已支付信息，但不包含 client_secret（因为已支付）
                        return {
                            "message": "申请已被接受，支付已完成",
                            "application_id": application_id,
                            "task_id": task_id,
                            "payment_intent_id": payment_intent.id,
                            "payment_status": "succeeded",
                            "is_paid": True
                        }
                    
                    logger.info(f"✅ 找到待支付的 PaymentIntent: {locked_task.payment_intent_id}")
                    return {
                        "message": "请完成支付以确认批准申请",
                        "application_id": application_id,
                        "task_id": task_id,
                        "payment_intent_id": payment_intent.id,
                        "client_secret": payment_intent.client_secret,
                        "amount": payment_intent.amount,
                        "amount_display": f"{payment_intent.amount / 100:.2f}",
                        "currency": payment_intent.currency.upper(),
                        "customer_id": customer_id,
                        "ephemeral_key_secret": ephemeral_key_secret,
                    }
                except Exception as e:
                    logger.error(f"❌ 获取 PaymentIntent 失败: {e}")
            
            # 否则返回已接受的消息（不包含支付信息）
            logger.info(f"ℹ️ 申请 {application_id} 已批准，但无需支付或已支付")
            return {
                "message": "申请已被接受",
                "application_id": application_id,
                "task_id": task_id
            }
        
        # 已付款任务（如取消后重新开放的）
        if locked_task.is_paid == 1:
            original_paid = float(locked_task.agreed_reward or locked_task.base_reward or 0)
            new_price = float(application.negotiated_price) if application.negotiated_price is not None else original_paid

            if new_price <= original_paid:
                # ---- 新价 ≤ 已付：跳过支付，直接批准 ----
                logger.info(f"✅ 任务 {task_id} 已付款(£{original_paid:.2f})，新价 £{new_price:.2f} ≤ 已付，直接批准")

                await db.execute(
                    update(models.TaskApplication)
                    .where(models.TaskApplication.id == application_id)
                    .values(status="approved")
                )
                locked_task.taker_id = application.applicant_id
                locked_task.status = "in_progress"
                if application.negotiated_price is not None:
                    locked_task.agreed_reward = application.negotiated_price

                # 更新可靠度画像（任务分配）
                try:
                    from app.services.reliability_calculator import on_task_assigned
                    from app.database import SessionLocal
                    sync_db = SessionLocal()
                    try:
                        on_task_assigned(sync_db, application.applicant_id, locked_task.poster_id)
                        sync_db.commit()
                    finally:
                        sync_db.close()
                except Exception as e:
                    import logging
                    logging.getLogger(__name__).warning(f"更新可靠度失败(task_assigned): {e}")

                # 重新计算 escrow（按新价格），多余的钱退给发布者
                from app.utils.fee_calculator import calculate_application_fee_pence
                import hashlib
                new_price_pence = round(new_price * 100)
                ts = getattr(locked_task, "task_source", None)
                tt = getattr(locked_task, "task_type", None)
                new_fee_pence = calculate_application_fee_pence(new_price_pence, ts, tt)
                locked_task.escrow_amount = max(0.0, (new_price_pence - new_fee_pence) / 100.0)

                # 自动退还差额（original_paid - new_price）
                original_paid_pence = round(original_paid * 100)
                refund_pence = original_paid_pence - new_price_pence
                if refund_pence > 0 and locked_task.payment_intent_id:
                    try:
                        import stripe
                        if stripe.api_key:
                            charges = stripe.Charge.list(
                                payment_intent=locked_task.payment_intent_id, limit=1
                            )
                            if charges.data:
                                idempotency_key = hashlib.sha256(
                                    f"price_diff_refund_{locked_task.id}_{charges.data[0].id}_{refund_pence}".encode()
                                ).hexdigest()
                                stripe.Refund.create(
                                    charge=charges.data[0].id,
                                    amount=refund_pence,
                                    reason="requested_by_customer",
                                    idempotency_key=idempotency_key,
                                    metadata={
                                        "task_id": str(task_id),
                                        "refund_type": "price_difference",
                                        "original_paid_pence": str(original_paid_pence),
                                        "new_price_pence": str(new_price_pence),
                                    }
                                )
                                logger.info(f"✅ 差价退款成功: task_id={task_id}, amount={refund_pence}p")
                    except Exception as e:
                        logger.error(f"差价退款失败(需人工处理): task_id={task_id}, amount={refund_pence}p, error={e}")

                # 自动拒绝其他 pending/chatting 申请
                other_apps_query = select(models.TaskApplication).where(
                    and_(
                        models.TaskApplication.task_id == task_id,
                        models.TaskApplication.id != application_id,
                        models.TaskApplication.status.in_(["chatting", "pending"])
                    )
                )
                other_apps_result = await db.execute(other_apps_query)
                for other_app in other_apps_result.scalars().all():
                    was_chatting = other_app.status == "chatting"
                    other_app.status = "rejected"
                    if was_chatting:
                        reject_msg = models.Message(
                            task_id=task_id, application_id=other_app.id,
                            sender_id=None, receiver_id=None,
                            content="发布者已选择了其他申请者完成此任务。",
                            message_type="system", conversation_type="task",
                            meta=json.dumps({"system_action": "auto_rejected",
                                             "content_en": "The poster has selected another applicant for this task."}),
                            created_at=get_utc_time(),
                        )
                        db.add(reject_msg)

                await db.commit()

                try:
                    from app import async_crud
                    await async_crud.async_notification_crud.create_notification(
                        db, application.applicant_id, "application_accepted",
                        "申请已通过", f'您的任务申请已被接受：{locked_task.title}',
                        related_id=str(application_id), title_en="Application Accepted",
                        content_en=f'Your application has been accepted: {locked_task.title}',
                        related_type="application_id",
                    )
                except Exception as e:
                    logger.warning(f"发送申请通过通知失败: {e}")

                return {
                    "message": "任务已付款，申请已直接通过",
                    "application_id": application_id,
                    "task_id": task_id,
                    "is_paid": True,
                    "already_paid": True,
                }
            else:
                # ---- 新价 > 已付：需要补差价，走支付流程 ----
                difference = new_price - original_paid
                top_up_pence = round(difference * 100)
                top_up_original_paid = original_paid
                logger.info(
                    f"✅ 任务 {task_id} 需补差价: 已付 £{original_paid:.2f}, "
                    f"新价 £{new_price:.2f}, 差额 £{difference:.2f}"
                )
                # 落入下方的支付创建流程，使用 top_up_pence 作为支付金额

        # 检查任务是否还有名额（已付款 top-up 路径 taker_id 已被清除，为 None）
        if locked_task.taker_id is not None:
            # 指定接单任务：允许发布者为已指定的接单者创建支付
            if (locked_task.status == "pending_acceptance"
                    and str(application.applicant_id) == str(locked_task.taker_id)):
                logger.info(
                    f"✅ 指定接单任务 {task_id}：发布者批准指定接单者 {application.applicant_id} 的申请"
                )
            else:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="任务已被接受"
                )

        # 获取申请人信息（用于 metadata）
        applicant = await db.get(models.User, application.applicant_id)
        if not applicant:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="申请人不存在"
            )

        # 获取当前时间
        current_time = get_utc_time()
        
        # 不立即批准申请，而是创建支付意图
        # 申请状态保持为 pending，等待支付成功后才批准
        
        # 计算任务金额
        # 判断是否为补差价模式（top_up_pence 在上方 is_paid==1 分支中设置）
        is_top_up = top_up_pence > 0

        task_amount = float(application.negotiated_price) if application.negotiated_price is not None else float(locked_task.base_reward) if locked_task.base_reward is not None else 0.0

        if task_amount <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="任务金额必须大于0，无法进行支付"
            )

        # 补差价时只收差额；普通支付收全额
        if is_top_up:
            charge_pence = top_up_pence
        else:
            charge_pence = round(task_amount * 100)

        # 计算平台服务费（按 *本次收款金额* 计算）
        from app.utils.fee_calculator import calculate_application_fee_pence
        task_source = getattr(locked_task, "task_source", None)
        task_type = getattr(locked_task, "task_type", None)
        application_fee_pence = calculate_application_fee_pence(charge_pence, task_source, task_type)

        # 创建 Stripe Payment Intent
        import stripe
        import os

        # 构建支付描述（方便在 Stripe Dashboard 中查看）
        task_title_short = locked_task.title[:50] if locked_task.title else f"Task #{task_id}"
        if is_top_up:
            payment_description = f"任务 #{task_id}: {task_title_short} - 补差价 #{application_id}"
        else:
            payment_description = f"任务 #{task_id}: {task_title_short} - 批准申请 #{application_id}"

        payment_type = "top_up" if is_top_up else "application_approval"
        task_amount_pence = round(task_amount * 100)
        pi_metadata = {
            "task_id": str(task_id),
            "task_title": locked_task.title[:200] if locked_task.title else "",
            "application_id": str(application_id),
            "poster_id": str(current_user.id),
            "poster_name": current_user.name or f"User {current_user.id}",
            "taker_id": str(application.applicant_id),
            "taker_name": applicant.name or f"User {application.applicant_id}",

            "application_fee": str(application_fee_pence),
            "task_amount": str(task_amount_pence),
            "task_amount_display": f"{task_amount:.2f}",
            "negotiated_price": str(application.negotiated_price) if application.negotiated_price else "",
            "pending_approval": "true",
            "platform": "Link²Ur",
            "payment_type": payment_type,
        }
        if is_top_up:
            pi_metadata["original_paid_pence"] = str(round(top_up_original_paid * 100))
        pi_currency = (getattr(locked_task, "currency", None) or "GBP").lower()
        pi_pm_types = _payment_method_types_for_currency(pi_currency)
        from app.secure_auth import get_wechat_pay_payment_method_options
        payment_method_options = get_wechat_pay_payment_method_options(request) if "wechat_pay" in pi_pm_types else {}
        create_pi_kw = {
            "amount": charge_pence,
            "currency": pi_currency,
            "payment_method_types": pi_pm_types,
            "description": payment_description,
            "metadata": pi_metadata,
        }
        if payment_method_options:
            create_pi_kw["payment_method_options"] = payment_method_options
        payment_intent = stripe.PaymentIntent.create(**create_pi_kw)

        # 为支付方创建/获取 Customer + EphemeralKey（用于保存卡）
        customer_id, ephemeral_key_secret = await _create_customer_and_ephemeral_key(
            stripe_module=stripe,
            user_obj=current_user,
            db_session=db,
        )
        
        # 保存 payment_intent_id 到任务（临时存储，支付成功后才会真正批准）
        locked_task.payment_intent_id = payment_intent.id
        
        # 如果申请包含议价，更新 agreed_reward（但不更新 taker_id 和状态）
        if application.negotiated_price is not None:
            locked_task.agreed_reward = application.negotiated_price
        
        # ⚠️ 新流程：任务保持 open 状态，不进入 pending_payment
        # 只有支付成功后才设置 taker_id 并将状态改为 in_progress
        # 如果支付失败/取消，任务状态保持 open，可以继续批准其他申请者
        # 不更新任务状态，保持为 open
        # 不设置 taker_id，等待支付成功后再设置（由 webhook 处理）
        # 不设置 payment_expires_at，因为任务状态保持 open，不需要支付过期检查
        # 不更新申请状态，保持为 pending（等待支付成功后由 webhook 更新）
        # 这样确保只有支付成功后才真正批准申请
        
        await db.commit()
        
        # 记录关键信息（INFO级别）
        logger.info(f"✅ {'补差价' if is_top_up else '批准申请'}成功: task_id={task_id}, application_id={application_id}, payment_intent_id={payment_intent.id}, amount={charge_pence/100:.2f} GBP")

        msg = "请完成补差价支付" if is_top_up else "请完成支付以确认批准申请"
        response_data = {
            "message": msg,
            "application_id": application_id,
            "task_id": task_id,
            "payment_intent_id": payment_intent.id,
            "client_secret": payment_intent.client_secret,
            "amount": charge_pence,
            "amount_display": f"{charge_pence / 100:.2f}",
            "currency": getattr(locked_task, "currency", None) or "GBP",
            "customer_id": customer_id,
            "ephemeral_key_secret": ephemeral_key_secret,
        }
        
        return response_data
    
    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"接受申请失败: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="接受申请失败，请稍后重试"
        )


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/start-chat")
async def start_application_chat(
    task_id: int,
    application_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    开始与申请者的聊天（单人任务专用）
    发布者点击"聊一聊"后，将申请状态改为 chatting（任务保持 open），
    并创建系统消息通知申请者。
    """
    try:
        # 使用 FOR UPDATE 锁定任务行（防止并发开始聊天）
        task_query = select(models.Task).where(
            models.Task.id == task_id
        ).with_for_update()
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()

        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="任务不存在"
            )

        # 权限检查：必须是发布者
        if task.poster_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只有发布者可以开始聊天"
            )

        # 多人任务不支持此流程
        if task.is_multi_participant:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="多人任务不支持此操作，请使用原有流程"
            )

        # 检查任务状态：open 或 chatting（chatting 兼容旧数据）
        if task.status not in ("open", "chatting"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"任务当前状态为 {task.status}，无法开始聊天"
            )

        # 检查申请是否存在且属于该任务（加锁）
        application_query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id
            )
        ).with_for_update()
        application_result = await db.execute(application_query)
        application = application_result.scalar_one_or_none()

        if not application:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="申请不存在"
            )

        # 幂等性：如果已经是 chatting 状态，直接返回成功
        if application.status == "chatting":
            return {
                "message": "聊天已开始",
                "application_id": application_id,
                "task_id": task_id,
                "applicant_id": application.applicant_id,
                "status": "chatting"
            }

        # 申请必须是 pending 状态
        if application.status != "pending":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"申请当前状态为 {application.status}，无法开始聊天"
            )

        # 更新申请状态为 chatting
        await db.execute(
            update(models.TaskApplication)
            .where(models.TaskApplication.id == application_id)
            .values(status="chatting")
        )

        # 任务保持 open 状态，不改变（允许其他人继续申请和发布者同时聊多个申请人）

        # 创建系统消息通知申请者
        current_time = get_utc_time()
        content_zh = "发布者已开始与你的聊天，请在此频道沟通任务详情。"
        content_en = "The poster has started a chat with you. Please discuss task details in this channel."
        system_message = models.Message(
            sender_id=None,
            receiver_id=None,
            content=content_zh,
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            application_id=application_id,
            meta=json.dumps({"system_action": "chat_started", "content_en": content_en}),
            created_at=current_time,
        )
        db.add(system_message)

        await db.commit()

        logger.info(f"✅ 开始聊天: task_id={task_id}, application_id={application_id}, applicant_id={application.applicant_id}")

        # 发送通知给申请者
        try:
            notification_time = get_utc_time()

            notif_content = f"发布者已同意与您聊天，讨论任务详情：{task.title}"
            notif_content_en = f"The poster has agreed to chat with you about the task: {task.title}"

            new_notification = models.Notification(
                user_id=application.applicant_id,
                type="application_chat_started",
                title="发布者邀请您聊天",
                content=notif_content,
                title_en="Chat Invitation",
                content_en=notif_content_en,
                related_id=application_id,
                related_type="application_id",
                created_at=notification_time
            )
            db.add(new_notification)
            await db.commit()

            # 发送推送通知
            try:
                send_push_notification_async_safe(
                    async_db=db,
                    user_id=application.applicant_id,
                    title=None,
                    body=None,
                    notification_type="application_chat_started",
                    data={"task_id": task_id, "application_id": application_id},
                    template_vars={
                        "task_title": task.title,
                        "task_id": task_id
                    }
                )
            except Exception as e:
                logger.warning(f"发送聊天开始推送通知失败: {e}")
        except Exception as e:
            logger.error(f"发送聊天开始通知失败: {e}")

        # 通过WebSocket通知申请者
        try:
            from app.websocket_manager import get_ws_manager
            ws_manager = get_ws_manager()

            ws_message = {
                "type": "task_message",
                "message": {
                    "id": system_message.id if hasattr(system_message, 'id') else None,
                    "sender_id": None,
                    "sender_name": "System",
                    "content": system_message.content,
                    "task_id": task_id,
                    "message_type": "system",
                    "application_id": application_id,
                    "created_at": format_iso_utc(current_time) if current_time else None,
                }
            }
            await ws_manager.send_to_user(application.applicant_id, ws_message)
        except Exception as e:
            logger.warning(f"WebSocket通知申请者失败: {e}")

        # 失效聊天缓存
        try:
            from app.redis_cache import invalidate_task_chat_cache
            invalidate_task_chat_cache(application.applicant_id)
            invalidate_task_chat_cache(current_user.id)
        except Exception as e:
            logger.warning(f"失效聊天缓存失败: {e}")

        return {
            "message": "聊天已开始",
            "application_id": application_id,
            "task_id": task_id,
            "applicant_id": application.applicant_id,
            "status": "chatting"
        }

    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"开始聊天失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="开始聊天失败，请稍后重试"
        )


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/propose-price")
async def propose_price(
    task_id: int,
    application_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    在聊天中提出新价格（发布者或申请者均可）
    更新申请的 negotiated_price 并创建 price_proposal 消息
    """
    try:
        # 解析请求体
        body = await request.json()
        proposed_price = body.get("proposed_price") or body.get("proposedPrice")

        if proposed_price is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="proposed_price 必须提供"
            )

        try:
            proposed_price = float(proposed_price)
        except (TypeError, ValueError):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="proposed_price 必须是有效的数字"
            )

        if proposed_price <= 0 or proposed_price > 50000:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="proposed_price 必须大于 0 且不超过 50000"
            )

        # 检查任务是否存在
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()

        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="任务不存在"
            )

        # 检查申请是否存在且属于该任务（加锁防并发报价）
        application_query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id
            )
        ).with_for_update()
        application_result = await db.execute(application_query)
        application = application_result.scalar_one_or_none()

        if not application:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="申请不存在"
            )

        # 申请必须是 chatting 状态
        if application.status != "chatting":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"申请当前状态为 {application.status}，只有 chatting 状态才能提出价格"
            )

        # 权限检查：必须是发布者或申请者
        is_poster = task.poster_id == current_user.id
        is_applicant = application.applicant_id == current_user.id

        if not is_poster and not is_applicant:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只有发布者或申请者可以提出价格"
            )

        # 确定消息接收方
        if is_poster:
            receiver_id = application.applicant_id
        else:
            receiver_id = task.poster_id

        # 更新申请的 negotiated_price
        from decimal import Decimal
        application.negotiated_price = Decimal(str(proposed_price))

        # 创建 price_proposal 消息
        current_time = get_utc_time()
        meta_dict = {
            "proposedPrice": float(proposed_price),
            "proposedBy": current_user.id
        }
        price_message = models.Message(
            sender_id=current_user.id,
            receiver_id=receiver_id,
            content=f"Proposed new price: £{proposed_price:.2f}",
            task_id=task_id,
            application_id=application_id,
            message_type="price_proposal",
            conversation_type="task",
            meta=json.dumps(meta_dict),
            created_at=current_time,
        )
        db.add(price_message)

        await db.commit()

        logger.info(
            f"✅ 价格提议: task_id={task_id}, application_id={application_id}, "
            f"proposed_price={proposed_price}, by user {current_user.id}"
        )

        # 发送通知给对方
        try:
            notification_time = get_utc_time()
            sender_name = current_user.name or f"用户{current_user.id}"

            notif_content = f"{sender_name} 提出了新价格 £{proposed_price:.2f}：{task.title}"
            notif_content_en = f"{sender_name} proposed a new price £{proposed_price:.2f}: {task.title}"

            new_notification = models.Notification(
                user_id=receiver_id,
                type="price_proposal",
                title="收到新的价格提议",
                content=notif_content,
                title_en="New Price Proposal",
                content_en=notif_content_en,
                related_id=application_id,
                related_type="application_id",
                created_at=notification_time
            )
            db.add(new_notification)
            await db.commit()

            # 发送推送通知
            try:
                send_push_notification_async_safe(
                    async_db=db,
                    user_id=receiver_id,
                    title=None,
                    body=None,
                    notification_type="price_proposal",
                    data={"task_id": task_id, "application_id": application_id},
                    template_vars={
                        "sender_name": sender_name,
                        "proposed_price": f"£{proposed_price:.2f}",
                        "task_title": task.title,
                        "task_id": task_id
                    }
                )
            except Exception as e:
                logger.warning(f"发送价格提议推送通知失败: {e}")
        except Exception as e:
            logger.error(f"发送价格提议通知失败: {e}")

        # 通过WebSocket通知对方
        try:
            from app.websocket_manager import get_ws_manager
            ws_manager = get_ws_manager()

            ws_message = {
                "type": "task_message",
                "message": {
                    "id": price_message.id if hasattr(price_message, 'id') else None,
                    "sender_id": current_user.id,
                    "sender_name": current_user.name,
                    "sender_avatar": getattr(current_user, 'avatar', None),
                    "content": price_message.content,
                    "task_id": task_id,
                    "message_type": "price_proposal",
                    "application_id": application_id,
                    "meta": meta_dict,
                    "created_at": format_iso_utc(current_time) if current_time else None,
                }
            }
            await ws_manager.send_to_user(receiver_id, ws_message)
        except Exception as e:
            logger.warning(f"WebSocket通知价格提议失败: {e}")

        # 失效聊天缓存
        try:
            from app.redis_cache import invalidate_task_chat_cache
            invalidate_task_chat_cache(receiver_id)
            invalidate_task_chat_cache(current_user.id)
        except Exception as e:
            logger.warning(f"失效聊天缓存失败: {e}")

        return {
            "status": "ok",
            "negotiatedPrice": float(proposed_price)
        }

    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"价格提议失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="价格提议失败，请稍后重试"
        )


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/confirm-and-pay")
async def confirm_and_pay(
    task_id: int,
    application_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    确认并支付（聊天后支付）
    发布者在与申请者聊天协商后，确认选择该申请者并创建支付意图。
    使用 negotiated_price（如果有）或 task.reward 作为最终价格。
    """
    try:
        # 使用 SELECT FOR UPDATE 锁定任务行（防止并发）
        locked_task_query = select(models.Task).where(
            models.Task.id == task_id
        ).with_for_update()
        locked_task_result = await db.execute(locked_task_query)
        locked_task = locked_task_result.scalar_one_or_none()

        if not locked_task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="任务不存在"
            )

        # 权限检查：必须是发布者
        if locked_task.poster_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只有发布者可以确认并支付"
            )

        # 检查任务状态：open 或 chatting 均可（chatting 兼容旧数据）
        if locked_task.status not in ("open", "chatting"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"任务当前状态为 {locked_task.status}，无法确认支付"
            )

        # 检查任务是否已支付（防止重复支付）
        if locked_task.is_paid == 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="任务已支付，无法重复支付。"
            )

        # 检查是否已有待处理的 PaymentIntent（防止重复创建）
        if locked_task.payment_intent_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="已有待处理的支付，请等待支付完成或联系客服"
            )

        # 使用 SELECT FOR UPDATE 锁定申请行
        locked_app_query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id
            )
        ).with_for_update()
        locked_app_result = await db.execute(locked_app_query)
        application = locked_app_result.scalar_one_or_none()

        if not application:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="申请不存在"
            )

        # 申请必须是 chatting 状态
        if application.status != "chatting":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"申请当前状态为 {application.status}，只有 chatting 状态才能确认支付"
            )

        # 确定最终价格：优先使用议价价格，否则使用任务原始奖励
        final_price = float(application.negotiated_price) if application.negotiated_price is not None else float(locked_task.base_reward) if locked_task.base_reward is not None else 0.0

        if final_price <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="任务金额必须大于0，无法进行支付"
            )

        # 获取申请人信息
        applicant = await db.get(models.User, application.applicant_id)
        if not applicant:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="申请人不存在"
            )

        # 计算金额（pence）
        final_price_pence = round(final_price * 100)

        # 计算平台服务费
        from app.utils.fee_calculator import calculate_application_fee_pence
        task_source = getattr(locked_task, "task_source", None)
        task_type = getattr(locked_task, "task_type", None)
        application_fee_pence = calculate_application_fee_pence(final_price_pence, task_source, task_type)

        # 创建 Stripe Payment Intent
        import stripe
        import os

        task_title_short = locked_task.title[:50] if locked_task.title else f"Task #{task_id}"
        payment_description = f"任务 #{task_id}: {task_title_short} - 确认支付申请 #{application_id}"

        pi_currency_2 = (getattr(locked_task, "currency", None) or "GBP").lower()
        pi_pm_types_2 = _payment_method_types_for_currency(pi_currency_2)
        from app.secure_auth import get_wechat_pay_payment_method_options
        payment_method_options = get_wechat_pay_payment_method_options(request) if "wechat_pay" in pi_pm_types_2 else {}
        create_pi_kw = {
            "amount": final_price_pence,
            "currency": pi_currency_2,
            "payment_method_types": pi_pm_types_2,
            "description": payment_description,
            "metadata": {
                "task_id": str(task_id),
                "task_title": locked_task.title[:200] if locked_task.title else "",
                "application_id": str(application_id),
                "poster_id": str(current_user.id),
                "poster_name": current_user.name or f"User {current_user.id}",
                "taker_id": str(application.applicant_id),
                "taker_name": applicant.name or f"User {application.applicant_id}",
    
                "application_fee": str(application_fee_pence),
                "task_amount": str(final_price_pence),
                "task_amount_display": f"{final_price:.2f}",
                "negotiated_price": str(application.negotiated_price) if application.negotiated_price else "",
                "pending_approval": "true",
                "platform": "Link²Ur",
                "payment_type": "chat_confirm_payment",
            },
        }
        if payment_method_options:
            create_pi_kw["payment_method_options"] = payment_method_options
        payment_intent = stripe.PaymentIntent.create(**create_pi_kw)

        # 为支付方创建/获取 Customer + EphemeralKey
        customer_id, ephemeral_key_secret = await _create_customer_and_ephemeral_key(
            stripe_module=stripe,
            user_obj=current_user,
            db_session=db,
        )

        # 保存 payment_intent_id 到任务
        locked_task.payment_intent_id = payment_intent.id

        # 如果申请包含议价，更新 agreed_reward
        if application.negotiated_price is not None:
            locked_task.agreed_reward = application.negotiated_price

        await db.commit()

        logger.info(
            f"✅ 确认支付成功: task_id={task_id}, application_id={application_id}, "
            f"payment_intent_id={payment_intent.id}, amount={final_price_pence/100:.2f} GBP"
        )

        return {
            "message": "请完成支付以确认选择该申请者",
            "application_id": application_id,
            "task_id": task_id,
            "payment_intent_id": payment_intent.id,
            "client_secret": payment_intent.client_secret,
            "amount": final_price_pence,
            "amount_display": f"{final_price_pence / 100:.2f}",
            "currency": getattr(locked_task, "currency", None) or "GBP",
            "customer_id": customer_id,
            "ephemeral_key_secret": ephemeral_key_secret,
        }

    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"确认支付失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="确认支付失败，请稍后重试"
        )


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/reject")
async def reject_application(
    task_id: int,
    application_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    拒绝申请
    """
    try:
        # 检查任务是否存在（加锁防止并发）
        task_query = select(models.Task).where(models.Task.id == task_id).with_for_update()
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()

        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="任务不存在"
            )

        # 权限检查：必须是发布者
        if task.poster_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只有发布者可以拒绝申请"
            )

        # 检查申请是否存在且属于该任务（加锁）
        application_query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id
            )
        ).with_for_update()
        application_result = await db.execute(application_query)
        application = application_result.scalar_one_or_none()

        if not application:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="申请不存在"
            )

        # 只能拒绝 pending 或 chatting 状态的申请
        if application.status not in ("pending", "chatting"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"申请当前状态为 {application.status}，只能拒绝待处理或聊天中的申请"
            )

        # 获取当前时间
        current_time = get_utc_time()

        # 更新申请状态
        application.status = "rejected"

        # 写入操作日志
        log_entry = models.NegotiationResponseLog(
            task_id=task_id,
            application_id=application_id,
            user_id=current_user.id,
            action="reject",
            responded_at=current_time
        )
        db.add(log_entry)

        # Flush so the status change is visible in the count query
        await db.flush()

        # 任务保持 open 状态，无需回退

        await db.commit()

        # 发送通知给申请者
        try:
            notification_time = get_utc_time()

            # ⚠️ 直接使用文本内容，不存储 JSON
            content = f"您的任务申请已被拒绝：{task.title}"
            content_en = f"Your task application has been rejected: {task.title}"
            
            new_notification = models.Notification(
                user_id=application.applicant_id,
                type="application_rejected",
                title="您的申请已被拒绝",
                content=content,  # 直接使用文本，不存储 JSON
                title_en="Application Rejected",
                content_en=content_en,
                related_id=application_id,
                related_type="application_id",  # related_id 是 application_id
                created_at=notification_time
            )
            db.add(new_notification)
            await db.commit()
            
            # 发送推送通知
            try:
                send_push_notification_async_safe(
                    async_db=db,
                    user_id=application.applicant_id,
                    title=None,  # 从模板生成（会根据用户语言偏好）
                    body=None,  # 从模板生成（会根据用户语言偏好）
                    notification_type="application_rejected",
                    data={"task_id": task_id, "application_id": application_id},
                    template_vars={
                        "task_title": task.title,  # 原始标题，会在 send_push_notification 中根据用户语言从翻译表获取
                        "task_id": task_id  # 传递 task_id 以便获取翻译
                    }
                )
            except Exception as e:
                logger.warning(f"发送申请拒绝推送通知失败: {e}")
                # 推送通知失败不影响主流程
        except Exception as e:
            logger.error(f"发送拒绝申请通知失败: {e}")
            # 通知失败不影响主流程
        
        return {
            "message": "申请已拒绝",
            "application_id": application_id,
            "task_id": task_id
        }
    
    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"拒绝申请失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="拒绝申请失败，请稍后重试"
        )


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/withdraw")
async def withdraw_application(
    task_id: int,
    application_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    撤回申请
    只有申请者本人可以撤回
    """
    try:
        # 检查任务是否存在（加锁防止并发）
        task_query = select(models.Task).where(models.Task.id == task_id).with_for_update()
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()

        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="任务不存在"
            )

        # 检查申请是否存在且属于该任务（加锁）
        application_query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id
            )
        ).with_for_update()
        application_result = await db.execute(application_query)
        application = application_result.scalar_one_or_none()

        if not application:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="申请不存在"
            )

        # 权限检查：必须是申请者本人
        if application.applicant_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只有申请者本人可以撤回申请"
            )

        # 检查申请状态：pending 或 chatting 状态可撤回
        if application.status not in ("pending", "chatting"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="只能撤回待处理或聊天中的申请"
            )

        # 获取当前时间
        current_time = get_utc_time()

        # 更新申请状态为 rejected（等同于撤回）
        application.status = "rejected"

        # 写入操作日志（用于审计区分撤回和拒绝）
        log_entry = models.NegotiationResponseLog(
            task_id=task_id,
            application_id=application_id,
            user_id=current_user.id,
            action="withdraw",
            responded_at=current_time
        )
        db.add(log_entry)

        # Flush so the status change is visible in the count query
        await db.flush()

        # 任务保持 open 状态，无需回退

        await db.commit()

        # 发送通知给发布者（可选，但建议发送）
        try:
            notification_content = {
                "type": "application_withdrawn",
                "task_id": task_id,
                "task_title": task.title,
                "application_id": application_id
            }
            
            # ⚠️ 直接使用文本内容，不存储 JSON
            content = f"有申请者撤回了对任务「{task.title}」的申请"
            content_en = f"An applicant has withdrawn their application for task「{task.title}」"
            
            new_notification = models.Notification(
                user_id=task.poster_id,
                type="application_withdrawn",
                title="有申请者撤回了申请",
                content=content,  # 直接使用文本，不存储 JSON
                title_en="Application Withdrawn",
                content_en=content_en,
                related_id=application_id,
                related_type="application_id",  # related_id 是 application_id
                created_at=current_time
            )
            db.add(new_notification)
            await db.commit()
            
            # 发送推送通知
            try:
                send_push_notification_async_safe(
                    async_db=db,
                    user_id=task.poster_id,
                    title=None,  # 从模板生成（会根据用户语言偏好）
                    body=None,  # 从模板生成（会根据用户语言偏好）
                    notification_type="application_withdrawn",
                    data={"task_id": task_id, "application_id": application_id},
                    template_vars={
                        "task_title": task.title,  # 原始标题，会在 send_push_notification 中根据用户语言从翻译表获取
                        "task_id": task_id  # 传递 task_id 以便获取翻译
                    }
                )
            except Exception as e:
                logger.warning(f"发送申请撤回推送通知失败: {e}")
                # 推送通知失败不影响主流程
        except Exception as e:
            logger.error(f"发送撤回申请通知失败: {e}")
            # 通知失败不影响主流程
        
        return {
            "application_id": application_id,
            "status": "rejected",
            "withdrawn_at": format_iso_utc(current_time) if current_time else None
        }
    
    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"撤回申请失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="撤回申请失败，请稍后重试"
        )


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/negotiate")
async def negotiate_application(
    task_id: int,
    application_id: int,
    request: NegotiateRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    再次议价
    发布者发起，生成一次性签名token
    """
    try:
        # 检查任务是否存在
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="任务不存在"
            )
        
        # 权限检查：必须是发布者
        if task.poster_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只有发布者可以发起再次议价"
            )
        
        # 检查申请是否存在且属于该任务
        application_query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id
            )
        )
        application_result = await db.execute(application_query)
        application = application_result.scalar_one_or_none()
        
        if not application:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="申请不存在"
            )

        # 申请必须处于可议价状态
        if application.status not in ("pending", "chatting"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"申请当前状态为 {application.status}，无法议价"
            )

        # 校验货币一致性
        if application.currency and task.currency:
            if application.currency != task.currency:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"货币不一致：申请使用 {application.currency}，任务使用 {task.currency}"
                )
        
        # ⚠️ 不在此处更新 application.negotiated_price
        # 只有当申请者通过 respond_negotiation 接受议价后才写入
        # 防止发布者提议后直接批准，绕过申请者同意

        # 生成一次性签名token
        import secrets
        import time
        
        # 生成两个token：accept 和 reject
        token_accept = secrets.token_urlsafe(32)
        token_reject = secrets.token_urlsafe(32)
        
        # 获取当前时间戳
        current_timestamp = int(time.time())
        expires_at = current_timestamp + 86400  # 24小时后过期
        
        # 生成nonce（防重放）
        nonce_accept = secrets.token_urlsafe(16)
        nonce_reject = secrets.token_urlsafe(16)
        
        # 存储token到Redis
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if redis_client:
            # Token payload
            token_data_accept = {
                "user_id": application.applicant_id,
                "action": "accept",
                "application_id": application_id,
                "task_id": task_id,
                "proposed_price": str(request.negotiated_price),
                "nonce": nonce_accept,
                "exp": expires_at,
                "expires_at": format_iso_utc(datetime.fromtimestamp(expires_at, tz=timezone.utc))
            }

            token_data_reject = {
                "user_id": application.applicant_id,
                "action": "reject",
                "application_id": application_id,
                "task_id": task_id,
                "proposed_price": str(request.negotiated_price),
                "nonce": nonce_reject,
                "exp": expires_at,
                "expires_at": format_iso_utc(datetime.fromtimestamp(expires_at, tz=timezone.utc))
            }

            # 存储到Redis，24小时过期
            redis_client.setex(
                f"negotiation_token:{token_accept}",
                86400,  # 24小时
                json.dumps(token_data_accept)
            )

            redis_client.setex(
                f"negotiation_token:{token_reject}",
                86400,  # 24小时
                json.dumps(token_data_reject)
            )
        else:
            logger.warning("Redis不可用，无法存储token")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="服务暂时不可用"
            )

        # 创建系统通知
        current_time = get_utc_time()
        
        # ⚠️ 直接使用文本内容，不存储 JSON
        # token 将通过 API 端点通过 notification_id 获取
        content_parts = [f"任务「{task.title}」的发布者提出议价"]
        if request.message:
            content_parts.append(f"留言：{request.message}")
        content_parts.append(f"议价金额：£{float(request.negotiated_price):.2f} {task.currency or 'GBP'}")
        content = "\n".join(content_parts)

        # 英文版本
        content_parts_en = [f"The publisher of task「{task.title}」proposed a negotiation"]
        if request.message:
            content_parts_en.append(f"Message: {request.message}")
        content_parts_en.append(f"Negotiated price: £{float(request.negotiated_price):.2f} {task.currency or 'GBP'}")
        content_en = "\n".join(content_parts_en)

        new_notification = models.Notification(
            user_id=application.applicant_id,
            type="negotiation_offer",
            title="新的议价提议",
            title_en="New Price Offer",
            content=content,  # 直接使用文本，不存储 JSON
            content_en=content_en,
            related_id=application_id,
            related_type="application_id",  # related_id 是 application_id
            created_at=current_time
        )
        db.add(new_notification)
        await db.flush()
        
        # 获取通知ID后，更新token payload添加notification_id，并存储token映射
        notification_id = new_notification.id
        
        # 更新Redis中的token，添加notification_id
        if redis_client:
            token_data_accept["notification_id"] = notification_id
            token_data_reject["notification_id"] = notification_id
            
            # 重新存储到Redis（覆盖之前的token）
            redis_client.setex(
                f"negotiation_token:{token_accept}",
                86400,  # 24小时
                json.dumps(token_data_accept)
            )

            redis_client.setex(
                f"negotiation_token:{token_reject}",
                86400,  # 24小时
                json.dumps(token_data_reject)
            )
            
            # ⚠️ 额外存储 notification_id -> tokens 映射，方便前端通过 notification_id 获取 token
            # 优化：在存储时也保存过期时间，方便API返回
            expires_at_iso = format_iso_utc(datetime.fromtimestamp(expires_at, tz=timezone.utc))
            redis_client.setex(
                f"negotiation_tokens_by_notification:{notification_id}",
                86400,  # 24小时
                json.dumps({
                    "token_accept": token_accept,
                    "token_reject": token_reject,
                    "task_id": task_id,
                    "application_id": application_id,
                    "expires_at": expires_at_iso  # 优化：保存过期时间
                })
            )

        await db.commit()
        
        # 发送推送通知
        try:
            send_push_notification_async_safe(
                async_db=db,
                user_id=application.applicant_id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="negotiation_offer",
                data={
                    "task_id": task_id,
                    "application_id": application_id
                },
                template_vars={
                    "task_title": task.title,  # 原始标题，会在 send_push_notification 中根据用户语言从翻译表获取
                    "task_id": task_id,  # 传递 task_id 以便获取翻译
                    "negotiated_price": float(request.negotiated_price)
                }
            )
        except Exception as e:
            logger.warning(f"发送议价提议推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
        return {
            "message": "议价提议已发送",
            "application_id": application_id,
            "task_id": task_id,
            "notification_id": notification_id
        }
    
    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"发起再次议价失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="发起再次议价失败，请稍后重试"
        )


class TakerCounterOfferRequest(BaseModel):
    price: float = Field(..., ge=0.01, le=50000.0, description="反报价金额（英镑）")


@task_chat_router.post("/tasks/{task_id}/taker-counter-offer")
async def taker_counter_offer(
    task_id: int,
    request: TakerCounterOfferRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    指定任务的接单方提交反报价。
    仅适用于 status='pending_acceptance' 的任务。
    """
    try:
        # 1. 查询任务（加行锁防止并发冲突）
        result = await db.execute(
            select(models.Task).where(models.Task.id == task_id).with_for_update()
        )
        task = result.scalar_one_or_none()

        # 2. 404 如果任务不存在
        if task is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="任务不存在")

        # 3. 400 如果任务状态不是 pending_acceptance
        if task.status != "pending_acceptance":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="只有 pending_acceptance 状态的任务才能接受反报价"
            )

        # 4. 403 如果是发布方，或非指定接单方
        if task.poster_id == current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="任务发布方不能提交反报价"
            )
        if task.taker_id and task.taker_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只有指定接单方才能提交反报价"
            )

        # 5. 400 如果已有 pending 反报价
        if task.counter_offer_status == "pending":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="已有待处理的反报价，请等待发布方响应"
            )

        # 6. 存储反报价信息
        from decimal import Decimal
        task.counter_offer_price = Decimal(str(request.price))
        task.counter_offer_status = "pending"
        task.counter_offer_user_id = current_user.id

        # 7. 构建通知对象并与任务更新一并提交（保证原子性）
        current_time = get_utc_time()
        content = f"接单方对任务「{task.title}」提交了反报价：£{request.price:.2f}"
        content_en = f"The taker submitted a counter offer for task「{task.title}」: £{request.price:.2f}"
        new_notification = models.Notification(
            user_id=task.poster_id,
            type="task_counter_offer",
            title="接单方提交了反报价",
            title_en="Taker submitted a counter offer",
            content=content,
            content_en=content_en,
            related_id=task_id,
            related_type="task_id",
            created_at=current_time,
        )
        db.add(new_notification)
        await db.commit()

        # 发送推送通知
        try:
            send_push_notification_async_safe(
                async_db=db,
                user_id=task.poster_id,
                title=None,
                body=None,
                notification_type="task_counter_offer",
                data={"task_id": task_id},
                template_vars={
                    "task_title": task.title,
                    "task_id": task_id,
                    "counter_offer_price": request.price,
                },
            )
        except Exception as e:
            logger.warning(f"发送反报价推送通知失败: {e}")

        # 9. 返回结果
        return {
            "message": "反报价已提交",
            "task_id": task_id,
            "counter_offer_price": float(task.counter_offer_price),
            "counter_offer_status": task.counter_offer_status,
        }

    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"提交反报价失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="提交反报价失败，请稍后重试"
        )


class RespondTakerCounterOfferRequest(BaseModel):
    action: str = Field(..., description="'accept' 或 'reject'")


@task_chat_router.post("/tasks/{task_id}/respond-taker-counter-offer")
async def respond_taker_counter_offer(
    task_id: int,
    request: RespondTakerCounterOfferRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    发布方响应接单方提交的反报价（accept 或 reject）。
    仅当 counter_offer_status == 'pending' 时可操作。
    """
    try:
        # 1. 校验 action 参数
        if request.action not in ("accept", "reject"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="action 必须为 'accept' 或 'reject'"
            )

        # 2. 查询任务（加行锁防止并发冲突）
        result = await db.execute(
            select(models.Task).where(models.Task.id == task_id).with_for_update()
        )
        task = result.scalar_one_or_none()

        # 3. 404 如果任务不存在
        if task is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="任务不存在")

        # 4. 403 如果不是发布方
        if task.poster_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只有任务发布方才能响应反报价"
            )

        # 5. 400 如果没有待处理的反报价
        if task.counter_offer_status != "pending" or task.counter_offer_price is None or task.counter_offer_user_id is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="当前没有待处理的反报价"
            )

        # 6. 存储接单方 ID，供后续通知使用
        taker_id = task.counter_offer_user_id

        current_time = get_utc_time()

        if request.action == "accept":
            # 7a. 接受反报价
            task.base_reward = task.counter_offer_price
            task.agreed_reward = task.counter_offer_price
            task.taker_id = taker_id
            task.status = "in_progress"
            task.accepted_at = current_time
            task.counter_offer_status = "accepted"

            content = f"发布方已接受您对任务「{task.title}」的反报价：£{float(task.agreed_reward):.2f}"
            content_en = f"The poster accepted your counter offer for task「{task.title}」: £{float(task.agreed_reward):.2f}"
            new_notification = models.Notification(
                user_id=taker_id,
                type="task_counter_offer_accepted",
                title="反报价已被接受",
                title_en="Counter offer accepted",
                content=content,
                content_en=content_en,
                related_id=task_id,
                related_type="task_id",
                created_at=current_time,
            )
            db.add(new_notification)
            await db.commit()

            # 发送推送通知
            try:
                send_push_notification_async_safe(
                    async_db=db,
                    user_id=taker_id,
                    title=None,
                    body=None,
                    notification_type="task_counter_offer_accepted",
                    data={"task_id": task_id},
                    template_vars={
                        "task_title": task.title,
                        "task_id": task_id,
                        "agreed_price": float(task.agreed_reward),
                    },
                )
            except Exception as e:
                logger.warning(f"发送反报价接受推送通知失败: {e}")

            return {
                "message": "已接受反报价，任务进入进行中",
                "task_status": task.status,
                "agreed_price": float(task.agreed_reward),
            }

        else:
            # 7b. 拒绝反报价
            task.counter_offer_status = "rejected"
            task.counter_offer_price = None
            task.counter_offer_user_id = None

            content = f"发布方已拒绝您对任务「{task.title}」的反报价"
            content_en = f"The poster rejected your counter offer for task「{task.title}」"
            new_notification = models.Notification(
                user_id=taker_id,
                type="task_counter_offer_rejected",
                title="反报价已被拒绝",
                title_en="Counter offer rejected",
                content=content,
                content_en=content_en,
                related_id=task_id,
                related_type="task_id",
                created_at=current_time,
            )
            db.add(new_notification)
            await db.commit()

            # 发送推送通知
            try:
                send_push_notification_async_safe(
                    async_db=db,
                    user_id=taker_id,
                    title=None,
                    body=None,
                    notification_type="task_counter_offer_rejected",
                    data={"task_id": task_id},
                    template_vars={
                        "task_title": task.title,
                        "task_id": task_id,
                    },
                )
            except Exception as e:
                logger.warning(f"发送反报价拒绝推送通知失败: {e}")

            return {
                "message": "已拒绝反报价，任务保持待接受状态",
                "task_status": task.status,
            }

    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"响应反报价失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="响应反报价失败，请稍后重试"
        )


@task_chat_router.get("/notifications/{notification_id}/negotiation-tokens")
async def get_negotiation_tokens(
    notification_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    通过 notification_id 获取议价 token（用于前端获取 token 而不需要解析 JSON）
    """
    try:
        # 验证通知是否存在且属于当前用户
        notification_query = select(models.Notification).where(
            and_(
                models.Notification.id == notification_id,
                models.Notification.user_id == current_user.id,
                models.Notification.type == "negotiation_offer"
            )
        )
        notification_result = await db.execute(notification_query)
        notification = notification_result.scalar_one_or_none()
        
        if not notification:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="通知不存在或无权限访问"
            )
        
        # 从 Redis 获取 token
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if not redis_client:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="服务暂时不可用"
            )
        
        token_key = f"negotiation_tokens_by_notification:{notification_id}"
        token_data_str = redis_client.get(token_key)
        
        if not token_data_str:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Token已过期或不存在"
            )
        
        if isinstance(token_data_str, bytes):
            token_data_str = token_data_str.decode('utf-8')
        
        try:
            token_data = json.loads(token_data_str)
        except json.JSONDecodeError:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Token数据格式错误"
            )
        
        # 优化：从token数据中获取过期时间（如果存在）
        expires_at = None
        if token_data.get("token_accept"):
            # 尝试从accept token的Redis数据中获取过期时间
            accept_token_key = f"negotiation_token:{token_data.get('token_accept')}"
            accept_token_data_str = redis_client.get(accept_token_key)
            if accept_token_data_str:
                if isinstance(accept_token_data_str, bytes):
                    accept_token_data_str = accept_token_data_str.decode('utf-8')
                try:
                    accept_token_data = json.loads(accept_token_data_str)
                    expires_at = accept_token_data.get("expires_at")
                except Exception:
                    pass
        
        # 如果没有从token中获取到，基于创建时间+24小时计算
        if not expires_at:
            notification_created = notification.created_at
            if notification_created:
                from datetime import timedelta
                expires_at_dt = notification_created + timedelta(seconds=86400)  # 24小时
                expires_at = format_iso_utc(expires_at_dt)
        
        # 优化：获取任务状态，如果任务已进入进行中或更后面的状态，议价应该显示为已过期
        task_status = None
        task_id = token_data.get("task_id")
        if task_id:
            try:
                task_query = select(models.Task).where(models.Task.id == task_id)
                task_result = await db.execute(task_query)
                task = task_result.scalar_one_or_none()
                if task:
                    task_status = task.status
            except Exception as e:
                logger.warning(f"获取任务状态失败: {e}")
        
        return {
            "token_accept": token_data.get("token_accept"),
            "token_reject": token_data.get("token_reject"),
            "task_id": task_id,
            "application_id": token_data.get("application_id"),
            "expires_at": expires_at,  # 优化：返回真实过期时间
            "task_status": task_status  # 优化：返回任务状态，用于判断是否已过期
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取议价token失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="获取议价信息失败，请稍后重试"
        )


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/respond-negotiation")
async def respond_negotiation(
    task_id: int,
    application_id: int,
    request: RespondNegotiationRequest,
    http_request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    处理再次议价（同意/拒绝）
    验证token，防重放，支持幂等性
    """
    try:
        # 验证action
        if request.action not in ["accept", "reject"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="action必须是 'accept' 或 'reject'"
            )
        
        # 从Redis获取并删除token（原子操作）
        from app.redis_cache import get_redis_client
        redis_client = get_redis_client()
        
        if not redis_client:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="服务暂时不可用"
            )
        
        # 使用GETDEL原子操作（Redis 6.2+）
        # 如果Redis版本不支持GETDEL，使用Lua脚本
        token_key = f"negotiation_token:{request.token}"
        
        # 尝试使用GETDEL
        try:
            token_data_str = redis_client.getdel(token_key)
        except AttributeError:
            # Redis版本不支持GETDEL，使用Lua脚本
            lua_script = """
            local key = KEYS[1]
            local value = redis.call('GET', key)
            if value then
                redis.call('DEL', key)
            end
            return value
            """
            token_data_str = redis_client.eval(lua_script, 1, token_key)
        
        if not token_data_str:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Token无效或已使用"
            )
        
        # 解析token数据
        if isinstance(token_data_str, bytes):
            token_data_str = token_data_str.decode('utf-8')
        
        try:
            token_data = json.loads(token_data_str)
        except json.JSONDecodeError:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Token格式错误"
            )
        
        # 验证token
        import time
        current_timestamp = int(time.time())
        
        # 检查过期时间
        if token_data.get("exp", 0) < current_timestamp:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Token已过期"
            )
        
        # 验证用户ID
        if token_data.get("user_id") != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Token用户不匹配"
            )
        
        # 验证action
        if token_data.get("action") != request.action:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Token action不匹配"
            )
        
        # 验证task_id和application_id
        if token_data.get("task_id") != task_id or token_data.get("application_id") != application_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Token参数不匹配"
            )
        
        # 检查任务和申请是否存在
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="任务不存在"
            )
        
        application_query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id
            )
        )
        application_result = await db.execute(application_query)
        application = application_result.scalar_one_or_none()
        
        if not application:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="申请不存在"
            )
        
        # 获取当前时间
        current_time = get_utc_time()
        
        if request.action == "accept":
            # 接受议价：等同于接受申请，需要更新任务状态
            # 使用 SELECT FOR UPDATE 锁定任务行（防止并发）
            locked_task_query = select(models.Task).where(
                models.Task.id == task_id
            ).with_for_update()
            locked_task_result = await db.execute(locked_task_query)
            locked_task = locked_task_result.scalar_one_or_none()
            
            # 幂等性检查：如果申请已经是 approved，直接返回成功
            if application.status == "approved":
                return {
                    "message": "议价已被接受，任务已在进行中",
                    "application_id": application_id,
                    "task_id": task_id
                }
            
            # 检查任务是否还有名额
            if locked_task.taker_id is not None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="任务已被接受"
                )
            
            # ⚠️ 安全修复：接受议价需要支付，不能直接进入 in_progress
            # 更新任务状态为 pending_payment，等待支付完成
            locked_task.taker_id = application.applicant_id
            locked_task.status = "pending_payment"
            locked_task.is_paid = 0  # 明确标记为未支付
            locked_task.payment_expires_at = get_utc_time() + timedelta(hours=24)  # 支付过期时间（24小时）

            # 更新可靠度画像（任务分配）
            try:
                from app.services.reliability_calculator import on_task_assigned
                from app.database import SessionLocal
                sync_db = SessionLocal()
                try:
                    on_task_assigned(sync_db, application.applicant_id, locked_task.poster_id)
                    sync_db.commit()
                finally:
                    sync_db.close()
            except Exception as e:
                import logging
                logging.getLogger(__name__).warning(f"更新可靠度失败(task_assigned): {e}")

            # 从 token 数据中读取提议价格，写入 application.negotiated_price
            # （negotiate_application 不再提前覆写，只有接受时才写入）
            proposed_price = token_data.get("proposed_price")
            if proposed_price is not None:
                from decimal import Decimal
                application.negotiated_price = Decimal(str(proposed_price))
                locked_task.agreed_reward = application.negotiated_price
            elif application.negotiated_price is not None:
                # 兼容：申请者在申请时自己提出的议价（非发布者提议）
                locked_task.agreed_reward = application.negotiated_price

            # 计算任务金额
            task_amount = float(application.negotiated_price) if application.negotiated_price is not None else float(locked_task.base_reward) if locked_task.base_reward is not None else 0.0
            
            if task_amount <= 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="任务金额必须大于0，无法进行支付"
                )
            
            task_amount_pence = round(task_amount * 100)

            # 计算平台服务费（按任务来源/类型取费率）
            from app.utils.fee_calculator import calculate_application_fee_pence
            task_source = getattr(locked_task, "task_source", None)
            task_type = getattr(locked_task, "task_type", None)
            application_fee_pence = calculate_application_fee_pence(task_amount_pence, task_source, task_type)
            
            # 获取申请者信息（用于创建 PaymentIntent）
            applicant = await db.get(models.User, application.applicant_id)
            if not applicant:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="申请者不存在"
                )
            
            # 创建 Stripe Payment Intent
            import stripe
            import os

            try:
                pi_currency_3 = (getattr(locked_task, "currency", None) or "GBP").lower()
                pi_pm_types_3 = _payment_method_types_for_currency(pi_currency_3)
                from app.secure_auth import get_wechat_pay_payment_method_options
                payment_method_options = get_wechat_pay_payment_method_options(http_request) if "wechat_pay" in pi_pm_types_3 else {}
                create_pi_kw = {
                    "amount": task_amount_pence,
                    "currency": pi_currency_3,
                    "payment_method_types": pi_pm_types_3,
                    "description": f"任务 #{task_id}: {locked_task.title[:50] if locked_task.title else 'Task'} - 接受议价申请 #{application_id}",
                    "metadata": {
                        "task_id": str(task_id),
                        "task_title": locked_task.title[:200] if locked_task.title else "",
                        "poster_id": str(locked_task.poster_id),
                        "taker_id": str(application.applicant_id),
                        "taker_name": applicant.name if applicant else f"User {application.applicant_id}",
            
                        "application_fee": str(application_fee_pence),
                        "task_amount": str(task_amount_pence),
                        "task_amount_display": f"{task_amount:.2f}",
                        "platform": "Link²Ur",
                        "payment_type": "negotiation_accept",
                        "application_id": str(application_id),
                        "negotiated_price": str(application.negotiated_price) if application.negotiated_price else ""
                    },
                }
                if payment_method_options:
                    create_pi_kw["payment_method_options"] = payment_method_options
                payment_intent = stripe.PaymentIntent.create(**create_pi_kw)
                
                # 更新任务的 payment_intent_id
                locked_task.payment_intent_id = payment_intent.id
            except Exception as e:
                await db.rollback()
                logger.error(f"创建 PaymentIntent 失败: {e}", exc_info=True)
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="创建支付失败，请稍后重试"
                )
            
            # 更新申请状态
            application.status = "approved"
            
            # 自动拒绝所有其他待处理的申请
            other_applications_query = select(models.TaskApplication).where(
                and_(
                    models.TaskApplication.task_id == task_id,
                    models.TaskApplication.id != application_id,
                    models.TaskApplication.status == "pending"
                )
            )
            other_apps_result = await db.execute(other_applications_query)
            other_applications = other_apps_result.scalars().all()
            
            for other_app in other_applications:
                other_app.status = "rejected"
            
            # 获取notification_id（从token中）
            notification_id = token_data.get("notification_id")
            
            # 写入操作日志
            log_entry = models.NegotiationResponseLog(
                notification_id=notification_id,
                task_id=task_id,
                application_id=application_id,
                user_id=current_user.id,
                action="accept",
                negotiated_price=application.negotiated_price,
                responded_at=current_time
            )
            db.add(log_entry)
            
            # 提交事务（任务状态、PaymentIntent 都已更新）
            await db.commit()
            
            # 为支付方创建/获取 Customer + EphemeralKey（用于保存卡）
            customer_id = None
            ephemeral_key_secret = None
            try:
                from app.utils.stripe_utils import get_or_create_stripe_customer
                poster = await db.get(models.User, locked_task.poster_id)
                if poster:
                    customer_id = get_or_create_stripe_customer(poster)
                    # 保存 customer_id 到用户记录
                    if customer_id and (not poster.stripe_customer_id or poster.stripe_customer_id != customer_id):
                        await db.execute(
                            update(models.User)
                            .where(models.User.id == poster.id)
                            .values(stripe_customer_id=customer_id)
                        )

                    ephemeral_key = stripe.EphemeralKey.create(
                        customer=customer_id,
                        stripe_version="2025-01-27.acacia",
                    )
                    ephemeral_key_secret = ephemeral_key.secret
            except Exception as e:
                logger.warning(f"无法创建 Stripe Customer 或 Ephemeral Key: {e}")
                customer_id = None
                ephemeral_key_secret = None
            
            # 发送通知给发布者（包含支付提醒）
            try:
                # 获取支付过期时间信息
                payment_expires_info = ""
                if locked_task.payment_expires_at:
                    from app.utils.time_utils import format_iso_utc
                    expires_at_str = format_iso_utc(locked_task.payment_expires_at)
                    payment_expires_info = f"\n支付过期时间：{expires_at_str}\n请在24小时内完成支付，否则任务将自动取消。"
                
                # ⚠️ 直接使用文本内容，不存储 JSON
                content = f"申请者已接受您对任务「{locked_task.title}」的议价，请完成支付。{payment_expires_info}"
                
                new_notification = models.Notification(
                    user_id=task.poster_id,
                    type="application_accepted",
                    title="申请者已接受您的议价，请完成支付",
                    content=content,  # 直接使用文本，不存储 JSON
                    title_en="Application Accepted - Payment Required",
                    content_en=f"The applicant has accepted your negotiation offer for task「{task.title}」. Please complete the payment.",
                    related_id=str(task_id),  # 使用task_id而不是application_id，方便前端跳转
                    related_type="task_id",  # related_id 是 task_id
                    created_at=current_time
                )
                db.add(new_notification)
                
                # 发送推送通知
                try:
                    from app.push_notification_service import send_push_notification_async_safe
                    send_push_notification_async_safe(
                        async_db=db,
                        user_id=task.poster_id,
                        title="申请者已接受您的议价，请完成支付",
                        body=f"任务「{locked_task.title}」的议价已被接受，请尽快完成支付",
                        notification_type="application_accepted",
                        data={"task_id": task_id},
                        template_vars={
                            "task_title": locked_task.title,
                            "task_id": task_id
                        }
                    )
                except Exception as e:
                    logger.warning(f"发送接受议价推送通知失败: {e}")
                
                await db.commit()
            except Exception as e:
                logger.error(f"发送接受议价通知失败: {e}")
                # 通知失败不影响主流程
            
            # 返回支付信息
            return {
                "message": "议价已被接受，请完成支付",
                "application_id": application_id,
                "task_id": task_id,
                "task_status": "pending_payment",
                "payment_intent_id": payment_intent.id,
                "client_secret": payment_intent.client_secret,
                "amount": payment_intent.amount,
                "amount_display": f"{payment_intent.amount / 100:.2f}",
                "currency": payment_intent.currency.upper(),
                "customer_id": customer_id,
                "ephemeral_key_secret": ephemeral_key_secret,
            }
            
        else:  # reject
            # 拒绝议价：更新申请状态为rejected
            application.status = "rejected"
            
            # 获取notification_id（从token中）
            notification_id = token_data.get("notification_id")
            
            # 写入操作日志
            log_entry = models.NegotiationResponseLog(
                notification_id=notification_id,
                task_id=task_id,
                application_id=application_id,
                user_id=current_user.id,
                action="reject",
                responded_at=current_time
            )
            db.add(log_entry)
            
            # 发送通知给发布者
            try:
                content = f"申请者已拒绝您对任务「{task.title}」的议价提议。"
                content_en = f"The applicant has rejected your negotiation offer for task「{task.title}」."

                new_notification = models.Notification(
                    user_id=task.poster_id,
                    type="negotiation_rejected",
                    title="申请者已拒绝您的议价",
                    content=content,
                    title_en="Negotiation Rejected",
                    content_en=content_en,
                    related_id=application_id,
                    related_type="application_id",  # related_id 是 application_id
                    created_at=current_time
                )
                db.add(new_notification)
                # 注意：通知会在下面的 await db.commit() 中一起提交
                
                # 发送推送通知
                try:
                    send_push_notification_async_safe(
                        async_db=db,
                        user_id=task.poster_id,
                        title=None,  # 从模板生成（会根据用户语言偏好）
                        body=None,  # 从模板生成（会根据用户语言偏好）
                        notification_type="negotiation_rejected",
                        data={
                            "task_id": task_id,
                            "application_id": application_id
                        },
                        template_vars={
                            "task_title": task.title,  # 原始标题，会在 send_push_notification 中根据用户语言从翻译表获取
                            "task_id": task_id  # 传递 task_id 以便获取翻译
                        }
                    )
                except Exception as e:
                    logger.warning(f"发送议价拒绝推送通知失败: {e}")
                    # 推送通知失败不影响主流程
            except Exception as e:
                logger.error(f"发送拒绝议价通知失败: {e}")
                # 通知失败不影响主流程
        
        await db.commit()
        
        return {
            "message": f"议价已{request.action}",
            "application_id": application_id,
            "task_id": task_id
        }
    
    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"处理再次议价失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="处理再次议价失败，请稍后重试"
        )


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/send-message")
async def send_application_message(
    task_id: int,
    application_id: int,
    request: SendApplicationMessageRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    发布者向申请者发送留言（可包含议价）
    """
    try:
        # 检查任务是否存在
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="任务不存在"
            )
        
        # 权限检查：必须是发布者
        if task.poster_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只有发布者可以发送留言"
            )
        
        # 检查申请是否存在且属于该任务
        application_query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id
            )
        )
        application_result = await db.execute(application_query)
        application = application_result.scalar_one_or_none()
        
        if not application:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="申请不存在"
            )
        
        # ⚠️ 不在此处更新 application.negotiated_price
        # 只有当申请者通过 respond_negotiation 接受议价后才写入
        if request.negotiated_price is not None:
            # 校验货币一致性
            if application.currency and task.currency:
                if application.currency != task.currency:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"货币不一致：申请使用 {application.currency}，任务使用 {task.currency}"
                    )
        
        # 确定通知类型
        notification_type = "negotiation_offer" if request.negotiated_price is not None else "application_message"
        
        # 生成一次性签名token（如果包含议价）
        token_accept = None
        token_reject = None
        if request.negotiated_price is not None:
            import secrets
            import time
            
            token_accept = secrets.token_urlsafe(32)
            token_reject = secrets.token_urlsafe(32)
            
            current_timestamp = int(time.time())
            expires_at = current_timestamp + 86400  # 24小时后过期
            
            nonce_accept = secrets.token_urlsafe(16)
            nonce_reject = secrets.token_urlsafe(16)
            
            # 存储token到Redis
            from app.redis_cache import get_redis_client
            redis_client = get_redis_client()
            
            if redis_client:
                token_data_accept = {
                    "user_id": application.applicant_id,
                    "action": "accept",
                    "application_id": application_id,
                    "task_id": task_id,
                    "proposed_price": str(request.negotiated_price),
                    "nonce": nonce_accept,
                    "exp": expires_at,
                    "expires_at": format_iso_utc(datetime.fromtimestamp(expires_at, tz=timezone.utc))
                }

                token_data_reject = {
                    "user_id": application.applicant_id,
                    "action": "reject",
                    "application_id": application_id,
                    "task_id": task_id,
                    "proposed_price": str(request.negotiated_price),
                    "nonce": nonce_reject,
                    "exp": expires_at,
                    "expires_at": format_iso_utc(datetime.fromtimestamp(expires_at, tz=timezone.utc))
                }

                redis_client.setex(
                    f"negotiation_token:{token_accept}",
                    86400,
                    json.dumps(token_data_accept)
                )

                redis_client.setex(
                    f"negotiation_token:{token_reject}",
                    86400,
                    json.dumps(token_data_reject)
                )
            else:
                logger.warning("Redis不可用，无法存储token")
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="服务暂时不可用"
                )

        # 创建或更新系统通知
        current_time = get_utc_time()
        
        # ⚠️ 所有通知都使用文本格式，token 通过 notification_id 从 Redis 获取
        if notification_type == "negotiation_offer":
            # 议价通知使用文本格式
            content_parts = [f"任务「{task.title}」的发布者提出议价"]
            if request.message:
                content_parts.append(f"留言：{request.message}")
            content_parts.append(f"议价金额：£{float(request.negotiated_price):.2f} {task.currency or 'GBP'}")
            content = "\n".join(content_parts)
            
            # 英文版本
            content_parts_en = [f"The publisher of task「{task.title}」proposed a negotiation"]
            if request.message:
                content_parts_en.append(f"Message: {request.message}")
            content_parts_en.append(f"Negotiated price: £{float(request.negotiated_price):.2f} {task.currency or 'GBP'}")
            content_en = "\n".join(content_parts_en)
            title_en = "New Price Offer"
        else:
            # application_message 使用文本格式
            if request.message:
                content = f"任务「{task.title}」的发布者给您留言：{request.message}"
                content_en = f"The publisher of task「{task.title}」sent you a message: {request.message}"
            else:
                content = f"任务「{task.title}」的发布者给您留言"
                content_en = f"The publisher of task「{task.title}」sent you a message"
            title_en = "New Message"
        
        # 检查是否已存在相同的通知（基于唯一约束）
        existing_notification_query = select(models.Notification).where(
            and_(
                models.Notification.user_id == application.applicant_id,
                models.Notification.type == notification_type,
                models.Notification.related_id == application_id  # 保持为 application_id 以符合唯一约束
            )
        )
        existing_notification_result = await db.execute(existing_notification_query)
        existing_notification = existing_notification_result.scalar_one_or_none()
        
        if existing_notification:
            # 更新现有通知
            existing_notification.title = "新的留言" if notification_type == "application_message" else "新的议价提议"
            existing_notification.content = content
            if notification_type == "negotiation_offer":
                existing_notification.title_en = "New Price Offer"
            else:
                existing_notification.title_en = "New Message"
            existing_notification.content_en = content_en
            existing_notification.created_at = current_time
            existing_notification.read_at = None  # 重置已读状态
            existing_notification.is_read = 0  # 重置已读状态
            new_notification = existing_notification
            await db.flush()
        else:
            # 创建新通知
            # related_id 保持为 application_id 以符合唯一约束 (user_id, type, related_id)
            # task_id 通过 token 响应或通知内容获取
            new_notification = models.Notification(
                user_id=application.applicant_id,
                type=notification_type,
                title="新的留言" if notification_type == "application_message" else "新的议价提议",
                content=content,
                title_en=title_en,
                content_en=content_en,
                related_id=application_id,  # 保持为 application_id
                related_type="application_id",  # related_id 是 application_id
                created_at=current_time
            )
            db.add(new_notification)
            await db.flush()
        
        # 发送推送通知
        try:
            template_vars = {
                "task_title": task.title,  # 原始标题，会在 send_push_notification 中根据用户语言从翻译表获取
                "task_id": task_id,  # 传递 task_id 以便获取翻译
            }
            
            # 如果是议价通知，添加议价金额
            if notification_type == "negotiation_offer" and request.negotiated_price is not None:
                template_vars["negotiated_price"] = float(request.negotiated_price)
            elif notification_type == "application_message":
                template_vars["message"] = (request.message or "").strip() or None  # 空时传 None，由模板使用兜底文案
            
            send_push_notification_async_safe(
                async_db=db,
                user_id=application.applicant_id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type=notification_type,
                data={
                    "task_id": task_id,
                    "application_id": application_id,
                    "notification_id": new_notification.id
                },
                template_vars=template_vars
            )
        except Exception as e:
            logger.warning(f"发送申请留言/议价推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
        # 如果包含议价，更新token payload添加notification_id
        if request.negotiated_price is not None and token_accept:
            notification_id = new_notification.id
            from app.redis_cache import get_redis_client
            redis_client = get_redis_client()
            
            if redis_client:
                token_data_accept = json.loads(redis_client.get(f"negotiation_token:{token_accept}") or "{}")
                token_data_reject = json.loads(redis_client.get(f"negotiation_token:{token_reject}") or "{}")
                
                if token_data_accept:
                    token_data_accept["notification_id"] = notification_id
                    redis_client.setex(
                        f"negotiation_token:{token_accept}",
                        86400,
                        json.dumps(token_data_accept)
                    )

                if token_data_reject:
                    token_data_reject["notification_id"] = notification_id
                    redis_client.setex(
                        f"negotiation_token:{token_reject}",
                        86400,
                        json.dumps(token_data_reject)
                    )

                # ⚠️ 额外存储 notification_id -> tokens 映射，方便前端通过 notification_id 获取 token
                redis_client.setex(
                    f"negotiation_tokens_by_notification:{notification_id}",
                    86400,  # 24小时
                    json.dumps({
                        "token_accept": token_accept,
                        "token_reject": token_reject,
                        "task_id": task_id,
                        "application_id": application_id
                    })
                )
        
        await db.commit()
        
        return {
            "message": "留言已发送",
            "application_id": application_id,
            "task_id": task_id,
            "notification_id": new_notification.id,
            "has_negotiation": request.negotiated_price is not None
        }
    
    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"发送申请留言失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="发送留言失败，请稍后重试"
        )


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/reply-message")
async def reply_application_message(
    task_id: int,
    application_id: int,
    request: ReplyApplicationMessageRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    申请者回复发布者的留言（每次留言只能回复一次）
    """
    try:
        # 检查任务是否存在
        task_query = select(models.Task).where(models.Task.id == task_id)
        task_result = await db.execute(task_query)
        task = task_result.scalar_one_or_none()
        
        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="任务不存在"
            )
        
        # 检查申请是否存在且属于该任务
        application_query = select(models.TaskApplication).where(
            and_(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id
            )
        )
        application_result = await db.execute(application_query)
        application = application_result.scalar_one_or_none()
        
        if not application:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="申请不存在"
            )
        
        # 权限检查：必须是申请者本人
        if application.applicant_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="只有申请者可以回复留言"
            )
        
        # 检查原始通知是否存在
        notification_query = select(models.Notification).where(
            and_(
                models.Notification.id == request.notification_id,
                models.Notification.user_id == current_user.id,
                models.Notification.related_id == application_id
            )
        )
        notification_result = await db.execute(notification_query)
        original_notification = notification_result.scalar_one_or_none()
        
        if not original_notification:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="原始通知不存在"
            )
        
        # 检查是否已经回复过（通过查找是否有回复通知）
        # related_id存储的是原始通知ID，user_id是接收回复的用户（发布者）
        reply_query = select(func.count(models.Notification.id)).where(
            and_(
                models.Notification.user_id == task.poster_id,
                models.Notification.type == "application_message_reply",
                models.Notification.related_id == request.notification_id
            )
        )
        reply_result = await db.execute(reply_query)
        reply_count = reply_result.scalar() or 0
        
        if reply_count > 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="您已经回复过这条留言，每次留言只能回复一次"
            )
        
        # 创建回复通知给发布者
        current_time = get_utc_time()
        
        # ⚠️ 直接使用文本内容，不存储 JSON
        content = f"申请者回复了您对任务「{task.title}」的留言：{request.message}"
        
        content_en = f"The applicant has replied to your message for task「{task.title}」: {request.message}"

        reply_notification = models.Notification(
            user_id=task.poster_id,
            type="application_message_reply",
            title="申请者回复了您的留言",
            title_en="Applicant Replied to Your Message",
            content=content,  # 直接使用文本，不存储 JSON
            content_en=content_en,
            related_id=request.notification_id,  # 关联到原始通知
            related_type=None,  # 关联到通知ID，不是 task_id 或 application_id
            created_at=current_time
        )
        db.add(reply_notification)
        
        await db.commit()
        
        # 发送推送通知
        try:
            send_push_notification_async_safe(
                async_db=db,
                user_id=task.poster_id,
                title=None,  # 从模板生成（会根据用户语言偏好）
                body=None,  # 从模板生成（会根据用户语言偏好）
                notification_type="application_message_reply",
                data={
                    "task_id": task_id,
                    "application_id": application_id,
                    "notification_id": request.notification_id
                },
                template_vars={
                    "task_title": task.title,  # 原始标题，会在 send_push_notification 中根据用户语言从翻译表获取
                    "task_id": task_id,  # 传递 task_id 以便获取翻译
                    "message": request.message
                }
            )
        except Exception as e:
            logger.warning(f"发送申请留言回复推送通知失败: {e}")
            # 推送通知失败不影响主流程
        
        return {
            "message": "回复已发送",
            "application_id": application_id,
            "task_id": task_id,
            "notification_id": reply_notification.id
        }
    
    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"回复申请留言失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="回复留言失败，请稍后重试"
        )


# ============================================================
# 发布者公开回复申请 (每个申请只能回复一次)
# ============================================================

@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/public-reply")
async def public_reply_to_application(
    task_id: int,
    application_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """发布者对申请的公开回复（每个申请只能回复一次）"""
    try:
        body = await request.json()
        message = body.get("message", "").strip()
        if not message:
            raise HTTPException(status_code=400, detail="Reply message is required")
        if len(message) > 500:
            raise HTTPException(status_code=400, detail="Reply message must be 500 characters or less")

        # Verify task exists and caller is poster
        task_result = await db.execute(
            select(models.Task).where(models.Task.id == task_id)
        )
        task = task_result.scalar_one_or_none()
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        if str(task.poster_id) != str(current_user.id):
            raise HTTPException(status_code=403, detail="Only the task poster can reply")

        # Verify application exists and belongs to this task
        app_result = await db.execute(
            select(models.TaskApplication).where(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id,
            )
        )
        application = app_result.scalar_one_or_none()
        if not application:
            raise HTTPException(status_code=404, detail="Application not found")

        # Check if already replied
        if application.poster_reply is not None:
            raise HTTPException(status_code=409, detail="Already replied to this application")

        # Set reply
        application.poster_reply = message
        application.poster_reply_at = get_utc_time()
        await db.commit()

        # Send notification to applicant
        try:
            notification_content = json.dumps({
                "task_id": task_id,
                "task_title": task.title if hasattr(task, 'title') else None,
                "reply_message": message[:200],
                "poster_name": current_user.name if hasattr(current_user, 'name') else None,
            })
            notification = models.Notification(
                user_id=str(application.applicant_id),
                type="public_reply",
                title="发布者回复了你的申请",
                title_en="The poster replied to your application",
                content=notification_content,
                related_id=task_id,
                related_type="task_id",
            )
            db.add(notification)
            await db.commit()
        except Exception as e:
            logger.warning(f"Failed to create notification for public reply: {e}")

        return {
            "id": application.id,
            "poster_reply": application.poster_reply,
            "poster_reply_at": format_iso_utc(application.poster_reply_at) if application.poster_reply_at else None,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in public reply for task {task_id}, app {application_id}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to submit reply: {str(e)}")


# ═══════════════════════════════════════════════════════════════════════════════
# 任务咨询 (Task Consultation) 端点
# ═══════════════════════════════════════════════════════════════════════════════


@task_chat_router.post("/tasks/{task_id}/consult")
async def create_task_consultation(
    task_id: int,
    request: Request,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """创建任务咨询 — 创建独立占位任务 + application，使咨询出现在消息列表中"""
    try:
        # 1. 验证原始任务存在且允许咨询
        task_result = await db.execute(
            select(models.Task).where(models.Task.id == task_id)
        )
        task = task_result.scalar_one_or_none()
        if not task:
            raise_http_error_with_code("任务不存在", 404, error_codes.TASK_NOT_FOUND)
        if task.status not in ("open", "chatting", "pending_acceptance"):
            raise_http_error_with_code(
                "任务当前状态不允许咨询", 400, error_codes.INVALID_STATUS_TRANSITION
            )

        # 2. 不能咨询自己发布的任务
        if str(task.poster_id) == str(current_user.id):
            raise_http_error_with_code(
                "不能咨询自己发布的任务", 400, error_codes.CANNOT_CONSULT_SELF
            )

        # 3. 查找是否已有此用户对该原始任务的咨询占位任务
        existing_placeholder_result = await db.execute(
            select(models.Task.id).where(
                models.Task.task_source == "task_consultation",
                models.Task.poster_id == current_user.id,
                models.Task.taker_id == task.poster_id,
                models.Task.description == f"original_task_id:{task_id}",
            )
        )
        placeholder_ids = [row[0] for row in existing_placeholder_result.fetchall()]

        existing_app = None
        existing_placeholder_id = None
        if placeholder_ids:
            app_result = await db.execute(
                select(models.TaskApplication).where(
                    models.TaskApplication.task_id.in_(placeholder_ids),
                    models.TaskApplication.applicant_id == current_user.id,
                )
            )
            existing_app = app_result.scalar_one_or_none()
            if existing_app:
                existing_placeholder_id = existing_app.task_id

        if existing_app:
            if existing_app.status in ("consulting", "negotiating", "price_agreed"):
                return {
                    "application_id": existing_app.id,
                    "task_id": existing_placeholder_id,
                    "original_task_id": task_id,
                    "status": existing_app.status,
                    "created_at": format_iso_utc(existing_app.created_at) if existing_app.created_at else None,
                    "is_existing": True,
                }
            elif existing_app.status == "cancelled":
                # 4. 重新打开已取消的咨询
                existing_app.status = "consulting"
                existing_app.negotiated_price = None
                existing_app.message = None

                # 重新打开占位任务（如果已关闭）
                placeholder_result = await db.execute(
                    select(models.Task).where(models.Task.id == existing_placeholder_id)
                )
                placeholder_task = placeholder_result.scalar_one_or_none()
                if placeholder_task and placeholder_task.status in ("closed", "cancelled"):
                    placeholder_task.status = "consulting"

                # 发送系统消息
                task_title = task.title or ""
                user_name = current_user.name if hasattr(current_user, "name") else "用户"
                content_zh = f"{user_name} 想咨询您的任务「{task_title}」"
                content_en = f"{user_name} wants to consult about your task \"{task_title}\""
                current_time = get_utc_time()
                system_message = models.Message(
                    sender_id=None,
                    receiver_id=None,
                    content=content_zh,
                    task_id=existing_placeholder_id,
                    application_id=existing_app.id,
                    message_type="system",
                    conversation_type="task",
                    meta=json.dumps({"system_action": "consultation_started", "content_en": content_en}),
                    created_at=current_time,
                )
                db.add(system_message)
                await db.commit()

                return {
                    "application_id": existing_app.id,
                    "task_id": existing_placeholder_id,
                    "original_task_id": task_id,
                    "status": "consulting",
                    "created_at": format_iso_utc(existing_app.created_at) if existing_app.created_at else None,
                    "is_existing": False,
                }
            else:
                raise HTTPException(status_code=400, detail="您已有该任务的申请")

        # 5. 创建占位任务
        current_time = get_utc_time()
        task_title = task.title or ""
        task_title_zh = getattr(task, "title_zh", None) or task_title
        task_title_en = getattr(task, "title_en", None) or task_title

        consulting_task = models.Task(
            title=f"咨询: {task_title}",
            title_zh=f"咨询: {task_title_zh}",
            title_en=f"Consultation: {task_title_en}",
            description=f"original_task_id:{task_id}",
            reward=task.base_reward or 0,
            base_reward=task.base_reward or 0,
            reward_to_be_quoted=getattr(task, "reward_to_be_quoted", False),
            currency=task.currency or "GBP",
            location=task.location or "",
            task_type=task.task_type or "other",
            task_source="task_consultation",
            poster_id=current_user.id,
            taker_id=task.poster_id,
            status="consulting",
            task_level=getattr(task, "task_level", "normal"),
        )
        db.add(consulting_task)
        await db.flush()  # 获取 consulting_task.id

        # 6. 创建 TaskApplication 指向占位任务
        new_application = models.TaskApplication(
            task_id=consulting_task.id,
            applicant_id=current_user.id,
            status="consulting",
            currency=task.currency or "GBP",
            created_at=current_time,
        )
        db.add(new_application)
        await db.flush()  # 获取 new_application.id

        # 7. 发送系统消息
        user_name = current_user.name if hasattr(current_user, "name") else "用户"
        content_zh = f"{user_name} 想咨询您的任务「{task_title}」"
        content_en = f"{user_name} wants to consult about your task \"{task_title}\""
        system_message = models.Message(
            sender_id=None,
            receiver_id=None,
            content=content_zh,
            task_id=consulting_task.id,
            application_id=new_application.id,
            message_type="system",
            conversation_type="task",
            meta=json.dumps({"system_action": "consultation_started", "content_en": content_en}),
            created_at=current_time,
        )
        db.add(system_message)

        # 通知原任务发布者
        try:
            from app import async_crud
            await async_crud.async_notification_crud.create_notification(
                db, str(task.poster_id), "task_consultation_received",
                "新任务咨询",
                f'{user_name} 想咨询您的任务「{task_title}」',
                related_id=str(consulting_task.id),
                title_en="New Task Consultation",
                content_en=f'{user_name} wants to consult about your task "{task_title}"',
                related_type="task_id",
            )
        except Exception as e:
            logger.warning(f"Failed to notify task poster about consultation: {e}")

        await db.commit()

        # 8. 返回结果
        return {
            "application_id": new_application.id,
            "task_id": consulting_task.id,
            "original_task_id": task_id,
            "status": new_application.status,
            "created_at": format_iso_utc(new_application.created_at) if new_application.created_at else None,
            "is_existing": False,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating consultation for task {task_id}: {e}")
        raise HTTPException(status_code=500, detail=f"创建咨询失败: {str(e)}")


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/consult-negotiate")
async def consult_negotiate(
    task_id: int,
    application_id: int,
    body: schemas.NegotiateRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """用户（申请者）发起议价"""
    try:
        from decimal import Decimal

        # 行锁查询申请
        app_result = await db.execute(
            select(models.TaskApplication)
            .where(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id,
            )
            .with_for_update()
        )
        application = app_result.scalar_one_or_none()
        if not application:
            raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)

        # 验证是申请者
        if str(application.applicant_id) != str(current_user.id):
            raise HTTPException(status_code=403, detail="只有申请者可以发起议价")

        # 验证状态
        if application.status not in ("consulting", "negotiating"):
            raise_http_error_with_code(
                f"当前状态 {application.status} 不允许议价",
                400,
                error_codes.INVALID_STATUS_TRANSITION,
            )

        # 获取任务信息（通知用）
        task_result = await db.execute(
            select(models.Task).where(models.Task.id == task_id)
        )
        task = task_result.scalar_one_or_none()
        if not task:
            raise_http_error_with_code("任务不存在", 404, error_codes.TASK_NOT_FOUND)

        # 更新状态和价格
        proposed_price = body.proposed_price
        application.status = "negotiating"
        application.negotiated_price = Decimal(str(proposed_price))

        # 创建议价消息
        current_time = get_utc_time()
        currency = application.currency or task.currency or "GBP"
        meta_dict = {
            "price": float(proposed_price),
            "currency": currency,
            "action": "negotiate",
        }
        negotiate_receiver_id = str(task.taker_id) if task.taker_id and current_user.id == task.poster_id else str(task.poster_id)
        negotiate_message = models.Message(
            sender_id=current_user.id,
            receiver_id=negotiate_receiver_id,
            content=f"提出报价: {currency} {float(proposed_price):.2f}",
            task_id=task_id,
            message_type="negotiation",
            conversation_type="task",
            application_id=application_id,
            meta=json.dumps(meta_dict),
            created_at=current_time,
        )
        db.add(negotiate_message)
        await db.commit()

        # 通知对方
        try:
            from app import async_crud
            user_name = current_user.name if hasattr(current_user, "name") else "用户"
            await async_crud.async_notification_crud.create_notification(
                db, negotiate_receiver_id, "consultation_update",
                "收到新报价", f'{user_name} 对任务「{task.title}」提出了报价 {currency} {float(proposed_price):.2f}',
                related_id=str(task_id), title_en="New Price Proposal",
                content_en=f'{user_name} proposed {currency} {float(proposed_price):.2f} for task "{task.title}"',
                related_type="task_id",
            )
        except Exception as e:
            logger.warning(f"Failed to create notification for consult-negotiate: {e}")

        return {
            "message": "议价已提交",
            "status": application.status,
            "application_id": application.id,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in consult-negotiate for task {task_id}, app {application_id}: {e}")
        raise HTTPException(status_code=500, detail=f"议价失败: {str(e)}")


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/consult-quote")
async def consult_quote(
    task_id: int,
    application_id: int,
    body: schemas.QuoteRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """发布者报价"""
    try:
        from decimal import Decimal

        # 验证报价权限
        task_result = await db.execute(
            select(models.Task).where(models.Task.id == task_id)
        )
        task = task_result.scalar_one_or_none()
        if not task:
            raise_http_error_with_code("任务不存在", 404, error_codes.TASK_NOT_FOUND)
        # 咨询类任务：卖家/服务者(taker)报价；普通任务：发布者(poster)报价
        if task.status == "consulting" or getattr(task, "task_source", "") == "flea_market_consultation":
            if str(task.taker_id) != str(current_user.id):
                raise HTTPException(status_code=403, detail="只有卖家/服务者可以报价")
        else:
            if str(task.poster_id) != str(current_user.id):
                raise HTTPException(status_code=403, detail="只有发布者可以报价")

        # 行锁查询申请
        app_result = await db.execute(
            select(models.TaskApplication)
            .where(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id,
            )
            .with_for_update()
        )
        application = app_result.scalar_one_or_none()
        if not application:
            raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)

        if application.status not in ("consulting", "negotiating"):
            raise_http_error_with_code(
                f"当前状态 {application.status} 不允许报价",
                400,
                error_codes.INVALID_STATUS_TRANSITION,
            )

        # 更新状态和价格
        quoted_price = body.quoted_price
        application.status = "negotiating"
        application.negotiated_price = Decimal(str(quoted_price))

        # 创建报价消息
        current_time = get_utc_time()
        currency = application.currency or task.currency or "GBP"
        meta_dict = {
            "price": float(quoted_price),
            "currency": currency,
            "message": body.message or "",
            "action": "quote",
        }
        quote_message = models.Message(
            sender_id=current_user.id,
            receiver_id=str(application.applicant_id),
            content=f"发布者报价: {currency} {float(quoted_price):.2f}" + (f" — {body.message}" if body.message else ""),
            task_id=task_id,
            message_type="quote",
            conversation_type="task",
            application_id=application_id,
            meta=json.dumps(meta_dict),
            created_at=current_time,
        )
        db.add(quote_message)
        await db.commit()

        # 通知申请者
        try:
            from app import async_crud
            poster_name = current_user.name if hasattr(current_user, "name") else "发布者"
            await async_crud.async_notification_crud.create_notification(
                db, str(application.applicant_id), "consultation_update",
                "收到报价", f'{poster_name} 对任务「{task.title}」报价 {currency} {float(quoted_price):.2f}',
                related_id=str(task_id), title_en="New Quote",
                content_en=f'{poster_name} quoted {currency} {float(quoted_price):.2f} for task "{task.title}"',
                related_type="task_id",
            )
        except Exception as e:
            logger.warning(f"Failed to create notification for consult-quote: {e}")

        return {
            "message": "报价已提交",
            "status": application.status,
            "application_id": application.id,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in consult-quote for task {task_id}, app {application_id}: {e}")
        raise HTTPException(status_code=500, detail=f"报价失败: {str(e)}")


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/consult-respond")
async def consult_respond(
    task_id: int,
    application_id: int,
    body: schemas.NegotiateResponseRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """双方回应议价：accept / reject / counter"""
    try:
        from decimal import Decimal

        # 获取任务
        task_result = await db.execute(
            select(models.Task).where(models.Task.id == task_id)
        )
        task = task_result.scalar_one_or_none()
        if not task:
            raise_http_error_with_code("任务不存在", 404, error_codes.TASK_NOT_FOUND)

        # 行锁查询申请
        app_result = await db.execute(
            select(models.TaskApplication)
            .where(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id,
            )
            .with_for_update()
        )
        application = app_result.scalar_one_or_none()
        if not application:
            raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)

        # 验证身份：双方均可回应
        is_poster = str(task.poster_id) == str(current_user.id)
        is_taker = str(task.taker_id) == str(current_user.id) if task.taker_id else False
        is_applicant = str(application.applicant_id) == str(current_user.id)
        if not is_poster and not is_taker and not is_applicant:
            raise HTTPException(status_code=403, detail="无权操作此申请")

        # 状态必须为 negotiating
        if application.status != "negotiating":
            raise_http_error_with_code(
                f"当前状态 {application.status} 不允许回应",
                400,
                error_codes.INVALID_STATUS_TRANSITION,
            )

        action = body.action
        currency = application.currency or task.currency or "GBP"
        current_time = get_utc_time()
        if is_applicant:
            other_party_id = str(task.taker_id) if task.taker_id else str(task.poster_id)
        else:
            other_party_id = str(application.applicant_id)
        user_name = current_user.name if hasattr(current_user, "name") else "用户"

        if action == "accept":
            application.status = "price_agreed"
            message_type = "negotiation_accepted"
            content_zh = f"{user_name} 接受了报价 {currency} {float(application.negotiated_price or 0):.2f}"
            content_en = f"{user_name} accepted the price {currency} {float(application.negotiated_price or 0):.2f}"
            notif_title = "报价已接受"
            notif_title_en = "Price Accepted"
            notif_body = f'{user_name} 接受了任务「{task.title}」的报价'
            notif_body_en = f'{user_name} accepted the price for task "{task.title}"'
        elif action == "reject":
            application.status = "consulting"
            message_type = "negotiation_rejected"
            content_zh = f"{user_name} 拒绝了当前报价"
            content_en = f"{user_name} rejected the current price"
            notif_title = "报价被拒绝"
            notif_title_en = "Price Rejected"
            notif_body = f'{user_name} 拒绝了任务「{task.title}」的报价'
            notif_body_en = f'{user_name} rejected the price for task "{task.title}"'
        elif action == "counter":
            counter_price = body.counter_price
            application.negotiated_price = Decimal(str(counter_price))
            message_type = "counter_offer"
            content_zh = f"{user_name} 提出还价 {currency} {float(counter_price):.2f}"
            content_en = f"{user_name} counter-offered {currency} {float(counter_price):.2f}"
            notif_title = "收到还价"
            notif_title_en = "Counter Offer"
            notif_body = f'{user_name} 对任务「{task.title}」还价 {currency} {float(counter_price):.2f}'
            notif_body_en = f'{user_name} counter-offered {currency} {float(counter_price):.2f} for task "{task.title}"'
        else:
            raise HTTPException(status_code=400, detail="无效的 action，必须为 accept / reject / counter")

        # 创建消息
        meta_dict = {
            "action": action,
            "price": float(application.negotiated_price) if application.negotiated_price else None,
            "currency": currency,
        }
        msg = models.Message(
            sender_id=current_user.id,
            receiver_id=other_party_id,
            content=content_zh,
            task_id=task_id,
            message_type=message_type,
            conversation_type="task",
            application_id=application_id,
            meta=json.dumps(meta_dict),
            created_at=current_time,
        )
        db.add(msg)
        await db.commit()

        # 通知对方
        try:
            from app import async_crud
            await async_crud.async_notification_crud.create_notification(
                db, other_party_id, "consultation_update",
                notif_title, notif_body,
                related_id=str(task_id), title_en=notif_title_en,
                content_en=notif_body_en,
                related_type="task_id",
            )
        except Exception as e:
            logger.warning(f"Failed to create notification for consult-respond: {e}")

        return {
            "message": content_zh,
            "status": application.status,
            "application_id": application.id,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in consult-respond for task {task_id}, app {application_id}: {e}")
        raise HTTPException(status_code=500, detail=f"回应议价失败: {str(e)}")


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/consult-formal-apply")
async def consult_formal_apply(
    task_id: int,
    application_id: int,
    body: schemas.FormalApplyRequest,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """将咨询转为正式申请 (status → pending)"""
    try:
        from decimal import Decimal

        # 行锁查询申请
        app_result = await db.execute(
            select(models.TaskApplication)
            .where(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id,
            )
            .with_for_update()
        )
        application = app_result.scalar_one_or_none()
        if not application:
            raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)

        # 验证是申请者
        if str(application.applicant_id) != str(current_user.id):
            raise HTTPException(status_code=403, detail="只有申请者可以转为正式申请")

        # 验证状态
        if application.status not in ("consulting", "price_agreed"):
            raise_http_error_with_code(
                f"当前状态 {application.status} 不允许转为正式申请",
                400,
                error_codes.INVALID_STATUS_TRANSITION,
            )

        # 获取任务
        task_result = await db.execute(
            select(models.Task).where(models.Task.id == task_id)
        )
        task = task_result.scalar_one_or_none()
        if not task:
            raise_http_error_with_code("任务不存在", 404, error_codes.TASK_NOT_FOUND)

        current_time = get_utc_time()
        user_name = current_user.name if hasattr(current_user, "name") else "用户"

        # For task_consultation: create formal application on the ORIGINAL task
        original_task_id = None
        orig_task = None
        if getattr(task, 'task_source', None) == 'task_consultation' and task.description:
            # Parse original_task_id from description
            if task.description.startswith("original_task_id:"):
                try:
                    original_task_id = int(task.description.split(":")[1])
                except (ValueError, IndexError):
                    pass

        if original_task_id:
            # Verify original task is still open
            orig_task_result = await db.execute(
                select(models.Task).where(models.Task.id == original_task_id)
            )
            orig_task = orig_task_result.scalar_one_or_none()
            if not orig_task:
                raise_http_error_with_code("原任务不存在", 404, error_codes.TASK_NOT_FOUND)
            if orig_task.status not in ("open", "chatting", "pending_acceptance"):
                raise_http_error_with_code(
                    "原任务当前状态不允许申请",
                    400,
                    error_codes.INVALID_STATUS_TRANSITION,
                )

            # Check if user already has an application on original task
            existing_orig_app = await db.execute(
                select(models.TaskApplication).where(
                    models.TaskApplication.task_id == original_task_id,
                    models.TaskApplication.applicant_id == current_user.id,
                    models.TaskApplication.status.notin_(["cancelled", "rejected"]),
                )
            )
            if existing_orig_app.scalar_one_or_none():
                raise HTTPException(status_code=400, detail="您已有该任务的申请")

            # Create application on original task
            orig_application = models.TaskApplication(
                task_id=original_task_id,
                applicant_id=current_user.id,
                status="pending",
                currency=application.currency or orig_task.currency or "GBP",
                negotiated_price=application.negotiated_price,
                message=body.message or application.message,
                created_at=current_time,
            )
            db.add(orig_application)
            await db.flush()

            # Send system message on original task too
            price_info = ""
            if application.negotiated_price:
                currency = application.currency or orig_task.currency or "GBP"
                price_info = f"，报价 {currency} {float(application.negotiated_price):.2f}"
            orig_content_zh = f"{user_name} 通过咨询提交了正式申请{price_info}"
            orig_content_en = f"{user_name} submitted formal application via consultation{price_info}"
            orig_sys_msg = models.Message(
                sender_id=None,
                receiver_id=None,
                content=orig_content_zh,
                task_id=original_task_id,
                message_type="system",
                conversation_type="task",
                meta=json.dumps({"system_action": "consultation_formal_apply", "content_en": orig_content_en, "from_consultation_task_id": task_id}),
                created_at=current_time,
            )
            db.add(orig_sys_msg)

        # 更新申请
        application.status = "pending"
        if body.message:
            application.message = body.message
        if body.proposed_price is not None:
            application.negotiated_price = Decimal(str(body.proposed_price))

        # Close placeholder task — formal application moves to original task
        task.status = "closed"

        # 创建系统消息
        price_info = ""
        if application.negotiated_price:
            currency = application.currency or task.currency or "GBP"
            price_info = f"，报价 {currency} {float(application.negotiated_price):.2f}"
        content_zh = f"{user_name} 已将咨询转为正式申请{price_info}"
        content_en = f"{user_name} converted consultation to formal application{price_info}"
        system_message = models.Message(
            sender_id=None,
            receiver_id=None,
            content=content_zh,
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            application_id=application_id,
            meta=json.dumps({"system_action": "consultation_to_formal", "content_en": content_en}),
            created_at=current_time,
        )
        db.add(system_message)
        await db.commit()

        # Notify the original task poster (for task_consultation) or placeholder poster (for service consultation)
        notify_user_id = str(orig_task.poster_id) if original_task_id and orig_task else str(task.poster_id)
        notify_task_title = orig_task.title if orig_task else task.title
        try:
            from app import async_crud
            await async_crud.async_notification_crud.create_notification(
                db, notify_user_id, "task_application",
                "收到正式申请", f'{user_name} 对任务「{notify_task_title}」提交了正式申请',
                related_id=str(original_task_id or task_id), title_en="New Formal Application",
                content_en=f'{user_name} submitted a formal application for task "{notify_task_title}"',
                related_type="task_id",
            )
        except Exception as e:
            logger.warning(f"Failed to create notification for consult-formal-apply: {e}")

        return {
            "message": "已转为正式申请",
            "status": application.status,
            "application_id": application.id,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in consult-formal-apply for task {task_id}, app {application_id}: {e}")
        raise HTTPException(status_code=500, detail=f"转为正式申请失败: {str(e)}")


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/consult-close")
async def consult_close(
    task_id: int,
    application_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """关闭咨询 (status → cancelled)"""
    try:
        # 获取任务
        task_result = await db.execute(
            select(models.Task).where(models.Task.id == task_id)
        )
        task = task_result.scalar_one_or_none()
        if not task:
            raise_http_error_with_code("任务不存在", 404, error_codes.TASK_NOT_FOUND)

        # 行锁查询申请
        app_result = await db.execute(
            select(models.TaskApplication)
            .where(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id,
            )
            .with_for_update()
        )
        application = app_result.scalar_one_or_none()
        if not application:
            raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)

        # 双方均可关闭
        is_poster = str(task.poster_id) == str(current_user.id)
        is_taker = str(task.taker_id) == str(current_user.id) if task.taker_id else False
        is_applicant = str(application.applicant_id) == str(current_user.id)
        if not is_poster and not is_taker and not is_applicant:
            raise HTTPException(status_code=403, detail="无权操作此申请")

        # 验证状态
        if application.status not in ("consulting", "negotiating", "price_agreed"):
            raise_http_error_with_code(
                f"当前状态 {application.status} 不允许关闭咨询",
                400,
                error_codes.INVALID_STATUS_TRANSITION,
            )

        application.status = "cancelled"
        # Also close the placeholder task
        task.status = "closed"

        # 系统消息
        current_time = get_utc_time()
        user_name = current_user.name if hasattr(current_user, "name") else "用户"
        content_zh = f"{user_name} 关闭了咨询"
        content_en = f"{user_name} closed the consultation"
        system_message = models.Message(
            sender_id=None,
            receiver_id=None,
            content=content_zh,
            task_id=task_id,
            message_type="system",
            conversation_type="task",
            application_id=application_id,
            meta=json.dumps({"system_action": "consultation_closed", "content_en": content_en}),
            created_at=current_time,
        )
        db.add(system_message)
        await db.commit()

        # 通知对方咨询已关闭
        try:
            from app import async_crud
            if is_applicant:
                other_id = str(task.taker_id) if task.taker_id else str(task.poster_id)
            elif is_taker:
                other_id = str(application.applicant_id)
            else:
                other_id = str(application.applicant_id)
            await async_crud.async_notification_crud.create_notification(
                db, other_id, "consultation_closed",
                "咨询已关闭",
                f'{user_name} 关闭了咨询',
                related_id=str(task_id),
                title_en="Consultation Closed",
                content_en=f'{user_name} closed the consultation',
                related_type="task_id",
            )
        except Exception as e:
            logger.warning(f"Failed to notify other party about consultation closure: {e}")

        return {
            "message": "咨询已关闭",
            "status": application.status,
            "application_id": application.id,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in consult-close for task {task_id}, app {application_id}: {e}")
        raise HTTPException(status_code=500, detail=f"关闭咨询失败: {str(e)}")


@task_chat_router.get("/tasks/{task_id}/applications/{application_id}/consult-status")
async def consult_status(
    task_id: int,
    application_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取咨询状态"""
    try:
        # 获取任务
        task_result = await db.execute(
            select(models.Task).where(models.Task.id == task_id)
        )
        task = task_result.scalar_one_or_none()
        if not task:
            raise_http_error_with_code("任务不存在", 404, error_codes.TASK_NOT_FOUND)

        # 查询申请
        app_result = await db.execute(
            select(models.TaskApplication).where(
                models.TaskApplication.id == application_id,
                models.TaskApplication.task_id == task_id,
            )
        )
        application = app_result.scalar_one_or_none()
        if not application:
            raise_http_error_with_code("申请不存在", 404, error_codes.CONSULTATION_NOT_FOUND)

        # 验证双方均可查看
        is_poster = str(task.poster_id) == str(current_user.id)
        is_taker = str(task.taker_id) == str(current_user.id) if task.taker_id else False
        is_applicant = str(application.applicant_id) == str(current_user.id)
        if not is_poster and not is_taker and not is_applicant:
            raise HTTPException(status_code=403, detail="无权查看此申请")

        return {
            "id": application.id,
            "task_id": application.task_id,
            "applicant_id": application.applicant_id,
            "status": application.status,
            "negotiated_price": float(application.negotiated_price) if application.negotiated_price else None,
            "currency": application.currency,
            "poster_id": str(task.poster_id),
            "created_at": format_iso_utc(application.created_at) if application.created_at else None,
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in consult-status for task {task_id}, app {application_id}: {e}")
        raise HTTPException(status_code=500, detail=f"获取咨询状态失败: {str(e)}")
