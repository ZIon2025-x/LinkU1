import datetime
from datetime import timezone
from typing import Optional
from dateutil.relativedelta import relativedelta

from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session

from app import models, schemas
from app.utils.time_utils import get_utc_time, parse_iso_utc, format_iso_utc

# 密码加密上下文已移至 app.security 模块
# 请使用: from app.security import pwd_context


# ⚠️ 已删除：get_utc_time() 函数
# 请使用: from app.utils.time_utils import get_utc_time


# 密码哈希函数已移至 app.security 模块
# 请使用: from app.security import get_password_hash


# 密码验证函数已移至 app.security 模块
# 请使用: from app.security import verify_password


def get_user_by_email(db: Session, email: str):
    return db.query(models.User).filter(models.User.email == email).first()


def get_user_by_phone(db: Session, phone: str):
    """通过手机号查找用户"""
    # 清理手机号格式（移除所有非数字字符）
    import re
    phone_digits = re.sub(r'\D', '', phone)
    return db.query(models.User).filter(models.User.phone == phone_digits).first()


def get_user_by_id(db: Session, user_id: str):
    # 尝试从Redis缓存获取
    from app.redis_cache import get_user_info, cache_user_info
    cached_user = get_user_info(user_id)
    
    # 如果缓存返回的是字典（新格式），需要从数据库重新查询
    # 因为代码期望 SQLAlchemy 对象，而不是字典
    # 注意：缓存主要用于减少数据库查询，但为了兼容性，我们仍然从数据库返回对象
    if cached_user and isinstance(cached_user, dict):
        # 缓存命中但格式是字典，从数据库查询以确保返回 SQLAlchemy 对象
        # 这样可以保持代码兼容性
        user = db.query(models.User).filter(models.User.id == user_id).first()
        if user:
            # 重新缓存（现在会转换为字典格式）
            cache_user_info(user_id, user)
        return user
    
    # 如果缓存返回的是 SQLAlchemy 对象（旧格式），直接返回
    # 但这种情况不应该发生，因为我们已经修改了缓存逻辑
    if cached_user and hasattr(cached_user, '__table__'):
        return cached_user
    
    # 缓存未命中，从数据库查询
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        # 缓存用户信息（会自动转换为字典格式）
        cache_user_info(user_id, user)
    return user


def get_all_users(db: Session):
    return db.query(models.User).all()


def update_user_statistics(db: Session, user_id: str):
    """自动更新用户的统计信息：task_count, completed_task_count 和 avg_rating
    同时同步更新对应的 TaskExpert 和 FeaturedTaskExpert 数据（如果存在）"""
    from app.models import Review, Task
    from decimal import Decimal

    # 计算用户的总任务数（发布的任务 + 接受的任务）
    posted_tasks = db.query(Task).filter(Task.poster_id == user_id).count()
    taken_tasks = db.query(Task).filter(Task.taker_id == user_id).count()
    total_tasks = posted_tasks + taken_tasks

    # 计算用户已完成的任务数（作为接受者完成的）和作为发布者被别人完成的任务数
    completed_taken_tasks = db.query(Task).filter(
        Task.taker_id == user_id, 
        Task.status == "completed"
    ).count()
    completed_posted_tasks = db.query(Task).filter(
        Task.poster_id == user_id,
        Task.status == "completed"
    ).count()
    completed_tasks = completed_taken_tasks + completed_posted_tasks

    # 计算用户的平均评分
    avg_rating_result = (
        db.query(func.avg(Review.rating)).filter(Review.user_id == user_id).scalar()
    )
    avg_rating = float(avg_rating_result) if avg_rating_result is not None else 0.0

    # 计算完成率（用于 FeaturedTaskExpert）
    # 完成率 = (完成的接受任务数 / 接受过的任务数) × 100%
    completion_rate = (completed_taken_tasks / taken_tasks * 100.0) if taken_tasks > 0 else 0.0

    # 更新用户记录
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        user.task_count = total_tasks
        user.completed_task_count = completed_tasks
        user.avg_rating = avg_rating
        db.commit()
        db.refresh(user)
        
        # 同步更新 TaskExpert 数据（如果该用户是任务达人）
        # 因为任务达人就是用户，数据应该保持同步
        # 重要：预加载 services 关系，避免 refresh 时清除未加载的关系
        from sqlalchemy.orm import joinedload
        task_expert = db.query(models.TaskExpert).options(
            joinedload(models.TaskExpert.services)
        ).filter(models.TaskExpert.id == user_id).first()
        if task_expert:
            task_expert.completed_tasks = completed_tasks
            task_expert.rating = Decimal(str(avg_rating)).quantize(Decimal('0.01'))  # 保留2位小数
            # 注意：expert_name 只在创建时使用 user.name，后续不自动同步，允许手动修改
            # 注意：bio 是简介，应该由用户或管理员手动填写，不在这里自动更新
            
            db.commit()
            # 注意：由于已经预加载了 services，refresh 不会清除这些关系
            db.refresh(task_expert)
        
        # 同步更新 FeaturedTaskExpert 数据（如果该用户是特色任务达人）
        # 因为特色任务达人也是用户，数据应该保持同步
        # 注意：FeaturedTaskExpert.id 现在就是 user_id
        featured_expert = db.query(models.FeaturedTaskExpert).filter(
            models.FeaturedTaskExpert.id == user_id
        ).first()
        if featured_expert:
            featured_expert.avg_rating = avg_rating
            featured_expert.completed_tasks = completed_tasks
            featured_expert.total_tasks = total_tasks
            featured_expert.completion_rate = completion_rate
            # 注意：name 只在创建时使用 user.name，后续不自动同步，允许手动修改
            # 注意：头像不应该自动同步！特色任务达人的头像应该由管理员独立管理
            # 如果自动同步用户头像，会导致管理员设置的头像被覆盖
            # 因此完全移除头像同步逻辑，保持特色任务达人头像的独立性
            # 注意：bio 是简介，应该由用户或管理员手动填写，不在这里自动更新
            
            db.commit()
            db.refresh(featured_expert)

    return {"task_count": total_tasks, "completed_task_count": completed_tasks, "avg_rating": avg_rating}


def update_task_expert_bio(db: Session, user_id: str):
    """计算并更新任务达人的响应时间和相关统计字段
    
    注意：
    - bio 是简介，不应该在这里更新（应该由用户或管理员手动填写）
    - response_time 和 response_time_en 才是响应时间，需要计算
    """
    from app.models import Review, Task
    
    # 1. 计算平均响应时间（用于 response_time 和 response_time_en）
    avg_response_time_seconds = None
    read_messages = (
        db.query(models.Message, models.MessageRead)
        .join(
            models.MessageRead,
            models.MessageRead.message_id == models.Message.id
        )
        .filter(
            models.Message.receiver_id == user_id,
            models.Message.sender_id != user_id,  # 排除自己发送的消息
            models.MessageRead.user_id == user_id
        )
        .all()
    )
    
    if read_messages:
        response_times = []
        for message, message_read in read_messages:
            if message.created_at and message_read.read_at:
                # 计算响应时间（秒）
                response_time = (message_read.read_at - message.created_at).total_seconds()
                if response_time > 0:  # 只计算有效的响应时间
                    response_times.append(response_time)
        
        if response_times:
            avg_response_time_seconds = sum(response_times) / len(response_times)
    
    # 2. 格式化响应时间为简短文本（用于 response_time 和 response_time_en 字段）
    def format_response_time_short(seconds, lang='zh'):
        """将秒数格式化为简短文本（如：2小时内）
        
        Args:
            seconds: 响应时间（秒）
            lang: 'zh' 或 'en'
        """
        if seconds is None:
            return None
        
        if seconds < 3600:  # 小于1小时
            minutes = int(seconds / 60)
            if minutes == 0:
                return "1小时内" if lang == 'zh' else "Within 1 hour"
            return f"{minutes}分钟内" if lang == 'zh' else f"Within {minutes} minutes"
        elif seconds < 86400:  # 小于1天
            hours = int(seconds / 3600)
            return f"{hours}小时内" if lang == 'zh' else f"Within {hours} hours"
        else:  # 大于等于1天
            days = int(seconds / 86400)
            return f"{days}天内" if lang == 'zh' else f"Within {days} days"
    
    response_time_zh = format_response_time_short(avg_response_time_seconds, 'zh')
    response_time_en = format_response_time_short(avg_response_time_seconds, 'en')
    
    # 3. 计算任务统计数据
    posted_tasks = db.query(Task).filter(Task.poster_id == user_id).count()
    taken_tasks = db.query(Task).filter(Task.taker_id == user_id).count()
    total_tasks = posted_tasks + taken_tasks
    
    completed_taken_tasks = db.query(Task).filter(
        Task.taker_id == user_id, 
        Task.status == "completed"
    ).count()
    completed_posted_tasks = db.query(Task).filter(
        Task.poster_id == user_id,
        Task.status == "completed"
    ).count()
    completed_tasks = completed_taken_tasks + completed_posted_tasks
    
    # 计算完成率 = (完成的接受任务数 / 接受过的任务数) × 100%
    completion_rate = (completed_taken_tasks / taken_tasks * 100.0) if taken_tasks > 0 else 0.0
    
    # 4. 计算平均评分
    avg_rating_result = (
        db.query(func.avg(Review.rating)).filter(Review.user_id == user_id).scalar()
    )
    avg_rating = float(avg_rating_result) if avg_rating_result is not None else 0.0
    
    # 5. 计算成功率（已完成任务中评价>=3星的任务数 / 已完成任务数 * 100）
    # 使用 JOIN 查询已完成任务中，有评价且评价>=3星的任务数量
    from sqlalchemy import distinct
    successful_tasks_count = (
        db.query(distinct(Task.id))
        .join(Review, Task.id == Review.task_id)
        .filter(
            Task.status == "completed",
            (Task.poster_id == user_id) | (Task.taker_id == user_id),
            Review.rating >= 3.0
        )
        .count()
    )
    
    # 成功率 = (评价>=3星的已完成任务数 / 已完成任务数) * 100
    success_rate = (successful_tasks_count / completed_tasks * 100.0) if completed_tasks > 0 else 0.0
    
    # 6. 更新 FeaturedTaskExpert 的响应时间和统计字段
    # 注意：bio 是简介，不应该在这里更新，应该由用户或管理员手动填写
    # 注意：FeaturedTaskExpert.id 现在就是 user_id
    featured_expert = db.query(models.FeaturedTaskExpert).filter(
        models.FeaturedTaskExpert.id == user_id
    ).first()
    if featured_expert:
        # 只更新响应时间和统计字段，不更新 bio（bio 是简介，应该手动填写）
        featured_expert.response_time = response_time_zh
        featured_expert.response_time_en = response_time_en
        featured_expert.avg_rating = avg_rating
        featured_expert.completed_tasks = completed_tasks
        featured_expert.total_tasks = total_tasks
        featured_expert.completion_rate = completion_rate
        featured_expert.success_rate = success_rate
        db.commit()
        db.refresh(featured_expert)
    
    # 注意：TaskExpert 模型没有 response_time 字段，只有 bio 字段
    # bio 是简介，不应该在这里更新
    
    return response_time_zh


def update_all_task_experts_bio():
    """更新所有任务达人的响应时间和统计字段（每天执行一次）
    
    注意：
    - bio 是简介，不应该在这里更新（应该由用户或管理员手动填写）
    - response_time 和 response_time_en 才是响应时间，需要计算
    
    已弃用：此函数已改为 update_all_featured_task_experts_response_time
    """
    # 为了向后兼容，调用新函数
    return update_all_featured_task_experts_response_time()


