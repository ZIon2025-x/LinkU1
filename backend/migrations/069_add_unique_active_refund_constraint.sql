-- 添加唯一活跃退款约束
-- 迁移文件：069_add_unique_active_refund_constraint.sql
-- 确保每个任务在同一时间只能有一个活跃的退款申请（pending或processing状态）

-- 创建部分唯一索引，只对pending和processing状态的记录生效
CREATE UNIQUE INDEX IF NOT EXISTS uix_refund_requests_active_task 
ON refund_requests(task_id) 
WHERE status IN ('pending', 'processing');

-- 添加注释
COMMENT ON INDEX uix_refund_requests_active_task IS '确保每个任务在同一时间只能有一个活跃的退款申请（pending或processing状态）';
