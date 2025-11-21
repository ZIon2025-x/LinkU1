-- ===========================================
-- Link²Ur 数据库完整初始化脚本
-- 用于在 pgAdmin 中执行
-- ===========================================
-- 
-- 使用说明：
-- 1. 在 pgAdmin 中连接到 PostgreSQL 服务器
-- 2. 选择或创建数据库 linku_db
-- 3. 打开 Query Tool (F5)
-- 4. 复制粘贴此脚本并执行
--
-- 注意：此脚本使用 IF NOT EXISTS，可以安全地重复执行
-- ===========================================

-- 设置时区
SET timezone = 'UTC';

-- ===========================================
-- 1. 用户表 (users)
-- ===========================================
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(8) PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(120) UNIQUE,
    hashed_password VARCHAR(128) NOT NULL,
    phone VARCHAR(20) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_active INTEGER DEFAULT 1,
    is_verified INTEGER DEFAULT 0,
    user_level VARCHAR(20) DEFAULT 'normal',
    task_count INTEGER DEFAULT 0,
    completed_task_count INTEGER DEFAULT 0,
    avg_rating FLOAT DEFAULT 0.0,
    avatar VARCHAR(200) DEFAULT '',
    is_suspended INTEGER DEFAULT 0,
    suspend_until TIMESTAMPTZ,
    is_banned INTEGER DEFAULT 0,
    timezone VARCHAR(50) DEFAULT 'UTC',
    residence_city VARCHAR(50),
    language_preference VARCHAR(10) DEFAULT 'en',
    agreed_to_terms INTEGER DEFAULT 0,
    terms_agreed_at TIMESTAMPTZ,
    name_updated_at TIMESTAMPTZ,
    inviter_id VARCHAR(8),
    invitation_code_id BIGINT,
    invitation_code_text VARCHAR(50)
);

-- ===========================================
-- 2. 邀请码表 (invitation_codes) - 需要在 users 之前或之后创建
-- ===========================================
CREATE TABLE IF NOT EXISTS invitation_codes (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100),
    description TEXT,
    reward_type VARCHAR(20) NOT NULL,
    points_reward BIGINT DEFAULT 0,
    coupon_id BIGINT,
    currency VARCHAR(3) DEFAULT 'GBP',
    max_uses INTEGER,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_by VARCHAR(5),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 添加 users 表的外键约束
ALTER TABLE users 
    ADD CONSTRAINT fk_users_inviter FOREIGN KEY (inviter_id) REFERENCES users(id),
    ADD CONSTRAINT fk_users_invitation_code FOREIGN KEY (invitation_code_id) REFERENCES invitation_codes(id);

-- ===========================================
-- 3. 管理员表 (admin_users)
-- ===========================================
CREATE TABLE IF NOT EXISTS admin_users (
    id VARCHAR(5) PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    hashed_password VARCHAR(128) NOT NULL,
    is_active INTEGER DEFAULT 1,
    is_super_admin INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_login TIMESTAMPTZ
);

-- 添加 invitation_codes 的外键
ALTER TABLE invitation_codes 
    ADD CONSTRAINT fk_invitation_codes_created_by FOREIGN KEY (created_by) REFERENCES admin_users(id);

-- ===========================================
-- 4. 任务表 (tasks)
-- ===========================================
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    deadline TIMESTAMPTZ,
    is_flexible INTEGER DEFAULT 0,
    reward FLOAT NOT NULL,
    base_reward DECIMAL(12, 2) NOT NULL,
    agreed_reward DECIMAL(12, 2),
    currency VARCHAR(3) DEFAULT 'GBP',
    location VARCHAR(100) NOT NULL,
    task_type VARCHAR(50) NOT NULL,
    poster_id VARCHAR(8) NOT NULL,
    taker_id VARCHAR(8),
    status VARCHAR(20) DEFAULT 'open',
    task_level VARCHAR(20) DEFAULT 'normal',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    accepted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    is_paid INTEGER DEFAULT 0,
    escrow_amount FLOAT DEFAULT 0.0,
    is_confirmed INTEGER DEFAULT 0,
    paid_to_user_id VARCHAR(8),
    is_public INTEGER DEFAULT 1,
    visibility VARCHAR(20) DEFAULT 'public',
    images TEXT,
    points_reward BIGINT,
    CONSTRAINT fk_tasks_poster FOREIGN KEY (poster_id) REFERENCES users(id),
    CONSTRAINT fk_tasks_taker FOREIGN KEY (taker_id) REFERENCES users(id),
    CONSTRAINT fk_tasks_paid_to FOREIGN KEY (paid_to_user_id) REFERENCES users(id)
);