def update_all_featured_task_experts_response_time():
    """更新所有特征任务达人（FeaturedTaskExpert）的响应时间（每天执行一次）
    
    注意：
    - 只更新 FeaturedTaskExpert 的 response_time 和 response_time_en
    - 不更新 bio（bio 是简介，应该由用户或管理员手动填写）
    """
    from app.database import SessionLocal
    from app.models import FeaturedTaskExpert
    import logging
    
    logger = logging.getLogger(__name__)
    
    db = None
    try:
        db = SessionLocal()
        # 获取所有特征任务达人
        featured_experts = db.query(FeaturedTaskExpert).all()
        updated_count = 0
        
        for expert in featured_experts:
            try:
                # 只更新响应时间，不更新其他字段
                update_task_expert_bio(db, expert.id)
                updated_count += 1
            except Exception as e:
                logger.error(f"更新特征任务达人 {expert.id} 的响应时间时出错: {e}")
                continue
        
        if updated_count > 0:
            logger.info(f"成功更新 {updated_count} 个特征任务达人的响应时间")
        else:
            logger.info("没有需要更新的特征任务达人")
        
        return updated_count
    
    except Exception as e:
        logger.error(f"更新特征任务达人响应时间时出错: {e}")
        raise
    finally:
        if db:
            db.close()


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

    # 处理同意时间
    terms_agreed_at = None
    if user.terms_agreed_at:
        terms_agreed_at = parse_iso_utc(user.terms_agreed_at.replace('Z', '+00:00') if user.terms_agreed_at.endswith('Z') else user.terms_agreed_at)
    
    db_user = models.User(
        id=user_id,
        name=user.name,
        email=user.email,
        phone=user.phone,
        hashed_password=hashed_password,
        avatar=user.avatar or "",
        agreed_to_terms=1 if user.agreed_to_terms else 0,
        terms_agreed_at=terms_agreed_at,
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


def get_user_tasks(db: Session, user_id: str, limit: int = 50, offset: int = 0):
    from app.models import Task, TaskTimeSlotRelation, TaskParticipant
    from sqlalchemy.orm import selectinload
    from sqlalchemy import or_, and_
    from datetime import datetime, timedelta, timezone
    
    # 直接从数据库查询，不使用缓存（避免缓存不一致问题）
    # 用户任务数据更新频繁，缓存TTL短且容易导致数据不一致
    # 使用预加载避免N+1查询
    
    # 计算3天前的时间（用于过滤已完成超过3天的任务）
    now_utc = get_utc_time()
    three_days_ago = now_utc - timedelta(days=3)
    
    # 1. 查询作为发布者或接受者的任务
    tasks_query = (
        db.query(Task)
        .options(
            selectinload(Task.poster),  # 预加载发布者
            selectinload(Task.taker),   # 预加载接受者
            selectinload(Task.reviews),   # 预加载评论
            selectinload(Task.time_slot_relations).selectinload(TaskTimeSlotRelation.time_slot),  # 预加载时间段关联
            selectinload(Task.participants)  # 预加载参与者，用于动态计算current_participants
        )
        .filter(
            or_(Task.poster_id == user_id, Task.taker_id == user_id),
            # 过滤掉已完成超过3天的任务
            or_(
                Task.status != "completed",
                and_(
                    Task.status == "completed",
                    Task.completed_at.isnot(None),
                    Task.completed_at > three_days_ago.replace(tzinfo=None) if three_days_ago.tzinfo else Task.completed_at > three_days_ago
                )
            )
        )
    )
    
    # 2. 查询作为多人任务参与者的任务
    participant_tasks_query = (
        db.query(Task)
        .join(TaskParticipant, Task.id == TaskParticipant.task_id)
        .options(
            selectinload(Task.poster),  # 预加载发布者
            selectinload(Task.taker),   # 预加载接受者
            selectinload(Task.reviews),   # 预加载评论
            selectinload(Task.time_slot_relations).selectinload(TaskTimeSlotRelation.time_slot),  # 预加载时间段关联
            selectinload(Task.participants)  # 预加载参与者，用于动态计算current_participants
        )
        .filter(
            and_(
                TaskParticipant.user_id == user_id,
                Task.is_multi_participant == True,
                # 过滤掉已完成超过3天的任务
                or_(
                    Task.status != "completed",
                    and_(
                        Task.status == "completed",
                        Task.completed_at.isnot(None),
                        Task.completed_at > three_days_ago.replace(tzinfo=None) if three_days_ago.tzinfo else Task.completed_at > three_days_ago
                    )
                )
            )
        )
    )
    
    # 合并两个查询结果，去重
    tasks_from_poster_taker = tasks_query.all()
    tasks_from_participant = participant_tasks_query.all()
    
    # 使用字典去重（按任务ID）
    tasks_dict = {}
    for task in tasks_from_poster_taker + tasks_from_participant:
        tasks_dict[task.id] = task
    
    # 转换为列表并排序
    tasks = list(tasks_dict.values())
    tasks.sort(key=lambda t: t.created_at, reverse=True)
    
    # 应用分页
    tasks = tasks[offset:offset + limit]
    
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
    vip_price_threshold = float(settings.get("vip_price_threshold", 10.0))
    super_vip_price_threshold = float(settings.get("super_vip_price_threshold", 50.0))

    # 处理价格字段：base_reward 是发布时的价格
    from decimal import Decimal
    base_reward_value = Decimal(str(task.reward)) if task.reward is not None else Decimal('0')
    
    # 任务等级分配逻辑（使用base_reward）
    if user.user_level == "super":
        task_level = "vip"
    elif float(base_reward_value) >= super_vip_price_threshold:
        task_level = "super"
    elif float(base_reward_value) >= vip_price_threshold:
        task_level = "vip"
    else:
        task_level = "normal"
    
    # 处理灵活时间和截止日期的一致性
    is_flexible = getattr(task, "is_flexible", 0) or 0
    deadline = None
    
    if is_flexible == 1:
        # 灵活模式：deadline 必须为 None
        deadline = None
    elif task.deadline is not None:
        # 非灵活模式：使用提供的 deadline
        deadline = task.deadline
        is_flexible = 0  # 有截止日期，确保 is_flexible=0
    else:
        # 如果没有提供 deadline 且不是灵活模式，设置默认值（7天后）
        from datetime import timedelta
        deadline = task.deadline if task.deadline else (get_utc_time() + timedelta(days=7))
        is_flexible = 0
    
    # 处理图片字段：将列表转为JSON字符串
    import json
    images_json = None
    if task.images and len(task.images) > 0:
        images_json = json.dumps(task.images)
    
    db_task = Task(
        title=task.title,
        description=task.description,
        deadline=deadline,
        is_flexible=is_flexible,  # 设置灵活时间标识
        reward=task.reward,  # 与base_reward同步
        base_reward=base_reward_value,  # 原始标价（发布时的价格）
        agreed_reward=None,  # 初始为空，如果有议价才会设置
        currency=getattr(task, "currency", "GBP") or "GBP",  # 货币类型
        location=task.location,
        task_type=task.task_type,
        poster_id=user_id,
        status="open",
        task_level=task_level,
        is_public=getattr(task, "is_public", 1),  # 默认为公开
        images=images_json,  # 存储为JSON字符串
    )
    db.add(db_task)
    db.commit()
    db.refresh(db_task)

    # 自动更新发布者的任务统计
    update_user_statistics(db, user_id)

    # 清除用户任务缓存，确保新任务能立即显示
    try:
        from app.redis_cache import invalidate_user_cache, invalidate_tasks_cache, redis_cache
        invalidate_user_cache(user_id)
        invalidate_tasks_cache()
        
        # 额外清除特定格式的缓存键
        patterns = [
            f"user_tasks:{user_id}*",
            f"{user_id}_*",
            f"user_tasks:{user_id}_*"
        ]
        for pattern in patterns:
            deleted = redis_cache.delete_pattern(pattern)
            if deleted > 0:
                print(f"DEBUG: 清除模式 {pattern}，删除了 {deleted} 个键")
    except Exception as e:
        print(f"清除缓存失败: {e}")

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
    from sqlalchemy import or_, and_
    from sqlalchemy.orm import selectinload
    from app.models import Task, User

    # 使用UTC时间进行过滤
    now_utc = get_utc_time()

    # 构建基础查询，直接在数据库层面完成所有过滤
    query = (
        db.query(Task)
        .options(selectinload(Task.poster))  # 预加载发布者信息，避免N+1查询
        .filter(
            and_(
                Task.status == "open",
                or_(
                    # 情况1：deadline有时区信息，直接比较
                    and_(
                        Task.deadline.isnot(None),
                        Task.deadline > now_utc
                    ),
                    # 情况2：deadline没有时区信息，假设是UTC时间
                    and_(
                        Task.deadline.isnot(None),
                        Task.deadline > now_utc.replace(tzinfo=None)
                    )
                )
            )
        )
    )
    
    # 在数据库层面添加任务类型筛选
    if task_type and task_type.strip():
        query = query.filter(Task.task_type == task_type.strip())

    # 在数据库层面添加城市筛选
    if location and location.strip():
        query = query.filter(Task.location == location.strip())

    # 在数据库层面添加关键词搜索（使用 pg_trgm 优化）
    if keyword and keyword.strip():
        from sqlalchemy import func
        keyword_clean = keyword.strip()
        
        # 使用相似度匹配，阈值设为 0.2（可以根据需要调整）
        # 这样可以支持拼写错误和部分匹配
        query = query.filter(
            or_(
                func.similarity(Task.title, keyword_clean) > 0.2,
                func.similarity(Task.description, keyword_clean) > 0.2,
                func.similarity(Task.task_type, keyword_clean) > 0.2,
                func.similarity(Task.location, keyword_clean) > 0.2,
                Task.title.ilike(f"%{keyword_clean}%"),  # 保留原始搜索作为备选
                Task.description.ilike(f"%{keyword_clean}%")
            )
        )
    
    # 在数据库层面完成排序
    if sort_by == "latest":
        query = query.order_by(Task.created_at.desc())
    elif sort_by == "reward_asc":
        query = query.order_by(Task.base_reward.asc())
    elif sort_by == "reward_desc":
        query = query.order_by(Task.base_reward.desc())
    elif sort_by == "deadline_asc":
        query = query.order_by(Task.deadline.asc())
    elif sort_by == "deadline_desc":
        query = query.order_by(Task.deadline.desc())
    else:
        # 默认按创建时间降序
        query = query.order_by(Task.created_at.desc())

    # 执行分页和查询
    tasks = query.offset(skip).limit(limit).all()

    # 为每个任务添加发布者时区信息（poster已经预加载，无需额外查询）
    for task in tasks:
        if task.poster:
            task.poster_timezone = task.poster.timezone if task.poster.timezone else "UTC"
        else:
            task.poster_timezone = "UTC"

    return tasks


def count_tasks(
    db: Session, task_type: str = None, location: str = None, keyword: str = None
):
    """计算符合条件的任务总数"""
    from sqlalchemy import or_

    from app.models import Task
    from datetime import timezone

    # 使用UTC时间进行过滤
    now_utc = get_utc_time()

    # 构建基础查询 - 需要手动过滤过期任务
    query = db.query(Task).filter(Task.status == "open")
    
    # 手动过滤过期任务（包括灵活模式任务，deadline 为 NULL）
    open_tasks = query.all()
    valid_tasks = []
    for task in open_tasks:
        # 灵活模式任务（deadline 为 NULL）始终有效
        if task.deadline is None:
            valid_tasks.append(task)
            continue
        
        # 有截止日期的任务，检查是否过期
        if task.deadline.tzinfo is None:
            task_deadline_utc = task.deadline.replace(tzinfo=timezone.utc)
        else:
            task_deadline_utc = task.deadline.astimezone(timezone.utc)
        
        if task_deadline_utc > now_utc:
            valid_tasks.append(task)

    # 添加任务类型筛选
    if task_type and task_type.strip():
        query = query.filter(Task.task_type == task_type)

    # 添加城市筛选
    if location and location.strip():
        query = query.filter(Task.location == location)

    # 添加关键词搜索（使用 pg_trgm 优化）
    if keyword and keyword.strip():
        from sqlalchemy import func
        keyword_clean = keyword.strip()
        query = query.filter(
            or_(
                func.similarity(Task.title, keyword_clean) > 0.2,
                func.similarity(Task.description, keyword_clean) > 0.2,
                Task.title.ilike(f"%{keyword_clean}%")
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
    """获取任务详情 - 优化 N+1 查询问题"""
    from app.models import Task, User, TaskTimeSlotRelation, Activity, ActivityTimeSlotRelation
    from sqlalchemy.orm import selectinload

    # 使用 selectinload 预加载关联数据，避免 N+1 查询
    task = (
        db.query(Task)
        .options(
            selectinload(Task.poster),  # 预加载发布者信息
            selectinload(Task.taker),   # 预加载接受者信息（如果存在）
            selectinload(Task.participants),  # 预加载参与者信息，用于动态计算current_participants
            selectinload(Task.time_slot_relations).selectinload(TaskTimeSlotRelation.time_slot),  # 预加载时间段关联，用于获取时间段信息
            selectinload(Task.parent_activity).selectinload(Activity.time_slot_relations).selectinload(ActivityTimeSlotRelation.time_slot),  # 预加载父活动的时间段关联（多人任务）
        )
        .filter(Task.id == task_id)
        .first()
    )
    
    if task:
        # 获取发布者时区信息（已通过 selectinload 预加载，无需额外查询）
        if task.poster:
            task.poster_timezone = task.poster.timezone if task.poster.timezone else "UTC"
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
    from decimal import Decimal

    task = (
        db.query(Task).filter(Task.id == task_id, Task.poster_id == poster_id).first()
    )
    if not task:
        return None
    # 只有任务状态为open时才能修改价格
    if task.status != "open":
        return None
    # 同时更新 reward 和 base_reward
    task.reward = new_reward
    task.base_reward = Decimal(str(new_reward))
    db.commit()
    db.refresh(task)
    return task


def cleanup_task_files(db: Session, task_id: int):
    """
    清理任务相关的所有图片和文件（公开和私密）
    使用新的image_cleanup模块统一处理
    """
    from app.image_cleanup import delete_task_images
    import logging
    
    logger = logging.getLogger(__name__)
    
    try:
        deleted_count = delete_task_images(task_id, include_private=True)
        logger.info(f"任务 {task_id} 已清理 {deleted_count} 个文件")
        return deleted_count
    except Exception as e:
        logger.error(f"清理任务文件失败 {task_id}: {e}")
        return 0


def cancel_task(db: Session, task_id: int, user_id: str, is_admin_review: bool = False):
    """取消任务 - 支持管理员审核后的取消，并清理相关文件"""
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
    
    # 更新时间段服务的参与者数量（如果任务有关联的时间段）
    from app.models import ServiceTimeSlot, TaskTimeSlotRelation, TaskParticipant
    
    # 检查任务是否通过TaskTimeSlotRelation关联了时间段
    task_time_slot_relation = db.query(TaskTimeSlotRelation).filter(
        TaskTimeSlotRelation.task_id == task_id
    ).first()
    
    if task_time_slot_relation and task_time_slot_relation.time_slot_id:
        # 如果是单个任务，直接减少时间段的参与者数量
        if not task.is_multi_participant:
            time_slot = db.query(ServiceTimeSlot).filter(
                ServiceTimeSlot.id == task_time_slot_relation.time_slot_id
            ).with_for_update().first()
            if time_slot and time_slot.current_participants > 0:
                time_slot.current_participants -= 1
                # 如果时间段现在有空位，确保is_available为True
                if time_slot.current_participants < time_slot.max_participants:
                    time_slot.is_available = True
                db.add(time_slot)
        else:
            # 如果是多人任务，需要检查所有参与者
            # 只统计状态为accepted或in_progress的参与者（这些参与者占用了时间段）
            participants = db.query(TaskParticipant).filter(
                TaskParticipant.task_id == task_id,
                TaskParticipant.status.in_(["accepted", "in_progress"])
            ).all()
            
            # 统计需要减少的参与者数量
            participants_to_decrement = len(participants)
            
            if participants_to_decrement > 0:
                time_slot = db.query(ServiceTimeSlot).filter(
                    ServiceTimeSlot.id == task_time_slot_relation.time_slot_id
                ).with_for_update().first()
                if time_slot:
                    # 减少对应数量的参与者
                    time_slot.current_participants = max(0, time_slot.current_participants - participants_to_decrement)
                    # 如果时间段现在有空位，确保is_available为True
                    if time_slot.current_participants < time_slot.max_participants:
                        time_slot.is_available = True
                    db.add(time_slot)
    
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

    # 清理任务相关的所有图片和文件
    try:
        cleanup_task_files(db, task_id)
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"清理任务文件失败 {task_id}: {e}")
        # 文件清理失败不影响任务取消流程

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

    # 检查用户是否是任务的参与者
    # 对于单人任务：检查是否是发布者或接受者
    # 对于多人任务：检查是否是发布者、接受者或 task_participants 表中的参与者
    is_participant = False
    if task.poster_id == user_id or task.taker_id == user_id:
        is_participant = True
    elif task.is_multi_participant:
        # 检查是否是 task_participants 表中的参与者
        from app.models import TaskParticipant
        participant = db.query(TaskParticipant).filter(
            TaskParticipant.task_id == task_id,
            TaskParticipant.user_id == user_id,
            TaskParticipant.status.in_(['accepted', 'in_progress', 'completed'])
        ).first()
        if participant:
            is_participant = True
    
    if not is_participant:
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
    db: Session, task_id: int, user_id: str | None, action: str, remark: str = None
):
    """添加任务历史记录
    user_id可以是None，用于管理员操作（管理员不在users表中）
    """
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


def send_message(db: Session, sender_id: str, receiver_id: str, content: str, message_id: str = None, timezone_str: str = "Europe/London", local_time_str: str = None, image_id: str = None):
    from app.models import Message
    from datetime import datetime, timedelta

    # 如果有消息ID，先检查是否已存在相同ID的消息
    if message_id:
        existing_by_id = (
            db.query(Message)
            .filter(Message.sender_id == sender_id)
            .filter(Message.content == content)
            .filter(Message.created_at >= get_utc_time() - timedelta(minutes=1))
            .first()
        )
        if existing_by_id:
            print(f"检测到重复消息ID，跳过保存: {message_id}")
            return existing_by_id

    # 检查是否在最近5秒内发送过完全相同的消息（防止重复发送）
    recent_time = get_utc_time() - timedelta(seconds=5)
    existing_message = (
        db.query(Message)
        .filter(
            Message.sender_id == sender_id,
            Message.receiver_id == receiver_id,
            Message.content == content,
            Message.created_at >= recent_time
        )
        .order_by(Message.created_at.desc())
        .first()
    )
    
    if existing_message:
        print(f"检测到重复消息，跳过保存: {content} (时间差: {(get_utc_time() - existing_message.created_at).total_seconds():.2f}秒)")
        return existing_message

    # 处理时间 - 统一使用UTC时间
    if local_time_str:
        # 使用用户提供的本地时间
        from app.utils.time_utils import parse_local_as_utc, LONDON
        from zoneinfo import ZoneInfo
        from datetime import datetime as dt
        
        # 解析本地时间字符串为datetime对象
        if 'T' in local_time_str:
            local_dt = dt.fromisoformat(local_time_str.replace('Z', '+00:00'))
        else:
            local_dt = dt.strptime(local_time_str, "%Y-%m-%d %H:%M")
        
        # 如果已经是带时区的，先转换为naive
        if local_dt.tzinfo is not None:
            local_dt = local_dt.replace(tzinfo=None)
        
        # 使用新的时间解析函数
        tz = ZoneInfo(timezone_str) if timezone_str != "Europe/London" else LONDON
        utc_time = parse_local_as_utc(local_dt, tz)
        tz_info = timezone_str
        local_time = local_time_str
    else:
        # 使用当前UTC时间
        utc_time = get_utc_time()
        tz_info = timezone_str
        local_time = None

    # 创建消息记录
    msg_data = {
        'sender_id': sender_id, 
        'receiver_id': receiver_id, 
        'content': content,
        'created_at': utc_time
    }
    
    # 如果image_id字段存在，则添加它
    if hasattr(Message, 'image_id') and image_id:
        msg_data['image_id'] = image_id
        print(f"🔍 [DEBUG] 设置image_id: {image_id}")
    else:
        print(f"🔍 [DEBUG] 未设置image_id - hasattr: {hasattr(Message, 'image_id')}, image_id: {image_id}")
    
    msg = Message(**msg_data)
    
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
    """
    获取未读消息（仅任务消息）
    ⚠️ 注意：普通消息（联系人聊天）已废弃，不再计入未读数
    统一使用 MessageRead 表来判断已读状态，不再使用 Message.is_read 字段
    """
    from app.models import Message, MessageRead, MessageReadCursor
    from sqlalchemy import and_, or_, not_, exists, select
    
    # ⚠️ 已移除：普通消息（联系人聊天功能已废弃，不再计入未读数）
    # 这些消息在界面上无法查看，因此不应该显示未读提示
    
    # 任务消息（通过MessageRead和MessageReadCursor判断）
    # 获取用户参与的所有任务（包括单人任务和多人任务）
    from app.models import Task, TaskParticipant
    task_ids_set = set()
    
    # 1. 作为发布者或接受者的任务（单人任务）
    user_tasks_1 = (
        db.query(Task.id)
        .filter(
            or_(
                Task.poster_id == user_id,
                Task.taker_id == user_id
            )
        )
        .all()
    )
    task_ids_set.update([task.id for task in user_tasks_1])
    
    # 2. 作为多人任务参与者的任务
    participant_tasks = (
        db.query(Task.id)
        .join(TaskParticipant, Task.id == TaskParticipant.task_id)
        .filter(
            and_(
                TaskParticipant.user_id == user_id,
                TaskParticipant.status.in_(["accepted", "in_progress", "completed"]),
                Task.is_multi_participant == True
            )
        )
        .all()
    )
    task_ids_set.update([task.id for task in participant_tasks])
    
    # 3. 作为多人任务创建者的任务（任务达人创建的活动）
    expert_creator_tasks = (
        db.query(Task.id)
        .filter(
            and_(
                Task.is_multi_participant == True,
                Task.created_by_expert == True,
                Task.expert_creator_id == user_id
            )
        )
        .all()
    )
    task_ids_set.update([task.id for task in expert_creator_tasks])
    
    task_ids = list(task_ids_set)
    
    if not task_ids:
        # 如果没有任务，返回空列表（不再返回普通消息）
        return []
    
    # 获取所有任务的游标
    cursors = (
        db.query(MessageReadCursor)
        .filter(
            MessageReadCursor.task_id.in_(task_ids),
            MessageReadCursor.user_id == user_id
        )
        .all()
    )
    # 构建游标字典，过滤掉 NULL 值（游标存在但 last_read_message_id 为 NULL 时视为没有游标）
    cursor_dict = {c.task_id: c.last_read_message_id for c in cursors if c.last_read_message_id is not None}
    
    # 查询任务消息的未读数
    task_unread_messages = []
    for task_id in task_ids:
        cursor = cursor_dict.get(task_id)
        
        if cursor is not None:
            # 有游标：查询ID大于游标的、不是自己发送的、非系统消息
            # 添加 JOIN 验证任务是否存在（防止任务删除后遗留消息被误判为未读）
            unread_msgs = (
                db.query(Message)
                .join(Task, Message.task_id == Task.id)  # 确保任务存在
                .filter(
                    Message.task_id == task_id,
                    Message.id > cursor,
                    Message.sender_id != user_id,
                    Message.sender_id.notin_(['system', 'SYSTEM']),  # 排除系统消息
                    Message.message_type != 'system',  # 排除系统类型消息
                    Message.conversation_type == 'task'
                )
                .all()
            )
        else:
            # 没有游标：查询在MessageRead表中没有记录的消息（排除自己发送的和系统消息）
            # 添加 JOIN 验证任务是否存在（防止任务删除后遗留消息被误判为未读）
            unread_msgs = (
                db.query(Message)
                .join(Task, Message.task_id == Task.id)  # 确保任务存在
                .filter(
                    Message.task_id == task_id,
                    Message.sender_id != user_id,
                    Message.sender_id.notin_(['system', 'SYSTEM']),  # 排除系统消息
                    Message.message_type != 'system',  # 排除系统类型消息
                    Message.conversation_type == 'task',
                    ~exists(
                        select(1).where(
                            and_(
                                MessageRead.message_id == Message.id,
                                MessageRead.user_id == user_id
                            )
                        )
                    )
                )
                .all()
            )
        
        task_unread_messages.extend(unread_msgs)
    
    # 只返回任务消息（不再包含普通消息）
    all_unread = task_unread_messages
    
    # 按创建时间排序
    all_unread.sort(key=lambda x: x.created_at, reverse=True)
    
    return all_unread


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
    auto_commit: bool = True,
):
    from app.models import Notification
    from app.utils.time_utils import get_utc_time
    from sqlalchemy.exc import IntegrityError

    try:
        # 尝试创建新通知
        notification = Notification(
            user_id=user_id, type=type, title=title, content=content, related_id=related_id
        )
        db.add(notification)
        if auto_commit:
            db.commit()
            db.refresh(notification)
        return notification
    except IntegrityError:
        # 如果违反唯一约束，更新现有通知
        if auto_commit:
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
            existing_notification.created_at = get_utc_time()
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
    """安全删除任务及其所有相关记录，包括图片和文件"""
    from app.models import Message, Notification, Review, Task, TaskHistory, MessageAttachment
    from pathlib import Path
    import os
    import logging
    
    logger = logging.getLogger(__name__)

    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        return False

    # 保存相关用户ID用于后续更新统计
    poster_id = task.poster_id
    taker_id = task.taker_id

    try:
        # 1. 删除议价响应日志（必须在删除任务申请之前）
        # 先获取所有相关的申请ID
        from app.models import TaskApplication, NegotiationResponseLog
        application_ids = [
            app.id for app in db.query(TaskApplication.id)
            .filter(TaskApplication.task_id == task_id)
            .all()
        ]
        
        # 删除所有相关的议价响应日志
        if application_ids:
            db.query(NegotiationResponseLog).filter(
                NegotiationResponseLog.application_id.in_(application_ids)
            ).delete(synchronize_session=False)
        
        # 2. 删除相关的任务申请（必须在删除任务之前）
        db.query(TaskApplication).filter(TaskApplication.task_id == task_id).delete(synchronize_session=False)

        # 3. 删除相关的通知
        db.query(Notification).filter(Notification.related_id == task_id).delete()

        # 4. 删除相关的评价
        db.query(Review).filter(Review.task_id == task_id).delete()

        # 5. 删除相关的任务历史
        db.query(TaskHistory).filter(TaskHistory.task_id == task_id).delete()

        # 5.5. 删除相关的 TaskTimeSlotRelation 记录（必须在删除任务之前）
        # 注意：虽然外键有 CASCADE，但显式删除可以避免 SQLAlchemy 尝试将 task_id 设置为 None
        from app.models import TaskTimeSlotRelation
        db.query(TaskTimeSlotRelation).filter(
            TaskTimeSlotRelation.task_id == task_id
        ).delete(synchronize_session=False)

        # 6. 查找并删除任务相关的消息、图片和文件
        # 获取与任务相关的所有消息
        task_messages = db.query(Message).filter(Message.task_id == task_id).all()
        
        # 收集需要删除的图片ID和文件ID
        image_ids = []
        message_ids = []
        
        for msg in task_messages:
            message_ids.append(msg.id)
            # 收集图片ID
            if msg.image_id:
                image_ids.append(msg.image_id)
        
        # 在删除消息之前，先删除相关的已读记录和游标记录
        if message_ids:
            # 删除 MessageRead 表中的已读记录（外键引用 messages.id）
            from app.models import MessageRead
            db.query(MessageRead).filter(
                MessageRead.message_id.in_(message_ids)
            ).delete(synchronize_session=False)
            
            # 删除 MessageReadCursor 表中的游标记录
            # 注意：需要删除 task_id 相关的记录，以及 last_read_message_id 在要删除的消息ID列表中的记录
            from app.models import MessageReadCursor
            db.query(MessageReadCursor).filter(
                MessageReadCursor.task_id == task_id
            ).delete(synchronize_session=False)
            
            # 同时删除其他任务中引用这些消息的游标（以防万一）
            db.query(MessageReadCursor).filter(
                MessageReadCursor.last_read_message_id.in_(message_ids)
            ).delete(synchronize_session=False)
        
        # 获取消息附件（文件）
        if message_ids:
            attachments = db.query(MessageAttachment).filter(
                MessageAttachment.message_id.in_(message_ids)
            ).all()
            
            # 删除附件文件
            for attachment in attachments:
                if attachment.blob_id:
                    try:
                        # 删除私密文件
                        railway_env = os.getenv("RAILWAY_ENVIRONMENT")
                        if railway_env:
                            file_dir = Path("/data/uploads/private/files")
                        else:
                            file_dir = Path("uploads/private/files")
                        
                        # 查找并删除文件（可能有不同扩展名）
                        file_pattern = f"{attachment.blob_id}.*"
                        for file_path in file_dir.glob(file_pattern):
                            file_path.unlink()
                            logger.info(f"删除任务附件文件: {file_path}")
                    except Exception as e:
                        logger.error(f"删除附件文件失败 {attachment.blob_id}: {e}")
            
            # 删除附件记录
            db.query(MessageAttachment).filter(
                MessageAttachment.message_id.in_(message_ids)
            ).delete(synchronize_session=False)
        
        # 删除图片文件
        for image_id in image_ids:
            try:
                # 删除私密图片
                railway_env = os.getenv("RAILWAY_ENVIRONMENT")
                if railway_env:
                    image_dir = Path("/data/uploads/private_images")
                else:
                    image_dir = Path("uploads/private_images")
                
                # 查找并删除图片（可能有不同扩展名）
                image_pattern = f"{image_id}.*"
                for img_path in image_dir.glob(image_pattern):
                    img_path.unlink()
                    logger.info(f"删除任务图片: {img_path}")
            except Exception as e:
                logger.error(f"删除图片失败 {image_id}: {e}")
        
        # 删除消息记录（现在可以安全删除了，因为所有外键引用都已删除）
        db.query(Message).filter(Message.task_id == task_id).delete()

        # 7. 最后删除任务本身（现在所有外键引用都已删除）
        db.delete(task)

        db.commit()

        # 8. 更新相关用户的统计信息
        update_user_statistics(db, poster_id)
        if taker_id:
            update_user_statistics(db, taker_id)

        logger.info(f"成功删除任务 {task_id}，包括 {len(image_ids)} 张图片和相关附件")
        return True

    except Exception as e:
        db.rollback()
        logger.error(f"删除任务失败 {task_id}: {e}")
        raise e


