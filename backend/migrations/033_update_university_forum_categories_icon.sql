-- ===========================================
-- 迁移文件033：为所有大学板块设置统一图标
-- 创建时间: 2025-12-06
-- 说明: 为所有 type='university' 的论坛板块设置统一的图标 🏫
-- ===========================================

BEGIN;

-- 更新所有大学板块的icon（如果还没有设置）
UPDATE forum_categories 
SET icon = '🏫'
WHERE type = 'university' 
  AND (icon IS NULL OR icon = '');

-- 显示更新结果
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '已更新 % 个大学板块的图标', updated_count;
END $$;

COMMIT;

