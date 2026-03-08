CREATE TABLE IF NOT EXISTS skill_categories (
    id SERIAL PRIMARY KEY,
    name_zh VARCHAR(100) NOT NULL,
    name_en VARCHAR(100) NOT NULL,
    icon VARCHAR(200) DEFAULT '',
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS skill_leaderboard (
    id SERIAL PRIMARY KEY,
    skill_category VARCHAR(50) NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    completed_tasks INTEGER DEFAULT 0,
    total_amount INTEGER DEFAULT 0,
    avg_rating FLOAT DEFAULT 0.0,
    score FLOAT DEFAULT 0.0,
    rank INTEGER DEFAULT 0,
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(skill_category, user_id)
);
CREATE INDEX IF NOT EXISTS idx_skill_leaderboard_category_rank ON skill_leaderboard(skill_category, rank);

CREATE TABLE IF NOT EXISTS user_badges (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_type VARCHAR(50) NOT NULL DEFAULT 'skill_rank',
    skill_category VARCHAR(50) NOT NULL,
    rank INTEGER NOT NULL,
    is_displayed BOOLEAN DEFAULT false,
    granted_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, skill_category)
);
CREATE INDEX IF NOT EXISTS idx_user_badges_user_id ON user_badges(user_id);

ALTER TABLE users ADD CONSTRAINT fk_users_displayed_badge
    FOREIGN KEY (displayed_badge_id) REFERENCES user_badges(id) ON DELETE SET NULL;