def cancel_expired_tasks(db: Session):
    """自动取消已过期的未接受任务 - 使用UTC时间进行比较，并同步更新参与者状态"""
    from datetime import datetime, timedelta, timezone
    import logging
    from sqlalchemy import text

    from app.models import Task, User

    logger = logging.getLogger(__name__)
    
    try:
        # 获取当前UTC时间
        now_utc = get_utc_time()
        logger.info(f"开始检查过期任务，当前UTC时间: {now_utc}")

        # 使用数据库查询直接找到过期的任务，避免逐个检查
        # 处理两种情况：deadline有时区信息和没有时区信息
        from sqlalchemy import and_, or_
        
        expired_tasks = db.query(Task).filter(
            and_(
                Task.status == "open",
                or_(
                    # 情况1：deadline有时区信息，直接比较
                    and_(
                        Task.deadline.isnot(None),
                        Task.deadline <= now_utc
                    ),
                    # 情况2：deadline没有时区信息，假设是UTC时间
                    and_(
                        Task.deadline.isnot(None),
                        Task.deadline <= now_utc.replace(tzinfo=None)
                    )
                )
            )
        ).all()

        logger.info(f"找到 {len(expired_tasks)} 个过期任务")

        cancelled_count = 0
        for task in expired_tasks:
            try:
                logger.info(f"取消过期任务 {task.id}: {task.title}")
                
                # 将任务状态更新为已取消
                task.status = "cancelled"

                # 同步更新所有申请者的状态为 rejected（任务取消时，申请应该被拒绝）
                # 先查询需要更新的申请者（用于后续通知）
                applicant_user_ids = []
                try:
                    # 使用 savepoint 来隔离可能失败的操作
                    # 这样即使 task_applications 表查询失败，也不会影响主事务
                    savepoint = db.begin_nested()
                    try:
                        # 先查询需要更新的申请者（状态为 pending 或 approved 的申请）
                        query_applicants_sql = text("""
                            SELECT DISTINCT applicant_id 
                            FROM task_applications 
                            WHERE task_id = :task_id 
                              AND status NOT IN ('rejected')
                        """)
                        applicants_result = db.execute(query_applicants_sql, {"task_id": task.id})
                        applicant_user_ids = [row[0] for row in applicants_result.fetchall()]
                        
                        # 更新 task_applications 表中所有非 rejected 状态的申请
                        if applicant_user_ids:
                            update_applicants_sql = text("""
                                UPDATE task_applications 
                                SET status = 'rejected'
                                WHERE task_id = :task_id 
                                  AND status NOT IN ('rejected')
                            """)
                            result = db.execute(update_applicants_sql, {"task_id": task.id})
                            applicants_updated = result.rowcount
                            if applicants_updated > 0:
                                logger.info(f"任务 {task.id} 已同步更新 {applicants_updated} 个申请状态为 rejected")
                        
                        # 提交 savepoint
                        savepoint.commit()
                    except Exception as e:
                        # 回滚 savepoint，不影响主事务
                        savepoint.rollback()
                        # 如果 task_applications 表查询失败，记录警告但继续处理
                        logger.warning(f"更新任务 {task.id} 的申请状态时出错（可能表不存在）: {e}")
                except Exception as e:
                    # 外层异常处理（savepoint 创建失败等）
                    logger.warning(f"更新任务 {task.id} 的申请状态时出错: {e}")
                
                # 使用申请者列表作为参与者列表（用于通知）
                participant_user_ids = applicant_user_ids

                # 记录任务历史
                add_task_history(
                    db,
                    task.id,
                    task.poster_id,
                    "cancelled",
                    "任务因超过截止日期自动取消",
                )

                # 创建通知给任务发布者（不自动提交）
                create_notification(
                    db,
                    task.poster_id,
                    "task_cancelled",
                    "任务自动取消",
                    f'您的任务"{task.title}"因超过截止日期已自动取消',
                    task.id,
                    auto_commit=False,
                )

                # 通知所有参与者
                for user_id in participant_user_ids:
                    if user_id != task.poster_id:  # 避免重复通知发布者
                        try:
                            create_notification(
                                db,
                                user_id,
                                "task_cancelled",
                                "任务自动取消",
                                f'您申请的任务"{task.title}"因超过截止日期已自动取消',
                                task.id,
                                auto_commit=False,
                            )
                        except Exception as e:
                            logger.warning(f"通知参与者 {user_id} 任务 {task.id} 取消时出错: {e}")

                cancelled_count += 1
                logger.info(f"任务 {task.id} 已成功取消")

            except Exception as e:
                logger.error(f"处理任务 {task.id} 时出错: {e}")
                # 记录错误但继续处理其他任务
                continue

        # 提交所有更改
        db.commit()
        logger.info(f"成功取消 {cancelled_count} 个过期任务")
        return cancelled_count
        
    except Exception as e:
        logger.error(f"取消过期任务时出错: {e}")
        db.rollback()
        return 0


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


