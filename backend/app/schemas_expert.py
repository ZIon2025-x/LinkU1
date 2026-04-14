"""达人团队体系 Pydantic Schemas"""
import datetime
from typing import Optional, List, Literal
from pydantic import BaseModel, Field, model_validator


# ==================== Expert ====================

class ExpertOut(BaseModel):
    id: str
    name: str
    name_en: Optional[str] = None
    name_zh: Optional[str] = None
    bio: Optional[str] = None
    bio_en: Optional[str] = None
    bio_zh: Optional[str] = None
    avatar: Optional[str] = None
    status: str
    allow_applications: bool
    member_count: int
    rating: float
    total_services: int
    completed_tasks: int
    completion_rate: float
    is_official: bool = False
    official_badge: Optional[str] = None
    stripe_onboarding_complete: bool = False
    forum_category_id: Optional[int] = None
    created_at: datetime.datetime
    # migration 188 / admin 编辑表单 + buyer 端达人画像字段
    category: Optional[str] = None
    location: Optional[str] = None
    display_order: int = 0
    is_verified: bool = False
    expertise_areas: Optional[List[str]] = None
    expertise_areas_en: Optional[List[str]] = None
    featured_skills: Optional[List[str]] = None
    featured_skills_en: Optional[List[str]] = None
    achievements: Optional[List[str]] = None
    achievements_en: Optional[List[str]] = None
    response_time: Optional[str] = None
    response_time_en: Optional[str] = None
    user_level: str = "normal"
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    service_radius_km: Optional[int] = None
    business_hours: Optional[dict] = None  # {"mon": {"open": "09:00", "close": "18:00"}, ...}
    follower_count: int = 0  # 粉丝数（接口层填充）
    is_following: bool = False  # 当前用户是否关注（接口层填充）
    my_role: Optional[str] = None  # 当前用户在此团队中的角色（接口层填充）

    class Config:
        from_attributes = True


class ExpertDetailOut(ExpertOut):
    members: List["ExpertMemberOut"] = []
    is_featured: bool = False
    is_open: Optional[bool] = None  # 当前是否在营业时间内（结合 business_hours + closed_dates）


# ==================== ExpertMember ====================

class ExpertMemberOut(BaseModel):
    id: int
    # user_id 改为 Optional: 公开列表对非团队成员/未登录用户隐藏(防枚举攻击)
    # 团队 owner/admin/member 仍能拿到 user_id 用于 remove/transfer 等操作
    user_id: Optional[str] = None
    user_name: Optional[str] = None
    user_avatar: Optional[str] = None
    role: str
    status: str
    joined_at: datetime.datetime

    class Config:
        from_attributes = True


# ==================== ExpertApplication (创建达人) ====================

class ExpertApplicationCreate(BaseModel):
    # 团队名称可选:不传时后端会回退用申请人的 user.name 作为默认团队名,
    # 用户可以在 dashboard 里之后修改。这样兼容只采集 application_message
    # 的简化申请表单(spec §0.1 — 团队即默认形态,1 人团队也合法)。
    expert_name: Optional[str] = Field(None, max_length=100)
    bio: Optional[str] = None
    avatar: Optional[str] = None
    application_message: Optional[str] = None


class ExpertApplicationOut(BaseModel):
    id: int
    user_id: str
    expert_name: str
    bio: Optional[str] = None
    avatar: Optional[str] = None
    application_message: Optional[str] = None
    status: str
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime.datetime] = None
    review_comment: Optional[str] = None
    created_at: datetime.datetime

    class Config:
        from_attributes = True


class ExpertApplicationReview(BaseModel):
    action: Literal["approve", "reject"]
    review_comment: Optional[str] = None


# ==================== Admin: 直接创建达人团队 ====================

class ExpertCreateByAdmin(BaseModel):
    """管理员直接创建达人团队的请求体"""
    name: str = Field(..., max_length=100, min_length=1)
    name_en: Optional[str] = Field(None, max_length=100)
    name_zh: Optional[str] = Field(None, max_length=100)
    bio: Optional[str] = None
    bio_en: Optional[str] = None
    bio_zh: Optional[str] = None
    avatar: Optional[str] = None
    owner_user_id: str = Field(..., min_length=1, description="必填:owner 必须是已存在的用户 id")
    is_official: bool = False
    official_badge: Optional[str] = Field(None, max_length=50)
    allow_applications: bool = False


# ==================== ExpertJoinRequest ====================

class ExpertJoinRequestCreate(BaseModel):
    message: Optional[str] = None


class ExpertJoinRequestOut(BaseModel):
    id: int
    expert_id: str
    user_id: str
    user_name: Optional[str] = None
    user_avatar: Optional[str] = None
    message: Optional[str] = None
    status: str
    created_at: datetime.datetime
    reviewed_at: Optional[datetime.datetime] = None

    class Config:
        from_attributes = True


class ExpertJoinRequestReview(BaseModel):
    action: Literal["approve", "reject"]


# ==================== ExpertInvitation ====================

class ExpertInvitationCreate(BaseModel):
    invitee_id: str


class ExpertInvitationOut(BaseModel):
    id: int
    expert_id: str
    inviter_id: str
    invitee_id: str
    invitee_name: Optional[str] = None
    invitee_avatar: Optional[str] = None
    status: str
    created_at: datetime.datetime
    responded_at: Optional[datetime.datetime] = None
    expert_name: Optional[str] = None
    expert_avatar: Optional[str] = None

    class Config:
        from_attributes = True


class ExpertInvitationResponse(BaseModel):
    action: Literal["accept", "reject"]


# ==================== Role Management ====================

class ExpertRoleChange(BaseModel):
    role: Literal["admin", "member"]


class ExpertTransfer(BaseModel):
    new_owner_id: str


# ==================== ExpertProfileUpdateRequest ====================

class ExpertProfileUpdateCreate(BaseModel):
    new_name: Optional[str] = Field(None, max_length=100)
    new_bio: Optional[str] = None
    new_avatar: Optional[str] = None

    @model_validator(mode='after')
    def check_at_least_one_field(self):
        if not any([self.new_name, self.new_bio, self.new_avatar]):
            raise ValueError("至少需要修改一个字段")
        return self


class ExpertProfileUpdateOut(BaseModel):
    id: int
    expert_id: str
    requester_id: str
    new_name: Optional[str] = None
    new_bio: Optional[str] = None
    new_avatar: Optional[str] = None
    status: str
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime.datetime] = None
    review_comment: Optional[str] = None
    created_at: datetime.datetime

    class Config:
        from_attributes = True


class ExpertProfileUpdateReview(BaseModel):
    action: Literal["approve", "reject"]
    review_comment: Optional[str] = None


class ExpertLocationUpdate(BaseModel):
    """更新达人团队基地地址 + 默认服务半径（Owner 直接生效，无需审核）"""
    location: Optional[str] = Field(None, max_length=100)
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    service_radius_km: Optional[Literal[0, 5, 10, 25, 50]] = None

    @model_validator(mode='after')
    def check_lat_lng_pair(self):
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("latitude 和 longitude 必须同时提供或同时为空")
        return self


# Forward ref
ExpertDetailOut.model_rebuild()
