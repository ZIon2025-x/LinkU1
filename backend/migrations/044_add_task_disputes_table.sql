-- 添加任务争议记录表
-- 迁移文件：044_add_task_disputes_table.sql
-- 用于记录任务发布者对任务完成状态的争议

-- 创建任务争议记录表
CREATE TABLE IF NOT EXISTS task_disputes (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    poster_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',  -- pending, resolved, dismissed
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE NULL,
    resolved_by VARCHAR(8) NULL REFERENCES users(id) ON DELETE SET NULL,
    resolution_note TEXT NULL
);

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS ix_task_disputes_task_id ON task_disputes(task_id);
CREATE INDEX IF NOT EXISTS ix_task_disputes_status ON task_disputes(status);
CREATE INDEX IF NOT EXISTS ix_task_disputes_poster_id ON task_disputes(poster_id);
CREATE INDEX IF NOT EXISTS ix_task_disputes_created_at ON task_disputes(created_at);

-- 添加唯一约束：确保一个任务只有一个活跃的争议（status = 'pending'）
CREATE UNIQUE INDEX IF NOT EXISTS uix_task_disputes_active_task ON task_disputes(task_id) WHERE status = 'pending';

-- 添加注释
COMMENT ON TABLE task_disputes IS '任务争议记录表，记录任务发布者对任务完成状态的争议';
COMMENT ON COLUMN task_disputes.id IS '争议记录ID';
COMMENT ON COLUMN task_disputes.task_id IS '关联的任务ID';
COMMENT ON COLUMN task_disputes.poster_id IS '任务发布者ID';
COMMENT ON COLUMN task_disputes.reason IS '争议原因';
COMMENT ON COLUMN task_disputes.status IS '争议状态：pending（待处理）, resolved（已解决）, dismissed（已驳回）';
COMMENT ON COLUMN task_disputes.created_at IS '创建时间';
COMMENT ON COLUMN task_disputes.resolved_at IS '处理时间';
COMMENT ON COLUMN task_disputes.resolved_by IS '处理的管理员ID';
COMMENT ON COLUMN task_disputes.resolution_note IS '处理备注';

