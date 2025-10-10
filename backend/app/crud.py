import datetime
from datetime import timezone
from typing import Optional

from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session

from app import models, schemas

# 密码加密上下文已移至 app.security 模块
# 请使用: from app.security import pwd_context


def get_uk_time():
    """获取当前英国时间 (自动处理夏令时/冬令时)"""
    from datetime import datetime

    import pytz

    uk_tz = pytz.timezone("Europe/London")
    return datetime.now(uk_tz)


# 密码哈希函数已移至 app.security 模块
# 请使用: from app.security import get_password_hash


# 密码验证函数已移至 app.security 模块
# 请使用: from app.security import verify_password


def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email == email).first()


def get_user_by_id(db: Session, user_id: str):
    # 尝试从Redis缓存获取
    from app.redis_cache import get_user_info, cache_user_info
    cached_user = get_user_info(user_id)
    if cached_user:
        return cached_user
    
    # 缓存未命中，从数据库查询
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        # 缓存用户信息
        cache_user_info(user_id, user)
    return user


def get_all_users(db: Session):
    return db.query(models.User).all()


def update_user_statistics(db: Session, user_id: str):
    """自动更新用户的统计信息：task_count 和 avg_rating"""
    from app.models import Review, Task

    # 计算用户的总任务数（发布的任务 + 接受的任务）
    posted_tasks = db.query(Task).filter(Task.poster_id == user_id).count()
    taken_tasks = db.query(Task).filter(Task.taker_id == user_id).count()
    total_tasks = posted_tasks + taken_tasks

    # 计算用户的平均评分
    avg_rating_result = (
        db.query(func.avg(Review.rating)).filter(Review.user_id == user_id).scalar()
    )
    avg_rating = float(avg_rating_result) if avg_rating_result is not None else 0.0

    # 更新用户记录
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        user.task_count = total_tasks
        user.avg_rating = avg_rating
        db.commit()
        db.refresh(user)

    return {"task_count": total_tasks, "avg_rating": avg_rating}


