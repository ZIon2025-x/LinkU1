-- 210: Phase A catch-up — 把 legacy TaskExpert / FeaturedTaskExpert 字段同步到 Expert / FeaturedExpertV2
--
-- 背景: migration 159/168/170/185 已把 task_experts → experts + expert_members 完成。
--       但 crud/user.py.sync_user_task_stats 只写 TaskExpert 不写 Expert,所以 Expert
--       的 rating/completed_tasks/... 从 159 之后一直停留在快照。migration 188 补过画像
--       字段但用 COALESCE 未覆盖 stats,并漏了 bio_en。
-- 目标:
--   1) ALTER experts 加 success_rate 列 (FTE 有但 Expert 无)
--   2) 从 task_experts 同步 rating/total_services/completed_tasks/is_official/official_badge/name/bio/avatar
--   3) 从 featured_task_experts 同步 completion_rate + success_rate (FTE 权威)
--   4) 从 featured_task_experts 补画像字段 (migration 188 漏项 bio_en 等)
--   5) featured_experts_v2 精简字段补刷
--
-- 执行机制 (atomicity 边界):
-- backend/app/db_migrations.py 的 execute_sql_file 会把 SQL 按 statement 拆分并
-- 逐条 commit. 这意味着:
--   - ALTER TABLE / CREATE INDEX (外部) 单独 commit, 不受 DO 块影响
--   - DO $$ ... $$ 块是一条 statement, 内部 RAISE EXCEPTION **只回滚 DO 块本身**
--   - execute_sql_file 对 statement 异常是 WARNING + 继续; 若 DO 块 RAISE,
--     migration 会被标记为"成功"但数据回填没跑. 这是已知 R10 风险, 通过发布
--     流程 T+0.1 查 logs 里 "210 complete: orphans=0, ..." NOTICE 兜底检测.
-- 因此 ALTER 用 IF NOT EXISTS 幂等保护, 重跑无副作用; DO 块所有 UPDATE
-- 使用 IS DISTINCT FROM 过滤 (step 1) 或 COALESCE 幂等策略 (step 2-5).

-- Schema 变更 (ALTER 不能放 DO 内部)
ALTER TABLE experts ADD COLUMN IF NOT EXISTS success_rate FLOAT NOT NULL DEFAULT 0.0;
CREATE INDEX IF NOT EXISTS ix_experts_success_rate ON experts(success_rate);

-- 数据回填 + 验证 (整个 DO 块作为单个 statement,RAISE EXCEPTION 回滚整个块)
DO $$
DECLARE
    orphan_count INTEGER;
    service_orphan_count INTEGER;
    stats_mismatch INTEGER;
    aggregate_mismatch INTEGER;
