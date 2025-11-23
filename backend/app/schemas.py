import datetime
from typing import List, Literal, Optional, Dict, Any
from decimal import Decimal

from pydantic import BaseModel, Field, validator, model_validator
from pydantic import condecimal


class UserBase(BaseModel):
    name: str
    email: Optional[str] = None  # 邮箱可为空（手机号登录时为空）
    phone: Optional[str] = None  # 手机号可为空（邮箱登录时为空）
    avatar: Optional[str] = ""


class UserCreate(UserBase):
    password: str = Field(..., min_length=6)
    avatar: Optional[str] = ""
    agreed_to_terms: Optional[bool] = False
    terms_agreed_at: Optional[str] = None
    invitation_code: Optional[str] = None  # 邀请码（注册时使用）


class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    avatar: Optional[str] = None
    user_level: Optional[str] = None
    timezone: Optional[str] = None


class UserLogin(BaseModel):
    email: str
    password: str

class EmailVerificationCodeRequest(BaseModel):
    """请求发送邮箱验证码"""
    email: str

class EmailVerificationCodeLogin(BaseModel):
    """使用邮箱验证码登录"""
    email: str
    verification_code: str

class PhoneVerificationCodeRequest(BaseModel):
    """请求发送手机验证码"""
    phone: str

class PhoneVerificationCodeLogin(BaseModel):
    """使用手机号验证码登录"""
    phone: str
    verification_code: str

class UpdateEmailRequest(BaseModel):
    """请求发送邮箱修改验证码"""
    new_email: str

class UpdateEmailVerify(BaseModel):
    """验证邮箱修改验证码"""
    new_email: str
    verification_code: str

class UpdatePhoneRequest(BaseModel):
    """请求发送手机号修改验证码"""
    new_phone: str

class UpdatePhoneVerify(BaseModel):
    """验证手机号修改验证码"""
    new_phone: str
    verification_code: str

class PasswordValidationRequest(BaseModel):
    password: str
    username: Optional[str] = None
    email: Optional[str] = None


class PasswordChange(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=6)


# 客服相关Schema
class CustomerServiceLogin(BaseModel):
    email: str
    password: str


class CustomerServiceCreate(BaseModel):
    name: str
    email: str
    password: str = Field(..., min_length=6)


class CustomerServiceUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    is_active: Optional[bool] = None


class CustomerServiceOut(BaseModel):
    id: str
    name: str
    email: str
    is_active: bool
    created_at: datetime.datetime
    last_login: Optional[datetime.datetime] = None


# 管理员相关Schema
class AdminLogin(BaseModel):
    username_or_id: str
    password: str


class AdminCreate(BaseModel):
    id: str
    name: str
    username: str
    email: str
    password: str = Field(..., min_length=6)
    is_active: bool = True
    is_super_admin: bool = False


class AdminUpdate(BaseModel):
    name: Optional[str] = None
    username: Optional[str] = None
    email: Optional[str] = None
    is_active: Optional[bool] = None
    is_super_admin: Optional[bool] = None


class AdminOut(BaseModel):
    id: str
    name: str
    username: str
    email: str
    is_active: bool
    is_super_admin: bool
    created_at: datetime.datetime
    last_login: Optional[datetime.datetime] = None


class AdminVerificationRequest(BaseModel):
    admin_id: str
    code: str = Field(..., min_length=6, max_length=6, description="6位数字验证码")

# 独立认证系统相关Schema
class AdminUserLoginNew(BaseModel):
    username_or_id: str
    password: str

class AdminLoginResponse(BaseModel):
    message: str
    admin: dict
    session_id: str

class AdminProfileResponse(BaseModel):
    id: str
    name: str
    username: str
    email: str
    is_super_admin: bool
    is_active: bool
    created_at: str
    last_login: Optional[str] = None

class AdminChangePassword(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=6)

class ServiceLoginResponse(BaseModel):
    message: str
    service: dict
    session_id: str

class ServiceProfileResponse(BaseModel):
    id: str
    name: str
    email: str
    avg_rating: float
    total_ratings: int
    is_online: bool
    created_at: Optional[str] = None

class ServiceChangePassword(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=6)

class UserProfileResponse(BaseModel):
    id: str
    name: str
    email: str
    phone: Optional[str] = None
    is_verified: bool
    is_suspended: bool
    is_banned: bool
    created_at: str
    last_login: Optional[str] = None


class UserOut(UserBase):
    id: str  # 现在ID是字符串类型
    created_at: datetime.datetime
    user_level: Optional[str] = "normal"
    is_admin: Optional[int] = 0
    is_verified: Optional[int] = 0
    is_active: Optional[int] = 1
    is_banned: Optional[int] = 0
    is_suspended: Optional[int] = 0
    is_customer_service: Optional[int] = 0
    task_count: Optional[int] = 0
    completed_task_count: Optional[int] = 0
    avg_rating: Optional[float] = 0.0
    timezone: Optional[str] = "UTC"
    user_type: Optional[str] = "normal_user"  # 添加用户类型字段
    residence_city: Optional[str] = None  # 常住城市
    language_preference: Optional[str] = "en"  # 语言偏好
    name_updated_at: Optional[datetime.date] = None  # 上次修改名字的时间

    class Config:
        from_attributes = True


QS_TOP100_CITIES = [
    "Online",
    "London",
    "Edinburgh",
    "Manchester",
    "Birmingham",
    "Glasgow",
    "Bristol",
    "Sheffield",
    "Leeds",
    "Nottingham",
    "Newcastle",
    "Southampton",
    "Liverpool",
    "Cardiff",
    "Coventry",
    "Exeter",
    "Leicester",
    "York",
    "Aberdeen",
    "Bath",
    "Dundee",
    "Reading",
    "St Andrews",
    "Belfast",
    "Brighton",
    "Durham",
    "Norwich",
    "Swansea",
    "Loughborough",
    "Lancaster",
    "Warwick",
    "Cambridge",
    "Oxford",
    "Other",
]
TASK_TYPES = [
    "Housekeeping",
    "Campus Life",
    "Second-hand & Rental",
    "Errand Running",
    "Skill Service",
    "Social Help",
    "Transportation",
    "Pet Care",
    "Life Convenience",
    "Other",
]


class TaskBase(BaseModel):
    title: str
    description: str
    deadline: Optional[datetime.datetime] = None  # 允许为 NULL，支持灵活模式任务
    is_flexible: Optional[int] = 0  # 是否灵活时间（1=灵活，无截止日期；0=有截止日期）
    reward: float
    base_reward: Optional[float] = None  # 原始标价
    agreed_reward: Optional[float] = None  # 最终成交价
    currency: Optional[str] = "GBP"  # 货币类型
    location: str  # Frontend should use QS_TOP100_CITIES options
    task_type: str  # Frontend should use TASK_TYPES options


class TaskCreate(TaskBase):
    is_public: Optional[int] = 1  # 1=public, 0=private (仅自己可见)
    images: Optional[List[str]] = None  # 图片URL列表


