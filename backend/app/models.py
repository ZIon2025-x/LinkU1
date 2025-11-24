from datetime import timedelta, timezone as tz, datetime
from app.utils.time_utils import get_utc_time

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
    DECIMAL,
    CheckConstraint,
    BigInteger,
    Boolean,
    Date,
    Time,
    JSON,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, INET
from sqlalchemy.ext.asyncio import AsyncAttrs
from sqlalchemy.orm import DeclarativeBase, relationship


class Base(AsyncAttrs, DeclarativeBase):
    """异步兼容的基础模型类"""

    pass


# ⚠️ 保留用于测试端点：get_uk_time_online() 仅用于 time_check_endpoint.py 的测试功能
def get_uk_time_online():
    """通过网络获取真实的英国时间，使用多个API作为备用 - 已弃用，仅用于测试"""
    import requests
    from zoneinfo import ZoneInfo
    from datetime import datetime, timezone
    from app.utils.time_utils import to_user_timezone, LONDON
    
    # 导入Railway配置
    try:
        from railway_config import railway_config
        config = railway_config
    except ImportError:
        # 如果Railway配置不可用，使用默认配置
        class DefaultConfig:
            enable_online_time = True
            timeout_seconds = 3
            max_retries = 3
            fallback_to_local = True
            
            def get_apis(self):
                return [
                    {
                        'name': 'WorldTimeAPI',
                        'url': 'http://worldtimeapi.org/api/timezone/Europe/London',
                        'parser': self._parse_worldtimeapi
                    },
                    {
                        'name': 'TimeAPI',
                        'url': 'http://timeapi.io/api/Time/current/zone?timeZone=Europe/London',
                        'parser': self._parse_timeapi
                    },
                    {
                        'name': 'WorldClockAPI',
                        'url': 'http://worldclockapi.com/api/json/utc/now',
                        'parser': self._parse_worldclockapi
                    }
                ]
            
            def _parse_worldtimeapi(self, data):
                # 直接使用API返回的英国时间，不进行时区转换
                if 'datetime' in data:
                    # 直接解析英国时间
                    return datetime.fromisoformat(data['datetime'].replace('Z', ''))
                else:
                    # 如果没有datetime字段，使用utc_datetime转换
                    utc_time = datetime.fromisoformat(data['utc_datetime'].replace('Z', '+00:00'))
                    uk_tz = ZoneInfo("Europe/London")
                    return utc_time.astimezone(uk_tz)
            
            def _parse_timeapi(self, data):
                # 直接使用API返回的英国时间
                return datetime.fromisoformat(data['dateTime'].replace('Z', ''))
            
            def _parse_worldclockapi(self, data):
                # 使用UTC时间转换为英国时间
                utc_time = datetime.fromisoformat(data['currentDateTime'].replace('Z', '+00:00'))
                uk_tz = ZoneInfo("Europe/London")
                return utc_time.astimezone(uk_tz)
        
        config = DefaultConfig()
    
    # 检查是否启用在线时间
    if not config.enable_online_time:
        print("在线时间获取已禁用，使用本地时间")
        from app.utils.time_utils import get_utc_time, to_user_timezone, LONDON
        utc_time = get_utc_time()
        return to_user_timezone(utc_time, LONDON)
    
    # 获取API列表
    apis = config.get_apis()
    
    for attempt in range(config.max_retries):
        for api in apis:
            try:
                print(f"尝试使用 {api['name']} 获取英国时间... (尝试 {attempt + 1}/{config.max_retries})")
                response = requests.get(api['url'], timeout=config.timeout_seconds)
                if response.status_code == 200:
                    data = response.json()
                    uk_time = api['parser'](data)
                    print(f"成功从 {api['name']} 获取英国时间: {uk_time}")
                    return uk_time
                else:
                    print(f"{api['name']} API失败，状态码: {response.status_code}")
            except Exception as e:
                print(f"{api['name']} 获取时间失败: {e}")
                continue
    
    # 所有API都失败时回退到本地时间
    if config.fallback_to_local:
        print("所有在线时间API都失败，使用本地时间")
        from app.utils.time_utils import get_utc_time, to_user_timezone, LONDON
        utc_time = get_utc_time()
        return to_user_timezone(utc_time, LONDON)
    else:
        print("所有在线时间API都失败，且禁用本地时间回退")
        raise Exception("无法获取英国时间")

class User(Base):
    __tablename__ = "users"
    id = Column(String(8), primary_key=True, index=True)  # 8位数字格式
    name = Column(String(50), unique=True, nullable=False)  # 用户名唯一
    email = Column(String(255), unique=True, nullable=True)  # 邮箱唯一，可为空（手机号登录时为空），RFC 5321标准最大254字符
    hashed_password = Column(String(128), nullable=False)
    phone = Column(String(20), unique=True, nullable=True)  # 手机号唯一，可为空（邮箱登录时为空）
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    is_active = Column(Integer, default=1)  # 1=active, 0=inactive
    is_verified = Column(Integer, default=0)  # 1=verified, 0=not verified
    user_level = Column(String(20), default="normal")  # normal, vip, super
    task_count = Column(Integer, default=0)
    completed_task_count = Column(Integer, default=0)  # 已完成任务数量
    avg_rating = Column(Float, default=0.0)
    avatar = Column(String(200), default="")
    is_suspended = Column(Integer, default=0)  # 1=suspended, 0=not
    suspend_until = Column(DateTime(timezone=True), nullable=True)
    is_banned = Column(Integer, default=0)  # 1=banned, 0=not
    timezone = Column(String(50), default="UTC")  # 用户时区，默认为UTC
    residence_city = Column(String(50), nullable=True)  # 常住城市
    language_preference = Column(String(10), default="en")  # 语言偏好：zh（中文）或 en（英文）
    agreed_to_terms = Column(Integer, default=0)  # 1=agreed, 0=not agreed
    terms_agreed_at = Column(DateTime(timezone=True), nullable=True)  # 同意时间
    name_updated_at = Column(DateTime(timezone=True), nullable=True)  # 上次修改名字的时间
    inviter_id = Column(String(8), ForeignKey("users.id"), nullable=True)  # 邀请人ID（当输入是用户ID格式时）
    invitation_code_id = Column(BigInteger, ForeignKey("invitation_codes.id"), nullable=True)  # 邀请码ID
    invitation_code_text = Column(String(50), nullable=True)  # 邀请码文本
    flea_market_notice_agreed_at = Column(DateTime(timezone=True), nullable=True)  # 跳蚤市场须知同意时间
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
    deadline = Column(DateTime(timezone=True), nullable=True)  # 允许为 NULL，支持灵活模式任务（无截止日期）
    is_flexible = Column(Integer, default=0)  # 是否灵活时间（1=灵活，无截止日期；0=有截止日期）
    reward = Column(Float, nullable=False)  # 价格字段（与base_reward同步）
    base_reward = Column(DECIMAL(12, 2), nullable=False)  # 原始标价（发布时的价格）
    agreed_reward = Column(DECIMAL(12, 2), nullable=True)  # 最终成交价（如果有议价）
    currency = Column(String(3), default="GBP")  # 货币类型
    location = Column(String(100), nullable=False)
    task_type = Column(String(50), nullable=False)
    poster_id = Column(String(8), ForeignKey("users.id"))
    taker_id = Column(String(8), ForeignKey("users.id"), nullable=True)
    status = Column(String(20), default="open")
    task_level = Column(String(20), default="normal")  # normal, vip, super, expert（达人任务）
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    accepted_at = Column(DateTime(timezone=True), nullable=True)  # 任务接受时间
    completed_at = Column(DateTime(timezone=True), nullable=True)  # 任务完成时间
    is_paid = Column(Integer, default=0)  # 1=paid, 0=not paid
    escrow_amount = Column(Float, default=0.0)
    is_confirmed = Column(Integer, default=0)  # 1=confirmed, 0=not
    paid_to_user_id = Column(String(8), ForeignKey("users.id"), nullable=True)
    is_public = Column(Integer, default=1)  # 1=public, 0=private (仅自己可见)
    visibility = Column(String(20), default="public")  # public, private
    images = Column(Text, nullable=True)  # JSON数组存储图片URL列表
    points_reward = Column(BigInteger, nullable=True)  # 任务完成奖励积分（可选，如果设置则覆盖系统默认值）
    
    # 多人任务相关字段
    is_multi_participant = Column(Boolean, default=False, nullable=False)
    is_official_task = Column(Boolean, default=False, nullable=False)
    max_participants = Column(Integer, default=1, nullable=False)
    min_participants = Column(Integer, default=1, nullable=False)
    current_participants = Column(Integer, default=0, nullable=False)
    completion_rule = Column(String(20), default="all", nullable=False)  # all, min
    reward_distribution = Column(String(20), default="equal", nullable=False)  # equal, custom
    reward_type = Column(String(20), default="cash", nullable=False)  # cash, points, both
    auto_accept = Column(Boolean, default=False, nullable=False)
    allow_negotiation = Column(Boolean, default=True, nullable=False)
    created_by_admin = Column(Boolean, default=False, nullable=False)
    admin_creator_id = Column(String(36), ForeignKey("admin_users.id"), nullable=True)
    created_by_expert = Column(Boolean, default=False, nullable=False)
    expert_creator_id = Column(String(8), ForeignKey("users.id"), nullable=True)
    expert_service_id = Column(Integer, ForeignKey("task_expert_services.id", ondelete="RESTRICT"), nullable=True)
    is_fixed_time_slot = Column(Boolean, default=False, nullable=False)
    time_slot_duration_minutes = Column(Integer, nullable=True)
    time_slot_start_time = Column(Time, nullable=True)
    time_slot_end_time = Column(Time, nullable=True)
    participants_per_slot = Column(Integer, nullable=True)
    original_price_per_participant = Column(DECIMAL(12, 2), nullable=True)
    discount_percentage = Column(DECIMAL(5, 2), nullable=True)
    discounted_price_per_participant = Column(DECIMAL(12, 2), nullable=True)
    # 关联的活动ID（如果此任务是从活动申请创建的）
    parent_activity_id = Column(Integer, ForeignKey("activities.id", ondelete="RESTRICT"), nullable=True)
    # 记录实际申请人（如果任务是从活动申请创建的）
    originating_user_id = Column(String(8), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 关系
    poster = relationship(
        "User", back_populates="tasks_posted", foreign_keys=[poster_id]
    )
    taker = relationship("User", back_populates="tasks_taken", foreign_keys=[taker_id])
    reviews = relationship("Review", back_populates="task")
    participants = relationship("TaskParticipant", back_populates="task", cascade="all, delete-orphan")
    participant_rewards = relationship("TaskParticipantReward", back_populates="task", cascade="all, delete-orphan")
    audit_logs = relationship("TaskAuditLog", back_populates="task", cascade="all, delete-orphan")
    parent_activity = relationship("Activity", back_populates="created_tasks", foreign_keys=[parent_activity_id])


class Review(Base):
    __tablename__ = "reviews"
    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id"))
    user_id = Column(String(8), ForeignKey("users.id"))
    rating = Column(Float, nullable=False)  # 改为Float以支持0.5星间隔
    comment = Column(Text, nullable=True)
    is_anonymous = Column(Integer, default=0)  # 0=实名, 1=匿名
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    # 关系
    task = relationship("Task", back_populates="reviews")
    user = relationship("User", back_populates="reviews")


class TaskHistory(Base):
    __tablename__ = "task_history"
    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id"))
    user_id = Column(String(8), ForeignKey("users.id"), nullable=True)  # 可空，用于管理员操作
    action = Column(String(20), nullable=False)  # accepted, completed, cancelled
    timestamp = Column(DateTime(timezone=True), default=get_utc_time)
    remark = Column(Text, nullable=True)


class Message(Base):
    __tablename__ = "messages"
    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(
        String(8), ForeignKey("users.id"), nullable=True
    )  # 允许为NULL，用于系统消息
    receiver_id = Column(String(8), ForeignKey("users.id"), nullable=True)  # 允许为NULL，用于任务消息
    content = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)  # 统一存储UTC时间
    is_read = Column(Integer, default=0)  # 0=unread, 1=read (保留向后兼容，新系统使用 message_reads 表)
    image_id = Column(String(100), nullable=True)  # 私密图片ID
    # 任务聊天相关字段
    task_id = Column(Integer, ForeignKey("tasks.id"), nullable=True)  # 关联的任务ID
    message_type = Column(String(20), default="normal")  # normal, system
    conversation_type = Column(String(20), default="task")  # task, customer_service, global
    meta = Column(Text, nullable=True)  # JSON格式存储元数据
    # 对话键（用于优化查询）：值为 least(sender_id, receiver_id) || '-' || greatest(sender_id, receiver_id)
    # 注意：conversation_key 由数据库触发器自动维护，应用层不需要手动设置
    conversation_key = Column(String(255), index=True, nullable=True)
    
    __table_args__ = (
        # 确保任务消息必须关联 task_id
        CheckConstraint(
            "(conversation_type <> 'task' OR task_id IS NOT NULL)",
            name="ck_messages_task_bind"
        ),
        # 枚举约束：限定 message_type 的合法值
        CheckConstraint(
            "message_type IN ('normal', 'system')",
            name="ck_messages_type"
        ),
        # 枚举约束：限定 conversation_type 的合法值
        CheckConstraint(
            "conversation_type IN ('task', 'customer_service', 'global')",
            name="ck_messages_conversation_type"
        ),
        # 索引
        # 注意：降序索引在某些数据库可能不支持，使用普通索引，查询时 ORDER BY created_at DESC, id DESC 也能走覆盖索引
        Index("ix_messages_task_id", task_id),
        Index("ix_messages_task_type", task_id, message_type),
        Index("ix_messages_task_created", task_id, created_at, id),  # 用于游标分页（查询时使用 ORDER BY created_at DESC, id DESC）
        Index("ix_messages_conversation_type", conversation_type, task_id),
        Index("ix_messages_task_id_id", task_id, id),  # 用于未读数聚合（配合 message_read_cursors）
    )


