-- 允许 tasks 表的 deadline 字段为 NULL（支持灵活模式任务）
-- 灵活模式任务没有截止日期，deadline 应该为 NULL

-- 修改 deadline 字段，允许为 NULL
ALTER TABLE tasks 
ALTER COLUMN deadline DROP NOT NULL;

-- 添加注释说明
COMMENT ON COLUMN tasks.deadline IS '任务截止日期。NULL 表示灵活模式，没有截止日期。';

