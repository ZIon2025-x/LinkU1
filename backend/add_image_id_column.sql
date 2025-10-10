-- 为messages表添加image_id字段
-- 如果字段已存在，此命令会失败，这是正常的

ALTER TABLE messages ADD COLUMN image_id VARCHAR(100) NULL;

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_messages_image_id ON messages(image_id);
