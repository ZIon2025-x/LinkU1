-- 添加 task_source 字段到 tasks 表
-- 用于区分任务来源：普通任务、达人服务、达人活动、跳蚤市场

-- 1. 添加 task_source 字段
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS task_source VARCHAR(20) DEFAULT 'normal';

-- 2. 添加注释
COMMENT ON COLUMN tasks.task_source IS '任务来源：normal（普通任务）、expert_service（达人服务）、expert_activity（达人活动）、flea_market（跳蚤市场）';

-- 3. 更新现有数据
-- 3.1 达人活动：parent_activity_id 不为 NULL
UPDATE tasks 
SET task_source = 'expert_activity' 
WHERE parent_activity_id IS NOT NULL 
  AND task_source = 'normal';

-- 3.2 达人服务：expert_service_id 不为 NULL 且 parent_activity_id 为 NULL
UPDATE tasks 
SET task_source = 'expert_service' 
WHERE expert_service_id IS NOT NULL 
  AND parent_activity_id IS NULL 
  AND task_source = 'normal';

-- 3.3 跳蚤市场：通过 FleaMarketItem.sold_task_id 关联
UPDATE tasks 
SET task_source = 'flea_market' 
WHERE id IN (
    SELECT DISTINCT sold_task_id 
    FROM flea_market_items 
    WHERE sold_task_id IS NOT NULL
) 
  AND task_source = 'normal';

-- 4. 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS ix_tasks_task_source 
ON tasks(task_source);

-- 5. 添加复合索引（task_source + status）
CREATE INDEX IF NOT EXISTS ix_tasks_source_status 
ON tasks(task_source, status);

-- 6. 添加注释
COMMENT ON INDEX ix_tasks_task_source IS '任务来源索引（用于快速筛选不同类型的任务）';
COMMENT ON INDEX ix_tasks_source_status IS '任务来源和状态复合索引（用于按来源和状态查询）';
