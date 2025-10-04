import datetime
from datetime import timedelta, timezone

from sqlalchemy import (
    Column,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.ext.asyncio import AsyncAttrs
from sqlalchemy.orm import DeclarativeBase, relationship


class Base(AsyncAttrs, DeclarativeBase):
    """异步兼容的基础模型类"""

    pass


def get_uk_time():
    """获取当前英国时间 (自动处理夏令时/冬令时)"""
    import pytz

    uk_tz = pytz.timezone("Europe/London")
    return datetime.datetime.now(uk_tz)

def get_uk_time_naive():
    """获取当前英国时间 (timezone-naive，用于数据库存储)"""
    import pytz
    from datetime import timezone

    uk_tz = pytz.timezone("Europe/London")
    uk_time = datetime.datetime.now(uk_tz)
    # 转换为UTC然后移除时区信息，存储为naive datetime
    return uk_time.astimezone(timezone.utc).replace(tzinfo=None)


class User(Base):
    __tablename__ = "users"
    id = Column(String(8), primary_key=True, index=True)  # 8位数字格式
    name = Column(String(50), unique=True, nullable=False)  # 用户名唯一
    email = Column(String(120), unique=True, nullable=False)  # 邮箱唯一
    hashed_password = Column(String(128), nullable=False)
    phone = Column(String(20), nullable=True)
    created_at = Column(DateTime, default=get_uk_time)
    is_active = Column(Integer, default=1)  # 1=active, 0=inactive
    is_verified = Column(Integer, default=0)  # 1=verified, 0=not verified
    user_level = Column(String(20), default="normal")  # normal, vip, super
    task_count = Column(Integer, default=0)
    avg_rating = Column(Float, default=0.0)
    avatar = Column(String(200), default="")
    is_suspended = Column(Integer, default=0)  # 1=suspended, 0=not
    suspend_until = Column(DateTime, nullable=True)
    is_banned = Column(Integer, default=0)  # 1=banned, 0=not
    timezone = Column(String(50), default="UTC")  # 用户时区，默认为UTC
    # 关系
    tasks_posted = relationship(
        "Task", back_populates="poster", foreign_keys="Task.poster_id"
    )
    tasks_taken = relationship(
        "Task", back_populates="taker", foreign_keys="Task.taker_id"
    )
    reviews = relationship("Review", back_populates="user")


class Task(Base):
    __tablename__ = "tasks"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(100), nullable=False)
    description = Column(Text, nullable=False)
    deadline = Column(DateTime, nullable=False)
    reward = Column(Float, nullable=False)
    location = Column(String(100), nullable=False)
    task_type = Column(String(50), nullable=False)
    poster_id = Column(String(8), ForeignKey("users.id"))
    taker_id = Column(String(8), ForeignKey("users.id"), nullable=True)
    status = Column(String(20), default="open")
    task_level = Column(String(20), default="normal")  # normal, vip, super
    created_at = Column(DateTime, default=get_uk_time_naive)
    accepted_at = Column(DateTime, nullable=True)  # 任务接受时间
    completed_at = Column(DateTime, nullable=True)  # 任务完成时间
    is_paid = Column(Integer, default=0)  # 1=paid, 0=not paid
    escrow_amount = Column(Float, default=0.0)
    is_confirmed = Column(Integer, default=0)  # 1=confirmed, 0=not
    paid_to_user_id = Column(String(8), ForeignKey("users.id"), nullable=True)
    is_public = Column(Integer, default=1)  # 1=public, 0=private (仅自己可见)
    visibility = Column(String(20), default="public")  # public, private
    # 关系
    poster = relationship(
        "User", back_populates="tasks_posted", foreign_keys=[poster_id]
    )
    taker = relationship("User", back_populates="tasks_taken", foreign_keys=[taker_id])
    reviews = relationship("Review", back_populates="task")


