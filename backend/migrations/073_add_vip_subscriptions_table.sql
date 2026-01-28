-- VIP订阅表
-- 创建时间: 2026-01-28
-- 说明: 记录用户的VIP订阅信息，包括IAP交易详情

CREATE TABLE IF NOT EXISTS vip_subscriptions (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id VARCHAR(100) NOT NULL,
    transaction_id VARCHAR(255) NOT NULL UNIQUE,
    original_transaction_id VARCHAR(255), -- 原始交易ID（用于订阅续费）
    transaction_jws TEXT NOT NULL, -- JWS表示（用于验证）
    purchase_date TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_date TIMESTAMP WITH TIME ZONE, -- 订阅到期时间（如果是订阅）
    is_trial_period BOOLEAN DEFAULT FALSE,
    is_in_intro_offer_period BOOLEAN DEFAULT FALSE,
    environment VARCHAR(20) DEFAULT 'Production', -- Production 或 Sandbox
    status VARCHAR(20) DEFAULT 'active', -- active, expired, cancelled, refunded
    auto_renew_status BOOLEAN DEFAULT TRUE,
    cancellation_reason VARCHAR(50), -- 取消原因
    refunded_at TIMESTAMP WITH TIME ZONE, -- 退款时间
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT fk_vip_subscriptions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_vip_subscriptions_user_id ON vip_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_vip_subscriptions_transaction_id ON vip_subscriptions(transaction_id);
CREATE INDEX IF NOT EXISTS idx_vip_subscriptions_original_transaction_id ON vip_subscriptions(original_transaction_id);
CREATE INDEX IF NOT EXISTS idx_vip_subscriptions_status ON vip_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_vip_subscriptions_expires_date ON vip_subscriptions(expires_date);
CREATE INDEX IF NOT EXISTS idx_vip_subscriptions_user_status ON vip_subscriptions(user_id, status);

-- 添加注释
COMMENT ON TABLE vip_subscriptions IS 'VIP订阅记录表，记录用户的IAP购买和订阅信息';
COMMENT ON COLUMN vip_subscriptions.transaction_id IS 'Apple交易ID，唯一标识一次购买';
COMMENT ON COLUMN vip_subscriptions.original_transaction_id IS '原始交易ID，用于订阅续费时关联';
COMMENT ON COLUMN vip_subscriptions.transaction_jws IS 'JWS格式的交易数据，用于服务器端验证';
COMMENT ON COLUMN vip_subscriptions.status IS '订阅状态：active-有效, expired-已过期, cancelled-已取消, refunded-已退款';
