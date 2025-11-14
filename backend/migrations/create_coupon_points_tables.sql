-- 优惠券和积分系统数据库迁移脚本
-- 执行此脚本创建所有相关表

-- 1. 优惠券表
CREATE TABLE IF NOT EXISTS coupons (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    type VARCHAR(20) NOT NULL,
    discount_value BIGINT,
    min_amount BIGINT DEFAULT 0,
    max_discount BIGINT,
    currency CHAR(3) DEFAULT 'GBP',
    total_quantity INTEGER,
    per_user_limit INTEGER DEFAULT 1,
    per_device_limit INTEGER,
    per_ip_limit INTEGER,
    can_combine BOOLEAN DEFAULT false,
    combine_limit INTEGER DEFAULT 1,
    apply_order INTEGER DEFAULT 0,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    usage_conditions JSONB,
    eligibility_type VARCHAR(20),
    eligibility_value TEXT,
    per_day_limit INTEGER,
    vat_category VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_coupon_dates CHECK (valid_until > valid_from),
    CONSTRAINT chk_coupon_discount CHECK (
        (type = 'fixed_amount' AND discount_value > 0) OR
        (type = 'percentage' AND discount_value BETWEEN 1 AND 10000)
    )
);

-- 创建不区分大小写的唯一索引
CREATE UNIQUE INDEX IF NOT EXISTS uq_coupons_code_lower ON coupons (LOWER(code));

-- 创建其他索引
CREATE INDEX IF NOT EXISTS idx_coupons_status ON coupons(status);
CREATE INDEX IF NOT EXISTS idx_coupons_valid ON coupons(valid_from, valid_until);
CREATE INDEX IF NOT EXISTS idx_coupons_conditions ON coupons USING GIN(usage_conditions);
CREATE INDEX IF NOT EXISTS idx_coupons_combine ON coupons(can_combine, apply_order);

