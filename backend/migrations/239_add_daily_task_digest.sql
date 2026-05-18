-- backend/migrations/239_add_daily_task_digest.sql
-- 每日同城任务摘要推送：
-- 1. UserProfilePreference.daily_digest_enabled 开关
-- 2. daily_task_digest_pushes 表（按 user_id+sent_date 去重，每天最多一条）

BEGIN;

-- 偏好开关，默认 true（opt-out，用户可在设置里关闭）
-- 已存在的偏好行通过 DEFAULT TRUE 一并回填，新用户由 SQLAlchemy 模型 default 兜底
ALTER TABLE user_profile_preferences
    ADD COLUMN IF NOT EXISTS daily_digest_enabled BOOLEAN NOT NULL DEFAULT TRUE;

-- 每日摘要推送去重表
CREATE TABLE IF NOT EXISTS daily_task_digest_pushes (
    id          SERIAL PRIMARY KEY,
    user_id     VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    sent_date   DATE NOT NULL,
    task_count  INTEGER NOT NULL DEFAULT 0,
    city        VARCHAR(64),
    pushed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_daily_digest_user_date UNIQUE (user_id, sent_date)
);

CREATE INDEX IF NOT EXISTS ix_daily_task_digest_pushes_pushed_at
    ON daily_task_digest_pushes(pushed_at);

COMMIT;
