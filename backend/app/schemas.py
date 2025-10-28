import datetime
from typing import List, Literal, Optional

from pydantic import BaseModel, Field


class UserBase(BaseModel):
    name: str
    email: str
    phone: Optional[str] = None
    avatar: Optional[str] = ""


class UserCreate(UserBase):
    password: str = Field(..., min_length=6)
    avatar: Optional[str] = ""
    agreed_to_terms: Optional[bool] = False
    terms_agreed_at: Optional[str] = None


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
    location: str  # Frontend should use QS_TOP100_CITIES options
    task_type: str  # Frontend should use TASK_TYPES options


class TaskCreate(TaskBase):
    is_public: Optional[int] = 1  # 1=public, 0=private (仅自己可见)


class TaskOut(TaskBase):
    id: int
    poster_id: str  # 现在ID是字符串类型
    taker_id: Optional[str]  # 现在ID是字符串类型
    status: str
    task_level: str = "normal"  # normal, vip, super
    created_at: datetime.datetime
    is_public: Optional[int] = 1  # 1=public, 0=private (仅自己可见)

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
