"""
Message + notification domain routes — extracted from app/routers.py (Task 12).

Includes 19 routes covering chat messages, notifications, device tokens,
contacts, and shared-task lookups:
  - POST/GET messages: send, history, unread, unread/count, unread/by-contact,
    {msg_id}/read, mark-chat-read/{contact_id}
  - GET/POST notifications: list, unread, with-recent-read, unread/count,
    interaction, {id}/read, read-all, send-announcement
  - POST/DELETE /users/device-token
  - GET /contacts, /users/shared-tasks/{other_user_id}

Mounts at both /api and /api/users via main.py.
"""
import logging
from datetime import timezone
from typing import List, Optional

from fastapi import (
    APIRouter,
    BackgroundTasks,
    Body,
    Depends,
    HTTPException,
    Query,
    Request,
    status,
)
from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.orm import Session
from sqlalchemy.ext.asyncio import AsyncSession

from app import async_crud, crud, models, schemas
from app.cache import cache_response
from app.deps import (
    check_user_status,
    get_async_db_dependency,
    get_current_admin_user,
    get_current_user_optional,
    get_current_user_secure_async_csrf,
    get_current_user_secure_sync_csrf,
    get_db,
    get_sync_db,
)
from app.performance_monitor import measure_api_performance
from app.push_notification_service import send_push_notification
from app.rate_limiting import rate_limit
from app.separate_auth_deps import get_current_admin
from app.utils.time_utils import format_iso_utc, get_utc_time

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/messages/send", response_model=schemas.MessageOut)
@rate_limit("send_message")
def send_message_api(
    # ⚠️ DEPRECATED: 此接口已废弃，不再使用
    # 联系人聊天功能已移除，请使用任务聊天接口：
    # POST /api/messages/task/{task_id}/send
    # 此接口已完全禁用，不再创建无任务ID的消息
    msg: schemas.MessageCreate,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    # 完全禁用此接口，返回错误
    raise HTTPException(
        status_code=410,  # 410 Gone - 资源已永久移除
        detail="此接口已废弃。联系人聊天功能已移除，请使用任务聊天接口：POST /api/messages/task/{task_id}/send"
    )


@router.get("/messages/history/{user_id}", response_model=list[schemas.MessageOut])
def get_chat_history_api(
    # ⚠️ DEPRECATED: 此接口已废弃，不再使用
    # 联系人聊天功能已移除，请使用任务聊天接口：
    # GET /api/messages/task/{task_id}
    # 此接口保留仅用于向后兼容，可能会在未来的版本中移除
    user_id: str,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0, le=100000),
    session_id: int = None,
):
    # 如果提供了session_id，直接使用它
    if session_id is not None:
        return crud.get_chat_history(
            db, current_user.id, user_id, limit, offset, session_id=session_id
        )

    # 普通用户之间的消息
    return crud.get_chat_history(db, current_user.id, user_id, limit, offset)


