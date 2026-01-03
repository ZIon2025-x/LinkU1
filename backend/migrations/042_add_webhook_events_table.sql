-- 添加 Webhook 事件记录表（用于 idempotency 和审计）
-- 迁移文件：042_add_webhook_events_table.sql

-- 创建 Webhook 事件记录表
CREATE TABLE IF NOT EXISTS webhook_events (
    id BIGSERIAL PRIMARY KEY,
    event_id VARCHAR(255) NOT NULL UNIQUE,  -- Stripe 事件 ID（唯一索引防止重复处理）
    event_type VARCHAR(100) NOT NULL,  -- 事件类型（如 payment_intent.succeeded）
    livemode BOOLEAN DEFAULT FALSE,  -- 是否为生产模式
    processed BOOLEAN DEFAULT FALSE,  -- 是否已处理
    processed_at TIMESTAMP WITH TIME ZONE NULL,  -- 处理时间
    processing_error TEXT NULL,  -- 处理错误信息
    event_data JSONB NOT NULL,  -- 完整事件数据（JSON格式）
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS ix_webhook_events_event_id ON webhook_events(event_id);
CREATE INDEX IF NOT EXISTS ix_webhook_events_event_type ON webhook_events(event_type);
CREATE INDEX IF NOT EXISTS ix_webhook_events_processed ON webhook_events(processed);
CREATE INDEX IF NOT EXISTS ix_webhook_events_created ON webhook_events(created_at);

-- 添加注释
COMMENT ON TABLE webhook_events IS 'Webhook 事件记录表，用于 idempotency 检查和审计';
COMMENT ON COLUMN webhook_events.event_id IS 'Stripe 事件 ID（唯一，防止重复处理）';
COMMENT ON COLUMN webhook_events.event_type IS '事件类型';
COMMENT ON COLUMN webhook_events.livemode IS '是否为生产模式';
COMMENT ON COLUMN webhook_events.processed IS '是否已处理';
COMMENT ON COLUMN webhook_events.processed_at IS '处理时间';
COMMENT ON COLUMN webhook_events.processing_error IS '处理错误信息';
COMMENT ON COLUMN webhook_events.event_data IS '完整事件数据（JSON格式）';

