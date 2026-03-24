-- 服务申请添加所有者回复字段
ALTER TABLE service_applications ADD COLUMN IF NOT EXISTS owner_reply TEXT;
ALTER TABLE service_applications ADD COLUMN IF NOT EXISTS owner_reply_at TIMESTAMPTZ;