@router.get("/messages/unread", response_model=list[schemas.MessageOut])
def get_unread_messages_api(
    current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    try:
        messages = crud.get_unread_messages(db, current_user.id)
        # 过滤并修复消息：确保 sender_id 和 receiver_id 都不为 None
        valid_messages = []
        for msg in messages:
            # 跳过 sender_id 为 None 的消息（系统消息）
            if msg.sender_id is None:
                continue
            # 对于任务消息，receiver_id 可能为 None，设置为当前用户ID
            # 因为这是未读消息，肯定是发送给当前用户的
            if msg.receiver_id is None:
                setattr(msg, 'receiver_id', current_user.id)
            valid_messages.append(msg)
        return valid_messages
    except Exception as e:
        from fastapi import HTTPException
        raise HTTPException(status_code=500, detail=f"获取未读消息失败: {str(e)}")


@router.get("/messages/unread/count")
def get_unread_count_api(
    debug: bool = False,
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    unread_messages = crud.get_unread_messages(db, current_user.id)
    result = {"unread_count": len(unread_messages)}
    
    if debug:
        from app.models import Task, TaskParticipant
        
        # 调试模式：返回每条未读消息的详细信息
        debug_details = []
        for msg in unread_messages:
            debug_details.append({
                "message_id": msg.id,
                "task_id": msg.task_id,
                "sender_id": msg.sender_id,
                "content": (msg.content[:80] + '...') if msg.content and len(msg.content) > 80 else msg.content,
                "message_type": msg.message_type,
                "conversation_type": msg.conversation_type,
                "created_at": msg.created_at.isoformat() if msg.created_at else None,
            })
        
        # 按 task_id 分组统计，并查询任务详情
        task_unread_map = {}
        for msg in unread_messages:
            tid = msg.task_id
            if tid not in task_unread_map:
                task_unread_map[tid] = {"task_id": tid, "count": 0, "latest_message": None}
            task_unread_map[tid]["count"] += 1
            if task_unread_map[tid]["latest_message"] is None:
                task_unread_map[tid]["latest_message"] = {
                    "message_id": msg.id,
                    "sender_id": msg.sender_id,
                    "content": (msg.content[:50] + '...') if msg.content and len(msg.content) > 50 else msg.content,
                    "created_at": msg.created_at.isoformat() if msg.created_at else None,
                }
        
        # 查询每个有未读消息的任务的详细信息
        for tid in task_unread_map:
            task = db.query(Task).filter(Task.id == tid).first()
            if task:
                task_info = {
                    "title": task.title[:50] if task.title else None,
                    "status": task.status,
                    "poster_id": task.poster_id,
                    "taker_id": task.taker_id,
                    "is_multi_participant": getattr(task, 'is_multi_participant', False),
                    "user_is_poster": str(task.poster_id) == str(current_user.id),
                    "user_is_taker": str(task.taker_id) == str(current_user.id) if task.taker_id else False,
                }
                # 查询用户在该任务中的参与者身份
                participant = db.query(TaskParticipant).filter(
                    TaskParticipant.task_id == tid,
                    TaskParticipant.user_id == current_user.id
                ).first()
                if participant:
                    task_info["participant_status"] = participant.status
                    task_info["participant_role"] = getattr(participant, 'role', None)
                else:
                    task_info["participant_status"] = None
                    task_info["participant_role"] = None
                task_unread_map[tid]["task_info"] = task_info
            else:
                task_unread_map[tid]["task_info"] = {"error": "任务不存在(已删除?)"}
        
        result["debug"] = {
            "user_id": current_user.id,
            "total_unread": len(unread_messages),
            "by_task": list(task_unread_map.values()),
            "messages": debug_details
        }
    
    return result


@router.get("/messages/unread/by-contact")
def get_unread_count_by_contact_api(
    current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """
    ⚠️ DEPRECATED: 此接口已废弃，不再使用
    联系人聊天功能已移除，请使用任务聊天接口：
    GET /api/messages/tasks (获取任务列表，包含未读消息数)
    此接口保留仅用于向后兼容，可能会在未来的版本中移除
    
    获取每个联系人的未读消息数量（已废弃）
    """
    from app.models import Message
    from sqlalchemy import func as sa_func
    
    rows = (
        db.query(Message.sender_id, sa_func.count(Message.id))
        .filter(
            Message.receiver_id == current_user.id,
            Message.is_read == 0,
            Message.sender_id.isnot(None),
        )
        .group_by(Message.sender_id)
        .all()
    )
    contact_counts = {str(sender_id): cnt for sender_id, cnt in rows}
    
    return {"contact_unread_counts": contact_counts}


@router.post("/messages/{msg_id}/read", response_model=schemas.MessageOut)
def mark_message_read_api(
    msg_id: int, current_user=Depends(check_user_status), db: Session = Depends(get_db)
):
    return crud.mark_message_read(db, msg_id, current_user.id)


@router.post("/messages/mark-chat-read/{contact_id}")
def mark_chat_messages_read_api(
    contact_id: str, current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)
):
    """
    ⚠️ DEPRECATED: 此接口已废弃，不再使用
    联系人聊天功能已移除，请使用任务聊天接口：
    POST /api/messages/task/{task_id}/read
    此接口保留仅用于向后兼容，可能会在未来的版本中移除
    
    标记与指定联系人的所有消息为已读（已废弃）
    """
    try:
        from app.models import Message
        
        
        # 获取与指定联系人的所有未读消息
        unread_messages = (
            db.query(Message)
            .filter(
                Message.receiver_id == current_user.id,
                Message.sender_id == contact_id,
                Message.is_read == 0
            )
            .all()
        )
        
        
        # 标记所有未读消息为已读
        for msg in unread_messages:
            msg.is_read = 1
        
        db.commit()
        
        return {
            "message": f"已标记与用户 {contact_id} 的 {len(unread_messages)} 条消息为已读",
            "marked_count": len(unread_messages)
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"标记消息为已读失败: {str(e)}")


# 已迁移到 admin_customer_service_routes.py: /admin/messages


# 通知相关API（已迁移为 async 以提升并发）
@router.get("/notifications", response_model=None)
@cache_response(ttl=30, key_prefix="notifications")
async def get_notifications_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    page: int = Query(1, ge=1, description="页码"),
    page_size: int = Query(20, ge=1, le=100, description="每页数量"),
    limit: Optional[int] = Query(None, ge=1, le=100, description="兼容旧版：直接限制条数"),
):
    """
    获取系统通知列表（排除排行榜互动类型）。
    Page 1: 全部未读 + 前 page_size 条已读
    Page 2+: 继续加载已读
    兼容旧版 limit 参数。
    """
    from app.utils.notification_utils import enrich_notifications_with_task_id_async

    leaderboard_interaction_types = ["leaderboard_vote", "leaderboard_like"]

    if limit is not None:
        notifications = await async_crud.async_notification_crud.get_user_notifications(
            db, current_user.id, skip=0, limit=limit, unread_only=False
        )
        enriched = await enrich_notifications_with_task_id_async(notifications, db)
        return [n for n in enriched if n.type not in leaderboard_interaction_types]

    all_notifications = await async_crud.async_notification_crud.get_user_notifications(
        db, current_user.id, skip=0, limit=1000, unread_only=False
    )
    enriched = await enrich_notifications_with_task_id_async(all_notifications, db)
    filtered = [n for n in enriched if n.type not in leaderboard_interaction_types]

    unread = [n for n in filtered if n.is_read == 0]
    read = [n for n in filtered if n.is_read != 0]

    if page == 1:
        read_page = read[:page_size]
        result = unread + read_page
    else:
        offset = (page - 1) * page_size
        result = read[offset:offset + page_size]

    has_more = len(read) > page * page_size

    return {
        "notifications": result,
        "total": len(filtered),
        "page": page,
        "page_size": page_size,
        "has_more": has_more,
    }


@router.get("/notifications/unread", response_model=list[schemas.NotificationOut])
async def get_unread_notifications_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """获取未读通知，支持分页（Flutter 传 page、page_size）"""
    from app.utils.notification_utils import enrich_notifications_with_task_id_async

    notifications = await async_crud.async_notification_crud.get_user_notifications(
        db, current_user.id, skip=(page - 1) * page_size, limit=page_size, unread_only=True
    )
    return await enrich_notifications_with_task_id_async(notifications, db)


@router.get("/notifications/with-recent-read", response_model=list[schemas.NotificationOut])
async def get_notifications_with_recent_read_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    recent_read_limit: int = Query(10, ge=1, le=100),
):
    """获取所有未读通知和最近N条已读通知"""
    from app.utils.notification_utils import enrich_notifications_with_task_id_async

    notifications = await async_crud.async_notification_crud.get_notifications_with_recent_read(
        db, current_user.id, recent_read_limit
    )
    return await enrich_notifications_with_task_id_async(notifications, db)


