-- 在 Railway Web 控制台粘贴执行这个文件的内容

-- 1. 确保扩展已安装
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 2. 创建索引
CREATE INDEX IF NOT EXISTS idx_tasks_title_trgm ON tasks USING gin(title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_tasks_description_trgm ON tasks USING gin(description gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_tasks_type_trgm ON tasks USING gin(task_type gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_tasks_location_trgm ON tasks USING gin(location gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_users_name_trgm ON users USING gin(name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_users_email_trgm ON users USING gin(email gin_trgm_ops);

-- 3. 验证索引创建成功
SELECT schemaname, tablename, indexname 
FROM pg_indexes 
WHERE indexname LIKE '%_trgm';

