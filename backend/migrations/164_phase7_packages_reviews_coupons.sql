-- ===========================================
-- 迁移 164: Phase 7 — 套餐/次卡、评价回复、达人优惠券
-- ===========================================
--
-- 1. services 表加 package_type / total_sessions / bundle_service_ids
-- 2. user_service_packages + package_usage_logs 表
-- 3. reviews 表加 reply_content / reply_at / reply_by / expert_id
-- 4. coupons 表加 expert_id
--
-- 执行时间: 2026-04-04
-- ===========================================

BEGIN;

-- ==================== 1. 服务套餐字段 ====================

ALTER TABLE task_expert_services
    ADD COLUMN IF NOT EXISTS package_type VARCHAR(20) NOT NULL DEFAULT 'single',
    ADD COLUMN IF NOT EXISTS total_sessions INTEGER,
    ADD COLUMN IF NOT EXISTS bundle_service_ids JSONB;

ALTER TABLE task_expert_services
    DROP CONSTRAINT IF EXISTS chk_package_type;
ALTER TABLE task_expert_services
    ADD CONSTRAINT chk_package_type
    CHECK (package_type IN ('single', 'multi_session', 'bundle'));

-- ==================== 2. 用户套餐购买记录 ====================

CREATE TABLE IF NOT EXISTS user_service_packages (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    service_id INTEGER NOT NULL REFERENCES task_expert_services(id) ON DELETE CASCADE,
    expert_id VARCHAR(8) REFERENCES experts(id) ON DELETE SET NULL,
    total_sessions INTEGER NOT NULL,
    used_sessions INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    purchased_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
    CONSTRAINT chk_package_status CHECK (status IN ('active', 'exhausted', 'expired', 'refunded'))
);

CREATE INDEX IF NOT EXISTS ix_user_packages_user ON user_service_packages(user_id);
CREATE INDEX IF NOT EXISTS ix_user_packages_service ON user_service_packages(service_id);
CREATE INDEX IF NOT EXISTS ix_user_packages_expert ON user_service_packages(expert_id);

-- ==================== 3. 套餐核销记录 ====================

CREATE TABLE IF NOT EXISTS package_usage_logs (
    id SERIAL PRIMARY KEY,
    package_id INTEGER NOT NULL REFERENCES user_service_packages(id) ON DELETE CASCADE,
    used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    used_by VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    note TEXT
);

CREATE INDEX IF NOT EXISTS ix_package_usage_package ON package_usage_logs(package_id);

-- ==================== 4. 评价回复 ====================

ALTER TABLE reviews
    ADD COLUMN IF NOT EXISTS reply_content TEXT,
    ADD COLUMN IF NOT EXISTS reply_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS reply_by VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS expert_id VARCHAR(8) REFERENCES experts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_reviews_expert_id
    ON reviews(expert_id) WHERE expert_id IS NOT NULL;

-- ==================== 5. 达人优惠券 ====================

ALTER TABLE coupons
    ADD COLUMN IF NOT EXISTS expert_id VARCHAR(8) REFERENCES experts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS ix_coupons_expert_id
    ON coupons(expert_id) WHERE expert_id IS NOT NULL;

COMMIT;
