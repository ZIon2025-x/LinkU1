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
    is_following: bool = False  # 当前用户是否关注（接口层填充）
    my_role: Optional[str] = None  # 当前用户在此团队中的角色（接口层填充）

    class Config:
        from_attributes = True


class ExpertDetailOut(ExpertOut):
    members: List["ExpertMemberOut"] = []
    is_featured: bool = False


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


# Forward ref
ExpertDetailOut.model_rebuild()
