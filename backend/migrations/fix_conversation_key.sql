-- ============================================
-- 修复 conversation_key 字段
-- ============================================
-- 此脚本用于：
-- 1. 检查并创建 conversation_key 字段（如果不存在）
-- 2. 填充所有现有的 null 值
-- 3. 确保触发器存在并正常工作
-- ============================================

-- 1. 确保 conversation_key 字段存在
ALTER TABLE messages ADD COLUMN IF NOT EXISTS conversation_key VARCHAR(255);

-- 2. 填充所有现有的 null 值
-- 对于有 sender_id 和 receiver_id 的消息，生成 conversation_key
UPDATE messages 
SET conversation_key = LEAST(sender_id::text, receiver_id::text) || '-' || 
                      GREATEST(sender_id::text, receiver_id::text)
WHERE conversation_key IS NULL 
  AND sender_id IS NOT NULL 
  AND receiver_id IS NOT NULL;

-- 3. 确保触发器函数存在
CREATE OR REPLACE FUNCTION update_message_conversation_key()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.sender_id IS NOT NULL AND NEW.receiver_id IS NOT NULL THEN
        NEW.conversation_key := LEAST(NEW.sender_id::text, NEW.receiver_id::text) || '-' || 
                               GREATEST(NEW.sender_id::text, NEW.receiver_id::text);
    ELSE
        NEW.conversation_key := NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. 删除旧触发器（如果存在）
DROP TRIGGER IF EXISTS trigger_update_conversation_key ON messages;

-- 5. 创建触发器
CREATE TRIGGER trigger_update_conversation_key
BEFORE INSERT OR UPDATE ON messages
FOR EACH ROW
EXECUTE FUNCTION update_message_conversation_key();

-- 6. 创建索引（如果不存在）
CREATE INDEX IF NOT EXISTS ix_messages_conversation_created 
ON messages(conversation_key, created_at DESC)
WHERE conversation_key IS NOT NULL;

-- ============================================
-- 验证脚本（可选，用于检查结果）
-- ============================================
-- 检查 conversation_key 的填充情况
-- SELECT 
--     COUNT(*) as total_messages,
--     COUNT(conversation_key) as messages_with_key,
--     COUNT(*) - COUNT(conversation_key) as messages_without_key
-- FROM messages;

-- 检查触发器是否存在
-- SELECT 
--     trigger_name, 
--     event_manipulation, 
--     event_object_table,
--     action_statement
-- FROM information_schema.triggers
-- WHERE event_object_table = 'messages' 
--   AND trigger_name = 'trigger_update_conversation_key';

