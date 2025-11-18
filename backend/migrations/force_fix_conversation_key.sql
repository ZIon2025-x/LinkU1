-- ============================================
-- 强制修复 conversation_key 字段
-- ============================================
-- 此脚本会：
-- 1. 强制重新填充所有 conversation_key（包括已存在的值）
-- 2. 确保触发器正确创建
-- 3. 验证触发器是否工作
-- ============================================

-- 1. 确保字段存在
ALTER TABLE messages ADD COLUMN IF NOT EXISTS conversation_key VARCHAR(255);

-- 2. 强制重新填充所有 conversation_key（包括已存在的值）
-- 这会更新所有有 sender_id 和 receiver_id 的消息
-- 注意：使用 UPDATE 会触发触发器，但为了确保数据一致性，我们直接更新
UPDATE messages 
SET conversation_key = LEAST(sender_id::text, receiver_id::text) || '-' || 
                      GREATEST(sender_id::text, receiver_id::text)
WHERE sender_id IS NOT NULL 
  AND receiver_id IS NOT NULL
  AND (conversation_key IS NULL OR conversation_key != LEAST(sender_id::text, receiver_id::text) || '-' || GREATEST(sender_id::text, receiver_id::text));

-- 3. 确保触发器函数存在（使用更严格的错误处理）
CREATE OR REPLACE FUNCTION update_message_conversation_key()
RETURNS TRIGGER AS $$
BEGIN
    -- 对于 INSERT 和 UPDATE，都重新计算 conversation_key
    IF NEW.sender_id IS NOT NULL AND NEW.receiver_id IS NOT NULL THEN
        NEW.conversation_key := LEAST(NEW.sender_id::text, NEW.receiver_id::text) || '-' || 
                               GREATEST(NEW.sender_id::text, NEW.receiver_id::text);
    ELSE
        NEW.conversation_key := NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. 删除所有可能的旧触发器
DROP TRIGGER IF EXISTS trigger_update_conversation_key ON messages;
DROP TRIGGER IF EXISTS update_message_conversation_key ON messages;

-- 5. 创建触发器（确保在 INSERT 和 UPDATE 时都触发）
CREATE TRIGGER trigger_update_conversation_key
BEFORE INSERT OR UPDATE ON messages
FOR EACH ROW
EXECUTE FUNCTION update_message_conversation_key();

-- 6. 确保索引存在
CREATE INDEX IF NOT EXISTS ix_messages_conversation_created 
ON messages(conversation_key, created_at DESC)
WHERE conversation_key IS NOT NULL;

-- 7. 验证：检查填充情况（这些查询结果会在日志中显示）
-- 注意：这些 SELECT 语句不会影响迁移执行，只是用于验证
-- SELECT 
--     COUNT(*) as total_messages,
--     COUNT(conversation_key) as messages_with_key,
--     COUNT(*) - COUNT(conversation_key) as messages_without_key
-- FROM messages;