def cleanup_completed_tasks_files(db: Session):
    """清理已完成超过3天的任务的图片和文件（公开和私密）"""
    from app.models import Task
    from datetime import timedelta
    import logging
    
    logger = logging.getLogger(__name__)
    
    # 计算3天前的时间
    now_utc = get_utc_time()
    three_days_ago = now_utc - timedelta(days=3)
    
    # 处理时区：将 three_days_ago 转换为 naive datetime（与数据库中的 completed_at 格式一致）
    three_days_ago_naive = three_days_ago.replace(tzinfo=None) if three_days_ago.tzinfo else three_days_ago
    
    # 查找已完成超过3天的任务
    # completed_at 在数据库中通常是 naive datetime
    completed_tasks = (
        db.query(Task)
        .filter(
            Task.status == "completed",
            Task.completed_at.isnot(None),
            Task.completed_at <= three_days_ago_naive
        )
        .all()
    )
    
    logger.info(f"找到 {len(completed_tasks)} 个已完成超过3天的任务，开始清理文件（公开和私密）")
    
    cleaned_count = 0
    for task in completed_tasks:
        try:
            cleanup_task_files(db, task.id)
            # 同时清理关联的商品图片（如果是跳蚤市场任务）
            if task.task_type == "Second-hand & Rental":
                cleanup_flea_market_item_files_for_task(db, task.id)
            cleaned_count += 1
            logger.info(f"成功清理任务 {task.id} 的文件")
        except Exception as e:
            logger.error(f"清理任务 {task.id} 文件失败: {e}")
            continue
    
    logger.info(f"完成清理，共清理 {cleaned_count} 个任务的文件")
    return cleaned_count


