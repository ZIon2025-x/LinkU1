-- 为论坛板块添加服务数和任务数缓存字段（用于发现页技能分类展示）
ALTER TABLE forum_categories ADD COLUMN IF NOT EXISTS service_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE forum_categories ADD COLUMN IF NOT EXISTS task_count INTEGER NOT NULL DEFAULT 0;
