# 达人团队体系 Phase 1a — 后端基础

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建达人团队的后端基础——新表、模型、路由、数据迁移，让达人从"个人身份"升级为"团队实体"。

**Architecture:** 新建 `experts` 独立实体表（8位随机ID），通过 `expert_members` 多对多关联用户。保留 `featured_experts` 精简表做展示控制。所有路由在新的 `expert_routes.py` 和 `admin_expert_routes.py` 中实现，旧路由暂不删除（Phase 2 服务层改造后再清理）。

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy (async), PostgreSQL, Pydantic v2

**Spec:** `docs/superpowers/specs/2026-04-04-expert-team-redesign.md`

---

## File Structure

### New Files
- `backend/migrations/158_create_expert_team_tables.sql` — 新表创建
- `backend/migrations/159_migrate_expert_data.sql` — 数据迁移
- `backend/app/models_expert.py` — 达人团队相关模型（后续合并到 models.py）
- `backend/app/schemas_expert.py` — 达人团队相关 Pydantic schemas
- `backend/app/expert_routes.py` — 达人团队用户侧路由
- `backend/app/admin_expert_routes.py` — 达人团队管理员侧路由
- `backend/tests/test_expert_models.py` — 模型测试
- `backend/tests/test_expert_routes.py` — 路由测试

### Modified Files
- `backend/app/models.py` — 导入新模型
- `backend/app/main.py` — 注册新路由

---

## Task 1: 数据库迁移 — 创建新表

**Files:**
- Create: `backend/migrations/158_create_expert_team_tables.sql`

- [ ] **Step 1: 编写建表 SQL**

```sql
-- ===========================================
-- 迁移 158: 创建达人团队体系新表
-- ===========================================
--
-- 新表：experts, expert_members, expert_applications,
--       expert_join_requests, expert_invitations,
--       expert_follows, expert_profile_update_requests,
--       featured_experts_v2
--
-- 执行时间: 2026-04-04
-- ===========================================

BEGIN;

-- ==================== experts ====================
CREATE TABLE IF NOT EXISTS experts (
    id VARCHAR(8) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    name_zh VARCHAR(100),
    bio TEXT,
    bio_en TEXT,
    bio_zh TEXT,
    avatar TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    allow_applications BOOLEAN NOT NULL DEFAULT true,
    max_members INTEGER NOT NULL DEFAULT 20,
    member_count INTEGER NOT NULL DEFAULT 1,
    rating DECIMAL(3,2) NOT NULL DEFAULT 0.00,
    total_services INTEGER NOT NULL DEFAULT 0,
    completed_tasks INTEGER NOT NULL DEFAULT 0,
    completion_rate FLOAT NOT NULL DEFAULT 0.0,
    is_official BOOLEAN NOT NULL DEFAULT false,
    official_badge VARCHAR(50),
    stripe_account_id VARCHAR(255),
    stripe_connect_country VARCHAR(10),
    stripe_onboarding_complete BOOLEAN NOT NULL DEFAULT false,
    forum_category_id INTEGER,
    internal_group_id INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_expert_status CHECK (status IN ('active', 'inactive', 'suspended', 'dissolved'))
);

CREATE INDEX IF NOT EXISTS ix_experts_status ON experts(status);
CREATE INDEX IF NOT EXISTS ix_experts_rating ON experts(rating);

-- ==================== expert_members ====================
CREATE TABLE IF NOT EXISTS expert_members (
    id SERIAL PRIMARY KEY,
    expert_id VARCHAR(8) NOT NULL REFERENCES experts(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_member_role CHECK (role IN ('owner', 'admin', 'member')),
    CONSTRAINT chk_member_status CHECK (status IN ('active', 'left', 'removed')),
    CONSTRAINT uq_expert_member UNIQUE (expert_id, user_id)
);

CREATE INDEX IF NOT EXISTS ix_expert_members_user ON expert_members(user_id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS ix_expert_members_expert_role ON expert_members(expert_id, role) WHERE status = 'active';

-- ==================== expert_applications ====================
CREATE TABLE IF NOT EXISTS expert_applications (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expert_name VARCHAR(100) NOT NULL,
    bio TEXT,
    avatar TEXT,
    application_message TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    reviewed_by VARCHAR(5) REFERENCES admin_users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    review_comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_expert_app_status CHECK (status IN ('pending', 'approved', 'rejected'))
);

CREATE INDEX IF NOT EXISTS ix_expert_applications_user_status ON expert_applications(user_id, status);
-- 每个用户同时只能有一个 pending 申请
CREATE UNIQUE INDEX IF NOT EXISTS uq_expert_applications_pending
    ON expert_applications(user_id) WHERE status = 'pending';

-- ==================== expert_join_requests ====================
CREATE TABLE IF NOT EXISTS expert_join_requests (
    id SERIAL PRIMARY KEY,
    expert_id VARCHAR(8) NOT NULL REFERENCES experts(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    reviewed_by VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    CONSTRAINT chk_join_request_status CHECK (status IN ('pending', 'approved', 'rejected'))
);

-- 每个用户对每个团队同时只能有一个 pending 请求
CREATE UNIQUE INDEX IF NOT EXISTS uq_join_requests_pending
    ON expert_join_requests(expert_id, user_id) WHERE status = 'pending';

-- ==================== expert_invitations ====================
CREATE TABLE IF NOT EXISTS expert_invitations (
    id SERIAL PRIMARY KEY,
    expert_id VARCHAR(8) NOT NULL REFERENCES experts(id) ON DELETE CASCADE,
    inviter_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitee_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    CONSTRAINT chk_invitation_status CHECK (status IN ('pending', 'accepted', 'rejected', 'expired'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_invitations_pending
    ON expert_invitations(expert_id, invitee_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS ix_invitations_invitee ON expert_invitations(invitee_id) WHERE status = 'pending';

-- ==================== expert_follows ====================
CREATE TABLE IF NOT EXISTS expert_follows (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expert_id VARCHAR(8) NOT NULL REFERENCES experts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_expert_follow UNIQUE (user_id, expert_id)
);

CREATE INDEX IF NOT EXISTS ix_expert_follows_user ON expert_follows(user_id);
CREATE INDEX IF NOT EXISTS ix_expert_follows_expert ON expert_follows(expert_id);

-- ==================== expert_profile_update_requests ====================
CREATE TABLE IF NOT EXISTS expert_profile_update_requests (
    id SERIAL PRIMARY KEY,
    expert_id VARCHAR(8) NOT NULL REFERENCES experts(id) ON DELETE CASCADE,
    requester_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    new_name VARCHAR(100),
    new_bio TEXT,
    new_avatar TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    reviewed_by VARCHAR(5) REFERENCES admin_users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    review_comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_profile_update_status CHECK (status IN ('pending', 'approved', 'rejected'))
);

CREATE INDEX IF NOT EXISTS ix_profile_updates_expert ON expert_profile_update_requests(expert_id, status);
-- 每个达人同时只能有一个 pending 修改请求
CREATE UNIQUE INDEX IF NOT EXISTS uq_profile_updates_pending
    ON expert_profile_update_requests(expert_id) WHERE status = 'pending';

-- ==================== featured_experts_v2 ====================
-- 用 _v2 后缀避免和旧表冲突，迁移完成后再重命名
CREATE TABLE IF NOT EXISTS featured_experts_v2 (
    id SERIAL PRIMARY KEY,
    expert_id VARCHAR(8) NOT NULL REFERENCES experts(id) ON DELETE CASCADE,
    is_featured BOOLEAN NOT NULL DEFAULT true,
    display_order INTEGER NOT NULL DEFAULT 0,
    category VARCHAR(50),
    created_by VARCHAR(5) REFERENCES admin_users(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_featured_expert UNIQUE (expert_id)
);

COMMIT;
```