class Review(Base):
    __tablename__ = "reviews"
    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id"))
    user_id = Column(String(8), ForeignKey("users.id"))
    rating = Column(Float, nullable=False)  # 改为Float以支持0.5星间隔
    comment = Column(Text, nullable=True)
    is_anonymous = Column(Integer, default=0)  # 0=实名, 1=匿名
    created_at = Column(DateTime, default=get_uk_time)
    # 关系
    task = relationship("Task", back_populates="reviews")
    user = relationship("User", back_populates="reviews")


class TaskHistory(Base):
    __tablename__ = "task_history"
    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id"))
    user_id = Column(String(8), ForeignKey("users.id"))
    action = Column(String(20), nullable=False)  # accepted, completed, cancelled
    timestamp = Column(DateTime, default=get_uk_time)
    remark = Column(Text, nullable=True)


class Message(Base):
    __tablename__ = "messages"
    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(
        String(8), ForeignKey("users.id"), nullable=True
    )  # 允许为NULL，用于系统消息
    receiver_id = Column(String(8), ForeignKey("users.id"))
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=get_uk_time_naive)
    is_read = Column(Integer, default=0)  # 0=unread, 1=read


class Notification(Base):
    __tablename__ = "notifications"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(8), ForeignKey("users.id"))
    type = Column(
        String(50), nullable=False
    )  # 'message', 'task_accepted', 'task_completed', 'customer_service', 'announcement'
    title = Column(String(200), nullable=False)
    content = Column(Text, nullable=False)
    related_id = Column(Integer, nullable=True)  # 相关ID（用户ID、任务ID、公告ID等）
    is_read = Column(Integer, default=0)  # 0=unread, 1=read
    created_at = Column(DateTime, default=get_uk_time_naive)
    __table_args__ = (
        UniqueConstraint("user_id", "type", "related_id", name="uix_user_type_related"),
    )


class TaskCancelRequest(Base):
    __tablename__ = "task_cancel_requests"
    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id"))
    requester_id = Column(String(8), ForeignKey("users.id"))  # 请求取消的用户ID
    reason = Column(Text, nullable=True)  # 取消原因
    status = Column(String(20), default="pending")  # pending, approved, rejected
    admin_id = Column(
        String(8), ForeignKey("users.id"), nullable=True
    )  # 审核的管理员ID
    admin_comment = Column(Text, nullable=True)  # 管理员审核意见
    created_at = Column(DateTime, default=get_uk_time)
    reviewed_at = Column(DateTime, nullable=True)  # 审核时间


class CustomerService(Base):
    __tablename__ = "customer_service"
    id = Column(String(6), primary_key=True)  # CS + 4位数字格式
    name = Column(String(50), nullable=False)
    email = Column(String(120), unique=True, nullable=False)  # 客服邮箱
    hashed_password = Column(String(128), nullable=False)  # 客服登录密码
    is_online = Column(Integer, default=0)  # 1=在线, 0=离线
    avg_rating = Column(Float, default=0.0)  # 平均评分
    total_ratings = Column(Integer, default=0)  # 总评分数量
    created_at = Column(DateTime, default=get_uk_time)  # 创建时间


class AdminRequest(Base):
    __tablename__ = "admin_requests"
    id = Column(Integer, primary_key=True, index=True)
    requester_id = Column(String(8), ForeignKey("customer_service.id"))  # 请求的客服ID
    type = Column(
        String(50), nullable=False
    )  # 请求类型：task_status, user_ban, feedback, other
    title = Column(String(200), nullable=False)  # 请求标题
    description = Column(Text, nullable=False)  # 请求描述
    priority = Column(String(20), default="medium")  # 优先级：low, medium, high
    status = Column(
        String(20), default="pending"
    )  # 状态：pending, processing, completed, rejected
    admin_response = Column(Text, nullable=True)  # 管理员回复
    admin_id = Column(
        String(8), ForeignKey("users.id"), nullable=True
    )  # 处理的管理员ID
    created_at = Column(DateTime, default=get_uk_time)
    updated_at = Column(DateTime, nullable=True)  # 更新时间


class AdminChatMessage(Base):
    __tablename__ = "admin_chat_messages"
    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(String(8), nullable=True)  # 发送者ID（客服或管理员）
    sender_type = Column(
        String(20), nullable=False
    )  # 发送者类型：customer_service, admin
    content = Column(Text, nullable=False)  # 消息内容
    created_at = Column(DateTime, default=get_uk_time)


