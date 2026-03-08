CREATE TABLE IF NOT EXISTS admin_reward_logs (
    id SERIAL PRIMARY KEY,
    admin_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reward_type VARCHAR(20) NOT NULL,
    points_amount INTEGER,
    coupon_id INTEGER REFERENCES coupons(id),
    reason TEXT DEFAULT '',
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_admin_reward_logs_user ON admin_reward_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_reward_logs_admin ON admin_reward_logs(admin_id);