@router.get("/notifications/unread/count")
@cache_response(ttl=30, key_prefix="notifications")
async def get_unread_notification_count_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    system_count = await async_crud.async_notification_crud.get_unread_notification_count(
        db, current_user.id
    )
    leaderboard_interaction_types = ["leaderboard_vote", "leaderboard_like"]
    lb_unread_result = await db.execute(
        select(func.count()).select_from(models.Notification).where(
            models.Notification.user_id == current_user.id,
            models.Notification.is_read == 0,
            models.Notification.type.in_(leaderboard_interaction_types),
        )
    )
    lb_unread = lb_unread_result.scalar() or 0

    # --- 论坛未读：必须与 /notifications/interaction 列表端点一致，
    #     只统计用户可见板块（general + 本校）内的通知 ---
    from app.forum_routes import visible_forums

    visible_category_ids = []
    gen_res = await db.execute(
        select(models.ForumCategory.id).where(
            models.ForumCategory.type == 'general',
            models.ForumCategory.is_visible == True
        )
    )
    visible_category_ids.extend([r[0] for r in gen_res.all()])
    school_ids = await visible_forums(current_user, db)
    visible_category_ids.extend(school_ids)

    # 取所有未读论坛通知
    forum_unread_rows = await db.execute(
        select(
            models.ForumNotification.id,
            models.ForumNotification.target_type,
            models.ForumNotification.target_id,
        ).where(
            models.ForumNotification.to_user_id == current_user.id,
            models.ForumNotification.is_read == False,
        )
    )
    unread_forum_list = forum_unread_rows.all()

    # 按 target_type 分组，批量查 category_id
    post_ids = [r.target_id for r in unread_forum_list if r.target_type == "post"]
    reply_ids = [r.target_id for r in unread_forum_list if r.target_type == "reply"]

    post_cat_map = {}
    if post_ids:
        res = await db.execute(
            select(models.ForumPost.id, models.ForumPost.category_id)
            .where(models.ForumPost.id.in_(post_ids))
        )
        post_cat_map = {r[0]: r[1] for r in res.all()}

    reply_cat_map = {}
    if reply_ids:
        res = await db.execute(
            select(models.ForumReply.id, models.ForumReply.post_id)
            .where(models.ForumReply.id.in_(reply_ids))
        )
        reply_post_map = {r[0]: r[1] for r in res.all()}
        if reply_post_map:
            res2 = await db.execute(
                select(models.ForumPost.id, models.ForumPost.category_id)
                .where(models.ForumPost.id.in_(list(reply_post_map.values())))
            )
            pid_cat = {r[0]: r[1] for r in res2.all()}
            reply_cat_map = {
                rid: pid_cat.get(pid)
                for rid, pid in reply_post_map.items()
                if pid in pid_cat
            }

    forum_unread = 0
    for r in unread_forum_list:
        if r.target_type == "post":
            cat_id = post_cat_map.get(r.target_id)
        else:
            cat_id = reply_cat_map.get(r.target_id)
        if cat_id and cat_id in visible_category_ids:
            forum_unread += 1

    return {
        "unread_count": system_count - lb_unread,
        "forum_count": forum_unread + lb_unread,
    }