-- ===========================================
-- 5. 评论表 (reviews)
-- ===========================================
CREATE TABLE IF NOT EXISTS reviews (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL,
    user_id VARCHAR(8) NOT NULL,
    rating FLOAT NOT NULL,
    comment TEXT,
    is_anonymous INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_reviews_task FOREIGN KEY (task_id) REFERENCES tasks(id),
    CONSTRAINT fk_reviews_user FOREIGN KEY (user_id) REFERENCES users(id)
);

-- ===========================================
-- 6. 任务历史表 (task_history)
-- ===========================================
CREATE TABLE IF NOT EXISTS task_history (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL,
    user_id VARCHAR(8),
    action VARCHAR(20) NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    remark TEXT,
    CONSTRAINT fk_task_history_task FOREIGN KEY (task_id) REFERENCES tasks(id),
    CONSTRAINT fk_task_history_user FOREIGN KEY (user_id) REFERENCES users(id)
);

-- ===========================================
-- 7. 消息表 (messages)
-- ===========================================
CREATE TABLE IF NOT EXISTS messages (
    id SERIAL PRIMARY KEY,
    sender_id VARCHAR(8),
    receiver_id VARCHAR(8),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    is_read INTEGER DEFAULT 0,
    image_id VARCHAR(100),
    task_id INTEGER,
    message_type VARCHAR(20) DEFAULT 'normal',
    conversation_type VARCHAR(20) DEFAULT 'task',
    meta TEXT,
    conversation_key VARCHAR(255),
    CONSTRAINT fk_messages_sender FOREIGN KEY (sender_id) REFERENCES users(id),
    CONSTRAINT fk_messages_receiver FOREIGN KEY (receiver_id) REFERENCES users(id),
    CONSTRAINT fk_messages_task FOREIGN KEY (task_id) REFERENCES tasks(id),
    CONSTRAINT ck_messages_task_bind CHECK (conversation_type <> 'task' OR task_id IS NOT NULL),
    CONSTRAINT ck_messages_type CHECK (message_type IN ('normal', 'system')),
    CONSTRAINT ck_messages_conversation_type CHECK (conversation_type IN ('task', 'customer_service', 'global'))
);

-- ===========================================
-- 8. 通知表 (notifications)
-- ===========================================
CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL,
    type VARCHAR(32) NOT NULL,
    related_id INTEGER,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    read_at TIMESTAMPTZ,
    title VARCHAR(200),
    is_read INTEGER DEFAULT 0,
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT uix_user_type_related UNIQUE (user_id, type, related_id)
);

