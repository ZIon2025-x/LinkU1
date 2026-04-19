-- Migration 213: Task 咨询占位任务改用 original_task_id 外键替代 description 字符串
--
-- 目的:
--   1) tasks 表新增 original_task_id 列(指向 tasks.id 自身),作为 task_consultation
--      占位任务对原始任务的正式引用
--   2) backfill: 从 description='original_task_id:{id}' 解析后写入新字段,
--      并把 description 替换为原始任务的 description(占位 Task 现在能展示真实内容)
--   3) 与 Service 咨询(service_id) / FleaMarket 咨询(item_id) 对称,消除字符串解析
--
-- 背景:
--   原实现把 description 字段征用为 "original_task_id:{id}" 字符串,三个问题:
--     - description 被占用,占位 Task 无法展示真实咨询内容
--     - 无法 SQL 联接(查某任务的所有咨询占位任务)
--     - 字符串解析脆弱(被人工编辑即断)
--
-- 兼容性:
--   - 代码同步更新(task_chat_routes.py / task_chat_business_logic.py):
--     写入路径直接写新字段;读取路径优先读新字段,fallback 解析字符串以保证过渡期安全。
--   - 本迁移可多次执行(IF NOT EXISTS);backfill 用 UPDATE ... WHERE original_task_id IS NULL 幂等。

BEGIN;

-- 1. 加列
ALTER TABLE tasks
    ADD COLUMN IF NOT EXISTS original_task_id INTEGER
    REFERENCES tasks(id) ON DELETE SET NULL;

-- 2. 辅助索引(部分索引,只索引咨询占位行)
CREATE INDEX IF NOT EXISTS idx_tasks_original_task_id
    ON tasks(original_task_id)
    WHERE original_task_id IS NOT NULL;

-- 3. Backfill: 解析 description='original_task_id:{N}' 的值到新字段
UPDATE tasks AS t
SET original_task_id = CAST(
    SUBSTRING(t.description FROM '^original_task_id:([0-9]+)$') AS INTEGER
)
WHERE t.task_source = 'task_consultation'
  AND t.description ~ '^original_task_id:[0-9]+$'
  AND t.original_task_id IS NULL;

-- 4. 把占位 Task 的 description 从 "original_task_id:X" 替换为原任务的 description
--    (按用户决策:占位 Task 的 description 就用主任务描述)
UPDATE tasks AS t
SET description = orig.description
FROM tasks AS orig
WHERE t.original_task_id = orig.id
  AND t.task_source = 'task_consultation'
  AND t.description ~ '^original_task_id:[0-9]+$';

COMMIT;