- [ ] **Step 2: 在数据库执行迁移**

Run: `psql $DATABASE_URL -f backend/migrations/158_create_expert_team_tables.sql`
Expected: 所有 CREATE TABLE / CREATE INDEX 成功，无错误

- [ ] **Step 3: Commit**

```bash
git add backend/migrations/158_create_expert_team_tables.sql
git commit -m "db: create expert team tables (migration 158)"
```

---

## Task 2: 后端模型定义

**Files:**
- Create: `backend/app/models_expert.py`
- Modify: `backend/app/models.py`

- [ ] **Step 1: 创建达人团队模型文件**

```python
"""达人团队体系模型

新的达人团队相关模型，独立文件避免 models.py 继续膨胀。
通过 models.py 末尾 import 合并到同一 metadata。
"""
import random
from sqlalchemy import (
    Column, Integer, String, Text, Boolean, Float, DateTime,
    ForeignKey, Index, UniqueConstraint, CheckConstraint,
    DECIMAL,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.models import Base
from app.utils.time_utils import get_utc_time


def generate_expert_id():
    """生成 8 位随机数字字符串作为达人 ID"""
    return str(random.randint(10000000, 99999999))


class Expert(Base):
    """达人团队实体"""
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
    forum_category_id = Column(Integer, nullable=True)
    internal_group_id = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())

    # Relationships
    members = relationship("ExpertMember", back_populates="expert", cascade="all, delete-orphan")
    follows = relationship("ExpertFollow", back_populates="expert", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_experts_status", status),
        Index("ix_experts_rating", rating),
        CheckConstraint(
            "status IN ('active', 'inactive', 'suspended', 'dissolved')",
            name="chk_expert_status"
        ),
    )


class ExpertMember(Base):
    """达人团队成员"""
    __tablename__ = "expert_members"

    id = Column(Integer, primary_key=True, index=True)
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
        Index("ix_expert_members_user", user_id, postgresql_where=(status == "active")),
        Index("ix_expert_members_expert_role", expert_id, role, postgresql_where=(status == "active")),
        CheckConstraint("role IN ('owner', 'admin', 'member')", name="chk_member_role"),
        CheckConstraint("status IN ('active', 'left', 'removed')", name="chk_member_status"),
    )


class ExpertApplication(Base):
    """达人创建申请（需管理员审核）"""
    __tablename__ = "expert_applications"

    id = Column(Integer, primary_key=True, index=True)
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
    user = relationship("User", backref="expert_applications")
    reviewer = relationship("AdminUser", backref="reviewed_expert_applications")

    __table_args__ = (
        Index("ix_expert_applications_user_status", user_id, status),
        CheckConstraint("status IN ('pending', 'approved', 'rejected')", name="chk_expert_app_status"),
    )


class ExpertJoinRequest(Base):
    """申请加入达人团队"""
    __tablename__ = "expert_join_requests"

    id = Column(Integer, primary_key=True, index=True)
    expert_id = Column(String(8), ForeignKey("experts.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    message = Column(Text, nullable=True)
    status = Column(String(20), nullable=False, default="pending")
    reviewed_by = Column(String(8), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    reviewed_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    expert = relationship("Expert", backref="join_requests")
    user = relationship("User", foreign_keys=[user_id], backref="expert_join_requests")
    reviewer_user = relationship("User", foreign_keys=[reviewed_by])

    __table_args__ = (
        CheckConstraint("status IN ('pending', 'approved', 'rejected')", name="chk_join_request_status"),
    )


class ExpertInvitation(Base):
    """邀请用户加入达人团队"""
    __tablename__ = "expert_invitations"

    id = Column(Integer, primary_key=True, index=True)
    expert_id = Column(String(8), ForeignKey("experts.id", ondelete="CASCADE"), nullable=False)
    inviter_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    invitee_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    status = Column(String(20), nullable=False, default="pending")
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    responded_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    expert = relationship("Expert", backref="invitations")
    inviter = relationship("User", foreign_keys=[inviter_id], backref="sent_expert_invitations")
    invitee = relationship("User", foreign_keys=[invitee_id], backref="received_expert_invitations")

    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'accepted', 'rejected', 'expired')",
            name="chk_invitation_status"
        ),
    )


class ExpertFollow(Base):
    """关注达人"""
    __tablename__ = "expert_follows"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    expert_id = Column(String(8), ForeignKey("experts.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())

    # Relationships
    user = relationship("User", backref="expert_follows")
    expert = relationship("Expert", back_populates="follows")

    __table_args__ = (
        UniqueConstraint("user_id", "expert_id", name="uq_expert_follow"),
        Index("ix_expert_follows_user", user_id),
        Index("ix_expert_follows_expert", expert_id),
    )


class ExpertProfileUpdateRequest(Base):
    """达人信息修改请求（需管理员审核）"""
    __tablename__ = "expert_profile_update_requests"

    id = Column(Integer, primary_key=True, index=True)
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
    expert = relationship("Expert", backref="profile_update_requests")
    requester = relationship("User", backref="expert_profile_update_requests")
    reviewer = relationship("AdminUser", backref="reviewed_expert_profile_updates")

    __table_args__ = (
        Index("ix_profile_updates_expert", expert_id, status),
        CheckConstraint("status IN ('pending', 'approved', 'rejected')", name="chk_profile_update_status"),
    )


class FeaturedExpertV2(Base):
    """精选达人（展示控制，不存实体数据）"""
    __tablename__ = "featured_experts_v2"

    id = Column(Integer, primary_key=True, index=True)
    expert_id = Column(String(8), ForeignKey("experts.id", ondelete="CASCADE"), nullable=False, unique=True)
    is_featured = Column(Boolean, nullable=False, default=True)
    display_order = Column(Integer, nullable=False, default=0)
    category = Column(String(50), nullable=True)
    created_by = Column(String(5), ForeignKey("admin_users.id", ondelete="RESTRICT"), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_time, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), default=get_utc_time, onupdate=get_utc_time, server_default=func.now())

    # Relationships
    expert = relationship("Expert", backref="featured_entry")
    creator = relationship("AdminUser", backref="featured_experts_created")
```