class Notification(Base):
    __tablename__ = "notifications"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(8), ForeignKey("users.id"), nullable=False)
    type = Column(
        String(32), nullable=False
    )  # 'negotiation_offer', 'task_application', 'task_approved', 'message', 'task_accepted', 'task_completed', 'customer_service', 'announcement', 'application_message', 'application_message_reply'
    related_id = Column(Integer, nullable=True)  # application_id 或 task_id（根据 type 而定）
    content = Column(Text, nullable=False)  # JSON 格式存储通知数据
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    read_at = Column(DateTime(timezone=True), nullable=True)  # 已读时间（可为空）
    # 保留向后兼容字段
    title = Column(String(200), nullable=True)  # 可选，用于旧通知
    is_read = Column(Integer, default=0)  # 0=unread, 1=read (保留向后兼容，新系统使用 read_at)
    __table_args__ = (
        UniqueConstraint("user_id", "type", "related_id", name="uix_user_type_related"),
        Index("ix_notifications_user", user_id, created_at),  # 查询时使用 ORDER BY created_at DESC
        Index("ix_notifications_type", type, related_id),
    )


class TaskCancelRequest(Base):
    __tablename__ = "task_cancel_requests"
    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id"))
    requester_id = Column(String(8), ForeignKey("users.id"))  # 请求取消的用户ID
    reason = Column(Text, nullable=True)  # 取消原因
    status = Column(String(20), default="pending")  # pending, approved, rejected
    admin_id = Column(
        String(5), ForeignKey("admin_users.id"), nullable=True
    )  # 审核的管理员ID（格式：A0001，指向 admin_users 表）
    service_id = Column(
        String(6), ForeignKey("customer_service.id"), nullable=True
    )  # 审核的客服ID（格式：CS8888，指向 customer_service 表）
    admin_comment = Column(Text, nullable=True)  # 审核意见
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)  # 审核时间


class CustomerService(Base):
    __tablename__ = "customer_service"
    id = Column(String(6), primary_key=True)  # CS + 4位数字格式
    name = Column(String(50), nullable=False)
    email = Column(String(255), unique=True, nullable=False)  # 客服邮箱，RFC 5321标准最大254字符
    hashed_password = Column(String(128), nullable=False)  # 客服登录密码
    is_online = Column(Integer, default=0)  # 1=在线, 0=离线
    avg_rating = Column(Float, default=0.0)  # 平均评分
    total_ratings = Column(Integer, default=0)  # 总评分数量
    created_at = Column(DateTime(timezone=True), default=get_utc_time)  # 创建时间


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
        String(5), ForeignKey("admin_users.id"), nullable=True
    )  # 处理的管理员ID（格式：A0001，指向 admin_users 表）
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    updated_at = Column(DateTime(timezone=True), nullable=True)  # 更新时间


class AdminChatMessage(Base):
    __tablename__ = "admin_chat_messages"
    id = Column(Integer, primary_key=True, index=True)
    sender_id = Column(String(8), nullable=True)  # 发送者ID（客服或管理员）
    sender_type = Column(
        String(20), nullable=False
    )  # 发送者类型：customer_service, admin
    content = Column(Text, nullable=False)  # 消息内容
    created_at = Column(DateTime(timezone=True), default=get_utc_time)


class AdminUser(Base):
    __tablename__ = "admin_users"
    id = Column(String(5), primary_key=True)  # A + 4位数字格式
    name = Column(String(50), nullable=False)  # 管理员姓名
    username = Column(String(50), unique=True, nullable=False)  # 登录用户名
    email = Column(String(255), unique=True, nullable=False)  # 邮箱，RFC 5321标准最大254字符
    hashed_password = Column(String(128), nullable=False)  # 登录密码
    is_active = Column(Integer, default=1)  # 1=激活, 0=禁用
    is_super_admin = Column(Integer, default=0)  # 1=超级管理员, 0=普通管理员
    created_at = Column(DateTime(timezone=True), default=get_utc_time)  # 创建时间
    last_login = Column(DateTime(timezone=True), nullable=True)  # 最后登录时间


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
    created_at = Column(DateTime(timezone=True), default=get_utc_time)  # 创建时间（使用UTC时间）
    read_at = Column(DateTime(timezone=True), nullable=True)  # 阅读时间


class SystemSettings(Base):
    __tablename__ = "system_settings"
    id = Column(Integer, primary_key=True, index=True)
    setting_key = Column(String(50), unique=True, nullable=False)  # 设置键名
    setting_value = Column(Text, nullable=False)  # 设置值（JSON格式存储）
    setting_type = Column(
        String(20), default="string"
    )  # 设置类型：string, boolean, number, json
    description = Column(String(200), nullable=True)  # 设置描述
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)


class CustomerServiceChat(Base):
    __tablename__ = "customer_service_chats"
    id = Column(Integer, primary_key=True, index=True)
    chat_id = Column(
        String(50), unique=True, nullable=False
    )  # 对话ID，格式：CS_CHAT_YYYYMMDD_HHMMSS_USERID_SERVICEID
    user_id = Column(String(20), nullable=False)  # 用户ID
    service_id = Column(String(20), nullable=False)  # 客服ID
    is_ended = Column(Integer, default=0)  # 是否已结束对话 (0: 进行中, 1: 已结束)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    ended_at = Column(DateTime(timezone=True), nullable=True)  # 结束时间
    last_message_at = Column(DateTime(timezone=True), default=get_utc_time)  # 最后消息时间
    total_messages = Column(Integer, default=0)  # 总消息数
    user_rating = Column(Integer, nullable=True)  # 用户评分 (1-5)
    user_comment = Column(Text, nullable=True)  # 用户评价内容
    rated_at = Column(DateTime(timezone=True), nullable=True)  # 评分时间
    # 新增字段：结束对话原因追踪
    ended_reason = Column(String(32), nullable=True)  # 结束原因: timeout, user_ended, service_ended, auto_cleanup
    ended_by = Column(String(32), nullable=True)  # 结束者: user_id, service_id, system
    ended_type = Column(String(32), nullable=True)  # 结束类型: user_inactive, service_inactive, manual, auto
    ended_comment = Column(Text, nullable=True)  # 结束备注（可选）


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
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    image_id = Column(String(100), nullable=True)  # 私密图片ID
    # 新增字段：消息状态追踪
    status = Column(String(20), default="sending")  # 消息状态: sending, sent, delivered, read
    sent_at = Column(DateTime(timezone=True), nullable=True)  # 发送时间
    delivered_at = Column(DateTime(timezone=True), nullable=True)  # 送达时间
    read_at = Column(DateTime(timezone=True), nullable=True)  # 已读时间


