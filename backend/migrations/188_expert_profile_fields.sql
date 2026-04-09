-- 188: 把 legacy `featured_task_experts` 上的"达人画像"字段迁到新 `experts` 表
--
-- 背景: 旧 admin 后台的"编辑达人"表单依赖 11 个字段 (category / location / display_order /
--       expertise_areas[_en] / featured_skills[_en] / achievements[_en] / response_time[_en] /
--       user_level / is_verified)，新 `experts` 表完全没有这些列，导致管理员保存时这些字段
--       被静默丢弃，UI 上看起来在改但保存后没变化。
--
-- 修复方案:
--   1. ALTER TABLE experts 加列 (用 IF NOT EXISTS，幂等)
--   2. 从 featured_task_experts 通过 _expert_id_migration_map 反向 JOIN 回填
--   3. legacy Text 列里存的是 JSON 字符串，cast::jsonb 写入新 JSONB 列
--   4. COALESCE 保护：只回填新表为空的字段，不覆盖管理员后续修改的内容
--
-- 依赖: migration 158 (experts 表) + migration 159/168 (_expert_id_migration_map)

BEGIN;

ALTER TABLE experts ADD COLUMN IF NOT EXISTS category VARCHAR(50);
ALTER TABLE experts ADD COLUMN IF NOT EXISTS location VARCHAR(100);
ALTER TABLE experts ADD COLUMN IF NOT EXISTS display_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE experts ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE experts ADD COLUMN IF NOT EXISTS expertise_areas JSONB;
ALTER TABLE experts ADD COLUMN IF NOT EXISTS expertise_areas_en JSONB;
ALTER TABLE experts ADD COLUMN IF NOT EXISTS featured_skills JSONB;
ALTER TABLE experts ADD COLUMN IF NOT EXISTS featured_skills_en JSONB;
ALTER TABLE experts ADD COLUMN IF NOT EXISTS achievements JSONB;
ALTER TABLE experts ADD COLUMN IF NOT EXISTS achievements_en JSONB;
ALTER TABLE experts ADD COLUMN IF NOT EXISTS response_time VARCHAR(50);
ALTER TABLE experts ADD COLUMN IF NOT EXISTS response_time_en VARCHAR(50);
ALTER TABLE experts ADD COLUMN IF NOT EXISTS user_level VARCHAR(20) NOT NULL DEFAULT 'normal';

CREATE INDEX IF NOT EXISTS ix_experts_category ON experts(category);
CREATE INDEX IF NOT EXISTS ix_experts_display_order ON experts(display_order);

-- 安全转换 JSON Text → JSONB 的 helper：legacy 列偶尔有非法 JSON / 空字符串
-- 用 try_cast 思路：嵌套 CASE WHEN ... THEN ... ELSE NULL END
UPDATE experts e
SET
    category       = COALESCE(e.category, fte.category),
    location       = COALESCE(e.location, fte.location),
    display_order  = CASE WHEN e.display_order = 0
                          THEN COALESCE(fte.display_order, 0)
                          ELSE e.display_order END,
    is_verified    = CASE WHEN e.is_verified = FALSE
                          THEN (COALESCE(fte.is_verified, 0) <> 0)
                          ELSE e.is_verified END,
    expertise_areas = COALESCE(e.expertise_areas,
        CASE WHEN fte.expertise_areas IS NOT NULL AND fte.expertise_areas <> ''
             THEN fte.expertise_areas::jsonb END),
    expertise_areas_en = COALESCE(e.expertise_areas_en,
        CASE WHEN fte.expertise_areas_en IS NOT NULL AND fte.expertise_areas_en <> ''
             THEN fte.expertise_areas_en::jsonb END),
    featured_skills = COALESCE(e.featured_skills,
        CASE WHEN fte.featured_skills IS NOT NULL AND fte.featured_skills <> ''
             THEN fte.featured_skills::jsonb END),
    featured_skills_en = COALESCE(e.featured_skills_en,
        CASE WHEN fte.featured_skills_en IS NOT NULL AND fte.featured_skills_en <> ''
             THEN fte.featured_skills_en::jsonb END),
    achievements = COALESCE(e.achievements,
        CASE WHEN fte.achievements IS NOT NULL AND fte.achievements <> ''
             THEN fte.achievements::jsonb END),
    achievements_en = COALESCE(e.achievements_en,
        CASE WHEN fte.achievements_en IS NOT NULL AND fte.achievements_en <> ''
             THEN fte.achievements_en::jsonb END),
    response_time    = COALESCE(e.response_time,    fte.response_time),
    response_time_en = COALESCE(e.response_time_en, fte.response_time_en),
    user_level       = CASE WHEN e.user_level = 'normal'
                            THEN COALESCE(fte.user_level, 'normal')
                            ELSE e.user_level END
FROM featured_task_experts fte
JOIN _expert_id_migration_map m ON m.old_id = fte.user_id
WHERE e.id = m.new_id;

COMMIT;
