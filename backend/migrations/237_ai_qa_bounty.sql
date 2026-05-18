-- backend/migrations/237_ai_qa_bounty.sql
-- AI 限时问答 P0 MVP: 5 新表 + ForumPost 字段 + SystemSettings 默认值

BEGIN;

-- ========== 1. ai_qa_cycle_configs (P1 才用,但 P0 建表) ==========
CREATE TABLE ai_qa_cycle_configs (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(80) NOT NULL,
    cadence         VARCHAR(20) NOT NULL,
    next_run_at     TIMESTAMPTZ,
    is_active       BOOLEAN DEFAULT TRUE,
    direction_prompt        TEXT NOT NULL,
    default_reward_pool_pence       INT NOT NULL DEFAULT 1000
        CHECK (default_reward_pool_pence BETWEEN 0 AND 100000),
    default_participation_points    INT NOT NULL DEFAULT 5
        CHECK (default_participation_points BETWEEN 0 AND 1000),
    default_floor_pence             INT NOT NULL DEFAULT 10 CHECK (default_floor_pence BETWEEN 1 AND 1000),
    default_duration_hours          INT NOT NULL DEFAULT 168,
    default_edit_lock_hours_before  INT NOT NULL DEFAULT 1,
    target_forum_category_id        INT NOT NULL REFERENCES forum_categories(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ========== 2. ai_questions (主表) ==========
CREATE TABLE ai_questions (
    id              SERIAL PRIMARY KEY,
    title           VARCHAR(200) NOT NULL,
    content         TEXT NOT NULL,
    topic_tag       VARCHAR(50),
    posed_by_expert_id  VARCHAR(8) NOT NULL REFERENCES experts(id),
    status          VARCHAR(20) NOT NULL DEFAULT 'draft',
    published_at    TIMESTAMPTZ,
    deadline        TIMESTAMPTZ,
    edit_lock_at    TIMESTAMPTZ,
    canceled_at     TIMESTAMPTZ,
    cancel_reason   TEXT,
    settled_at      TIMESTAMPTZ,
    reward_pool_pence       INT NOT NULL DEFAULT 1000
        CHECK (reward_pool_pence BETWEEN 0 AND 100000),
    participation_points    INT NOT NULL DEFAULT 5
        CHECK (participation_points BETWEEN 0 AND 1000),
    floor_pence             INT NOT NULL DEFAULT 10 CHECK (floor_pence BETWEEN 1 AND 1000),
    ai_prompt_used          TEXT,
    target_forum_category_id INT NOT NULL REFERENCES forum_categories(id),
    cycle_config_id         INT REFERENCES ai_qa_cycle_configs(id),
    created_by_admin_id     VARCHAR(5) NOT NULL REFERENCES admin_users(id),
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_ai_questions_status ON ai_questions(status);
CREATE INDEX idx_ai_questions_deadline ON ai_questions(deadline) WHERE status = 'published';

-- ========== 3. ai_question_candidates (P1 才用,P0 建表) ==========
CREATE TABLE ai_question_candidates (
    id              SERIAL PRIMARY KEY,
    cycle_run_id    VARCHAR(36) NOT NULL,
    cycle_config_id INT NOT NULL REFERENCES ai_qa_cycle_configs(id),
    title           VARCHAR(200) NOT NULL,
    content         TEXT NOT NULL,
    topic_tag       VARCHAR(50),
    ai_model_used   VARCHAR(80),
    chosen          BOOLEAN DEFAULT FALSE,
    expired_at      TIMESTAMPTZ,
    snapshot_reward_pool_pence       INT NOT NULL,
    snapshot_floor_pence             INT NOT NULL,
    snapshot_duration_hours          INT NOT NULL,
    snapshot_edit_lock_hours_before  INT NOT NULL,
    snapshot_participation_points    INT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_ai_question_candidates_cycle ON ai_question_candidates(cycle_run_id);
CREATE INDEX idx_ai_question_candidates_cycle_config ON ai_question_candidates(cycle_config_id);

-- ========== 4. ai_answer_scores ("答案+评分"完整记录) ==========
CREATE TABLE ai_answer_scores (
    id              SERIAL PRIMARY KEY,
    ai_question_id  INT NOT NULL REFERENCES ai_questions(id) ON DELETE CASCADE,
    forum_post_id   INT NOT NULL,  -- 不加 FK,允许 ForumPost 删后保留历史
    user_id         VARCHAR(8) NOT NULL,
    risk_score      INT DEFAULT 0,
    risk_reasons    TEXT,
    ai_score        INT,
    off_topic       BOOLEAN DEFAULT FALSE,
    ai_generated    VARCHAR(10),
    ai_raw_response JSONB,
    admin_override_score    INT,
    admin_reviewer_id       VARCHAR(5) REFERENCES admin_users(id),
    admin_reviewed_at       TIMESTAMPTZ,
    hide_in_qa              BOOLEAN DEFAULT FALSE,
    final_score             INT,
    rank_final              INT,
    reward_pence            INT DEFAULT 0,
    reward_points           INT DEFAULT 0,
    settled_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (ai_question_id, forum_post_id),
    UNIQUE (ai_question_id, user_id)
);
CREATE INDEX idx_ai_answer_scores_question ON ai_answer_scores(ai_question_id);
CREATE INDEX idx_ai_answer_scores_user ON ai_answer_scores(user_id);

-- ========== 5. ai_qa_leaderboard (P0 写入,P2 才上前端入口) ==========
CREATE TABLE ai_qa_leaderboard (
    id              SERIAL PRIMARY KEY,
    user_id         VARCHAR(8) NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    total_won_pence INT DEFAULT 0,
    win_count       INT DEFAULT 0,
    answer_count    INT DEFAULT 0,
    last_won_at     TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ========== 6. ForumPost 加 ai_question_id 字段 ==========
ALTER TABLE forum_posts ADD COLUMN ai_question_id INT REFERENCES ai_questions(id);
CREATE INDEX idx_forum_posts_ai_question_id ON forum_posts(ai_question_id)
    WHERE ai_question_id IS NOT NULL;

-- ========== 7. SystemSettings 默认值 ==========
-- 这些是运行时可调的安全/告警参数
INSERT INTO system_settings (setting_key, setting_value, description) VALUES
    ('ai_qa_weekly_settle_cap_pence', '20000',
     'AI 限时问答周度发奖总额上限 (pence)，默认 £200/周'),
    ('ai_qa_settle_alert_threshold_pence', '10000',
     'AI 限时问答周度发奖告警阈值 (pence)，超过发邮件给 admin'),
    ('ai_qa_default_expert_id', '',
     'AI 限时问答 draft 路径默认 posed_by_expert_id (留空则 admin 提交时必填)')
ON CONFLICT (setting_key) DO NOTHING;

COMMIT;
