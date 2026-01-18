-- ===========================================
-- 迁移 055: 为 admin_users 表添加 2FA 相关字段
-- ===========================================
-- 说明：为管理员账户添加双因素认证（2FA/TOTP）支持
-- 功能：支持 Google Authenticator、Microsoft Authenticator 等 TOTP 应用
-- 适用范围：仅限管理员子域名 (admin.link2ur.com)
-- 执行时间：应用启动时自动执行（如果 AUTO_MIGRATE=true）
-- ===========================================

ALTER TABLE admin_users 
ADD COLUMN IF NOT EXISTS totp_secret VARCHAR(32),
ADD COLUMN IF NOT EXISTS totp_enabled INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS totp_backup_codes TEXT;

-- 添加注释
COMMENT ON COLUMN admin_users.totp_secret IS 'TOTP 密钥（Base32 编码），用于生成 6 位验证码';
COMMENT ON COLUMN admin_users.totp_enabled IS '2FA 是否已启用：1=已启用，0=未启用';
COMMENT ON COLUMN admin_users.totp_backup_codes IS '备份代码（JSON 数组），用于在丢失 Authenticator 设备时恢复账户';
