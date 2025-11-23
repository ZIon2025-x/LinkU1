-- ===========================================
-- 迁移 017: 将现有的多人任务迁移到活动表
-- ===========================================
--
-- 此迁移将现有的达人发布的多人任务迁移到新的活动表
-- 迁移策略：
-- 1. 查找所有 is_multi_participant=true 且 expert_creator_id IS NOT NULL 的任务
-- 2. 将这些任务的数据迁移到 activities 表
-- 3. 更新原任务的 parent_activity_id 指向新创建的活动
--
-- 执行时间: 2025-11-23
-- ===========================================

-- 开始事务
BEGIN;

-- 步骤1: 创建活动记录（从现有任务迁移）
-- 注意：使用 SERIAL 自增ID，所以新活动的ID会从现有最大ID+1开始
INSERT INTO activities (
    id,
    title,
    description,
    expert_id,
    expert_service_id,
    location,
    task_type,
    reward_type,
    original_price_per_participant,
    discount_percentage,
    discounted_price_per_participant,
    currency,
    points_reward,
    max_participants,
    min_participants,
    completion_rule,
    reward_distribution,
    status,
    is_public,
    visibility,
    deadline,
    activity_end_date,
    images,
    has_time_slots,
    created_at,
    updated_at
)
SELECT 
    t.id,  -- 使用原任务ID作为活动ID（保持一致性）
    t.title,
    t.description,
    t.expert_creator_id AS expert_id,
    t.expert_service_id,
    t.location,
    t.task_type,
    COALESCE(t.reward_type, 'cash') AS reward_type,
    t.original_price_per_participant,
    t.discount_percentage,
    t.discounted_price_per_participant,
    COALESCE(t.currency, 'GBP') AS currency,
    t.points_reward,
    COALESCE(t.max_participants, 1) AS max_participants,
    COALESCE(t.min_participants, 1) AS min_participants,
    COALESCE(t.completion_rule, 'all') AS completion_rule,
    COALESCE(t.reward_distribution, 'equal') AS reward_distribution,
    CASE 
        WHEN t.status IN ('open', 'taken') THEN 'open'
        WHEN t.status = 'completed' THEN 'completed'
        WHEN t.status = 'cancelled' THEN 'cancelled'
        ELSE 'open'
    END AS status,
    COALESCE(t.is_public = 1, true) AS is_public,
    COALESCE(t.visibility, 'public') AS visibility,
    t.deadline,
    NULL AS activity_end_date,  -- 暂时设为NULL，后续可根据需要更新
    t.images,
    COALESCE(
        EXISTS(
            SELECT 1 FROM activity_time_slot_relations atsr 
            WHERE atsr.activity_id = t.id
        ),
        false
    ) AS has_time_slots,
    t.created_at,
    t.updated_at
FROM tasks t
WHERE 
    t.is_multi_participant = true 
    AND t.expert_creator_id IS NOT NULL
    AND NOT EXISTS (
        -- 避免重复迁移（如果活动已存在）
        SELECT 1 FROM activities a WHERE a.id = t.id
    )
ON CONFLICT (id) DO NOTHING;  -- 如果ID冲突，跳过（已迁移）

-- 步骤2: 迁移时间段关联
-- 注意：如果之前使用的是 task_time_slot_relations 表，需要先迁移数据
-- 但根据新的设计，活动应该直接使用 activity_time_slot_relations 表
-- 这里假设旧数据已经在 task_time_slot_relations 表中（如果存在）
-- 如果不存在旧数据，此步骤将不会插入任何记录
DO $$
BEGIN
    -- 检查是否存在 task_time_slot_relations 表（旧表）
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'task_time_slot_relations'
    ) THEN
        -- 从旧表迁移数据到新表
        INSERT INTO activity_time_slot_relations (
            activity_id,
            time_slot_id,
            relation_mode,
            recurring_rule,
            auto_add_new_slots,
            activity_end_date,
            created_at,
            updated_at
        )
        SELECT 
            ttsr.task_id AS activity_id,  -- 使用原任务ID作为活动ID
            ttsr.time_slot_id,
            COALESCE(ttsr.relation_mode, 'fixed') AS relation_mode,
            ttsr.recurring_rule,
            COALESCE(ttsr.auto_add_new_slots, true) AS auto_add_new_slots,
            ttsr.activity_end_date,
            ttsr.created_at,
            ttsr.updated_at
        FROM task_time_slot_relations ttsr
        INNER JOIN tasks t ON t.id = ttsr.task_id
        WHERE 
            t.is_multi_participant = true 
            AND t.expert_creator_id IS NOT NULL
            AND EXISTS (
                -- 确保对应的活动已创建
                SELECT 1 FROM activities a WHERE a.id = ttsr.task_id
            )
            AND NOT EXISTS (
                -- 避免重复迁移
                SELECT 1 FROM activity_time_slot_relations atsr 
                WHERE atsr.activity_id = ttsr.task_id 
                AND atsr.time_slot_id = ttsr.time_slot_id
                AND atsr.relation_mode = COALESCE(ttsr.relation_mode, 'fixed')
            );
    END IF;
END $$;

-- 步骤3: 更新原任务的 parent_activity_id（指向新创建的活动）
UPDATE tasks t
SET parent_activity_id = t.id  -- 指向自己对应的活动（活动ID = 原任务ID）
WHERE 
    t.is_multi_participant = true 
    AND t.expert_creator_id IS NOT NULL
    AND EXISTS (
        -- 确保对应的活动已创建
        SELECT 1 FROM activities a WHERE a.id = t.id
    )
    AND t.parent_activity_id IS NULL;  -- 只更新未设置 parent_activity_id 的任务

-- 步骤4: 验证迁移结果
DO $$
DECLARE
    migrated_activities_count INTEGER;
    migrated_relations_count INTEGER;
    updated_tasks_count INTEGER;
BEGIN
    -- 统计迁移的活动数量
    SELECT COUNT(*) INTO migrated_activities_count
    FROM activities a
    INNER JOIN tasks t ON a.id = t.id
    WHERE t.is_multi_participant = true AND t.expert_creator_id IS NOT NULL;
    
    -- 统计迁移的时间段关联数量
    SELECT COUNT(*) INTO migrated_relations_count
    FROM activity_time_slot_relations atsr
    INNER JOIN tasks t ON atsr.activity_id = t.id
    WHERE t.is_multi_participant = true AND t.expert_creator_id IS NOT NULL;
    
    -- 统计更新的任务数量
    SELECT COUNT(*) INTO updated_tasks_count
    FROM tasks t
    WHERE t.is_multi_participant = true 
    AND t.expert_creator_id IS NOT NULL
    AND t.parent_activity_id = t.id;
    
    RAISE NOTICE '迁移完成统计:';
    RAISE NOTICE '  - 迁移活动数: %', migrated_activities_count;
    RAISE NOTICE '  - 迁移时间段关联数: %', migrated_relations_count;
    RAISE NOTICE '  - 更新任务 parent_activity_id 数: %', updated_tasks_count;
END $$;

-- 提交事务
COMMIT;

RAISE NOTICE '迁移 017 执行完成: 已将现有多人任务迁移到活动表';

