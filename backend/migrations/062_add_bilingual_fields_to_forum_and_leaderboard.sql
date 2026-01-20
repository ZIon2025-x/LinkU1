-- 添加双语字段到论坛板块和排行榜
-- 迁移文件：062_add_bilingual_fields_to_forum_and_leaderboard.sql
-- 创建时间: 2025-01-XX

-- 1. 为论坛板块表添加双语字段
ALTER TABLE forum_categories
    ADD COLUMN IF NOT EXISTS name_en VARCHAR(100) NULL,
    ADD COLUMN IF NOT EXISTS name_zh VARCHAR(100) NULL,
    ADD COLUMN IF NOT EXISTS description_en TEXT NULL,
    ADD COLUMN IF NOT EXISTS description_zh TEXT NULL;

-- 2. 为自定义排行榜表添加双语字段
ALTER TABLE custom_leaderboards
    ADD COLUMN IF NOT EXISTS name_en VARCHAR(100) NULL,
    ADD COLUMN IF NOT EXISTS name_zh VARCHAR(100) NULL,
    ADD COLUMN IF NOT EXISTS description_en TEXT NULL,
    ADD COLUMN IF NOT EXISTS description_zh TEXT NULL;

-- 3. 为论坛板块申请表添加双语字段（用于申请时填写）
ALTER TABLE forum_category_requests
    ADD COLUMN IF NOT EXISTS name_en VARCHAR(100) NULL,
    ADD COLUMN IF NOT EXISTS name_zh VARCHAR(100) NULL,
    ADD COLUMN IF NOT EXISTS description_en TEXT NULL,
    ADD COLUMN IF NOT EXISTS description_zh TEXT NULL;

-- 4. 添加注释
COMMENT ON COLUMN forum_categories.name_en IS '板块名称（英文）';
COMMENT ON COLUMN forum_categories.name_zh IS '板块名称（中文）';
COMMENT ON COLUMN forum_categories.description_en IS '板块描述（英文）';
COMMENT ON COLUMN forum_categories.description_zh IS '板块描述（中文）';

COMMENT ON COLUMN custom_leaderboards.name_en IS '排行榜名称（英文）';
COMMENT ON COLUMN custom_leaderboards.name_zh IS '排行榜名称（中文）';
COMMENT ON COLUMN custom_leaderboards.description_en IS '排行榜描述（英文）';
COMMENT ON COLUMN custom_leaderboards.description_zh IS '排行榜描述（中文）';

COMMENT ON COLUMN forum_category_requests.name_en IS '申请的板块名称（英文）';
COMMENT ON COLUMN forum_category_requests.name_zh IS '申请的板块名称（中文）';
COMMENT ON COLUMN forum_category_requests.description_en IS '申请的板块描述（英文）';
COMMENT ON COLUMN forum_category_requests.description_zh IS '申请的板块描述（中文）';