- [ ] **Step 2: 在 models.py 末尾导入新模型**

在 `backend/app/models.py` 文件末尾追加：

```python
# 达人团队体系模型（独立文件，合并到同一 metadata）
from app.models_expert import (  # noqa: E402, F401
    Expert,
    ExpertMember,
    ExpertApplication,
    ExpertJoinRequest,
    ExpertInvitation,
    ExpertFollow,
    ExpertProfileUpdateRequest,
    FeaturedExpertV2,
    generate_expert_id,
)
```

- [ ] **Step 3: 验证模型可正常导入**

Run: `cd backend && python -c "from app.models import Expert, ExpertMember; print('OK')"`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add backend/app/models_expert.py backend/app/models.py
git commit -m "feat: add expert team SQLAlchemy models"
```

---

## Task 3: Pydantic Schemas

**Files:**
- Create: `backend/app/schemas_expert.py`

- [ ] **Step 1: 创建 schemas 文件**

```python
"""达人团队体系 Pydantic Schemas"""
import datetime
from typing import Optional, List, Literal
from pydantic import BaseModel, Field


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
    created_at: datetime.datetime
    is_following: bool = False  # 当前用户是否关注（接口层填充）

    class Config:
        from_attributes = True


class ExpertDetailOut(ExpertOut):
    members: List["ExpertMemberOut"] = []
    is_featured: bool = False


# ==================== ExpertMember ====================

class ExpertMemberOut(BaseModel):
    id: int
    user_id: str
    user_name: Optional[str] = None
    user_avatar: Optional[str] = None
    role: str
    status: str
    joined_at: datetime.datetime

    class Config:
        from_attributes = True


# ==================== ExpertApplication (创建达人) ====================

class ExpertApplicationCreate(BaseModel):
    expert_name: str = Field(..., max_length=100)
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
```

- [ ] **Step 2: 验证 schemas 可正常导入**

Run: `cd backend && python -c "from app.schemas_expert import ExpertOut, ExpertApplicationCreate; print('OK')"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add backend/app/schemas_expert.py
git commit -m "feat: add expert team Pydantic schemas"
```

---

## Task 4: 达人创建/申请路由

**Files:**
- Create: `backend/app/expert_routes.py`
- Modify: `backend/app/main.py`

- [ ] **Step 1: 创建路由文件 — 申请创建达人 + 查看申请状态**

```python
"""达人团队用户侧路由"""
import logging
from typing import List, Optional
from datetime import datetime, timezone

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    Request,
    status,
)
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import IntegrityError

from app import models
from app.models_expert import (
    Expert, ExpertMember, ExpertApplication,
    ExpertJoinRequest, ExpertInvitation, ExpertFollow,
    ExpertProfileUpdateRequest, generate_expert_id,
)
from app.schemas_expert import (
    ExpertOut, ExpertDetailOut, ExpertMemberOut,
    ExpertApplicationCreate, ExpertApplicationOut,
    ExpertJoinRequestCreate, ExpertJoinRequestOut, ExpertJoinRequestReview,
    ExpertInvitationCreate, ExpertInvitationOut, ExpertInvitationResponse,
    ExpertRoleChange, ExpertTransfer,
    ExpertProfileUpdateCreate, ExpertProfileUpdateOut,
)
from app.deps import get_async_db_dependency
from app.async_routers import get_current_user_secure, get_current_user_optional
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

expert_router = APIRouter(prefix="/api/experts", tags=["experts"])


# ==================== 权限检查工具函数 ====================

async def _get_member_or_403(
    db: AsyncSession, expert_id: str, user_id: str, required_roles: list[str] | None = None
) -> ExpertMember:
    """检查用户是否为达人活跃成员，可选检查角色"""
    query = select(ExpertMember).where(
        and_(
            ExpertMember.expert_id == expert_id,
            ExpertMember.user_id == user_id,
            ExpertMember.status == "active",
        )
    )
    result = await db.execute(query)
    member = result.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=403, detail="You are not a member of this expert team")
    if required_roles and member.role not in required_roles:
        raise HTTPException(status_code=403, detail=f"Required role: {required_roles}")
    return member


async def _get_expert_or_404(db: AsyncSession, expert_id: str) -> Expert:
    """获取达人或 404"""
    result = await db.execute(select(Expert).where(Expert.id == expert_id))
    expert = result.scalar_one_or_none()
    if not expert:
        raise HTTPException(status_code=404, detail="Expert team not found")
    return expert


# ==================== 申请创建达人 ====================

