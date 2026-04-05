"""
达人团队体系 SQLAlchemy 模型
对应迁移 158_experts_system.sql 创建的表
"""
import random

from sqlalchemy import (
    Column,
    Integer,
    String,
    Text,
    Boolean,
    Float,
    DateTime,
    ForeignKey,
    Index,
    UniqueConstraint,
    DECIMAL,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.models import Base
from app.utils.time_utils import get_utc_time


def generate_expert_id() -> str:
    """生成 8 位数字字符串作为达人团队 ID（与 user_id 格式一致）"""
    return str(random.randint(10000000, 99999999))


class Expert(Base):
    """达人团队"""
    __tablename__ = "experts"

    id = Column(String(8), primary_key=True, default=generate_expert_id)
    name = Column(String(100), nullable=False)
    name_en = Column(String(100), nullable=True)
    name_zh = Column(String(100), nullable=True)
    bio = Column(Text, nullable=True)
    bio_en = Column(Text, nullable=True)
    bio_zh = Column(Text, nullable=True)
    avatar = Column(Text, nullable=True)
    status = Column(String(20), nullable=False, default="active")
    allow_applications = Column(Boolean, nullable=False, default=True)
    max_members = Column(Integer, nullable=False, default=20)
    member_count = Column(Integer, nullable=False, default=1)
    rating = Column(DECIMAL(3, 2), nullable=False, default=0.00)
    total_services = Column(Integer, nullable=False, default=0)
    completed_tasks = Column(Integer, nullable=False, default=0)
    completion_rate = Column(Float, nullable=False, default=0.0)
    is_official = Column(Boolean, nullable=False, default=False)
    official_badge = Column(String(50), nullable=True)
    stripe_account_id = Column(String(255), nullable=True)
    stripe_connect_country = Column(String(10), nullable=True)
    stripe_onboarding_complete = Column(Boolean, nullable=False, default=False)
    # Phase 3/4: FK 约束后续迁移添加
    forum_category_id = Column(Integer, nullable=True)
    internal_group_id = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())

    # Relationships
    members = relationship("ExpertMember", back_populates="expert", cascade="all, delete-orphan")
    join_requests = relationship("ExpertJoinRequest", back_populates="expert", cascade="all, delete-orphan")
    invitations = relationship("ExpertInvitation", back_populates="expert", cascade="all, delete-orphan")
    followers = relationship("ExpertFollow", back_populates="expert", cascade="all, delete-orphan")
    profile_update_requests = relationship("ExpertProfileUpdateRequest", back_populates="expert", cascade="all, delete-orphan")
    featured = relationship("FeaturedExpertV2", back_populates="expert", uselist=False, cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_experts_status", "status"),
        Index("ix_experts_rating", "rating"),
    )