-- ===========================================
-- 9. 客服表 (customer_service)
-- ===========================================
CREATE TABLE IF NOT EXISTS customer_service (
    id VARCHAR(6) PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    hashed_password VARCHAR(128) NOT NULL,
    is_online INTEGER DEFAULT 0,
    avg_rating FLOAT DEFAULT 0.0,
    total_ratings INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================================
-- 10. 任务取消请求表 (task_cancel_requests)
-- ===========================================
CREATE TABLE IF NOT EXISTS task_cancel_requests (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL,
    requester_id VARCHAR(8) NOT NULL,
    reason TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    admin_id VARCHAR(5),
    service_id VARCHAR(6),
    admin_comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ,
    CONSTRAINT fk_cancel_requests_task FOREIGN KEY (task_id) REFERENCES tasks(id),
    CONSTRAINT fk_cancel_requests_user FOREIGN KEY (requester_id) REFERENCES users(id),
    CONSTRAINT fk_cancel_requests_admin FOREIGN KEY (admin_id) REFERENCES admin_users(id),
    CONSTRAINT fk_cancel_requests_service FOREIGN KEY (service_id) REFERENCES customer_service(id)
);

-- ===========================================
-- 11. 系统设置表 (system_settings)
-- ===========================================
CREATE TABLE IF NOT EXISTS system_settings (
    id SERIAL PRIMARY KEY,
    setting_key VARCHAR(50) UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    setting_type VARCHAR(20) DEFAULT 'string',
    description VARCHAR(200),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================================
-- 12. 客服对话表 (customer_service_chats)
-- ===========================================
CREATE TABLE IF NOT EXISTS customer_service_chats (
    id SERIAL PRIMARY KEY,
    chat_id VARCHAR(50) UNIQUE NOT NULL,
    user_id VARCHAR(20) NOT NULL,
    service_id VARCHAR(20) NOT NULL,
    is_ended INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    total_messages INTEGER DEFAULT 0,
    user_rating INTEGER,
    user_comment TEXT,
    rated_at TIMESTAMPTZ,
    ended_reason VARCHAR(32),
    ended_by VARCHAR(32),
    ended_type VARCHAR(32),
    ended_comment TEXT
);

-- ===========================================
-- 13. 客服消息表 (customer_service_messages)
-- ===========================================
CREATE TABLE IF NOT EXISTS customer_service_messages (
    id SERIAL PRIMARY KEY,
    chat_id VARCHAR(50) NOT NULL,
    sender_id VARCHAR(20) NOT NULL,
    sender_type VARCHAR(20) NOT NULL,
    content TEXT NOT NULL,
    is_read INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    image_id VARCHAR(100),
    status VARCHAR(20) DEFAULT 'sending',
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ
);

-- ===========================================
-- 14. 客服排队表 (customer_service_queue)
-- ===========================================
CREATE TABLE IF NOT EXISTS customer_service_queue (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(20) NOT NULL,
    status VARCHAR(20) DEFAULT 'waiting',
    queued_at TIMESTAMPTZ DEFAULT NOW(),
    assigned_service_id VARCHAR(20),
    assigned_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    version INTEGER DEFAULT 0
);

-- ===========================================
-- 15. 待验证用户表 (pending_users)
-- ===========================================
CREATE TABLE IF NOT EXISTS pending_users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    hashed_password VARCHAR(128) NOT NULL,
    phone VARCHAR(20),
    verification_token VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    agreed_to_terms INTEGER DEFAULT 1,
    terms_agreed_at TIMESTAMPTZ,
    inviter_id VARCHAR(8),
    invitation_code_id BIGINT,
    invitation_code_text VARCHAR(50),
    CONSTRAINT fk_pending_users_inviter FOREIGN KEY (inviter_id) REFERENCES users(id),
    CONSTRAINT fk_pending_users_invitation_code FOREIGN KEY (invitation_code_id) REFERENCES invitation_codes(id)
);

-- ===========================================
-- 16. 任务申请表 (task_applications)
-- ===========================================
CREATE TABLE IF NOT EXISTS task_applications (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL,
    applicant_id VARCHAR(8) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    message TEXT,
    negotiated_price DECIMAL(12, 2),
    currency VARCHAR(3) DEFAULT 'GBP',
    CONSTRAINT fk_task_applications_task FOREIGN KEY (task_id) REFERENCES tasks(id),
    CONSTRAINT fk_task_applications_user FOREIGN KEY (applicant_id) REFERENCES users(id),
    CONSTRAINT unique_task_applicant UNIQUE (task_id, applicant_id)
);

-- ===========================================
-- 17. 优惠券表 (coupons)
-- ===========================================
CREATE TABLE IF NOT EXISTS coupons (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    type VARCHAR(20) NOT NULL,
    discount_value BIGINT,
    min_amount BIGINT DEFAULT 0,
    max_discount BIGINT,
    currency VARCHAR(3) DEFAULT 'GBP',
    total_quantity INTEGER,
    per_user_limit INTEGER DEFAULT 1,
    per_device_limit INTEGER,
    per_ip_limit INTEGER,
    can_combine BOOLEAN DEFAULT FALSE,
    combine_limit INTEGER DEFAULT 1,
    apply_order INTEGER DEFAULT 0,
    valid_from TIMESTAMPTZ NOT NULL,
    valid_until TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) DEFAULT 'active',
    usage_conditions JSONB,
    eligibility_type VARCHAR(20),
    eligibility_value TEXT,
    per_day_limit INTEGER,
    vat_category VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_coupon_dates CHECK (valid_until > valid_from),
    CONSTRAINT chk_coupon_discount CHECK (
        (type = 'fixed_amount' AND discount_value > 0) OR 
        (type = 'percentage' AND discount_value BETWEEN 1 AND 10000)
    )
);

