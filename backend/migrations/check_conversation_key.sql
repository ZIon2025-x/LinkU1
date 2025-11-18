-- ============================================
-- 检查 conversation_key 状态
-- ============================================
-- 此脚本用于检查 conversation_key 字段和触发器的状态
-- ============================================

-- 1. 检查字段是否存在
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_name = 'messages' 
  AND column_name = 'conversation_key';

-- 2. 检查 conversation_key 的填充情况
SELECT 
    COUNT(*) as total_messages,
    COUNT(conversation_key) as messages_with_key,
    COUNT(*) - COUNT(conversation_key) as messages_without_key,
    ROUND(COUNT(conversation_key) * 100.0 / NULLIF(COUNT(*), 0), 2) as fill_percentage
FROM messages;

-- 3. 检查触发器是否存在
SELECT 
    trigger_name, 
    event_manipulation, 
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'messages' 
  AND trigger_name = 'trigger_update_conversation_key';

-- 4. 检查索引是否存在
SELECT 
    indexname, 
    indexdef
FROM pg_indexes
WHERE tablename = 'messages' 
  AND indexname = 'ix_messages_conversation_created';

-- 5. 查看一些示例数据（前10条）
SELECT 
    id,
    sender_id,
    receiver_id,
    conversation_key,
    created_at
FROM messages
ORDER BY created_at DESC
LIMIT 10;