class AdminUser(Base):
    __tablename__ = "admin_users"
    id = Column(String(5), primary_key=True)  # A + 4位数字格式
    name = Column(String(50), nullable=False)  # 管理员姓名
    username = Column(String(50), unique=True, nullable=False)  # 登录用户名
    email = Column(String(120), unique=True, nullable=False)  # 邮箱
    hashed_password = Column(String(128), nullable=False)  # 登录密码
    is_active = Column(Integer, default=1)  # 1=激活, 0=禁用
    is_super_admin = Column(Integer, default=0)  # 1=超级管理员, 0=普通管理员
    created_at = Column(DateTime, default=get_uk_time)  # 创建时间
    last_login = Column(DateTime, nullable=True)  # 最后登录时间


class StaffNotification(Base):
    __tablename__ = "staff_notifications"
    id = Column(Integer, primary_key=True, index=True)
    recipient_id = Column(String(10), nullable=False)  # 接收者ID（客服或管理员）
    recipient_type = Column(
        String(20), nullable=False
    )  # 接收者类型：customer_service, admin
    sender_id = Column(String(10), nullable=True)  # 发送者ID（管理员）
    title = Column(String(100), nullable=False)  # 提醒标题
    content = Column(Text, nullable=False)  # 提醒内容
    notification_type = Column(
        String(20), default="info"
    )  # 提醒类型：info, warning, error, success
    is_read = Column(Integer, default=0)  # 是否已读：1=已读, 0=未读
    created_at = Column(DateTime, default=get_uk_time)  # 创建时间
    read_at = Column(DateTime, nullable=True)  # 阅读时间


class SystemSettings(Base):
    __tablename__ = "system_settings"
    id = Column(Integer, primary_key=True, index=True)
    setting_key = Column(String(50), unique=True, nullable=False)  # 设置键名
    setting_value = Column(Text, nullable=False)  # 设置值（JSON格式存储）
    setting_type = Column(
        String(20), default="string"
    )  # 设置类型：string, boolean, number, json
    description = Column(String(200), nullable=True)  # 设置描述
    created_at = Column(DateTime, default=get_uk_time)
    updated_at = Column(DateTime, default=get_uk_time, onupdate=get_uk_time)


class CustomerServiceChat(Base):
    __tablename__ = "customer_service_chats"
    id = Column(Integer, primary_key=True, index=True)
    chat_id = Column(
        String(50), unique=True, nullable=False
    )  # 对话ID，格式：CS_CHAT_YYYYMMDD_HHMMSS_USERID_SERVICEID
    user_id = Column(String(20), nullable=False)  # 用户ID
    service_id = Column(String(20), nullable=False)  # 客服ID
    is_ended = Column(Integer, default=0)  # 是否已结束对话 (0: 进行中, 1: 已结束)
    created_at = Column(DateTime, default=get_uk_time)
    ended_at = Column(DateTime, nullable=True)  # 结束时间
    last_message_at = Column(DateTime, default=get_uk_time)  # 最后消息时间
    total_messages = Column(Integer, default=0)  # 总消息数
    user_rating = Column(Integer, nullable=True)  # 用户评分 (1-5)
    user_comment = Column(Text, nullable=True)  # 用户评价内容
    rated_at = Column(DateTime, nullable=True)  # 评分时间


class CustomerServiceMessage(Base):
    __tablename__ = "customer_service_messages"
    id = Column(Integer, primary_key=True, index=True)
    chat_id = Column(String(50), nullable=False)  # 对话ID
    sender_id = Column(String(20), nullable=False)  # 发送者ID
    sender_type = Column(
        String(20), nullable=False
    )  # 发送者类型: 'user', 'customer_service', 'system'
    content = Column(Text, nullable=False)  # 消息内容
    is_read = Column(Integer, default=0)  # 是否已读 (0: 未读, 1: 已读)
    created_at = Column(DateTime, default=get_uk_time)


