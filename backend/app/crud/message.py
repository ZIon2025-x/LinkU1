"""消息相关 CRUD，独立模块便于维护与测试。"""
import logging
from datetime import timedelta

from sqlalchemy import and_, exists, not_, or_, select
from sqlalchemy.orm import Session

from app import models
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)


def send_message(
    db: Session,
    sender_id: str,
    receiver_id: str,
    content: str,
    message_id: str = None,
    timezone_str: str = "Europe/London",
    local_time_str: str = None,
    image_id: str = None,
):
    from app.models import Message

    if message_id:
        existing_by_id = (
            db.query(Message)
            .filter(Message.sender_id == sender_id)
            .filter(Message.content == content)
            .filter(
                Message.created_at >= get_utc_time() - timedelta(minutes=1)
            )
            .first()
        )
        if existing_by_id:
            logger.debug(
                f"检测到重复消息ID，跳过保存: {message_id}"
            )
            return existing_by_id

    recent_time = get_utc_time() - timedelta(seconds=5)
    existing_message = (
        db.query(Message)
        .filter(
            Message.sender_id == sender_id,
            Message.receiver_id == receiver_id,
            Message.content == content,
            Message.created_at >= recent_time,
        )
        .order_by(Message.created_at.desc())
        .first()
    )
    if existing_message:
        logger.debug(
            f"检测到重复消息，跳过保存: {content} (时间差: {(get_utc_time() - existing_message.created_at).total_seconds():.2f}秒)"
        )
        return existing_message

    if local_time_str:
        from datetime import datetime as dt

        from app.utils.time_utils import LONDON, parse_local_as_utc
        from zoneinfo import ZoneInfo

        if "T" in local_time_str:
            local_dt = dt.fromisoformat(
                local_time_str.replace("Z", "+00:00")
            )
        else:
            local_dt = dt.strptime(local_time_str, "%Y-%m-%d %H:%M")
        if local_dt.tzinfo is not None:
            local_dt = local_dt.replace(tzinfo=None)
        tz = (
            ZoneInfo(timezone_str)
            if timezone_str != "Europe/London"
            else LONDON
        )
        utc_time = parse_local_as_utc(local_dt, tz)
    else:
        utc_time = get_utc_time()

    msg_data = {
        "sender_id": sender_id,
        "receiver_id": receiver_id,
        "content": content,
        "created_at": utc_time,
    }
    if hasattr(Message, "image_id") and image_id:
        msg_data["image_id"] = image_id
        logger.debug(f"设置image_id: {image_id}")
    else:
        logger.debug(
            f"未设置image_id - hasattr: {hasattr(Message, 'image_id')}, image_id: {image_id}"
        )

    msg = Message(**msg_data)
    db.add(msg)
    db.commit()
    db.refresh(msg)
    return msg


