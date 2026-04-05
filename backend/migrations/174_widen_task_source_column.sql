-- 扩大 task_source 列宽度
-- 'flea_market_consultation' 有 25 个字符，超过原来的 VARCHAR(20)
ALTER TABLE tasks
ALTER COLUMN task_source TYPE VARCHAR(50);
