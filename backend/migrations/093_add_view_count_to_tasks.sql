-- 添加 view_count 到 tasks 表（仅存库，不展示）
ALTER TABLE tasks
ADD COLUMN IF NOT EXISTS view_count INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN tasks.view_count IS '浏览量（仅存库，不展示到前端）';
