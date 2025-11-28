-- 为论坛板块添加"是否禁止用户发帖"字段
-- 创建时间: 2025-01-27
-- 说明: 添加 is_admin_only 字段，允许管理员设置某些板块只能由管理员发帖

-- 添加 is_admin_only 字段
ALTER TABLE forum_categories 
ADD COLUMN IF NOT EXISTS is_admin_only BOOLEAN DEFAULT FALSE NOT NULL;

-- 添加注释
COMMENT ON COLUMN forum_categories.is_admin_only IS '是否禁止普通用户发帖，true表示只有管理员可以发帖';

-- 为"活动公告"板块设置默认值（如果存在）
UPDATE forum_categories 
SET is_admin_only = TRUE 
WHERE name = '活动公告' AND is_admin_only = FALSE;

