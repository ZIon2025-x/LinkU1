-- 158_create_expert_team_tables.sql
-- 创建达人团队系统相关表
-- 达人(expert)成为独立实体，与用户多对多关联，不再与 users 1:1 绑定
-- 创建时间: 2026-04-04

BEGIN;

-- ==================== 达人团队实体 ====================
CREATE TABLE IF NOT EXISTS experts (
    id                      VARCHAR(8)      PRIMARY KEY,
    name                    VARCHAR(100)    NOT NULL,
    name_zh                 VARCHAR(100),
    name_en                 VARCHAR(100),
    bio                     TEXT,
    bio_zh                  TEXT,
    bio_en                  TEXT,
    avatar_url              TEXT,
    status                  VARCHAR(20)     NOT NULL DEFAULT 'active'
                                CHECK (status IN ('active', 'inactive', 'suspended', 'dissolved')),
    rating_avg              NUMERIC(3,2)    NOT NULL DEFAULT 0,
    rating_count            INTEGER         NOT NULL DEFAULT 0,
    stripe_account_id       VARCHAR(100),
    stripe_onboarding_done  BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_experts_status ON experts(status);

-- ==================== 团队成员 ====================
CREATE TABLE IF NOT EXISTS expert_members (
    id          SERIAL          PRIMARY KEY,
    expert_id   VARCHAR(8)      NOT NULL REFERENCES experts(id) ON DELETE CASCADE,
    user_id     VARCHAR(8)      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role        VARCHAR(20)     NOT NULL DEFAULT 'member'
                    CHECK (role IN ('owner', 'admin', 'member')),
    status      VARCHAR(20)     NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'left', 'removed')),
    joined_at   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (expert_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_expert_members_expert_id   ON expert_members(expert_id);
CREATE INDEX IF NOT EXISTS idx_expert_members_user_id     ON expert_members(user_id);
-- 只对活跃成员建局部索引，加速常用查询
CREATE INDEX IF NOT EXISTS idx_expert_members_active_expert
    ON expert_members(expert_id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_expert_members_active_user
    ON expert_members(user_id) WHERE status = 'active';

-- ==================== 达人创建申请 ====================
-- 用户申请创建一个新的达人团队，须管理员审核
CREATE TABLE IF NOT EXISTS expert_applications (
    id              SERIAL          PRIMARY KEY,
    applicant_id    VARCHAR(8)      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    proposed_name   VARCHAR(100)    NOT NULL,
    proposed_bio    TEXT,
    status          VARCHAR(20)     NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by     VARCHAR(5)      REFERENCES admin_users(id) ON DELETE SET NULL,
    review_note     TEXT,
    -- 审核通过后关联创建的达人实体
    expert_id       VARCHAR(8)      REFERENCES experts(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expert_applications_applicant ON expert_applications(applicant_id);
CREATE INDEX IF NOT EXISTS idx_expert_applications_status    ON expert_applications(status);
-- 每个用户同时只能有一个 pending 申请
CREATE UNIQUE INDEX IF NOT EXISTS uidx_expert_applications_one_pending_per_user
    ON expert_applications(applicant_id) WHERE status = 'pending';

-- ==================== 申请加入团队 ====================
-- 用户主动申请加入已有达人团队
CREATE TABLE IF NOT EXISTS expert_join_requests (
    id          SERIAL          PRIMARY KEY,
    expert_id   VARCHAR(8)      NOT NULL REFERENCES experts(id) ON DELETE CASCADE,
    user_id     VARCHAR(8)      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message     TEXT,
    status      VARCHAR(20)     NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    reviewed_by VARCHAR(8)      REFERENCES users(id) ON DELETE SET NULL,
    review_note TEXT,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expert_join_requests_expert ON expert_join_requests(expert_id);
CREATE INDEX IF NOT EXISTS idx_expert_join_requests_user   ON expert_join_requests(user_id);
-- 每个 (expert, user) 同时只能有一个 pending 申请
CREATE UNIQUE INDEX IF NOT EXISTS uidx_expert_join_requests_one_pending
    ON expert_join_requests(expert_id, user_id) WHERE status = 'pending';

-- ==================== 邀请加入团队 ====================
-- 达人 owner/admin 邀请用户加入团队
CREATE TABLE IF NOT EXISTS expert_invitations (
    id          SERIAL          PRIMARY KEY,
    expert_id   VARCHAR(8)      NOT NULL REFERENCES experts(id) ON DELETE CASCADE,
    inviter_id  VARCHAR(8)      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitee_id  VARCHAR(8)      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role        VARCHAR(20)     NOT NULL DEFAULT 'member'
                    CHECK (role IN ('admin', 'member')),
    message     TEXT,
    status      VARCHAR(20)     NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
    expires_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expert_invitations_expert  ON expert_invitations(expert_id);
CREATE INDEX IF NOT EXISTS idx_expert_invitations_invitee ON expert_invitations(invitee_id);
-- 每个 (expert, invitee) 同时只能有一个 pending 邀请
CREATE UNIQUE INDEX IF NOT EXISTS uidx_expert_invitations_one_pending
    ON expert_invitations(expert_id, invitee_id) WHERE status = 'pending';

-- ==================== 关注达人 ====================
CREATE TABLE IF NOT EXISTS expert_follows (
    id          SERIAL          PRIMARY KEY,
    expert_id   VARCHAR(8)      NOT NULL REFERENCES experts(id) ON DELETE CASCADE,
    user_id     VARCHAR(8)      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (expert_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_expert_follows_expert ON expert_follows(expert_id);
CREATE INDEX IF NOT EXISTS idx_expert_follows_user   ON expert_follows(user_id);

-- ==================== 达人信息修改请求 ====================
-- 达人修改名称/简介等需管理员审核的信息变更申请
CREATE TABLE IF NOT EXISTS expert_profile_update_requests (
    id              SERIAL          PRIMARY KEY,
    expert_id       VARCHAR(8)      NOT NULL REFERENCES experts(id) ON DELETE CASCADE,
    requested_by    VARCHAR(8)      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- 变更字段快照（JSON），仅存拟修改的字段
    proposed_fields JSONB           NOT NULL DEFAULT '{}',
    status          VARCHAR(20)     NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by     VARCHAR(5)      REFERENCES admin_users(id) ON DELETE SET NULL,
    review_note     TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expert_profile_updates_expert ON expert_profile_update_requests(expert_id);
CREATE INDEX IF NOT EXISTS idx_expert_profile_updates_status ON expert_profile_update_requests(status);
-- 每个达人同时只能有一个 pending 修改申请
CREATE UNIQUE INDEX IF NOT EXISTS uidx_expert_profile_updates_one_pending
    ON expert_profile_update_requests(expert_id) WHERE status = 'pending';

-- ==================== 精选达人 (v2) ====================
-- 仅用于展示控制，不复制达人实体数据
-- 使用 featured_experts_v2 避免与现有 featured_task_experts 表冲突
CREATE TABLE IF NOT EXISTS featured_experts_v2 (
    id          SERIAL          PRIMARY KEY,
    expert_id   VARCHAR(8)      NOT NULL REFERENCES experts(id) ON DELETE CASCADE,
    sort_order  INTEGER         NOT NULL DEFAULT 0,
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_by  VARCHAR(5)      REFERENCES admin_users(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    UNIQUE (expert_id)
);

CREATE INDEX IF NOT EXISTS idx_featured_experts_v2_active     ON featured_experts_v2(is_active, sort_order);

COMMIT;