def cleanup_expired_tasks_files(db: Session):
    """清理过期任务（已取消或deadline已过超过3天）的图片和文件"""
    from app.models import Task, TaskHistory
    from datetime import timedelta, datetime as dt, timezone
    from app.utils.time_utils import get_utc_time
    from sqlalchemy import or_, and_, func
    from sqlalchemy.orm import selectinload
    import logging
    
    logger = logging.getLogger(__name__)
    
    # 获取当前UTC时间（带时区）
    now_utc = get_utc_time()
    three_days_ago = now_utc - timedelta(days=3)
    
    # 优化：批量查询所有已取消任务的取消时间，避免 N+1 查询
    # 1. 先获取所有已取消的任务ID
    cancelled_task_ids = db.query(Task.id).filter(Task.status == "cancelled").all()
    cancelled_task_ids = [tid[0] for tid in cancelled_task_ids]
    
    # 2. 批量查询这些任务的最新取消时间（一次性查询，避免 N+1）
    cancel_times_map = {}
    if cancelled_task_ids:
        # 使用窗口函数或子查询获取每个任务的最新取消时间
        from sqlalchemy import desc
        
        # 方法1：使用子查询获取每个任务的最新取消时间
        latest_cancels = (
            db.query(
                TaskHistory.task_id,
                func.max(TaskHistory.timestamp).label('cancel_time')
            )
            .filter(
                TaskHistory.task_id.in_(cancelled_task_ids),
                TaskHistory.action == "cancelled"
            )
            .group_by(TaskHistory.task_id)
            .all()
        )
        
        # 构建 task_id -> cancel_time 的映射
        for task_id, cancel_time in latest_cancels:
            cancel_times_map[task_id] = cancel_time
    
    # 3. 批量加载已取消的任务对象
    expired_tasks = []
    if cancelled_task_ids:
        cancelled_tasks = db.query(Task).filter(Task.id.in_(cancelled_task_ids)).all()
        
        for task in cancelled_tasks:
            # 从映射中获取取消时间，如果没有则使用 created_at
            cancel_time = cancel_times_map.get(task.id) or task.created_at
            if cancel_time:
                # 确保 cancel_time 是带时区的
                if cancel_time.tzinfo is None:
                    cancel_time = cancel_time.replace(tzinfo=timezone.utc)
                if cancel_time <= three_days_ago:
                    expired_tasks.append(task)
    
    # 2. 查找deadline已过超过3天的open任务
    deadline_expired_tasks = (
        db.query(Task)
        .filter(
            Task.status == "open",
            Task.deadline.isnot(None),
            Task.deadline <= three_days_ago
        )
        .all()
    )
    
    # 合并结果（去重）
    task_ids = {task.id for task in expired_tasks}
    for task in deadline_expired_tasks:
        if task.id not in task_ids:
            expired_tasks.append(task)
    
    logger.info(f"找到 {len(expired_tasks)} 个过期超过3天的任务，开始清理文件")
    
    cleaned_count = 0
    for task in expired_tasks:
        try:
            cleanup_task_files(db, task.id)
            cleaned_count += 1
            logger.info(f"成功清理过期任务 {task.id} 的文件")
        except Exception as e:
            logger.error(f"清理过期任务 {task.id} 文件失败: {e}")
            continue
    
    logger.info(f"完成清理，共清理 {cleaned_count} 个过期任务的文件")
    return cleaned_count


def cleanup_all_old_tasks_files(db: Session):
    """清理所有已完成和过期任务的图片和文件（超过3天）"""
    import logging
    
    logger = logging.getLogger(__name__)
    
    logger.info("开始清理所有已完成和过期任务的文件...")
    
    # 清理已完成任务的文件
    completed_count = cleanup_completed_tasks_files(db)
    
    # 清理过期任务的文件
    expired_count = cleanup_expired_tasks_files(db)
    
    total_count = completed_count + expired_count
    
    logger.info(f"清理完成：已完成任务 {completed_count} 个，过期任务 {expired_count} 个，总计 {total_count} 个")
    
    return {
        "completed_count": completed_count,
        "expired_count": expired_count,
        "total_count": total_count
    }


def cleanup_expired_time_slots(db: Session) -> int:
    """
    清理过期的时间段（保留期限方案）
    每天执行一次，删除超过保留期限的过期时间段
    优化：只清理对应任务已完成/取消的时间段，或保留最近30天的时间段（用于历史记录）
    """
    from datetime import timedelta, datetime as dt_datetime, time as dt_time
    from app.utils.time_utils import get_utc_time, parse_local_as_utc, LONDON
    import logging
    
    logger = logging.getLogger(__name__)
    
    try:
        current_utc = get_utc_time()
        # 保留最近30天的时间段（用于历史记录和审计）
        # 计算30天前的23:59:59（英国时间）转换为UTC
        thirty_days_ago = current_utc.date() - timedelta(days=30)
        cutoff_local = dt_datetime.combine(thirty_days_ago, dt_time(23, 59, 59))
        cutoff_time = parse_local_as_utc(cutoff_local, LONDON)
        
        # 查找超过保留期限的时间段
        # 优先清理：对应任务已完成/取消的时间段
        # 其次清理：没有关联任务的时间段
        expired_slots = db.query(models.ServiceTimeSlot).filter(
            models.ServiceTimeSlot.slot_start_datetime < cutoff_time,
            models.ServiceTimeSlot.is_manually_deleted == False,  # 不删除手动删除的（它们已经被标记为删除）
        ).all()
        
        # 检查时间段关联的任务状态
        from app.models import Task, TaskTimeSlotRelation
        slots_to_delete = []
        slots_with_active_tasks = 0
        
        for slot in expired_slots:
            # 检查是否有关联的任务
            task_relations = db.query(TaskTimeSlotRelation).filter(
                TaskTimeSlotRelation.time_slot_id == slot.id
            ).all()
            
            if task_relations:
                # 检查关联的任务状态
                task_ids = [rel.task_id for rel in task_relations]
                tasks = db.query(Task).filter(Task.id.in_(task_ids)).all()
                
                # 如果所有任务都是已完成或已取消状态，可以删除时间段
                all_finished = all(task.status in ['completed', 'cancelled'] for task in tasks)
                
                if all_finished:
                    slots_to_delete.append(slot)
                else:
                    slots_with_active_tasks += 1
                    logger.debug(f"时间段 {slot.id} 有未完成的任务，保留")
            else:
                # 没有关联任务的时间段，可以删除
                slots_to_delete.append(slot)
        
        # 删除符合条件的时间段
        
        deleted_count = 0
        slots_with_participants = 0
        for slot in slots_to_delete:
            try:
                # 记录有参与者的时间段数量（用于日志）
                if slot.current_participants > 0:
                    slots_with_participants += 1
                db.delete(slot)
                deleted_count += 1
            except Exception as e:
                logger.error(f"删除过期时间段失败 {slot.id}: {e}")
        
        if deleted_count > 0:
            db.commit()
            if slots_with_participants > 0:
                logger.info(f"清理了 {deleted_count} 个过期时间段（超过30天且任务已完成/取消），其中 {slots_with_participants} 个有参与者，保留了 {slots_with_active_tasks} 个有未完成任务的时间段")
            else:
                logger.info(f"清理了 {deleted_count} 个过期时间段（超过30天且任务已完成/取消），保留了 {slots_with_active_tasks} 个有未完成任务的时间段")
        elif slots_with_active_tasks > 0:
            logger.info(f"检查完成，保留了 {slots_with_active_tasks} 个有未完成任务的时间段（超过30天但任务未完成）")
        
        return deleted_count
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"清理过期时间段失败: {e}")
        db.rollback()
        return 0