def create_user(db: Session, user: schemas.UserCreate):
    import random
    from app.security import get_password_hash
    hashed_password = get_password_hash(user.password)

    # 生成唯一的8位用户ID
    while True:
        # 生成一个随机的8位数字作为用户ID
        user_id = str(random.randint(10000000, 99999999))

        # 检查ID是否已存在
        existing_user = (
            db.query(models.User).filter(models.User.id == user_id).first()
        )
        if not existing_user:
            break

    db_user = models.User(
        id=user_id,
        name=user.name,
        email=user.email,
        phone=user.phone,
        hashed_password=hashed_password,
        avatar=getattr(user, "avatar", ""),
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def get_user_tasks(db: Session, user_id: str, limit: int = 50, offset: int = 0):
    from app.models import Task
    from app.redis_cache import get_user_tasks, cache_user_tasks
    
    # 尝试从Redis缓存获取
    cache_key = f"{user_id}_{limit}_{offset}"
    cached_tasks = get_user_tasks(cache_key)
    if cached_tasks:
        return cached_tasks
    
    # 缓存未命中，从数据库查询
    tasks = (
        db.query(Task)
        .filter((Task.poster_id == user_id) | (Task.taker_id == user_id))
        .order_by(Task.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    
    # 缓存任务列表
    cache_user_tasks(cache_key, tasks)
    return tasks


def get_user_reviews(db: Session, user_id: str, limit: int = 5):
    from app.models import Review

    return (
        db.query(Review)
        .filter(Review.user_id == user_id)
        .order_by(Review.created_at.desc())
        .limit(limit)
        .all()
    )


def get_reviews_received_by_user(db: Session, user_id: str, limit: int = 5):
    """获取用户收到的评价（其他用户对该用户的评价）"""
    from app.models import Review, Task, User

    # 通过任务关系找到用户收到的评价，并包含评价者信息
    # 用户收到的评价是指：用户作为任务的poster或taker，而评价者是任务的另一个参与者
    reviews = (
        db.query(Review, User)
        .select_from(Review)
        .join(Task, Review.task_id == Task.id)
        .join(User, Review.user_id == User.id)
        .filter(
            ((Task.poster_id == user_id) & (Review.user_id == Task.taker_id))
            | ((Task.taker_id == user_id) & (Review.user_id == Task.poster_id))
        )
        .order_by(Review.created_at.desc())
        .limit(limit)
        .all()
    )
    return reviews


def get_user_reviews_with_reviewer_info(db: Session, user_id: str, limit: int = 5):
    """获取用户收到的评价，包含评价者信息（用于个人主页显示）"""
    from app.models import Review, Task, User

    # 通过任务关系找到用户收到的评价，并包含评价者和任务信息
    reviews = (
        db.query(Review, User, Task)
        .join(User, Review.user_id == User.id)
        .join(Task, Review.task_id == Task.id)
        .filter(
            ((Task.poster_id == user_id) & (Review.user_id == Task.taker_id))
            | ((Task.taker_id == user_id) & (Review.user_id == Task.poster_id))
        )
        .order_by(Review.created_at.desc())
        .limit(limit)
        .all()
    )

    # 构造返回数据
    result = []
    for review, reviewer, task in reviews:
        result.append(
            {
                "id": review.id,
                "task_id": review.task_id,
                "user_id": review.user_id,
                "rating": review.rating,
                "comment": review.comment,
                "is_anonymous": bool(review.is_anonymous),
                "created_at": review.created_at,
                "reviewer_name": "匿名用户" if review.is_anonymous else reviewer.name,
                "reviewer_avatar": reviewer.avatar if not review.is_anonymous else "",
                "task_title": task.title,
            }
        )
    return result


def create_task(db: Session, user_id: str, task: schemas.TaskCreate):
    from app.models import Task, User

    user = db.query(User).filter(User.id == user_id).first()

    # 获取系统设置中的价格阈值
    settings = get_system_settings_dict(db)
    vip_price_threshold = settings.get("vip_price_threshold", 10.0)
    super_vip_price_threshold = settings.get("super_vip_price_threshold", 50.0)

    # 任务等级分配逻辑
    if user.user_level == "super":
        task_level = "vip"
    elif task.reward >= super_vip_price_threshold:
        task_level = "super"
    elif task.reward >= vip_price_threshold:
        task_level = "vip"
    else:
        task_level = "normal"
    db_task = Task(
        title=task.title,
        description=task.description,
        deadline=task.deadline,
        reward=task.reward,
        location=task.location,
        task_type=task.task_type,
        poster_id=user_id,
        status="open",
        task_level=task_level,
        is_public=getattr(task, "is_public", 1),  # 默认为公开
    )
    db.add(db_task)
    db.commit()
    db.refresh(db_task)

    # 自动更新发布者的任务统计
    update_user_statistics(db, user_id)

    return db_task


def list_tasks(
    db: Session,
    skip: int = 0,
    limit: int = 20,
    task_type: str = None,
    location: str = None,
    keyword: str = None,
    sort_by: str = "latest",
):
    from sqlalchemy import or_

    from app.models import Task, User

    # 使用英国时间进行过滤
    now_utc = get_uk_time()

    # 构建基础查询
    query = db.query(Task).filter(Task.status == "open", Task.deadline > now_utc)

    # 添加任务类型筛选
    if task_type and task_type.strip():
        query = query.filter(Task.task_type == task_type)

    # 添加城市筛选
    if location and location.strip():
        query = query.filter(Task.location == location)

    # 添加关键词搜索
    if keyword and keyword.strip():
        keyword = keyword.strip()
        # 搜索标题、描述、任务类型、城市
        query = query.filter(
            or_(
                Task.title.ilike(f"%{keyword}%"),
                Task.description.ilike(f"%{keyword}%"),
                Task.task_type.ilike(f"%{keyword}%"),
                Task.location.ilike(f"%{keyword}%"),
            )
        )

    # 根据排序参数进行排序
    if sort_by == "latest":
        query = query.order_by(Task.created_at.desc())
    elif sort_by == "reward_asc":
        query = query.order_by(Task.reward.asc())
    elif sort_by == "reward_desc":
        query = query.order_by(Task.reward.desc())
    elif sort_by == "deadline_asc":
        query = query.order_by(Task.deadline.asc())
    elif sort_by == "deadline_desc":
        query = query.order_by(Task.deadline.desc())
    else:
        # 默认按创建时间降序
        query = query.order_by(Task.created_at.desc())

    # 执行查询
    tasks = query.offset(skip).limit(limit).all()

    # 为每个任务添加发布者时区信息
    for task in tasks:
        poster = db.query(User).filter(User.id == task.poster_id).first()
        if poster:
            task.poster_timezone = poster.timezone if poster.timezone else "UTC"
        else:
            task.poster_timezone = "UTC"

    return tasks


def count_tasks(
    db: Session, task_type: str = None, location: str = None, keyword: str = None
):
    """计算符合条件的任务总数"""
    from sqlalchemy import or_

    from app.models import Task

    # 使用英国时间进行过滤
    now_utc = get_uk_time()

    # 构建基础查询
    query = db.query(Task).filter(Task.status == "open", Task.deadline > now_utc)

    # 添加任务类型筛选
    if task_type and task_type.strip():
        query = query.filter(Task.task_type == task_type)

    # 添加城市筛选
    if location and location.strip():
        query = query.filter(Task.location == location)

    # 添加关键词搜索
    if keyword and keyword.strip():
        keyword = keyword.strip()
        query = query.filter(
            or_(
                Task.title.ilike(f"%{keyword}%"),
                Task.description.ilike(f"%{keyword}%"),
                Task.task_type.ilike(f"%{keyword}%"),
                Task.location.ilike(f"%{keyword}%"),
            )
        )

    return query.count()


def list_all_tasks(db: Session, skip: int = 0, limit: int = 1000):
    """获取所有任务（用于客服管理，不进行状态过滤）"""
    from app.models import Task, User
    from sqlalchemy.orm import selectinload

    # 使用预加载避免N+1查询问题
    tasks = (
        db.query(Task)
        .options(selectinload(Task.poster))  # 预加载发布者信息
        .order_by(Task.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )

    # 为每个任务添加发布者时区信息（现在poster已经预加载）
    for task in tasks:
        if task.poster:
            task.poster_timezone = task.poster.timezone if task.poster.timezone else "UTC"
        else:
            task.poster_timezone = "UTC"

    return tasks


def get_task(db: Session, task_id: int):
    from app.models import Task, User

    task = db.query(Task).filter(Task.id == task_id).first()
    if task:
        # 获取发布者时区信息
        poster = db.query(User).filter(User.id == task.poster_id).first()
        if poster:
            task.poster_timezone = poster.timezone if poster.timezone else "UTC"
        else:
            task.poster_timezone = "UTC"
    return task


def accept_task(db: Session, task_id: int, taker_id: str):
    from app.models import Task, User

    try:
        task = db.query(Task).filter(Task.id == task_id).first()
        taker = db.query(User).filter(User.id == taker_id).first()

        # 基本验证
        if not task:
            print(f"DEBUG: Task {task_id} not found")
            return None
        if not taker:
            print(f"DEBUG: User {taker_id} not found")
            return None

        if task.status != "open":
            print(f"DEBUG: Task {task_id} status is {task.status}, not open")
            return None

        # 简单更新
        task.taker_id = str(taker_id)
        task.status = "taken"
        db.commit()
        db.refresh(task)

        print(f"DEBUG: Successfully accepted task {task_id} by user {taker_id}")
        return task
    except Exception as e:
        print(f"DEBUG: Error in accept_task: {e}")
        db.rollback()
        return None


def update_task_reward(db: Session, task_id: int, poster_id: int, new_reward: float):
    from app.models import Task

    task = (
        db.query(Task).filter(Task.id == task_id, Task.poster_id == poster_id).first()
    )
    if not task:
        return None
    # 只有任务状态为open时才能修改价格
    if task.status != "open":
        return None
    task.reward = new_reward
    db.commit()
    db.refresh(task)
    return task


def cancel_task(db: Session, task_id: int, user_id: str, is_admin_review: bool = False):
    """取消任务 - 支持管理员审核后的取消"""
    from app.models import Task

    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        return None

    # 检查权限
    if not is_admin_review:
        # 普通用户只能取消自己发布的任务，且只能是open状态
        if task.poster_id != user_id:
            return None
        if task.status != "open":
            return None
    else:
        # 管理员审核通过后，可以取消任何状态的任务
        # 检查用户是否是任务参与者（发布者或接受者）
        if task.poster_id != user_id and task.taker_id != user_id:
            return None

    # 更新任务状态为已取消
    task.status = "cancelled"

    # 记录任务历史
    if is_admin_review:
        add_task_history(db, task.id, user_id, "cancelled", "管理员审核通过后取消")
    else:
        add_task_history(db, task.id, task.poster_id, "cancelled", "任务发布者手动取消")

    # 创建通知给任务发布者
    create_notification(
        db,
        task.poster_id,
        "task_cancelled",
        "任务已取消",
        f'您的任务"{task.title}"已被取消',
        task.id,
    )

    # 如果任务有接受者，也通知接受者
    if task.taker_id and task.taker_id != task.poster_id:
        create_notification(
            db,
            task.taker_id,
            "task_cancelled",
            "任务已取消",
            f'您接受的任务"{task.title}"已被取消',
            task.id,
        )

    db.commit()
    db.refresh(task)

    # 自动更新相关用户的统计信息
    update_user_statistics(db, task.poster_id)
    if task.taker_id:
        update_user_statistics(db, task.taker_id)

    return task


def calculate_user_avg_rating(db: Session, user_id: str):
    """计算并更新用户的平均评分"""
    from sqlalchemy import func

    from app.models import Review

    # 计算用户收到的所有评价的平均分
    result = (
        db.query(func.avg(Review.rating)).filter(Review.user_id == user_id).scalar()
    )
    avg_rating = float(result) if result is not None else 0.0

    # 更新用户的平均评分
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        user.avg_rating = avg_rating
        db.commit()
        db.refresh(user)

    return avg_rating


def create_review(
    db: Session, user_id: str, task_id: int, review: schemas.ReviewCreate
):
    from app.models import Review, Task

    # 检查任务是否存在且已确认完成
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        return None
    if task.status != "completed":
        return None

    # 检查用户是否是任务的参与者（发布者或接受者）
    if task.poster_id != user_id and task.taker_id != user_id:
        return None

    # 检查用户是否已经评价过这个任务
    existing_review = (
        db.query(Review)
        .filter(Review.task_id == task_id, Review.user_id == user_id)
        .first()
    )
    if existing_review:
        return None

    db_review = Review(
        user_id=user_id,
        task_id=task_id,
        rating=review.rating,
        comment=review.comment,
        is_anonymous=1 if review.is_anonymous else 0,
    )
    db.add(db_review)
    db.commit()
    db.refresh(db_review)

    # 自动更新被评价用户的平均评分和统计信息
    # 确定被评价的用户（不是评价者）
    reviewed_user_id = task.taker_id if user_id == task.poster_id else task.poster_id
    if reviewed_user_id:
        update_user_statistics(db, reviewed_user_id)

    return db_review


def get_task_reviews(db: Session, task_id: int):
    """获取任务评价 - 只返回实名评价，匿名评价不显示在任务页面"""
    from app.models import Review
    return db.query(Review).filter(Review.task_id == task_id, Review.is_anonymous == 0).all()


def get_user_received_reviews(db: Session, user_id: str):
    """获取用户收到的所有评价（包括匿名评价），用于个人主页显示"""
    from app.models import Review, Task
    return (
        db.query(Review)
        .join(Task, Review.task_id == Task.id)
        .filter(
            (Task.poster_id == user_id) | (Task.taker_id == user_id),
            Review.user_id != user_id  # 排除自己给自己的评价
        )
        .all()
    )


def add_task_history(
    db: Session, task_id: int, user_id: str, action: str, remark: str = None
):
    from app.models import TaskHistory

    history = TaskHistory(
        task_id=task_id, user_id=user_id, action=action, remark=remark
    )
    db.add(history)
    db.commit()
    db.refresh(history)
    return history


def get_task_history(db: Session, task_id: int):
    from app.models import TaskHistory

    return (
        db.query(TaskHistory)
        .filter(TaskHistory.task_id == task_id)
        .order_by(TaskHistory.timestamp)
        .all()
    )


def send_message(db: Session, sender_id: str, receiver_id: str, content: str, message_id: str = None):
    from app.models import Message
    from datetime import datetime, timedelta

    # 如果有消息ID，先检查是否已存在
    if message_id:
        existing_by_id = (
            db.query(Message)
            .filter(Message.sender_id == sender_id)
            .filter(Message.content == content)
            .filter(Message.created_at >= datetime.now() - timedelta(minutes=1))
            .first()
        )
        if existing_by_id:
            print(f"检测到重复消息ID，跳过保存: {message_id}")
            return existing_by_id

    # 检查是否在最近5秒内发送过相同的消息（防止重复发送）
    recent_time = datetime.now() - timedelta(seconds=5)
    existing_message = (
        db.query(Message)
        .filter(
            Message.sender_id == sender_id,
            Message.receiver_id == receiver_id,
            Message.content == content,
            Message.created_at >= recent_time
        )
        .first()
    )
    
    if existing_message:
        print(f"检测到重复消息，跳过保存: {content}")
        return existing_message

    msg = Message(sender_id=sender_id, receiver_id=receiver_id, content=content)
    db.add(msg)
    db.commit()
    db.refresh(msg)
    return msg


def get_chat_history(
    db: Session, user1_id: str, user2_id: str, limit: int = 10, offset: int = 0
):
    """获取两个用户之间的聊天历史"""
    from sqlalchemy import and_, or_

    from app.models import Message

    # 特殊处理系统消息（user2_id为0）
    if user2_id == 0:
        query = db.query(Message).filter(
            and_(Message.sender_id.is_(None), Message.receiver_id == user1_id)
        )
    else:
        query = db.query(Message).filter(
            or_(
                and_(Message.sender_id == user1_id, Message.receiver_id == user2_id),
                and_(Message.sender_id == user2_id, Message.receiver_id == user1_id),
            )
        )

    return query.order_by(Message.created_at.desc()).offset(offset).limit(limit).all()


def get_unread_messages(db: Session, user_id: str):
    from app.models import Message

    return (
        db.query(Message)
        .filter(Message.receiver_id == user_id, Message.is_read == 0)
        .order_by(Message.created_at.desc())
        .all()
    )


def get_customer_service_messages(db: Session, session_id: int, limit: int = 50):
    """获取指定客服会话的所有消息"""
    from app.models import Message

    return (
        db.query(Message)
        .filter(Message.session_id == session_id)
        .order_by(Message.created_at.desc())
        .limit(limit)
        .all()
    )


def mark_message_read(db: Session, msg_id: int, user_id: str):
    from app.models import Message

    msg = (
        db.query(Message)
        .filter(Message.id == msg_id, Message.receiver_id == user_id)
        .first()
    )
    if msg:
        msg.is_read = 1
        db.commit()
        db.refresh(msg)
    return msg


def get_admin_messages(db: Session, admin_id: int):
    from app.models import Message

    return (
        db.query(Message)
        .filter(Message.receiver_id == admin_id, Message.is_admin_msg == 1)
        .order_by(Message.created_at.desc())
        .all()
    )


# 通知相关函数
def create_notification(
    db: Session,
    user_id: str,
    type: str,
    title: str,
    content: str,
    related_id: str = None,
):
    from app.models import Notification, get_uk_time_naive
    from sqlalchemy.exc import IntegrityError

    try:
        # 尝试创建新通知
        notification = Notification(
            user_id=user_id, type=type, title=title, content=content, related_id=related_id
        )
        db.add(notification)
        db.commit()
        db.refresh(notification)
        return notification
    except IntegrityError:
        # 如果违反唯一约束，更新现有通知
        db.rollback()
        existing_notification = db.query(Notification).filter(
            Notification.user_id == user_id,
            Notification.type == type,
            Notification.related_id == related_id
        ).first()
        
        if existing_notification:
            # 更新现有通知的内容和时间
            existing_notification.content = content
            existing_notification.title = title
            existing_notification.created_at = get_uk_time()
            existing_notification.is_read = 0  # 重置为未读
            db.commit()
            db.refresh(existing_notification)
            return existing_notification
        else:
            # 如果找不到现有通知，重新抛出异常
            raise


def get_user_notifications(db: Session, user_id: str, limit: int = 20):
    from app.models import Notification

    return (
        db.query(Notification)
        .filter(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc())
        .limit(limit)
        .all()
    )


def get_unread_notifications(db: Session, user_id: str):
    from app.models import Notification

    return (
        db.query(Notification)
        .filter(Notification.user_id == user_id, Notification.is_read == 0)
        .order_by(Notification.created_at.desc())
        .all()
    )


def get_unread_notification_count(db: Session, user_id: str):
    from app.models import Notification

    return (
        db.query(Notification)
        .filter(Notification.user_id == user_id, Notification.is_read == 0)
        .count()
    )


def get_notifications_with_recent_read(db: Session, user_id: str, recent_read_limit: int = 10):
    """获取所有未读通知和最近N条已读通知"""
    from app.models import Notification
    
    # 获取所有未读通知
    unread_notifications = (
        db.query(Notification)
        .filter(Notification.user_id == user_id, Notification.is_read == 0)
        .order_by(Notification.created_at.desc())
        .all()
    )
    
    # 获取最近N条已读通知
    recent_read_notifications = (
        db.query(Notification)
        .filter(Notification.user_id == user_id, Notification.is_read == 1)
        .order_by(Notification.created_at.desc())
        .limit(recent_read_limit)
        .all()
    )
    
    # 合并并重新排序（按创建时间降序）
    all_notifications = unread_notifications + recent_read_notifications
    all_notifications.sort(
        key=lambda x: x.created_at.timestamp() if x.created_at else 0, 
        reverse=True
    )
    
    return all_notifications


def mark_notification_read(db: Session, notification_id: int, user_id: str):
    from app.models import Notification

    notification = (
        db.query(Notification)
        .filter(Notification.id == notification_id, Notification.user_id == user_id)
        .first()
    )
    if notification:
        notification.is_read = 1
        db.commit()
        db.refresh(notification)
    return notification


def mark_all_notifications_read(db: Session, user_id: str):
    from app.models import Notification

    db.query(Notification).filter(
        Notification.user_id == user_id, Notification.is_read == 0
    ).update({Notification.is_read: 1})
    db.commit()


def delete_task_safely(db: Session, task_id: int):
    """安全删除任务及其所有相关记录"""
    from app.models import Message, Notification, Review, Task, TaskHistory

    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        return False

    # 保存相关用户ID用于后续更新统计
    poster_id = task.poster_id
    taker_id = task.taker_id

    try:
        # 1. 删除相关的通知
        db.query(Notification).filter(Notification.related_id == task_id).delete()

        # 2. 删除相关的评价
        db.query(Review).filter(Review.task_id == task_id).delete()

        # 3. 删除相关的任务历史
        db.query(TaskHistory).filter(TaskHistory.task_id == task_id).delete()

        # 4. 删除相关的消息（如果有的话）
        # 注意：这里我们只删除与任务相关的消息，如果有的话
        # 通常消息是用户之间的，不直接关联到任务，所以这里可能不需要

        # 5. 最后删除任务本身
        db.delete(task)

        db.commit()

        # 6. 更新相关用户的统计信息
        update_user_statistics(db, poster_id)
        if taker_id:
            update_user_statistics(db, taker_id)

        return True

    except Exception as e:
        db.rollback()
        raise e


def cancel_expired_tasks(db: Session):
    """自动取消已过期的未接受任务 - 使用英国时间进行比较"""
    from datetime import datetime, timedelta, timezone

    # 获取当前英国时间 (UTC+0)
    import pytz

    from app.models import Task, User

    uk_tz = pytz.timezone("Europe/London")
    now_local = get_uk_time()

    # 查找所有状态为'open'的任务
    open_tasks = db.query(Task).filter(Task.status == "open").all()

    cancelled_count = 0
    for task in open_tasks:
        try:
            # 数据库中的截止时间是naive datetime，需要转换为英国时间进行比较
            if task.deadline.tzinfo is None:
                # 如果deadline没有时区信息，假设它是英国时间
                task_deadline_uk = uk_tz.localize(task.deadline)
            else:
                # 如果deadline有时区信息，转换为英国时间
                task_deadline_uk = task.deadline.astimezone(uk_tz)

            if now_local > task_deadline_uk:
                # 将任务状态更新为已取消
                task.status = "cancelled"

                # 记录任务历史
                add_task_history(
                    db,
                    task.id,
                    task.poster_id,
                    "cancelled",
                    "任务因超过截止日期自动取消（基于UTC时间）",
                )

                # 创建通知给任务发布者
                create_notification(
                    db,
                    task.poster_id,
                    "task_cancelled",
                    "任务自动取消",
                    f'您的任务"{task.title}"因超过截止日期已自动取消（基于UTC时间）',
                    task.id,
                )

                cancelled_count += 1

        except Exception as e:
            # 记录错误但继续处理其他任务
            continue

    # 提交所有更改
    db.commit()
    return cancelled_count


def cleanup_cancelled_tasks(db: Session):
    """清理已取消的任务"""
    from app.models import Task

    # 查找所有状态为'cancelled'的任务
    cancelled_tasks = db.query(Task).filter(Task.status == "cancelled").all()

    deleted_count = 0
    for task in cancelled_tasks:
        try:
            # 记录任务历史
            add_task_history(
                db, task.id, task.poster_id, "deleted", "已取消任务被清理删除"
            )

            # 创建通知给任务发布者
            create_notification(
                db,
                task.poster_id,
                "task_deleted",
                "任务已删除",
                f'您的已取消任务"{task.title}"已被系统清理删除',
                task.id,
            )

            # 使用安全删除方法
            if delete_task_safely(db, task.id):
                deleted_count += 1

        except Exception as e:
            # 记录错误但继续处理其他任务
            continue

    return deleted_count


def delete_user_task(db: Session, task_id: int, user_id: str):
    """用户删除自己的任务（已取消的任务）"""
    from app.models import Task

    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        return None

    # 只有任务发布者可以删除任务
    if task.poster_id != user_id:
        return None

    # 只有已取消的任务可以删除
    if task.status != "cancelled":
        return None

    try:
        # 记录任务历史
        add_task_history(
            db,
            task.id,
            task.poster_id,
            "deleted",
            f"任务发布者手动删除（状态：{task.status}）",
        )

        # 创建通知
        create_notification(
            db,
            task.poster_id,
            "task_deleted",
            "任务已删除",
            f'您的{task.status}任务"{task.title}"已被删除',
            task.id,
        )

        # 使用安全删除方法
        if delete_task_safely(db, task.id):
            return {"message": "Task deleted successfully"}
        else:
            return None

    except Exception as e:
        db.rollback()
        raise e


def create_task_cancel_request(
    db: Session, task_id: int, requester_id: str, reason: str = None
):
    from app.models import TaskCancelRequest

    cancel_request = TaskCancelRequest(
        task_id=task_id, requester_id=requester_id, reason=reason
    )
    db.add(cancel_request)
    db.commit()
    db.refresh(cancel_request)
    return cancel_request


def get_task_cancel_requests(db: Session, status: str = None):
    from app.models import TaskCancelRequest

    query = db.query(TaskCancelRequest)
    if status:
        query = query.filter(TaskCancelRequest.status == status)
    return query.order_by(TaskCancelRequest.created_at.desc()).all()


def get_task_cancel_request_by_id(db: Session, request_id: int):
    from app.models import TaskCancelRequest

    return (
        db.query(TaskCancelRequest).filter(TaskCancelRequest.id == request_id).first()
    )


def update_task_cancel_request(
    db: Session, request_id: int, status: str, admin_id: int, admin_comment: str = None
):
    """更新任务取消请求状态"""
    request = (
        db.query(models.TaskCancelRequest)
        .filter(models.TaskCancelRequest.id == request_id)
        .first()
    )
    if request:
        request.status = status
        request.admin_id = admin_id
        request.admin_comment = admin_comment
        request.reviewed_at = get_uk_time()
        db.commit()
        db.refresh(request)
    return request


# 管理后台相关函数
def get_users_for_admin(
    db: Session, skip: int = 0, limit: int = 20, search: str = None
):
    """管理员获取用户列表"""
    query = db.query(models.User)

    if search:
        query = query.filter(
            or_(
                models.User.id.contains(search),  # 支持ID搜索
                models.User.name.contains(search),  # 支持用户名搜索
                models.User.email.contains(search),  # 支持邮箱搜索
            )
        )

    total = query.count()
    users = query.offset(skip).limit(limit).all()

    return {"users": users, "total": total}


def get_admin_users_for_admin(db: Session, skip: int = 0, limit: int = 20):
    """超级管理员获取管理员列表"""
    query = db.query(models.AdminUser)
    total = query.count()
    admin_users = query.offset(skip).limit(limit).all()

    return {"admin_users": admin_users, "total": total}


def delete_admin_user_by_super_admin(db: Session, admin_id: str):
    """超级管理员删除管理员账号"""
    admin = db.query(models.AdminUser).filter(models.AdminUser.id == admin_id).first()
    if admin:
        # 不能删除自己
        if admin.is_super_admin:
            return False
        db.delete(admin)
        db.commit()
        return True
    return False


# 员工提醒相关函数
def create_staff_notification(db: Session, notification_data: dict):
    """创建员工提醒"""
    notification = models.StaffNotification(**notification_data)
    db.add(notification)
    db.commit()
    db.refresh(notification)
    return notification


def get_staff_notifications(db: Session, recipient_id: str, recipient_type: str):
    """获取员工提醒列表（所有未读 + 5条最新已读）"""
    # 获取所有未读提醒
    unread_notifications = (
        db.query(models.StaffNotification)
        .filter(
            models.StaffNotification.recipient_id == recipient_id,
            models.StaffNotification.recipient_type == recipient_type,
            models.StaffNotification.is_read == 0,
        )
        .order_by(models.StaffNotification.created_at.desc())
        .all()
    )

    # 获取5条最新已读提醒
    read_notifications = (
        db.query(models.StaffNotification)
        .filter(
            models.StaffNotification.recipient_id == recipient_id,
            models.StaffNotification.recipient_type == recipient_type,
            models.StaffNotification.is_read == 1,
        )
        .order_by(models.StaffNotification.created_at.desc())
        .limit(5)
        .all()
    )

    # 合并并重新排序（按创建时间降序）
    all_notifications = unread_notifications + read_notifications
    all_notifications.sort(
        key=lambda x: x.created_at.timestamp() if x.created_at else 0, reverse=True
    )

    return all_notifications


def get_unread_staff_notifications(db: Session, recipient_id: str, recipient_type: str):
    """获取未读员工提醒"""
    notifications = (
        db.query(models.StaffNotification)
        .filter(
            models.StaffNotification.recipient_id == recipient_id,
            models.StaffNotification.recipient_type == recipient_type,
            models.StaffNotification.is_read == 0,
        )
        .order_by(models.StaffNotification.created_at.desc())
        .all()
    )
    return notifications


def get_unread_staff_notification_count(
    db: Session, recipient_id: str, recipient_type: str
):
    """获取未读员工提醒数量"""
    count = (
        db.query(models.StaffNotification)
        .filter(
            models.StaffNotification.recipient_id == recipient_id,
            models.StaffNotification.recipient_type == recipient_type,
            models.StaffNotification.is_read == 0,
        )
        .count()
    )
    return count


def mark_staff_notification_read(
    db: Session, notification_id: int, recipient_id: str, recipient_type: str
):
    """标记员工提醒为已读"""
    notification = (
        db.query(models.StaffNotification)
        .filter(
            models.StaffNotification.id == notification_id,
            models.StaffNotification.recipient_id == recipient_id,
            models.StaffNotification.recipient_type == recipient_type,
        )
        .first()
    )
    if notification:
        notification.is_read = 1
        notification.read_at = get_uk_time()
        db.commit()
        db.refresh(notification)
        return notification
    return None


def mark_all_staff_notifications_read(
    db: Session, recipient_id: str, recipient_type: str
):
    """标记所有员工提醒为已读"""
    notifications = (
        db.query(models.StaffNotification)
        .filter(
            models.StaffNotification.recipient_id == recipient_id,
            models.StaffNotification.recipient_type == recipient_type,
            models.StaffNotification.is_read == 0,
        )
        .all()
    )
    for notification in notifications:
        notification.is_read = 1
        notification.read_at = get_uk_time()
    db.commit()
    return len(notifications)


def update_user_by_admin(db: Session, user_id: str, user_update: dict):
    """管理员更新用户信息"""
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        for field, value in user_update.items():
            if value is not None and hasattr(user, field):
                setattr(user, field, value)
        db.commit()
        db.refresh(user)
    return user


def create_customer_service_by_admin(db: Session, cs_data: dict):
    """管理员创建客服账号"""
    # 创建用户账号
    from app.security import get_password_hash
    hashed_password = get_password_hash(cs_data["password"])
    user = models.User(
        name=cs_data["name"],
        email=cs_data["email"],
        hashed_password=hashed_password,
        is_customer_service=1,
        is_admin=0,
        is_super_admin=0,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # 创建客服记录
    cs = models.CustomerService(name=cs_data["name"], is_online=0)
    db.add(cs)
    db.commit()
    db.refresh(cs)

    return {"user": user, "customer_service": cs}


def delete_customer_service_by_admin(db: Session, cs_id: int):
    """管理员删除客服账号"""
    # 删除客服记录
    cs = (
        db.query(models.CustomerService)
        .filter(models.CustomerService.id == cs_id)
        .first()
    )
    if cs:
        # 找到对应的用户账号
        user = (
            db.query(models.User)
            .filter(models.User.name == cs.name, models.User.is_customer_service == 1)
            .first()
        )

        if user:
            db.delete(user)
        db.delete(cs)
        db.commit()
        return True
    return False


def get_customer_services_for_admin(db: Session, skip: int = 0, limit: int = 20):
    """管理员获取客服列表"""
    cs_list = db.query(models.CustomerService).offset(skip).limit(limit).all()
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


def send_admin_notification(
    db: Session,
    user_ids: list,
    title: str,
    content: str,
    notification_type: str = "admin_notification",
):
    """管理员发送通知"""
    notifications = []

    if not user_ids:  # 发送给所有用户
        users = db.query(models.User).filter(models.User.is_customer_service == 0).all()
        user_ids = [user.id for user in users]

    for user_id in user_ids:
        notification = models.Notification(
            user_id=user_id, type=notification_type, title=title, content=content
        )
        db.add(notification)
        notifications.append(notification)

    db.commit()
    return notifications


def get_dashboard_stats(db: Session):
    """获取管理后台统计数据"""
    # 统计普通用户数量（排除客服）
    total_users = db.query(models.User).count()
    total_tasks = db.query(models.Task).count()
    total_customer_service = db.query(models.CustomerService).count()
    active_sessions = (
        db.query(models.CustomerServiceChat)
        .filter(models.CustomerServiceChat.is_ended == 0)
        .count()
    )

    # 计算总收入（任务奖励总和）
    total_revenue = (
        db.query(func.sum(models.Task.reward))
        .filter(models.Task.status == "completed")
        .scalar()
        or 0.0
    )

    # 计算平均评分
    avg_rating = db.query(func.avg(models.CustomerService.avg_rating)).scalar() or 0.0

    return {
        "total_users": total_users,
        "total_tasks": total_tasks,
        "total_customer_service": total_customer_service,
        "active_sessions": active_sessions,
        "total_revenue": float(total_revenue),
        "avg_rating": float(avg_rating),
    }


def update_task_by_admin(db: Session, task_id: int, task_update: dict):
    """管理员更新任务信息"""
    task = db.query(models.Task).filter(models.Task.id == task_id).first()
    if task:
        for field, value in task_update.items():
            if value is not None and hasattr(task, field):
                setattr(task, field, value)
        db.commit()
        db.refresh(task)
    return task


def delete_task_by_admin(db: Session, task_id: int):
    """管理员删除任务"""
    task = db.query(models.Task).filter(models.Task.id == task_id).first()
    if task:
        db.delete(task)
        db.commit()
        return True
    return False


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


# 后台管理员相关函数
def get_admin_user_by_username(db: Session, username: str):
    """根据用户名获取后台管理员"""
    return (
        db.query(models.AdminUser).filter(models.AdminUser.username == username).first()
    )


def get_admin_user_by_id(db: Session, admin_id: str):
    """根据ID获取后台管理员"""
    return db.query(models.AdminUser).filter(models.AdminUser.id == admin_id).first()


def get_admin_user_by_email(db: Session, email: str):
    """根据邮箱获取后台管理员"""
    return db.query(models.AdminUser).filter(models.AdminUser.email == email).first()


def authenticate_admin_user(db: Session, username: str, password: str):
    """验证后台管理员登录凭据"""
    admin = get_admin_user_by_username(db, username)
    if not admin:
        return False
    if not admin.is_active:
        return False
    from app.security import verify_password
    if not verify_password(password, admin.hashed_password):
        return False
    return admin


def create_admin_user(db: Session, admin_data: dict):
    """创建后台管理员账号"""
    import random

    from app.id_generator import format_admin_id

    from app.security import get_password_hash
    hashed_password = get_password_hash(admin_data["password"])

    # 生成唯一的ID
    while True:
        # 生成4位随机数字
        random_id = random.randint(1000, 9999)
        admin_id = format_admin_id(random_id)

        # 检查ID是否已存在
        existing_admin = (
            db.query(models.AdminUser).filter(models.AdminUser.id == admin_id).first()
        )
        if not existing_admin:
            break

    admin = models.AdminUser(
        id=admin_id,
        name=admin_data["name"],
        username=admin_data["username"],
        email=admin_data["email"],
        hashed_password=hashed_password,
        is_super_admin=admin_data.get("is_super_admin", 0),
    )
    db.add(admin)
    db.commit()
    db.refresh(admin)
    return admin


def update_admin_last_login(db: Session, admin_id: str):
    """更新管理员最后登录时间"""
    admin = db.query(models.AdminUser).filter(models.AdminUser.id == admin_id).first()
    if admin:
        admin.last_login = get_uk_time()
        db.commit()
        db.refresh(admin)
    return admin


# 系统设置相关CRUD操作
def get_system_setting(db: Session, setting_key: str):
    """获取系统设置"""
    return (
        db.query(models.SystemSettings)
        .filter(models.SystemSettings.setting_key == setting_key)
        .first()
    )


def get_all_system_settings(db: Session):
    """获取所有系统设置"""
    return db.query(models.SystemSettings).all()


def create_system_setting(db: Session, setting: schemas.SystemSettingsCreate):
    """创建系统设置"""
    db_setting = models.SystemSettings(
        setting_key=setting.setting_key,
        setting_value=setting.setting_value,
        setting_type=setting.setting_type,
        description=setting.description,
    )
    db.add(db_setting)
    db.commit()
    db.refresh(db_setting)
    return db_setting


def update_system_setting(
    db: Session, setting_key: str, setting_value: str, description: str = None
):
    """更新系统设置"""
    db_setting = (
        db.query(models.SystemSettings)
        .filter(models.SystemSettings.setting_key == setting_key)
        .first()
    )
    if db_setting:
        db_setting.setting_value = setting_value
        if description is not None:
            db_setting.description = description
        db_setting.updated_at = get_uk_time()
        db.commit()
        db.refresh(db_setting)
    return db_setting


def upsert_system_setting(
    db: Session,
    setting_key: str,
    setting_value: str,
    setting_type: str = "string",
    description: str = None,
):
    """创建或更新系统设置"""
    db_setting = (
        db.query(models.SystemSettings)
        .filter(models.SystemSettings.setting_key == setting_key)
        .first()
    )
    if db_setting:
        # 更新现有设置
        db_setting.setting_value = setting_value
        if description is not None:
            db_setting.description = description
        db_setting.updated_at = get_uk_time()
    else:
        # 创建新设置
        db_setting = models.SystemSettings(
            setting_key=setting_key,
            setting_value=setting_value,
            setting_type=setting_type,
            description=description,
        )
        db.add(db_setting)

    db.commit()
    db.refresh(db_setting)
    return db_setting


def bulk_update_system_settings(
    db: Session, settings_data: schemas.SystemSettingsBulkUpdate
):
    """批量更新系统设置"""
    import json

    settings_map = {
        "vip_enabled": str(settings_data.vip_enabled),
        "super_vip_enabled": str(settings_data.super_vip_enabled),
        "vip_task_threshold": str(settings_data.vip_task_threshold),
        "super_vip_task_threshold": str(settings_data.super_vip_task_threshold),
        "vip_price_threshold": str(settings_data.vip_price_threshold),
        "super_vip_price_threshold": str(settings_data.super_vip_price_threshold),
        "vip_button_visible": str(settings_data.vip_button_visible),
        "vip_auto_upgrade_enabled": str(settings_data.vip_auto_upgrade_enabled),
        "vip_benefits_description": settings_data.vip_benefits_description,
        "super_vip_benefits_description": settings_data.super_vip_benefits_description,
        # VIP晋升超级VIP的条件
        "vip_to_super_task_count_threshold": str(
            settings_data.vip_to_super_task_count_threshold
        ),
        "vip_to_super_rating_threshold": str(
            settings_data.vip_to_super_rating_threshold
        ),
        "vip_to_super_completion_rate_threshold": str(
            settings_data.vip_to_super_completion_rate_threshold
        ),
        "vip_to_super_enabled": str(settings_data.vip_to_super_enabled),
    }

    updated_settings = []
    for key, value in settings_map.items():
        setting = upsert_system_setting(
            db=db,
            setting_key=key,
            setting_value=value,
            setting_type=(
                "boolean"
                if key.endswith("_enabled") or key.endswith("_visible")
                else (
                    "number"
                    if key.endswith("_threshold") or key.endswith("_rate_threshold")
                    else "string"
                )
            ),
            description=f"系统设置: {key}",
        )
        updated_settings.append(setting)

    return updated_settings


def get_system_settings_dict(db: Session):
    """获取系统设置字典"""
    settings = get_all_system_settings(db)
    settings_dict = {}
    for setting in settings:
        if setting.setting_type == "boolean":
            settings_dict[setting.setting_key] = setting.setting_value.lower() == "true"
        elif setting.setting_type == "number":
            try:
                # 尝试解析为浮点数，如果是整数则返回整数
                float_val = float(setting.setting_value)
                if float_val.is_integer():
                    settings_dict[setting.setting_key] = int(float_val)
                else:
                    settings_dict[setting.setting_key] = float_val
            except ValueError:
                settings_dict[setting.setting_key] = 0
        else:
            settings_dict[setting.setting_key] = setting.setting_value
    return settings_dict


def check_and_upgrade_vip_to_super(db: Session, user_id: str):
    """检查VIP用户是否满足晋升为超级VIP的条件，如果满足则自动晋升"""
    from app.models import Task, User

    # 获取用户信息
    user = db.query(User).filter(User.id == user_id).first()
    if not user or user.user_level != "vip":
        return False

    # 获取系统设置
    settings = get_system_settings_dict(db)

    # 检查是否启用自动晋升
    if not settings.get("vip_to_super_enabled", True):
        return False

    # 获取晋升条件阈值
    task_count_threshold = settings.get("vip_to_super_task_count_threshold", 50)
    rating_threshold = settings.get("vip_to_super_rating_threshold", 4.5)
    completion_rate_threshold = settings.get(
        "vip_to_super_completion_rate_threshold", 0.8
    )

    # 计算用户的任务统计
    # 发布任务数量
    posted_tasks = db.query(Task).filter(Task.poster_id == user_id).count()

    # 接受任务数量
    accepted_tasks = db.query(Task).filter(Task.taker_id == user_id).count()

    # 总任务数量
    total_task_count = posted_tasks + accepted_tasks

    # 计算任务完成率
    completed_tasks = (
        db.query(Task)
        .filter(Task.taker_id == user_id, Task.status == "completed")
        .count()
    )

    completion_rate = completed_tasks / accepted_tasks if accepted_tasks > 0 else 0

    # 获取用户平均评分（这里假设用户模型有rating字段，如果没有则需要从其他地方获取）
    user_rating = getattr(user, "avg_rating", 0) or 0

    # 检查是否满足所有晋升条件
    if (
        total_task_count >= task_count_threshold
        and user_rating >= rating_threshold
        and completion_rate >= completion_rate_threshold
    ):

        # 晋升为超级VIP
        user.user_level = "super"
        db.commit()
        db.refresh(user)

        # 创建晋升通知
        try:
            create_notification(
                db=db,
                user_id=user_id,
                type="vip_upgrade",
                title="恭喜晋升为超级VIP！",
                content=f"您已成功晋升为超级VIP会员！感谢您的优秀表现。",
                related_id="system",
            )
        except Exception as e:
            print(f"Failed to create upgrade notification: {e}")

        return True

    return False


def get_user_task_statistics(db: Session, user_id: str):
    """获取用户的任务统计信息"""
    from app.models import Task

    # 发布任务数量
    posted_tasks = db.query(Task).filter(Task.poster_id == user_id).count()

    # 接受任务数量
    accepted_tasks = db.query(Task).filter(Task.taker_id == user_id).count()

    # 完成任务数量
    completed_tasks = (
        db.query(Task)
        .filter(Task.taker_id == user_id, Task.status == "completed")
        .count()
    )

    # 计算完成率
    completion_rate = completed_tasks / accepted_tasks if accepted_tasks > 0 else 0

    return {
        "posted_tasks": posted_tasks,
        "accepted_tasks": accepted_tasks,
        "completed_tasks": completed_tasks,
        "total_tasks": posted_tasks + accepted_tasks,
        "completion_rate": round(completion_rate, 2),
    }


# 客服对话管理函数
def generate_customer_service_chat_id(user_id: str, service_id: str) -> str:
    """生成客服对话ID"""
    from datetime import datetime

    now = datetime.now()
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
        # 返回现有对话
        return {
            "chat_id": existing_chat.chat_id,
            "user_id": existing_chat.user_id,
            "service_id": existing_chat.service_id,
            "is_ended": existing_chat.is_ended,
            "created_at": existing_chat.created_at,
            "total_messages": existing_chat.total_messages,
        }

    # 创建新对话
    chat_id = generate_customer_service_chat_id(user_id, service_id)
    new_chat = CustomerServiceChat(
        chat_id=chat_id, user_id=user_id, service_id=service_id, is_ended=0
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
    new_chat.last_message_at = get_uk_time()
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
        "created_at": chat.created_at,
        "ended_at": chat.ended_at,
        "last_message_at": chat.last_message_at,
        "total_messages": chat.total_messages,
        "user_rating": chat.user_rating,
        "user_comment": chat.user_comment,
        "rated_at": chat.rated_at,
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
            "created_at": chat.created_at,
            "ended_at": chat.ended_at,
            "last_message_at": chat.last_message_at,
            "total_messages": chat.total_messages,
            "user_rating": chat.user_rating,
            "user_comment": chat.user_comment,
            "rated_at": chat.rated_at,
        }
        for chat in chats
    ]


def get_service_customer_service_chats(db: Session, service_id: str) -> list:
    """获取客服的所有对话 - 进行中对话置顶，已结束对话沉底且最多50个"""
    from sqlalchemy import or_

    from app.models import CustomerServiceChat

    # 分别查询进行中和已结束的对话
    # 1. 进行中的对话 - 按最后消息时间降序排列
    active_chats = (
        db.query(CustomerServiceChat)
        .filter(
            CustomerServiceChat.service_id == service_id,
            CustomerServiceChat.is_ended == 0,
        )
        .order_by(CustomerServiceChat.last_message_at.desc())
        .all()
    )

    # 2. 已结束的对话 - 按结束时间降序排列，最多50个
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

    # 合并列表：进行中的对话在前，已结束的对话在后
    all_chats = active_chats + ended_chats

    return [
        {
            "chat_id": chat.chat_id,
            "user_id": chat.user_id,
            "service_id": chat.service_id,
            "is_ended": chat.is_ended,
            "created_at": chat.created_at,
            "ended_at": chat.ended_at,
            "last_message_at": chat.last_message_at,
            "total_messages": chat.total_messages,
            "user_rating": chat.user_rating,
            "user_comment": chat.user_comment,
            "rated_at": chat.rated_at,
        }
        for chat in all_chats
    ]


def cleanup_old_ended_chats(db: Session, service_id: str) -> int:
    """清理客服的旧已结束对话，保留最新的50个"""
    from app.models import CustomerServiceChat

    # 获取所有已结束的对话，按结束时间降序排列
    all_ended_chats = (
        db.query(CustomerServiceChat)
        .filter(
            CustomerServiceChat.service_id == service_id,
            CustomerServiceChat.is_ended == 1,
        )
        .order_by(CustomerServiceChat.ended_at.desc())
        .all()
    )

    # 如果超过50个，删除多余的
    if len(all_ended_chats) > 50:
        chats_to_delete = all_ended_chats[50:]  # 保留前50个，删除其余的
        deleted_count = 0

        for chat in chats_to_delete:
            # 先删除相关的消息
            from app.models import CustomerServiceMessage

            db.query(CustomerServiceMessage).filter(
                CustomerServiceMessage.chat_id == chat.chat_id
            ).delete()

            # 再删除对话记录
            db.delete(chat)
            deleted_count += 1

        db.commit()
        return deleted_count

    return 0


def end_customer_service_chat(db: Session, chat_id: str) -> bool:
    """结束客服对话"""
    from app.models import CustomerServiceChat

    chat = (
        db.query(CustomerServiceChat)
        .filter(CustomerServiceChat.chat_id == chat_id)
        .first()
    )
    if not chat:
        return False

    chat.is_ended = 1
    chat.ended_at = get_uk_time()
    db.commit()

    # 结束对话后，清理该客服的旧已结束对话
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
    chat.rated_at = get_uk_time()
    db.commit()

    return True


def save_customer_service_message(
    db: Session, chat_id: str, sender_id: str, sender_type: str, content: str
) -> dict:
    """保存客服对话消息"""
    from datetime import datetime, timedelta, timezone

    from app.models import CustomerServiceChat, CustomerServiceMessage

    # 保存消息
    message = CustomerServiceMessage(
        chat_id=chat_id, sender_id=sender_id, sender_type=sender_type, content=content
    )

    db.add(message)

    # 更新对话的最后消息时间和总消息数
    chat = (
        db.query(CustomerServiceChat)
        .filter(CustomerServiceChat.chat_id == chat_id)
        .first()
    )
    if chat:
        # 使用英国时间 (UTC+0)
        chat.last_message_at = get_uk_time()
        chat.total_messages += 1

    db.commit()
    db.refresh(message)

    return {
        "id": message.id,
        "chat_id": message.chat_id,
        "sender_id": message.sender_id,
        "sender_type": message.sender_type,
        "content": message.content,
        "is_read": message.is_read,
        "created_at": message.created_at,
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
            "created_at": msg.created_at,
        }
        for msg in messages
    ]


def mark_customer_service_messages_read(
    db: Session, chat_id: str, reader_id: str
) -> int:
    """标记客服对话消息为已读"""
    from app.models import CustomerServiceMessage

    # 标记所有不是当前用户发送的消息为已读
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

    count = (
        db.query(CustomerServiceMessage)
        .filter(
            CustomerServiceMessage.chat_id == chat_id,
            CustomerServiceMessage.sender_id != reader_id,
            CustomerServiceMessage.is_read == 0,
        )
        .count()
    )

    return count
