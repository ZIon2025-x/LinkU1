-- 指定任务被指定方反报价字段
-- 迁移文件：103_add_counter_offer_to_tasks.sql
-- 允许被指定方在 pending_acceptance 阶段提出反报价，发布方可接受或拒绝

-- 添加字段
ALTER TABLE tasks
    ADD COLUMN IF NOT EXISTS counter_offer_price   NUMERIC(12, 2) DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS counter_offer_status  VARCHAR(20)    DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS counter_offer_user_id VARCHAR(8)     DEFAULT NULL;

-- 外键：被指定方用户 ID（用户删除时置空）
ALTER TABLE tasks
    ADD CONSTRAINT IF NOT EXISTS fk_tasks_counter_offer_user
    FOREIGN KEY (counter_offer_user_id) REFERENCES users(id) ON DELETE SET NULL;

-- 注释
COMMENT ON COLUMN tasks.counter_offer_price   IS '被指定方提出的反报价金额（英镑）';
COMMENT ON COLUMN tasks.counter_offer_status  IS '反报价状态：NULL=无/pending=待回应/accepted=已接受/rejected=已拒绝';
COMMENT ON COLUMN tasks.counter_offer_user_id IS '提出反报价的用户 ID（即被指定的接单方）';