def auto_generate_future_time_slots(db: Session) -> int:
    """
    自动为所有启用了时间段功能的服务生成下个月的今天的时间段
    每天执行一次，只生成新的一天，保持从今天到下个月的今天的时间段（一个月）
    """
    from datetime import date, timedelta, time as dt_time, datetime as dt_datetime
    from decimal import Decimal
    from app.utils.time_utils import parse_local_as_utc, LONDON
    
    try:
        # 获取所有启用了时间段功能且状态为active的服务
        services = db.query(models.TaskExpertService).filter(
            models.TaskExpertService.has_time_slots == True,
            models.TaskExpertService.status == 'active',
        ).all()
        
        if not services:
            return 0
        
        total_created = 0
        today = date.today()
        # 只生成下个月的今天的时间段（保持一个月）
        target_date = today + relativedelta(months=1)
        
        for service in services:
            try:
                # 检查配置
                has_weekly_config = service.weekly_time_slot_config and isinstance(service.weekly_time_slot_config, dict)
                
                if not has_weekly_config:
                    # 使用旧的统一配置
                    if not service.time_slot_start_time or not service.time_slot_end_time or not service.time_slot_duration_minutes or not service.participants_per_slot:
                        continue
                else:
                    # 使用新的按周几配置
                    if not service.time_slot_duration_minutes or not service.participants_per_slot:
                        continue
                
                # 使用服务的base_price作为默认价格
                price_per_participant = Decimal(str(service.base_price))
                
                # 周几名称映射
                weekday_names = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']
                
                created_count = 0
                duration_minutes = service.time_slot_duration_minutes
                
                # 只处理目标日期（未来第30天）
                current_date = target_date
                
                # 获取当前日期是周几
                weekday = current_date.weekday()
                weekday_name = weekday_names[weekday]
                
                # 确定该日期的时间段配置
                if has_weekly_config:
                    day_config = service.weekly_time_slot_config.get(weekday_name, {})
                    if not day_config.get('enabled', False):
                        # 该周几未启用，跳过这个服务
                        continue
                    
                    slot_start_time_str = day_config.get('start_time', '09:00:00')
                    slot_end_time_str = day_config.get('end_time', '18:00:00')
                    
                    try:
                        slot_start_time = dt_time.fromisoformat(slot_start_time_str)
                        slot_end_time = dt_time.fromisoformat(slot_end_time_str)
                    except ValueError:
                        if len(slot_start_time_str) == 5:
                            slot_start_time_str += ':00'
                        if len(slot_end_time_str) == 5:
                            slot_end_time_str += ':00'
                        slot_start_time = dt_time.fromisoformat(slot_start_time_str)
                        slot_end_time = dt_time.fromisoformat(slot_end_time_str)
                else:
                    slot_start_time = service.time_slot_start_time
                    slot_end_time = service.time_slot_end_time
                
                # 检查该日期是否被手动删除
                from datetime import datetime as dt_datetime
                start_local = dt_datetime.combine(current_date, dt_time(0, 0, 0))
                end_local = dt_datetime.combine(current_date, dt_time(23, 59, 59))
                start_utc = parse_local_as_utc(start_local, LONDON)
                end_utc = parse_local_as_utc(end_local, LONDON)
                
                deleted_check = db.query(models.ServiceTimeSlot).filter(
                    models.ServiceTimeSlot.service_id == service.id,
                    models.ServiceTimeSlot.slot_start_datetime >= start_utc,
                    models.ServiceTimeSlot.slot_start_datetime <= end_utc,
                    models.ServiceTimeSlot.is_manually_deleted == True,
                ).first()
                
                if deleted_check:
                    # 该日期已被手动删除，跳过
                    continue
                
                # 计算该日期的时间段
                current_time = slot_start_time
                while current_time < slot_end_time:
                    # 计算结束时间
                    total_minutes = current_time.hour * 60 + current_time.minute + duration_minutes
                    end_hour = total_minutes // 60
                    end_minute = total_minutes % 60
                    if end_hour >= 24:
                        break
                    
                    slot_end = dt_time(end_hour, end_minute)
                    if slot_end > slot_end_time:
                        break
                    
                    # 转换为UTC时间
                    slot_start_local = dt_datetime.combine(current_date, current_time)
                    slot_end_local = dt_datetime.combine(current_date, slot_end)
                    slot_start_utc = parse_local_as_utc(slot_start_local, LONDON)
                    slot_end_utc = parse_local_as_utc(slot_end_local, LONDON)
                    
                    # 检查是否已存在且未被手动删除
                    existing = db.query(models.ServiceTimeSlot).filter(
                        models.ServiceTimeSlot.service_id == service.id,
                        models.ServiceTimeSlot.slot_start_datetime == slot_start_utc,
                        models.ServiceTimeSlot.slot_end_datetime == slot_end_utc,
                        models.ServiceTimeSlot.is_manually_deleted == False,
                    ).first()
                    
                    if not existing:
                        # 创建新时间段
                        new_slot = models.ServiceTimeSlot(
                            service_id=service.id,
                            slot_start_datetime=slot_start_utc,
                            slot_end_datetime=slot_end_utc,
                            price_per_participant=price_per_participant,
                            max_participants=service.participants_per_slot,
                            current_participants=0,
                            is_available=True,
                            is_manually_deleted=False,
                        )
                        db.add(new_slot)
                        created_count += 1
                    
                    # 移动到下一个时间段
                    total_minutes = current_time.hour * 60 + current_time.minute + duration_minutes
                    next_hour = total_minutes // 60
                    next_minute = total_minutes % 60
                    if next_hour >= 24:
                        break
                    current_time = dt_time(next_hour, next_minute)
                
                if created_count > 0:
                    db.commit()
                    total_created += created_count
                    import logging
                    logger = logging.getLogger(__name__)
                    logger.info(f"为服务 {service.id} ({service.service_name}) 自动生成了 {created_count} 个时间段（{target_date}）")
                
            except Exception as e:
                import logging
                logger = logging.getLogger(__name__)
                logger.error(f"为服务 {service.id} 自动生成时间段失败: {e}")
                db.rollback()
                continue
        
        if total_created > 0:
            import logging
            logger = logging.getLogger(__name__)
            logger.info(f"总共自动生成了 {total_created} 个时间段（下个月的今天）")
        
        return total_created
        
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"自动生成时间段失败: {e}", exc_info=True)
        db.rollback()
        return 0


def cleanup_expired_flea_market_items(db: Session):
    """清理超过10天未刷新的跳蚤市场商品（自动删除）"""
    from app.models import FleaMarketItem
    from datetime import timedelta
    import logging
    import json
    import os
    import shutil
    from pathlib import Path
    from urllib.parse import urlparse
    
    logger = logging.getLogger(__name__)
    
    # 计算10天前的时间
    now_utc = get_utc_time()
    ten_days_ago = now_utc - timedelta(days=10)
    
    # 查找超过10天未刷新且状态为active的商品
    expired_items = (
        db.query(FleaMarketItem)
        .filter(
            FleaMarketItem.status == "active",
            FleaMarketItem.refreshed_at <= ten_days_ago
        )
        .all()
    )
    
    logger.info(f"找到 {len(expired_items)} 个超过10天未刷新的商品，开始清理")
    
    # 检测部署环境
    RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
    if RAILWAY_ENVIRONMENT:
        base_dir = Path("/data/uploads")
    else:
        base_dir = Path("uploads")
    
    deleted_count = 0
    for item in expired_items:
        try:
            # 删除商品图片文件
            if item.images:
                try:
                    images = json.loads(item.images) if isinstance(item.images, str) else item.images
                    
                    # 方法1：删除商品图片目录（标准路径）
                    flea_market_dir = base_dir / "flea_market" / str(item.id)
                    if flea_market_dir.exists():
                        shutil.rmtree(flea_market_dir)
                        logger.info(f"删除商品 {item.id} 的图片目录: {flea_market_dir}")
                    
                    # 方法2：从URL中提取路径并删除（兼容其他存储位置）
                    for image_url in images:
                        try:
                            # 解析URL，提取路径
                            parsed = urlparse(image_url)
                            path = parsed.path
                            
                            # 如果URL包含 /uploads/flea_market/，尝试删除对应文件
                            if "/uploads/flea_market/" in path:
                                # 提取相对路径
                                if path.startswith("/uploads/"):
                                    relative_path = path[len("/uploads/"):]
                                    file_path = base_dir / relative_path
                                    if file_path.exists():
                                        if file_path.is_file():
                                            file_path.unlink()
                                            logger.info(f"删除图片文件: {file_path}")
                                        elif file_path.is_dir():
                                            shutil.rmtree(file_path)
                                            logger.info(f"删除图片目录: {file_path}")
                        except Exception as e:
                            logger.warning(f"删除图片URL {image_url} 对应的文件失败: {e}")
                            
                except Exception as e:
                    logger.error(f"删除商品 {item.id} 图片文件失败: {e}")
            
            # 更新商品状态为deleted（软删除）
            item.status = "deleted"
            db.commit()
            
            deleted_count += 1
            logger.info(f"成功删除商品 {item.id}")
        except Exception as e:
            logger.error(f"删除商品 {item.id} 失败: {e}")
            db.rollback()
            continue
    
    logger.info(f"完成清理，共删除 {deleted_count} 个过期商品")
    return deleted_count


def cleanup_flea_market_item_files_for_task(db: Session, task_id: int):
    """清理任务关联的商品图片（任务完成后清理）"""
    from app.models import FleaMarketItem
    import json
    import os
    import shutil
    import logging
    from pathlib import Path
    from urllib.parse import urlparse
    
    logger = logging.getLogger(__name__)
    
    # 查找关联的商品
    item = db.query(FleaMarketItem).filter(
        FleaMarketItem.sold_task_id == task_id
    ).first()
    
    if not item:
        return
    
    try:
        # 检测部署环境
        RAILWAY_ENVIRONMENT = os.getenv("RAILWAY_ENVIRONMENT")
        if RAILWAY_ENVIRONMENT:
            base_dir = Path("/data/uploads")
        else:
            base_dir = Path("uploads")
        
        # 删除商品图片文件
        if item.images:
            try:
                images = json.loads(item.images) if isinstance(item.images, str) else item.images
                
                # 方法1：删除商品图片目录（标准路径）
                flea_market_dir = base_dir / "flea_market" / str(item.id)
                if flea_market_dir.exists():
                    shutil.rmtree(flea_market_dir)
                    logger.info(f"删除任务 {task_id} 关联的商品 {item.id} 的图片目录: {flea_market_dir}")
                
                # 方法2：从URL中提取路径并删除（兼容其他存储位置）
                for image_url in images:
                    try:
                        parsed = urlparse(image_url)
                        path = parsed.path
                        if "/uploads/flea_market/" in path:
                            if path.startswith("/uploads/"):
                                relative_path = path[len("/uploads/"):]
                                file_path = base_dir / relative_path
                                if file_path.exists():
                                    if file_path.is_file():
                                        file_path.unlink()
                                    elif file_path.is_dir():
                                        shutil.rmtree(file_path)
                    except Exception as e:
                        logger.warning(f"删除图片URL {image_url} 对应的文件失败: {e}")
                        
            except Exception as e:
                logger.error(f"删除商品 {item.id} 图片文件失败: {e}")
    except Exception as e:
        logger.error(f"清理任务 {task_id} 关联的商品图片失败: {e}")


