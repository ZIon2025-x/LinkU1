"""
任务聊天功能API路由
实现任务聊天相关的所有接口
"""

import json
import logging
from datetime import datetime, timezone
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
from sqlalchemy import and_, func, or_, select, text, exists, desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app import models, schemas
from app.deps import get_async_db_dependency
from app.utils.time_utils import get_utc_time, parse_iso_utc, format_iso_utc

logger = logging.getLogger(__name__)

# 创建任务聊天路由器
task_chat_router = APIRouter()


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
        # 查询用户相关的任务（作为发布者、接受者或多人任务参与者）
        # 获取所有相关的任务ID
        task_ids_set = set()
        
        # 1. 作为发布者或接受者的任务
        tasks_query_1 = select(models.Task.id).where(
            or_(
                models.Task.poster_id == current_user.id,
                models.Task.taker_id == current_user.id,
                # 多人任务：作为任务达人创建者
                and_(
                    models.Task.is_multi_participant.is_(True),
                    models.Task.created_by_expert.is_(True),
                    models.Task.expert_creator_id == current_user.id
                )
            )
        )
        result_1 = await db.execute(tasks_query_1)
        task_ids_set.update([row[0] for row in result_1.all()])
        
        # 2. 作为多人任务参与者的任务
        participant_tasks_query = select(models.Task.id).join(
            models.TaskParticipant,
            models.Task.id == models.TaskParticipant.task_id
        ).where(
            and_(
                models.TaskParticipant.user_id == current_user.id,
                models.TaskParticipant.status.in_(["accepted", "in_progress"]),
                models.Task.is_multi_participant.is_(True)
            )
        )
        result_2 = await db.execute(participant_tasks_query)
        task_ids_set.update([row[0] for row in result_2.all()])
        
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
                    models.Message.conversation_type == 'task'
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
        
        # 批量获取任务ID列表
        task_ids = [task.id for task in tasks]
        
        # 批量查询所有游标（优化性能）
        cursors_query = select(models.MessageReadCursor).where(
            and_(
                models.MessageReadCursor.task_id.in_(task_ids),
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
                    models.Message.task_id.in_(task_ids),
                    models.Message.conversation_type == 'task'
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
        
        # 批量查询发送者信息
        if sender_ids_for_last_messages:
            senders_query = select(models.User).where(
                models.User.id.in_(list(sender_ids_for_last_messages))
            )
            senders_result = await db.execute(senders_query)
            senders_dict = {s.id: s for s in senders_result.scalars().all()}
        else:
            senders_dict = {}
        
        # 为每个任务计算未读数和最后消息
        task_list = []
        for task in tasks:
            # 计算未读数（排除自己发送的消息）
            cursor = cursors_dict.get(task.id)
            
            if cursor and cursor.last_read_message_id is not None:
                # 使用游标计算未读数
                unread_query = select(func.count(models.Message.id)).where(
                    and_(
                        models.Message.task_id == task.id,
                        models.Message.id > cursor.last_read_message_id,
                        models.Message.sender_id != current_user.id,
                        models.Message.conversation_type == 'task'
                    )
                )
            else:
                # 没有游标或游标为None，使用 message_reads 表兜底
                unread_query = select(func.count(models.Message.id)).where(
                    and_(
                        models.Message.task_id == task.id,
                        models.Message.sender_id != current_user.id,
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
            
            task_data = {
                "id": task.id,
                "title": task.title,
                "task_type": task.task_type,
                "images": images_list,
                "poster_id": task.poster_id,
                "status": task.status,
                "taker_id": task.taker_id,
                "completed_at": format_iso_utc(task.completed_at) if task.completed_at else None,
                "unread_count": unread_count,
                "last_message": last_message_data,
                # 多人任务相关字段
                "is_multi_participant": bool(task.is_multi_participant) if hasattr(task, 'is_multi_participant') else False,
                "expert_creator_id": task.expert_creator_id if hasattr(task, 'expert_creator_id') else None,
                "created_by_expert": bool(task.created_by_expert) if hasattr(task, 'created_by_expert') else False
            }
            task_list.append(task_data)
        
        return {
            "tasks": task_list,
            "total": total
        }
    
    except Exception as e:
        logger.error(f"获取任务聊天列表失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取任务聊天列表失败: {str(e)}"
        )


@task_chat_router.get("/messages/task/{task_id}")
async def get_task_messages(
    task_id: int,
    limit: int = Query(20, ge=1, le=100),
    cursor: Optional[str] = Query(None),
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
        
        if not is_poster and not is_taker and not is_participant:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限查看该任务的消息"
            )
        
        # 构建消息查询
        messages_query = select(models.Message).where(
            and_(
                models.Message.task_id == task_id,
                models.Message.conversation_type == 'task'
            )
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
                    detail=f"无效的游标格式: {str(e)}"
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
                except:
                    attachment_data["meta"] = {}
            else:
                attachment_data["meta"] = {}
            
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
                "attachments": attachments_by_message.get(msg.id, [])
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
        
        # 构建任务信息
        task_data = {
            "id": task.id,
            "title": task.title,
            "task_type": task.task_type,
            "images": images_list,
            "poster_id": task.poster_id,
            "taker_id": task.taker_id,
            "status": task.status,
            "completed_at": format_iso_utc(task.completed_at) if task.completed_at else None,
            "base_reward": float(task.base_reward) if task.base_reward else None,
            "agreed_reward": float(task.agreed_reward) if task.agreed_reward else None,
            "currency": task.currency or "GBP",
            # 多人任务相关字段
            "is_multi_participant": bool(task.is_multi_participant) if hasattr(task, 'is_multi_participant') else False,
            "expert_creator_id": task.expert_creator_id if hasattr(task, 'expert_creator_id') else None,
            "created_by_expert": bool(task.created_by_expert) if hasattr(task, 'created_by_expert') else False
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
            detail=f"获取任务消息失败: {str(e)}"
        )


# Pydantic 模型定义
from pydantic import BaseModel, Field, validator, model_validator
from typing import Dict, Any


class SendMessageRequest(BaseModel):
    """发送消息请求体"""
    content: str = Field(..., min_length=1, max_length=5000)
    meta: Optional[Dict[str, Any]] = Field(None, description="JSON格式元数据")
    attachments: List[Dict[str, Any]] = Field(default_factory=list, description="附件数组")
    
    @validator('meta')
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
    
    @model_validator(mode='after')
    def validate_at_least_one(self):
        """验证至少提供一个字段"""
        upto_id = self.upto_message_id
        msg_ids = self.message_ids
        if not upto_id and not msg_ids:
            raise ValueError("必须提供 upto_message_id 或 message_ids 之一")
        return self


@task_chat_router.get("/tasks/{task_id}/applications")
async def get_task_applications(
    task_id: int,
    status: Optional[str] = Query(None, description="申请状态过滤"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    获取任务申请列表
    发布者可以看到所有申请，申请者只能看到自己的申请
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
        
        # 权限检查
        is_poster = task.poster_id == current_user.id
        is_taker = task.taker_id == current_user.id
        # 多人任务：任务达人也可以查看申请列表
        is_expert_creator = getattr(task, 'is_multi_participant', False) and getattr(task, 'expert_creator_id', None) == current_user.id
        
        if not is_poster and not is_taker and not is_expert_creator:
            # 检查是否是申请者
            application_check = select(models.TaskApplication).where(
                and_(
                    models.TaskApplication.task_id == task_id,
                    models.TaskApplication.applicant_id == current_user.id
                )
            )
            app_check_result = await db.execute(application_check)
            has_application = app_check_result.scalar_one_or_none() is not None
            
            if not has_application:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="无权限查看该任务的申请"
                )
        
        # 构建查询
        applications_query = select(models.TaskApplication).where(
            models.TaskApplication.task_id == task_id
        )
        
        # 如果不是发布者，只能看到自己的申请
        if not is_poster:
            applications_query = applications_query.where(
                models.TaskApplication.applicant_id == current_user.id
            )
        
        # 状态过滤
        if status:
            applications_query = applications_query.where(
                models.TaskApplication.status == status
            )
        
        # 查询总数
        count_query = select(func.count(models.TaskApplication.id)).where(
            models.TaskApplication.task_id == task_id
        )
        if not is_poster:
            count_query = count_query.where(
                models.TaskApplication.applicant_id == current_user.id
            )
        if status:
            count_query = count_query.where(
                models.TaskApplication.status == status
            )
        
        total_result = await db.execute(count_query)
        total = total_result.scalar()
        
        # 分页
        applications_query = applications_query.order_by(
            models.TaskApplication.created_at.desc()
        ).offset(offset).limit(limit)
        
        applications_result = await db.execute(applications_query)
        applications = applications_result.scalars().all()
        
        # 获取申请者ID列表
        applicant_ids = list(set([app.applicant_id for app in applications]))
        
        # 批量查询用户信息
        users_query = select(models.User).where(models.User.id.in_(applicant_ids))
        users_result = await db.execute(users_query)
        users = {user.id: user for user in users_result.scalars().all()}
        
        # 构建返回数据
        applications_data = []
        for app in applications:
            applicant = users.get(app.applicant_id)
            
            # 处理议价金额：从 task_applications 表中读取 negotiated_price 字段
            negotiated_price_value = None
            if app.negotiated_price is not None:
                try:
                    # Decimal 类型转换为 float
                    from decimal import Decimal
                    if isinstance(app.negotiated_price, Decimal):
                        negotiated_price_value = float(app.negotiated_price)
                    elif isinstance(app.negotiated_price, (int, float)):
                        negotiated_price_value = float(app.negotiated_price)
                    else:
                        # 尝试字符串转换
                        negotiated_price_value = float(str(app.negotiated_price))
                except (ValueError, TypeError, AttributeError) as e:
                    logger.warning(f"转换议价金额失败: app_id={app.id}, negotiated_price={app.negotiated_price}, 类型={type(app.negotiated_price)}, error={e}")
                    negotiated_price_value = None
            
            app_data = {
                "id": app.id,
                "applicant_id": app.applicant_id,
                "applicant_name": applicant.name if applicant else None,
                "applicant_avatar": applicant.avatar if applicant and hasattr(applicant, 'avatar') else None,
                "message": app.message,
                "negotiated_price": negotiated_price_value,  # 从 task_applications.negotiated_price 字段读取
                "currency": app.currency or "GBP",  # 从 task_applications.currency 字段读取
                "status": app.status,
                "created_at": format_iso_utc(app.created_at) if app.created_at else None
            }
            applications_data.append(app_data)
        
        return {
            "applications": applications_data,
            "total": total,
            "limit": limit,
            "offset": offset
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务申请列表失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取任务申请列表失败: {str(e)}"
        )


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
        
        if not is_poster and not is_taker and not is_participant and not is_expert_creator:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限发送消息"
            )
        
        # 任务状态检查
        can_send_normal = (task.status == "in_progress" or task.taker_id is not None)
        can_send_prenote = (task.status == "open" and is_poster)
        
        if not can_send_normal and not can_send_prenote:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="当前任务状态不允许发送消息"
            )
        
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
                # 检查 url 和 blob_id 必须二选一
                has_url = "url" in att and att["url"]
                has_blob_id = "blob_id" in att and att["blob_id"]
                if not (has_url ^ has_blob_id):
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail="附件必须提供 url 或 blob_id 之一，且不能同时提供"
                    )
        
        # 获取当前时间
        current_time = get_utc_time()
        
        # 创建消息
        meta_str = json.dumps(request.meta) if request.meta else None
        new_message = models.Message(
            sender_id=current_user.id,
            receiver_id=None,  # 任务消息不需要 receiver_id
            content=request.content,
            task_id=task_id,
            message_type="normal",
            conversation_type="task",
            meta=meta_str,
            created_at=current_time
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
            
            # 添加发布者（对于单人任务，这是发布者；对于多人任务，这是申请活动的用户）
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
                
                # 添加所有TaskParticipant（包括申请活动的用户和其他参与者）
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
            
            # 向所有参与者（除了发送者）广播消息
            for participant_id in participant_ids:
                if participant_id != current_user.id:
                    success = await ws_manager.send_to_user(participant_id, message_response)
                    if success:
                        logger.debug(f"Task message broadcasted to participant {participant_id}")
        except Exception as e:
            # WebSocket广播失败不应该影响消息发送
            logger.error(f"Failed to broadcast task message via WebSocket: {e}", exc_info=True)
        
        return {
            "id": new_message.id,
            "sender_id": new_message.sender_id,
            "content": new_message.content,
            "task_id": new_message.task_id,
            "created_at": format_iso_utc(new_message.created_at) if new_message.created_at else None,
            "attachments": attachments_data
        }
    
    except HTTPException:
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"发送任务消息失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"发送任务消息失败: {str(e)}"
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
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="无权限标记该任务的消息"
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
            messages_to_mark_query = select(models.Message).where(
                and_(
                    models.Message.task_id == task_id,
                    models.Message.sender_id != current_user.id,
                    or_(
                        models.Message.created_at < upto_message.created_at,
                        and_(
                            models.Message.created_at == upto_message.created_at,
                            models.Message.id <= upto_message.id
                        )
                    )
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
            
            # 更新或创建游标
            cursor_query = select(models.MessageReadCursor).where(
                and_(
                    models.MessageReadCursor.task_id == task_id,
                    models.MessageReadCursor.user_id == current_user.id
                )
            )
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
            
            # 更新游标（使用最大的消息ID）
            if messages_to_mark:
                max_message_id = max([msg.id for msg in messages_to_mark])
                
                cursor_query = select(models.MessageReadCursor).where(
                    and_(
                        models.MessageReadCursor.task_id == task_id,
                        models.MessageReadCursor.user_id == current_user.id
                    )
                )
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
                        last_read_message_id=max_message_id,
                        updated_at=current_time
                    )
                    db.add(new_cursor)
        
        await db.commit()
        
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
            detail=f"标记消息已读失败: {str(e)}"
        )


# 申请相关接口
class ApplyTaskRequest(BaseModel):
    """申请任务请求体"""
    message: Optional[str] = Field(None, max_length=1000)
    negotiated_price: Optional[float] = Field(None, ge=0)
    currency: Optional[str] = Field(None, max_length=3)


class NegotiateRequest(BaseModel):
    """再次议价请求体"""
    negotiated_price: float = Field(..., ge=0)
    message: Optional[str] = Field(None, max_length=1000)


class RespondNegotiationRequest(BaseModel):
    """处理再次议价请求体"""
    action: str = Field(..., description="accept 或 reject")
    token: str = Field(..., description="一次性签名token")


class SendApplicationMessageRequest(BaseModel):
    """发送申请留言请求体"""
    message: str = Field(..., max_length=1000, description="留言内容")
    negotiated_price: Optional[float] = Field(None, ge=0, description="议价金额（可选）")


class ReplyApplicationMessageRequest(BaseModel):
    """回复申请留言请求体"""
    message: str = Field(..., max_length=1000, description="回复内容")
    notification_id: int = Field(..., description="原始通知ID")


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/accept")
async def accept_application(
    task_id: int,
    application_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """
    接受申请
    使用事务锁防止并发，支持幂等性
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
        
        # 使用 SELECT FOR UPDATE 锁定任务行（防止并发）
        from sqlalchemy import update
        locked_task_query = select(models.Task).where(
            models.Task.id == task_id
        ).with_for_update()
        locked_task_result = await db.execute(locked_task_query)
        locked_task = locked_task_result.scalar_one_or_none()
        
        # 幂等性检查：如果申请已经是 approved，直接返回成功
        if application.status == "approved":
            return {
                "message": "申请已被接受",
                "application_id": application_id,
                "task_id": task_id
            }
        
        # 检查任务是否还有名额
        if locked_task.taker_id is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="任务已被接受"
            )
        
        # 检查申请人是否有 Stripe Connect 账户（用于接收任务奖励）
        applicant = await db.get(models.User, application.applicant_id)
        if not applicant:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="申请人不存在"
            )
        
        if not applicant.stripe_account_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="申请人尚未创建 Stripe Connect 收款账户，无法接受任务。请先创建收款账户。",
                headers={"X-Stripe-Connect-Required": "true"}
            )
        
        # 检查 Stripe Connect 账户状态（异步检查，不阻塞）
        try:
            import stripe
            import os
            stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
            
            account = stripe.Account.retrieve(applicant.stripe_account_id)
            
            # 检查账户是否已完成 onboarding
            if not account.details_submitted:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="申请人的 Stripe Connect 账户尚未完成设置，无法接受任务。请先完成账户设置。",
                    headers={"X-Stripe-Connect-Onboarding-Required": "true"}
                )
            
            # 检查账户是否已启用收款
            if not account.charges_enabled:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="申请人的 Stripe Connect 账户尚未启用收款功能，无法接受任务。",
                    headers={"X-Stripe-Connect-Charges-Not-Enabled": "true"}
                )
        except HTTPException:
            raise
        except Exception as e:
            # 如果 Stripe API 调用失败，记录错误但不阻止接受申请
            # 在确认完成时会再次检查
            import logging
            logger = logging.getLogger(__name__)
            logger.warning(f"无法验证申请人 {application.applicant_id} 的 Stripe Connect 账户: {e}")
        
        # 获取当前时间
        current_time = get_utc_time()
        
        # 不立即批准申请，而是创建支付意图
        # 申请状态保持为 pending，等待支付成功后才批准
        
        # 计算任务金额
        from app.crud import get_system_setting
        task_amount = float(application.negotiated_price) if application.negotiated_price is not None else float(locked_task.base_reward) if locked_task.base_reward is not None else 0.0
        
        if task_amount <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="任务金额必须大于0，无法进行支付"
            )
        
        task_amount_pence = int(task_amount * 100)
        
        # 计算平台服务费
        application_fee_rate_setting = await db.execute(
            select(models.SystemSetting).where(models.SystemSetting.setting_key == "application_fee_rate")
        )
        application_fee_rate_setting = application_fee_rate_setting.scalar_one_or_none()
        application_fee_rate = float(application_fee_rate_setting.setting_value) if application_fee_rate_setting else 0.10
        application_fee_pence = int(task_amount_pence * application_fee_rate)
        
        # 创建 Stripe Payment Intent
        import stripe
        import os
        stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
        
        # 获取接受者的 Stripe Connect 账户ID
        taker_stripe_account_id = applicant.stripe_account_id
        
        # 创建 Payment Intent，使用 Destination charges
        payment_intent = stripe.PaymentIntent.create(
            amount=task_amount_pence,
            currency="gbp",
            application_fee_amount=application_fee_pence,
            transfer_data={
                "destination": taker_stripe_account_id
            },
            metadata={
                "task_id": str(task_id),
                "application_id": str(application_id),
                "poster_id": str(current_user.id),
                "taker_id": str(application.applicant_id),
                "pending_approval": "true"  # 标记这是待确认的批准
            },
            automatic_payment_methods={"enabled": True},
        )
        
        # 保存 payment_intent_id 到任务（临时存储，支付成功后才会真正批准）
        locked_task.payment_intent_id = payment_intent.id
        
        # 如果申请包含议价，更新 agreed_reward（但不更新 taker_id 和状态）
        if application.negotiated_price is not None:
            locked_task.agreed_reward = application.negotiated_price
        
        # 不更新申请状态，保持为 pending
        # 不更新任务状态，保持原状态
        # 不设置 taker_id，等待支付成功后再设置
        
        await db.commit()
        
        return {
            "message": "请完成支付以确认批准申请",
            "application_id": application_id,
            "task_id": task_id,
            "payment_intent_id": payment_intent.id,
            "client_secret": payment_intent.client_secret,
            "amount": task_amount_pence,
            "amount_display": f"{task_amount_pence / 100:.2f}",
            "currency": "GBP"
        }
    
    except HTTPException:
        await db.rollback()
        raise
    except Exception as e:
        await db.rollback()
        logger.error(f"接受申请失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"接受申请失败: {str(e)}"
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
                detail="只有发布者可以拒绝申请"
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
        
        await db.commit()
        
        # 发送通知给申请者
        try:
            notification_time = get_utc_time()
            
            # ⚠️ 直接使用文本内容，不存储 JSON
            content = f"您的任务申请已被拒绝：{task.title}"
            
            new_notification = models.Notification(
                user_id=application.applicant_id,
                type="application_rejected",
                title="您的申请已被拒绝",
                content=content,  # 直接使用文本，不存储 JSON
                related_id=application_id,
                created_at=notification_time
            )
            db.add(new_notification)
            await db.commit()
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
            detail=f"拒绝申请失败: {str(e)}"
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
                detail="只有申请者本人可以撤回申请"
            )
        
        # 检查申请状态
        if application.status != "pending":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="只能撤回待处理的申请"
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
            
            new_notification = models.Notification(
                user_id=task.poster_id,
                type="application_withdrawn",
                title="有申请者撤回了申请",
                content=content,  # 直接使用文本，不存储 JSON
                related_id=application_id,
                created_at=current_time
            )
            db.add(new_notification)
            await db.commit()
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
            detail=f"撤回申请失败: {str(e)}"
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
        
        # 校验货币一致性
        if application.currency and task.currency:
            if application.currency != task.currency:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"货币不一致：申请使用 {application.currency}，任务使用 {task.currency}"
                )
        
        # 更新议价价格
        from decimal import Decimal
        application.negotiated_price = Decimal(str(request.negotiated_price))
        
        # 生成一次性签名token
        import secrets
        import time
        
        # 生成两个token：accept 和 reject
        token_accept = secrets.token_urlsafe(32)
        token_reject = secrets.token_urlsafe(32)
        
        # 获取当前时间戳
        current_timestamp = int(time.time())
        expires_at = current_timestamp + 300  # 5分钟后过期
        
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
                "nonce": nonce_accept,
                "exp": expires_at,
                "expires_at": format_iso_utc(datetime.fromtimestamp(expires_at, tz=timezone.utc))
            }
            
            token_data_reject = {
                "user_id": application.applicant_id,
                "action": "reject",
                "application_id": application_id,
                "task_id": task_id,
                "nonce": nonce_reject,
                "exp": expires_at,
                "expires_at": format_iso_utc(datetime.fromtimestamp(expires_at, tz=timezone.utc))
            }
            
            # 存储到Redis，5分钟过期
            redis_client.setex(
                f"negotiation_token:{token_accept}",
                300,  # 5分钟
                json.dumps(token_data_accept)
            )
            
            redis_client.setex(
                f"negotiation_token:{token_reject}",
                300,  # 5分钟
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
        
        new_notification = models.Notification(
            user_id=application.applicant_id,
            type="negotiation_offer",
            title="新的议价提议",
            content=content,  # 直接使用文本，不存储 JSON
            related_id=application_id,
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
                300,  # 5分钟
                json.dumps(token_data_accept)
            )
            
            redis_client.setex(
                f"negotiation_token:{token_reject}",
                300,  # 5分钟
                json.dumps(token_data_reject)
            )
            
            # ⚠️ 额外存储 notification_id -> tokens 映射，方便前端通过 notification_id 获取 token
            redis_client.setex(
                f"negotiation_tokens_by_notification:{notification_id}",
                300,  # 5分钟
                json.dumps({
                    "token_accept": token_accept,
                    "token_reject": token_reject,
                    "task_id": task_id,
                    "application_id": application_id
                })
            )
        
        await db.commit()
        
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
            detail=f"发起再次议价失败: {str(e)}"
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
        
        return {
            "token_accept": token_data.get("token_accept"),
            "token_reject": token_data.get("token_reject"),
            "task_id": token_data.get("task_id"),
            "application_id": token_data.get("application_id")
        }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取议价token失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取议价token失败: {str(e)}"
        )


@task_chat_router.post("/tasks/{task_id}/applications/{application_id}/respond-negotiation")
async def respond_negotiation(
    task_id: int,
    application_id: int,
    request: RespondNegotiationRequest,
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
            
            # 更新任务
            locked_task.taker_id = application.applicant_id
            locked_task.status = "in_progress"
            
            # 如果申请包含议价，更新 agreed_reward
            if application.negotiated_price is not None:
                locked_task.agreed_reward = application.negotiated_price
            
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
            
            # 发送通知给发布者
            try:
                # ⚠️ 直接使用文本内容，不存储 JSON
                content = f"申请者已接受您对任务「{task.title}」的议价"
                
                new_notification = models.Notification(
                    user_id=task.poster_id,
                    type="application_accepted",
                    title="申请者已接受您的议价",
                    content=content,  # 直接使用文本，不存储 JSON
                    related_id=application_id,
                    created_at=current_time
                )
                db.add(new_notification)
                # 注意：通知会在下面的 await db.commit() 中一起提交
            except Exception as e:
                logger.error(f"发送接受议价通知失败: {e}")
                # 通知失败不影响主流程
            
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
                notification_content = {
                    "type": "negotiation_rejected",
                    "task_id": task_id,
                    "task_title": task.title,
                    "application_id": application_id
                }
                
                new_notification = models.Notification(
                    user_id=task.poster_id,
                    type="negotiation_rejected",
                    title="申请者已拒绝您的议价",
                    content=json.dumps(notification_content),
                    related_id=application_id,
                    created_at=current_time
                )
                db.add(new_notification)
                # 注意：通知会在下面的 await db.commit() 中一起提交
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
            detail=f"处理再次议价失败: {str(e)}"
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
        
        # 如果包含议价，更新申请的negotiated_price
        if request.negotiated_price is not None:
            from decimal import Decimal
            application.negotiated_price = Decimal(str(request.negotiated_price))
            
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
            expires_at = current_timestamp + 300  # 5分钟后过期
            
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
                    "nonce": nonce_accept,
                    "exp": expires_at,
                    "expires_at": format_iso_utc(datetime.fromtimestamp(expires_at, tz=timezone.utc))
                }
                
                token_data_reject = {
                    "user_id": application.applicant_id,
                    "action": "reject",
                    "application_id": application_id,
                    "task_id": task_id,
                    "nonce": nonce_reject,
                    "exp": expires_at,
                    "expires_at": format_iso_utc(datetime.fromtimestamp(expires_at, tz=timezone.utc))
                }
                
                redis_client.setex(
                    f"negotiation_token:{token_accept}",
                    300,
                    json.dumps(token_data_accept)
                )
                
                redis_client.setex(
                    f"negotiation_token:{token_reject}",
                    300,
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
        else:
            # application_message 使用文本格式
            if request.message:
                content = f"任务「{task.title}」的发布者给您留言：{request.message}"
            else:
                content = f"任务「{task.title}」的发布者给您留言"
        
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
                related_id=application_id,  # 保持为 application_id
                created_at=current_time
            )
            db.add(new_notification)
            await db.flush()
        
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
                        300,
                        json.dumps(token_data_accept)
                    )
                
                if token_data_reject:
                    token_data_reject["notification_id"] = notification_id
                    redis_client.setex(
                        f"negotiation_token:{token_reject}",
                        300,
                        json.dumps(token_data_reject)
                    )
                
                # ⚠️ 额外存储 notification_id -> tokens 映射，方便前端通过 notification_id 获取 token
                redis_client.setex(
                    f"negotiation_tokens_by_notification:{notification_id}",
                    300,  # 5分钟
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
            detail=f"发送留言失败: {str(e)}"
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
        
        reply_notification = models.Notification(
            user_id=task.poster_id,
            type="application_message_reply",
            title="申请者回复了您的留言",
            content=content,  # 直接使用文本，不存储 JSON
            related_id=request.notification_id,  # 关联到原始通知
            created_at=current_time
        )
        db.add(reply_notification)
        
        await db.commit()
        
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
            detail=f"回复留言失败: {str(e)}"
        )

