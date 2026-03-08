CREATE TABLE IF NOT EXISTS official_tasks (
    id SERIAL PRIMARY KEY,
    title_zh VARCHAR(200) NOT NULL,
    title_en VARCHAR(200) NOT NULL,
    description_zh TEXT DEFAULT '',
    description_en TEXT DEFAULT '',
    topic_tag VARCHAR(50),
    task_type VARCHAR(20) NOT NULL DEFAULT 'forum_post',
    reward_type VARCHAR(20) NOT NULL DEFAULT 'points',
    reward_amount INTEGER NOT NULL DEFAULT 0,
    coupon_id INTEGER REFERENCES coupons(id),
    max_per_user INTEGER NOT NULL DEFAULT 1,
    valid_from TIMESTAMP,
    valid_until TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    created_by INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS official_task_submissions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    official_task_id INTEGER NOT NULL REFERENCES official_tasks(id) ON DELETE CASCADE,
    forum_post_id INTEGER,
    status VARCHAR(20) NOT NULL DEFAULT 'submitted',
    submitted_at TIMESTAMP DEFAULT NOW(),
    claimed_at TIMESTAMP,
    reward_amount INTEGER DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_official_task_submissions_user ON official_task_submissions(user_id);
CREATE INDEX IF NOT EXISTS idx_official_task_submissions_task ON official_task_submissions(official_task_id);

ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS official_task_id INTEGER REFERENCES official_tasks(id);
