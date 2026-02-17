"""客服认证 / 对话 / 排队 / 消息相关 CRUD，独立模块便于维护与测试。"""

import logging

from sqlalchemy.orm import Session

from app import models
from app.utils.time_utils import format_iso_utc, get_utc_time

logger = logging.getLogger(__name__)


def update_customer_service_online_status(db: Session, cs_id: str, is_online: bool):
    """更新客服在线状态"""
    cs = (
        db.query(models.CustomerService)
        .filter(models.CustomerService.id == cs_id)
        .first()
    )
    if cs:
        cs.is_online = 1 if is_online else 0
        db.commit()
        db.refresh(cs)
        return cs
    return None


def create_customer_service_by_admin(db: Session, cs_data: dict):
    """管理员创建客服账号"""
    # 创建用户账号
    from app.security import get_password_hash

    hashed_password = get_password_hash(cs_data["password"])
    # ⚠️ User模型没有is_customer_service、is_admin、is_super_admin字段
    # 客服是单独的CustomerService模型，管理员是AdminUser模型
    # 这里只创建普通User记录，客服记录在CustomerService表中创建
    user = models.User(
        name=cs_data["name"],
        email=cs_data["email"],
        hashed_password=hashed_password,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # 创建客服记录
    cs = models.CustomerService(
        name=cs_data["name"],
        email=cs_data["email"],
        hashed_password=hashed_password,
        is_online=0,
    )
    db.add(cs)
    db.commit()
    db.refresh(cs)

    return {"user": user, "customer_service": cs}


def delete_customer_service_by_admin(db: Session, cs_id: int):
    """管理员删除客服账号"""
    cs = (
        db.query(models.CustomerService)
        .filter(models.CustomerService.id == cs_id)
        .first()
    )
    if cs:
        # ⚠️ User模型没有is_customer_service字段
        # 通过邮箱或名称找到对应的用户账号（如果存在）
        # 注意：客服和用户是分开的模型，可能没有对应的User记录
        user = db.query(models.User).filter(models.User.email == cs.email).first()

        # 如果通过邮箱找不到，尝试通过名称（但名称可能不唯一）
        if not user:
            user = db.query(models.User).filter(models.User.name == cs.name).first()

        # 如果找到对应的用户，检查是否有任务（poster_id是RESTRICT约束）
        if user:
            task_count = (
                db.query(models.Task)
                .filter(models.Task.poster_id == user.id)
                .count()
            )

            if task_count > 0:
                # 有任务，不能删除用户，只删除客服记录
                db.delete(cs)
                db.commit()
                return True
            else:
                # 没有任务，可以删除用户
                db.delete(user)

        db.delete(cs)
        db.commit()
        return True
    return False


def get_customer_services_for_admin(db: Session, skip: int = 0, limit: int = 20):
    """管理员获取客服列表"""
    cs_list = (
        db.query(models.CustomerService).offset(skip).limit(limit).all()
    )
    total = db.query(models.CustomerService).count()

    # 获取对应的用户信息
    result = []
    for cs in cs_list:
        # 通过名称匹配用户，因为客服和用户可能使用相同的名称
        user = db.query(models.User).filter(models.User.name == cs.name).first()

        cs_info = {
            "id": cs.id,
            "name": cs.name,
            "is_online": cs.is_online,
            "avg_rating": cs.avg_rating,
            "total_ratings": cs.total_ratings,
            "user_id": user.id if user else None,
            "email": user.email if user else None,
        }
        result.append(cs_info)

    return {"customer_services": result, "total": total}


# 客服登录相关函数
def get_customer_service_by_id(db: Session, cs_id: str):
    """根据客服ID获取客服"""
    return (
        db.query(models.CustomerService)
        .filter(models.CustomerService.id == cs_id)
        .first()
    )


def get_customer_service_by_email(db: Session, email: str):
    """根据邮箱获取客服"""
    return (
        db.query(models.CustomerService)
        .filter(models.CustomerService.email == email)
        .first()
    )


def authenticate_customer_service(db: Session, cs_id: str, password: str):
    """验证客服登录凭据"""
    cs = get_customer_service_by_id(db, cs_id)
    if not cs:
        return False
    from app.security import verify_password

    if not verify_password(password, cs.hashed_password):
        return False
    return cs


def create_customer_service_with_login(db: Session, cs_data: dict):
    """创建客服账号（包含登录信息）"""
    from app.security import get_password_hash

    hashed_password = get_password_hash(cs_data["password"])
    cs = models.CustomerService(
        id=cs_data["id"],  # 使用提供的客服ID
        name=cs_data["name"],
        email=cs_data["email"],
        hashed_password=hashed_password,
        is_online=0,
    )
    db.add(cs)
    db.commit()
    db.refresh(cs)
    return cs


# 客服对话管理函数
def generate_customer_service_chat_id(user_id: str, service_id: str) -> str:
    """生成客服对话ID"""
    now = get_utc_time()
    timestamp = now.strftime("%Y%m%d_%H%M%S")
    return f"CS_CHAT_{timestamp}_{user_id}_{service_id}"


def create_customer_service_chat(db: Session, user_id: str, service_id: str) -> dict:
    """创建新的客服对话"""
    from app.models import CustomerServiceChat

    # 检查是否已有未结束的对话
    existing_chat = (
        db.query(CustomerServiceChat)
        .filter(
            CustomerServiceChat.user_id == user_id,
            CustomerServiceChat.service_id == service_id,
            CustomerServiceChat.is_ended == 0,
        )
        .first()
    )

    if existing_chat:
        return {
            "chat_id": existing_chat.chat_id,
            "user_id": existing_chat.user_id,
            "service_id": existing_chat.service_id,
            "is_ended": existing_chat.is_ended,
            "created_at": existing_chat.created_at,
            "total_messages": existing_chat.total_messages,
        }

    chat_id = generate_customer_service_chat_id(user_id, service_id)
    new_chat = CustomerServiceChat(
        chat_id=chat_id,
        user_id=user_id,
        service_id=service_id,
        is_ended=0,
    )

    db.add(new_chat)
    db.commit()
    db.refresh(new_chat)

    # 自动生成一个系统消息，确保对话在数据库中有记录
    from app.models import CustomerServiceMessage

    system_message = CustomerServiceMessage(
        chat_id=chat_id,
        sender_id="SYSTEM",
        sender_type="system",
        content="用户已连接客服，对话开始。",
    )

    db.add(system_message)

    # 更新对话的最后消息时间和总消息数
    new_chat.last_message_at = get_utc_time()
    new_chat.total_messages = 1

    db.commit()
    db.refresh(system_message)

    return {
        "chat_id": new_chat.chat_id,
        "user_id": new_chat.user_id,
        "service_id": new_chat.service_id,
        "is_ended": new_chat.is_ended,
        "created_at": new_chat.created_at,
        "total_messages": new_chat.total_messages,
    }


def get_customer_service_chat(db: Session, chat_id: str) -> dict:
    """获取客服对话信息"""
    from app.models import CustomerServiceChat

    chat = (
        db.query(CustomerServiceChat)
        .filter(CustomerServiceChat.chat_id == chat_id)
        .first()
    )
    if not chat:
        return None

    return {
        "chat_id": chat.chat_id,
        "user_id": chat.user_id,
        "service_id": chat.service_id,
        "is_ended": chat.is_ended,
        "created_at": format_iso_utc(chat.created_at) if chat.created_at else None,
        "ended_at": format_iso_utc(chat.ended_at) if chat.ended_at else None,
        "last_message_at": format_iso_utc(chat.last_message_at)
        if chat.last_message_at
        else None,
        "total_messages": chat.total_messages,
        "user_rating": chat.user_rating,
        "user_comment": chat.user_comment,
        "rated_at": format_iso_utc(chat.rated_at) if chat.rated_at else None,
    }


def get_user_customer_service_chats(db: Session, user_id: str) -> list:
    """获取用户的所有客服对话"""
    from app.models import CustomerServiceChat

    chats = (
        db.query(CustomerServiceChat)
        .filter(CustomerServiceChat.user_id == user_id)
        .order_by(CustomerServiceChat.created_at.desc())
        .all()
    )

    return [
        {
            "chat_id": chat.chat_id,
            "user_id": chat.user_id,
            "service_id": chat.service_id,
            "is_ended": chat.is_ended,
            "created_at": format_iso_utc(chat.created_at) if chat.created_at else None,
            "ended_at": format_iso_utc(chat.ended_at) if chat.ended_at else None,
            "last_message_at": format_iso_utc(chat.last_message_at)
            if chat.last_message_at
            else None,
            "total_messages": chat.total_messages,
            "user_rating": chat.user_rating,
            "user_comment": chat.user_comment,
            "rated_at": format_iso_utc(chat.rated_at) if chat.rated_at else None,
        }
        for chat in chats
    ]


def get_service_customer_service_chats(db: Session, service_id: str) -> list:
    """获取客服的所有对话 - 进行中对话置顶，已结束对话沉底且最多50个"""
    from datetime import timedelta

    from app.models import CustomerServiceChat, CustomerServiceMessage

    active_chats_query = db.query(CustomerServiceChat).filter(
        CustomerServiceChat.service_id == service_id,
        CustomerServiceChat.is_ended == 0,
    )

    all_active_chats = active_chats_query.all()

    if not all_active_chats:
        active_chats = []
    else:
        chat_ids = [chat.chat_id for chat in all_active_chats]
        chats_with_real_messages = set(
            db.query(CustomerServiceMessage.chat_id)
            .filter(
                CustomerServiceMessage.chat_id.in_(chat_ids),
                CustomerServiceMessage.sender_type != "system",
            )
            .distinct()
            .all()
        )
        chats_with_real_messages = {
            chat_id[0] for chat_id in chats_with_real_messages
        }

        now = get_utc_time()
        threshold_time = now - timedelta(minutes=10)

        active_chats = []
        for chat in all_active_chats:
            has_real_message = chat.chat_id in chats_with_real_messages

            if not has_real_message:
                if chat.created_at and chat.created_at < threshold_time:
                    continue

            active_chats.append(chat)

        active_chats.sort(
            key=lambda x: x.last_message_at if x.last_message_at else x.created_at,
            reverse=True,
        )

    ended_chats = (
        db.query(CustomerServiceChat)
        .filter(
            CustomerServiceChat.service_id == service_id,
            CustomerServiceChat.is_ended == 1,
        )
        .order_by(CustomerServiceChat.ended_at.desc())
        .limit(50)
        .all()
    )

    all_chats = active_chats + ended_chats

    return [
        {
            "chat_id": chat.chat_id,
            "user_id": chat.user_id,
            "service_id": chat.service_id,
            "is_ended": chat.is_ended,
            "created_at": format_iso_utc(chat.created_at) if chat.created_at else None,
            "ended_at": format_iso_utc(chat.ended_at) if chat.ended_at else None,
            "last_message_at": format_iso_utc(chat.last_message_at)
            if chat.last_message_at
            else None,
            "total_messages": chat.total_messages,
            "user_rating": chat.user_rating,
            "user_comment": chat.user_comment,
            "rated_at": format_iso_utc(chat.rated_at) if chat.rated_at else None,
        }
        for chat in all_chats
    ]


def cleanup_old_ended_chats(db: Session, service_id: str) -> int:
    """清理客服的旧已结束对话，保留最新的50个"""
    from app.models import CustomerServiceChat, CustomerServiceMessage

    all_ended_chats = (
        db.query(CustomerServiceChat)
        .filter(
            CustomerServiceChat.service_id == service_id,
            CustomerServiceChat.is_ended == 1,
        )
        .order_by(CustomerServiceChat.ended_at.desc())
        .all()
    )

    if len(all_ended_chats) > 50:
        chats_to_delete = all_ended_chats[50:]
        deleted_count = 0

        for chat in chats_to_delete:
            db.query(CustomerServiceMessage).filter(
                CustomerServiceMessage.chat_id == chat.chat_id
            ).delete()
            db.delete(chat)
            deleted_count += 1

        db.commit()
        return deleted_count

    return 0


def add_user_to_customer_service_queue(db: Session, user_id: str) -> dict:
    """将用户添加到客服排队队列"""
    from app.models import CustomerServiceQueue

    existing_queue = (
        db.query(CustomerServiceQueue)
        .filter(
            CustomerServiceQueue.user_id == user_id,
            CustomerServiceQueue.status.in_(["waiting", "assigned"]),
        )
        .first()
    )

    if existing_queue:
        wait_seconds = int(
            (get_utc_time() - existing_queue.queued_at).total_seconds()
        )
        wait_time_minutes = wait_seconds // 60

        result = {
            "queue_id": existing_queue.id,
            "status": existing_queue.status,
            "queued_at": format_iso_utc(existing_queue.queued_at)
            if existing_queue.queued_at
            else None,
            "wait_seconds": wait_seconds,
            "wait_time_minutes": wait_time_minutes,
            "assigned_service_id": existing_queue.assigned_service_id,
        }

        if existing_queue.status == "waiting":
            queue_position = db.query(CustomerServiceQueue).filter(
                CustomerServiceQueue.status == "waiting",
                CustomerServiceQueue.queued_at <= existing_queue.queued_at,
            ).count()

            estimated_wait_time = calculate_estimated_wait_time(queue_position, db)
            result["queue_position"] = queue_position
            result["estimated_wait_time"] = estimated_wait_time

        return result

    new_queue = CustomerServiceQueue(
        user_id=user_id,
        status="waiting",
        queued_at=get_utc_time(),
    )
    db.add(new_queue)
    db.commit()
    db.refresh(new_queue)

    queue_position = db.query(CustomerServiceQueue).filter(
        CustomerServiceQueue.status == "waiting",
        CustomerServiceQueue.queued_at <= new_queue.queued_at,
    ).count()

    estimated_wait_time = calculate_estimated_wait_time(queue_position, db)

    return {
        "queue_id": new_queue.id,
        "status": "waiting",
        "queued_at": format_iso_utc(new_queue.queued_at) if new_queue.queued_at else None,
        "wait_seconds": 0,
        "wait_time_minutes": 0,
        "queue_position": queue_position,
        "estimated_wait_time": estimated_wait_time,
    }


def calculate_estimated_wait_time(queue_position: int, db: Session) -> int:
    """
    计算预计等待时间（分钟）
    使用移动平均处理时长，统一使用UTC时间
    返回：至少1分钟，避免返回0

    单一权威实现：所有调用此函数的地方应统一引用此实现，避免重复定义
    """
    from sqlalchemy import Integer, cast

    from app.models import CustomerService, CustomerServiceChat
    from app.utils.time_utils import to_utc

    recent_chats = (
        db.query(CustomerServiceChat)
        .filter(
            CustomerServiceChat.is_ended == 1,
            CustomerServiceChat.ended_at.isnot(None),
            CustomerServiceChat.assigned_at.isnot(None),
        )
        .order_by(CustomerServiceChat.ended_at.desc())
        .limit(100)
        .all()
    )

    if not recent_chats:
        return max(1, queue_position * 5)

    total_duration = 0
    count = 0

    for chat in recent_chats:
        if chat.assigned_at and chat.ended_at:
            assigned_utc = to_utc(chat.assigned_at)
            ended_utc = to_utc(chat.ended_at)
            duration = (ended_utc - assigned_utc).total_seconds() / 60
            total_duration += duration
            count += 1

    if count == 0:
        return max(1, queue_position * 5)

    avg_duration = total_duration / count

    online_services = db.query(CustomerService).filter(
        cast(CustomerService.is_online, Integer) == 1
    ).count()

    if online_services == 0:
        return max(1, queue_position * 10)

    load_factor = max(1.0, 5.0 / online_services)
    estimated_time = queue_position * avg_duration * load_factor
    return max(1, int(estimated_time))


def get_user_queue_status(db: Session, user_id: str) -> dict:
    """获取用户在排队队列中的状态"""
    from app.models import CustomerServiceQueue

    queue_entry = (
        db.query(CustomerServiceQueue)
        .filter(CustomerServiceQueue.user_id == user_id)
        .order_by(CustomerServiceQueue.queued_at.desc())
        .first()
    )

    if not queue_entry:
        return {"status": "not_in_queue"}

    wait_seconds = int((get_utc_time() - queue_entry.queued_at).total_seconds())
    wait_time_minutes = wait_seconds // 60

    estimated_wait_time = None
    queue_position = None

    if queue_entry.status == "waiting":
        queue_position = db.query(CustomerServiceQueue).filter(
            CustomerServiceQueue.status == "waiting",
            CustomerServiceQueue.queued_at <= queue_entry.queued_at,
        ).count()

        estimated_wait_time = calculate_estimated_wait_time(queue_position, db)

    result = {
        "queue_id": queue_entry.id,
        "status": queue_entry.status,
        "queued_at": format_iso_utc(queue_entry.queued_at) if queue_entry.queued_at else None,
        "wait_seconds": wait_seconds,
        "wait_time_minutes": wait_time_minutes,
        "assigned_service_id": queue_entry.assigned_service_id,
        "assigned_at": format_iso_utc(queue_entry.assigned_at) if queue_entry.assigned_at else None,
    }

    if queue_position is not None:
        result["queue_position"] = queue_position

    if estimated_wait_time is not None:
        result["estimated_wait_time"] = estimated_wait_time

    return result


def end_customer_service_chat(
    db: Session,
    chat_id: str,
    reason: str = None,
    ended_by: str = None,
    ended_type: str = None,
    comment: str = None,
) -> bool:
    """
    结束客服对话，并清理该聊天的所有图片和文件
    支持记录结束原因、结束者、结束类型和备注
    """
    from app.models import CustomerServiceChat

    chat = (
        db.query(CustomerServiceChat)
        .filter(CustomerServiceChat.chat_id == chat_id)
        .first()
    )
    if not chat:
        return False

    if chat.is_ended == 1:
        return True

    chat.is_ended = 1
    chat.ended_at = get_utc_time()
    if reason:
        chat.ended_reason = reason
    if ended_by:
        chat.ended_by = ended_by
    if ended_type:
        chat.ended_type = ended_type
    if comment:
        chat.ended_comment = comment
    db.commit()

    logger.info(
        f"Chat {chat_id} ended: reason={reason}, type={ended_type}, by={ended_by}"
    )

    from app.image_cleanup import delete_chat_images_and_files

    try:
        deleted_count = delete_chat_images_and_files(chat_id)
        logger.info(f"客服聊天 {chat_id} 已清理 {deleted_count} 个文件")
    except Exception as e:
        logger.warning(f"清理客服聊天文件失败 {chat_id}: {e}")

    cleanup_old_ended_chats(db, chat.service_id)
    return True


def rate_customer_service_chat(
    db: Session, chat_id: str, rating: int, comment: str = None
) -> bool:
    """为客服对话评分"""
    from app.models import CustomerServiceChat

    chat = (
        db.query(CustomerServiceChat)
        .filter(CustomerServiceChat.chat_id == chat_id)
        .first()
    )
    if not chat:
        return False

    chat.user_rating = rating
    chat.user_comment = comment
    chat.rated_at = get_utc_time()
    db.commit()
    return True


def mark_customer_service_message_delivered(db: Session, message_id: int) -> bool:
    """标记消息为已送达"""
    from app.models import CustomerServiceMessage

    message = (
        db.query(CustomerServiceMessage)
        .filter(CustomerServiceMessage.id == message_id)
        .first()
    )

    if not message:
        return False

    if message.status != "sent":
        return False

    message.status = "delivered"
    message.delivered_at = get_utc_time()
    db.commit()
    return True


def mark_customer_service_message_read(db: Session, message_id: int) -> bool:
    """标记消息为已读"""
    from app.models import CustomerServiceMessage

    message = (
        db.query(CustomerServiceMessage)
        .filter(CustomerServiceMessage.id == message_id)
        .first()
    )

    if not message:
        return False

    if message.status not in ["sent", "delivered"]:
        return False

    message.status = "read"
    message.read_at = get_utc_time()
    if not message.delivered_at:
        message.delivered_at = message.read_at
    db.commit()
    return True


def save_customer_service_message(
    db: Session,
    chat_id: str,
    sender_id: str,
    sender_type: str,
    content: str,
    image_id: str = None,
) -> dict:
    """保存客服对话消息"""
    from app.models import CustomerServiceChat, CustomerServiceMessage

    message_data = {
        "chat_id": chat_id,
        "sender_id": sender_id,
        "sender_type": sender_type,
        "content": content,
    }

    if hasattr(CustomerServiceMessage, "image_id") and image_id:
        message_data["image_id"] = image_id
        logger.debug(f"客服消息设置image_id: {image_id}")

    message_data["status"] = "sending"
    message_data["sent_at"] = get_utc_time()

    message = CustomerServiceMessage(**message_data)

    db.add(message)
    db.flush()

    message.status = "sent"
    db.commit()

    chat = (
        db.query(CustomerServiceChat)
        .filter(CustomerServiceChat.chat_id == chat_id)
        .first()
    )
    if chat:
        chat.last_message_at = get_utc_time()
        chat.total_messages += 1

    db.refresh(message)

    return {
        "id": message.id,
        "chat_id": message.chat_id,
        "sender_id": message.sender_id,
        "sender_type": message.sender_type,
        "content": message.content,
        "is_read": message.is_read,
        "created_at": format_iso_utc(message.created_at) if message.created_at else None,
        "status": message.status,
        "sent_at": format_iso_utc(message.sent_at) if message.sent_at else None,
        "delivered_at": format_iso_utc(message.delivered_at) if message.delivered_at else None,
        "read_at": format_iso_utc(message.read_at) if message.read_at else None,
    }


def get_customer_service_messages(
    db: Session, chat_id: str, limit: int = 50, offset: int = 0
) -> list:
    """获取客服对话消息"""
    from app.models import CustomerServiceMessage

    messages = (
        db.query(CustomerServiceMessage)
        .filter(CustomerServiceMessage.chat_id == chat_id)
        .order_by(CustomerServiceMessage.created_at.asc())
        .offset(offset)
        .limit(limit)
        .all()
    )

    return [
        {
            "id": msg.id,
            "chat_id": msg.chat_id,
            "sender_id": msg.sender_id,
            "sender_type": msg.sender_type,
            "content": msg.content,
            "is_read": msg.is_read,
            "created_at": format_iso_utc(msg.created_at) if msg.created_at else None,
        }
        for msg in messages
    ]


def mark_customer_service_messages_read(
    db: Session, chat_id: str, reader_id: str
) -> int:
    """标记客服对话消息为已读"""
    from app.models import CustomerServiceMessage

    updated_count = (
        db.query(CustomerServiceMessage)
        .filter(
            CustomerServiceMessage.chat_id == chat_id,
            CustomerServiceMessage.sender_id != reader_id,
            CustomerServiceMessage.is_read == 0,
        )
        .update({"is_read": 1})
    )

    db.commit()
    return updated_count


def get_unread_customer_service_messages_count(
    db: Session, chat_id: str, reader_id: str
) -> int:
    """获取未读消息数量"""
    from app.models import CustomerServiceMessage

    return (
        db.query(CustomerServiceMessage)
        .filter(
            CustomerServiceMessage.chat_id == chat_id,
            CustomerServiceMessage.sender_id != reader_id,
            CustomerServiceMessage.is_read == 0,
        )
        .count()
    )