class TaskOut(TaskBase):
    id: int
    poster_id: str  # 现在ID是字符串类型
    taker_id: Optional[str]  # 现在ID是字符串类型
    status: str
    task_level: str = "normal"  # normal, vip, super, expert（达人任务）
    created_at: datetime.datetime
    is_public: Optional[int] = 1  # 1=public, 0=private (仅自己可见)
    images: Optional[List[str]] = None  # 图片URL列表
    points_reward: Optional[int] = None  # 任务完成奖励积分（可选，如果设置则覆盖系统默认值）
    is_flexible: Optional[int] = 0  # 是否灵活时间（1=灵活，无截止日期；0=有截止日期）
    # 多人任务相关字段
    is_multi_participant: Optional[bool] = False
    expert_creator_id: Optional[str] = None
    # 时间段相关字段（如果任务有固定时间段）
    time_slot_start_time: Optional[str] = None  # 时间格式：HH:MM:SS
    time_slot_end_time: Optional[str] = None  # 时间格式：HH:MM:SS

    @validator('images', pre=True)
    def parse_images(cls, v):
        """将JSON字符串解析为列表"""
        if v is None:
            return None
        if isinstance(v, str):
            import json
            try:
                return json.loads(v)
            except (json.JSONDecodeError, TypeError):
                return []
        if isinstance(v, list):
            return v
        return None

    @model_validator(mode='after')
    def set_reward_from_agreed_or_base(self):
        """设置reward字段：优先使用agreed_reward，否则使用base_reward"""
        # 优先使用agreed_reward
        if self.agreed_reward is not None:
            self.reward = float(self.agreed_reward)
        # 否则使用base_reward
        elif self.base_reward is not None:
            self.reward = float(self.base_reward)
        # 如果都没有，保持原有的reward值或设为0.0
        elif self.reward is None:
            self.reward = 0.0
        else:
            self.reward = float(self.reward)
        return self
    
    @classmethod
    def from_orm(cls, obj):
        """自定义ORM转换，处理时间字段"""
        from datetime import time
        data = {
            "id": obj.id,
            "poster_id": obj.poster_id,
            "taker_id": obj.taker_id,
            "status": obj.status,
            "task_level": obj.task_level,
            "created_at": obj.created_at,
            "is_public": obj.is_public,
            "images": obj.images,
            "points_reward": obj.points_reward,
            "is_flexible": obj.is_flexible,
            "title": obj.title,
            "description": obj.description,
            "deadline": obj.deadline,
            "reward": float(obj.reward) if obj.reward else 0.0,
            "base_reward": float(obj.base_reward) if obj.base_reward else None,
            "agreed_reward": float(obj.agreed_reward) if obj.agreed_reward else None,
            "currency": obj.currency,
            "location": obj.location,
            "task_type": obj.task_type,
            "is_multi_participant": getattr(obj, 'is_multi_participant', False),
            "expert_creator_id": getattr(obj, 'expert_creator_id', None),
            "time_slot_start_time": obj.time_slot_start_time.isoformat() if hasattr(obj, 'time_slot_start_time') and isinstance(obj.time_slot_start_time, time) else (str(obj.time_slot_start_time) if hasattr(obj, 'time_slot_start_time') and obj.time_slot_start_time else None),
            "time_slot_end_time": obj.time_slot_end_time.isoformat() if hasattr(obj, 'time_slot_end_time') and isinstance(obj.time_slot_end_time, time) else (str(obj.time_slot_end_time) if hasattr(obj, 'time_slot_end_time') and obj.time_slot_end_time else None),
        }
        return cls(**data)

    class Config:
        from_attributes = True
        # 排除关系字段，避免序列化问题
        exclude = {"poster", "taker", "reviews"}


class TaskUpdate(BaseModel):
    reward: float = Field(..., gt=0)  # 价格必须大于0


class ReviewBase(BaseModel):
    rating: float
    comment: Optional[str] = None
    is_anonymous: bool = False  # 是否匿名评价


class ReviewCreate(ReviewBase):
    pass


class ReviewOut(ReviewBase):
    id: int
    task_id: int
    user_id: str  # 现在ID是字符串类型
    created_at: datetime.datetime

    class Config:
        from_attributes = True


class ReviewWithReviewerInfo(ReviewBase):
    id: int
    task_id: int
    user_id: str  # 现在ID是字符串类型
    created_at: datetime.datetime
    reviewer_name: str  # 评价者用户名
    reviewer_avatar: str  # 评价者头像
    task_title: str  # 任务标题

    class Config:
        from_attributes = True


class MessageBase(BaseModel):
    content: str
    receiver_id: str  # 现在ID是字符串类型


class MessageCreate(MessageBase):
    pass


class MessageOut(MessageBase):
    id: int
    sender_id: str  # 现在ID是字符串类型
    created_at: datetime.datetime
    is_read: int

    class Config:
        from_attributes = True


class NotificationBase(BaseModel):
    type: str
    title: str
    content: str
    related_id: Optional[int] = None


class NotificationCreate(NotificationBase):
    pass


class NotificationOut(NotificationBase):
    id: int
    user_id: str  # 现在ID是字符串类型
    is_read: int
    created_at: datetime.datetime

    class Config:
        from_attributes = True


class TaskCancelRequestBase(BaseModel):
    reason: Optional[str] = None


class TaskCancelRequestCreate(TaskCancelRequestBase):
    pass


class TaskCancelRequestOut(TaskCancelRequestBase):
    id: int
    task_id: int
    requester_id: int
    status: str
    admin_id: Optional[int] = None
    admin_comment: Optional[str] = None
    created_at: datetime.datetime
    reviewed_at: Optional[datetime.datetime] = None

    class Config:
        from_attributes = True


class TaskCancelRequestReview(BaseModel):
    status: str  # approved, rejected
    admin_comment: Optional[str] = None
    
    @validator('status')
    def validate_status(cls, v):
        if v not in ['approved', 'rejected']:
            raise ValueError('status must be either "approved" or "rejected"')
        return v


class TaskCancelRequest(BaseModel):
    reason: Optional[str] = None


# 客服评分相关schemas
class CustomerServiceRating(BaseModel):
    rating: float = Field(..., ge=1, le=5)  # 评分1-5分
    comment: Optional[str] = None


# 管理后台相关schemas
class AdminUserUpdate(BaseModel):
    user_level: Optional[str] = None
    is_active: Optional[int] = None
    is_banned: Optional[int] = None
    is_suspended: Optional[int] = None
    suspend_until: Optional[datetime.datetime] = None


class AdminCustomerServiceCreate(BaseModel):
    name: str
    email: str
    password: str = Field(..., min_length=6)


class AdminCustomerServiceUpdate(BaseModel):
    name: Optional[str] = None
    is_online: Optional[int] = None


class AdminNotificationCreate(BaseModel):
    user_ids: List[str]  # 目标用户ID列表，空列表表示发送给所有用户
    title: str
    content: str
    type: str = "admin_notification"


class AdminTaskUpdate(BaseModel):
    task_level: Optional[str] = None
    status: Optional[str] = None
    is_public: Optional[int] = None
    task_type: Optional[str] = None  # 任务类型
    location: Optional[str] = None  # 工作地点
    title: Optional[str] = None  # 任务标题
    description: Optional[str] = None  # 任务描述
    reward: Optional[float] = None  # 赏金
    deadline: Optional[datetime.datetime] = None  # 截止时间
    images: Optional[List[str]] = None  # 图片URL列表（会被序列化为JSON字符串存储）


class AdminDashboardStats(BaseModel):
    total_users: int
    total_tasks: int
    total_customer_service: int
    active_sessions: int
    total_revenue: float
    avg_rating: float


class AdminUserList(BaseModel):
    users: List[UserOut]
    total: int
    page: int
    size: int


class AdminCustomerServiceList(BaseModel):
    customer_services: List[dict]  # 包含客服信息的列表
    total: int
    page: int
    size: int


# 客服登录相关schemas
class CustomerServiceLogin(BaseModel):
    cs_id: str
    password: str


class CustomerServiceOut(BaseModel):
    id: str
    name: str
    email: str
    is_online: int
    avg_rating: float
    total_ratings: int
    created_at: datetime.datetime

    class Config:
        from_attributes = True


class CustomerServiceCreate(BaseModel):
    id: str
    name: str
    email: str
    password: str = Field(..., min_length=6)


# 后台管理员相关schemas
class AdminUserLogin(BaseModel):
    username: str
    password: str


class AdminUserOut(BaseModel):
    id: int
    name: str
    username: str
    email: str
    is_active: int
    is_super_admin: int
    created_at: datetime.datetime
    last_login: Optional[datetime.datetime] = None

    class Config:
        from_attributes = True


class AdminUserCreate(BaseModel):
    name: str
    username: str
    email: str
    password: str = Field(..., min_length=6)
    is_super_admin: Optional[int] = 0