# 数据库索引优化
# 用户表索引
Index("ix_users_email", User.email)
Index("ix_users_name", User.name)
Index("ix_users_phone", User.phone)
Index("ix_users_user_level", User.user_level)
Index("ix_users_is_verified", User.is_verified)
Index("ix_users_created_at", User.created_at)

# 任务表索引
Index("ix_tasks_poster_id", Task.poster_id)
Index("ix_tasks_taker_id", Task.taker_id)
Index("ix_tasks_status", Task.status)
Index("ix_tasks_task_level", Task.task_level)
Index("ix_tasks_task_type", Task.task_type)
Index("ix_tasks_location", Task.location)
Index("ix_tasks_created_at", Task.created_at)
Index("ix_tasks_deadline", Task.deadline)
Index("ix_tasks_reward", Task.reward)

# 消息表索引
Index("ix_messages_sender_id", Message.sender_id)
Index("ix_messages_receiver_id", Message.receiver_id)
Index("ix_messages_created_at", Message.created_at)

# 评论表索引
Index("ix_reviews_user_id", Review.user_id)
Index("ix_reviews_task_id", Review.task_id)
Index("ix_reviews_created_at", Review.created_at)

# 通知表索引
Index("ix_notifications_user_id", Notification.user_id)
Index("ix_notifications_type", Notification.type)
Index("ix_notifications_is_read", Notification.is_read)
Index("ix_notifications_created_at", Notification.created_at)

# 客服对话表索引
Index("ix_customer_service_chats_user_id", CustomerServiceChat.user_id)
Index("ix_customer_service_chats_service_id", CustomerServiceChat.service_id)
Index("ix_customer_service_chats_is_ended", CustomerServiceChat.is_ended)
Index("ix_customer_service_chats_created_at", CustomerServiceChat.created_at)
Index("ix_customer_service_chats_last_message_at", CustomerServiceChat.last_message_at)

# 客服消息表索引
Index("ix_customer_service_messages_chat_id", CustomerServiceMessage.chat_id)
Index("ix_customer_service_messages_sender_id", CustomerServiceMessage.sender_id)
Index("ix_customer_service_messages_created_at", CustomerServiceMessage.created_at)

# 复合索引（用于复杂查询优化）
Index("ix_tasks_poster_status", Task.poster_id, Task.status)
Index("ix_tasks_taker_status", Task.taker_id, Task.status)
Index("ix_tasks_type_status", Task.task_type, Task.status)
Index("ix_tasks_level_status", Task.task_level, Task.status)
Index("ix_messages_sender_receiver", Message.sender_id, Message.receiver_id)
Index("ix_notifications_user_read", Notification.user_id, Notification.is_read)


class PendingUser(Base):
    """待验证用户模型"""
    __tablename__ = "pending_users"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), nullable=False)
    email = Column(String(120), unique=True, nullable=False)
    hashed_password = Column(String(128), nullable=False)
    phone = Column(String(20), nullable=True)
    verification_token = Column(String(64), unique=True, nullable=False)
    created_at = Column(DateTime, default=get_uk_time)
    expires_at = Column(DateTime, nullable=False)
    
    # 索引
    __table_args__ = (
        Index("ix_pending_users_email", email),
        Index("ix_pending_users_token", verification_token),
        Index("ix_pending_users_expires", expires_at),
    )


class TaskApplication(Base):
    """任务申请表"""
    __tablename__ = "task_applications"
    
    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id"), nullable=False)
    applicant_id = Column(String(8), ForeignKey("users.id"), nullable=False)
    status = Column(String(20), default="pending")  # pending, approved, rejected
    created_at = Column(DateTime, default=get_uk_time_naive)
    message = Column(Text, nullable=True)  # 申请时的留言
    
    # 确保同一用户不能重复申请同一任务
    __table_args__ = (
        UniqueConstraint('task_id', 'applicant_id', name='unique_task_applicant'),
        Index("ix_task_applications_task_id", task_id),
        Index("ix_task_applications_applicant_id", applicant_id),
        Index("ix_task_applications_status", status),
    )
