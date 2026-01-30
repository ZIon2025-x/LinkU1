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
from sqlalchemy import and_, func, or_, select, text, exists, desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app import models, schemas
from app.deps import get_async_db_dependency
from app.utils.time_utils import get_utc_time, parse_iso_utc, format_iso_utc
from app.push_notification_service import send_push_notification_async_safe

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
                models.Task.taker_id == current_user.id
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
        participant_tasks_query = select(models.TaskParticipant.task_id).where(
            and_(
                models.TaskParticipant.user_id == current_user.id,
                models.TaskParticipant.status.in_(["accepted", "in_progress"])
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
        
        # 批量获取任务翻译（使用辅助函数）
        from app.utils.task_translation_helper import get_task_translations_batch, get_task_title_translations
        translations_dict = await get_task_translations_batch(db, task_ids, field_type='title')
        
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
                # 排除系统消息，与 crud.get_unread_messages 保持一致
                unread_query = select(func.count(models.Message.id)).where(
                    and_(
                        models.Message.task_id == task.id,
                        models.Message.id > cursor.last_read_message_id,
                        models.Message.sender_id != current_user.id,
                        models.Message.sender_id.notin_(['system', 'SYSTEM']),  # 排除系统消息
                        models.Message.message_type != 'system',  # 排除系统类型消息
                        models.Message.conversation_type == 'task'
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
            
            # 获取双语标题
            title_en, title_zh = get_task_title_translations(translations_dict, task.id)
            
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
                # 多人任务相关字段
                "is_multi_participant": bool(task.is_multi_participant) if hasattr(task, 'is_multi_participant') else False,
                "expert_creator_id": task.expert_creator_id if hasattr(task, 'expert_creator_id') else None,
                "created_by_expert": bool(task.created_by_expert) if hasattr(task, 'created_by_expert') else False,
                "task_source": getattr(task, 'task_source', 'normal')  # 任务来源
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
        from app.task_chat_business_logic import UnreadCountLogic
        
        # 查询用户相关的任务（作为发布者、接受者或多人任务参与者）
        task_ids_set = set()
        
        # 1. 作为发布者或接受者的任务
        tasks_query_1 = select(models.Task.id).where(
            or_(
                models.Task.poster_id == current_user.id,
                models.Task.taker_id == current_user.id
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
        participant_tasks_query = select(models.TaskParticipant.task_id).where(
            and_(
                models.TaskParticipant.user_id == current_user.id,
                models.TaskParticipant.status.in_(["accepted", "in_progress"])
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
        
        return {"unread_count": total_unread}
    
    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        logger.error(f"获取任务聊天未读数量失败: {e}\n{error_trace}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取任务聊天未读数量失败: {str(e)}"
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
        
        # 获取任务翻译
        from app.utils.task_translation_helper import get_task_translations_batch, get_task_title_translations
        translations_dict = await get_task_translations_batch(db, [task_id], field_type='title')
        title_en, title_zh = get_task_title_translations(translations_dict, task_id)
        
        # 构建任务信息
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
            "base_reward": float(task.base_reward) if task.base_reward else None,
            "agreed_reward": float(task.agreed_reward) if task.agreed_reward else None,
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
        
        # 从 meta 中读取 message_type，如果是系统消息，则设置为 "system"
        # 系统消息的 sender_id 应该为 None
        message_type = "normal"
        sender_id = current_user.id
        if request.meta and request.meta.get("message_type") == "system":
            message_type = "system"
            sender_id = None  # 系统消息的 sender_id 为 None
        
        new_message = models.Message(
            sender_id=sender_id,
            receiver_id=None,  # 任务消息不需要 receiver_id
            content=request.content,
            task_id=task_id,
            message_type=message_type,
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
                            # 截取消息内容（最多50个字符）
                            message_preview = new_message.content[:50] + ("..." if len(new_message.content) > 50 else "")
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
        
        # 确保 sender_id 为字符串，与 iOS Message 模型 decodeIfPresent(String.self) 兼容；
        # 补全 message_type、is_read、sender_name、sender_avatar，与 GET 消息格式一致，便于发送后即展示
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
        async def _create_customer_and_ephemeral_key(stripe_module, user_id: str, user_name: str):
            """
            为支付方创建/获取 Stripe Customer，并生成 Ephemeral Key（用于客户端保存/复用支付方式）。
            失败时返回 (None, None)，不阻塞支付流程。
            """
            customer_id = None
            ephemeral_key_secret = None
            try:
                # 使用 Stripe Search API 查找现有 Customer（通过 metadata.user_id）
                # 注意：Customer.list() 不支持通过 metadata 查询，需要使用 Search API
                try:
                    search_result = stripe_module.Customer.search(
                        query=f"metadata['user_id']:'{user_id}'",
                        limit=1
                    )
                    if search_result.data:
                        customer_id = search_result.data[0].id
                    else:
                        customer = stripe_module.Customer.create(
                            metadata={
                                "user_id": user_id,
                                "user_name": user_name,
                            }
                        )
                        customer_id = customer.id
                except Exception as search_error:
                    # 如果 Search API 不可用或失败，直接创建新的 Customer
                    logger.debug(f"Stripe Search API 不可用，直接创建新 Customer: {search_error}")
                    customer = stripe_module.Customer.create(
                        metadata={
                            "user_id": user_id,
                            "user_name": user_name,
                        }
                    )
                    customer_id = customer.id

                ephemeral_key = stripe_module.EphemeralKey.create(
                    customer=customer_id,
                    stripe_version="2025-04-30.preview",
                )
                ephemeral_key_secret = ephemeral_key.secret
            except Exception as e:
                logger.warning(f"无法创建 Stripe Customer 或 Ephemeral Key: {e}")
                customer_id = None
                ephemeral_key_secret = None

            return customer_id, ephemeral_key_secret

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
                    stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
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
                        user_id=str(current_user.id),
                        user_name=current_user.name or f"User {current_user.id}",
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
        
        # 检查任务是否已支付（防止重复支付）
        if locked_task.is_paid == 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="任务已支付，无法重复支付。如果支付未完成，请联系客服。"
            )
        
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
            logger.warning(f"无法验证申请人 {application.applicant_id} 的 Stripe Connect 账户: {e}")
        
        # 获取当前时间
        current_time = get_utc_time()
        
        # 不立即批准申请，而是创建支付意图
        # 申请状态保持为 pending，等待支付成功后才批准
        
        # 计算任务金额
        task_amount = float(application.negotiated_price) if application.negotiated_price is not None else float(locked_task.base_reward) if locked_task.base_reward is not None else 0.0
        
        if task_amount <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="任务金额必须大于0，无法进行支付"
            )
        
        task_amount_pence = int(task_amount * 100)
        
        # 计算平台服务费
        # 规则：小于10镑固定收取1镑，大于等于10镑按10%计算
        from app.utils.fee_calculator import calculate_application_fee_pence
        application_fee_pence = calculate_application_fee_pence(task_amount_pence)
        
        # 创建 Stripe Payment Intent
        import stripe
        import os
        stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
        
        # 获取接受者的 Stripe Connect 账户ID
        taker_stripe_account_id = applicant.stripe_account_id
        
        # 创建 Payment Intent（参考 Stripe Payment Intents API sample code）
        # Create a PaymentIntent with the order amount and currency
        # 使用 automatic_payment_methods（与官方 sample code 一致）
        # 
        # 交易市场托管模式：
        # - 支付时：资金先到平台账户（不立即转账给任务接受人）
        # - 任务完成后：使用 Transfer.create 将资金转给任务接受人
        # - 平台服务费在转账时扣除（不在这里设置 application_fee_amount）
        
        # 构建支付描述（方便在 Stripe Dashboard 中查看）
        task_title_short = locked_task.title[:50] if locked_task.title else f"Task #{task_id}"
        payment_description = f"任务 #{task_id}: {task_title_short} - 批准申请 #{application_id}"
        
        payment_intent = stripe.PaymentIntent.create(
            amount=task_amount_pence,
            currency="gbp",
            # 明确指定支付方式类型，确保 WeChat Pay 可用
            # 注意：不能同时使用 payment_method_types 和 automatic_payment_methods
            # 必须在 Stripe Dashboard 中启用 WeChat Pay
            payment_method_types=["card", "wechat_pay", "alipay"],
            # 不设置 transfer_data.destination，让资金留在平台账户（托管模式）
            # 不设置 application_fee_amount，服务费在任务完成转账时扣除
            description=payment_description,  # 支付描述，方便在 Stripe Dashboard 中查看
            metadata={
                "task_id": str(task_id),
                "task_title": locked_task.title[:200] if locked_task.title else "",  # 任务标题（限制长度）
                "application_id": str(application_id),
                "poster_id": str(current_user.id),
                "poster_name": current_user.name or f"User {current_user.id}",  # 发布者名称
                "taker_id": str(application.applicant_id),
                "taker_name": applicant.name or f"User {application.applicant_id}",  # 接受者名称
                "taker_stripe_account_id": taker_stripe_account_id,  # 保存接受人的 Stripe 账户ID，用于后续转账
                "application_fee": str(application_fee_pence),  # 保存服务费金额，用于后续转账时扣除
                "task_amount": str(task_amount_pence),  # 任务金额（便士）
                "task_amount_display": f"{task_amount:.2f}",  # 任务金额（显示格式）
                "negotiated_price": str(application.negotiated_price) if application.negotiated_price else "",  # 议价金额
                "pending_approval": "true",  # 标记这是待确认的批准
                "platform": "Link²Ur",  # 平台标识
                "payment_type": "application_approval"  # 支付类型：申请批准
            },
        )

        # 为支付方创建/获取 Customer + EphemeralKey（用于保存卡）
        customer_id, ephemeral_key_secret = await _create_customer_and_ephemeral_key(
            stripe_module=stripe,
            user_id=str(current_user.id),
            user_name=current_user.name or f"User {current_user.id}",
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
        logger.info(f"✅ 批准申请成功: task_id={task_id}, application_id={application_id}, payment_intent_id={payment_intent.id}, amount={task_amount_pence/100:.2f} GBP")
        
        response_data = {
            "message": "请完成支付以确认批准申请",
            "application_id": application_id,
            "task_id": task_id,
            "payment_intent_id": payment_intent.id,
            "client_secret": payment_intent.client_secret,
            "amount": task_amount_pence,
            "amount_display": f"{task_amount_pence / 100:.2f}",
            "currency": "GBP",
            "customer_id": customer_id,
            "ephemeral_key_secret": ephemeral_key_secret,
        }
        
        # 详细的字段检查日志降级为DEBUG（仅在调试时可见）
        logger.debug(f"✅ 创建 PaymentIntent: payment_intent_id={payment_intent.id}, amount={task_amount_pence}, currency=GBP")
        logger.debug(f"✅ PaymentIntent client_secret 存在: {bool(payment_intent.client_secret)}, 长度: {len(payment_intent.client_secret) if payment_intent.client_secret else 0}")
        logger.debug(f"✅ 返回响应数据字段检查:")
        logger.debug(f"  - message: {response_data.get('message')}")
        logger.debug(f"  - application_id: {response_data.get('application_id')} (类型: {type(response_data.get('application_id'))})")
        logger.debug(f"  - task_id: {response_data.get('task_id')} (类型: {type(response_data.get('task_id'))})")
        logger.debug(f"  - payment_intent_id: {response_data.get('payment_intent_id')} (类型: {type(response_data.get('payment_intent_id'))})")
        logger.debug(f"  - client_secret 存在: {bool(response_data.get('client_secret'))}, 类型: {type(response_data.get('client_secret'))}, 长度: {len(response_data.get('client_secret')) if response_data.get('client_secret') else 0}")
        logger.debug(f"  - amount: {response_data.get('amount')} (类型: {type(response_data.get('amount'))})")
        logger.debug(f"  - amount_display: {response_data.get('amount_display')} (类型: {type(response_data.get('amount_display'))})")
        logger.debug(f"  - currency: {response_data.get('currency')} (类型: {type(response_data.get('currency'))})")
        
        return response_data
    
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
                300,  # 5分钟
                json.dumps(token_data_accept)
            )
            
            redis_client.setex(
                f"negotiation_token:{token_reject}",
                300,  # 5分钟
                json.dumps(token_data_reject)
            )
            
            # ⚠️ 额外存储 notification_id -> tokens 映射，方便前端通过 notification_id 获取 token
            # 优化：在存储时也保存过期时间，方便API返回
            expires_at_iso = format_iso_utc(datetime.fromtimestamp(expires_at, tz=timezone.utc))
            redis_client.setex(
                f"negotiation_tokens_by_notification:{notification_id}",
                300,  # 5分钟
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
                except:
                    pass
        
        # 如果没有从token中获取到，基于创建时间+5分钟计算
        if not expires_at:
            notification_created = notification.created_at
            if notification_created:
                from datetime import timedelta
                expires_at_dt = notification_created + timedelta(seconds=300)  # 5分钟
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
            
            # ⚠️ 安全修复：接受议价需要支付，不能直接进入 in_progress
            # 更新任务状态为 pending_payment，等待支付完成
            locked_task.taker_id = application.applicant_id
            locked_task.status = "pending_payment"
            locked_task.is_paid = 0  # 明确标记为未支付
            locked_task.payment_expires_at = get_utc_time() + timedelta(hours=24)  # 支付过期时间（24小时）
            
            # 如果申请包含议价，更新 agreed_reward
            if application.negotiated_price is not None:
                locked_task.agreed_reward = application.negotiated_price
            
            # 计算任务金额
            task_amount = float(application.negotiated_price) if application.negotiated_price is not None else float(locked_task.base_reward) if locked_task.base_reward is not None else 0.0
            
            if task_amount <= 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="任务金额必须大于0，无法进行支付"
                )
            
            task_amount_pence = int(task_amount * 100)
            
            # 计算平台服务费
            from app.utils.fee_calculator import calculate_application_fee_pence
            application_fee_pence = calculate_application_fee_pence(task_amount_pence)
            
            # 获取申请者信息（用于创建 PaymentIntent）
            applicant = await db.get(models.User, application.applicant_id)
            if not applicant:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="申请者不存在"
                )
            
            # 获取接受者的 Stripe Connect 账户ID
            taker_stripe_account_id = applicant.stripe_account_id
            
            if not taker_stripe_account_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="申请者尚未创建 Stripe Connect 收款账户，无法完成支付。请联系申请者先创建收款账户。",
                    headers={"X-Stripe-Connect-Required": "true"}
                )
            
            # 创建 Stripe Payment Intent
            import stripe
            import os
            stripe.api_key = os.getenv("STRIPE_SECRET_KEY")
            
            try:
                payment_intent = stripe.PaymentIntent.create(
                    amount=task_amount_pence,
                    currency="gbp",
                    # 明确指定支付方式类型，确保 WeChat Pay 可用
                    # 注意：不能同时使用 payment_method_types 和 automatic_payment_methods
                    # 必须在 Stripe Dashboard 中启用 WeChat Pay
                    payment_method_types=["card", "wechat_pay", "alipay"],
                    description=f"任务 #{task_id}: {locked_task.title[:50] if locked_task.title else 'Task'} - 接受议价申请 #{application_id}",
                    metadata={
                        "task_id": str(task_id),
                        "task_title": locked_task.title[:200] if locked_task.title else "",
                        "poster_id": str(locked_task.poster_id),
                        "taker_id": str(application.applicant_id),
                        "taker_name": applicant.name if applicant else f"User {application.applicant_id}",
                        "taker_stripe_account_id": taker_stripe_account_id,
                        "application_fee": str(application_fee_pence),
                        "task_amount": str(task_amount_pence),
                        "task_amount_display": f"{task_amount:.2f}",
                        "platform": "Link²Ur",
                        "payment_type": "negotiation_accept",
                        "application_id": str(application_id),
                        "negotiated_price": str(application.negotiated_price) if application.negotiated_price else ""
                    },
                )
                
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
                # 使用 Stripe Search API 查找现有 Customer（通过 metadata.user_id）
                # 注意：Customer.list() 不支持通过 metadata 查询，需要使用 Search API
                try:
                    search_result = stripe.Customer.search(
                        query=f"metadata['user_id']:'{locked_task.poster_id}'",
                        limit=1
                    )
                    if search_result.data:
                        customer_id = search_result.data[0].id
                    else:
                        poster = await db.get(models.User, locked_task.poster_id)
                        customer = stripe.Customer.create(
                            metadata={
                                "user_id": str(locked_task.poster_id),
                                "user_name": poster.name if poster else f"User {locked_task.poster_id}",
                            }
                        )
                        customer_id = customer.id
                except Exception as search_error:
                    # 如果 Search API 不可用或失败，直接创建新的 Customer
                    logger.debug(f"Stripe Search API 不可用，直接创建新 Customer: {search_error}")
                    poster = await db.get(models.User, locked_task.poster_id)
                    customer = stripe.Customer.create(
                        metadata={
                            "user_id": str(locked_task.poster_id),
                            "user_name": poster.name if poster else f"User {locked_task.poster_id}",
                        }
                    )
                    customer_id = customer.id

                ephemeral_key = stripe.EphemeralKey.create(
                    customer=customer_id,
                    stripe_version="2025-04-30.preview",
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
                    title_en="Negotiation Rejected",
                    content_en=f"The applicant has rejected your negotiation offer for task「{task.title}」",
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
            elif notification_type == "application_message" and request.message:
                template_vars["message"] = request.message
            
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
            detail=f"回复留言失败: {str(e)}"
        )