# 管理请求相关schemas
class AdminRequestCreate(BaseModel):
    type: str
    title: str
    description: str
    priority: str = "medium"


class AdminRequestOut(BaseModel):
    id: int
    requester_id: str
    type: str
    title: str
    description: str
    priority: str
    status: str
    admin_response: Optional[str] = None
    admin_id: Optional[str] = None
    created_at: datetime.datetime
    updated_at: Optional[datetime.datetime] = None

    class Config:
        from_attributes = True


class AdminChatMessageCreate(BaseModel):
    content: str


class AdminChatMessageOut(BaseModel):
    id: int
    sender_id: Optional[str] = None
    sender_type: str
    content: str
    created_at: datetime.datetime

    class Config:
        from_attributes = True


# 员工提醒相关schemas
class StaffNotificationCreate(BaseModel):
    recipient_id: str
    recipient_type: str  # customer_service, admin
    title: str
    content: str
    notification_type: str = "info"  # info, warning, error, success


class StaffNotificationOut(BaseModel):
    id: int
    recipient_id: str
    recipient_type: str
    sender_id: Optional[str] = None
    title: str
    content: str
    notification_type: str
    is_read: int
    created_at: datetime.datetime
    read_at: Optional[datetime.datetime] = None

    class Config:
        from_attributes = True


# 系统设置相关schemas
class SystemSettingsCreate(BaseModel):
    setting_key: str
    setting_value: str
    setting_type: str = "string"
    description: Optional[str] = None


class SystemSettingsUpdate(BaseModel):
    setting_value: str
    description: Optional[str] = None


class SystemSettingsOut(BaseModel):
    id: int
    setting_key: str
    setting_value: str
    setting_type: str
    description: Optional[str] = None
    created_at: datetime.datetime
    updated_at: datetime.datetime

    class Config:
        from_attributes = True


class SystemSettingsBulkUpdate(BaseModel):
    vip_enabled: bool = True
    super_vip_enabled: bool = True
    vip_task_threshold: int = 5
    super_vip_task_threshold: int = 20
    vip_price_threshold: float = 10.0
    super_vip_price_threshold: float = 50.0
    vip_button_visible: bool = True
    vip_auto_upgrade_enabled: bool = False
    vip_benefits_description: str = "优先任务推荐、专属客服服务、任务发布数量翻倍"
    super_vip_benefits_description: str = (
        "所有VIP功能、无限任务发布、专属高级客服、任务优先展示、专属会员标识"
    )

    # VIP晋升超级VIP的条件
    vip_to_super_task_count_threshold: int = 50  # 发布+接受任务总数阈值
    vip_to_super_rating_threshold: float = 4.5  # 平均评分阈值
    vip_to_super_completion_rate_threshold: float = 0.8  # 任务完成率阈值
    vip_to_super_enabled: bool = True  # 是否启用自动晋升


# 岗位相关Schema
class JobPositionBase(BaseModel):
    title: str = Field(..., max_length=100, description="岗位名称")
    title_en: Optional[str] = Field(None, max_length=100, description="岗位名称（英文）")
    department: str = Field(..., max_length=50, description="部门")
    department_en: Optional[str] = Field(None, max_length=50, description="部门（英文）")
    type: str = Field(..., max_length=20, description="工作类型")
    type_en: Optional[str] = Field(None, max_length=20, description="工作类型（英文）")
    location: str = Field(..., max_length=100, description="工作地点")
    location_en: Optional[str] = Field(None, max_length=100, description="工作地点（英文）")
    experience: str = Field(..., max_length=50, description="经验要求")
    experience_en: Optional[str] = Field(None, max_length=50, description="经验要求（英文）")
    salary: str = Field(..., max_length=50, description="薪资范围")
    salary_en: Optional[str] = Field(None, max_length=50, description="薪资范围（英文）")
    description: str = Field(..., description="岗位描述")
    description_en: Optional[str] = Field(None, description="岗位描述（英文）")
    requirements: List[str] = Field(..., description="任职要求")
    requirements_en: Optional[List[str]] = Field(None, description="任职要求（英文）")
    tags: Optional[List[str]] = Field(None, description="技能标签")
    tags_en: Optional[List[str]] = Field(None, description="技能标签（英文）")
    is_active: bool = Field(True, description="是否启用")


class JobPositionCreate(JobPositionBase):
    pass


class JobPositionUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=100)
    title_en: Optional[str] = Field(None, max_length=100)
    department: Optional[str] = Field(None, max_length=50)
    department_en: Optional[str] = Field(None, max_length=50)
    type: Optional[str] = Field(None, max_length=20)
    type_en: Optional[str] = Field(None, max_length=20)
    location: Optional[str] = Field(None, max_length=100)
    location_en: Optional[str] = Field(None, max_length=100)
    experience: Optional[str] = Field(None, max_length=50)
    experience_en: Optional[str] = Field(None, max_length=50)
    salary: Optional[str] = Field(None, max_length=50)
    salary_en: Optional[str] = Field(None, max_length=50)
    description: Optional[str] = None
    description_en: Optional[str] = None
    requirements: Optional[List[str]] = None
    requirements_en: Optional[List[str]] = None
    tags: Optional[List[str]] = None
    tags_en: Optional[List[str]] = None
    is_active: Optional[bool] = None


class JobPositionOut(JobPositionBase):
    id: int
    created_at: datetime.datetime
    updated_at: datetime.datetime
    created_by: str

    class Config:
        from_attributes = True


class JobPositionList(BaseModel):
    positions: List[JobPositionOut]
    total: int
    page: int
    size: int


# ==================== 优惠券和积分系统 Schemas ====================

# 积分相关 Schemas
class PointsAccountOut(BaseModel):
    balance: int  # 整数，积分数量
    balance_display: str  # 前端显示格式（£150.00）
    currency: str
    total_earned: int
    total_spent: int
    usage_restrictions: Dict[str, Any]

    class Config:
        from_attributes = True


class PointsTransactionOut(BaseModel):
    id: int
    type: str  # earn, spend, refund, expire
    amount: int  # 整数，积分数量
    amount_display: str  # 前端显示格式
    balance_after: int
    balance_after_display: str
    currency: str
    source: Optional[str]
    description: Optional[str]
    batch_id: Optional[str]
    created_at: datetime.datetime

    class Config:
        from_attributes = True


class PointsTransactionList(BaseModel):
    total: int
    page: int
    limit: int
    data: List[PointsTransactionOut]


class PointsRedeemCouponRequest(BaseModel):
    coupon_id: int
    idempotency_key: Optional[str] = None


class PointsRedeemProductRequest(BaseModel):
    product_sku: str
    idempotency_key: Optional[str] = None


# 优惠券相关 Schemas
class CouponUsageConditions(BaseModel):
    locations: Optional[List[str]] = None
    time_restrictions: Optional[Dict[str, Any]] = None
    task_types: Optional[List[str]] = None
    min_task_amount: Optional[int] = None
    max_task_amount: Optional[int] = None
    excluded_task_types: Optional[List[str]] = None


class CouponBase(BaseModel):
    code: str
    name: str
    description: Optional[str] = None
    type: str  # fixed_amount, percentage
    discount_value: int  # 整数，最小货币单位
    min_amount: int = 0
    max_discount: Optional[int] = None
    currency: str = "GBP"
    total_quantity: Optional[int] = None
    per_user_limit: int = 1
    can_combine: bool = False
    combine_limit: int = 1
    apply_order: int = 0
    valid_from: datetime.datetime
    valid_until: datetime.datetime
    usage_conditions: Optional[Dict[str, Any]] = None
    eligibility_type: Optional[str] = None
    eligibility_value: Optional[str] = None


class CouponCreate(CouponBase):
    pass


class CouponUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    valid_until: Optional[datetime.datetime] = None
    status: Optional[str] = None
    usage_conditions: Optional[Dict[str, Any]] = None


