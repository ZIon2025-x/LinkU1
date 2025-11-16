-- 允许 tasks 表的 deadline 字段为 NULL（支持灵活模式任务）
-- 灵活模式任务没有截止日期，deadline 应该为 NULL

-- 修改 deadline 字段，允许为 NULL
-- 如果字段当前不允许为 NULL，则修改；如果已经是 NULL，则跳过（不会报错）
ALTER TABLE tasks ALTER COLUMN deadline DROP NOT NULL;