-- 2. 用户优惠券表
CREATE TABLE IF NOT EXISTS user_coupons (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    coupon_id BIGINT NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
    promotion_code_id BIGINT REFERENCES promotion_codes(id),
    status VARCHAR(20) DEFAULT 'unused',
    obtained_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    used_at TIMESTAMPTZ,
    used_in_task_id BIGINT REFERENCES tasks(id),
    device_fingerprint VARCHAR(64),
    ip_address INET,
    idempotency_key VARCHAR(64) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_user_coupons_user ON user_coupons(user_id);
CREATE INDEX IF NOT EXISTS idx_user_coupons_status ON user_coupons(status);
CREATE INDEX IF NOT EXISTS idx_user_coupons_coupon ON user_coupons(coupon_id);

-- 3. 优惠券使用记录表（两阶段使用控制）
CREATE TABLE IF NOT EXISTS coupon_redemptions (
    id BIGSERIAL PRIMARY KEY,
    user_coupon_id BIGINT NOT NULL REFERENCES user_coupons(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    coupon_id BIGINT NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
    task_id BIGINT REFERENCES tasks(id),
    status VARCHAR(20) DEFAULT 'reserved',
    reserved_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    idempotency_key VARCHAR(64) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_user_coupon ON coupon_redemptions(user_coupon_id);
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_status ON coupon_redemptions(status);
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_expires ON coupon_redemptions(expires_at);

-- 部分唯一索引：确保同一张券同一时刻至多一条未确认的预留
CREATE UNIQUE INDEX IF NOT EXISTS idx_coupon_redemptions_reserved_unique 
    ON coupon_redemptions(user_coupon_id) 
    WHERE status = 'reserved';

-- 部分唯一索引：防止同一任务重复使用同一张券
CREATE UNIQUE INDEX IF NOT EXISTS uq_redemption_task_nonnull
    ON coupon_redemptions(user_id, coupon_id, task_id)
    WHERE task_id IS NOT NULL;

-- 4. 积分账户表
CREATE TABLE IF NOT EXISTS points_accounts (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    balance BIGINT DEFAULT 0,
    currency CHAR(3) DEFAULT 'GBP',
    total_earned BIGINT DEFAULT 0,
    total_spent BIGINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_points_accounts_user ON points_accounts(user_id);

-- 5. 积分交易记录表
CREATE TABLE IF NOT EXISTS points_transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL,
    amount BIGINT NOT NULL,
    balance_after BIGINT NOT NULL,
    currency CHAR(3) DEFAULT 'GBP',
    source VARCHAR(50),
    related_id BIGINT,
    related_type VARCHAR(50),
    batch_id VARCHAR(50),
    expires_at TIMESTAMPTZ,
    description TEXT,
    idempotency_key VARCHAR(64) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_points_amount_sign CHECK (
        (type = 'earn' AND amount > 0) OR
        (type = 'spend' AND amount < 0) OR
        (type = 'refund' AND amount > 0) OR
        (type = 'expire' AND amount < 0)
    )
);

CREATE INDEX IF NOT EXISTS idx_points_transactions_user ON points_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_points_transactions_type ON points_transactions(type);
CREATE INDEX IF NOT EXISTS idx_points_transactions_created ON points_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_points_transactions_related ON points_transactions(related_type, related_id);

-- 6. 优惠券使用记录表
CREATE TABLE IF NOT EXISTS coupon_usage_logs (
    id BIGSERIAL PRIMARY KEY,
    user_coupon_id BIGINT NOT NULL REFERENCES user_coupons(id) ON DELETE CASCADE,
    redemption_id BIGINT REFERENCES coupon_redemptions(id),
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    coupon_id BIGINT NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
    promotion_code_id BIGINT REFERENCES promotion_codes(id),
    task_id BIGINT REFERENCES tasks(id),
    discount_amount_before_tax BIGINT NOT NULL,
    discount_amount BIGINT NOT NULL,
    order_amount_before_tax BIGINT NOT NULL,
    order_amount_incl_tax BIGINT NOT NULL,
    final_amount_before_tax BIGINT NOT NULL,
    final_amount_incl_tax BIGINT NOT NULL,
    vat_amount BIGINT,
    vat_rate DECIMAL(5, 2),
    vat_category VARCHAR(20),
    rounding_method VARCHAR(20) DEFAULT 'bankers',
    currency CHAR(3) DEFAULT 'GBP',
    applied_coupons JSONB,
    refund_status VARCHAR(20) DEFAULT 'none',
    refunded_at TIMESTAMPTZ,
    refund_reason TEXT,
    idempotency_key VARCHAR(64) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_coupon_usage_logs_user ON coupon_usage_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_coupon_usage_logs_task ON coupon_usage_logs(task_id);
CREATE INDEX IF NOT EXISTS idx_coupon_usage_logs_coupon ON coupon_usage_logs(coupon_id);

-- 7. 签到记录表
CREATE TABLE IF NOT EXISTS check_ins (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    check_in_date DATE NOT NULL,
    timezone VARCHAR(50) DEFAULT 'Europe/London',
    consecutive_days INTEGER DEFAULT 1,
    reward_type VARCHAR(20),
    points_reward BIGINT,
    coupon_id BIGINT REFERENCES coupons(id),
    reward_description TEXT,
    device_fingerprint VARCHAR(64),
    ip_address INET,
    idempotency_key VARCHAR(64) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_user_checkin_date UNIQUE(user_id, check_in_date),
    CONSTRAINT chk_checkin_reward CHECK (
        (reward_type = 'points' AND points_reward IS NOT NULL AND coupon_id IS NULL) OR
        (reward_type = 'coupon' AND coupon_id IS NOT NULL AND points_reward IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_check_ins_user ON check_ins(user_id);
CREATE INDEX IF NOT EXISTS idx_check_ins_date ON check_ins(check_in_date);
CREATE INDEX IF NOT EXISTS idx_check_ins_user_date ON check_ins(user_id, check_in_date);

-- 8. 签到奖励配置表
CREATE TABLE IF NOT EXISTS check_in_rewards (
    id BIGSERIAL PRIMARY KEY,
    consecutive_days INTEGER NOT NULL UNIQUE,
    reward_type VARCHAR(20) NOT NULL,
    points_reward BIGINT,
    coupon_id BIGINT REFERENCES coupons(id),
    reward_description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_checkin_reward_value CHECK (
        (reward_type = 'points' AND points_reward IS NOT NULL AND coupon_id IS NULL) OR
        (reward_type = 'coupon' AND coupon_id IS NOT NULL AND points_reward IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_check_in_rewards_days ON check_in_rewards(consecutive_days);
CREATE INDEX IF NOT EXISTS idx_check_in_rewards_active ON check_in_rewards(is_active);

-- 9. 邀请码表
CREATE TABLE IF NOT EXISTS invitation_codes (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100),
    description TEXT,
    reward_type VARCHAR(20) NOT NULL,
    points_reward BIGINT DEFAULT 0,
    coupon_id BIGINT REFERENCES coupons(id),
    currency CHAR(3) DEFAULT 'GBP',
    max_uses INTEGER,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_by VARCHAR(5) REFERENCES admin_users(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_invitation_code_lower ON invitation_codes (LOWER(code));
CREATE INDEX IF NOT EXISTS idx_invitation_codes_active ON invitation_codes(is_active);
CREATE INDEX IF NOT EXISTS idx_invitation_codes_valid ON invitation_codes(valid_from, valid_until);
CREATE INDEX IF NOT EXISTS idx_invitation_codes_created_by ON invitation_codes(created_by);

-- 10. 用户邀请码使用记录表
CREATE TABLE IF NOT EXISTS user_invitation_usage (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invitation_code_id BIGINT NOT NULL REFERENCES invitation_codes(id) ON DELETE CASCADE,
    used_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    reward_received BOOLEAN DEFAULT false,
    points_received BIGINT,
    coupon_received_id BIGINT REFERENCES coupons(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, invitation_code_id)
);

CREATE INDEX IF NOT EXISTS idx_user_invitation_usage_user ON user_invitation_usage(user_id);
CREATE INDEX IF NOT EXISTS idx_user_invitation_usage_code ON user_invitation_usage(invitation_code_id);
CREATE INDEX IF NOT EXISTS idx_user_invitation_usage_used_at ON user_invitation_usage(used_at);

-- 11. 管理员发放记录表
CREATE TABLE IF NOT EXISTS admin_rewards (
    id BIGSERIAL PRIMARY KEY,
    reward_type VARCHAR(20) NOT NULL,
    target_type VARCHAR(20) NOT NULL,
    target_value TEXT,
    points_value BIGINT,
    coupon_id BIGINT REFERENCES coupons(id),
    total_users INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    failed_count INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pending',
    description TEXT,
    created_by VARCHAR(5) NOT NULL REFERENCES admin_users(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,
    CONSTRAINT chk_admin_rewards_value CHECK (
        (reward_type = 'points' AND points_value IS NOT NULL AND coupon_id IS NULL) OR
        (reward_type = 'coupon' AND coupon_id IS NOT NULL AND points_value IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_admin_rewards_type ON admin_rewards(reward_type);
CREATE INDEX IF NOT EXISTS idx_admin_rewards_target ON admin_rewards(target_type);
CREATE INDEX IF NOT EXISTS idx_admin_rewards_status ON admin_rewards(status);
CREATE INDEX IF NOT EXISTS idx_admin_rewards_created_by ON admin_rewards(created_by);
CREATE INDEX IF NOT EXISTS idx_admin_rewards_created_at ON admin_rewards(created_at);

-- 12. 管理员发放详情表
CREATE TABLE IF NOT EXISTS admin_reward_details (
    id BIGSERIAL PRIMARY KEY,
    admin_reward_id BIGINT NOT NULL REFERENCES admin_rewards(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reward_type VARCHAR(20) NOT NULL,
    points_value BIGINT,
    coupon_id BIGINT REFERENCES coupons(id),
    status VARCHAR(20) DEFAULT 'pending',
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,
    CONSTRAINT chk_admin_reward_details_value CHECK (
        (reward_type = 'points' AND points_value IS NOT NULL AND coupon_id IS NULL) OR
        (reward_type = 'coupon' AND coupon_id IS NOT NULL AND points_value IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_admin_reward_details_reward ON admin_reward_details(admin_reward_id);
CREATE INDEX IF NOT EXISTS idx_admin_reward_details_user ON admin_reward_details(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_reward_details_status ON admin_reward_details(status);

-- 13. 设备指纹表
CREATE TABLE IF NOT EXISTS device_fingerprints (
    id BIGSERIAL PRIMARY KEY,
    fingerprint VARCHAR(64) UNIQUE NOT NULL,
    user_id VARCHAR(8) REFERENCES users(id),
    device_info JSONB,
    ip_address INET,
    first_seen TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    risk_score INTEGER DEFAULT 0,
    is_blocked BOOLEAN DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_device_fingerprints_fp ON device_fingerprints(fingerprint);
CREATE INDEX IF NOT EXISTS idx_device_fingerprints_user ON device_fingerprints(user_id);
CREATE INDEX IF NOT EXISTS idx_device_fingerprints_risk ON device_fingerprints(risk_score);

-- 14. 风控记录表
CREATE TABLE IF NOT EXISTS risk_control_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) REFERENCES users(id),
    device_fingerprint VARCHAR(64) REFERENCES device_fingerprints(fingerprint),
    action_type VARCHAR(50) NOT NULL,
    risk_level VARCHAR(20),
    risk_reason TEXT,
    action_blocked BOOLEAN DEFAULT false,
    meta_data JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_risk_logs_user ON risk_control_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_risk_logs_device ON risk_control_logs(device_fingerprint);
CREATE INDEX IF NOT EXISTS idx_risk_logs_action ON risk_control_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_risk_logs_risk ON risk_control_logs(risk_level);
CREATE INDEX IF NOT EXISTS idx_risk_logs_created ON risk_control_logs(created_at);

-- 15. 推广码表
CREATE TABLE IF NOT EXISTS promotion_codes (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL,
    coupon_id BIGINT NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
    name VARCHAR(100),
    description TEXT,
    max_uses INTEGER,
    per_user_limit INTEGER DEFAULT 1,
    min_order_amount BIGINT,
    can_combine BOOLEAN,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT true,
    target_user_type VARCHAR(20),
    created_by VARCHAR(5) REFERENCES admin_users(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_promo_dates CHECK (valid_until > valid_from)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_promotion_code_lower ON promotion_codes (LOWER(code));
CREATE INDEX IF NOT EXISTS idx_promotion_codes_coupon ON promotion_codes(coupon_id);
CREATE INDEX IF NOT EXISTS idx_promotion_codes_active ON promotion_codes(is_active);
CREATE INDEX IF NOT EXISTS idx_promotion_codes_valid ON promotion_codes(valid_from, valid_until);

-- 16. 审计日志表
CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    action_type VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50),
    entity_id VARCHAR(50),
    user_id VARCHAR(8) REFERENCES users(id),
    admin_id VARCHAR(5) REFERENCES admin_users(id),
    old_value JSONB,
    new_value JSONB,
    reason TEXT,
    ip_address INET,
    device_fingerprint VARCHAR(64),
    error_code VARCHAR(50),
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_admin ON audit_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);

-- 创建 updated_at 自动更新触发器函数（如果不存在）
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 为需要的表创建触发器
DROP TRIGGER IF EXISTS trg_coupons_updated ON coupons;
CREATE TRIGGER trg_coupons_updated
  BEFORE UPDATE ON coupons
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_points_accounts_updated ON points_accounts;
CREATE TRIGGER trg_points_accounts_updated
  BEFORE UPDATE ON points_accounts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_check_in_rewards_updated ON check_in_rewards;
CREATE TRIGGER trg_check_in_rewards_updated
  BEFORE UPDATE ON check_in_rewards
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_invitation_codes_updated ON invitation_codes;
CREATE TRIGGER trg_invitation_codes_updated
  BEFORE UPDATE ON invitation_codes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_promotion_codes_updated ON promotion_codes;
CREATE TRIGGER trg_promotion_codes_updated
  BEFORE UPDATE ON promotion_codes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 创建邀请码使用统计视图
CREATE OR REPLACE VIEW invitation_code_stats AS
SELECT 
    ic.id,
    ic.code,
    ic.name,
    ic.max_uses,
    COUNT(uiu.*) FILTER (WHERE uiu.reward_received = true) AS used_count
FROM invitation_codes ic
LEFT JOIN user_invitation_usage uiu ON uiu.invitation_code_id = ic.id
GROUP BY ic.id, ic.code, ic.name, ic.max_uses;

-- 添加 users 表的 invitation_code_id 字段（如果不存在）
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'invitation_code_id'
    ) THEN
        ALTER TABLE users ADD COLUMN invitation_code_id BIGINT REFERENCES invitation_codes(id);
        CREATE INDEX IF NOT EXISTS idx_users_invitation_code_id ON users(invitation_code_id);
    END IF;
END $$;

-- 添加 users 表的 invitation_code_text 字段（如果不存在）
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'invitation_code_text'
    ) THEN
        ALTER TABLE users ADD COLUMN invitation_code_text VARCHAR(50);
    END IF;
END $$;

-- 添加 users 表的 inviter_id 字段（如果不存在）
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'inviter_id'
    ) THEN
        ALTER TABLE users ADD COLUMN inviter_id VARCHAR(8) REFERENCES users(id);
        CREATE INDEX IF NOT EXISTS idx_users_inviter_id ON users(inviter_id);
    END IF;
END $$;

-- 添加 pending_users 表的 inviter_id 字段（如果不存在）
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pending_users' AND column_name = 'inviter_id'
    ) THEN
        ALTER TABLE pending_users ADD COLUMN inviter_id VARCHAR(8) REFERENCES users(id);
        CREATE INDEX IF NOT EXISTS idx_pending_users_inviter_id ON pending_users(inviter_id);
    END IF;
END $$;

-- 添加 pending_users 表的 invitation_code_id 字段（如果不存在）
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pending_users' AND column_name = 'invitation_code_id'
    ) THEN
        ALTER TABLE pending_users ADD COLUMN invitation_code_id BIGINT REFERENCES invitation_codes(id);
        CREATE INDEX IF NOT EXISTS idx_pending_users_invitation_code_id ON pending_users(invitation_code_id);
    END IF;
END $$;

-- 添加 pending_users 表的 invitation_code_text 字段（如果不存在）
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pending_users' AND column_name = 'invitation_code_text'
    ) THEN
        ALTER TABLE pending_users ADD COLUMN invitation_code_text VARCHAR(50);
    END IF;
END $$;