class ExpertMember(Base):
    """达人团队成员"""
    __tablename__ = "expert_members"

    id = Column(Integer, primary_key=True, autoincrement=True)
    expert_id = Column(String(8), ForeignKey("experts.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role = Column(String(20), nullable=False)
    status = Column(String(20), nullable=False, default="active")
    joined_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())

    # Relationships
    expert = relationship("Expert", back_populates="members")
    user = relationship("User", backref="expert_memberships")

    __table_args__ = (
        UniqueConstraint("expert_id", "user_id", name="uq_expert_member"),
        # 部分索引匹配 SQL migration 158
        Index("ix_expert_members_user", "user_id", postgresql_where="status = 'active'"),
        Index("ix_expert_members_expert_role", "expert_id", "role", postgresql_where="status = 'active'"),
    )


class ExpertApplication(Base):
    """创建达人团队的申请"""
    __tablename__ = "expert_applications"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    expert_name = Column(String(100), nullable=False)
    bio = Column(Text, nullable=True)
    avatar = Column(Text, nullable=True)
    application_message = Column(Text, nullable=True)
    status = Column(String(20), nullable=False, default="pending")
    reviewed_by = Column(String(5), ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    review_comment = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())

    # Relationships
    applicant = relationship("User", backref="expert_applications")
    reviewer = relationship("AdminUser", foreign_keys=[reviewed_by], backref="reviewed_expert_applications")

    __table_args__ = (
        Index("ix_expert_applications_user_id", "user_id"),
        Index("ix_expert_applications_status", "status"),
    )


class ExpertJoinRequest(Base):
    """申请加入达人团队"""
    __tablename__ = "expert_join_requests"

    id = Column(Integer, primary_key=True, autoincrement=True)
    expert_id = Column(String(8), ForeignKey("experts.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    message = Column(Text, nullable=True)
    status = Column(String(20), nullable=False, default="pending")
    reviewed_by = Column(String(8), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    reviewed_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships — disambiguate two FKs to users
    expert = relationship("Expert", back_populates="join_requests")
    requester = relationship("User", foreign_keys=[user_id], backref="expert_join_requests_sent")
    reviewer = relationship("User", foreign_keys=[reviewed_by], backref="expert_join_requests_reviewed")

    __table_args__ = (
        Index("ix_expert_join_requests_expert_id", "expert_id"),
        Index("ix_expert_join_requests_user_id", "user_id"),
        Index("ix_expert_join_requests_status", "status"),
    )


class ExpertInvitation(Base):
    """达人团队邀请"""
    __tablename__ = "expert_invitations"

    id = Column(Integer, primary_key=True, autoincrement=True)
    expert_id = Column(String(8), ForeignKey("experts.id", ondelete="CASCADE"), nullable=False)
    inviter_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    invitee_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    status = Column(String(20), nullable=False, default="pending")
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    responded_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships — disambiguate three FKs to users
    expert = relationship("Expert", back_populates="invitations")
    inviter = relationship("User", foreign_keys=[inviter_id], backref="expert_invitations_sent")
    invitee = relationship("User", foreign_keys=[invitee_id], backref="expert_invitations_received")

    __table_args__ = (
        Index("ix_expert_invitations_expert_id", "expert_id"),
        Index("ix_expert_invitations_invitee_id", "invitee_id"),
        Index("ix_expert_invitations_status", "status"),
    )


class ExpertFollow(Base):
    """用户关注达人团队"""
    __tablename__ = "expert_follows"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    expert_id = Column(String(8), ForeignKey("experts.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())

    # Relationships
    user = relationship("User", backref="expert_follows")
    expert = relationship("Expert", back_populates="followers")

    __table_args__ = (
        UniqueConstraint("user_id", "expert_id", name="uq_expert_follow"),
        Index("ix_expert_follows_user_id", "user_id"),
        Index("ix_expert_follows_expert_id", "expert_id"),
    )


class ExpertProfileUpdateRequest(Base):
    """达人团队资料修改申请"""
    __tablename__ = "expert_profile_update_requests"

    id = Column(Integer, primary_key=True, autoincrement=True)
    expert_id = Column(String(8), ForeignKey("experts.id", ondelete="CASCADE"), nullable=False)
    requester_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    new_name = Column(String(100), nullable=True)
    new_bio = Column(Text, nullable=True)
    new_avatar = Column(Text, nullable=True)
    status = Column(String(20), nullable=False, default="pending")
    reviewed_by = Column(String(5), ForeignKey("admin_users.id", ondelete="SET NULL"), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    review_comment = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())

    # Relationships
    expert = relationship("Expert", back_populates="profile_update_requests")
    requester = relationship("User", backref="expert_profile_update_requests")
    reviewer = relationship("AdminUser", foreign_keys=[reviewed_by], backref="reviewed_expert_profile_updates")

    __table_args__ = (
        Index("ix_expert_profile_update_requests_expert_id", "expert_id"),
        Index("ix_expert_profile_update_requests_status", "status"),
    )


class FeaturedExpertV2(Base):
    """精选达人团队（v2）"""
    __tablename__ = "featured_experts_v2"

    id = Column(Integer, primary_key=True, autoincrement=True)
    expert_id = Column(String(8), ForeignKey("experts.id", ondelete="CASCADE"), nullable=False, unique=True)
    is_featured = Column(Boolean, nullable=False, default=True)
    display_order = Column(Integer, nullable=False, default=0)
    category = Column(String(50), nullable=True)
    created_by = Column(String(5), ForeignKey("admin_users.id", ondelete="RESTRICT"), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())

    # Relationships
    expert = relationship("Expert", back_populates="featured")
    creator = relationship("AdminUser", foreign_keys=[created_by], backref="featured_experts_created")

    __table_args__ = (
        Index("ix_featured_experts_v2_is_featured", "is_featured"),
        Index("ix_featured_experts_v2_display_order", "display_order"),
    )


class ChatParticipant(Base):
    """任务聊天参与者（多人聊天扩展）"""
    __tablename__ = "chat_participants"

    id = Column(Integer, primary_key=True, autoincrement=True)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    role = Column(String(20), nullable=False, default="expert_member")
    invited_by = Column(String(8), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    joined_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())

    # Relationships
    user = relationship("User", foreign_keys=[user_id], backref="chat_participations")
    inviter = relationship("User", foreign_keys=[invited_by])

    __table_args__ = (
        UniqueConstraint("task_id", "user_id", name="uq_chat_participant"),
        Index("ix_chat_participants_task", "task_id"),
        Index("ix_chat_participants_user", "user_id"),
    )


class UserServicePackage(Base):
    """用户购买的服务套餐"""
    __tablename__ = "user_service_packages"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    service_id = Column(Integer, ForeignKey("task_expert_services.id", ondelete="CASCADE"), nullable=False)
    expert_id = Column(String(8), ForeignKey("experts.id", ondelete="SET NULL"), nullable=True)
    total_sessions = Column(Integer, nullable=False)
    used_sessions = Column(Integer, nullable=False, default=0)
    status = Column(String(20), nullable=False, default="active")
    purchased_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=True)
    task_id = Column(Integer, ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True)

    user = relationship("User", backref="service_packages")

    __table_args__ = (
        Index("ix_user_packages_user", "user_id"),
        Index("ix_user_packages_service", "service_id"),
        Index("ix_user_packages_expert", "expert_id"),
    )


class PackageUsageLog(Base):
    """套餐核销记录"""
    __tablename__ = "package_usage_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    package_id = Column(Integer, ForeignKey("user_service_packages.id", ondelete="CASCADE"), nullable=False)
    used_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    used_by = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    note = Column(Text, nullable=True)

    __table_args__ = (
        Index("ix_package_usage_package", "package_id"),
    )


class GroupBuyParticipant(Base):
    """拼单参与者"""
    __tablename__ = "group_buy_participants"

    id = Column(Integer, primary_key=True, autoincrement=True)
    activity_id = Column(Integer, ForeignKey("activities.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    round = Column(Integer, nullable=False, default=1)
    status = Column(String(20), nullable=False, default="joined")
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    cancelled_at = Column(DateTime(timezone=True), nullable=True)

    user = relationship("User", backref="group_buy_participations")

    __table_args__ = (
        UniqueConstraint("activity_id", "user_id", "round", name="uq_gbp_activity_user_round"),
        Index("ix_gbp_activity", "activity_id", "round"),
        Index("ix_gbp_user", "user_id"),
    )
