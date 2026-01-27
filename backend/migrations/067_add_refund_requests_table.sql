-- 添加退款申请记录表
-- 迁移文件：067_add_refund_requests_table.sql
-- 用于记录任务发布者在任务待确认状态时申请的退款

-- 创建退款申请记录表
CREATE TABLE IF NOT EXISTS refund_requests (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    poster_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason TEXT NOT NULL,  -- 退款原因说明
    evidence_files TEXT NULL,  -- JSON数组存储证据文件ID列表
    refund_amount DECIMAL(12, 2) NULL,  -- 申请退款金额（NULL表示全额退款）
    status VARCHAR(20) DEFAULT 'pending',  -- pending, approved, rejected, processing, completed, cancelled
    admin_comment TEXT NULL,  -- 管理员审核备注
    reviewed_by VARCHAR(8) NULL REFERENCES users(id) ON DELETE SET NULL,  -- 审核的管理员ID
    reviewed_at TIMESTAMP WITH TIME ZONE NULL,  -- 审核时间
    refund_intent_id VARCHAR(255) NULL,  -- Stripe Refund ID（如果使用Stripe退款）
    refund_transfer_id VARCHAR(255) NULL,  -- 反向转账ID（如果已转账需要撤销）
    processed_at TIMESTAMP WITH TIME ZONE NULL,  -- 退款处理时间
    completed_at TIMESTAMP WITH TIME ZONE NULL,  -- 退款完成时间
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS ix_refund_requests_task_id ON refund_requests(task_id);
CREATE INDEX IF NOT EXISTS ix_refund_requests_poster_id ON refund_requests(poster_id);
CREATE INDEX IF NOT EXISTS ix_refund_requests_status ON refund_requests(status);
CREATE INDEX IF NOT EXISTS ix_refund_requests_created_at ON refund_requests(created_at);
CREATE INDEX IF NOT EXISTS ix_refund_requests_reviewed_at ON refund_requests(reviewed_at);

-- 添加唯一约束：确保一个任务只有一个活跃的退款申请（status = 'pending' 或 'processing'）
CREATE UNIQUE INDEX IF NOT EXISTS uix_refund_requests_active_task ON refund_requests(task_id) 
WHERE status IN ('pending', 'processing');

-- 添加注释
COMMENT ON TABLE refund_requests IS '退款申请记录表，记录任务发布者在任务待确认状态时申请的退款';
COMMENT ON COLUMN refund_requests.id IS '退款申请ID';
COMMENT ON COLUMN refund_requests.task_id IS '关联的任务ID';
COMMENT ON COLUMN refund_requests.poster_id IS '任务发布者ID';
COMMENT ON COLUMN refund_requests.reason IS '退款原因说明';
COMMENT ON COLUMN refund_requests.evidence_files IS '证据文件ID列表（JSON数组格式）';
COMMENT ON COLUMN refund_requests.refund_amount IS '申请退款金额（NULL表示全额退款）';
COMMENT ON COLUMN refund_requests.status IS '退款状态：pending（待审核）, approved（已批准）, rejected（已拒绝）, processing（处理中）, completed（已完成）, cancelled（已取消）';
COMMENT ON COLUMN refund_requests.admin_comment IS '管理员审核备注';
COMMENT ON COLUMN refund_requests.reviewed_by IS '审核的管理员ID';
COMMENT ON COLUMN refund_requests.reviewed_at IS '审核时间';
COMMENT ON COLUMN refund_requests.refund_intent_id IS 'Stripe Refund ID（如果使用Stripe退款）';
COMMENT ON COLUMN refund_requests.refund_transfer_id IS '反向转账ID（如果已转账需要撤销）';
COMMENT ON COLUMN refund_requests.processed_at IS '退款处理时间';
COMMENT ON COLUMN refund_requests.completed_at IS '退款完成时间';
COMMENT ON COLUMN refund_requests.created_at IS '创建时间';
COMMENT ON COLUMN refund_requests.updated_at IS '更新时间';
