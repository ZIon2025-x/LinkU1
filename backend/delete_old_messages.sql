-- 删除无任务ID的旧普通消息（联系人聊天功能已废弃）
-- 执行前请确保 message_read_cursors 表的外键约束已修复

-- 1. 先删除 message_read_cursors 中引用这些消息的记录（如果有）
UPDATE message_read_cursors 
SET last_read_message_id = NULL 
WHERE last_read_message_id IN (
    SELECT id FROM messages 
    WHERE task_id IS NULL 
    AND receiver_id IS NOT NULL
);

-- 2. 删除 message_reads 中引用这些消息的记录（会自动级联删除，但为了安全先手动删除）
DELETE FROM message_reads 
WHERE message_id IN (
    SELECT id FROM messages 
    WHERE task_id IS NULL 
    AND receiver_id IS NOT NULL
);

-- 3. 删除 message_attachments 中引用这些消息的记录（如果有）
DELETE FROM message_attachments 
WHERE message_id IN (
    SELECT id FROM messages 
    WHERE task_id IS NULL 
    AND receiver_id IS NOT NULL
);

-- 4. 最后删除这些旧消息
DELETE FROM messages 
WHERE task_id IS NULL 
AND receiver_id IS NOT NULL
AND sender_id IS NOT NULL
AND sender_id NOT IN ('system', 'SYSTEM')
AND message_type != 'system';

-- 查看删除结果
-- SELECT COUNT(*) FROM messages WHERE task_id IS NULL AND receiver_id IS NOT NULL;

