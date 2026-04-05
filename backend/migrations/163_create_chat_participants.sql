-- ===========================================
-- 迁移 163: 创建任务聊天参与者表
-- ===========================================
--
-- chat_participants 记录被邀请进入任务聊天的额外参与者
-- 现有双人聊天逻辑不变，此表为空时走旧逻辑
--
-- 执行时间: 2026-04-04
-- ===========================================

BEGIN;

CREATE TABLE IF NOT EXISTS chat_participants (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'expert_member',
    invited_by VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_chat_participant_role CHECK (role IN ('client', 'expert_owner', 'expert_admin', 'expert_member')),
    CONSTRAINT uq_chat_participant UNIQUE (task_id, user_id)
);

CREATE INDEX IF NOT EXISTS ix_chat_participants_task ON chat_participants(task_id);
CREATE INDEX IF NOT EXISTS ix_chat_participants_user ON chat_participants(user_id);

COMMIT;
