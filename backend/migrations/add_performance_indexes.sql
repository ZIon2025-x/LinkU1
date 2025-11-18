-- ============================================
-- LinkU 数据库性能优化索引迁移脚本
-- 创建日期: 2025-01-27
-- 说明: 根据《数据库读取功能优化开发文档》创建所有必要的索引
-- ============================================

-- ============================================
-- 1. 启用 PostgreSQL 扩展
-- ============================================

-- 启用 pg_trgm 扩展（用于相似度搜索）
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================
-- 2. 任务表索引
-- ============================================

-- 游标分页索引（用于按时间排序的查询）
CREATE INDEX IF NOT EXISTS ix_tasks_status_created_id 
ON tasks(status, created_at DESC, id DESC)
WHERE status IN ('open', 'taken');

-- 组合查询索引（任务类型+地点+状态）
CREATE INDEX IF NOT EXISTS ix_tasks_type_location_status 
ON tasks(task_type, location, status)
WHERE status IN ('open', 'taken');

-- 用户发布任务查询索引
CREATE INDEX IF NOT EXISTS ix_tasks_poster_status_created 
ON tasks(poster_id, status, created_at DESC);

-- 用户接受任务查询索引
CREATE INDEX IF NOT EXISTS ix_tasks_taker_status_created 
ON tasks(taker_id, status, created_at DESC);

-- 关键词搜索索引（pg_trgm）
CREATE INDEX IF NOT EXISTS idx_tasks_title_trgm 
ON tasks USING gin(title gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_tasks_description_trgm 
ON tasks USING gin(description gin_trgm_ops);

-- 全文搜索索引（可选，如果使用全文搜索）
CREATE INDEX IF NOT EXISTS idx_tasks_search 
ON tasks USING gin(to_tsvector('english', title || ' ' || description));

-- ============================================
-- 3. 申请表索引
-- ============================================

-- 申请者查询索引
CREATE INDEX IF NOT EXISTS ix_applications_applicant_created 
ON task_applications(applicant_id, created_at DESC);

-- 任务申请状态查询索引
CREATE INDEX IF NOT EXISTS ix_applications_task_status 
ON task_applications(task_id, status);

-- ============================================
-- 4. 消息表索引（优化方案：使用 conversation_key）
-- ============================================

-- 1. 添加 conversation_key 字段（如果还没有）
ALTER TABLE messages ADD COLUMN IF NOT EXISTS conversation_key VARCHAR(255);

-- 2. 填充 conversation_key（使用 least/greatest 确保一致性）
UPDATE messages 
SET conversation_key = LEAST(sender_id::text, receiver_id::text) || '-' || 
                      GREATEST(sender_id::text, receiver_id::text)
WHERE conversation_key IS NULL AND sender_id IS NOT NULL AND receiver_id IS NOT NULL;

-- 3. 创建对话查询索引
CREATE INDEX IF NOT EXISTS ix_messages_conversation_created 
ON messages(conversation_key, created_at DESC)
WHERE conversation_key IS NOT NULL;

-- 4. 接收者查询索引
CREATE INDEX IF NOT EXISTS ix_messages_receiver_created 
ON messages(receiver_id, created_at DESC);

-- 5. 添加触发器，自动维护 conversation_key（可选）
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

-- 删除旧触发器（如果存在）
DROP TRIGGER IF EXISTS trigger_update_conversation_key ON messages;

-- 创建触发器
CREATE TRIGGER trigger_update_conversation_key
BEFORE INSERT OR UPDATE ON messages
FOR EACH ROW
EXECUTE FUNCTION update_message_conversation_key();

-- ============================================
-- 5. 通知表索引
-- ============================================

-- 用户通知查询索引（用户ID + 已读状态 + 创建时间）
CREATE INDEX IF NOT EXISTS ix_notifications_user_read_created 
ON notifications(user_id, is_read, created_at DESC);

-- ============================================
-- 6. 分析表，更新统计信息
-- ============================================

ANALYZE tasks;
ANALYZE task_applications;
ANALYZE messages;
ANALYZE notifications;

-- ============================================
-- 7. 验证索引创建情况
-- ============================================

-- 查看所有新创建的索引
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename IN ('tasks', 'task_applications', 'messages', 'notifications')
  AND indexname LIKE 'ix_%' OR indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

