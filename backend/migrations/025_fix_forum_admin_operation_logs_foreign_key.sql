-- 修复论坛管理员操作日志表的外键约束
-- 创建时间: 2025-11-29
-- 说明: 将 operator_id 从引用 users.id 改为引用 admin_users.id

-- 1. 删除旧的外键约束
ALTER TABLE forum_admin_operation_logs 
DROP CONSTRAINT IF EXISTS forum_admin_operation_logs_operator_id_fkey;

-- 2. 修改 operator_id 字段类型（从 VARCHAR(8) 改为 VARCHAR(5)）
-- 注意：如果表中已有数据，需要先清理无效数据
-- 删除所有 operator_id 不在 admin_users 表中的记录
DELETE FROM forum_admin_operation_logs 
WHERE operator_id NOT IN (SELECT id FROM admin_users);

-- 3. 修改字段类型
ALTER TABLE forum_admin_operation_logs 
ALTER COLUMN operator_id TYPE VARCHAR(5);

-- 4. 添加新的外键约束指向 admin_users.id
ALTER TABLE forum_admin_operation_logs 
ADD CONSTRAINT forum_admin_operation_logs_operator_id_fkey 
FOREIGN KEY (operator_id) REFERENCES admin_users(id) ON DELETE CASCADE;

-- 5. 验证修改
-- 检查约束是否创建成功
SELECT 
    conname AS constraint_name,
    conrelid::regclass AS table_name,
    confrelid::regclass AS referenced_table
FROM pg_constraint
WHERE conname = 'forum_admin_operation_logs_operator_id_fkey';

