-- 添加管理员验证码表
CREATE TABLE IF NOT EXISTS admin_verification_codes (
    id SERIAL PRIMARY KEY,
    admin_id VARCHAR(5) NOT NULL REFERENCES admin_users(id),
    code VARCHAR(6) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_used INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    used_at TIMESTAMP NULL
);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_admin_verification_codes_admin_id ON admin_verification_codes(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_verification_codes_code ON admin_verification_codes(code);
CREATE INDEX IF NOT EXISTS idx_admin_verification_codes_expires_at ON admin_verification_codes(expires_at);
CREATE INDEX IF NOT EXISTS idx_admin_verification_codes_is_used ON admin_verification_codes(is_used);
