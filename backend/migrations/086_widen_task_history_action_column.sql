-- 086: 扩大 task_history.action 列的长度限制
-- 日期: 2026-02-09
-- 原因: 原 varchar(20) 太短，无法容纳 auto_confirmed_completion (26)、
--       auto_confirmed_3days_pending_transfer (37) 等操作类型

ALTER TABLE task_history
    ALTER COLUMN action TYPE VARCHAR(50);
