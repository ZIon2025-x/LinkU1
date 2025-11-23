-- ===========================================
-- 迁移脚本：添加任务达人关门日期功能
-- 版本：v1.6
-- 创建日期：2025-01-23
-- ===========================================

-- ===========================================
-- 步骤1：创建任务达人关门日期表
-- ===========================================

CREATE TABLE IF NOT EXISTS expert_closed_dates (
    id SERIAL PRIMARY KEY,
    expert_id VARCHAR(8) NOT NULL REFERENCES task_experts(id) ON DELETE CASCADE,
    closed_date DATE NOT NULL,
    reason VARCHAR(200),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_expert_closed_date UNIQUE (expert_id, closed_date)
);

-- ===========================================
-- 步骤2：创建索引
-- ===========================================

CREATE INDEX IF NOT EXISTS ix_expert_closed_dates_expert_id ON expert_closed_dates(expert_id);
CREATE INDEX IF NOT EXISTS ix_expert_closed_dates_closed_date ON expert_closed_dates(closed_date);

-- ===========================================
-- 步骤3：添加注释
-- ===========================================

COMMENT ON TABLE expert_closed_dates IS '任务达人关门日期表 - 存储任务达人的休息日';
COMMENT ON COLUMN expert_closed_dates.expert_id IS '任务达人ID';
COMMENT ON COLUMN expert_closed_dates.closed_date IS '关门日期（不包含时间）';
COMMENT ON COLUMN expert_closed_dates.reason IS '关门原因（可选）';