class CouponOut(BaseModel):
    id: int
    code: str
    name: str
    type: str
    discount_value: int
    discount_value_display: str
    min_amount: int
    min_amount_display: str
    currency: str
    valid_until: datetime.datetime
    usage_conditions: Optional[Dict[str, Any]] = None

    class Config:
        from_attributes = True


class CouponList(BaseModel):
    data: List[CouponOut]


class UserCouponOut(BaseModel):
    id: int
    coupon: CouponOut
    status: str
    obtained_at: datetime.datetime
    valid_until: datetime.datetime

    class Config:
        from_attributes = True


class UserCouponList(BaseModel):
    data: List[UserCouponOut]


class CouponClaimRequest(BaseModel):
    coupon_id: Optional[int] = None
    promotion_code: Optional[str] = None
    idempotency_key: Optional[str] = None


class CouponValidateRequest(BaseModel):
    coupon_code: str
    order_amount: int  # 整数，最小货币单位
    task_location: Optional[str] = None
    task_type: Optional[str] = None
    task_date: Optional[datetime.datetime] = None


class CouponValidateResponse(BaseModel):
    valid: bool
    discount_amount: int
    discount_amount_display: str
    final_amount: int
    final_amount_display: str
    currency: str
    coupon_id: int
    usage_conditions: Optional[Dict[str, Any]] = None


class CouponUseRequest(BaseModel):
    user_coupon_id: int
    task_id: int
    order_amount: int
    task_location: Optional[str] = None
    task_type: Optional[str] = None
    task_date: Optional[datetime.datetime] = None
    idempotency_key: Optional[str] = None


class CouponUseResponse(BaseModel):
    discount_amount: int
    discount_amount_display: str
    final_amount: int
    final_amount_display: str
    currency: str
    usage_log_id: int
    message: str


# 签到相关 Schemas
class CheckInResponse(BaseModel):
    success: bool
    check_in_date: datetime.date
    consecutive_days: int
    reward: Optional[Dict[str, Any]] = None
    message: str


class CheckInStatus(BaseModel):
    today_checked: bool
    consecutive_days: int
    last_check_in_date: Optional[datetime.date] = None
    next_check_in_date: Optional[datetime.date] = None
    check_in_history: List[Dict[str, Any]]


class CheckInRewardConfig(BaseModel):
    consecutive_days: int
    reward_type: str
    points_reward: Optional[int] = None
    points_reward_display: Optional[str] = None
    coupon_id: Optional[int] = None
    reward_description: Optional[str] = None
    is_active: Optional[bool] = True

    class Config:
        from_attributes = True


class CheckInRewardConfigUpdate(BaseModel):
    consecutive_days: Optional[int] = None
    reward_type: Optional[str] = None
    points_reward: Optional[int] = None
    coupon_id: Optional[int] = None
    reward_description: Optional[str] = None
    is_active: Optional[bool] = None


class CheckInRewardsResponse(BaseModel):
    rewards: List[CheckInRewardConfig]


# 邀请码相关 Schemas
class InvitationCodeValidateRequest(BaseModel):
    code: str


class InvitationCodeValidateResponse(BaseModel):
    valid: bool
    code: str
    name: Optional[str] = None
    reward_type: str
    points_reward: int
    points_reward_display: str
    coupon: Optional[Dict[str, Any]] = None
    message: str


# 管理员配置 Schemas
class PointsSettings(BaseModel):
    points_exchange_rate: float
    points_task_complete_bonus: int
    points_invite_reward: int
    points_invite_task_bonus: int
    points_expire_days: int


class PointsSettingsUpdate(PointsSettings):
    pass


class CheckInSettings(BaseModel):
    daily_base_points: int
    daily_base_points_display: str
    max_consecutive_days: int
    rewards: List[CheckInRewardConfig]


class CheckInSettingsUpdate(BaseModel):
    daily_base_points: Optional[int] = None
    max_consecutive_days: Optional[int] = None


class TaskPointsRewardUpdate(BaseModel):
    points_reward: Optional[int] = None  # 任务完成奖励积分（None表示使用系统默认值）


class CheckInRewardCreate(BaseModel):
    consecutive_days: int
    reward_type: str  # points, coupon
    points_reward: Optional[int] = None
    coupon_id: Optional[int] = None
    reward_description: str
    is_active: bool = True


class CheckInRewardUpdate(BaseModel):
    consecutive_days: Optional[int] = None
    reward_type: Optional[str] = None
    points_reward: Optional[int] = None
    coupon_id: Optional[int] = None
    reward_description: Optional[str] = None
    is_active: Optional[bool] = None


class CheckInRewardOut(CheckInRewardConfig):
    id: int
    is_active: bool
    created_at: datetime.datetime
    updated_at: datetime.datetime

    class Config:
        from_attributes = True


class CheckInRewardList(BaseModel):
    total: int
    page: int
    limit: int
    data: List[CheckInRewardOut]


# 管理员优惠券管理 Schemas
class CouponAdminOut(CouponOut):
    description: Optional[str] = None
    valid_from: datetime.datetime
    status: str
    total_quantity: Optional[int] = None
    used_quantity: Optional[int] = None
    usage_conditions: Optional[Dict[str, Any]] = None

    class Config:
        from_attributes = True


class CouponAdminList(BaseModel):
    total: int
    page: int
    limit: int
    data: List[CouponAdminOut]


class CouponAdminDetail(CouponAdminOut):
    statistics: Optional[Dict[str, Any]] = None

    class Config:
        from_attributes = True


# 邀请码管理 Schemas
class InvitationCodeCreate(BaseModel):
    code: str
    name: Optional[str] = None
    description: Optional[str] = None
    reward_type: str  # points, coupon, both
    points_reward: int = 0
    coupon_id: Optional[int] = None
    max_uses: Optional[int] = None
    valid_from: datetime.datetime
    valid_until: datetime.datetime
    is_active: bool = True


class InvitationCodeUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    is_active: Optional[bool] = None
    max_uses: Optional[int] = None
    valid_from: Optional[datetime.datetime] = None
    valid_until: Optional[datetime.datetime] = None
    points_reward: Optional[int] = None
    coupon_id: Optional[int] = None


class InvitationCodeOut(BaseModel):
    id: int
    code: str
    name: Optional[str] = None
    reward_type: str
    points_reward: int
    points_reward_display: str
    coupon_id: Optional[int] = None
    max_uses: Optional[int] = None
    used_count: Optional[int] = None
    valid_from: datetime.datetime
    valid_until: datetime.datetime
    is_active: bool
    created_by: Optional[str] = None
    created_at: datetime.datetime

    class Config:
        from_attributes = True


class InvitationCodeList(BaseModel):
    total: int
    page: int
    limit: int
    data: List[InvitationCodeOut]


class InvitationCodeDetail(InvitationCodeOut):
    description: Optional[str] = None
    coupon: Optional[Dict[str, Any]] = None
    remaining_uses: Optional[int] = None
    statistics: Optional[Dict[str, Any]] = None

    class Config:
        from_attributes = True


class InvitationCodeUserItem(BaseModel):
    user_id: str
    username: Optional[str] = None
    email: Optional[str] = None
    used_at: datetime.datetime
    reward_received: bool
    points_received: int
    points_received_display: str
    coupon_received: Optional[Dict[str, Any]] = None


class InvitationCodeUsersList(BaseModel):
    total: int
    page: int
    limit: int
    data: List[InvitationCodeUserItem]


class InvitationCodeStatistics(BaseModel):
    code: str
    total_users: int
    total_points_given: int
    total_points_given_display: str
    total_coupons_given: int
    usage_by_date: List[Dict[str, Any]]
    recent_users: List[Dict[str, Any]]


# 用户详情管理 Schemas
class UserDetailOut(BaseModel):
    user: Dict[str, Any]
    points_account: Dict[str, Any]
    coupons: Dict[str, Any]
    points_transactions: Dict[str, Any]
    check_in_stats: Dict[str, Any]
    invitation_usage: Optional[Dict[str, Any]] = None


