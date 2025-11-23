-- ===========================================
-- 迁移脚本：添加多人任务功能
-- 版本：v1.5
-- 创建日期：2025-01-20
-- ===========================================

-- ⚠️ 重要：执行顺序
-- 1. 先添加字段（允许NULL）
-- 2. 迁移历史数据
-- 3. 添加约束和索引
-- 4. 创建新表
-- 5. 创建触发器

-- ===========================================
-- 步骤1：为 tasks 表添加多人任务相关字段
-- ===========================================

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS is_multi_participant BOOLEAN DEFAULT false;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS is_official_task BOOLEAN DEFAULT false;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS max_participants INTEGER DEFAULT 1;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS min_participants INTEGER DEFAULT 1;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS current_participants INTEGER DEFAULT 0;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS completion_rule VARCHAR(20) DEFAULT 'all';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS reward_distribution VARCHAR(20) DEFAULT 'equal';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS reward_type VARCHAR(20) DEFAULT 'cash';
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS points_reward BIGINT DEFAULT 0;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS auto_accept BOOLEAN DEFAULT false;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS allow_negotiation BOOLEAN DEFAULT true;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS created_by_admin BOOLEAN DEFAULT false;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS admin_creator_id VARCHAR(36);
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS created_by_expert BOOLEAN DEFAULT false;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS expert_creator_id VARCHAR(8);
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS expert_service_id INTEGER;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS is_fixed_time_slot BOOLEAN DEFAULT false;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS time_slot_duration_minutes INTEGER;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS time_slot_start_time TIME;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS time_slot_end_time TIME;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS participants_per_slot INTEGER;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS original_price_per_participant DECIMAL(12, 2);
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS discount_percentage DECIMAL(5, 2);
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS discounted_price_per_participant DECIMAL(12, 2);
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;

-- 添加外键约束（如果表存在且约束不存在）
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'admin_users') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conname = 'fk_tasks_admin_creator' 
            AND conrelid = 'tasks'::regclass
        ) THEN
            ALTER TABLE tasks ADD CONSTRAINT fk_tasks_admin_creator 
                FOREIGN KEY (admin_creator_id) REFERENCES admin_users(id);
        END IF;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conname = 'fk_tasks_expert_creator' 
            AND conrelid = 'tasks'::regclass
        ) THEN
            ALTER TABLE tasks ADD CONSTRAINT fk_tasks_expert_creator 
                FOREIGN KEY (expert_creator_id) REFERENCES users(id);
        END IF;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'task_expert_services') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conname = 'fk_tasks_expert_service' 
            AND conrelid = 'tasks'::regclass
        ) THEN
            ALTER TABLE tasks ADD CONSTRAINT fk_tasks_expert_service 
                FOREIGN KEY (expert_service_id) REFERENCES task_expert_services(id) ON DELETE RESTRICT;
        END IF;
    END IF;
END $$;

-- ===========================================
-- 步骤2：迁移历史数据
-- ===========================================

-- 2.1 补齐 reward_type
UPDATE tasks SET reward_type = 'cash' WHERE reward_type IS NULL AND reward > 0;
UPDATE tasks SET reward_type = 'points' WHERE reward_type IS NULL AND points_reward > 0 AND (reward IS NULL OR reward = 0);
UPDATE tasks SET reward_type = 'both' WHERE reward_type IS NULL AND reward > 0 AND points_reward > 0;
UPDATE tasks SET reward_type = 'cash' WHERE reward_type IS NULL;  -- 默认值

-- 2.2 处理 reward_type='points' 时 reward 必须为 NULL
UPDATE tasks SET reward = NULL WHERE reward_type = 'points' AND reward = 0;

-- 2.3 补齐 points_reward
UPDATE tasks SET points_reward = 0 WHERE points_reward IS NULL AND reward_type = 'cash';

