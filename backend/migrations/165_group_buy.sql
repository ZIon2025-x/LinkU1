-- ===========================================
-- 迁移 165: 拼单模式
-- ===========================================
--
-- 1. activities 表加拼单字段
-- 2. group_buy_participants 表
--
-- 执行时间: 2026-04-04
-- ===========================================

BEGIN;

-- ==================== 1. activities 拼单字段 ====================

ALTER TABLE activities
    ADD COLUMN IF NOT EXISTS is_group_buy BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS group_buy_min INTEGER,
    ADD COLUMN IF NOT EXISTS group_buy_deadline TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS group_buy_task_mode VARCHAR(20) DEFAULT 'individual',
    ADD COLUMN IF NOT EXISTS group_buy_multi_round BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS group_buy_current_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS group_buy_round INTEGER NOT NULL DEFAULT 1;

ALTER TABLE activities
    DROP CONSTRAINT IF EXISTS chk_group_buy_task_mode;
ALTER TABLE activities
    ADD CONSTRAINT chk_group_buy_task_mode
    CHECK (group_buy_task_mode IS NULL OR group_buy_task_mode IN ('individual', 'shared'));

CREATE INDEX IF NOT EXISTS ix_activities_group_buy
    ON activities(is_group_buy) WHERE is_group_buy = true;

-- ==================== 2. group_buy_participants ====================

CREATE TABLE IF NOT EXISTS group_buy_participants (
    id SERIAL PRIMARY KEY,
    activity_id INTEGER NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    round INTEGER NOT NULL DEFAULT 1,
    status VARCHAR(20) NOT NULL DEFAULT 'joined',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    cancelled_at TIMESTAMPTZ,
    CONSTRAINT chk_gbp_status CHECK (status IN ('joined', 'confirmed', 'cancelled', 'expired')),
    CONSTRAINT uq_gbp_activity_user_round UNIQUE (activity_id, user_id, round)
);

CREATE INDEX IF NOT EXISTS ix_gbp_activity ON group_buy_participants(activity_id, round);
CREATE INDEX IF NOT EXISTS ix_gbp_user ON group_buy_participants(user_id);

COMMIT;
