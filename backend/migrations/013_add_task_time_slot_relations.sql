-- ===========================================
-- 迁移 013: 添加活动与时间段的关联表
-- ===========================================
-- 
-- 此迁移创建 activity_time_slot_relations 表，用于存储活动与时间段的关系
-- 支持两种模式：
-- 1. 固定时间段模式：直接关联具体的时间段ID
-- 2. 重复模式：通过规则匹配时间段（每天/每周几的某些时间段）
--
-- 注意：此表用于活动（Activity），不是任务（Task）
-- 执行时间: 2025-11-23
-- ===========================================

-- 创建活动与时间段的关联表
-- 注意：activities表在015迁移中创建，所以这里先不添加外键约束
-- 外键约束将在015迁移后添加（在016或018迁移中）
CREATE TABLE IF NOT EXISTS activity_time_slot_relations (
    id SERIAL PRIMARY KEY,
    activity_id INTEGER NOT NULL,  -- 外键约束将在015迁移后添加
    time_slot_id INTEGER REFERENCES service_time_slots(id) ON DELETE CASCADE,
    -- 关联模式：'fixed' = 固定时间段，'recurring' = 重复模式
    relation_mode VARCHAR(20) NOT NULL DEFAULT 'fixed',
    -- 重复规则（JSON格式，仅用于recurring模式）
    -- 例如：{"type": "daily", "time_ranges": [{"start": "10:00", "end": "12:00"}, {"start": "14:00", "end": "16:00"}]}
    -- 或：{"type": "weekly", "weekdays": [1, 3, 5], "time_ranges": [{"start": "10:00", "end": "12:00"}]}
    recurring_rule JSONB,
    -- 是否自动添加新匹配的时间段
    auto_add_new_slots BOOLEAN DEFAULT TRUE,
    -- 活动截至日期（可选，如果设置则在此时活动自动结束）
    activity_end_date DATE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    -- 约束：固定模式必须有time_slot_id，重复模式必须有recurring_rule
    CONSTRAINT chk_relation_mode CHECK (
        (relation_mode = 'fixed' AND time_slot_id IS NOT NULL) OR
        (relation_mode = 'recurring' AND recurring_rule IS NOT NULL)
    )
);

-- 创建索引
CREATE INDEX IF NOT EXISTS ix_activity_time_slot_relations_activity_id ON activity_time_slot_relations(activity_id);
CREATE INDEX IF NOT EXISTS ix_activity_time_slot_relations_time_slot_id ON activity_time_slot_relations(time_slot_id);
CREATE INDEX IF NOT EXISTS ix_activity_time_slot_relations_mode ON activity_time_slot_relations(relation_mode);
CREATE INDEX IF NOT EXISTS ix_activity_time_slot_relations_end_date ON activity_time_slot_relations(activity_end_date);

-- 唯一约束：一个时间段只能被一个活动使用（固定模式）
CREATE UNIQUE INDEX IF NOT EXISTS uq_activity_time_slot_fixed 
    ON activity_time_slot_relations(time_slot_id) 
    WHERE relation_mode = 'fixed' AND time_slot_id IS NOT NULL;

-- 添加注释
COMMENT ON TABLE activity_time_slot_relations IS '活动与时间段的关联表，支持固定时间段和重复模式';
COMMENT ON COLUMN activity_time_slot_relations.relation_mode IS '关联模式：fixed=固定时间段，recurring=重复模式';
COMMENT ON COLUMN activity_time_slot_relations.recurring_rule IS '重复规则（JSON格式），仅用于recurring模式';
COMMENT ON COLUMN activity_time_slot_relations.auto_add_new_slots IS '是否自动添加新匹配的时间段';
COMMENT ON COLUMN activity_time_slot_relations.activity_end_date IS '活动截至日期（可选）';

-- 添加更新时间触发器
CREATE OR REPLACE FUNCTION update_activity_time_slot_relations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_activity_time_slot_relations_updated_at
    BEFORE UPDATE ON activity_time_slot_relations
    FOR EACH ROW
    EXECUTE FUNCTION update_activity_time_slot_relations_updated_at();

RAISE NOTICE '迁移 013 执行完成: 已创建活动与时间段的关联表 (activity_time_slot_relations)';

