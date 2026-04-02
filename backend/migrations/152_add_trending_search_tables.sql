-- 152_add_trending_search_tables.sql
-- Trending search feature: search logs, blacklist, pinned

-- Search logs table
CREATE TABLE IF NOT EXISTS search_logs (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL,
    raw_query VARCHAR(200) NOT NULL,
    tokens JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_search_logs_created_at ON search_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_search_logs_user_id ON search_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_search_logs_raw_query ON search_logs(raw_query);

-- Trending blacklist table
CREATE TABLE IF NOT EXISTS trending_blacklist (
    id SERIAL PRIMARY KEY,
    keyword VARCHAR(100) NOT NULL UNIQUE,
    created_by VARCHAR(5) REFERENCES admin_users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Trending pinned table
CREATE TABLE IF NOT EXISTS trending_pinned (
    id SERIAL PRIMARY KEY,
    keyword VARCHAR(200) NOT NULL,
    display_heat VARCHAR(50) NOT NULL DEFAULT '',
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_by VARCHAR(5) REFERENCES admin_users(id) ON DELETE SET NULL,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trending_pinned_expires_at ON trending_pinned(expires_at);
