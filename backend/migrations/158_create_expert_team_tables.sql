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
