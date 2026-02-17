-- ===========================================
-- 迁移文件092：任务与活动表增加中英双语字段（标题、描述）
-- 翻译结果写入对应字段，空则按需翻译后写入；任务翻译表暂停使用
-- ===========================================

-- 1. 任务表 tasks：增加 title_zh, title_en, description_zh, description_en
ALTER TABLE tasks
    ADD COLUMN IF NOT EXISTS title_zh VARCHAR(200) NULL,
    ADD COLUMN IF NOT EXISTS title_en VARCHAR(200) NULL,
    ADD COLUMN IF NOT EXISTS description_zh TEXT NULL,
    ADD COLUMN IF NOT EXISTS description_en TEXT NULL;

COMMENT ON COLUMN tasks.title_zh IS '标题（中文），首次翻译后写入';
COMMENT ON COLUMN tasks.title_en IS '标题（英文），首次翻译后写入';
COMMENT ON COLUMN tasks.description_zh IS '描述（中文），首次翻译后写入';
COMMENT ON COLUMN tasks.description_en IS '描述（英文），首次翻译后写入';

-- 2. 活动表 activities：增加 title_zh, title_en, description_zh, description_en
ALTER TABLE activities
    ADD COLUMN IF NOT EXISTS title_zh VARCHAR(200) NULL,
    ADD COLUMN IF NOT EXISTS title_en VARCHAR(200) NULL,
    ADD COLUMN IF NOT EXISTS description_zh TEXT NULL,
    ADD COLUMN IF NOT EXISTS description_en TEXT NULL;

COMMENT ON COLUMN activities.title_zh IS '标题（中文），首次翻译后写入';
COMMENT ON COLUMN activities.title_en IS '标题（英文），首次翻译后写入';
COMMENT ON COLUMN activities.description_zh IS '描述（中文），首次翻译后写入';
COMMENT ON COLUMN activities.description_en IS '描述（英文），首次翻译后写入';