-- ===========================================
-- 18. 用户优惠券表 (user_coupons)
-- ===========================================
CREATE TABLE IF NOT EXISTS user_coupons (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL,
    coupon_id BIGINT NOT NULL,
    promotion_code_id BIGINT,
    status VARCHAR(20) DEFAULT 'unused',
    obtained_at TIMESTAMPTZ DEFAULT NOW(),
    used_at TIMESTAMPTZ,
    used_in_task_id BIGINT,
    device_fingerprint VARCHAR(64),
    ip_address INET,
    idempotency_key VARCHAR(64) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_user_coupons_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_coupons_coupon FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_coupons_task FOREIGN KEY (used_in_task_id) REFERENCES tasks(id)
);

-- ===========================================
-- 19. 积分账户表 (points_accounts)
-- ===========================================
CREATE TABLE IF NOT EXISTS points_accounts (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) UNIQUE NOT NULL,
    balance BIGINT DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'GBP',
    total_earned BIGINT DEFAULT 0,
    total_spent BIGINT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_points_accounts_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- ===========================================
-- 20. 积分交易记录表 (points_transactions)
-- ===========================================
CREATE TABLE IF NOT EXISTS points_transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL,
    type VARCHAR(20) NOT NULL,
    amount BIGINT NOT NULL,
    balance_after BIGINT NOT NULL,
    currency VARCHAR(3) DEFAULT 'GBP',
    source VARCHAR(50),
    related_id BIGINT,
    related_type VARCHAR(50),
    batch_id VARCHAR(50),
    expires_at TIMESTAMPTZ,
    description TEXT,
    idempotency_key VARCHAR(64) UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT fk_points_transactions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_points_amount_sign CHECK (
        (type = 'earn' AND amount > 0) OR 
        (type = 'spend' AND amount < 0) OR 
        (type = 'refund' AND amount > 0) OR 
        (type = 'expire' AND amount < 0)
    )
);

-- ===========================================
-- 21. 消息已读表 (message_reads)
-- ===========================================
CREATE TABLE IF NOT EXISTS message_reads (
    id SERIAL PRIMARY KEY,
    message_id INTEGER NOT NULL,
    user_id VARCHAR(8) NOT NULL,
    read_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT fk_message_reads_message FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    CONSTRAINT fk_message_reads_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT uq_message_reads_message_user UNIQUE (message_id, user_id)
);

-- ===========================================
-- 22. 消息已读游标表 (message_read_cursors)
-- ===========================================
CREATE TABLE IF NOT EXISTS message_read_cursors (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL,
    user_id VARCHAR(8) NOT NULL,
    last_read_message_id INTEGER NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT fk_message_read_cursors_task FOREIGN KEY (task_id) REFERENCES tasks(id),
    CONSTRAINT fk_message_read_cursors_user FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT fk_message_read_cursors_message FOREIGN KEY (last_read_message_id) REFERENCES messages(id),
    CONSTRAINT uq_message_read_cursors_task_user UNIQUE (task_id, user_id)
);

-- ===========================================
-- 创建索引
-- ===========================================

-- 用户表索引
CREATE INDEX IF NOT EXISTS ix_users_email ON users(email);
CREATE INDEX IF NOT EXISTS ix_users_name ON users(name);
CREATE INDEX IF NOT EXISTS ix_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS ix_users_user_level ON users(user_level);
CREATE INDEX IF NOT EXISTS ix_users_is_verified ON users(is_verified);
CREATE INDEX IF NOT EXISTS ix_users_created_at ON users(created_at);

