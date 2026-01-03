-- 添加支付转账记录表（用于审计和重试）
-- 迁移文件：041_add_payment_transfer_table.sql

-- 创建支付转账记录表
CREATE TABLE IF NOT EXISTS payment_transfers (
    id BIGSERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    taker_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    poster_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    transfer_id VARCHAR(255) NULL,  -- Stripe Transfer ID
    amount DECIMAL(12, 2) NOT NULL,  -- 转账金额
    currency VARCHAR(3) DEFAULT 'GBP',
    status VARCHAR(20) DEFAULT 'pending',  -- pending, succeeded, failed, retrying
    retry_count INTEGER DEFAULT 0,  -- 重试次数
    max_retries INTEGER DEFAULT 5,  -- 最大重试次数
    last_error TEXT NULL,  -- 最后一次错误信息
    next_retry_at TIMESTAMP WITH TIME ZONE NULL,  -- 下次重试时间
    extra_metadata JSONB NULL,  -- 额外元数据（使用 extra_metadata 避免与 SQLAlchemy 的 metadata 属性冲突）
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    succeeded_at TIMESTAMP WITH TIME ZONE NULL  -- 成功时间
);

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS ix_payment_transfer_task ON payment_transfers(task_id);
CREATE INDEX IF NOT EXISTS ix_payment_transfer_taker ON payment_transfers(taker_id);
CREATE INDEX IF NOT EXISTS ix_payment_transfer_status ON payment_transfers(status);
CREATE INDEX IF NOT EXISTS ix_payment_transfer_retry ON payment_transfers(next_retry_at) WHERE status = 'retrying';
CREATE INDEX IF NOT EXISTS ix_payment_transfer_created ON payment_transfers(created_at);

-- 添加注释
COMMENT ON TABLE payment_transfers IS '支付转账记录表，记录任务完成后的转账信息，支持重试机制';
COMMENT ON COLUMN payment_transfers.id IS '转账记录ID';
COMMENT ON COLUMN payment_transfers.task_id IS '关联的任务ID';
COMMENT ON COLUMN payment_transfers.taker_id IS '任务接受人ID';
COMMENT ON COLUMN payment_transfers.poster_id IS '任务发布者ID';
COMMENT ON COLUMN payment_transfers.transfer_id IS 'Stripe Transfer ID';
COMMENT ON COLUMN payment_transfers.amount IS '转账金额';
COMMENT ON COLUMN payment_transfers.currency IS '货币代码';
COMMENT ON COLUMN payment_transfers.status IS '转账状态：pending, succeeded, failed, retrying';
COMMENT ON COLUMN payment_transfers.retry_count IS '重试次数';
COMMENT ON COLUMN payment_transfers.max_retries IS '最大重试次数';
COMMENT ON COLUMN payment_transfers.last_error IS '最后一次错误信息';
COMMENT ON COLUMN payment_transfers.next_retry_at IS '下次重试时间';
COMMENT ON COLUMN payment_transfers.extra_metadata IS '额外元数据（JSON格式，使用 extra_metadata 避免与 SQLAlchemy 的 metadata 属性冲突）';
COMMENT ON COLUMN payment_transfers.created_at IS '创建时间';
COMMENT ON COLUMN payment_transfers.updated_at IS '更新时间';
COMMENT ON COLUMN payment_transfers.succeeded_at IS '成功时间';

