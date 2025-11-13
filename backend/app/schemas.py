import datetime
from typing import List, Literal, Optional, Dict, Any

from pydantic import BaseModel, Field, validator, model_validator


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
    inviter_id: Optional[str] = None
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
    deadline: datetime.datetime
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
    task_level: str = "normal"  # normal, vip, super
    created_at: datetime.datetime
    is_public: Optional[int] = 1  # 1=public, 0=private (仅自己可见)
    images: Optional[List[str]] = None  # 图片URL列表

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