class UserPointsAdjustRequest(BaseModel):
    action: str  # add, subtract, set
    amount: float  # 金额（£）
    description: str
    reason: str


class UserPointsAdjustResponse(BaseModel):
    success: bool
    user_id: str
    action: str
    amount: int
    amount_display: str
    balance_before: int
    balance_before_display: str
    balance_after: int
    balance_after_display: str
    transaction_id: int


# 批量发放 Schemas
class BatchRewardRequest(BaseModel):
    target_type: str  # user, user_type, all
    target_value: Optional[str] = None  # 用户类型或用户ID列表（JSON）
    amount: int  # 积分数量（整数）
    description: str
    is_async: bool = True  # 是否异步处理（async是Python保留字，使用is_async）


class BatchCouponRequest(BaseModel):
    target_type: str
    target_value: Optional[str] = None
    coupon_id: int
    description: str
    is_async: bool = False  # 是否异步处理（async是Python保留字，使用is_async）


class BatchRewardResponse(BaseModel):
    reward_id: int
    status: str
    estimated_users: Optional[int] = None
    total_users: Optional[int] = None
    success_count: Optional[int] = None
    failed_count: Optional[int] = None
    message: Optional[str] = None
    details: Optional[List[Dict[str, Any]]] = None


class BatchRewardDetail(BaseModel):
    id: int
    reward_type: str
    target_type: str
    target_value: Optional[str] = None
    points_value: Optional[int] = None
    points_value_display: Optional[str] = None
    total_users: int
    success_count: int
    failed_count: int
    status: str
    description: Optional[str] = None
    created_at: datetime.datetime
    completed_at: Optional[datetime.datetime] = None
    progress: Optional[float] = None
    failed_users: Optional[List[Dict[str, Any]]] = None

    class Config:
        from_attributes = True


class BatchRewardList(BaseModel):
    total: int
    page: int
    limit: int
    data: List[BatchRewardDetail]


# ==================== 任务支付相关 Schemas ====================

class TaskPaymentRequest(BaseModel):
    payment_method: str  # points, stripe, mixed
    points_amount: Optional[int] = None  # 积分数量（整数，最小货币单位）
    coupon_code: Optional[str] = None  # 优惠券代码
    user_coupon_id: Optional[int] = None  # 用户优惠券ID（如果使用优惠券）
    stripe_amount: Optional[int] = None  # Stripe支付金额（整数，最小货币单位）


class TaskPaymentResponse(BaseModel):
    payment_id: Optional[int] = None
    fee_type: str  # application_fee
    total_amount: int  # 平台服务费总额（整数，最小货币单位）
    total_amount_display: str
    points_used: Optional[int] = None
    points_used_display: Optional[str] = None
    coupon_discount: Optional[int] = None
    coupon_discount_display: Optional[str] = None
    stripe_amount: Optional[int] = None
    stripe_amount_display: Optional[str] = None
    currency: str
    final_amount: int  # 最终需要支付的金额（整数，最小货币单位）
    final_amount_display: str
    checkout_url: Optional[str] = None
    note: str


# ==================== 任务达人功能 Schema ====================

class TaskExpertApplicationCreate(BaseModel):
    application_message: Optional[str] = None


class TaskExpertApplicationOut(BaseModel):
    id: int
    user_id: str
    application_message: Optional[str]
    status: str
    reviewed_by: Optional[str]
    reviewed_at: Optional[datetime.datetime]
    review_comment: Optional[str]
    created_at: datetime.datetime
    
    class Config:
        from_attributes = True


class TaskExpertApplicationReview(BaseModel):
    """管理员审核申请请求"""
    action: Literal["approve", "reject"]
    review_comment: Optional[str] = None


class TaskExpertCreate(BaseModel):
    expert_name: Optional[str] = None
    bio: Optional[str] = None
    avatar: Optional[str] = None


class TaskExpertUpdate(BaseModel):
    expert_name: Optional[str] = None
    bio: Optional[str] = None
    avatar: Optional[str] = None


class TaskExpertProfileUpdateRequestCreate(BaseModel):
    """任务达人提交信息修改请求"""
    expert_name: Optional[str] = None
    bio: Optional[str] = None
    avatar: Optional[str] = None


class TaskExpertProfileUpdateRequestOut(BaseModel):
    """任务达人信息修改请求输出"""
    id: int
    expert_id: str
    new_expert_name: Optional[str]
    new_bio: Optional[str]
    new_avatar: Optional[str]
    status: str
    reviewed_by: Optional[str]
    reviewed_at: Optional[datetime.datetime]
    review_comment: Optional[str]
    created_at: datetime.datetime
    updated_at: datetime.datetime
    
    class Config:
        from_attributes = True


class TaskExpertProfileUpdateRequestReview(BaseModel):
    """管理员审核信息修改请求"""
    action: Literal["approve", "reject"]
    review_comment: Optional[str] = None


class TaskExpertOut(BaseModel):
    id: str
    expert_name: Optional[str]
    bio: Optional[str]
    avatar: Optional[str]
    status: str
    rating: float
    total_services: int
    completed_tasks: int
    created_at: datetime.datetime
    
    class Config:
        from_attributes = True


class TaskExpertServiceCreate(BaseModel):
    service_name: str
    description: str
    images: Optional[List[str]] = None
    base_price: condecimal(gt=0, max_digits=12, decimal_places=2)  # 使用condecimal与DB的DECIMAL一致
    currency: Literal["GBP"] = "GBP"  # 统一为Literal类型
    display_order: int = 0
    # 时间段相关字段
    has_time_slots: bool = False
    time_slot_duration_minutes: Optional[int] = None  # 每个时间段的时长（分钟）
    time_slot_start_time: Optional[str] = None  # 时间段开始时间（格式：HH:MM:SS，向后兼容）
    time_slot_end_time: Optional[str] = None  # 时间段结束时间（格式：HH:MM:SS，向后兼容）
    participants_per_slot: Optional[int] = None  # 每个时间段最多参与者数量
    weekly_time_slot_config: Optional[dict] = None  # 按周几设置时间段配置


class TaskExpertServiceUpdate(BaseModel):
    service_name: Optional[str] = None
    description: Optional[str] = None
    images: Optional[List[str]] = None
    base_price: Optional[condecimal(gt=0, max_digits=12, decimal_places=2)] = None  # 使用condecimal与DB的DECIMAL一致，避免精度丢失
    currency: Optional[Literal["GBP"]] = None  # 统一为Literal类型
    status: Optional[str] = None
    display_order: Optional[int] = None
    # 时间段相关字段
    has_time_slots: Optional[bool] = None
    time_slot_duration_minutes: Optional[int] = None
    time_slot_start_time: Optional[str] = None
    time_slot_end_time: Optional[str] = None
    participants_per_slot: Optional[int] = None
    weekly_time_slot_config: Optional[dict] = None  # 按周几设置时间段配置


class TaskExpertServiceOut(BaseModel):
    id: int
    expert_id: str
    service_name: str
    description: str
    images: Optional[List[str]]
    base_price: float
    currency: Literal["GBP"]  # 统一为Literal类型
    status: str
    display_order: int
    view_count: int
    application_count: int
    created_at: datetime.datetime
    # 时间段相关字段
    has_time_slots: bool = False
    time_slot_duration_minutes: Optional[int] = None
    time_slot_start_time: Optional[str] = None
    time_slot_end_time: Optional[str] = None
    participants_per_slot: Optional[int] = None
    
    @classmethod
    def from_orm(cls, obj):
        """自定义ORM转换，处理时间字段"""
        from datetime import time
        data = {
            "id": obj.id,
            "expert_id": obj.expert_id,
            "service_name": obj.service_name,
            "description": obj.description,
            "images": obj.images,
            "base_price": float(obj.base_price),
            "currency": obj.currency,
            "status": obj.status,
            "display_order": obj.display_order,
            "view_count": obj.view_count,
            "application_count": obj.application_count,
            "created_at": obj.created_at,
            "has_time_slots": obj.has_time_slots,
            "time_slot_duration_minutes": obj.time_slot_duration_minutes,
            "time_slot_start_time": obj.time_slot_start_time.isoformat() if isinstance(obj.time_slot_start_time, time) else (str(obj.time_slot_start_time) if obj.time_slot_start_time else None),
            "time_slot_end_time": obj.time_slot_end_time.isoformat() if isinstance(obj.time_slot_end_time, time) else (str(obj.time_slot_end_time) if obj.time_slot_end_time else None),
            "participants_per_slot": obj.participants_per_slot,
            "weekly_time_slot_config": obj.weekly_time_slot_config,
        }
        return cls(**data)
    
    class Config:
        from_attributes = True