def cleanup_all_completed_and_cancelled_tasks_files(db: Session):
    """清理所有已完成或已取消的任务的图片和文件（不检查时间限制，管理员手动清理）"""
    from app.models import Task
    from sqlalchemy import or_
    import logging
    
    logger = logging.getLogger(__name__)
    
    logger.info("开始清理所有已完成或已取消任务的文件（不检查时间限制）...")
    
    # 查找所有已完成或已取消的任务
    tasks_to_clean = (
        db.query(Task)
        .filter(
            or_(
                Task.status == "completed",
                Task.status == "cancelled"
            )
        )
        .all()
    )
    
    logger.info(f"找到 {len(tasks_to_clean)} 个已完成或已取消的任务，开始清理文件（公开和私密）")
    
    completed_count = 0
    cancelled_count = 0
    
    for task in tasks_to_clean:
        try:
            cleanup_task_files(db, task.id)
            if task.status == "completed":
                completed_count += 1
            elif task.status == "cancelled":
                cancelled_count += 1
            logger.info(f"成功清理任务 {task.id} 的文件（状态：{task.status}）")
        except Exception as e:
            logger.error(f"清理任务 {task.id} 文件失败: {e}")
            continue
    
    total_count = completed_count + cancelled_count
    
    logger.info(f"清理完成：已完成任务 {completed_count} 个，已取消任务 {cancelled_count} 个，总计 {total_count} 个")
    
    return {
        "completed_count": completed_count,
        "cancelled_count": cancelled_count,
        "total_count": total_count
    }


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
    db: Session, request_id: int, status: str, reviewer_id: str, admin_comment: str = None, reviewer_type: str = None
):
    """
    更新任务取消请求状态
    
    Args:
        reviewer_id: 审核者ID（管理员ID或客服ID）
        reviewer_type: 审核者类型，'admin' 或 'service'。如果为None，根据ID格式自动判断
    """
    request = (
        db.query(models.TaskCancelRequest)
        .filter(models.TaskCancelRequest.id == request_id)
        .first()
    )
    if request:
        request.status = status
        request.admin_comment = admin_comment
        request.reviewed_at = get_utc_time()
        
        # 根据审核者类型设置相应字段
        if reviewer_type is None:
            # 自动判断：管理员ID以'A'开头（格式：A0001），客服ID以'CS'开头（格式：CS8888）
            if reviewer_id.startswith('A'):
                reviewer_type = 'admin'
            elif reviewer_id.startswith('CS'):
                reviewer_type = 'service'
            else:
                # 默认为管理员（向后兼容）
                reviewer_type = 'admin'
        
        # 先清除两个字段，避免旧数据干扰
        if reviewer_type == 'admin':
            request.service_id = None  # 先清除客服ID
            request.admin_id = reviewer_id  # 设置管理员ID
        elif reviewer_type == 'service':
            request.admin_id = None  # 先清除管理员ID
            request.service_id = reviewer_id  # 设置客服ID
        
        db.flush()  # 先刷新到数据库，检查是否有错误
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
        from sqlalchemy import func
        search_clean = search.strip()
        
        # 使用 pg_trgm 实现智能搜索
        query = query.filter(
            or_(
                func.similarity(models.User.name, search_clean) > 0.2,
                func.similarity(models.User.email, search_clean) > 0.2,
                models.User.id.contains(search_clean),  # 保留 ID 精确搜索
                models.User.name.ilike(f"%{search_clean}%"),  # 模糊匹配作为备选
                models.User.email.ilike(f"%{search_clean}%")
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
        
        # 检查是否有不可为空的记录引用此管理员（created_by不可为空，使用RESTRICT约束）
        # 检查岗位（JobPosition）
        job_count = db.query(models.JobPosition).filter(
            models.JobPosition.created_by == admin_id
        ).count()
        
        # 检查精选任务达人（FeaturedTaskExpert）
        expert_count = db.query(models.FeaturedTaskExpert).filter(
            models.FeaturedTaskExpert.created_by == admin_id
        ).count()
        
        # 检查管理员奖励（AdminReward）
        reward_count = db.query(models.AdminReward).filter(
            models.AdminReward.created_by == admin_id
        ).count()
        
        if job_count > 0 or expert_count > 0 or reward_count > 0:
            # 有相关记录，不能删除
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
        notification.read_at = get_utc_time()
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
        notification.read_at = get_utc_time()
    db.commit()
    return len(notifications)


def create_audit_log(
    db: Session,
    action_type: str,
    entity_type: str,
    entity_id: str,
    admin_id: str = None,
    user_id: str = None,
    old_value: dict = None,
    new_value: dict = None,
    reason: str = None,
    ip_address: str = None,
    device_fingerprint: str = None,
):
    """创建审计日志记录
    old_value和new_value应该是dict类型，SQLAlchemy的JSONB会自动处理
    """
    from app.models import AuditLog
    
    audit_log = AuditLog(
        action_type=action_type,
        entity_type=entity_type,
        entity_id=str(entity_id),
        admin_id=admin_id,
        user_id=user_id,
        old_value=old_value,  # JSONB类型会自动处理dict
        new_value=new_value,  # JSONB类型会自动处理dict
        reason=reason,
        ip_address=ip_address,
        device_fingerprint=device_fingerprint,
    )
    db.add(audit_log)
    db.commit()
    db.refresh(audit_log)
    return audit_log


def update_user_by_admin(db: Session, user_id: str, user_update: dict):
    """管理员更新用户信息"""
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user:
        # 记录修改前的值
        old_values = {}
        new_values = {}
        
        for field, value in user_update.items():
            if value is not None and hasattr(user, field):
                old_value = getattr(user, field)
                # 只记录有变更的字段
                if old_value != value:
                    old_values[field] = old_value
                    new_values[field] = value
                    setattr(user, field, value)
        
        db.commit()
        db.refresh(user)
        
        # 如果有变更，返回变更信息用于审计日志
        if old_values:
            return user, old_values, new_values
    return user, None, None


def update_customer_service_online_status(db: Session, cs_id: str, is_online: bool):
    """更新客服在线状态"""
    cs = db.query(models.CustomerService).filter(models.CustomerService.id == cs_id).first()
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
        is_online=0
    )
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
        # ⚠️ User模型没有is_customer_service字段
        # 通过邮箱或名称找到对应的用户账号（如果存在）
        # 注意：客服和用户是分开的模型，可能没有对应的User记录
        user = (
            db.query(models.User)
            .filter(models.User.email == cs.email)
            .first()
        )
        
        # 如果通过邮箱找不到，尝试通过名称（但名称可能不唯一）
        if not user:
            user = (
                db.query(models.User)
                .filter(models.User.name == cs.name)
                .first()
            )

        # 如果找到对应的用户，检查是否有任务（poster_id是RESTRICT约束）
        if user:
            # 检查是否有任务
            task_count = db.query(models.Task).filter(
                models.Task.poster_id == user.id
            ).count()
            
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
        # ⚠️ User模型没有is_customer_service字段，客服是单独的CustomerService模型
        # 使用ID格式判断：客服ID格式为CS+4位数字，用户ID为8位数字
        from app.id_generator import is_customer_service_id
        all_users = db.query(models.User).all()
        # 过滤掉客服用户（客服ID格式：CS+4位数字）
        users = [user for user in all_users if not is_customer_service_id(user.id)]
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

    # 计算总收入（任务奖励总和，使用base_reward）
    total_revenue = (
        db.query(func.sum(models.Task.base_reward))
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
    import json
    task = db.query(models.Task).filter(models.Task.id == task_id).first()
    if task:
        # 记录修改前的值
        old_values = {}
        new_values = {}
        
        for field, value in task_update.items():
            if value is not None and hasattr(task, field):
                old_value = getattr(task, field)
                # 特殊处理 images 字段：如果是列表，需要序列化为 JSON 字符串
                if field == 'images' and isinstance(value, list):
                    new_value = json.dumps(value) if value else None
                else:
                    new_value = value
                
                # 只记录有变更的字段
                if old_value != new_value:
                    # 对于images字段，如果old_value是字符串，需要解析
                    if field == 'images' and isinstance(old_value, str):
                        try:
                            old_values[field] = json.loads(old_value) if old_value else None
                        except:
                            old_values[field] = old_value
                    else:
                        old_values[field] = old_value
                    
                    if field == 'images' and isinstance(new_value, str):
                        try:
                            new_values[field] = json.loads(new_value) if new_value else None
                        except:
                            new_values[field] = new_value
                    else:
                        new_values[field] = new_value
                    
                    # 设置新值
                    if field == 'images' and isinstance(value, list):
                        setattr(task, field, json.dumps(value) if value else None)
                    else:
                        setattr(task, field, value)
        
        db.commit()
        db.refresh(task)
        
        # 如果有变更，返回变更信息用于审计日志
        if old_values:
            return task, old_values, new_values
    return task, None, None


def delete_task_by_admin(db: Session, task_id: int):
    """管理员删除任务（使用安全删除方法，确保删除所有相关数据）"""
    return delete_task_safely(db, task_id)


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
        admin.last_login = get_utc_time()
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
        db_setting.updated_at = get_utc_time()
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
        db_setting.updated_at = get_utc_time()
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
    task_count_threshold = int(settings.get("vip_to_super_task_count_threshold", 50))
    rating_threshold = float(settings.get("vip_to_super_rating_threshold", 4.5))
    completion_rate_threshold = float(settings.get(
        "vip_to_super_completion_rate_threshold", 0.8
    ))

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
        "last_message_at": format_iso_utc(chat.last_message_at) if chat.last_message_at else None,
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
            "last_message_at": format_iso_utc(chat.last_message_at) if chat.last_message_at else None,
            "total_messages": chat.total_messages,
            "user_rating": chat.user_rating,
            "user_comment": chat.user_comment,
            "rated_at": format_iso_utc(chat.rated_at) if chat.rated_at else None,
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
            "created_at": format_iso_utc(chat.created_at) if chat.created_at else None,
            "ended_at": format_iso_utc(chat.ended_at) if chat.ended_at else None,
            "last_message_at": format_iso_utc(chat.last_message_at) if chat.last_message_at else None,
            "total_messages": chat.total_messages,
            "user_rating": chat.user_rating,
            "user_comment": chat.user_comment,
            "rated_at": format_iso_utc(chat.rated_at) if chat.rated_at else None,
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


def add_user_to_customer_service_queue(db: Session, user_id: str) -> dict:
    """将用户添加到客服排队队列"""
    from app.models import CustomerServiceQueue
    
    # 检查用户是否已在队列中（等待或已分配但未完成）
    existing_queue = (
        db.query(CustomerServiceQueue)
        .filter(
            CustomerServiceQueue.user_id == user_id,
            CustomerServiceQueue.status.in_(["waiting", "assigned"])
        )
        .first()
    )
    
    if existing_queue:
        # 计算等待时间
        from app.utils.time_utils import get_utc_time
        wait_seconds = int((get_utc_time() - existing_queue.queued_at).total_seconds())
        wait_time_minutes = wait_seconds // 60
        
        result = {
            "queue_id": existing_queue.id,
            "status": existing_queue.status,
            "queued_at": format_iso_utc(existing_queue.queued_at) if existing_queue.queued_at else None,
            "wait_seconds": wait_seconds,
            "wait_time_minutes": wait_time_minutes,
            "assigned_service_id": existing_queue.assigned_service_id
        }
        
        # 如果状态是waiting，计算排队位置和预计等待时间
        if existing_queue.status == "waiting":
            # 计算排队位置
            queue_position = db.query(CustomerServiceQueue).filter(
                CustomerServiceQueue.status == "waiting",
                CustomerServiceQueue.queued_at <= existing_queue.queued_at
            ).count()
            
            # 计算预计等待时间
            estimated_wait_time = calculate_estimated_wait_time(queue_position, db)
            result["queue_position"] = queue_position
            result["estimated_wait_time"] = estimated_wait_time  # 分钟
        
        return result
    
    # 创建新的排队记录
    from app.utils.time_utils import get_utc_time
    new_queue = CustomerServiceQueue(
        user_id=user_id,
        status="waiting",
        queued_at=get_utc_time()
    )
    db.add(new_queue)
    db.commit()
    db.refresh(new_queue)
    
    # 计算排队位置和预计等待时间
    queue_position = db.query(CustomerServiceQueue).filter(
        CustomerServiceQueue.status == "waiting",
        CustomerServiceQueue.queued_at <= new_queue.queued_at
    ).count()
    
    estimated_wait_time = calculate_estimated_wait_time(queue_position, db)
    
    return {
        "queue_id": new_queue.id,
        "status": "waiting",
        "queued_at": format_iso_utc(new_queue.queued_at) if new_queue.queued_at else None,
        "wait_seconds": 0,
        "wait_time_minutes": 0,
        "queue_position": queue_position,
        "estimated_wait_time": estimated_wait_time  # 分钟
    }


def calculate_estimated_wait_time(
    queue_position: int,
    db: Session
) -> int:
    """
    计算预计等待时间（分钟）
    使用移动平均处理时长，统一使用UTC时间
    返回：至少1分钟，避免返回0
    
    单一权威实现：所有调用此函数的地方应统一引用此实现，避免重复定义
    严禁在接口返回示例中内联简化版实现，必须统一调用此函数
    """
    from sqlalchemy import func
    from app.models import CustomerService, CustomerServiceChat
    from app.utils.time_utils import get_utc_time, to_utc
    
    # 获取最近100个已分配对话的平均处理时长
    recent_chats = db.query(CustomerServiceChat).filter(
        CustomerServiceChat.is_ended == 1,
        CustomerServiceChat.ended_at.isnot(None),
        CustomerServiceChat.assigned_at.isnot(None)
    ).order_by(
        CustomerServiceChat.ended_at.desc()
    ).limit(100).all()
    
    if not recent_chats:
        # 没有历史数据，使用保守的默认值（5分钟/人）
        # 注意：这是函数内部的默认值计算，不是独立的实现
        return max(1, queue_position * 5)
    
    # 计算平均处理时长（统一使用UTC）
    total_duration = 0
    count = 0
    
    for chat in recent_chats:
        if chat.assigned_at and chat.ended_at:
            # 统一转换为UTC后计算
            assigned_utc = to_utc(chat.assigned_at)
            ended_utc = to_utc(chat.ended_at)
            duration = (ended_utc - assigned_utc).total_seconds() / 60
            total_duration += duration
            count += 1
    
    if count == 0:
        # 没有有效数据，使用保守的默认值（5分钟/人）
        # 注意：这是函数内部的默认值计算，不是独立的实现
        return max(1, queue_position * 5)
    
    avg_duration = total_duration / count
    
    # 考虑当前客服负载
    # 使用类型转换确保正确匹配，兼容数据库中可能存在的不同类型
    from sqlalchemy import cast, Integer
    online_services = db.query(CustomerService).filter(
        cast(CustomerService.is_online, Integer) == 1
    ).count()
    
    if online_services == 0:
        # 没有在线客服，等待时间更长（函数内部计算，不是独立实现）
        return max(1, queue_position * 10)
    
    # 动态调整：根据在线客服数量和平均处理时长
    load_factor = max(1.0, 5.0 / online_services)  # 客服越少，等待时间越长
    estimated_time = queue_position * avg_duration * load_factor
    
    # 确保至少返回1分钟，避免返回0
    return max(1, int(estimated_time))


def get_user_queue_status(db: Session, user_id: str) -> dict:
    """获取用户在排队队列中的状态"""
    from app.models import CustomerServiceQueue
    from app.utils.time_utils import get_utc_time
    
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
    
    # 如果状态是waiting，计算排队位置和预计等待时间
    estimated_wait_time = None
    queue_position = None
    
    if queue_entry.status == "waiting":
        # 计算排队位置（前面有多少人在等待）
        queue_position = db.query(CustomerServiceQueue).filter(
            CustomerServiceQueue.status == "waiting",
            CustomerServiceQueue.queued_at <= queue_entry.queued_at
        ).count()
        
        # 计算预计等待时间
        estimated_wait_time = calculate_estimated_wait_time(queue_position, db)
    
    result = {
        "queue_id": queue_entry.id,
        "status": queue_entry.status,
        "queued_at": format_iso_utc(queue_entry.queued_at) if queue_entry.queued_at else None,
        "wait_seconds": wait_seconds,
        "wait_time_minutes": wait_time_minutes,
        "assigned_service_id": queue_entry.assigned_service_id,
        "assigned_at": format_iso_utc(queue_entry.assigned_at) if queue_entry.assigned_at else None
    }
    
    if queue_position is not None:
        result["queue_position"] = queue_position
    
    if estimated_wait_time is not None:
        result["estimated_wait_time"] = estimated_wait_time  # 分钟
    
    return result


def end_customer_service_chat(
    db: Session, 
    chat_id: str,
    reason: str = None,
    ended_by: str = None,
    ended_type: str = None,
    comment: str = None
) -> bool:
    """
    结束客服对话，并清理该聊天的所有图片和文件
    支持记录结束原因、结束者、结束类型和备注
    """
    from app.models import CustomerServiceChat
    import logging
    
    logger = logging.getLogger(__name__)

    chat = (
        db.query(CustomerServiceChat)
        .filter(CustomerServiceChat.chat_id == chat_id)
        .first()
    )
    if not chat:
        return False

    if chat.is_ended == 1:
        # 已经结束，避免重复结束
        return True

    chat.is_ended = 1
    chat.ended_at = get_utc_time()
    # 记录结束原因信息
    if reason:
        chat.ended_reason = reason
    if ended_by:
        chat.ended_by = ended_by
    if ended_type:
        chat.ended_type = ended_type
    if comment:
        chat.ended_comment = comment
    db.commit()
    
    # 记录审计日志
    logger.info(
        f"Chat {chat_id} ended: reason={reason}, type={ended_type}, by={ended_by}"
    )

    # 清理该聊天的所有图片和文件
    from app.image_cleanup import delete_chat_images_and_files
    try:
        deleted_count = delete_chat_images_and_files(chat_id)
        logger.info(f"客服聊天 {chat_id} 已清理 {deleted_count} 个文件")
    except Exception as e:
        logger.warning(f"清理客服聊天文件失败 {chat_id}: {e}")

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
    chat.rated_at = get_utc_time()
    db.commit()

    return True


def mark_customer_service_message_delivered(db: Session, message_id: int) -> bool:
    """标记消息为已送达"""
    from app.models import CustomerServiceMessage
    from app.utils.time_utils import get_utc_time
    
    message = db.query(CustomerServiceMessage).filter(
        CustomerServiceMessage.id == message_id
    ).first()
    
    if not message:
        return False
    
    if message.status != "sent":
        return False  # 只有已发送的消息才能标记为已送达
    
    message.status = "delivered"
    message.delivered_at = get_utc_time()
    db.commit()
    return True


def mark_customer_service_message_read(db: Session, message_id: int) -> bool:
    """标记消息为已读"""
    from app.models import CustomerServiceMessage
    from app.utils.time_utils import get_utc_time
    
    message = db.query(CustomerServiceMessage).filter(
        CustomerServiceMessage.id == message_id
    ).first()
    
    if not message:
        return False
    
    if message.status not in ["sent", "delivered"]:
        return False  # 只有已发送或已送达的消息才能标记为已读
    
    message.status = "read"
    message.read_at = get_utc_time()
    # 如果之前没有delivered_at，也设置它
    if not message.delivered_at:
        message.delivered_at = message.read_at
    db.commit()
    return True


def save_customer_service_message(
    db: Session, chat_id: str, sender_id: str, sender_type: str, content: str, image_id: str = None
) -> dict:
    """保存客服对话消息"""
    from datetime import datetime, timedelta, timezone

    from app.models import CustomerServiceChat, CustomerServiceMessage

    # 保存消息
    message_data = {
        'chat_id': chat_id, 
        'sender_id': sender_id, 
        'sender_type': sender_type, 
        'content': content
    }
    
    # 如果image_id字段存在，则添加它
    if hasattr(CustomerServiceMessage, 'image_id') and image_id:
        message_data['image_id'] = image_id
        print(f"🔍 [DEBUG] 客服消息设置image_id: {image_id}")
    
    # 设置消息状态和时间戳
    from app.utils.time_utils import get_utc_time
    message_data['status'] = 'sending'  # 初始状态为发送中
    message_data['sent_at'] = get_utc_time()  # 发送时间
    
    message = CustomerServiceMessage(**message_data)

    db.add(message)
    db.flush()  # 刷新以获取message.id
    
    # 立即标记为已发送（因为消息已保存到数据库）
    message.status = 'sent'
    db.commit()

    # 更新对话的最后消息时间和总消息数
    chat = (
        db.query(CustomerServiceChat)
        .filter(CustomerServiceChat.chat_id == chat_id)
        .first()
    )
    if chat:
        # 使用英国时间 (UTC+0)
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


# 岗位相关CRUD操作
def create_job_position(db: Session, position: schemas.JobPositionCreate, created_by: str):
    """创建岗位"""
    import json
    
    db_position = models.JobPosition(
        title=position.title,
        title_en=position.title_en,
        department=position.department,
        department_en=position.department_en,
        type=position.type,
        type_en=position.type_en,
        location=position.location,
        location_en=position.location_en,
        experience=position.experience,
        experience_en=position.experience_en,
        salary=position.salary,
        salary_en=position.salary_en,
        description=position.description,
        description_en=position.description_en,
        requirements=json.dumps(position.requirements, ensure_ascii=False),
        requirements_en=json.dumps(position.requirements_en, ensure_ascii=False) if position.requirements_en else None,
        tags=json.dumps(position.tags, ensure_ascii=False) if position.tags else None,
        tags_en=json.dumps(position.tags_en, ensure_ascii=False) if position.tags_en else None,
        is_active=1 if position.is_active else 0,
        created_by=created_by
    )
    db.add(db_position)
    db.commit()
    db.refresh(db_position)
    return db_position


def get_job_position(db: Session, position_id: int):
    """获取单个岗位"""
    return db.query(models.JobPosition).filter(models.JobPosition.id == position_id).first()


def get_job_positions(
    db: Session, 
    skip: int = 0, 
    limit: int = 100, 
    is_active: Optional[bool] = None,
    department: Optional[str] = None,
    type: Optional[str] = None
):
    """获取岗位列表"""
    query = db.query(models.JobPosition)
    
    if is_active is not None:
        query = query.filter(models.JobPosition.is_active == (1 if is_active else 0))
    
    if department:
        query = query.filter(models.JobPosition.department == department)
    
    if type:
        query = query.filter(models.JobPosition.type == type)
    
    total = query.count()
    positions = query.offset(skip).limit(limit).all()
    
    return positions, total


def update_job_position(db: Session, position_id: int, position: schemas.JobPositionUpdate):
    """更新岗位"""
    import json
    from app.utils.time_utils import get_utc_time
    from zoneinfo import ZoneInfo
    
    db_position = db.query(models.JobPosition).filter(models.JobPosition.id == position_id).first()
    if not db_position:
        return None
    
    update_data = position.dict(exclude_unset=True)
    
    # 处理JSON字段
    if 'requirements' in update_data and update_data['requirements'] is not None:
        update_data['requirements'] = json.dumps(update_data['requirements'], ensure_ascii=False)
    
    if 'requirements_en' in update_data and update_data['requirements_en'] is not None:
        update_data['requirements_en'] = json.dumps(update_data['requirements_en'], ensure_ascii=False)
    
    if 'tags' in update_data and update_data['tags'] is not None:
        update_data['tags'] = json.dumps(update_data['tags'], ensure_ascii=False)
    
    if 'tags_en' in update_data and update_data['tags_en'] is not None:
        update_data['tags_en'] = json.dumps(update_data['tags_en'], ensure_ascii=False)
    
    # 处理布尔值
    if 'is_active' in update_data:
        update_data['is_active'] = 1 if update_data['is_active'] else 0
    
    for field, value in update_data.items():
        setattr(db_position, field, value)
    
    db_position.updated_at = get_utc_time()
    db.commit()
    db.refresh(db_position)
    return db_position


def delete_job_position(db: Session, position_id: int):
    """删除岗位"""
    db_position = db.query(models.JobPosition).filter(models.JobPosition.id == position_id).first()
    if not db_position:
        return False
    
    db.delete(db_position)
    db.commit()
    return True


def toggle_job_position_status(db: Session, position_id: int):
    """切换岗位启用状态"""
    db_position = db.query(models.JobPosition).filter(models.JobPosition.id == position_id).first()
    if not db_position:
        return None
    
    db_position.is_active = 1 if db_position.is_active == 0 else 0
    db_position.updated_at = get_utc_time()
    db.commit()
    db.refresh(db_position)
    return db_position