-- 2.4 补齐 max_participants 和 min_participants
UPDATE tasks SET max_participants = 1 WHERE max_participants IS NULL OR max_participants < 1;
UPDATE tasks SET min_participants = 1 WHERE min_participants IS NULL OR min_participants < 1;
UPDATE tasks SET min_participants = max_participants WHERE min_participants > max_participants;

-- ===========================================
-- 步骤3：添加 CHECK 约束（幂等性处理）
-- ===========================================

-- 使用 DO 块确保约束不存在时才添加
DO $$
BEGIN
    -- 添加参与者范围约束
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'chk_tasks_participants_range' 
        AND conrelid = 'tasks'::regclass
    ) THEN
        ALTER TABLE tasks ADD CONSTRAINT chk_tasks_participants_range CHECK (
            max_participants >= min_participants AND min_participants >= 1
        );
    END IF;
    
    -- 添加奖励非负约束
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'chk_tasks_reward_non_negative' 
        AND conrelid = 'tasks'::regclass
    ) THEN
        ALTER TABLE tasks ADD CONSTRAINT chk_tasks_reward_non_negative CHECK (
            (reward IS NULL OR reward >= 0) AND (points_reward IS NULL OR points_reward >= 0)
        );
    END IF;
    
    -- 添加奖励类型一致性约束
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'chk_tasks_reward_type_consistency' 
        AND conrelid = 'tasks'::regclass
    ) THEN
        ALTER TABLE tasks ADD CONSTRAINT chk_tasks_reward_type_consistency CHECK (
            (reward_type = 'cash' AND reward > 0 AND (points_reward IS NULL OR points_reward = 0)) OR
            (reward_type = 'points' AND points_reward > 0 AND reward IS NULL) OR
            (reward_type = 'both' AND reward > 0 AND points_reward > 0)
        );
    END IF;
    
    -- 添加任务达人服务约束
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'chk_expert_task_service' 
        AND conrelid = 'tasks'::regclass
    ) THEN
        ALTER TABLE tasks ADD CONSTRAINT chk_expert_task_service CHECK (
            NOT created_by_expert OR expert_service_id IS NOT NULL
        );
    END IF;
    
    -- 添加任务达人现金任务taker_id约束
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'chk_expert_cash_taker' 
        AND conrelid = 'tasks'::regclass
    ) THEN
        ALTER TABLE tasks ADD CONSTRAINT chk_expert_cash_taker CHECK (
            NOT (created_by_expert AND reward_type='cash') OR taker_id = expert_creator_id
        );
    END IF;
    
    -- 添加任务身份互斥约束
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'chk_task_identity' 
        AND conrelid = 'tasks'::regclass
    ) THEN
        ALTER TABLE tasks ADD CONSTRAINT chk_task_identity CHECK (
            NOT (is_official_task AND created_by_expert)
        );
    END IF;
END $$;

-- ===========================================
-- 步骤4：创建 task_participants 表
-- ===========================================

CREATE TABLE IF NOT EXISTS task_participants (
    id BIGSERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending',
    previous_status VARCHAR(20),
    time_slot_id INTEGER,
    preferred_deadline TIMESTAMPTZ,
    is_flexible_time BOOLEAN DEFAULT false,
    -- 性能优化字段（冗余字段）
    is_expert_task BOOLEAN DEFAULT false,
    is_official_task BOOLEAN DEFAULT false,
    expert_creator_id VARCHAR(8),
    planned_reward_amount DECIMAL(12, 2),
    planned_points_reward BIGINT DEFAULT 0,
    applied_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    exit_requested_at TIMESTAMPTZ,
    exit_reason TEXT,
    exited_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    completion_notes TEXT,
    admin_notes TEXT,
    idempotency_key VARCHAR(64),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_task_participant UNIQUE(task_id, user_id),
    CONSTRAINT chk_participant_status CHECK (
        status IN ('pending', 'accepted', 'in_progress', 'completed', 'exit_requested', 'exited', 'cancelled')
    )
);