class ServiceTimeSlotCreate(BaseModel):
    """创建服务时间段"""
    slot_date: str  # 日期格式：YYYY-MM-DD
    start_time: str  # 时间格式：HH:MM:SS
    end_time: str  # 时间格式：HH:MM:SS
    price_per_participant: condecimal(gt=0, max_digits=12, decimal_places=2)
    max_participants: int = Field(..., gt=0)


class ServiceTimeSlotUpdate(BaseModel):
    """更新服务时间段"""
    price_per_participant: Optional[condecimal(gt=0, max_digits=12, decimal_places=2)] = None
    max_participants: Optional[int] = Field(None, gt=0)
    is_available: Optional[bool] = None


class ServiceTimeSlotOut(BaseModel):
    """服务时间段输出（UTC时间）"""
    id: int
    service_id: int
    slot_start_datetime: str  # UTC时间格式：YYYY-MM-DDTHH:MM:SS+00:00
    slot_end_datetime: str  # UTC时间格式：YYYY-MM-DDTHH:MM:SS+00:00
    slot_date: str  # 日期格式：YYYY-MM-DD（向后兼容，从slot_start_datetime提取）
    start_time: str  # 时间格式：HH:MM:SS（向后兼容，从slot_start_datetime提取）
    end_time: str  # 时间格式：HH:MM:SS（向后兼容，从slot_end_datetime提取）
    price_per_participant: float
    max_participants: int
    current_participants: int
    is_available: bool
    is_expired: bool  # 时间段是否已过期（开始时间已过当前时间）
    is_manually_deleted: bool  # 是否手动删除
    created_at: datetime.datetime
    updated_at: datetime.datetime
    # 活动相关信息（如果时间段被活动使用）
    activity_id: Optional[int] = None  # 关联的活动ID
    activity_title: Optional[str] = None  # 活动标题
    activity_price: Optional[float] = None  # 活动价格（折扣后的价格）
    activity_original_price: Optional[float] = None  # 活动原价
    activity_discount_percentage: Optional[float] = None  # 折扣百分比
    has_activity: bool = False  # 是否有活动
    
    class Config:
        from_attributes = True
    
    @classmethod
    def from_orm(cls, obj):
        """自定义ORM转换，处理日期时间字段（UTC时间）"""
        from datetime import timezone
        from app.utils.time_utils import format_iso_utc
        from app.models import get_utc_time
        
        # 获取UTC时间
        slot_start_utc = obj.slot_start_datetime
        slot_end_utc = obj.slot_end_datetime
        
        # 确保时区信息存在
        if slot_start_utc.tzinfo is None:
            slot_start_utc = slot_start_utc.replace(tzinfo=timezone.utc)
        else:
            slot_start_utc = slot_start_utc.astimezone(timezone.utc)
            
        if slot_end_utc.tzinfo is None:
            slot_end_utc = slot_end_utc.replace(tzinfo=timezone.utc)
        else:
            slot_end_utc = slot_end_utc.astimezone(timezone.utc)
        
        # 检查时间段是否已过期（开始时间是否已过当前UTC时间）
        current_utc = get_utc_time()
        is_expired = slot_start_utc < current_utc
        
        # 查询关联的活动信息（如果时间段被活动使用）
        activity_id = None
        activity_title = None
        activity_price = None
        activity_original_price = None
        activity_discount_percentage = None
        has_activity = False
        
        # 检查是否有活动关联（通过ActivityTimeSlotRelation）
        # 只返回状态为open的活动
        if hasattr(obj, 'activity_relations') and obj.activity_relations:
            # 查找固定模式的活动关联，且活动状态为open
            fixed_relation = next(
                (rel for rel in obj.activity_relations 
                 if rel.relation_mode == 'fixed' 
                 and rel.activity_id 
                 and rel.activity 
                 and rel.activity.status == 'open'),
                None
            )
            if fixed_relation and fixed_relation.activity:
                activity = fixed_relation.activity
                activity_id = activity.id
                activity_title = activity.title
                has_activity = True
                # 活动价格（优先使用折扣后的价格）
                if activity.discounted_price_per_participant:
                    activity_price = float(activity.discounted_price_per_participant)
                elif activity.original_price_per_participant:
                    activity_price = float(activity.original_price_per_participant)
                if activity.original_price_per_participant:
                    activity_original_price = float(activity.original_price_per_participant)
                if activity.discount_percentage:
                    activity_discount_percentage = float(activity.discount_percentage)
        
        data = {
            "id": obj.id,
            "service_id": obj.service_id,
            "slot_start_datetime": format_iso_utc(slot_start_utc),
            "slot_end_datetime": format_iso_utc(slot_end_utc),
            # 向后兼容字段
            "slot_date": slot_start_utc.date().isoformat(),
            "start_time": slot_start_utc.time().isoformat(),
            "end_time": slot_end_utc.time().isoformat(),
            "price_per_participant": float(obj.price_per_participant),
            "max_participants": obj.max_participants,
            "current_participants": obj.current_participants,
            "is_available": obj.is_available,
            "is_expired": is_expired,  # 时间段是否已过期
            "is_manually_deleted": obj.is_manually_deleted,
            "created_at": obj.created_at,
            "updated_at": obj.updated_at,
            # 活动信息
            "activity_id": activity_id,
            "activity_title": activity_title,
            "activity_price": activity_price,
            "activity_original_price": activity_original_price,
            "activity_discount_percentage": activity_discount_percentage,
            "has_activity": has_activity,
        }
        return cls(**data)


# ==================== 任务达人关门日期相关Schemas ====================

class ExpertClosedDateCreate(BaseModel):
    """创建关门日期"""
    closed_date: str  # 日期格式：YYYY-MM-DD
    reason: Optional[str] = None  # 关门原因（可选）


class ExpertClosedDateOut(BaseModel):
    """关门日期输出"""
    id: int
    expert_id: str
    closed_date: str  # 日期格式：YYYY-MM-DD
    reason: Optional[str] = None
    created_at: datetime.datetime
    updated_at: datetime.datetime
    
    class Config:
        from_attributes = True


class ServiceApplicationOut(BaseModel):
    id: int
    service_id: int
    applicant_id: str
    expert_id: str
    time_slot_id: Optional[int] = None  # 选择的时间段ID
    application_message: Optional[str]
    negotiated_price: Optional[float]  # 输出时保持float，输入时使用condecimal
    expert_counter_price: Optional[float]
    currency: Literal["GBP"]  # 统一为Literal类型
    status: str
    final_price: Optional[float]
    task_id: Optional[int]
    deadline: Optional[datetime.datetime]  # 任务截至日期
    is_flexible: Optional[int]  # 是否灵活（1=灵活，无截至日期；0=有截至日期）
    created_at: datetime.datetime
    approved_at: Optional[datetime.datetime]
    price_agreed_at: Optional[datetime.datetime]
    
    class Config:
        from_attributes = True


