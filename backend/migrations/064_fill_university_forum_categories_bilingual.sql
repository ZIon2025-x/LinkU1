-- ===========================================
-- 迁移文件064：为学校论坛板块填充英文字段
-- 创建时间: 2026-01-20
-- 说明: 根据 universities 表的数据，为 type='university' 的论坛板块填充 name_en 和 description_en
-- ===========================================

BEGIN;

-- 更新所有 university 类型的板块，填充英文字段
UPDATE forum_categories fc
SET 
    name_en = COALESCE(
        fc.name_en,  -- 如果已有值，保持不变
        u.name       -- 否则使用大学的英文名称
    ),
    description_en = COALESCE(
        fc.description_en,  -- 如果已有值，保持不变
        CASE 
            WHEN fc.description IS NOT NULL AND fc.description != '' THEN
                u.name || ' Student Discussion Forum'
            ELSE
                u.name || ' Student Discussion Forum'
        END
    ),
    name_zh = COALESCE(
        fc.name_zh,  -- 如果已有值，保持不变
        u.name_cn    -- 否则使用大学的中文名称
    ),
    description_zh = COALESCE(
        fc.description_zh,  -- 如果已有值，保持不变
        fc.description      -- 否则使用原有的 description
    ),
    updated_at = NOW()
FROM universities u
WHERE 
    fc.type = 'university'
    AND fc.university_code IS NOT NULL
    AND fc.university_code = u.code
    AND (
        -- 只更新缺少多语言字段的板块
        fc.name_en IS NULL 
        OR fc.name_zh IS NULL 
        OR fc.description_en IS NULL 
        OR (fc.description_zh IS NULL AND fc.description IS NOT NULL)
    );

-- 输出更新统计
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE '已更新 % 个学校论坛板块的多语言字段', updated_count;
END $$;

COMMIT;

-- 验证更新结果
SELECT 
    fc.id,
    fc.name,
    fc.name_en,
    fc.name_zh,
    fc.description,
    fc.description_en,
    fc.description_zh,
    fc.university_code,
    u.name as university_name,
    u.name_cn as university_name_cn
FROM forum_categories fc
LEFT JOIN universities u ON fc.university_code = u.code
WHERE fc.type = 'university'
ORDER BY fc.id;
