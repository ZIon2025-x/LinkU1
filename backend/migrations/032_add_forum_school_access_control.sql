-- ===========================================
-- 迁移文件032：添加论坛学校板块访问控制字段
-- 创建时间: 2025-12-06
-- 说明: 为 forum_categories 和 universities 表添加学校板块访问控制相关字段
-- ===========================================

BEGIN;

-- ==================== 1. forum_categories 表新增字段 ====================

-- 1.1 添加字段
ALTER TABLE forum_categories 
ADD COLUMN IF NOT EXISTS type VARCHAR(20) DEFAULT 'general',
ADD COLUMN IF NOT EXISTS country VARCHAR(10),
ADD COLUMN IF NOT EXISTS university_code VARCHAR(50);

-- 1.2 添加 type 字段的 CHECK 约束
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'chk_forum_type'
    ) THEN
        ALTER TABLE forum_categories 
        ADD CONSTRAINT chk_forum_type 
        CHECK (type IN ('general', 'root', 'university'));
    END IF;
END $$;

-- 1.3 添加 type 与 university_code 的关联约束
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'chk_forum_type_university_code'
    ) THEN
        ALTER TABLE forum_categories 
        ADD CONSTRAINT chk_forum_type_university_code 
        CHECK (
            (type = 'university' AND university_code IS NOT NULL) OR 
            (type IN ('general', 'root') AND university_code IS NULL)
        );
    END IF;
END $$;

-- 1.4 添加索引
CREATE INDEX IF NOT EXISTS idx_forum_categories_type_country 
ON forum_categories(type, country) 
WHERE type IN ('root', 'university');

CREATE INDEX IF NOT EXISTS idx_forum_categories_university_code 
ON forum_categories(university_code) 
WHERE university_code IS NOT NULL;

-- 1.5 创建"英国留学生"大板块（如果不存在）
INSERT INTO forum_categories (name, description, type, country, sort_order, is_visible)
SELECT '英国留学生', '英国留学生交流讨论区', 'root', 'UK', 0, true
WHERE NOT EXISTS (
    SELECT 1 FROM forum_categories WHERE name = '英国留学生'
);

-- ==================== 2. universities 表新增字段 ====================

-- 2.1 添加 country 字段（必须，用于判断是否英国大学）
ALTER TABLE universities 
ADD COLUMN IF NOT EXISTS country VARCHAR(10);

-- 添加索引
CREATE INDEX IF NOT EXISTS idx_universities_country 
ON universities(country) 
WHERE country IS NOT NULL;

-- 为现有英国大学填充 country（通过 email_domain 判断）
UPDATE universities 
SET country = 'UK' 
WHERE email_domain LIKE '%.ac.uk' AND country IS NULL;

-- 2.2 添加 code 字段（推荐，用于大学编码）
ALTER TABLE universities 
ADD COLUMN IF NOT EXISTS code VARCHAR(50);

-- 添加唯一索引
CREATE UNIQUE INDEX IF NOT EXISTS idx_universities_code_unique 
ON universities(code) 
WHERE code IS NOT NULL;

-- 示例：为现有大学填充 code（需要根据实际数据调整）
-- UPDATE universities SET code = 'UOB' WHERE email_domain = 'bristol.ac.uk';
-- UPDATE universities SET code = 'UOX' WHERE email_domain = 'ox.ac.uk';
-- UPDATE universities SET code = 'UCAM' WHERE email_domain = 'cam.ac.uk';

-- ==================== 3. 添加字段注释 ====================

COMMENT ON COLUMN forum_categories.type IS '板块类型: general(普通), root(国家/地区级大板块), university(大学级小板块)';
COMMENT ON COLUMN forum_categories.country IS '国家代码（如 UK），仅 type=root 时使用';
COMMENT ON COLUMN forum_categories.university_code IS '大学编码（如 UOB），仅 type=university 时使用，需与 universities.code 一致';
COMMENT ON COLUMN universities.country IS '国家代码（如 UK），用于判断是否英国大学';
COMMENT ON COLUMN universities.code IS '大学编码（如 UOB），用于与 forum_categories.university_code 关联';

COMMIT;