class CustomerServiceQueue(Base):
    """客服排队系统模型"""
    __tablename__ = "customer_service_queue"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(20), nullable=False)  # 用户ID
    status = Column(String(20), default="waiting")  # 状态: waiting, assigned, cancelled
    queued_at = Column(DateTime(timezone=True), default=get_utc_time)  # 排队时间
    assigned_service_id = Column(String(20), nullable=True)  # 分配的客服ID
    assigned_at = Column(DateTime(timezone=True), nullable=True)  # 分配时间
    cancelled_at = Column(DateTime(timezone=True), nullable=True)  # 取消时间
    version = Column(Integer, default=0)  # 版本号，用于乐观锁


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
Index("ix_tasks_base_reward", Task.base_reward)

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
Index("ix_customer_service_messages_status", CustomerServiceMessage.status)
Index("ix_customer_service_messages_chat_status", CustomerServiceMessage.chat_id, CustomerServiceMessage.status)

# 客服排队表索引
Index("ix_customer_service_queue_user_id", CustomerServiceQueue.user_id)
Index("ix_customer_service_queue_status", CustomerServiceQueue.status)
Index("ix_customer_service_queue_queued_at", CustomerServiceQueue.queued_at)
Index("ix_customer_service_queue_status_queued_at", CustomerServiceQueue.status, CustomerServiceQueue.queued_at)

# 复合索引（用于复杂查询优化）
Index("ix_tasks_poster_status", Task.poster_id, Task.status)
Index("ix_tasks_taker_status", Task.taker_id, Task.status)
Index("ix_tasks_type_status", Task.task_type, Task.status)
Index("ix_tasks_level_status", Task.task_level, Task.status)
Index("ix_messages_sender_receiver", Message.sender_id, Message.receiver_id)
Index("ix_notifications_user_read", Notification.user_id, Notification.is_read)

# 新增高性能复合索引
Index("ix_tasks_status_deadline", Task.status, Task.deadline)  # 过滤开放任务和截止日期
Index("ix_tasks_type_location_status", Task.task_type, Task.location, Task.status)  # 任务类型+城市+状态组合查询
Index("ix_tasks_status_created_at", Task.status, Task.created_at)  # 按状态和创建时间排序
Index("ix_tasks_poster_created_at", Task.poster_id, Task.created_at)  # 用户的发布任务排序


class PendingUser(Base):
    """待验证用户模型"""
    __tablename__ = "pending_users"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), nullable=False)
    email = Column(String(255), unique=True, nullable=False)  # 待验证用户邮箱，RFC 5321标准最大254字符
    hashed_password = Column(String(128), nullable=False)
    phone = Column(String(20), nullable=True)
    verification_token = Column(String(255), unique=True, nullable=False)  # 增加到255以支持JWT token
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    agreed_to_terms = Column(Integer, default=1)  # 1=agreed, 0=not agreed
    terms_agreed_at = Column(DateTime(timezone=True), nullable=True)  # 同意时间
    inviter_id = Column(String(8), ForeignKey("users.id"), nullable=True)  # 邀请人ID（当输入是用户ID格式时）
    invitation_code_id = Column(BigInteger, ForeignKey("invitation_codes.id"), nullable=True)  # 邀请码ID
    invitation_code_text = Column(String(50), nullable=True)  # 邀请码文本
    
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
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    message = Column(Text, nullable=True)  # 申请时的留言
    negotiated_price = Column(DECIMAL(12, 2), nullable=True)  # 议价价格
    currency = Column(String(3), default="GBP")  # 货币类型
    
    # 关系
    task = relationship("Task", backref="applications")  # 任务关系
    applicant = relationship("User", foreign_keys=[applicant_id])  # 申请者关系
    
    # 确保同一用户不能重复申请同一任务
    __table_args__ = (
        UniqueConstraint('task_id', 'applicant_id', name='unique_task_applicant'),
        Index("ix_task_applications_task_id", task_id),
        Index("ix_task_applications_applicant_id", applicant_id),
        Index("ix_task_applications_status", status),
    )


class JobPosition(Base):
    """岗位模型"""
    __tablename__ = "job_positions"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(100), nullable=False)  # 岗位名称
    title_en = Column(String(100), nullable=True)  # 岗位名称（英文）
    department = Column(String(50), nullable=False)  # 部门
    department_en = Column(String(50), nullable=True)  # 部门（英文）
    type = Column(String(20), nullable=False)  # 全职/兼职/实习
    type_en = Column(String(20), nullable=True)  # 工作类型（英文）
    location = Column(String(100), nullable=False)  # 工作地点
    location_en = Column(String(100), nullable=True)  # 工作地点（英文）
    experience = Column(String(50), nullable=False)  # 经验要求
    experience_en = Column(String(50), nullable=True)  # 经验要求（英文）
    salary = Column(String(50), nullable=False)  # 薪资范围
    salary_en = Column(String(50), nullable=True)  # 薪资范围（英文）
    description = Column(Text, nullable=False)  # 岗位描述
    description_en = Column(Text, nullable=True)  # 岗位描述（英文）
    requirements = Column(Text, nullable=False)  # 任职要求（JSON格式存储）
    requirements_en = Column(Text, nullable=True)  # 任职要求（英文，JSON格式存储）
    tags = Column(Text, nullable=True)  # 技能标签（JSON格式存储）
    tags_en = Column(Text, nullable=True)  # 技能标签（英文，JSON格式存储）
    is_active = Column(Integer, default=1)  # 是否启用
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)
    created_by = Column(String(5), ForeignKey("admin_users.id"), nullable=False)  # 创建者
    
    # 索引
    __table_args__ = (
        Index("ix_job_positions_title", title),
        Index("ix_job_positions_department", department),
        Index("ix_job_positions_type", type),
        Index("ix_job_positions_location", location),
        Index("ix_job_positions_is_active", is_active),
        Index("ix_job_positions_created_at", created_at),
    )


class FeaturedTaskExpert(Base):
    """精选任务达人模型"""
    __tablename__ = "featured_task_experts"
    
    id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)  # 使用用户ID作为主键
    user_id = Column(String(8), ForeignKey("users.id"), unique=True, nullable=False)  # 关联到实际用户（与id相同）
    name = Column(String(50), nullable=False)  # 显示名称
    avatar = Column(String(200), default="")  # 头像URL
    user_level = Column(String(20), default="normal")  # normal, vip, super
    bio = Column(Text, nullable=True)  # 个人简介
    bio_en = Column(Text, nullable=True)  # 个人简介（英文）
    
    # 统计数据（如果关联用户ID，这些可以从用户数据获取）
    avg_rating = Column(Float, default=0.0)  # 平均评分
    completed_tasks = Column(Integer, default=0)  # 已完成任务数
    total_tasks = Column(Integer, default=0)  # 总任务数
    completion_rate = Column(Float, default=0.0)  # 完成率
    
    # 专业领域和技能（JSON格式存储）
    expertise_areas = Column(Text, nullable=True)  # 专业领域
    expertise_areas_en = Column(Text, nullable=True)  # 专业领域（英文）
    featured_skills = Column(Text, nullable=True)  # 特色技能
    featured_skills_en = Column(Text, nullable=True)  # 特色技能（英文）
    achievements = Column(Text, nullable=True)  # 成就徽章
    achievements_en = Column(Text, nullable=True)  # 成就徽章（英文）
    
    response_time = Column(String(50), nullable=True)  # 响应时间
    response_time_en = Column(String(50), nullable=True)  # 响应时间（英文）
    success_rate = Column(Float, default=0.0)  # 成功率
    is_verified = Column(Integer, default=0)  # 是否认证
    is_active = Column(Integer, default=1)  # 是否显示
    is_featured = Column(Integer, default=1)  # 是否精选推荐
    display_order = Column(Integer, default=0)  # 显示顺序
    category = Column(String(50), nullable=True)  # 分类（programming, design, marketing, writing, translation）
    location = Column(String(50), nullable=True)  # 城市位置（如：London, Manchester, Online等）
    
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)
    created_by = Column(String(5), ForeignKey("admin_users.id"), nullable=False)  # 创建者
    
    # 索引
    # 注意：id 已经是主键，会自动创建索引
    # user_id 有唯一约束，会自动创建唯一索引，但为了明确性和查询优化，也显式添加索引
    __table_args__ = (
        Index("ix_featured_task_experts_user_id", user_id),  # user_id 索引，用于优化查询
        Index("ix_task_experts_category", category),
        Index("ix_task_experts_is_active", is_active),
        Index("ix_task_experts_is_featured", is_featured),
        Index("ix_task_experts_display_order", display_order),
        Index("ix_task_experts_created_at", created_at),
    )


class UserPreferences(Base):
    """用户任务偏好模型"""
    __tablename__ = "user_preferences"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(8), ForeignKey("users.id"), unique=True, nullable=False)  # 关联用户
    task_types = Column(Text, nullable=True)  # JSON格式存储偏好的任务类型
    locations = Column(Text, nullable=True)  # JSON格式存储偏好的地点
    task_levels = Column(Text, nullable=True)  # JSON格式存储偏好的任务等级
    keywords = Column(Text, nullable=True)  # JSON格式存储偏好关键词
    min_deadline_days = Column(Integer, default=1)  # 最少截止时间（天）
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)
    
    # 关系
    user = relationship("User", backref="preferences")
    
    # 索引
    __table_args__ = (
        Index("ix_user_preferences_user_id", user_id),
        Index("ix_user_preferences_updated_at", updated_at),
    )


