-- 修复 message_read_cursors 表的外键约束
-- 如果表是空的，可以直接删除并重建约束
-- 如果表有数据，需要先更新约束

-- 方法1：如果表是空的，删除并重建约束
-- 注意：先检查表是否真的为空
-- SELECT COUNT(*) FROM message_read_cursors;

-- 如果表是空的，执行以下SQL：
-- 1. 删除旧的外键约束
ALTER TABLE message_read_cursors 
DROP CONSTRAINT IF EXISTS message_read_cursors_last_read_message_id_fkey;

-- 2. 修改列允许为NULL
ALTER TABLE message_read_cursors 
ALTER COLUMN last_read_message_id DROP NOT NULL;

-- 3. 重新创建外键约束，使用 SET NULL 行为
ALTER TABLE message_read_cursors
ADD CONSTRAINT message_read_cursors_last_read_message_id_fkey 
FOREIGN KEY (last_read_message_id) 
REFERENCES messages(id) 
ON DELETE SET NULL;

-- 方法2：如果表有数据，需要先更新引用已删除消息的记录
-- UPDATE message_read_cursors 
-- SET last_read_message_id = NULL 
-- WHERE last_read_message_id IN (279, 280, 281);

-- 然后再执行方法1的步骤