@router.get("/notifications/interaction")
async def get_interaction_notifications_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    """
    获取互动消息（统一接口）
    合并论坛通知 + 排行榜互动通知，按时间倒序排列，支持分页。
    Page 1: 全部未读 + 前 page_size 条已读
    Page 2+: 继续加载已读
    """
    from sqlalchemy.orm import selectinload
    from app.forum_routes import visible_forums

    # === 1. 查论坛通知 ===
    forum_query = (
        select(models.ForumNotification)
        .where(models.ForumNotification.to_user_id == current_user.id)
        .order_by(models.ForumNotification.created_at.desc())
        .options(selectinload(models.ForumNotification.from_user))
    )
    forum_result = await db.execute(forum_query)
    all_forum = forum_result.scalars().all()

    # 过滤学校板块
    visible_category_ids = []
    general_result = await db.execute(
        select(models.ForumCategory.id).where(
            models.ForumCategory.type == 'general',
            models.ForumCategory.is_visible == True
        )
    )
    visible_category_ids.extend([r[0] for r in general_result.all()])
    school_ids = await visible_forums(current_user, db)
    visible_category_ids.extend(school_ids)

    # 批量查 post/reply 的 category_id
    post_notifs = [n for n in all_forum if n.target_type == "post"]
    reply_notifs = [n for n in all_forum if n.target_type == "reply"]

    post_category_map = {}
    if post_notifs:
        res = await db.execute(
            select(models.ForumPost.id, models.ForumPost.category_id)
            .where(models.ForumPost.id.in_([n.target_id for n in post_notifs]))
        )
        post_category_map = {r[0]: r[1] for r in res.all()}

    reply_post_map = {}
    reply_category_map = {}
    if reply_notifs:
        res = await db.execute(
            select(models.ForumReply.id, models.ForumReply.post_id)
            .where(models.ForumReply.id.in_([n.target_id for n in reply_notifs]))
        )
        reply_post_map = {r[0]: r[1] for r in res.all()}
        if reply_post_map:
            res2 = await db.execute(
                select(models.ForumPost.id, models.ForumPost.category_id)
                .where(models.ForumPost.id.in_(list(reply_post_map.values())))
            )
            pid_to_cat = {r[0]: r[1] for r in res2.all()}
            reply_category_map = {
                rid: pid_to_cat.get(pid)
                for rid, pid in reply_post_map.items()
                if pid in pid_to_cat
            }

    # 转换论坛通知为统一格式
    forum_converted = []
    _type_labels = {
        "reply_post": ("回复了你的帖子", "replied to your post"),
        "reply_reply": ("回复了你的评论", "replied to your comment"),
        "like_post": ("点赞了你的帖子", "liked your post"),
        "feature_post": ("精选了你的帖子", "featured your post"),
        "pin_post": ("置顶了你的帖子", "pinned your post"),
    }

    for n in all_forum:
        if n.target_type == "post":
            cat_id = post_category_map.get(n.target_id)
        else:
            cat_id = reply_category_map.get(n.target_id)
        if not cat_id or cat_id not in visible_category_ids:
            continue

        if n.target_type == "reply":
            post_id = reply_post_map.get(n.target_id)
        else:
            post_id = n.target_id

        from_name = n.from_user.name if n.from_user else "某人"
        from_name_en = n.from_user.name if n.from_user else "Someone"
        label_zh, label_en = _type_labels.get(
            n.notification_type, ("与你互动", "interacted with you")
        )

        forum_converted.append({
            "id": n.id,
            "user_id": current_user.id,
            "type": f"forum_{n.notification_type}",
            "title": f"{from_name}{label_zh}",
            "content": f"{from_name}{label_zh}",
            "title_en": f"{from_name_en} {label_en}",
            "content_en": f"{from_name_en} {label_en}",
            "related_id": post_id,
            "related_type": "forum_post_id",
            "is_read": 1 if n.is_read else 0,
            "created_at": n.created_at,
            "task_id": None,
            "variables": None,
        })

    # === 2. 查排行榜互动通知 ===
    leaderboard_types = ["leaderboard_vote", "leaderboard_like"]
    lb_result = await db.execute(
        select(models.Notification)
        .where(
            models.Notification.user_id == current_user.id,
            models.Notification.type.in_(leaderboard_types),
        )
        .order_by(models.Notification.created_at.desc())
    )
    lb_notifications = lb_result.scalars().all()

    lb_converted = []
    for n in lb_notifications:
        lb_converted.append({
            "id": n.id,
            "user_id": n.user_id,
            "type": n.type,
            "title": n.title,
            "content": n.content,
            "title_en": n.title_en,
            "content_en": n.content_en,
            "related_id": n.related_id,
            "related_type": n.related_type,
            "is_read": n.is_read,
            "created_at": n.created_at,
            "task_id": None,
            "variables": None,
        })

    # === 3. 合并 + 未读优先分页 ===
    from datetime import datetime as dt
    all_items = forum_converted + lb_converted
    unread_items = [x for x in all_items if x["is_read"] in (False, 0)]
    read_items = [x for x in all_items if x["is_read"] not in (False, 0)]

    unread_items.sort(key=lambda x: x["created_at"] or dt.min, reverse=True)
    read_items.sort(key=lambda x: x["created_at"] or dt.min, reverse=True)

    if page == 1:
        read_page = read_items[:page_size]
        result_items = unread_items + read_page
    else:
        offset = (page - 1) * page_size
        read_page = read_items[offset:offset + page_size]
        result_items = read_page

    has_more = len(read_items) > page * page_size

    return {
        "notifications": result_items,
        "total": len(all_items),
        "page": page,
        "page_size": page_size,
        "has_more": has_more,
    }