-- 任务表索引
CREATE INDEX IF NOT EXISTS ix_tasks_poster_id ON tasks(poster_id);
CREATE INDEX IF NOT EXISTS ix_tasks_taker_id ON tasks(taker_id);
CREATE INDEX IF NOT EXISTS ix_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS ix_tasks_task_level ON tasks(task_level);
CREATE INDEX IF NOT EXISTS ix_tasks_task_type ON tasks(task_type);
CREATE INDEX IF NOT EXISTS ix_tasks_location ON tasks(location);
CREATE INDEX IF NOT EXISTS ix_tasks_created_at ON tasks(created_at);
CREATE INDEX IF NOT EXISTS ix_tasks_deadline ON tasks(deadline);
CREATE INDEX IF NOT EXISTS ix_tasks_base_reward ON tasks(base_reward);
CREATE INDEX IF NOT EXISTS ix_tasks_poster_status ON tasks(poster_id, status);
CREATE INDEX IF NOT EXISTS ix_tasks_taker_status ON tasks(taker_id, status);
CREATE INDEX IF NOT EXISTS ix_tasks_type_status ON tasks(task_type, status);
CREATE INDEX IF NOT EXISTS ix_tasks_level_status ON tasks(task_level, status);
CREATE INDEX IF NOT EXISTS ix_tasks_status_deadline ON tasks(status, deadline);
CREATE INDEX IF NOT EXISTS ix_tasks_type_location_status ON tasks(task_type, location, status);
CREATE INDEX IF NOT EXISTS ix_tasks_status_created_at ON tasks(status, created_at);
CREATE INDEX IF NOT EXISTS ix_tasks_poster_created_at ON tasks(poster_id, created_at);

-- 消息表索引
CREATE INDEX IF NOT EXISTS ix_messages_sender_id ON messages(sender_id);
CREATE INDEX IF NOT EXISTS ix_messages_receiver_id ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS ix_messages_created_at ON messages(created_at);
CREATE INDEX IF NOT EXISTS ix_messages_sender_receiver ON messages(sender_id, receiver_id);
CREATE INDEX IF NOT EXISTS ix_messages_task_id ON messages(task_id);
CREATE INDEX IF NOT EXISTS ix_messages_task_type ON messages(task_id, message_type);
CREATE INDEX IF NOT EXISTS ix_messages_task_created ON messages(task_id, created_at, id);
CREATE INDEX IF NOT EXISTS ix_messages_conversation_type ON messages(conversation_type, task_id);
CREATE INDEX IF NOT EXISTS ix_messages_task_id_id ON messages(task_id, id);
CREATE INDEX IF NOT EXISTS ix_messages_conversation_key ON messages(conversation_key);

-- 评论表索引
CREATE INDEX IF NOT EXISTS ix_reviews_user_id ON reviews(user_id);
CREATE INDEX IF NOT EXISTS ix_reviews_task_id ON reviews(task_id);
CREATE INDEX IF NOT EXISTS ix_reviews_created_at ON reviews(created_at);

-- 通知表索引
CREATE INDEX IF NOT EXISTS ix_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS ix_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS ix_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS ix_notifications_created_at ON notifications(created_at);
CREATE INDEX IF NOT EXISTS ix_notifications_user ON notifications(user_id, created_at);
CREATE INDEX IF NOT EXISTS ix_notifications_type_related ON notifications(type, related_id);
CREATE INDEX IF NOT EXISTS ix_notifications_user_read ON notifications(user_id, is_read);

-- 任务申请索引
CREATE INDEX IF NOT EXISTS ix_task_applications_task_id ON task_applications(task_id);
CREATE INDEX IF NOT EXISTS ix_task_applications_applicant_id ON task_applications(applicant_id);
CREATE INDEX IF NOT EXISTS ix_task_applications_status ON task_applications(status);

-- 优惠券相关索引
CREATE INDEX IF NOT EXISTS ix_coupons_code ON coupons(code);
CREATE INDEX IF NOT EXISTS ix_coupons_status ON coupons(status);
CREATE INDEX IF NOT EXISTS ix_coupons_valid ON coupons(valid_from, valid_until);
CREATE INDEX IF NOT EXISTS ix_coupons_combine ON coupons(can_combine, apply_order);