-- ===========================================
-- 步骤5：创建 task_participant_rewards 表
-- ===========================================

CREATE TABLE IF NOT EXISTS task_participant_rewards (
    id BIGSERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    participant_id BIGINT NOT NULL REFERENCES task_participants(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reward_type VARCHAR(20) DEFAULT 'cash',
    reward_amount DECIMAL(12, 2),
    points_amount BIGINT,
    payment_status VARCHAR(20) DEFAULT 'pending',
    points_status VARCHAR(20) DEFAULT 'pending',
    payment_method VARCHAR(50),
    payment_reference VARCHAR(100),
    idempotency_key VARCHAR(64),
    external_txn_id VARCHAR(100),
    reversal_reference VARCHAR(100),
    admin_operator_id VARCHAR(36),
    expert_operator_id VARCHAR(8),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_reward_external_txn UNIQUE(external_txn_id),
    CONSTRAINT chk_reward_payment_status CHECK (
        payment_status IN ('pending', 'paid', 'failed', 'refunded')
    ),
    CONSTRAINT chk_reward_points_status CHECK (
        points_status IN ('pending', 'credited', 'failed', 'refunded')
    ),
    CONSTRAINT chk_reward_type_values CHECK (
        reward_type IN ('cash', 'points', 'both')
    ),
    CONSTRAINT chk_reward_type_amount CHECK (
        (reward_type = 'cash' AND reward_amount IS NOT NULL AND points_amount IS NULL) OR
        (reward_type = 'points' AND reward_amount IS NULL AND points_amount IS NOT NULL) OR
        (reward_type = 'both' AND reward_amount IS NOT NULL AND points_amount IS NOT NULL)
    ),
    CONSTRAINT chk_reward_positive_amount CHECK (
        (reward_amount IS NULL OR reward_amount > 0) AND
        (points_amount IS NULL OR points_amount > 0)
    )
);

-- 添加外键约束（幂等性处理）
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'admin_users') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conname = 'fk_reward_admin_operator' 
            AND conrelid = 'task_participant_rewards'::regclass
        ) THEN
            ALTER TABLE task_participant_rewards ADD CONSTRAINT fk_reward_admin_operator 
                FOREIGN KEY (admin_operator_id) REFERENCES admin_users(id) ON DELETE SET NULL;
        END IF;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conname = 'fk_reward_expert_operator' 
            AND conrelid = 'task_participant_rewards'::regclass
        ) THEN
            ALTER TABLE task_participant_rewards ADD CONSTRAINT fk_reward_expert_operator 
                FOREIGN KEY (expert_operator_id) REFERENCES users(id) ON DELETE SET NULL;
        END IF;
    END IF;
END $$;

-- ===========================================
-- 步骤6：创建 task_audit_logs 表
-- ===========================================

CREATE TABLE IF NOT EXISTS task_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    participant_id BIGINT REFERENCES task_participants(id) ON DELETE CASCADE,
    action_type VARCHAR(50) NOT NULL,
    action_description TEXT,
    admin_id VARCHAR(36),
    user_id VARCHAR(8),
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_audit_user_or_admin CHECK (
        (user_id IS NOT NULL) OR (admin_id IS NOT NULL)
    )
);

-- 添加外键约束（幂等性处理）
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'admin_users') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conname = 'fk_audit_admin' 
            AND conrelid = 'task_audit_logs'::regclass
        ) THEN
            ALTER TABLE task_audit_logs ADD CONSTRAINT fk_audit_admin 
                FOREIGN KEY (admin_id) REFERENCES admin_users(id) ON DELETE SET NULL;
        END IF;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint 
            WHERE conname = 'fk_audit_user' 
            AND conrelid = 'task_audit_logs'::regclass
        ) THEN
            ALTER TABLE task_audit_logs ADD CONSTRAINT fk_audit_user 
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;
        END IF;
    END IF;
END $$;

