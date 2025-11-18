-- ============================================
-- 诊断 conversation_key 问题
-- ============================================

-- 1. 检查字段是否存在
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns
WHERE table_name = 'messages' 
  AND column_name = 'conversation_key';

-- 2. 检查填充情况
SELECT 
    COUNT(*) as total_messages,
    COUNT(conversation_key) as messages_with_key,
    COUNT(*) - COUNT(conversation_key) as messages_without_key,
    COUNT(CASE WHEN sender_id IS NOT NULL AND receiver_id IS NOT NULL AND conversation_key IS NULL THEN 1 END) as should_have_key_but_null
FROM messages;

-- 3. 检查触发器是否存在
SELECT 
    trigger_name, 
    event_manipulation, 
    event_object_table,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'messages' 
  AND trigger_name LIKE '%conversation_key%';

-- 4. 检查触发器函数是否存在
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_name = 'update_message_conversation_key';

-- 5. 查看一些示例数据
SELECT 
    id,
    sender_id,
    receiver_id,
    conversation_key,
    created_at
FROM messages
WHERE sender_id IS NOT NULL 
  AND receiver_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;