BEGIN
    -- 前置 orphan 检查: 任何 task_expert 没有映射即中止回滚
    SELECT COUNT(*) INTO orphan_count
    FROM task_experts te
    WHERE NOT EXISTS (SELECT 1 FROM _expert_id_migration_map m WHERE m.old_id = te.id);
    IF orphan_count > 0 THEN
        RAISE EXCEPTION '210: % orphan task_experts without mapping — run migration 185 first', orphan_count;
    END IF;

    -- 1. 统计字段 (TE 权威: rating/completed_tasks/total_services + is_official/official_badge)
    --    completion_rate 不从 TE 取 (TaskExpert 模型未定义,DB 列无维护)
    UPDATE experts e
    SET rating          = COALESCE(te.rating, e.rating),
        total_services  = COALESCE(te.total_services, e.total_services),
        completed_tasks = COALESCE(te.completed_tasks, e.completed_tasks),
        is_official     = COALESCE(te.is_official, e.is_official),
        official_badge  = COALESCE(te.official_badge, e.official_badge),
        updated_at      = NOW()
    FROM _expert_id_migration_map m
    JOIN task_experts te ON te.id = m.old_id
    WHERE e.id = m.new_id
      AND (te.rating IS DISTINCT FROM e.rating
        OR te.total_services IS DISTINCT FROM e.total_services
        OR te.completed_tasks IS DISTINCT FROM e.completed_tasks);

    -- 2. 基础展示字段 (updated_at 较新一侧为准)
    UPDATE experts e
    SET name   = CASE WHEN te.updated_at > e.updated_at
                      THEN COALESCE(te.expert_name, e.name) ELSE e.name END,
        bio    = CASE WHEN te.updated_at > e.updated_at
                      THEN COALESCE(te.bio, e.bio) ELSE e.bio END,
        avatar = CASE WHEN te.updated_at > e.updated_at
                      THEN COALESCE(te.avatar, e.avatar) ELSE e.avatar END
    FROM _expert_id_migration_map m
    JOIN task_experts te ON te.id = m.old_id
    WHERE e.id = m.new_id;

    -- 3. 聚合指标回填 (FTE 权威 — 由 crud/task_expert.py.update_task_expert_bio 聚合写入)
    UPDATE experts e
    SET completion_rate = COALESCE(fte.completion_rate, e.completion_rate),
        success_rate    = COALESCE(fte.success_rate, e.success_rate)
    FROM _expert_id_migration_map m
    JOIN featured_task_experts fte ON fte.user_id = m.old_id
    WHERE e.id = m.new_id
      AND (fte.completion_rate IS DISTINCT FROM e.completion_rate
        OR fte.success_rate    IS DISTINCT FROM e.success_rate);

    -- 4. 画像字段补刷 (补 migration 188 漏项; COALESCE 保留 Expert 已有值)
    --    WHERE 仅按 id 匹配,无 IS DISTINCT FROM 过滤 — 重跑会 touch 所有行的 updated_at,
    --    但值不变。折衷选择:写 ~12 字段的 IS DISTINCT FROM 条件串可读性差。
    UPDATE experts e
    SET bio_en             = COALESCE(e.bio_en, fte.bio_en),
        expertise_areas    = COALESCE(e.expertise_areas,
            CASE WHEN fte.expertise_areas IS NOT NULL AND fte.expertise_areas <> ''
                 THEN fte.expertise_areas::jsonb END),
        expertise_areas_en = COALESCE(e.expertise_areas_en,
            CASE WHEN fte.expertise_areas_en IS NOT NULL AND fte.expertise_areas_en <> ''
                 THEN fte.expertise_areas_en::jsonb END),
        featured_skills    = COALESCE(e.featured_skills,
            CASE WHEN fte.featured_skills IS NOT NULL AND fte.featured_skills <> ''
                 THEN fte.featured_skills::jsonb END),
        featured_skills_en = COALESCE(e.featured_skills_en,
            CASE WHEN fte.featured_skills_en IS NOT NULL AND fte.featured_skills_en <> ''
                 THEN fte.featured_skills_en::jsonb END),
        achievements       = COALESCE(e.achievements,
            CASE WHEN fte.achievements IS NOT NULL AND fte.achievements <> ''
                 THEN fte.achievements::jsonb END),
        achievements_en    = COALESCE(e.achievements_en,
            CASE WHEN fte.achievements_en IS NOT NULL AND fte.achievements_en <> ''
                 THEN fte.achievements_en::jsonb END),
        response_time      = COALESCE(e.response_time, fte.response_time),
        response_time_en   = COALESCE(e.response_time_en, fte.response_time_en),
        category           = COALESCE(e.category, fte.category),
        location           = COALESCE(e.location, fte.location),
        display_order      = CASE WHEN e.display_order = 0
                                  THEN COALESCE(fte.display_order, 0)
                                  ELSE e.display_order END,
        is_verified        = CASE WHEN e.is_verified = false
                                  THEN (COALESCE(fte.is_verified, 0) <> 0)
                                  ELSE e.is_verified END,
        user_level         = CASE WHEN e.user_level = 'normal'
                                  THEN COALESCE(fte.user_level, 'normal')
                                  ELSE e.user_level END
    FROM featured_task_experts fte
    JOIN _expert_id_migration_map m ON m.old_id = fte.user_id
    WHERE e.id = m.new_id;

    -- 5. FeaturedExpertV2 精简字段补刷
    UPDATE featured_experts_v2 fv2
    SET category      = COALESCE(fv2.category, fte.category),
        is_featured   = CASE WHEN fv2.is_featured = false
                             THEN COALESCE(fte.is_featured, 0) <> 0
                             ELSE fv2.is_featured END,
        display_order = CASE WHEN fv2.display_order = 0
                             THEN COALESCE(fte.display_order, 0)
                             ELSE fv2.display_order END
    FROM _expert_id_migration_map m
    JOIN featured_task_experts fte ON fte.user_id = m.old_id
    WHERE fv2.expert_id = m.new_id;

    -- 6. 后置验证 (WARNING 级别,不中止)
    SELECT COUNT(*) INTO service_orphan_count
    FROM task_expert_services
    WHERE service_type = 'expert' AND owner_id IS NULL;
    IF service_orphan_count > 0 THEN
        RAISE WARNING '210: % task_expert_services with service_type=expert have NULL owner_id', service_orphan_count;
    END IF;

    SELECT COUNT(*) INTO stats_mismatch
    FROM _expert_id_migration_map m
    JOIN task_experts te ON te.id = m.old_id
    JOIN experts e ON e.id = m.new_id
    WHERE te.rating IS DISTINCT FROM e.rating
       OR te.completed_tasks IS DISTINCT FROM e.completed_tasks;
    IF stats_mismatch > 0 THEN
        RAISE WARNING '210: % experts still have stats mismatch — manual check', stats_mismatch;
    END IF;

    SELECT COUNT(*) INTO aggregate_mismatch
    FROM _expert_id_migration_map m
    JOIN featured_task_experts fte ON fte.user_id = m.old_id
    JOIN experts e ON e.id = m.new_id
    WHERE fte.completion_rate IS DISTINCT FROM e.completion_rate
       OR fte.success_rate    IS DISTINCT FROM e.success_rate;
    IF aggregate_mismatch > 0 THEN
        RAISE WARNING '210: % experts completion_rate/success_rate mismatch with FTE', aggregate_mismatch;
    END IF;

    RAISE NOTICE '210 complete: orphans=%, service_orphans=%, stats_mismatch=%, aggregate_mismatch=%',
        orphan_count, service_orphan_count, stats_mismatch, aggregate_mismatch;
END $$;