-- ===========================================
-- 步骤7：创建索引
-- ===========================================

-- task_participants 表索引
CREATE INDEX IF NOT EXISTS idx_task_participants_user ON task_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_task_participants_status ON task_participants(status);
CREATE INDEX IF NOT EXISTS idx_task_participants_task_status_updated ON task_participants(task_id, status, updated_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_per_time_slot ON task_participants(task_id, user_id, time_slot_id) WHERE time_slot_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_task_participants_time_slot ON task_participants(task_id, time_slot_id, status) WHERE time_slot_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_participant_idempotency ON task_participants(task_id, user_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_task_participants_expert_task ON task_participants(is_expert_task, task_id, status) WHERE is_expert_task = true;
CREATE INDEX IF NOT EXISTS idx_task_participants_official_task ON task_participants(is_official_task, task_id, status) WHERE is_official_task = true;
CREATE INDEX IF NOT EXISTS idx_task_participants_expert_creator ON task_participants(expert_creator_id, status, updated_at) WHERE expert_creator_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_task_participants_user_expert ON task_participants(user_id, is_expert_task, status) WHERE is_expert_task = true;
CREATE INDEX IF NOT EXISTS idx_task_participants_user_official ON task_participants(user_id, is_official_task, status) WHERE is_official_task = true;

-- task_participant_rewards 表索引
CREATE INDEX IF NOT EXISTS idx_participant_rewards_task ON task_participant_rewards(task_id);
CREATE INDEX IF NOT EXISTS idx_participant_rewards_participant ON task_participant_rewards(participant_id);
CREATE INDEX IF NOT EXISTS idx_participant_rewards_user ON task_participant_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_participant_rewards_payment_status ON task_participant_rewards(payment_status);
CREATE INDEX IF NOT EXISTS idx_participant_rewards_points_status ON task_participant_rewards(points_status);
CREATE INDEX IF NOT EXISTS idx_participant_rewards_task_status ON task_participant_rewards(task_id, payment_status, points_status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_reward_idempotency ON task_participant_rewards(task_id, participant_id, idempotency_key) WHERE idempotency_key IS NOT NULL;

-- task_audit_logs 表索引
CREATE INDEX IF NOT EXISTS idx_audit_logs_task ON task_audit_logs(task_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_participant ON task_audit_logs(participant_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON task_audit_logs(created_at DESC);

-- tasks 表索引
CREATE INDEX IF NOT EXISTS idx_tasks_multi_official ON tasks(is_multi_participant, is_official_task, status);
CREATE INDEX IF NOT EXISTS idx_tasks_status_deadline ON tasks(status, deadline);
CREATE INDEX IF NOT EXISTS idx_tasks_admin_creator ON tasks(created_by_admin, admin_creator_id);
CREATE INDEX IF NOT EXISTS idx_tasks_reward_type ON tasks(reward_type, status);
CREATE INDEX IF NOT EXISTS idx_tasks_official_status_deadline ON tasks(is_official_task, status, deadline DESC) WHERE is_official_task = true;

-- ===========================================
-- 步骤8：创建触发器函数
-- ===========================================

-- updated_at 自动更新触发器函数
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- current_participants 增量更新触发器函数
CREATE OR REPLACE FUNCTION update_task_participants_count() RETURNS trigger AS $$
DECLARE
  old_is_occupying BOOLEAN;
  new_is_occupying BOOLEAN;
BEGIN
  -- 定义占坑状态
  old_is_occupying := (OLD.status IN ('pending', 'accepted', 'in_progress', 'exit_requested'));
  new_is_occupying := (NEW.status IN ('pending', 'accepted', 'in_progress', 'exit_requested'));
  
  IF TG_OP = 'INSERT' THEN
    -- 新插入：如果状态是占坑状态，+1
    IF new_is_occupying THEN
      UPDATE tasks 
      SET current_participants = COALESCE(current_participants, 0) + 1
      WHERE id = NEW.task_id;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    -- 状态变更：判断是否从占坑→非占坑或非占坑→占坑
    IF OLD.status != NEW.status THEN
      IF old_is_occupying AND NOT new_is_occupying THEN
        -- 从占坑状态变为非占坑状态：-1
        UPDATE tasks 
        SET current_participants = GREATEST(COALESCE(current_participants, 0) - 1, 0)
        WHERE id = NEW.task_id;
      ELSIF NOT old_is_occupying AND new_is_occupying THEN
        -- 从非占坑状态变为占坑状态：+1
        UPDATE tasks 
        SET current_participants = COALESCE(current_participants, 0) + 1
        WHERE id = NEW.task_id;
      END IF;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    -- 删除：如果删除的是占坑状态，-1
    IF old_is_occupying THEN
      UPDATE tasks 
      SET current_participants = GREATEST(COALESCE(current_participants, 0) - 1, 0)
      WHERE id = OLD.task_id;
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 奖励类型一致性验证触发器函数
CREATE OR REPLACE FUNCTION validate_reward_type_consistency() RETURNS trigger AS $$
DECLARE
    task_reward_type VARCHAR(20);
BEGIN
    SELECT reward_type INTO task_reward_type FROM tasks WHERE id = NEW.task_id;
    IF task_reward_type IS NULL THEN
        RAISE EXCEPTION 'Task not found: %', NEW.task_id;
    END IF;
    -- 验证奖励类型一致性
    IF task_reward_type = 'points' AND NEW.reward_type != 'points' THEN
        RAISE EXCEPTION 'Reward type mismatch: task is points-only but reward type is %', NEW.reward_type;
    END IF;
    IF task_reward_type = 'cash' AND NEW.reward_type != 'cash' THEN
        RAISE EXCEPTION 'Reward type mismatch: task is cash-only but reward type is %', NEW.reward_type;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- 步骤9：创建触发器
-- ===========================================

-- tasks 表 updated_at 触发器
DROP TRIGGER IF EXISTS trg_tasks_updated_at ON tasks;
CREATE TRIGGER trg_tasks_updated_at
BEFORE UPDATE ON tasks
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- task_participants 表触发器
DROP TRIGGER IF EXISTS trg_task_participants_updated_at ON task_participants;
CREATE TRIGGER trg_task_participants_updated_at
BEFORE UPDATE ON task_participants
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_update_task_participants_count ON task_participants;
CREATE TRIGGER trg_update_task_participants_count
AFTER INSERT OR UPDATE OR DELETE ON task_participants
FOR EACH ROW EXECUTE FUNCTION update_task_participants_count();

-- task_participant_rewards 表触发器
DROP TRIGGER IF EXISTS trg_task_participant_rewards_updated_at ON task_participant_rewards;
CREATE TRIGGER trg_task_participant_rewards_updated_at
BEFORE UPDATE ON task_participant_rewards
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_validate_reward_type_consistency ON task_participant_rewards;
CREATE TRIGGER trg_validate_reward_type_consistency
BEFORE INSERT OR UPDATE ON task_participant_rewards
FOR EACH ROW EXECUTE FUNCTION validate_reward_type_consistency();

-- ===========================================
-- 步骤10：回填 current_participants（如果有历史数据）
-- ===========================================

-- 注意：此步骤在 task_participants 表创建后执行
-- 如果表为空，此步骤不会影响任何数据

UPDATE tasks t
SET current_participants = (
  SELECT COUNT(*) FROM task_participants tp
  WHERE tp.task_id = t.id
  AND tp.status IN ('pending', 'accepted', 'in_progress', 'exit_requested')
)
WHERE EXISTS (
  SELECT 1 FROM task_participants tp
  WHERE tp.task_id = t.id
  AND tp.status IN ('pending', 'accepted', 'in_progress', 'exit_requested')
);

-- ===========================================
-- 迁移完成
-- ===========================================