@expert_router.post("/apply", response_model=ExpertApplicationOut)
async def apply_to_create_expert(
    data: ExpertApplicationCreate,
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """申请创建达人团队，需管理员审核"""
    # 检查是否已有 pending 申请
    existing = await db.execute(
        select(ExpertApplication).where(
            and_(
                ExpertApplication.user_id == current_user.id,
                ExpertApplication.status == "pending",
            )
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="You already have a pending application")

    application = ExpertApplication(
        user_id=current_user.id,
        expert_name=data.expert_name,
        bio=data.bio,
        avatar=data.avatar,
        application_message=data.application_message,
    )
    db.add(application)
    await db.commit()
    await db.refresh(application)
    return application


@expert_router.get("/my-applications", response_model=List[ExpertApplicationOut])
async def get_my_applications(
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """查看我的达人申请列表"""
    result = await db.execute(
        select(ExpertApplication)
        .where(ExpertApplication.user_id == current_user.id)
        .order_by(ExpertApplication.created_at.desc())
    )
    return result.scalars().all()


# ==================== 我的达人团队 ====================

@expert_router.get("/my-teams", response_model=List[ExpertOut])
async def get_my_teams(
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取我关联的所有达人团队"""
    result = await db.execute(
        select(Expert)
        .join(ExpertMember, ExpertMember.expert_id == Expert.id)
        .where(
            and_(
                ExpertMember.user_id == current_user.id,
                ExpertMember.status == "active",
                Expert.status.in_(["active", "inactive"]),
            )
        )
        .order_by(Expert.created_at.desc())
    )
    return result.scalars().all()


# ==================== 达人详情 ====================

@expert_router.get("/{expert_id}", response_model=ExpertDetailOut)
async def get_expert_detail(
    expert_id: str,
    current_user=Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取达人详情（含成员列表）"""
    expert = await _get_expert_or_404(db, expert_id)

    # 成员列表
    members_result = await db.execute(
        select(ExpertMember, models.User)
        .join(models.User, models.User.id == ExpertMember.user_id)
        .where(
            and_(
                ExpertMember.expert_id == expert_id,
                ExpertMember.status == "active",
            )
        )
        .order_by(
            # owner 排第一，admin 第二，member 第三
            func.array_position(func.cast(["owner", "admin", "member"], type_=None), ExpertMember.role),
            ExpertMember.joined_at,
        )
    )
    members = []
    for member, user in members_result.all():
        members.append(ExpertMemberOut(
            id=member.id,
            user_id=member.user_id,
            user_name=user.name,
            user_avatar=user.avatar,
            role=member.role,
            status=member.status,
            joined_at=member.joined_at,
        ))

    # 关注状态
    is_following = False
    if current_user:
        follow_result = await db.execute(
            select(ExpertFollow).where(
                and_(
                    ExpertFollow.user_id == current_user.id,
                    ExpertFollow.expert_id == expert_id,
                )
            )
        )
        is_following = follow_result.scalar_one_or_none() is not None

    # 是否精选
    from app.models_expert import FeaturedExpertV2
    featured_result = await db.execute(
        select(FeaturedExpertV2).where(
            and_(FeaturedExpertV2.expert_id == expert_id, FeaturedExpertV2.is_featured == True)
        )
    )
    is_featured = featured_result.scalar_one_or_none() is not None

    return ExpertDetailOut(
        **{c.name: getattr(expert, c.name) for c in Expert.__table__.columns},
        members=members,
        is_following=is_following,
        is_featured=is_featured,
    )


# ==================== 达人搜索 ====================

@expert_router.get("", response_model=List[ExpertOut])
async def list_experts(
    keyword: Optional[str] = None,
    category: Optional[str] = None,
    sort: str = Query("rating", regex="^(rating|created_at|completed_tasks)$"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user=Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """搜索/列表达人"""
    query = select(Expert).where(Expert.status == "active")

    if keyword:
        like_pattern = f"%{keyword}%"
        query = query.where(
            Expert.name.ilike(like_pattern) | Expert.name_en.ilike(like_pattern) | Expert.name_zh.ilike(like_pattern)
        )

    sort_map = {
        "rating": Expert.rating.desc(),
        "created_at": Expert.created_at.desc(),
        "completed_tasks": Expert.completed_tasks.desc(),
    }
    query = query.order_by(sort_map[sort]).offset(offset).limit(limit)

    result = await db.execute(query)
    experts = result.scalars().all()

    # 批量查关注状态
    if current_user and experts:
        expert_ids = [e.id for e in experts]
        follow_result = await db.execute(
            select(ExpertFollow.expert_id).where(
                and_(
                    ExpertFollow.user_id == current_user.id,
                    ExpertFollow.expert_id.in_(expert_ids),
                )
            )
        )
        followed_ids = {row[0] for row in follow_result.all()}
        return [
            ExpertOut(**{c.name: getattr(e, c.name) for c in Expert.__table__.columns}, is_following=e.id in followed_ids)
            for e in experts
        ]

    return experts


# ==================== 关注/取关达人 ====================

@expert_router.post("/{expert_id}/follow", response_model=dict)
async def toggle_follow_expert(
    expert_id: str,
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """关注/取消关注达人"""
    await _get_expert_or_404(db, expert_id)

    existing = await db.execute(
        select(ExpertFollow).where(
            and_(ExpertFollow.user_id == current_user.id, ExpertFollow.expert_id == expert_id)
        )
    )
    follow = existing.scalar_one_or_none()

    if follow:
        await db.delete(follow)
        await db.commit()
        return {"following": False}
    else:
        db.add(ExpertFollow(user_id=current_user.id, expert_id=expert_id))
        await db.commit()
        return {"following": True}


# ==================== 团队成员管理 ====================

@expert_router.get("/{expert_id}/members", response_model=List[ExpertMemberOut])
async def get_members(
    expert_id: str,
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取团队成员列表"""
    await _get_expert_or_404(db, expert_id)

    result = await db.execute(
        select(ExpertMember, models.User)
        .join(models.User, models.User.id == ExpertMember.user_id)
        .where(and_(ExpertMember.expert_id == expert_id, ExpertMember.status == "active"))
        .order_by(ExpertMember.joined_at)
    )
    return [
        ExpertMemberOut(
            id=member.id, user_id=member.user_id,
            user_name=user.name, user_avatar=user.avatar,
            role=member.role, status=member.status, joined_at=member.joined_at,
        )
        for member, user in result.all()
    ]


# ==================== 邀请加入团队 ====================

@expert_router.post("/{expert_id}/invite", response_model=ExpertInvitationOut)
async def invite_to_team(
    expert_id: str,
    data: ExpertInvitationCreate,
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """邀请用户加入达人团队（Owner/Admin）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    # 检查人数上限
    if expert.member_count >= expert.max_members:
        raise HTTPException(status_code=400, detail="Team member limit reached")

    # 检查被邀请人是否存在
    invitee = await db.execute(select(models.User).where(models.User.id == data.invitee_id))
    invitee_user = invitee.scalar_one_or_none()
    if not invitee_user:
        raise HTTPException(status_code=404, detail="User not found")

    # 检查是否已是成员
    existing_member = await db.execute(
        select(ExpertMember).where(
            and_(ExpertMember.expert_id == expert_id, ExpertMember.user_id == data.invitee_id, ExpertMember.status == "active")
        )
    )
    if existing_member.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="User is already a member")

    # 检查是否已有 pending 邀请
    existing_inv = await db.execute(
        select(ExpertInvitation).where(
            and_(ExpertInvitation.expert_id == expert_id, ExpertInvitation.invitee_id == data.invitee_id, ExpertInvitation.status == "pending")
        )
    )
    if existing_inv.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Invitation already pending")

    invitation = ExpertInvitation(
        expert_id=expert_id,
        inviter_id=current_user.id,
        invitee_id=data.invitee_id,
    )
    db.add(invitation)
    await db.commit()
    await db.refresh(invitation)

    return ExpertInvitationOut(
        id=invitation.id, expert_id=invitation.expert_id,
        inviter_id=invitation.inviter_id, invitee_id=invitation.invitee_id,
        invitee_name=invitee_user.name, invitee_avatar=invitee_user.avatar,
        status=invitation.status, created_at=invitation.created_at,
        responded_at=invitation.responded_at,
    )


# ==================== 响应邀请 ====================

@expert_router.post("/invitations/{invitation_id}/respond", response_model=dict)
async def respond_to_invitation(
    invitation_id: int,
    data: ExpertInvitationResponse,
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """接受/拒绝团队邀请"""
    result = await db.execute(
        select(ExpertInvitation).where(
            and_(ExpertInvitation.id == invitation_id, ExpertInvitation.invitee_id == current_user.id, ExpertInvitation.status == "pending")
        )
    )
    invitation = result.scalar_one_or_none()
    if not invitation:
        raise HTTPException(status_code=404, detail="Invitation not found or already responded")

    if data.action == "reject":
        invitation.status = "rejected"
        invitation.responded_at = get_utc_time()
        await db.commit()
        return {"status": "rejected"}

    # accept
    expert = await _get_expert_or_404(db, invitation.expert_id)
    if expert.member_count >= expert.max_members:
        raise HTTPException(status_code=400, detail="Team member limit reached")

    invitation.status = "accepted"
    invitation.responded_at = get_utc_time()

    # 检查是否有已存在的 left/removed 记录，复用
    existing = await db.execute(
        select(ExpertMember).where(
            and_(ExpertMember.expert_id == invitation.expert_id, ExpertMember.user_id == current_user.id)
        )
    )
    member = existing.scalar_one_or_none()
    if member:
        member.status = "active"
        member.role = "member"
        member.joined_at = get_utc_time()
        member.updated_at = get_utc_time()
    else:
        db.add(ExpertMember(
            expert_id=invitation.expert_id,
            user_id=current_user.id,
            role="member",
        ))

    expert.member_count += 1
    await db.commit()
    return {"status": "accepted"}


# ==================== 申请加入团队 ====================

@expert_router.post("/{expert_id}/join", response_model=ExpertJoinRequestOut)
async def request_to_join(
    expert_id: str,
    data: ExpertJoinRequestCreate,
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """申请加入达人团队"""
    expert = await _get_expert_or_404(db, expert_id)

    if not expert.allow_applications:
        raise HTTPException(status_code=400, detail="This team is not accepting applications")

    if expert.member_count >= expert.max_members:
        raise HTTPException(status_code=400, detail="Team member limit reached")

    # 检查是否已是成员
    existing_member = await db.execute(
        select(ExpertMember).where(
            and_(ExpertMember.expert_id == expert_id, ExpertMember.user_id == current_user.id, ExpertMember.status == "active")
        )
    )
    if existing_member.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="You are already a member")

    # 检查是否已有 pending 请求
    existing_req = await db.execute(
        select(ExpertJoinRequest).where(
            and_(ExpertJoinRequest.expert_id == expert_id, ExpertJoinRequest.user_id == current_user.id, ExpertJoinRequest.status == "pending")
        )
    )
    if existing_req.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Join request already pending")

    join_request = ExpertJoinRequest(
        expert_id=expert_id,
        user_id=current_user.id,
        message=data.message,
    )
    db.add(join_request)
    await db.commit()
    await db.refresh(join_request)

    return ExpertJoinRequestOut(
        id=join_request.id, expert_id=join_request.expert_id,
        user_id=join_request.user_id, message=join_request.message,
        status=join_request.status, created_at=join_request.created_at,
    )


# ==================== 审批加入申请（Owner/Admin） ====================

@expert_router.get("/{expert_id}/join-requests", response_model=List[ExpertJoinRequestOut])
async def get_join_requests(
    expert_id: str,
    status_filter: Optional[str] = Query(None, alias="status"),
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取加入申请列表（Owner/Admin）"""
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    query = select(ExpertJoinRequest, models.User).join(
        models.User, models.User.id == ExpertJoinRequest.user_id
    ).where(ExpertJoinRequest.expert_id == expert_id)

    if status_filter:
        query = query.where(ExpertJoinRequest.status == status_filter)

    query = query.order_by(ExpertJoinRequest.created_at.desc())
    result = await db.execute(query)

    return [
        ExpertJoinRequestOut(
            id=req.id, expert_id=req.expert_id, user_id=req.user_id,
            user_name=user.name, user_avatar=user.avatar,
            message=req.message, status=req.status,
            created_at=req.created_at, reviewed_at=req.reviewed_at,
        )
        for req, user in result.all()
    ]


@expert_router.put("/{expert_id}/join-requests/{request_id}", response_model=dict)
async def review_join_request(
    expert_id: str,
    request_id: int,
    data: ExpertJoinRequestReview,
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """审批加入申请（Owner/Admin）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner", "admin"])

    result = await db.execute(
        select(ExpertJoinRequest).where(
            and_(ExpertJoinRequest.id == request_id, ExpertJoinRequest.expert_id == expert_id, ExpertJoinRequest.status == "pending")
        )
    )
    join_request = result.scalar_one_or_none()
    if not join_request:
        raise HTTPException(status_code=404, detail="Join request not found or already reviewed")

    join_request.reviewed_by = current_user.id
    join_request.reviewed_at = get_utc_time()

    if data.action == "reject":
        join_request.status = "rejected"
        await db.commit()
        return {"status": "rejected"}

    # approve
    if expert.member_count >= expert.max_members:
        raise HTTPException(status_code=400, detail="Team member limit reached")

    join_request.status = "approved"

    # 复用已有 left/removed 记录
    existing = await db.execute(
        select(ExpertMember).where(
            and_(ExpertMember.expert_id == expert_id, ExpertMember.user_id == join_request.user_id)
        )
    )
    member = existing.scalar_one_or_none()
    if member:
        member.status = "active"
        member.role = "member"
        member.joined_at = get_utc_time()
        member.updated_at = get_utc_time()
    else:
        db.add(ExpertMember(
            expert_id=expert_id,
            user_id=join_request.user_id,
            role="member",
        ))

    expert.member_count += 1
    await db.commit()
    return {"status": "approved"}


# ==================== 角色管理 ====================

@expert_router.put("/{expert_id}/members/{user_id}/role", response_model=dict)
async def change_member_role(
    expert_id: str,
    user_id: str,
    data: ExpertRoleChange,
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """变更成员角色（仅 Owner）"""
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner"])

    target = await db.execute(
        select(ExpertMember).where(
            and_(ExpertMember.expert_id == expert_id, ExpertMember.user_id == user_id, ExpertMember.status == "active")
        )
    )
    target_member = target.scalar_one_or_none()
    if not target_member:
        raise HTTPException(status_code=404, detail="Member not found")
    if target_member.role == "owner":
        raise HTTPException(status_code=400, detail="Cannot change owner's role, use transfer instead")

    target_member.role = data.role
    target_member.updated_at = get_utc_time()
    await db.commit()
    return {"role": data.role}


@expert_router.post("/{expert_id}/transfer", response_model=dict)
async def transfer_ownership(
    expert_id: str,
    data: ExpertTransfer,
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """转让 Owner（仅 Owner）"""
    owner_member = await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner"])

    target = await db.execute(
        select(ExpertMember).where(
            and_(ExpertMember.expert_id == expert_id, ExpertMember.user_id == data.new_owner_id, ExpertMember.status == "active")
        )
    )
    target_member = target.scalar_one_or_none()
    if not target_member:
        raise HTTPException(status_code=404, detail="Target member not found")

    # 转让
    target_member.role = "owner"
    target_member.updated_at = get_utc_time()
    owner_member.role = "admin"
    owner_member.updated_at = get_utc_time()
    await db.commit()
    return {"new_owner_id": data.new_owner_id}


# ==================== 移除成员 ====================

@expert_router.delete("/{expert_id}/members/{user_id}", response_model=dict)
async def remove_member(
    expert_id: str,
    user_id: str,
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """移除成员（仅 Owner）"""
    expert = await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner"])

    target = await db.execute(
        select(ExpertMember).where(
            and_(ExpertMember.expert_id == expert_id, ExpertMember.user_id == user_id, ExpertMember.status == "active")
        )
    )
    target_member = target.scalar_one_or_none()
    if not target_member:
        raise HTTPException(status_code=404, detail="Member not found")
    if target_member.role == "owner":
        raise HTTPException(status_code=400, detail="Cannot remove owner")

    target_member.status = "removed"
    target_member.updated_at = get_utc_time()
    expert.member_count = max(0, expert.member_count - 1)
    await db.commit()
    return {"removed": True}


# ==================== 退出团队 ====================

@expert_router.post("/{expert_id}/leave", response_model=dict)
async def leave_team(
    expert_id: str,
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """退出团队"""
    expert = await _get_expert_or_404(db, expert_id)
    member = await _get_member_or_403(db, expert_id, current_user.id)

    if member.role == "owner":
        raise HTTPException(status_code=400, detail="Owner cannot leave. Transfer ownership first.")

    member.status = "left"
    member.updated_at = get_utc_time()
    expert.member_count = max(0, expert.member_count - 1)
    await db.commit()
    return {"left": True}


# ==================== 达人信息修改请求 ====================

@expert_router.post("/{expert_id}/profile-update-request", response_model=ExpertProfileUpdateOut)
async def request_profile_update(
    expert_id: str,
    data: ExpertProfileUpdateCreate,
    current_user=Depends(get_current_user_secure),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """提交达人信息修改请求（仅 Owner）"""
    await _get_expert_or_404(db, expert_id)
    await _get_member_or_403(db, expert_id, current_user.id, required_roles=["owner"])

    if not data.new_name and not data.new_bio and not data.new_avatar:
        raise HTTPException(status_code=400, detail="At least one field must be provided")

    # 检查是否已有 pending 请求
    existing = await db.execute(
        select(ExpertProfileUpdateRequest).where(
            and_(ExpertProfileUpdateRequest.expert_id == expert_id, ExpertProfileUpdateRequest.status == "pending")
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="A pending update request already exists")

    request_obj = ExpertProfileUpdateRequest(
        expert_id=expert_id,
        requester_id=current_user.id,
        new_name=data.new_name,
        new_bio=data.new_bio,
        new_avatar=data.new_avatar,
    )
    db.add(request_obj)
    await db.commit()
    await db.refresh(request_obj)
    return request_obj
```

- [ ] **Step 2: 注册路由到 main.py**

在 `backend/app/main.py` 中，找到其他 router 注册的位置，追加：

```python
from app.expert_routes import expert_router
app.include_router(expert_router)
```

- [ ] **Step 3: 验证路由可正常加载**

Run: `cd backend && python -c "from app.expert_routes import expert_router; print(f'{len(expert_router.routes)} routes loaded')"`
Expected: 显示路由数量，无 import 错误

- [ ] **Step 4: Commit**

```bash
git add backend/app/expert_routes.py backend/app/main.py
git commit -m "feat: add expert team user-facing routes"
```

---

## Task 5: 管理员路由

**Files:**
- Create: `backend/app/admin_expert_routes.py`
- Modify: `backend/app/main.py`

- [ ] **Step 1: 创建管理员路由文件**

```python
"""达人团队管理员侧路由"""
import logging
from typing import List, Optional

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    status,
)
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app import models
from app.models_expert import (
    Expert, ExpertMember, ExpertApplication,
    ExpertProfileUpdateRequest, FeaturedExpertV2,
    generate_expert_id,
)
from app.schemas_expert import (
    ExpertApplicationOut, ExpertApplicationReview,
    ExpertProfileUpdateOut, ExpertProfileUpdateReview,
    ExpertOut,
)
from app.deps import get_async_db_dependency
from app.separate_auth_deps import get_current_admin
from app.utils.time_utils import get_utc_time

logger = logging.getLogger(__name__)

admin_expert_router = APIRouter(prefix="/api/admin/experts", tags=["admin-experts"])


# ==================== 达人申请审核 ====================

@admin_expert_router.get("/applications", response_model=List[ExpertApplicationOut])
async def list_applications(
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_admin=Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取达人申请列表"""
    query = select(ExpertApplication)
    if status_filter:
        query = query.where(ExpertApplication.status == status_filter)
    query = query.order_by(ExpertApplication.created_at.desc()).offset(offset).limit(limit)

    result = await db.execute(query)
    return result.scalars().all()


@admin_expert_router.post("/applications/{application_id}/review", response_model=dict)
async def review_application(
    application_id: int,
    data: ExpertApplicationReview,
    current_admin=Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """审核达人申请"""
    result = await db.execute(
        select(ExpertApplication).where(
            and_(ExpertApplication.id == application_id, ExpertApplication.status == "pending")
        )
    )
    application = result.scalar_one_or_none()
    if not application:
        raise HTTPException(status_code=404, detail="Application not found or already reviewed")

    application.reviewed_by = current_admin.id
    application.reviewed_at = get_utc_time()
    application.review_comment = data.review_comment

    if data.action == "reject":
        application.status = "rejected"
        await db.commit()
        return {"status": "rejected"}

    # approve: 创建达人团队
    application.status = "approved"

    # 生成唯一 ID
    while True:
        expert_id = generate_expert_id()
        existing = await db.execute(select(Expert).where(Expert.id == expert_id))
        if not existing.scalar_one_or_none():
            break

    expert = Expert(
        id=expert_id,
        name=application.expert_name,
        bio=application.bio,
        avatar=application.avatar,
    )
    db.add(expert)

    # 创建 owner 成员记录
    db.add(ExpertMember(
        expert_id=expert_id,
        user_id=application.user_id,
        role="owner",
    ))

    # TODO (Phase 3): 创建达人板块 forum_categories
    # TODO (Phase 4): 创建内部群聊 chat_groups

    await db.commit()
    return {"status": "approved", "expert_id": expert_id}


# ==================== 达人信息修改审核 ====================

@admin_expert_router.get("/profile-update-requests", response_model=List[ExpertProfileUpdateOut])
async def list_profile_update_requests(
    status_filter: Optional[str] = Query(None, alias="status"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_admin=Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """获取达人信息修改请求列表"""
    query = select(ExpertProfileUpdateRequest)
    if status_filter:
        query = query.where(ExpertProfileUpdateRequest.status == status_filter)
    query = query.order_by(ExpertProfileUpdateRequest.created_at.desc()).offset(offset).limit(limit)

    result = await db.execute(query)
    return result.scalars().all()


@admin_expert_router.post("/profile-update-requests/{request_id}/review", response_model=dict)
async def review_profile_update(
    request_id: int,
    data: ExpertProfileUpdateReview,
    current_admin=Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """审核达人信息修改请求"""
    result = await db.execute(
        select(ExpertProfileUpdateRequest).where(
            and_(ExpertProfileUpdateRequest.id == request_id, ExpertProfileUpdateRequest.status == "pending")
        )
    )
    request_obj = result.scalar_one_or_none()
    if not request_obj:
        raise HTTPException(status_code=404, detail="Request not found or already reviewed")

    request_obj.reviewed_by = current_admin.id
    request_obj.reviewed_at = get_utc_time()
    request_obj.review_comment = data.review_comment

    if data.action == "reject":
        request_obj.status = "rejected"
        await db.commit()
        return {"status": "rejected"}

    # approve: 更新达人信息
    request_obj.status = "approved"

    expert_result = await db.execute(select(Expert).where(Expert.id == request_obj.expert_id))
    expert = expert_result.scalar_one_or_none()
    if expert:
        if request_obj.new_name:
            expert.name = request_obj.new_name
        if request_obj.new_bio:
            expert.bio = request_obj.new_bio
        if request_obj.new_avatar:
            expert.avatar = request_obj.new_avatar
        expert.updated_at = get_utc_time()

    await db.commit()
    return {"status": "approved"}


# ==================== 达人列表管理 ====================

@admin_expert_router.get("", response_model=List[ExpertOut])
async def list_all_experts(
    status_filter: Optional[str] = Query(None, alias="status"),
    keyword: Optional[str] = None,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_admin=Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员：获取所有达人列表"""
    query = select(Expert)
    if status_filter:
        query = query.where(Expert.status == status_filter)
    if keyword:
        like_pattern = f"%{keyword}%"
        query = query.where(Expert.name.ilike(like_pattern))
    query = query.order_by(Expert.created_at.desc()).offset(offset).limit(limit)

    result = await db.execute(query)
    return result.scalars().all()


# ==================== 精选达人管理 ====================

@admin_expert_router.post("/{expert_id}/feature", response_model=dict)
async def toggle_featured(
    expert_id: str,
    current_admin=Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """设置/取消精选达人"""
    expert_result = await db.execute(select(Expert).where(Expert.id == expert_id))
    if not expert_result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Expert not found")

    featured_result = await db.execute(
        select(FeaturedExpertV2).where(FeaturedExpertV2.expert_id == expert_id)
    )
    featured = featured_result.scalar_one_or_none()

    if featured:
        featured.is_featured = not featured.is_featured
        featured.updated_at = get_utc_time()
        await db.commit()
        return {"is_featured": featured.is_featured}
    else:
        db.add(FeaturedExpertV2(
            expert_id=expert_id,
            created_by=current_admin.id,
        ))
        await db.commit()
        return {"is_featured": True}


# ==================== 达人状态管理 ====================

@admin_expert_router.put("/{expert_id}/status", response_model=dict)
async def update_expert_status(
    expert_id: str,
    new_status: str = Query(..., regex="^(active|inactive|suspended)$"),
    current_admin=Depends(get_current_admin),
    db: AsyncSession = Depends(get_async_db_dependency),
):
    """管理员：变更达人状态"""
    result = await db.execute(select(Expert).where(Expert.id == expert_id))
    expert = result.scalar_one_or_none()
    if not expert:
        raise HTTPException(status_code=404, detail="Expert not found")

    expert.status = new_status
    expert.updated_at = get_utc_time()
    await db.commit()
    return {"status": new_status}
```

- [ ] **Step 2: 注册管理员路由到 main.py**

在 `backend/app/main.py` 中追加：

```python
from app.admin_expert_routes import admin_expert_router
app.include_router(admin_expert_router)
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/admin_expert_routes.py backend/app/main.py
git commit -m "feat: add expert team admin routes"
```

---

## Task 6: 数据迁移脚本

**Files:**
- Create: `backend/migrations/159_migrate_expert_data.sql`

- [ ] **Step 1: 编写数据迁移 SQL**

```sql
-- ===========================================
-- 迁移 159: 迁移现有达人数据到新表
-- ===========================================
--
-- 将 task_experts → experts + expert_members
-- 将 featured_task_experts → featured_experts_v2
-- 保留旧表不删除
--
-- 执行时间: 2026-04-04
-- ===========================================

BEGIN;

-- 1. 创建临时映射表：old_expert_id (= user_id) → new_expert_id
CREATE TEMP TABLE expert_id_map (
    old_id VARCHAR(8) PRIMARY KEY,
    new_id VARCHAR(8) NOT NULL UNIQUE
);

-- 2. 为每个现有达人生成新的 8 位 ID 并插入映射表
-- 使用 PL/pgSQL 确保 ID 唯一
DO $$
DECLARE
    rec RECORD;
    new_id VARCHAR(8);
    id_exists BOOLEAN;
BEGIN
    FOR rec IN SELECT id FROM task_experts LOOP
        LOOP
            new_id := LPAD(FLOOR(RANDOM() * 100000000)::TEXT, 8, '0');
            SELECT EXISTS(SELECT 1 FROM expert_id_map WHERE expert_id_map.new_id = new_id) INTO id_exists;
            EXIT WHEN NOT id_exists;
        END LOOP;
        INSERT INTO expert_id_map (old_id, new_id) VALUES (rec.id, new_id);
    END LOOP;
END $$;

-- 3. 迁移 task_experts → experts
INSERT INTO experts (id, name, bio, avatar, status, rating, total_services, completed_tasks, is_official, official_badge, created_at, updated_at)
SELECT
    m.new_id,
    COALESCE(te.expert_name, u.name, 'Unnamed'),
    te.bio,
    te.avatar,
    te.status,
    te.rating,
    te.total_services,
    te.completed_tasks,
    te.is_official,
    te.official_badge,
    te.created_at,
    te.updated_at
FROM task_experts te
JOIN expert_id_map m ON m.old_id = te.id
LEFT JOIN users u ON u.id = te.id;

-- 4. 为每个达人创建 owner 成员记录
INSERT INTO expert_members (expert_id, user_id, role, status, joined_at)
SELECT
    m.new_id,
    te.id,  -- 原 expert id = user id
    'owner',
    'active',
    te.created_at
FROM task_experts te
JOIN expert_id_map m ON m.old_id = te.id;

-- 5. 迁移 featured_task_experts → featured_experts_v2
INSERT INTO featured_experts_v2 (expert_id, is_featured, display_order, category, created_by, created_at, updated_at)
SELECT
    m.new_id,
    CASE WHEN fte.is_featured = 1 THEN true ELSE false END,
    COALESCE(fte.display_order, 0),
    fte.category,
    fte.created_by,
    fte.created_at,
    fte.updated_at
FROM featured_task_experts fte
JOIN expert_id_map m ON m.old_id = fte.user_id;

-- 6. 保存映射表到永久表（供后续 Phase 2 服务迁移使用）
CREATE TABLE IF NOT EXISTS _expert_id_migration_map (
    old_id VARCHAR(8) PRIMARY KEY,
    new_id VARCHAR(8) NOT NULL UNIQUE
);
INSERT INTO _expert_id_migration_map SELECT * FROM expert_id_map
ON CONFLICT DO NOTHING;

COMMIT;
```

- [ ] **Step 2: 在测试环境执行迁移**

Run: `psql $DATABASE_URL -f backend/migrations/159_migrate_expert_data.sql`
Expected: 成功，无错误

- [ ] **Step 3: 验证迁移数据**

```sql
-- 验证 experts 数量与 task_experts 一致
SELECT COUNT(*) FROM experts;
SELECT COUNT(*) FROM task_experts;
-- 两个数字应该一致

-- 验证每个 expert 都有一个 owner
SELECT COUNT(*) FROM expert_members WHERE role = 'owner';
-- 应该等于 experts 数量

-- 验证映射表
SELECT COUNT(*) FROM _expert_id_migration_map;
```

- [ ] **Step 4: Commit**

```bash
git add backend/migrations/159_migrate_expert_data.sql
git commit -m "db: migrate existing expert data to new tables (migration 159)"
```

---

## Task 7: 路由注册验证

**Files:**
- Modify: `backend/app/main.py`

- [ ] **Step 1: 确认 main.py 中新路由已注册**

确认 `backend/app/main.py` 中包含以下两行（Task 4 和 Task 5 已添加）：

```python
from app.expert_routes import expert_router
app.include_router(expert_router)

from app.admin_expert_routes import admin_expert_router
app.include_router(admin_expert_router)
```

- [ ] **Step 2: 启动服务验证无报错**

Run: `cd backend && python -c "from app.main import app; print(f'Total routes: {len(app.routes)}')"`
Expected: 输出路由总数，无 import 错误

- [ ] **Step 3: 验证 API 文档可访问**

启动服务后访问 `/docs`，确认新端点出现在 `experts` 和 `admin-experts` 标签下。

- [ ] **Step 4: 最终 Commit**

```bash
git add -A
git commit -m "feat: complete expert team Phase 1a backend foundation"
```

---

## Self-Review Checklist

- [x] **Spec coverage:** experts 表 ✅, expert_members ✅, expert_applications ✅, expert_join_requests ✅, expert_invitations ✅, expert_follows ✅, expert_profile_update_requests ✅, featured_experts_v2 ✅, 数据迁移 ✅, 角色管理（提升/降级/转让/移除）✅, 申请/邀请/审批 ✅, 关注 ✅, 搜索 ✅
- [x] **Placeholder scan:** 两个 TODO 标记为 Phase 3/4 明确标注——达人板块和内部群聊在后续 phase 实现
- [x] **Type consistency:** generate_expert_id / ExpertMember / ExpertApplication 等名称全文一致
- [x] **Not in scope (deferred to Phase 1b/2+):** Flutter 前端, Admin 面板, services 表改造, 达人板块, 内部群聊, chat_participants