def get_chat_history(
    db: Session,
    user1_id: str,
    user2_id: str,
    limit: int = 10,
    offset: int = 0,
):
    """获取两个用户之间的聊天历史。user2_id 为 0 时表示系统消息。"""
    from app.models import Message

    if user2_id == 0:
        query = db.query(Message).filter(
            and_(
                Message.sender_id.is_(None),
                Message.receiver_id == user1_id,
            )
        )
    else:
        query = db.query(Message).filter(
            or_(
                and_(
                    Message.sender_id == user1_id,
                    Message.receiver_id == user2_id,
                ),
                and_(
                    Message.sender_id == user2_id,
                    Message.receiver_id == user1_id,
                ),
            )
        )
    return (
        query.order_by(Message.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )


def get_unread_messages(db: Session, user_id: str):
    """
    获取未读消息（仅任务消息）。
    使用 MessageRead / MessageReadCursor 判断已读，不含普通联系人聊天。
    """
    from app.models import Message, MessageRead, MessageReadCursor, Task
    from app.models import TaskParticipant

    task_ids_set = set()

    user_tasks_1 = (
        db.query(Task.id)
        .filter(
            or_(Task.poster_id == user_id, Task.taker_id == user_id),
            Task.status != "cancelled",
        )
        .all()
    )
    task_ids_set.update([t.id for t in user_tasks_1])

    participant_task_ids = (
        db.query(TaskParticipant.task_id)
        .filter(
            and_(
                TaskParticipant.user_id == user_id,
                TaskParticipant.status.in_(
                    ["accepted", "in_progress", "completed"]
                ),
            )
        )
        .all()
    )
    participant_task_id_list = [row[0] for row in participant_task_ids]
    if participant_task_id_list:
        participant_tasks = (
            db.query(Task.id)
            .filter(
                and_(
                    Task.id.in_(participant_task_id_list),
                    Task.is_multi_participant.is_(True),
                    Task.status != "cancelled",
                )
            )
            .all()
        )
        task_ids_set.update([t.id for t in participant_tasks])

    expert_creator_tasks = (
        db.query(Task.id)
        .filter(
            and_(
                Task.is_multi_participant.is_(True),
                Task.created_by_expert.is_(True),
                Task.expert_creator_id == user_id,
                Task.status != "cancelled",
            )
        )
        .all()
    )
    task_ids_set.update([t.id for t in expert_creator_tasks])

    task_ids = list(task_ids_set)
    if not task_ids:
        return []

    cursors = (
        db.query(MessageReadCursor)
        .filter(
            MessageReadCursor.task_id.in_(task_ids),
            MessageReadCursor.user_id == user_id,
        )
        .all()
    )
    cursor_dict = {
        c.task_id: c.last_read_message_id
        for c in cursors
        if c.last_read_message_id is not None
    }

    task_unread_messages = []
    common_filters = [
        Message.sender_id != user_id,
        Message.sender_id.notin_(["system", "SYSTEM"]),
        Message.message_type != "system",
        Message.conversation_type == "task",
        Task.status != "cancelled",
    ]

    tasks_with_cursor = {
        tid: cid for tid, cid in cursor_dict.items() if tid in task_ids
    }
    tasks_without_cursor = [tid for tid in task_ids if tid not in cursor_dict]

    if tasks_with_cursor:
        cursor_conditions = [
            and_(Message.task_id == tid, Message.id > cid)
            for tid, cid in tasks_with_cursor.items()
        ]
        unread_with_cursor = (
            db.query(Message)
            .join(Task, Message.task_id == Task.id)
            .filter(or_(*cursor_conditions), *common_filters)
            .all()
        )
        task_unread_messages.extend(unread_with_cursor)

    if tasks_without_cursor:
        unread_without_cursor = (
            db.query(Message)
            .join(Task, Message.task_id == Task.id)
            .filter(
                Message.task_id.in_(tasks_without_cursor),
                *common_filters,
                ~exists(
                    select(1).where(
                        and_(
                            MessageRead.message_id == Message.id,
                            MessageRead.user_id == user_id,
                        )
                    )
                ),
            )
            .all()
        )
        task_unread_messages.extend(unread_without_cursor)

    task_unread_messages.sort(key=lambda x: x.created_at, reverse=True)
    return task_unread_messages


def get_customer_service_messages(
    db: Session, session_id: int, limit: int = 50
):
    """获取指定客服会话的所有消息"""
    return (
        db.query(models.Message)
        .filter(models.Message.session_id == session_id)
        .order_by(models.Message.created_at.desc())
        .limit(limit)
        .all()
    )


def mark_message_read(db: Session, msg_id: int, user_id: str):
    msg = (
        db.query(models.Message)
        .filter(
            models.Message.id == msg_id,
            models.Message.receiver_id == user_id,
        )
        .first()
    )
    if msg:
        msg.is_read = 1
        db.commit()
        db.refresh(msg)
    return msg


def get_admin_messages(db: Session, admin_id: int):
    return (
        db.query(models.Message)
        .filter(
            models.Message.receiver_id == admin_id,
            models.Message.is_admin_msg == 1,
        )
        .order_by(models.Message.created_at.desc())
        .all()
    )
