-- 添加支付历史记录表
-- 迁移文件：040_add_payment_history_table.sql

-- 创建支付历史记录表
CREATE TABLE IF NOT EXISTS payment_history (
    id BIGSERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    payment_intent_id VARCHAR(255) NULL,
    payment_method VARCHAR(20) NOT NULL,
    total_amount BIGINT NOT NULL,
    points_used BIGINT DEFAULT 0,
    coupon_discount BIGINT DEFAULT 0,
    stripe_amount BIGINT NULL,
    final_amount BIGINT NOT NULL,
    currency VARCHAR(3) DEFAULT 'GBP',
    status VARCHAR(20) DEFAULT 'pending',
    application_fee BIGINT NULL,
    escrow_amount DECIMAL(12, 2) NULL,
    coupon_usage_log_id BIGINT NULL REFERENCES coupon_usage_logs(id) ON DELETE SET NULL,
    metadata JSONB NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS ix_payment_history_task ON payment_history(task_id);
CREATE INDEX IF NOT EXISTS ix_payment_history_user ON payment_history(user_id);
CREATE INDEX IF NOT EXISTS ix_payment_history_payment_intent ON payment_history(payment_intent_id) WHERE payment_intent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_payment_history_status ON payment_history(status);
CREATE INDEX IF NOT EXISTS ix_payment_history_created ON payment_history(created_at);

-- 添加注释
COMMENT ON TABLE payment_history IS '支付历史记录表，记录所有任务支付的详细信息';
COMMENT ON COLUMN payment_history.id IS '支付记录ID';
COMMENT ON COLUMN payment_history.task_id IS '关联的任务ID';
COMMENT ON COLUMN payment_history.user_id IS '支付者用户ID';
COMMENT ON COLUMN payment_history.payment_intent_id IS 'Stripe Payment Intent ID';
COMMENT ON COLUMN payment_history.payment_method IS '支付方式：stripe, points, mixed';
COMMENT ON COLUMN payment_history.total_amount IS '总金额（便士）';
COMMENT ON COLUMN payment_history.points_used IS '使用的积分（便士）';
COMMENT ON COLUMN payment_history.coupon_discount IS '优惠券折扣（便士）';
COMMENT ON COLUMN payment_history.stripe_amount IS 'Stripe 支付金额（便士）';
COMMENT ON COLUMN payment_history.final_amount IS '最终支付金额（便士）';
COMMENT ON COLUMN payment_history.currency IS '货币代码';
COMMENT ON COLUMN payment_history.status IS '支付状态：pending, succeeded, failed, canceled';
COMMENT ON COLUMN payment_history.application_fee IS '平台服务费（便士）';
COMMENT ON COLUMN payment_history.escrow_amount IS '托管金额';
COMMENT ON COLUMN payment_history.coupon_usage_log_id IS '关联的优惠券使用记录ID';
COMMENT ON COLUMN payment_history.metadata IS '额外元数据（JSON格式）';
COMMENT ON COLUMN payment_history.created_at IS '创建时间';
COMMENT ON COLUMN payment_history.updated_at IS '更新时间';

