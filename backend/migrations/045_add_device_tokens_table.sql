-- 添加设备推送令牌表（用于 iOS/Android 推送通知）
-- 迁移文件：045_add_device_tokens_table.sql

-- 创建设备推送令牌表
CREATE TABLE IF NOT EXISTS device_tokens (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_token VARCHAR(255) NOT NULL,
    platform VARCHAR(20) NOT NULL DEFAULT 'ios',  -- ios, android
    device_id VARCHAR(255) NULL,  -- 设备唯一标识（可选）
    app_version VARCHAR(20) NULL,  -- 应用版本
    is_active BOOLEAN DEFAULT TRUE,  -- 是否激活
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_used_at TIMESTAMP WITH TIME ZONE NULL  -- 最后使用时间
);

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS ix_device_tokens_user ON device_tokens(user_id);
CREATE INDEX IF NOT EXISTS ix_device_tokens_token ON device_tokens(device_token);
CREATE INDEX IF NOT EXISTS ix_device_tokens_user_active ON device_tokens(user_id, is_active);
CREATE INDEX IF NOT EXISTS ix_device_tokens_platform ON device_tokens(platform);

-- 添加唯一约束：同一用户同一设备只能有一个 token
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_device_token ON device_tokens(user_id, device_token);

-- 添加注释
COMMENT ON TABLE device_tokens IS '设备推送令牌表，用于存储 iOS/Android 设备的推送通知令牌';
COMMENT ON COLUMN device_tokens.id IS '设备令牌ID';
COMMENT ON COLUMN device_tokens.user_id IS '用户ID';
COMMENT ON COLUMN device_tokens.device_token IS 'APNs/FCM 设备令牌';
COMMENT ON COLUMN device_tokens.platform IS '平台：ios 或 android';
COMMENT ON COLUMN device_tokens.device_id IS '设备唯一标识（可选）';
COMMENT ON COLUMN device_tokens.app_version IS '应用版本';
COMMENT ON COLUMN device_tokens.is_active IS '是否激活（用于禁用特定设备的推送）';
COMMENT ON COLUMN device_tokens.last_used_at IS '最后使用时间（用于清理过期 token）';