CREATE INDEX IF NOT EXISTS ix_user_coupons_user ON user_coupons(user_id);
CREATE INDEX IF NOT EXISTS ix_user_coupons_status ON user_coupons(status);
CREATE INDEX IF NOT EXISTS ix_user_coupons_coupon ON user_coupons(coupon_id);

CREATE INDEX IF NOT EXISTS ix_points_accounts_user ON points_accounts(user_id);

CREATE INDEX IF NOT EXISTS ix_points_transactions_user ON points_transactions(user_id);
CREATE INDEX IF NOT EXISTS ix_points_transactions_type ON points_transactions(type);
CREATE INDEX IF NOT EXISTS ix_points_transactions_created ON points_transactions(created_at);
CREATE INDEX IF NOT EXISTS ix_points_transactions_related ON points_transactions(related_type, related_id);

-- 邀请码索引
CREATE INDEX IF NOT EXISTS ix_invitation_codes_code ON invitation_codes(code);
CREATE INDEX IF NOT EXISTS ix_invitation_codes_active ON invitation_codes(is_active);
CREATE INDEX IF NOT EXISTS ix_invitation_codes_valid ON invitation_codes(valid_from, valid_until);
CREATE INDEX IF NOT EXISTS ix_invitation_codes_created_by ON invitation_codes(created_by);

-- 待验证用户索引
CREATE INDEX IF NOT EXISTS ix_pending_users_email ON pending_users(email);
CREATE INDEX IF NOT EXISTS ix_pending_users_token ON pending_users(verification_token);
CREATE INDEX IF NOT EXISTS ix_pending_users_expires ON pending_users(expires_at);

-- 客服相关索引
CREATE INDEX IF NOT EXISTS ix_customer_service_chats_user_id ON customer_service_chats(user_id);
CREATE INDEX IF NOT EXISTS ix_customer_service_chats_service_id ON customer_service_chats(service_id);
CREATE INDEX IF NOT EXISTS ix_customer_service_chats_is_ended ON customer_service_chats(is_ended);
CREATE INDEX IF NOT EXISTS ix_customer_service_chats_created_at ON customer_service_chats(created_at);
CREATE INDEX IF NOT EXISTS ix_customer_service_chats_last_message_at ON customer_service_chats(last_message_at);

CREATE INDEX IF NOT EXISTS ix_customer_service_messages_chat_id ON customer_service_messages(chat_id);
CREATE INDEX IF NOT EXISTS ix_customer_service_messages_sender_id ON customer_service_messages(sender_id);
CREATE INDEX IF NOT EXISTS ix_customer_service_messages_created_at ON customer_service_messages(created_at);
CREATE INDEX IF NOT EXISTS ix_customer_service_messages_status ON customer_service_messages(status);
CREATE INDEX IF NOT EXISTS ix_customer_service_messages_chat_status ON customer_service_messages(chat_id, status);

CREATE INDEX IF NOT EXISTS ix_customer_service_queue_user_id ON customer_service_queue(user_id);
CREATE INDEX IF NOT EXISTS ix_customer_service_queue_status ON customer_service_queue(status);
CREATE INDEX IF NOT EXISTS ix_customer_service_queue_queued_at ON customer_service_queue(queued_at);
CREATE INDEX IF NOT EXISTS ix_customer_service_queue_status_queued_at ON customer_service_queue(status, queued_at);

-- 消息已读索引
CREATE INDEX IF NOT EXISTS ix_message_reads_message_id ON message_reads(message_id);
CREATE INDEX IF NOT EXISTS ix_message_reads_user_id ON message_reads(user_id);
CREATE INDEX IF NOT EXISTS ix_message_reads_task_user ON message_reads(message_id, user_id);

CREATE INDEX IF NOT EXISTS ix_message_read_cursors_task_user ON message_read_cursors(task_id, user_id);
CREATE INDEX IF NOT EXISTS ix_message_read_cursors_message ON message_read_cursors(last_read_message_id);

-- ===========================================
-- 完成提示
-- ===========================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '数据库初始化完成！';
    RAISE NOTICE '所有表和索引已创建成功！';
    RAISE NOTICE '可以开始使用数据库了。';
    RAISE NOTICE '========================================';
END $$;