class ServiceApplicationCreate(BaseModel):
    # 注意：service_id 从路径参数获取，不需要在请求体中
    application_message: Optional[str] = None
    negotiated_price: Optional[condecimal(gt=0, max_digits=12, decimal_places=2)] = None  # 修复：添加校验，必须大于0
    currency: Literal["GBP"] = "GBP"
    deadline: Optional[datetime.datetime] = None  # 任务截至日期（如果is_flexible为False）
    is_flexible: Optional[int] = 0  # 是否灵活（1=灵活，无截至日期；0=有截至日期）
    time_slot_id: Optional[int] = None  # 选择的时间段ID（如果服务启用了时间段）


class CounterOfferRequest(BaseModel):
    """任务达人再次议价请求"""
    counter_price: condecimal(gt=0, max_digits=12, decimal_places=2) = Field(..., description="任务达人提出的议价价格")
    message: Optional[str] = None  # 可选说明


class AcceptCounterOfferRequest(BaseModel):
    """用户同意任务达人议价请求"""
    accept: bool = Field(..., description="是否同意议价")


class ServiceApplicationRejectRequest(BaseModel):
    """任务达人拒绝申请请求"""
    reject_reason: Optional[str] = None


class PaginatedResponse(BaseModel):
    """分页响应基类"""
    total: int
    items: List[Any]
    limit: int
    offset: int
    has_more: bool


# ==================== 跳蚤市场相关 Schemas ====================

class FleaMarketItemBase(BaseModel):
    """跳蚤市场商品基础模型"""
    title: str = Field(..., min_length=1, max_length=200)
    description: str = Field(..., min_length=1)
    price: Decimal = Field(..., gt=0)
    images: List[str] = Field(default_factory=list, max_items=5)
    location: Optional[str] = Field(None, max_length=100)
    category: Optional[str] = Field(None, max_length=100)
    contact: Optional[str] = Field(None, max_length=200)  # 联系方式


class FleaMarketItemCreate(FleaMarketItemBase):
    """创建商品请求"""
    pass


class FleaMarketItemUpdate(BaseModel):
    """更新商品请求"""
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = Field(None, min_length=1)
    price: Optional[Decimal] = Field(None, gt=0)
    images: Optional[List[str]] = Field(None, max_items=5)
    location: Optional[str] = Field(None, max_length=100)
    category: Optional[str] = Field(None, max_length=100)
    contact: Optional[str] = Field(None, max_length=200)  # 联系方式
    status: Optional[Literal["deleted"]] = None  # 仅允许设置为deleted


class FleaMarketItemResponse(BaseModel):
    """商品响应模型（不包含联系方式）"""
    id: str  # 格式化为 S + 数字
    title: str
    description: str
    price: Decimal
    currency: Literal["GBP"] = "GBP"
    images: List[str]
    location: Optional[str]
    category: Optional[str]
    status: Literal["active", "sold", "deleted"]
    seller_id: str
    view_count: int
    refreshed_at: str
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True


class FleaMarketItemListResponse(BaseModel):
    """商品列表响应"""
    items: List[FleaMarketItemResponse]
    page: int
    pageSize: int
    total: int
    hasMore: bool


class FleaMarketPurchaseRequestCreate(BaseModel):
    """创建购买申请请求"""
    proposed_price: Decimal = Field(..., gt=0)
    message: Optional[str] = None


class FleaMarketPurchaseRequestResponse(BaseModel):
    """购买申请响应"""
    id: str  # 格式化为 S + 数字
    item_id: str
    buyer_id: str
    proposed_price: Optional[Decimal]
    message: Optional[str]
    status: Literal["pending", "accepted", "rejected"]
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True


class AcceptPurchaseRequest(BaseModel):
    """接受购买申请请求（买家接受卖家议价后创建任务）"""
    purchase_request_id: int


class RejectPurchaseRequest(BaseModel):
    """拒绝购买申请请求"""
    purchase_request_id: int


class SellerCounterOfferRequest(BaseModel):
    """卖家议价请求"""
    purchase_request_id: int
    counter_price: Decimal = Field(..., gt=0)


class BuyerRespondToCounterOfferRequest(BaseModel):
    """买家回应卖家议价请求"""
    purchase_request_id: int
    accept: bool  # True表示接受，False表示拒绝


class MyPurchasesItemResponse(FleaMarketItemResponse):
    """我的购买商品响应（包含任务信息）"""
    task_id: str  # 关联的任务ID
    final_price: Decimal  # 最终成交价


class MyPurchasesListResponse(BaseModel):
    """我的购买商品列表响应"""
    items: List[MyPurchasesItemResponse]
    page: int
    pageSize: int
    total: int
    hasMore: bool


# ==================== 商品收藏相关Schemas ====================

class FleaMarketFavoriteResponse(BaseModel):
    id: int
    item_id: str  # 格式化的ID
    created_at: str
    
    class Config:
        from_attributes = True


class FleaMarketFavoriteListResponse(BaseModel):
    items: List[FleaMarketFavoriteResponse]
    page: int
    pageSize: int
    total: int
    hasMore: bool


# ==================== 多人任务相关Schemas ====================

# 管理员创建官方多人任务
class MultiParticipantTaskCreate(BaseModel):
    title: str
    description: str
    deadline: Optional[datetime.datetime] = None
    location: str
    task_type: str
    max_participants: int = Field(..., gt=0)
    min_participants: int = Field(..., gt=0)
    completion_rule: Literal["all", "min"] = "all"
    reward_distribution: Literal["equal", "custom"] = "equal"
    reward_type: Literal["cash", "points", "both"] = "cash"
    reward: Optional[float] = None  # 现金奖励（reward_type包含cash时必填）
    points_reward: Optional[int] = None  # 积分奖励（reward_type包含points时必填）
    currency: str = "GBP"
    images: Optional[List[str]] = None
    is_public: bool = True
    
    @model_validator(mode='after')
    def validate_reward_fields(self):
        """验证奖励字段"""
        if self.reward_type == "cash":
            if self.reward is None or self.reward <= 0:
                raise ValueError("reward must be > 0 when reward_type='cash'")
            if self.points_reward is not None and self.points_reward > 0:
                raise ValueError("points_reward must be None or 0 when reward_type='cash'")
        elif self.reward_type == "points":
            if self.points_reward is None or self.points_reward <= 0:
                raise ValueError("points_reward must be > 0 when reward_type='points'")
            if self.reward is not None and self.reward > 0:
                raise ValueError("reward must be None when reward_type='points'")
        elif self.reward_type == "both":
            if self.reward is None or self.reward <= 0:
                raise ValueError("reward must be > 0 when reward_type='both'")
            if self.points_reward is None or self.points_reward <= 0:
                raise ValueError("points_reward must be > 0 when reward_type='both'")
        return self


# ===========================================
# 活动相关Schemas
# ===========================================

class ActivityCreate(BaseModel):
    """创建活动"""
    title: str
    description: str
    expert_service_id: int
    deadline: Optional[datetime.datetime] = None
    location: str
    task_type: str
    reward_type: Literal["cash", "points", "both"] = "cash"
    original_price_per_participant: Optional[float] = None
    discount_percentage: Optional[float] = None
    discounted_price_per_participant: Optional[float] = None
    currency: str = "GBP"
    points_reward: Optional[int] = None
    max_participants: int = Field(..., gt=0)
    min_participants: int = Field(..., gt=0)
    completion_rule: Literal["all", "min"] = "all"
    reward_distribution: Literal["equal", "custom"] = "equal"
    images: Optional[List[str]] = None
    is_public: bool = True
    # 时间段选择相关字段
    selected_time_slot_ids: Optional[List[int]] = None
    time_slot_selection_mode: Optional[Literal["fixed", "recurring_daily", "recurring_weekly"]] = None
    recurring_daily_time_ranges: Optional[List[Dict[str, str]]] = None
    recurring_weekly_weekdays: Optional[List[int]] = None
    recurring_weekly_time_ranges: Optional[List[Dict[str, str]]] = None
    auto_add_new_slots: bool = True
    activity_end_date: Optional[datetime.date] = None


