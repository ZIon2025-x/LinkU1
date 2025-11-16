-- 在 tasks 表中添加 is_flexible 字段
-- 用于标识任务是否是灵活时间模式（1=灵活，无截止日期；0=有截止日期）

-- 添加 is_flexible 字段
-- 如果字段已存在，会报错但会被错误处理逻辑捕获并跳过
ALTER TABLE tasks ADD COLUMN is_flexible INTEGER DEFAULT 0;