class MessageRead(Base):
    """消息已读状态表"""
    __tablename__ = "message_reads"
    
    id = Column(Integer, primary_key=True, index=True)
    message_id = Column(Integer, ForeignKey("messages.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(8), ForeignKey("users.id"), nullable=False)
    read_at = Column(DateTime(timezone=True), default=get_utc_time, nullable=False)
    
    __table_args__ = (
        UniqueConstraint("message_id", "user_id", name="uq_message_reads_message_user"),
        Index("ix_message_reads_message_id", message_id),
        Index("ix_message_reads_user_id", user_id),
        Index("ix_message_reads_task_user", message_id, user_id),
    )


class MessageAttachment(Base):
    """消息附件表"""
    __tablename__ = "message_attachments"
    
    id = Column(Integer, primary_key=True, index=True)
    message_id = Column(Integer, ForeignKey("messages.id", ondelete="CASCADE"), nullable=False)
    attachment_type = Column(String(20), nullable=False)  # image/file/video等
    url = Column(String(500), nullable=True)  # 附件URL（公开附件）
    blob_id = Column(String(100), nullable=True)  # 私密文件ID（私密附件）
    meta = Column(Text, nullable=True)  # JSON格式存储元数据
    created_at = Column(DateTime(timezone=True), default=get_utc_time, nullable=False)
    
    __table_args__ = (
        # 存在性约束：url 和 blob_id 必须二选一
        CheckConstraint(
            "(url IS NOT NULL AND blob_id IS NULL) OR (url IS NULL AND blob_id IS NOT NULL)",
            name="ck_message_attachments_url_blob"
        ),
        Index("ix_message_attachments_message_id", message_id),
    )


class NegotiationResponseLog(Base):
    """议价响应操作日志表"""
    __tablename__ = "negotiation_response_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    notification_id = Column(Integer, ForeignKey("notifications.id"), nullable=True)  # 可为空（如果通知被删除）
    task_id = Column(Integer, ForeignKey("tasks.id"), nullable=False)
    application_id = Column(Integer, ForeignKey("task_applications.id"), nullable=False)
    user_id = Column(String(8), ForeignKey("users.id"), nullable=False)
    action = Column(String(20), nullable=False)  # 'accept' 或 'reject' 或 'withdraw'
    negotiated_price = Column(DECIMAL(12, 2), nullable=True)  # 议价价格（如果接受）
    responded_at = Column(DateTime(timezone=True), default=get_utc_time, nullable=False)
    ip_address = Column(String(45), nullable=True)  # 操作IP（可选，用于审计）
    user_agent = Column(Text, nullable=True)  # 用户代理（可选，用于审计）
    
    __table_args__ = (
        # 业务级唯一约束：防止重复落库（包括重放/抖动）
        UniqueConstraint("application_id", "action", name="uq_negotiation_log_application_action"),
        Index("ix_negotiation_log_notification", notification_id),
        Index("ix_negotiation_log_task", task_id),
        Index("ix_negotiation_log_application", application_id),
        Index("ix_negotiation_log_user", user_id),
    )


class MessageReadCursor(Base):
    """消息已读游标表（按任务维度记录已读游标，降低写放大）"""
    __tablename__ = "message_read_cursors"
    
    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id"), nullable=False)
    user_id = Column(String(8), ForeignKey("users.id"), nullable=False)
    last_read_message_id = Column(Integer, ForeignKey("messages.id"), nullable=False)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, nullable=False)
    
    __table_args__ = (
        UniqueConstraint("task_id", "user_id", name="uq_message_read_cursors_task_user"),
        Index("ix_message_read_cursors_task_user", task_id, user_id),
        Index("ix_message_read_cursors_message", last_read_message_id),
    )


# ==================== 优惠券和积分系统模型 ====================

class Coupon(Base):
    """优惠券表"""
    __tablename__ = "coupons"
    
    id = Column(BigInteger, primary_key=True, index=True)
    code = Column(String(50), nullable=False, index=True)  # 优惠券代码（不区分大小写唯一）
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    type = Column(String(20), nullable=False)  # fixed_amount, percentage
    discount_value = Column(BigInteger, nullable=True)  # 优惠金额或折扣基点
    min_amount = Column(BigInteger, default=0)  # 最低使用金额
    max_discount = Column(BigInteger, nullable=True)  # 最大折扣金额
    currency = Column(String(3), default="GBP")
    total_quantity = Column(Integer, nullable=True)  # 总发放数量（NULL表示无限制）
    per_user_limit = Column(Integer, default=1)  # 每个用户限用次数
    per_device_limit = Column(Integer, nullable=True)  # 每个设备限用次数
    per_ip_limit = Column(Integer, nullable=True)  # 每个IP限用次数
    can_combine = Column(Boolean, default=False)  # 是否可与其他优惠叠加
    combine_limit = Column(Integer, default=1)  # 最多可叠加数量
    apply_order = Column(Integer, default=0)  # 应用顺序
    valid_from = Column(DateTime(timezone=True), nullable=False)  # TIMESTAMPTZ
    valid_until = Column(DateTime(timezone=True), nullable=False)  # TIMESTAMPTZ
    status = Column(String(20), default="active")  # active, inactive, expired
    usage_conditions = Column(JSONB, nullable=True)  # 使用条件限制（JSON格式）
    eligibility_type = Column(String(20), nullable=True)  # first_order, new_user, user_type, member, all
    eligibility_value = Column(Text, nullable=True)  # 资格值
    per_day_limit = Column(Integer, nullable=True)  # 每日限用次数
    vat_category = Column(String(20), nullable=True)  # VAT分类
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)
    
    __table_args__ = (
        Index("ix_coupons_code_lower", "code"),  # 不区分大小写唯一索引（需要在数据库层面创建）
        Index("ix_coupons_status", status),
        Index("ix_coupons_valid", valid_from, valid_until),
        Index("ix_coupons_conditions", usage_conditions, postgresql_using="gin"),  # GIN索引用于JSONB
        Index("ix_coupons_combine", can_combine, apply_order),
        CheckConstraint("valid_until > valid_from", name="chk_coupon_dates"),
        CheckConstraint(
            "(type = 'fixed_amount' AND discount_value > 0) OR (type = 'percentage' AND discount_value BETWEEN 1 AND 10000)",
            name="chk_coupon_discount"
        ),
    )