class ActivityOut(BaseModel):
    """活动输出"""
    id: int
    title: str
    description: str
    expert_id: str
    expert_service_id: int
    location: str
    task_type: str
    reward_type: str
    original_price_per_participant: Optional[float] = None
    discount_percentage: Optional[float] = None
    discounted_price_per_participant: Optional[float] = None
    currency: str
    points_reward: Optional[int] = None
    max_participants: int
    min_participants: int
    current_participants: Optional[int] = 0  # 当前参与者数量（从关联任务计算）
    completion_rule: str
    reward_distribution: str
    status: str
    is_public: bool
    visibility: str
    deadline: Optional[datetime.datetime] = None
    activity_end_date: Optional[datetime.date] = None
    images: Optional[List[str]] = None
    service_images: Optional[List[str]] = None  # 关联服务的图片（用于前端显示）
    has_time_slots: bool
    created_at: datetime.datetime
    updated_at: datetime.datetime
    
    class Config:
        from_attributes = True
    
    @classmethod
    def from_orm_with_participants(cls, obj, current_participants: int = 0):
        """从ORM对象创建，包含参与者数量"""
        # 获取关联服务的图片
        service_images = None
        if hasattr(obj, 'service') and obj.service and obj.service.images:
            service_images = obj.service.images
        
        data = {
            "id": obj.id,
            "title": obj.title,
            "description": obj.description,
            "expert_id": obj.expert_id,
            "expert_service_id": obj.expert_service_id,
            "location": obj.location,
            "task_type": obj.task_type,
            "reward_type": obj.reward_type,
            "original_price_per_participant": float(obj.original_price_per_participant) if obj.original_price_per_participant else None,
            "discount_percentage": float(obj.discount_percentage) if obj.discount_percentage else None,
            "discounted_price_per_participant": float(obj.discounted_price_per_participant) if obj.discounted_price_per_participant else None,
            "currency": obj.currency,
            "points_reward": obj.points_reward,
            "max_participants": obj.max_participants,
            "min_participants": obj.min_participants,
            "current_participants": current_participants,
            "completion_rule": obj.completion_rule,
            "reward_distribution": obj.reward_distribution,
            "status": obj.status,
            "is_public": obj.is_public,
            "visibility": obj.visibility,
            "deadline": obj.deadline,
            "activity_end_date": obj.activity_end_date,
            "images": obj.images,
            "service_images": service_images,
            "has_time_slots": obj.has_time_slots,
            "created_at": obj.created_at,
            "updated_at": obj.updated_at,
        }
        return cls(**data)


class ActivityApplyRequest(BaseModel):
    """申请参与活动"""
    idempotency_key: str = Field(..., min_length=1, max_length=64)
    time_slot_id: Optional[int] = None  # 时间段服务必填
    preferred_deadline: Optional[datetime.datetime] = None  # 非时间段服务可选
    is_flexible_time: Optional[bool] = False  # 非时间段服务
    # 如果是多人任务，这些字段用于创建TaskParticipant
    is_multi_participant: bool = False  # 是否创建多人任务
    max_participants: Optional[int] = None  # 多人任务的最大参与者数
    min_participants: Optional[int] = None  # 多人任务的最小参与者数


# 任务达人创建多人任务（保留向后兼容，但改为创建Activity）
class ExpertMultiParticipantTaskCreate(BaseModel):
    title: str
    description: str
    expert_service_id: int
    deadline: Optional[datetime.datetime] = None
    location: str
    reward_type: Literal["cash", "points", "both"] = "cash"
    reward: Optional[float] = None
    points_reward: Optional[int] = None
    currency: str = "GBP"
    max_participants: int = Field(..., gt=0)
    min_participants: int = Field(..., gt=0)
    completion_rule: Literal["all", "min"] = "all"
    reward_distribution: Literal["equal", "custom"] = "equal"
    is_fixed_time_slot: bool = False
    time_slot_duration_minutes: Optional[int] = None
    time_slot_start_time: Optional[str] = None  # TIME格式 "HH:MM:SS"
    time_slot_end_time: Optional[str] = None
    participants_per_slot: Optional[int] = None
    original_price_per_participant: Optional[float] = None
    discount_percentage: Optional[float] = None
    discounted_price_per_participant: Optional[float] = None
    images: Optional[List[str]] = None
    is_public: bool = True
    # 时间段选择相关字段
    selected_time_slot_ids: Optional[List[int]] = None  # 固定模式：选择的具体时间段ID列表
    time_slot_selection_mode: Optional[Literal["fixed", "recurring_daily", "recurring_weekly"]] = None  # 选择模式
    recurring_daily_time_ranges: Optional[List[Dict[str, str]]] = None  # 每天的时间段范围，例如：[{"start": "10:00", "end": "12:00"}]
    recurring_weekly_weekdays: Optional[List[int]] = None  # 每周几，0=周一，6=周日
    recurring_weekly_time_ranges: Optional[List[Dict[str, str]]] = None  # 每周的时间段范围
    auto_add_new_slots: bool = True  # 是否自动添加新匹配的时间段
    activity_end_date: Optional[datetime.date] = None  # 活动截至日期（可选）


# 申请参与多人任务
class TaskApplyRequest(BaseModel):
    idempotency_key: str = Field(..., min_length=1, max_length=64)  # 必须携带
    time_slot_id: Optional[int] = None  # 固定时间段服务必填
    preferred_deadline: Optional[datetime.datetime] = None  # 非固定时间段服务
    is_flexible_time: Optional[bool] = False  # 非固定时间段服务


# 参与者信息
class TaskParticipantOut(BaseModel):
    id: int
    task_id: int
    user_id: str
    status: str
    time_slot_id: Optional[int] = None
    preferred_deadline: Optional[datetime.datetime] = None
    is_flexible_time: bool = False
    planned_reward_amount: Optional[float] = None
    planned_points_reward: int = 0
    applied_at: datetime.datetime
    accepted_at: Optional[datetime.datetime] = None
    started_at: Optional[datetime.datetime] = None
    completed_at: Optional[datetime.datetime] = None
    exit_requested_at: Optional[datetime.datetime] = None
    exit_reason: Optional[str] = None
    completion_notes: Optional[str] = None
    
    class Config:
        from_attributes = True


# 提交完成
class TaskParticipantCompleteRequest(BaseModel):
    idempotency_key: str = Field(..., min_length=1, max_length=64)  # 必须携带
    completion_notes: Optional[str] = None


# 申请退出
class TaskParticipantExitRequest(BaseModel):
    idempotency_key: str = Field(..., min_length=1, max_length=64)  # 必须携带
    exit_reason: Optional[str] = None


# 分配奖励（平均分配）
class TaskRewardDistributeEqualRequest(BaseModel):
    idempotency_key: str = Field(..., min_length=1, max_length=64)  # 必须携带


# 分配奖励（自定义分配）
class ParticipantRewardItem(BaseModel):
    participant_id: int
    reward_type: Literal["cash", "points", "both"]
    reward_amount: Optional[float] = None
    points_amount: Optional[int] = None


class TaskRewardDistributeCustomRequest(BaseModel):
    idempotency_key: str = Field(..., min_length=1, max_length=64)  # 必须携带
    rewards: List[ParticipantRewardItem]


# 奖励信息
class TaskParticipantRewardOut(BaseModel):
    id: int
    task_id: int
    participant_id: int
    user_id: str
    reward_type: str
    reward_amount: Optional[float] = None
    points_amount: Optional[int] = None
    payment_status: str
    points_status: str
    paid_at: Optional[datetime.datetime] = None
    points_credited_at: Optional[datetime.datetime] = None
    created_at: datetime.datetime
    
    class Config:
        from_attributes = True


# ==================== 商品举报相关Schemas ====================

class FleaMarketReportCreate(BaseModel):
    reason: str  # spam, fraud, inappropriate, other
    description: Optional[str] = None


class FleaMarketReportResponse(BaseModel):
    id: int
    item_id: str
    reason: str
    description: Optional[str]
    status: str
    created_at: str
    
    class Config:
        from_attributes = True