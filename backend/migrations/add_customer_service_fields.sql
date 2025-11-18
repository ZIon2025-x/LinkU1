-- 客服功能字段扩展迁移脚本
-- 添加结束对话原因字段和消息状态字段
-- 执行时间：2024-12-28

-- 1. 为 customer_service_chats 表添加结束原因字段
DO $$
BEGIN
    -- 添加 ended_reason 字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service_chats' AND column_name = 'ended_reason'
    ) THEN
        ALTER TABLE customer_service_chats 
        ADD COLUMN ended_reason VARCHAR(32);
        COMMENT ON COLUMN customer_service_chats.ended_reason IS '结束原因: timeout, user_ended, service_ended, auto_cleanup';
    END IF;

    -- 添加 ended_by 字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service_chats' AND column_name = 'ended_by'
    ) THEN
        ALTER TABLE customer_service_chats 
        ADD COLUMN ended_by VARCHAR(32);
        COMMENT ON COLUMN customer_service_chats.ended_by IS '结束者: user_id, service_id, system';
    END IF;

    -- 添加 ended_type 字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service_chats' AND column_name = 'ended_type'
    ) THEN
        ALTER TABLE customer_service_chats 
        ADD COLUMN ended_type VARCHAR(32);
        COMMENT ON COLUMN customer_service_chats.ended_type IS '结束类型: user_inactive, service_inactive, manual, auto';
    END IF;

    -- 添加 ended_comment 字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service_chats' AND column_name = 'ended_comment'
    ) THEN
        ALTER TABLE customer_service_chats 
        ADD COLUMN ended_comment TEXT;
        COMMENT ON COLUMN customer_service_chats.ended_comment IS '结束备注（可选）';
    END IF;
END $$;

-- 2. 为 customer_service_messages 表添加消息状态字段
DO $$
BEGIN
    -- 添加 status 字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service_messages' AND column_name = 'status'
    ) THEN
        ALTER TABLE customer_service_messages 
        ADD COLUMN status VARCHAR(20) DEFAULT 'sending';
        COMMENT ON COLUMN customer_service_messages.status IS '消息状态: sending, sent, delivered, read';
    END IF;

    -- 添加 sent_at 字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service_messages' AND column_name = 'sent_at'
    ) THEN
        ALTER TABLE customer_service_messages 
        ADD COLUMN sent_at TIMESTAMPTZ;
        COMMENT ON COLUMN customer_service_messages.sent_at IS '发送时间';
    END IF;

    -- 添加 delivered_at 字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service_messages' AND column_name = 'delivered_at'
    ) THEN
        ALTER TABLE customer_service_messages 
        ADD COLUMN delivered_at TIMESTAMPTZ;
        COMMENT ON COLUMN customer_service_messages.delivered_at IS '送达时间';
    END IF;

    -- 添加 read_at 字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service_messages' AND column_name = 'read_at'
    ) THEN
        ALTER TABLE customer_service_messages 
        ADD COLUMN read_at TIMESTAMPTZ;
        COMMENT ON COLUMN customer_service_messages.read_at IS '已读时间';
    END IF;
END $$;

-- 3. 为现有已结束的对话设置默认值
UPDATE customer_service_chats 
SET 
    ended_reason = 'manual',
    ended_by = 'system',
    ended_type = 'manual'
WHERE is_ended = 1 
  AND ended_reason IS NULL;

-- 4. 为现有消息设置默认状态
UPDATE customer_service_messages 
SET status = 'sent'
WHERE status IS NULL OR status = '';

-- 5. 为已读消息设置状态和时间
UPDATE customer_service_messages 
SET 
    status = 'read',
    read_at = created_at
WHERE is_read = 1 
  AND status != 'read'
  AND read_at IS NULL;

-- 6. 创建索引优化查询性能
CREATE INDEX IF NOT EXISTS ix_customer_service_chats_ended_reason 
ON customer_service_chats(ended_reason) 
WHERE ended_reason IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_customer_service_messages_status 
ON customer_service_messages(status);

CREATE INDEX IF NOT EXISTS ix_customer_service_messages_chat_status 
ON customer_service_messages(chat_id, status);

