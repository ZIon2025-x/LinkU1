-- 迁移 021: 修复 message_read_cursors 表的外键约束
-- 目的：允许删除消息时，message_read_cursors 表的 last_read_message_id 自动设为 NULL
-- 问题：旧约束使用 RESTRICT 行为，导致无法删除被引用的消息
-- 解决：改为 SET NULL 行为，并允许 last_read_message_id 为 NULL

DO $$
BEGIN
    -- 1. 删除旧的外键约束（如果存在）
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'message_read_cursors_last_read_message_id_fkey'
        AND table_name = 'message_read_cursors'
    ) THEN
        ALTER TABLE message_read_cursors 
        DROP CONSTRAINT message_read_cursors_last_read_message_id_fkey;
        
        RAISE NOTICE '已删除旧的外键约束: message_read_cursors_last_read_message_id_fkey';
    END IF;

    -- 2. 修改列允许为 NULL（如果还不是可空）
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'message_read_cursors' 
        AND column_name = 'last_read_message_id'
        AND is_nullable = 'NO'
    ) THEN
        -- 先更新引用已删除消息的记录为 NULL（如果有）
        -- 注意：这里假设 messages 表中已删除的消息ID不存在
        -- 如果存在无效引用，先清理它们
        UPDATE message_read_cursors 
        SET last_read_message_id = NULL 
        WHERE last_read_message_id NOT IN (
            SELECT id FROM messages
        );
        
        -- 然后修改列为可空
        ALTER TABLE message_read_cursors 
        ALTER COLUMN last_read_message_id DROP NOT NULL;
        
        RAISE NOTICE '已将 last_read_message_id 列改为可空';
    END IF;

    -- 3. 重新创建外键约束，使用 SET NULL 行为
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'message_read_cursors_last_read_message_id_fkey'
        AND table_name = 'message_read_cursors'
    ) THEN
        ALTER TABLE message_read_cursors
        ADD CONSTRAINT message_read_cursors_last_read_message_id_fkey 
        FOREIGN KEY (last_read_message_id) 
        REFERENCES messages(id) 
        ON DELETE SET NULL;
        
        RAISE NOTICE '已创建新的外键约束（ON DELETE SET NULL）';
    END IF;

    RAISE NOTICE '迁移 021 执行完成: message_read_cursors 外键约束已修复';
END $$;