class UserCoupon(Base):
    """用户优惠券表"""
    __tablename__ = "user_coupons"
    
    id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    coupon_id = Column(BigInteger, ForeignKey("coupons.id", ondelete="CASCADE"), nullable=False)
    promotion_code_id = Column(BigInteger, ForeignKey("promotion_codes.id"), nullable=True)
    status = Column(String(20), default="unused")  # unused, used, expired
    obtained_at = Column(DateTime(timezone=True), default=get_utc_time)
    used_at = Column(DateTime(timezone=True), nullable=True)
    used_in_task_id = Column(BigInteger, ForeignKey("tasks.id"), nullable=True)  # 统一为BIGINT
    device_fingerprint = Column(String(64), nullable=True)
    ip_address = Column(INET, nullable=True)
    idempotency_key = Column(String(64), unique=True, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    
    __table_args__ = (
        Index("ix_user_coupons_user", user_id),
        Index("ix_user_coupons_status", status),
        Index("ix_user_coupons_coupon", coupon_id),
    )


class CouponRedemption(Base):
    """优惠券使用记录表（两阶段使用控制）"""
    __tablename__ = "coupon_redemptions"
    
    id = Column(BigInteger, primary_key=True, index=True)
    user_coupon_id = Column(BigInteger, ForeignKey("user_coupons.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    coupon_id = Column(BigInteger, ForeignKey("coupons.id", ondelete="CASCADE"), nullable=False)
    task_id = Column(BigInteger, ForeignKey("tasks.id"), nullable=True)
    status = Column(String(20), default="reserved")  # reserved, confirmed, cancelled
    reserved_at = Column(DateTime(timezone=True), default=get_utc_time)
    confirmed_at = Column(DateTime(timezone=True), nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=True)  # 预授权过期时间
    idempotency_key = Column(String(64), unique=True, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    
    __table_args__ = (
        Index("ix_coupon_redemptions_user_coupon", user_coupon_id),
        Index("ix_coupon_redemptions_status", status),
        Index("ix_coupon_redemptions_expires", expires_at),
        # 部分唯一索引：确保同一张券同一时刻至多一条未确认的预留
        Index("idx_coupon_redemptions_reserved_unique", user_coupon_id, unique=True, 
              postgresql_where=(status == "reserved")),
        # 部分唯一索引：防止同一任务重复使用同一张券
        Index("uq_redemption_task_nonnull", user_id, coupon_id, task_id, unique=True,
              postgresql_where=(task_id.isnot(None))),
    )


class PointsAccount(Base):
    """积分账户表"""
    __tablename__ = "points_accounts"
    
    id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    balance = Column(BigInteger, default=0)  # 当前积分余额（整数，100积分=£1.00）
    currency = Column(String(3), default="GBP")
    total_earned = Column(BigInteger, default=0)  # 累计获得积分
    total_spent = Column(BigInteger, default=0)  # 累计消费积分
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)
    
    __table_args__ = (
        Index("ix_points_accounts_user", user_id),
    )


class PointsTransaction(Base):
    """积分交易记录表"""
    __tablename__ = "points_transactions"
    
    id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    type = Column(String(20), nullable=False)  # earn, spend, refund, expire
    amount = Column(BigInteger, nullable=False)  # 积分数量（正数表示增加，负数表示减少）
    balance_after = Column(BigInteger, nullable=False)  # 交易后余额
    currency = Column(String(3), default="GBP")
    source = Column(String(50), nullable=True)  # 来源：task_complete_bonus, invite_bonus等
    related_id = Column(BigInteger, nullable=True)  # 关联ID
    related_type = Column(String(50), nullable=True)  # 关联类型：task, coupon等
    batch_id = Column(String(50), nullable=True)  # 批次ID
    expires_at = Column(DateTime(timezone=True), nullable=True)  # 过期时间
    description = Column(Text, nullable=True)
    idempotency_key = Column(String(64), unique=True, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    
    __table_args__ = (
        Index("ix_points_transactions_user", user_id),
        Index("ix_points_transactions_type", type),
        Index("ix_points_transactions_created", created_at),
        Index("ix_points_transactions_related", related_type, related_id),
        CheckConstraint(
            "(type = 'earn' AND amount > 0) OR (type = 'spend' AND amount < 0) OR (type = 'refund' AND amount > 0) OR (type = 'expire' AND amount < 0)",
            name="chk_points_amount_sign"
        ),
    )


class CouponUsageLog(Base):
    """优惠券使用记录表"""
    __tablename__ = "coupon_usage_logs"
    
    id = Column(BigInteger, primary_key=True, index=True)
    user_coupon_id = Column(BigInteger, ForeignKey("user_coupons.id", ondelete="CASCADE"), nullable=False)
    redemption_id = Column(BigInteger, ForeignKey("coupon_redemptions.id"), nullable=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    coupon_id = Column(BigInteger, ForeignKey("coupons.id", ondelete="CASCADE"), nullable=False)
    promotion_code_id = Column(BigInteger, ForeignKey("promotion_codes.id"), nullable=True)
    task_id = Column(BigInteger, ForeignKey("tasks.id"), nullable=True)
    discount_amount_before_tax = Column(BigInteger, nullable=False)  # 折前优惠金额
    discount_amount = Column(BigInteger, nullable=False)  # 实际优惠金额（含税）
    order_amount_before_tax = Column(BigInteger, nullable=False)  # 订单原始金额（折前）
    order_amount_incl_tax = Column(BigInteger, nullable=False)  # 订单原始金额（含税）
    final_amount_before_tax = Column(BigInteger, nullable=False)  # 优惠后金额（折前）
    final_amount_incl_tax = Column(BigInteger, nullable=False)  # 优惠后金额（含税）
    vat_amount = Column(BigInteger, nullable=True)  # VAT税额
    vat_rate = Column(DECIMAL(5, 2), nullable=True)  # VAT税率
    vat_category = Column(String(20), nullable=True)  # VAT分类
    rounding_method = Column(String(20), default="bankers")  # 舍入方法
    currency = Column(String(3), default="GBP")
    applied_coupons = Column(JSONB, nullable=True)  # 应用的优惠券列表
    refund_status = Column(String(20), default="none")  # none, partial, full
    refunded_at = Column(DateTime(timezone=True), nullable=True)
    refund_reason = Column(Text, nullable=True)
    idempotency_key = Column(String(64), unique=True, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    
    __table_args__ = (
        Index("ix_coupon_usage_logs_user", user_id),
        Index("ix_coupon_usage_logs_task", task_id),
        Index("ix_coupon_usage_logs_coupon", coupon_id),
    )


class CheckIn(Base):
    """签到记录表"""
    __tablename__ = "check_ins"
    
    id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    check_in_date = Column(Date, nullable=False)  # 签到日期
    timezone = Column(String(50), default="Europe/London")  # 时区
    consecutive_days = Column(Integer, default=1)  # 连续签到天数
    reward_type = Column(String(20), nullable=True)  # points, coupon
    points_reward = Column(BigInteger, nullable=True)  # 积分奖励
    coupon_id = Column(BigInteger, ForeignKey("coupons.id"), nullable=True)  # 优惠券ID
    reward_description = Column(Text, nullable=True)
    device_fingerprint = Column(String(64), nullable=True)
    ip_address = Column(INET, nullable=True)
    idempotency_key = Column(String(64), unique=True, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    
    __table_args__ = (
        UniqueConstraint("user_id", "check_in_date", name="uq_user_checkin_date"),
        Index("ix_check_ins_user", user_id),
        Index("ix_check_ins_date", check_in_date),
        Index("ix_check_ins_user_date", user_id, check_in_date),
        CheckConstraint(
            "(reward_type = 'points' AND points_reward IS NOT NULL AND coupon_id IS NULL) OR (reward_type = 'coupon' AND coupon_id IS NOT NULL AND points_reward IS NULL)",
            name="chk_checkin_reward"
        ),
    )


class CheckInReward(Base):
    """签到奖励配置表"""
    __tablename__ = "check_in_rewards"
    
    id = Column(BigInteger, primary_key=True, index=True)
    consecutive_days = Column(Integer, unique=True, nullable=False)  # 连续签到天数
    reward_type = Column(String(20), nullable=False)  # points, coupon
    points_reward = Column(BigInteger, nullable=True)  # 积分奖励
    coupon_id = Column(BigInteger, ForeignKey("coupons.id"), nullable=True)  # 优惠券ID
    reward_description = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)
    
    __table_args__ = (
        Index("ix_check_in_rewards_days", consecutive_days),
        Index("ix_check_in_rewards_active", is_active),
        CheckConstraint(
            "(reward_type = 'points' AND points_reward IS NOT NULL AND coupon_id IS NULL) OR (reward_type = 'coupon' AND coupon_id IS NOT NULL AND points_reward IS NULL)",
            name="chk_checkin_reward_value"
        ),
    )


class InvitationCode(Base):
    """邀请码表"""
    __tablename__ = "invitation_codes"
    
    id = Column(BigInteger, primary_key=True, index=True)
    code = Column(String(50), nullable=False, index=True)  # 邀请码（不区分大小写唯一）
    name = Column(String(100), nullable=True)
    description = Column(Text, nullable=True)
    reward_type = Column(String(20), nullable=False)  # points, coupon, both
    points_reward = Column(BigInteger, default=0)  # 积分奖励数量
    coupon_id = Column(BigInteger, ForeignKey("coupons.id"), nullable=True)
    currency = Column(String(3), default="GBP")
    max_uses = Column(Integer, nullable=True)  # 最大使用次数（NULL表示无限制）
    valid_from = Column(DateTime(timezone=True), nullable=False)
    valid_until = Column(DateTime(timezone=True), nullable=False)
    is_active = Column(Boolean, default=True)
    created_by = Column(String(5), ForeignKey("admin_users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)
    
    __table_args__ = (
        Index("ix_invitation_codes_code_lower", "code"),  # 不区分大小写唯一索引（需要在数据库层面创建）
        Index("ix_invitation_codes_active", is_active),
        Index("ix_invitation_codes_valid", valid_from, valid_until),
        Index("ix_invitation_codes_created_by", created_by),
    )


class UserInvitationUsage(Base):
    """用户邀请码使用记录表"""
    __tablename__ = "user_invitation_usage"
    
    id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    invitation_code_id = Column(BigInteger, ForeignKey("invitation_codes.id", ondelete="CASCADE"), nullable=False)
    used_at = Column(DateTime(timezone=True), default=get_utc_time)
    reward_received = Column(Boolean, default=False)  # 是否已发放奖励
    points_received = Column(BigInteger, nullable=True)  # 实际获得的积分
    coupon_received_id = Column(BigInteger, ForeignKey("coupons.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    
    __table_args__ = (
        UniqueConstraint("user_id", "invitation_code_id", name="uq_user_invitation_usage"),
        Index("ix_user_invitation_usage_user", user_id),
        Index("ix_user_invitation_usage_code", invitation_code_id),
        Index("ix_user_invitation_usage_used_at", used_at),
    )


class AdminReward(Base):
    """管理员发放记录表"""
    __tablename__ = "admin_rewards"
    
    id = Column(BigInteger, primary_key=True, index=True)
    reward_type = Column(String(20), nullable=False)  # points, coupon
    target_type = Column(String(20), nullable=False)  # user, user_type, all
    target_value = Column(Text, nullable=True)  # 目标值（JSON格式）
    points_value = Column(BigInteger, nullable=True)  # 积分数量
    coupon_id = Column(BigInteger, ForeignKey("coupons.id"), nullable=True)
    total_users = Column(Integer, default=0)  # 发放用户总数
    success_count = Column(Integer, default=0)  # 成功发放数量
    failed_count = Column(Integer, default=0)  # 失败数量
    status = Column(String(20), default="pending")  # pending, processing, completed, failed
    description = Column(Text, nullable=True)
    created_by = Column(String(5), ForeignKey("admin_users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    
    __table_args__ = (
        Index("ix_admin_rewards_type", reward_type),
        Index("ix_admin_rewards_target", target_type),
        Index("ix_admin_rewards_status", status),
        Index("ix_admin_rewards_created_by", created_by),
        Index("ix_admin_rewards_created_at", created_at),
        CheckConstraint(
            "(reward_type = 'points' AND points_value IS NOT NULL AND coupon_id IS NULL) OR (reward_type = 'coupon' AND coupon_id IS NOT NULL AND points_value IS NULL)",
            name="chk_admin_rewards_value"
        ),
    )


class AdminRewardDetail(Base):
    """管理员发放详情表"""
    __tablename__ = "admin_reward_details"
    
    id = Column(BigInteger, primary_key=True, index=True)
    admin_reward_id = Column(BigInteger, ForeignKey("admin_rewards.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    reward_type = Column(String(20), nullable=False)  # points, coupon
    points_value = Column(BigInteger, nullable=True)  # 积分数量
    coupon_id = Column(BigInteger, ForeignKey("coupons.id"), nullable=True)
    status = Column(String(20), default="pending")  # pending, success, failed
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    
    __table_args__ = (
        Index("ix_admin_reward_details_reward", admin_reward_id),
        Index("ix_admin_reward_details_user", user_id),
        Index("ix_admin_reward_details_status", status),
        CheckConstraint(
            "(reward_type = 'points' AND points_value IS NOT NULL AND coupon_id IS NULL) OR (reward_type = 'coupon' AND coupon_id IS NOT NULL AND points_value IS NULL)",
            name="chk_admin_reward_details_value"
        ),
    )


class DeviceFingerprint(Base):
    """设备指纹表"""
    __tablename__ = "device_fingerprints"
    
    id = Column(BigInteger, primary_key=True, index=True)
    fingerprint = Column(String(64), unique=True, nullable=False)
    user_id = Column(String(8), ForeignKey("users.id"), nullable=True)
    device_info = Column(JSONB, nullable=True)  # 设备信息
    ip_address = Column(INET, nullable=True)
    first_seen = Column(DateTime(timezone=True), default=get_utc_time)
    last_seen = Column(DateTime(timezone=True), default=get_utc_time)
    risk_score = Column(Integer, default=0)  # 风险评分（0-100）
    is_blocked = Column(Boolean, default=False)
    
    __table_args__ = (
        Index("ix_device_fingerprints_fp", fingerprint),
        Index("ix_device_fingerprints_user", user_id),
        Index("ix_device_fingerprints_risk", risk_score),
    )


class RiskControlLog(Base):
    """风控记录表"""
    __tablename__ = "risk_control_logs"
    
    id = Column(BigInteger, primary_key=True, index=True)
    user_id = Column(String(8), ForeignKey("users.id"), nullable=True)
    device_fingerprint = Column(String(64), ForeignKey("device_fingerprints.fingerprint"), nullable=True)
    action_type = Column(String(50), nullable=False)  # checkin, coupon_claim, points_earn等
    risk_level = Column(String(20), nullable=True)  # low, medium, high, critical
    risk_reason = Column(Text, nullable=True)
    action_blocked = Column(Boolean, default=False)
    meta_data = Column(JSONB, nullable=True)  # 额外信息（使用meta_data避免与SQLAlchemy保留字冲突）
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    
    __table_args__ = (
        Index("ix_risk_logs_user", user_id),
        Index("ix_risk_logs_device", device_fingerprint),
        Index("ix_risk_logs_action", action_type),
        Index("ix_risk_logs_risk", risk_level),
        Index("ix_risk_logs_created", created_at),
    )


class PromotionCode(Base):
    """推广码表（Stripe风格设计）"""
    __tablename__ = "promotion_codes"
    
    id = Column(BigInteger, primary_key=True, index=True)
    code = Column(String(50), nullable=False, index=True)  # 推广码（不区分大小写唯一）
    coupon_id = Column(BigInteger, ForeignKey("coupons.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(100), nullable=True)
    description = Column(Text, nullable=True)
    max_uses = Column(Integer, nullable=True)  # 最大使用次数
    per_user_limit = Column(Integer, default=1)  # 每个用户限用次数
    min_order_amount = Column(BigInteger, nullable=True)  # 最低订单金额
    can_combine = Column(Boolean, nullable=True)  # 是否可叠加
    valid_from = Column(DateTime(timezone=True), nullable=False)
    valid_until = Column(DateTime(timezone=True), nullable=False)
    is_active = Column(Boolean, default=True)
    target_user_type = Column(String(20), nullable=True)  # vip, super, normal, all
    created_by = Column(String(5), ForeignKey("admin_users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)
    
    __table_args__ = (
        Index("ix_promotion_codes_code_lower", "code"),  # 不区分大小写唯一索引（需要在数据库层面创建）
        Index("ix_promotion_codes_coupon", coupon_id),
        Index("ix_promotion_codes_active", is_active),
        Index("ix_promotion_codes_valid", valid_from, valid_until),
        CheckConstraint("valid_until > valid_from", name="chk_promo_dates"),
    )


class AuditLog(Base):
    """审计日志表"""
    __tablename__ = "audit_logs"
    
    id = Column(BigInteger, primary_key=True, index=True)
    action_type = Column(String(50), nullable=False)  # 操作类型
    entity_type = Column(String(50), nullable=True)  # 实体类型
    entity_id = Column(String(50), nullable=True)  # 实体ID
    user_id = Column(String(8), ForeignKey("users.id"), nullable=True)
    admin_id = Column(String(5), ForeignKey("admin_users.id"), nullable=True)
    old_value = Column(JSONB, nullable=True)  # 旧值
    new_value = Column(JSONB, nullable=True)  # 新值
    reason = Column(Text, nullable=True)
    ip_address = Column(INET, nullable=True)
    device_fingerprint = Column(String(64), nullable=True)
    error_code = Column(String(50), nullable=True)
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    
    __table_args__ = (
        Index("ix_audit_logs_action", action_type),
        Index("ix_audit_logs_entity", entity_type, entity_id),
        Index("ix_audit_logs_user", user_id),
        Index("ix_audit_logs_admin", admin_id),
        Index("ix_audit_logs_created", created_at),
    )


# ==================== 任务达人功能模型 ====================

class TaskExpertApplication(Base):
    """任务达人申请表"""
    __tablename__ = "task_expert_applications"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    application_message = Column(Text, nullable=True)
    status = Column(String(20), default="pending")  # pending, approved, rejected
    reviewed_by = Column(String(5), ForeignKey("admin_users.id"), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)  # 审核时间
    review_comment = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 关系
    user = relationship("User", backref="expert_applications")  # 修复：改为复数，表示一对多关系
    reviewer = relationship("AdminUser", backref="reviewed_expert_applications")
    
    __table_args__ = (
        Index("ix_task_expert_applications_user_id", user_id),
        Index("ix_task_expert_applications_status", status),
        Index("ix_task_expert_applications_reviewed_by", reviewed_by),
        # 注意：部分唯一索引需要在数据库层面通过SQL创建
        # CREATE UNIQUE INDEX uq_expert_app_pending ON task_expert_applications (user_id, status) WHERE status = 'pending';
    )


class TaskExpert(Base):
    """任务达人表
    
    重要说明：
    - id 字段与用户在 users 表中的 id 相同
    - 通过外键约束确保数据一致性
    - 管理员批准申请时，使用申请中的 user_id 作为任务达人的 id
    """
    __tablename__ = "task_experts"
    
    id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)  # 与用户ID相同
    expert_name = Column(String(100), nullable=True)
    bio = Column(Text, nullable=True)
    avatar = Column(Text, nullable=True)  # 与DDL统一为TEXT，支持长CDN URL
    status = Column(String(20), default="active")  # active, inactive, suspended
    rating = Column(DECIMAL(3, 2), default=0.00)  # 0.00-5.00（CHECK约束在DDL中定义）
    total_services = Column(Integer, default=0)
    completed_tasks = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    approved_by = Column(String(5), ForeignKey("admin_users.id"), nullable=True)
    approved_at = Column(DateTime(timezone=True), nullable=True)
    
    # 关系
    user = relationship("User", backref="expert_profile", foreign_keys=[id])
    approver = relationship("AdminUser", backref="approved_experts")
    services = relationship("TaskExpertService", back_populates="expert", cascade="all, delete-orphan")
    profile_update_requests = relationship("TaskExpertProfileUpdateRequest", back_populates="expert", cascade="all, delete-orphan")
    closed_dates = relationship("ExpertClosedDate", back_populates="expert", cascade="all, delete-orphan")
    
    __table_args__ = (
        Index("ix_task_experts_status", status),
        Index("ix_task_experts_rating", rating),
    )


class TaskExpertProfileUpdateRequest(Base):
    """任务达人信息修改审核申请表"""
    __tablename__ = "task_expert_profile_update_requests"
    
    id = Column(Integer, primary_key=True, index=True)
    expert_id = Column(String(8), ForeignKey("task_experts.id", ondelete="CASCADE"), nullable=False)
    # 待修改的字段
    new_expert_name = Column(String(100), nullable=True)  # 新的名字
    new_bio = Column(Text, nullable=True)  # 新的简介
    new_avatar = Column(Text, nullable=True)  # 新的头像
    # 审核相关
    status = Column(String(20), default="pending")  # pending, approved, rejected
    reviewed_by = Column(String(5), ForeignKey("admin_users.id"), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    review_comment = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 关系
    expert = relationship("TaskExpert", back_populates="profile_update_requests")
    reviewer = relationship("AdminUser", backref="reviewed_profile_update_requests")
    
    __table_args__ = (
        Index("ix_profile_update_requests_expert_id", expert_id),
        Index("ix_profile_update_requests_status", status),
        Index("ix_profile_update_requests_reviewed_by", reviewed_by),
        # 部分唯一索引：确保一个任务达人只能有一个待审核的修改请求
        # CREATE UNIQUE INDEX uq_profile_update_pending ON task_expert_profile_update_requests (expert_id, status) WHERE status = 'pending';
    )


class TaskExpertService(Base):
    """任务达人服务菜单表"""
    __tablename__ = "task_expert_services"
    
    id = Column(Integer, primary_key=True, index=True)
    expert_id = Column(String(8), ForeignKey("task_experts.id", ondelete="CASCADE"), nullable=False)
    service_name = Column(String(200), nullable=False)
    description = Column(Text, nullable=False)
    images = Column(JSONB, nullable=True)  # JSON数组（使用PostgreSQL JSONB类型）
    base_price = Column(DECIMAL(12, 2), nullable=False)
    currency = Column(String(3), default="GBP")
    status = Column(String(20), default="active")  # active, inactive
    display_order = Column(Integer, default=0)
    view_count = Column(Integer, default=0)
    application_count = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 时间段相关字段
    has_time_slots = Column(Boolean, default=False, nullable=False)  # 是否启用时间段
    time_slot_duration_minutes = Column(Integer, nullable=True)  # 每个时间段的时长（分钟）
    time_slot_start_time = Column(Time, nullable=True)  # 时间段开始时间（每天，向后兼容）
    time_slot_end_time = Column(Time, nullable=True)  # 时间段结束时间（每天，向后兼容）
    participants_per_slot = Column(Integer, nullable=True)  # 每个时间段最多参与者数量
    weekly_time_slot_config = Column(JSONB, nullable=True)  # 按周几设置时间段配置（JSON格式）
    
    # 关系
    expert = relationship("TaskExpert", back_populates="services")
    applications = relationship("ServiceApplication", back_populates="service", cascade="all, delete-orphan")
    time_slots = relationship("ServiceTimeSlot", back_populates="service", cascade="all, delete-orphan")
    activities = relationship("Activity", back_populates="service", cascade="all, delete-orphan")
    
    __table_args__ = (
        Index("ix_task_expert_services_expert_id", expert_id),
        Index("ix_task_expert_services_status", status),
        Index("ix_task_expert_services_expert_status", expert_id, status),
    )


class ServiceTimeSlot(Base):
    """服务时间段表 - 存储具体的日期时间段和价格（使用UTC时间）"""
    __tablename__ = "service_time_slots"
    
    id = Column(Integer, primary_key=True, index=True)
    service_id = Column(Integer, ForeignKey("task_expert_services.id", ondelete="CASCADE"), nullable=False)
    slot_start_datetime = Column(DateTime(timezone=True), nullable=False)  # 时间段开始时间（UTC，包含日期和时间）
    slot_end_datetime = Column(DateTime(timezone=True), nullable=False)  # 时间段结束时间（UTC，包含日期和时间）
    price_per_participant = Column(DECIMAL(12, 2), nullable=False)  # 每个参与者的价格
    max_participants = Column(Integer, nullable=False)  # 该时间段最多参与者数量
    current_participants = Column(Integer, default=0, nullable=False)  # 当前已报名参与者数量
    is_available = Column(Boolean, default=True, nullable=False)  # 是否可用（可手动关闭某个时间段）
    is_manually_deleted = Column(Boolean, default=False, nullable=False)  # 是否手动删除（避免自动重新生成）
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 为了向后兼容，添加属性访问器
    @property
    def slot_date(self):
        """获取日期部分（用于向后兼容）"""
        if self.slot_start_datetime:
            return self.slot_start_datetime.date()
        return None
    
    @property
    def start_time(self):
        """获取开始时间部分（用于向后兼容）"""
        if self.slot_start_datetime:
            return self.slot_start_datetime.time()
        return None
    
    @property
    def end_time(self):
        """获取结束时间部分（用于向后兼容）"""
        if self.slot_end_datetime:
            return self.slot_end_datetime.time()
        return None
    
    # 关系
    service = relationship("TaskExpertService", back_populates="time_slots")
    applications = relationship("ServiceApplication", back_populates="time_slot", cascade="all, delete-orphan")
    
    __table_args__ = (
        Index("ix_service_time_slots_service_id", service_id),
        Index("ix_service_time_slots_slot_start_datetime", slot_start_datetime),
        Index("ix_service_time_slots_service_start", service_id, slot_start_datetime),
        UniqueConstraint("service_id", "slot_start_datetime", "slot_end_datetime", name="uq_service_time_slot"),
    )


class ExpertClosedDate(Base):
    """任务达人关门日期表 - 存储任务达人的休息日"""
    __tablename__ = "expert_closed_dates"
    
    id = Column(Integer, primary_key=True, index=True)
    expert_id = Column(String(8), ForeignKey("task_experts.id", ondelete="CASCADE"), nullable=False)
    closed_date = Column(Date, nullable=False)  # 关门日期（不包含时间）
    reason = Column(String(200), nullable=True)  # 关门原因（可选）
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 关系
    expert = relationship("TaskExpert", back_populates="closed_dates")
    
    __table_args__ = (
        Index("ix_expert_closed_dates_expert_id", expert_id),
        Index("ix_expert_closed_dates_closed_date", closed_date),
        UniqueConstraint("expert_id", "closed_date", name="uq_expert_closed_date"),
    )


class ServiceApplication(Base):
    """服务申请表"""
    __tablename__ = "service_applications"
    
    id = Column(Integer, primary_key=True, index=True)
    service_id = Column(Integer, ForeignKey("task_expert_services.id", ondelete="CASCADE"), nullable=False)
    applicant_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    expert_id = Column(String(8), ForeignKey("task_experts.id", ondelete="CASCADE"), nullable=False)
    time_slot_id = Column(Integer, ForeignKey("service_time_slots.id", ondelete="SET NULL"), nullable=True)  # 选择的时间段ID
    application_message = Column(Text, nullable=True)
    negotiated_price = Column(DECIMAL(12, 2), nullable=True)  # 用户提出的议价价格
    expert_counter_price = Column(DECIMAL(12, 2), nullable=True)  # 任务达人提出的再次议价价格
    currency = Column(String(3), default="GBP")
    status = Column(String(20), default="pending")  # pending, negotiating, price_agreed, approved, rejected, cancelled
    final_price = Column(DECIMAL(12, 2), nullable=True)
    task_id = Column(Integer, ForeignKey("tasks.id"), nullable=True)
    deadline = Column(DateTime(timezone=True), nullable=True)  # 任务截至日期（如果is_flexible为False）
    is_flexible = Column(Integer, default=0)  # 是否灵活（1=灵活，无截至日期；0=有截至日期）
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    approved_at = Column(DateTime(timezone=True), nullable=True)
    rejected_at = Column(DateTime(timezone=True), nullable=True)
    price_agreed_at = Column(DateTime(timezone=True), nullable=True)  # 价格达成一致的时间
    
    # 关系
    service = relationship("TaskExpertService", back_populates="applications")
    applicant = relationship("User", foreign_keys=[applicant_id], backref="service_applications")
    expert = relationship("TaskExpert", foreign_keys=[expert_id])
    task = relationship("Task", backref="service_application")
    time_slot = relationship("ServiceTimeSlot", back_populates="applications", foreign_keys=[time_slot_id])
    
    __table_args__ = (
        Index("ix_service_applications_service_id", service_id),
        Index("ix_service_applications_applicant_id", applicant_id),
        Index("ix_service_applications_expert_id", expert_id),
        Index("ix_service_applications_status", status),
        Index("ix_service_applications_task_id", task_id),
        # 注意：部分唯一索引需要在数据库层面通过SQL创建
        # CREATE UNIQUE INDEX uq_service_app_pending_combo ON service_applications (service_id, applicant_id, status) WHERE status IN ('pending', 'negotiating', 'price_agreed');
    )


class FleaMarketItem(Base):
    """跳蚤市场商品表"""
    __tablename__ = "flea_market_items"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=False)
    price = Column(DECIMAL(12, 2), nullable=False)
    currency = Column(String(3), nullable=False, default="GBP")
    images = Column(Text, nullable=True)  # JSON数组存储图片URL列表
    location = Column(String(100), nullable=True)  # 线下交易地点或"Online"
    category = Column(String(100), nullable=True)
    contact = Column(String(200), nullable=True)  # 预留字段，本期不使用
    status = Column(String(20), nullable=False, default="active")
    seller_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)  # 卖家ID
    sold_task_id = Column(Integer, ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True)  # 售出后关联的任务ID
    view_count = Column(Integer, nullable=False, default=0)  # 浏览量
    refreshed_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())  # 刷新时间
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 关系
    seller = relationship("User", backref="flea_market_items")  # 卖家关系
    
    __table_args__ = (
        Index("idx_flea_market_items_seller_id", seller_id),
        Index("idx_flea_market_items_status", status),
        Index("idx_flea_market_items_category", category),
        Index("idx_flea_market_items_created_at", created_at),
        Index("idx_flea_market_items_price", price),
        Index("idx_flea_market_items_refreshed_at", refreshed_at),  # 用于自动删除查询
        Index("idx_flea_market_items_view_count", view_count),  # 用于按浏览量排序
        CheckConstraint("price >= 0", name="check_price_positive"),
        CheckConstraint("currency = 'GBP'", name="check_currency_gbp"),
        CheckConstraint("status IN ('active', 'sold', 'deleted')", name="check_status_valid"),
    )


class FleaMarketFavorite(Base):
    """跳蚤市场商品收藏模型"""
    __tablename__ = "flea_market_favorites"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    item_id = Column(Integer, ForeignKey("flea_market_items.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    
    # 关系
    user = relationship("User", backref="flea_market_favorites")
    item = relationship("FleaMarketItem", backref="favorites")
    
    # 索引和约束
    __table_args__ = (
        UniqueConstraint("user_id", "item_id", name="uix_user_item_favorite"),
        Index("idx_flea_market_favorites_user_id", user_id),
        Index("idx_flea_market_favorites_item_id", item_id),
        Index("idx_flea_market_favorites_created_at", created_at),
    )


class FleaMarketReport(Base):
    """跳蚤市场商品举报模型"""
    __tablename__ = "flea_market_reports"
    
    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("flea_market_items.id", ondelete="CASCADE"), nullable=False)
    reporter_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    reason = Column(String(100), nullable=False)  # spam, fraud, inappropriate, other
    description = Column(Text, nullable=True)
    status = Column(String(20), nullable=False, default="pending")  # pending, reviewing, resolved, rejected
    admin_comment = Column(Text, nullable=True)
    handled_by = Column(String(5), ForeignKey("admin_users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time)
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time)
    handled_at = Column(DateTime(timezone=True), nullable=True)
    
    # 关系
    item = relationship("FleaMarketItem", backref="reports")
    reporter = relationship("User", backref="flea_market_reports")
    handler = relationship("AdminUser", backref="flea_market_reports_handled")
    
    # 索引和约束
    __table_args__ = (
        Index("idx_flea_market_reports_item_id", item_id),
        Index("idx_flea_market_reports_reporter_id", reporter_id),
        Index("idx_flea_market_reports_status", status),
        Index("idx_flea_market_reports_created_at", created_at),
    )


class FleaMarketPurchaseRequest(Base):
    """跳蚤市场购买申请表"""
    __tablename__ = "flea_market_purchase_requests"
    
    id = Column(Integer, primary_key=True, index=True)
    item_id = Column(Integer, ForeignKey("flea_market_items.id", ondelete="CASCADE"), nullable=False)
    buyer_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    proposed_price = Column(DECIMAL(12, 2), nullable=True)  # 议价金额（如果买家议价）
    seller_counter_price = Column(DECIMAL(12, 2), nullable=True)  # 卖家议价金额
    message = Column(Text, nullable=True)  # 购买留言
    status = Column(String(20), nullable=False, default="pending")
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 关系
    item = relationship("FleaMarketItem", backref="purchase_requests")  # 商品关系
    buyer = relationship("User", backref="flea_market_purchase_requests")  # 买家关系
    
    __table_args__ = (
        Index("idx_flea_market_purchase_requests_item_id", item_id),
        Index("idx_flea_market_purchase_requests_buyer_id", buyer_id),
        Index("idx_flea_market_purchase_requests_status", status),
        Index("idx_flea_market_purchase_requests_created_at", created_at),
        CheckConstraint("status IN ('pending', 'seller_negotiating', 'accepted', 'rejected')", name="check_status_valid"),
    )


# ===========================================
# 多人任务相关模型
# ===========================================

class TaskParticipant(Base):
    """任务参与者表"""
    __tablename__ = "task_participants"
    
    id = Column(BigInteger, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    # 冗余字段：关联的活动ID（从任务的parent_activity_id获取，用于性能优化）
    activity_id = Column(Integer, ForeignKey("activities.id", ondelete="SET NULL"), nullable=True)
    status = Column(String(20), default="pending", nullable=False)
    previous_status = Column(String(20), nullable=True)
    time_slot_id = Column(Integer, nullable=True)
    preferred_deadline = Column(DateTime(timezone=True), nullable=True)
    is_flexible_time = Column(Boolean, default=False, nullable=False)
    # 性能优化字段（冗余字段）
    is_expert_task = Column(Boolean, default=False, nullable=False)
    is_official_task = Column(Boolean, default=False, nullable=False)
    expert_creator_id = Column(String(8), nullable=True)
    planned_reward_amount = Column(DECIMAL(12, 2), nullable=True)
    planned_points_reward = Column(BigInteger, default=0, nullable=False)
    applied_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    accepted_at = Column(DateTime(timezone=True), nullable=True)
    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    exit_requested_at = Column(DateTime(timezone=True), nullable=True)
    exit_reason = Column(Text, nullable=True)
    exited_at = Column(DateTime(timezone=True), nullable=True)
    cancelled_at = Column(DateTime(timezone=True), nullable=True)
    completion_notes = Column(Text, nullable=True)
    admin_notes = Column(Text, nullable=True)
    idempotency_key = Column(String(64), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 关系
    task = relationship("Task", back_populates="participants")
    user = relationship("User")
    rewards = relationship("TaskParticipantReward", back_populates="participant", cascade="all, delete-orphan")
    
    __table_args__ = (
        UniqueConstraint("task_id", "user_id", name="uq_task_participant"),
        CheckConstraint(
            "status IN ('pending', 'accepted', 'in_progress', 'completed', 'exit_requested', 'exited', 'cancelled')",
            name="chk_participant_status"
        ),
    )


class TaskParticipantReward(Base):
    """任务参与者奖励表"""
    __tablename__ = "task_participant_rewards"
    
    id = Column(BigInteger, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    participant_id = Column(BigInteger, ForeignKey("task_participants.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    reward_type = Column(String(20), default="cash", nullable=False)
    reward_amount = Column(DECIMAL(12, 2), nullable=True)
    points_amount = Column(BigInteger, nullable=True)
    currency = Column(String(3), default="GBP", nullable=False)
    payment_status = Column(String(20), default="pending", nullable=False)
    points_status = Column(String(20), default="pending", nullable=False)
    paid_at = Column(DateTime(timezone=True), nullable=True)
    points_credited_at = Column(DateTime(timezone=True), nullable=True)
    payment_method = Column(String(50), nullable=True)
    payment_reference = Column(String(100), nullable=True)
    idempotency_key = Column(String(64), nullable=True)
    external_txn_id = Column(String(100), nullable=True)
    reversal_reference = Column(String(100), nullable=True)
    admin_operator_id = Column(String(36), ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True)
    expert_operator_id = Column(String(8), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 关系
    task = relationship("Task", back_populates="participant_rewards")
    participant = relationship("TaskParticipant", back_populates="rewards")
    user = relationship("User", foreign_keys=[user_id])  # 明确指定使用 user_id 外键
    expert_operator = relationship("User", foreign_keys=[expert_operator_id])  # 操作的任务达人
    
    __table_args__ = (
        UniqueConstraint("external_txn_id", name="uq_reward_external_txn"),
        CheckConstraint(
            "payment_status IN ('pending', 'paid', 'failed', 'refunded')",
            name="chk_reward_payment_status"
        ),
        CheckConstraint(
            "points_status IN ('pending', 'credited', 'failed', 'refunded')",
            name="chk_reward_points_status"
        ),
        CheckConstraint(
            "reward_type IN ('cash', 'points', 'both')",
            name="chk_reward_type_values"
        ),
    )


class TaskTimeSlotRelation(Base):
    """活动与时间段的关联表"""
    __tablename__ = "task_time_slot_relations"
    
    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    time_slot_id = Column(Integer, ForeignKey("service_time_slots.id", ondelete="CASCADE"), nullable=True)
    # 关联模式：'fixed' = 固定时间段，'recurring' = 重复模式
    relation_mode = Column(String(20), nullable=False, default='fixed')
    # 重复规则（JSON格式，仅用于recurring模式）
    recurring_rule = Column(JSONB, nullable=True)
    # 是否自动添加新匹配的时间段
    auto_add_new_slots = Column(Boolean, default=True, nullable=False)
    # 活动截至日期（可选，如果设置则在此时活动自动结束）
    activity_end_date = Column(Date, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 关系
    task = relationship("Task", backref="time_slot_relations")
    time_slot = relationship("ServiceTimeSlot", backref="task_relations")
    
    __table_args__ = (
        Index("ix_task_time_slot_relations_task_id", task_id),
        Index("ix_task_time_slot_relations_time_slot_id", time_slot_id),
        Index("ix_task_time_slot_relations_mode", relation_mode),
        Index("ix_task_time_slot_relations_end_date", activity_end_date),
        # 注意：部分唯一索引（一个时间段只能被一个活动使用）在数据库迁移中创建
        # 约束：固定模式必须有time_slot_id，重复模式必须有recurring_rule
        CheckConstraint(
            "(relation_mode = 'fixed' AND time_slot_id IS NOT NULL) OR (relation_mode = 'recurring' AND recurring_rule IS NOT NULL)",
            name="chk_relation_mode"
        ),
    )


class Activity(Base):
    """活动表 - 存储任务达人发布的多人活动"""
    __tablename__ = "activities"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=False)
    expert_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    expert_service_id = Column(Integer, ForeignKey("task_expert_services.id", ondelete="RESTRICT"), nullable=False)
    location = Column(String(100), nullable=False)
    task_type = Column(String(50), nullable=False)
    # 价格相关
    reward_type = Column(String(20), nullable=False, default='cash')  # cash, points, both
    original_price_per_participant = Column(DECIMAL(12, 2), nullable=True)
    discount_percentage = Column(DECIMAL(5, 2), nullable=True)
    discounted_price_per_participant = Column(DECIMAL(12, 2), nullable=True)
    currency = Column(String(3), default="GBP")
    points_reward = Column(BigInteger, nullable=True)
    # 参与者相关
    max_participants = Column(Integer, nullable=False, default=1)
    min_participants = Column(Integer, nullable=False, default=1)
    completion_rule = Column(String(20), nullable=False, default='all')  # all, min
    reward_distribution = Column(String(20), nullable=False, default='equal')  # equal, custom
    # 活动状态
    status = Column(String(20), nullable=False, default='open')  # open, closed, cancelled, completed
    is_public = Column(Boolean, default=True, nullable=False)
    visibility = Column(String(20), default="public")  # public, private
    # 截止日期（非时间段服务使用）
    deadline = Column(DateTime(timezone=True), nullable=True)
    # 活动截至日期（时间段服务使用，可选）
    activity_end_date = Column(Date, nullable=True)
    # 图片
    images = Column(JSONB, nullable=True)
    # 时间段相关（如果关联时间段服务）
    has_time_slots = Column(Boolean, default=False, nullable=False)
    # 创建时间
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 关系
    expert = relationship("User", foreign_keys=[expert_id])
    service = relationship("TaskExpertService", back_populates="activities")
    time_slot_relations = relationship("ActivityTimeSlotRelation", back_populates="activity", cascade="all, delete-orphan")
    created_tasks = relationship("Task", back_populates="parent_activity", foreign_keys="Task.parent_activity_id")
    
    __table_args__ = (
        Index("ix_activities_expert_id", expert_id),
        Index("ix_activities_expert_service_id", expert_service_id),
        Index("ix_activities_status", status),
        Index("ix_activities_deadline", deadline),
        Index("ix_activities_activity_end_date", activity_end_date),
        Index("ix_activities_has_time_slots", has_time_slots),
        CheckConstraint(
            "status IN ('open', 'closed', 'cancelled', 'completed')",
            name="chk_activity_status"
        ),
        CheckConstraint(
            "reward_type IN ('cash', 'points', 'both')",
            name="chk_activity_reward_type"
        ),
        CheckConstraint(
            "completion_rule IN ('all', 'min')",
            name="chk_activity_completion_rule"
        ),
        CheckConstraint(
            "reward_distribution IN ('equal', 'custom')",
            name="chk_activity_reward_distribution"
        ),
        CheckConstraint(
            "min_participants > 0 AND max_participants >= min_participants",
            name="chk_activity_participants"
        ),
    )


class ActivityTimeSlotRelation(Base):
    """活动与时间段的关联表"""
    __tablename__ = "activity_time_slot_relations"
    
    id = Column(Integer, primary_key=True, index=True)
    activity_id = Column(Integer, ForeignKey("activities.id", ondelete="CASCADE"), nullable=False)
    time_slot_id = Column(Integer, ForeignKey("service_time_slots.id", ondelete="CASCADE"), nullable=True)
    # 关联模式：'fixed' = 固定时间段，'recurring' = 重复模式
    relation_mode = Column(String(20), nullable=False, default='fixed')
    # 重复规则（JSON格式，仅用于recurring模式）
    recurring_rule = Column(JSONB, nullable=True)
    # 是否自动添加新匹配的时间段
    auto_add_new_slots = Column(Boolean, default=True, nullable=False)
    # 活动截至日期（可选，如果设置则在此时活动自动结束）
    activity_end_date = Column(Date, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())
    
    # 关系
    activity = relationship("Activity", back_populates="time_slot_relations")
    time_slot = relationship("ServiceTimeSlot", backref="activity_relations")
    
    __table_args__ = (
        Index("ix_activity_time_slot_relations_activity_id", activity_id),
        Index("ix_activity_time_slot_relations_time_slot_id", time_slot_id),
        Index("ix_activity_time_slot_relations_mode", relation_mode),
        Index("ix_activity_time_slot_relations_end_date", activity_end_date),
        # 约束：固定模式必须有time_slot_id，重复模式必须有recurring_rule
        CheckConstraint(
            "(relation_mode = 'fixed' AND time_slot_id IS NOT NULL) OR (relation_mode = 'recurring' AND recurring_rule IS NOT NULL)",
            name="chk_activity_relation_mode"
        ),
    )


class TaskAuditLog(Base):
    """任务审计日志表"""
    __tablename__ = "task_audit_logs"
    
    id = Column(BigInteger, primary_key=True, index=True)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    participant_id = Column(BigInteger, ForeignKey("task_participants.id", ondelete="CASCADE"), nullable=True)
    action_type = Column(String(50), nullable=False)
    action_description = Column(Text, nullable=True)
    admin_id = Column(String(36), ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    old_status = Column(String(20), nullable=True)
    new_status = Column(String(20), nullable=True)
    audit_metadata = Column(JSONB, nullable=True)  # 使用 audit_metadata 避免与 SQLAlchemy 的 metadata 属性冲突
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    
    # 关系
    task = relationship("Task", back_populates="audit_logs")
    participant = relationship("TaskParticipant")
    
    __table_args__ = (
        CheckConstraint(
            "(user_id IS NOT NULL) OR (admin_id IS NOT NULL)",
            name="chk_audit_user_or_admin"
        ),
    )