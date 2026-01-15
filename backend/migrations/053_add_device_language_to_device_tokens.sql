-- 迁移文件053：为 device_tokens 表添加设备语言字段
-- 创建时间: 2026-01-15
-- 说明: 添加 device_language 字段，用于存储设备的系统语言，以便推送通知时使用对应语言

-- 添加设备语言字段
ALTER TABLE device_tokens 
ADD COLUMN IF NOT EXISTS device_language VARCHAR(10) DEFAULT 'en';

-- 添加注释
COMMENT ON COLUMN device_tokens.device_language IS '设备系统语言代码（zh 或 en），用于推送通知时生成对应语言的内容';

-- 创建索引以提高查询性能（如果需要根据语言筛选）
CREATE INDEX IF NOT EXISTS ix_device_tokens_language ON device_tokens(device_language) WHERE is_active = TRUE;
