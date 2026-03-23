CREATE TABLE IF NOT EXISTS user_follows (
    id SERIAL PRIMARY KEY,
    follower_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_user_follow UNIQUE (follower_id, following_id)
);
CREATE INDEX IF NOT EXISTS ix_user_follows_follower ON user_follows(follower_id);
CREATE INDEX IF NOT EXISTS ix_user_follows_following ON user_follows(following_id);