@router.post(
    "/notifications/{notification_id}/read", response_model=schemas.NotificationOut
)
async def mark_notification_read_api(
    notification_id: int,
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    from app.utils.notification_utils import enrich_notification_dict_with_task_id_async

    notification = await async_crud.async_notification_crud.mark_notification_as_read(
        db, notification_id, current_user.id
    )
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")
    notification_dict = schemas.NotificationOut.model_validate(notification).model_dump()
    enriched_dict = await enrich_notification_dict_with_task_id_async(
        notification, notification_dict, db
    )
    return schemas.NotificationOut(**enriched_dict)


@router.post("/users/device-token")
def register_device_token(
    request: Request,
    device_token_data: schemas.DeviceTokenRegister,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """注册或更新设备推送令牌"""
    import logging
    from sqlalchemy.exc import IntegrityError
    logger = logging.getLogger(__name__)
    
    device_token = device_token_data.device_token
    platform = device_token_data.platform
    device_id = device_token_data.device_id  # 可能为 None 或空字符串
    app_version = device_token_data.app_version  # 可能为 None 或空字符串
    device_language = device_token_data.device_language  # 设备系统语言（zh 或 en）
    
    # 验证和规范化设备语言
    # 只有中文使用中文推送，其他所有语言都使用英文推送
    if device_language:
        device_language = device_language.strip().lower()
        if device_language.startswith('zh'):
            device_language = 'zh'  # 中文
        else:
            device_language = 'en'  # 其他所有语言都使用英文
    else:
        device_language = 'en'  # 默认英文
    
    logger.debug(f"[DEVICE_TOKEN] 用户 {current_user.id} 尝试注册设备令牌: platform={platform}, app_version={app_version}, device_id={device_id or '未提供'}, device_language={device_language}")
    
    if not device_token:
        raise HTTPException(status_code=400, detail="device_token is required")
    
    # 查找是否已存在该设备令牌（当前用户的）
    existing_token = db.query(models.DeviceToken).filter(
        models.DeviceToken.user_id == current_user.id,
        models.DeviceToken.device_token == device_token
    ).first()
    
    # ---- 节流：如果令牌已存在且信息无变化，10 分钟内跳过写库 ----
    from datetime import timedelta
    THROTTLE_MINUTES = 10
    if existing_token and existing_token.is_active:
        now = get_utc_time()
        recently_updated = (
            existing_token.last_used_at
            and (now - existing_token.last_used_at) < timedelta(minutes=THROTTLE_MINUTES)
        )
        info_unchanged = (
            existing_token.platform == platform
            and existing_token.device_language == device_language
            and (not (device_id and device_id.strip()) or existing_token.device_id == device_id)
            and (not (app_version and app_version.strip()) or existing_token.app_version == app_version)
        )
        if recently_updated and info_unchanged:
            logger.debug(f"[DEVICE_TOKEN] 用户 {current_user.id} 的设备令牌无变化且在 {THROTTLE_MINUTES} 分钟内已更新，跳过写库: token_id={existing_token.id}")
            return {"message": "Device token up-to-date", "token_id": existing_token.id}
    
    # 在注册/更新令牌前，禁用同一 device_id 的所有其他旧令牌（包括其他用户的）
    if device_id and device_id.strip():
        deactivated_own = db.query(models.DeviceToken).filter(
            models.DeviceToken.user_id == current_user.id,
            models.DeviceToken.device_id == device_id,
            models.DeviceToken.device_token != device_token,
            models.DeviceToken.is_active == True
        ).update({"is_active": False, "updated_at": get_utc_time()})
        if deactivated_own > 0:
            logger.info(f"[DEVICE_TOKEN] 已禁用同一 device_id 的 {deactivated_own} 个当前用户旧令牌: user_id={current_user.id}, device_id={device_id}")
        
        deactivated_others = db.query(models.DeviceToken).filter(
            models.DeviceToken.user_id != current_user.id,
            models.DeviceToken.device_id == device_id,
            models.DeviceToken.is_active == True
        ).update({"is_active": False, "updated_at": get_utc_time()})
        if deactivated_others > 0:
            logger.info(f"[DEVICE_TOKEN] 已禁用同一 device_id 上其他用户的 {deactivated_others} 个令牌（账号切换）: device_id={device_id}")
    
    deactivated_same_token = db.query(models.DeviceToken).filter(
        models.DeviceToken.user_id != current_user.id,
        models.DeviceToken.device_token == device_token,
        models.DeviceToken.is_active == True
    ).update({"is_active": False, "updated_at": get_utc_time()})
    if deactivated_same_token > 0:
        logger.info(f"[DEVICE_TOKEN] 已禁用其他用户持有的相同 device_token 的 {deactivated_same_token} 个记录")
    
    if existing_token:
        existing_token.is_active = True
        existing_token.platform = platform
        existing_token.device_language = device_language
        
        if device_id and device_id.strip():
            old_device_id = existing_token.device_id
            existing_token.device_id = device_id
            if old_device_id != device_id:
                logger.debug(f"[DEVICE_TOKEN] device_id 已更新: {old_device_id or '未设置'} -> {device_id}")
        
        if app_version and app_version.strip():
            existing_token.app_version = app_version
        
        existing_token.updated_at = get_utc_time()
        existing_token.last_used_at = get_utc_time()
        db.commit()
        logger.info(f"[DEVICE_TOKEN] 用户 {current_user.id} 的设备令牌已更新: token_id={existing_token.id}, device_id={existing_token.device_id or '未设置'}, device_language={existing_token.device_language}")
        return {"message": "Device token updated", "token_id": existing_token.id}
    else:
        # 创建新令牌
        # 使用 try-except 处理并发插入时的唯一约束冲突
        try:
            new_token = models.DeviceToken(
                user_id=current_user.id,
                device_token=device_token,
                platform=platform,
                device_id=device_id,
                app_version=app_version,
                device_language=device_language,  # 设置设备语言
                is_active=True,
                last_used_at=get_utc_time()
            )
            db.add(new_token)
            db.commit()
            db.refresh(new_token)
            logger.info(f"[DEVICE_TOKEN] 用户 {current_user.id} 的设备令牌已注册: token_id={new_token.id}, device_token={device_token[:20]}..., device_id={new_token.device_id or '未设置'}")
            return {"message": "Device token registered", "token_id": new_token.id}
        except IntegrityError as e:
            # 处理并发插入时的唯一约束冲突
            # 回滚当前事务
            db.rollback()
            
            # 重新查询已存在的令牌（可能由另一个并发请求插入）
            existing_token = db.query(models.DeviceToken).filter(
                models.DeviceToken.user_id == current_user.id,
                models.DeviceToken.device_token == device_token
            ).first()
            
            if existing_token:
                # 禁用同一 device_id 的其他旧令牌（并发处理时也需要）
                if device_id and device_id.strip():
                    deactivated_count = db.query(models.DeviceToken).filter(
                        models.DeviceToken.user_id == current_user.id,
                        models.DeviceToken.device_id == device_id,
                        models.DeviceToken.device_token != device_token,
                        models.DeviceToken.is_active == True
                    ).update({"is_active": False, "updated_at": get_utc_time()})
                    if deactivated_count > 0:
                        logger.info(f"[DEVICE_TOKEN] 已禁用同一 device_id 的 {deactivated_count} 个旧令牌（并发处理）: user_id={current_user.id}, device_id={device_id}")
                
                # 更新现有令牌
                existing_token.is_active = True
                existing_token.platform = platform
                existing_token.device_language = device_language
                
                # 更新 device_id
                if device_id and device_id.strip():
                    existing_token.device_id = device_id
                
                # 更新 app_version
                if app_version and app_version.strip():
                    existing_token.app_version = app_version
                
                existing_token.updated_at = get_utc_time()
                existing_token.last_used_at = get_utc_time()
                db.commit()
                logger.info(f"[DEVICE_TOKEN] 用户 {current_user.id} 的设备令牌已更新（处理并发冲突）: token_id={existing_token.id}, device_id={existing_token.device_id or '未设置'}, device_language={existing_token.device_language}")
                return {"message": "Device token updated", "token_id": existing_token.id}
            else:
                # 如果仍然找不到，记录错误并重新抛出异常
                logger.error(f"[DEVICE_TOKEN] 唯一约束冲突但未找到现有令牌: user_id={current_user.id}, device_token={device_token[:20]}...")
                raise HTTPException(status_code=500, detail="Failed to register device token due to concurrent conflict")


@router.delete("/users/device-token")
def unregister_device_token(
    device_token_data: schemas.DeviceTokenUnregister,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """注销设备推送令牌 - 标记为不活跃而非删除
    
    登出或切换账号时调用此接口，将设备令牌标记为不活跃，
    而不是完全删除，这样可以：
    1. 保留历史记录用于调试
    2. 重新登录时可以快速重新激活
    3. 避免删除后重新注册时的竞态条件
    """
    logger = logging.getLogger(__name__)
    device_token = device_token_data.device_token
    
    # 查找令牌并标记为不活跃（而不是删除）
    updated = db.query(models.DeviceToken).filter(
        models.DeviceToken.user_id == current_user.id,
        models.DeviceToken.device_token == device_token
    ).update({"is_active": False, "updated_at": get_utc_time()})
    
    db.commit()
    
    if updated > 0:
        logger.info(f"[DEVICE_TOKEN] 用户 {current_user.id} 的设备令牌已标记为不活跃（登出）: token={device_token[:20]}...")
        return {"message": "Device token deactivated"}
    else:
        # 令牌不存在时也返回成功（幂等操作，避免客户端重试问题）
        logger.info(f"[DEVICE_TOKEN] 用户 {current_user.id} 的设备令牌未找到或已不活跃: token={device_token[:20]}...")
        return {"message": "Device token not found or already deactivated"}


@router.post("/notifications/read-all")
async def mark_all_notifications_read_api(
    current_user: models.User = Depends(get_current_user_secure_async_csrf),
    db: AsyncSession = Depends(get_async_db_dependency),
    type: Optional[str] = Query(None, description="system, interaction, or all (default: all)"),
):
    """
    标记通知为已读。
    type=system: 只标记系统通知（排除 leaderboard_vote/like）
    type=interaction: 标记论坛通知 + 排行榜互动通知
    type=all 或 None: 标记全部
    """
    effective_type = type or "all"
    leaderboard_interaction_types = ["leaderboard_vote", "leaderboard_like"]

    if effective_type in ("system", "all"):
        if effective_type == "system":
            await db.execute(
                update(models.Notification)
                .where(
                    models.Notification.user_id == current_user.id,
                    models.Notification.is_read == 0,
                    models.Notification.type.notin_(leaderboard_interaction_types),
                )
                .values(is_read=1)
            )
        else:
            await async_crud.async_notification_crud.mark_all_notifications_read(
                db, current_user.id
            )

    if effective_type in ("interaction", "all"):
        await db.execute(
            update(models.ForumNotification)
            .where(
                models.ForumNotification.to_user_id == current_user.id,
                models.ForumNotification.is_read == False,
            )
            .values(is_read=True)
        )
        if effective_type == "interaction":
            await db.execute(
                update(models.Notification)
                .where(
                    models.Notification.user_id == current_user.id,
                    models.Notification.is_read == 0,
                    models.Notification.type.in_(leaderboard_interaction_types),
                )
                .values(is_read=1)
            )

    await db.commit()
    return {"message": "Notifications marked as read"}


@router.post("/notifications/send-announcement")
def send_announcement_api(
    announcement: schemas.AnnouncementCreate,
    current_user=Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """发送平台公告给所有用户"""
    from app.models import User

    # 获取所有用户（分批处理，防止内存溢出）
    # 使用 yield_per 分批加载，每批最多 1000 个用户
    users_query = db.query(User)
    total_users = users_query.count()
    
    # 如果用户数量过多，分批处理
    batch_size = 1000
    if total_users > batch_size:
        logger.warning(f"用户数量过多 ({total_users})，将分批处理，每批 {batch_size} 个")
    
    # 分批处理用户
    offset = 0
    processed_count = 0
    while offset < total_users:
        users = users_query.offset(offset).limit(batch_size).all()
        if not users:
            break
            
        # 为每个用户创建公告通知
        for user in users:
            try:
                crud.create_notification(
                    db,
                    user.id,
                    "announcement",
                    announcement.title,
                    announcement.content,
                    None,
                )
                processed_count += 1
            except Exception as e:
                logger.error(f"创建通知失败，用户ID: {user.id}, 错误: {e}")
        
        # 更新偏移量
        offset += batch_size
        # 每批处理后提交一次，避免事务过大
        db.commit()
    
    return {"message": f"Announcement sent to {processed_count} users"}


@router.get("/contacts")
@measure_api_performance("get_contacts")
@cache_response(ttl=180, key_prefix="user_contacts")  # 缓存3分钟
def get_contacts(current_user=Depends(get_current_user_secure_sync_csrf), db: Session = Depends(get_db)):
    try:
        from app.models import Message, User
        
        logger.debug(f"开始获取联系人，用户ID: {current_user.id}")

        # 简化版本：直接获取所有与当前用户有消息往来的用户
        # 获取发送的消息
        sent_contacts = db.query(Message.receiver_id).filter(
            Message.sender_id == current_user.id
        ).distinct().all()
        
        # 获取接收的消息
        received_contacts = db.query(Message.sender_id).filter(
            Message.receiver_id == current_user.id
        ).distinct().all()

        # 合并并去重
        contact_ids = set()
        for result in sent_contacts:
            if result[0]:
                contact_ids.add(result[0])
        for result in received_contacts:
            if result[0]:
                contact_ids.add(result[0])

        # 排除自己
        contact_ids.discard(current_user.id)
        
        logger.debug(f"找到 {len(contact_ids)} 个联系人ID: {list(contact_ids)}")

        if not contact_ids:
            logger.debug("没有找到联系人，返回空列表")
            return []

        # 使用一次查询获取所有用户信息和最新消息时间
        from sqlalchemy import func, case
        
        # 构建联系人ID列表用于IN查询
        contact_id_list = list(contact_ids)
        
        # 一次性查询所有用户信息
        users_query = db.query(User).filter(User.id.in_(contact_id_list)).all()
        users_dict = {user.id: user for user in users_query}
        
        # 一次性查询所有最新消息时间
        latest_messages = db.query(
            case(
                (Message.sender_id == current_user.id, Message.receiver_id),
                else_=Message.sender_id
            ).label('contact_id'),
            func.max(Message.created_at).label('last_message_time')
        ).filter(
            ((Message.sender_id == current_user.id) & (Message.receiver_id.in_(contact_id_list))) |
            ((Message.receiver_id == current_user.id) & (Message.sender_id.in_(contact_id_list)))
        ).group_by(
            case(
                (Message.sender_id == current_user.id, Message.receiver_id),
                else_=Message.sender_id
            )
        ).all()
        
        # 确保时间格式正确，添加时区信息
        latest_messages_dict = {}
        for msg in latest_messages:
            if msg.last_message_time:
                # 确保时间是UTC格式，添加Z后缀
                if msg.last_message_time.tzinfo is None:
                    # 假设是UTC时间，添加时区信息
                    utc_time = msg.last_message_time.replace(tzinfo=timezone.utc)
                else:
                    utc_time = msg.last_message_time.astimezone(timezone.utc)
                latest_messages_dict[msg.contact_id] = format_iso_utc(utc_time)
            else:
                latest_messages_dict[msg.contact_id] = None
        
        # 构建联系人信息
        contacts_with_last_message = []
        for contact_id in contact_id_list:
            user = users_dict.get(contact_id)
            if user:
                contact_info = {
                    "id": user.id,
                    "name": getattr(user, 'name', None) or f"用户{user.id}",
                    "avatar": getattr(user, 'avatar', None) or "/static/avatar1.png",
                    "email": getattr(user, 'email', None),
                    "user_level": 1,  # 默认等级
                    "task_count": 0,
                    "avg_rating": 0.0,
                    "last_message_time": latest_messages_dict.get(contact_id),
                    "is_verified": False
                }
                contacts_with_last_message.append(contact_info)
                logger.debug(f"添加联系人: {contact_info['name']} (ID: {contact_info['id']})")
        
        # 按最新消息时间排序
        contacts_with_last_message.sort(
            key=lambda x: x["last_message_time"] or "1970-01-01T00:00:00", 
            reverse=True
        )

        logger.debug(f"成功获取 {len(contacts_with_last_message)} 个联系人")
        return contacts_with_last_message
        
    except Exception as e:
        logger.warning(f"contacts API发生错误: {e}", exc_info=True)
        return []


@router.get("/users/shared-tasks/{other_user_id}")
def get_shared_tasks(
    other_user_id: str,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
):
    """获取当前用户与指定用户之间的共同任务"""
    from app.models import Task

    # 查找当前用户和对方用户都参与的任务
    # 任务状态为 'taken' 或 'pending_confirmation' 或 'completed'
    shared_tasks = (
        db.query(Task)
        .filter(
            Task.status.in_(["taken", "pending_confirmation", "completed"]),
            Task.is_visible == True,
            ((Task.poster_id == current_user.id) & (Task.taker_id == other_user_id))
            | ((Task.poster_id == other_user_id) & (Task.taker_id == current_user.id)),
        )
        .order_by(Task.created_at.desc())
        .all()
    )

    return [
        {
            "id": task.id,
            "title": task.title,
            "status": task.status,
            "created_at": task.created_at,
            "reward": float(task.agreed_reward) if task.agreed_reward is not None else float(task.base_reward) if task.base_reward is not None else 0.0,
            "task_type": task.task_type,
            "is_poster": task.poster_id == current_user.id,
        }
        for task in shared_tasks
    ]


# 已迁移到 admin_task_management_routes.py: /admin/cancel-requests, /admin/cancel-requests/{request_id}/review


