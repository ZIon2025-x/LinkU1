-- ===========================================
-- 迁移文件030：创建学生认证系统相关表
-- 包括：universities, student_verifications, verification_history
-- ===========================================

DO $body$
BEGIN
    -- 1. 创建大学表 (universities)
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'universities') THEN
        CREATE TABLE universities (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL UNIQUE,
            name_cn VARCHAR(255),
            email_domain VARCHAR(255) NOT NULL UNIQUE,
            domain_pattern VARCHAR(255) NOT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
        );

        -- 添加字段注释
        COMMENT ON COLUMN universities.name IS '大学名称（英文）';
        COMMENT ON COLUMN universities.name_cn IS '大学名称（中文）';
        COMMENT ON COLUMN universities.email_domain IS '邮箱域名（如 bristol.ac.uk）';
        COMMENT ON COLUMN universities.domain_pattern IS '匹配模式（支持通配符）';
        COMMENT ON COLUMN universities.is_active IS '是否启用';

        -- 创建索引（使用表名前缀确保唯一性）
        CREATE INDEX IF NOT EXISTS idx_universities_email_domain ON universities(email_domain);
        CREATE INDEX IF NOT EXISTS idx_universities_is_active ON universities(is_active);
    END IF;

    -- 2. 创建学生认证表 (student_verifications)
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'student_verifications') THEN
        CREATE TABLE student_verifications (
            id SERIAL PRIMARY KEY,
            user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            university_id INTEGER NOT NULL REFERENCES universities(id),
            email VARCHAR(255) NOT NULL,
            status VARCHAR(50) NOT NULL DEFAULT 'pending',
            verification_token VARCHAR(255),
            token_expires_at TIMESTAMPTZ,
            verified_at TIMESTAMPTZ,
            expires_at TIMESTAMPTZ NOT NULL,
            revoked_at TIMESTAMPTZ,
            revoked_reason TEXT,
            revoked_reason_type VARCHAR(50),
            created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
        );

        -- 添加字段注释
        COMMENT ON COLUMN student_verifications.email IS '验证的学生邮箱（统一小写存储）';
        COMMENT ON COLUMN student_verifications.status IS '状态: pending, verified, expired, revoked';
        COMMENT ON COLUMN student_verifications.verification_token IS '验证令牌';
        COMMENT ON COLUMN student_verifications.token_expires_at IS '令牌过期时间';
        COMMENT ON COLUMN student_verifications.verified_at IS '验证通过时间';
        COMMENT ON COLUMN student_verifications.expires_at IS '认证过期时间（每年10月1日）';
        COMMENT ON COLUMN student_verifications.revoked_at IS '撤销时间';
        COMMENT ON COLUMN student_verifications.revoked_reason IS '撤销原因（必填，提升审计能力）';
        COMMENT ON COLUMN student_verifications.revoked_reason_type IS '撤销原因类型（user_request, violation, account_hacked, other）';

        -- 创建索引（使用表名前缀确保唯一性）
        CREATE INDEX IF NOT EXISTS idx_student_verifications_user_id ON student_verifications(user_id);
        CREATE INDEX IF NOT EXISTS idx_student_verifications_university_id ON student_verifications(university_id);
        CREATE INDEX IF NOT EXISTS idx_student_verifications_email ON student_verifications(email);
        CREATE INDEX IF NOT EXISTS idx_student_verifications_status ON student_verifications(status);
        CREATE INDEX IF NOT EXISTS idx_student_verifications_expires_at ON student_verifications(expires_at);
        CREATE INDEX IF NOT EXISTS idx_student_verifications_token ON student_verifications(verification_token);
        CREATE INDEX IF NOT EXISTS idx_student_verifications_user_status ON student_verifications(user_id, status);
        CREATE INDEX IF NOT EXISTS idx_student_verifications_expires_status ON student_verifications(expires_at, status);

        -- 创建唯一索引（验证令牌）
        CREATE UNIQUE INDEX IF NOT EXISTS idx_student_verifications_token_unique 
        ON student_verifications(verification_token) 
        WHERE verification_token IS NOT NULL;

        -- 部分唯一索引：同一用户只能有一个活跃的认证（pending或verified状态）
        CREATE UNIQUE INDEX IF NOT EXISTS idx_student_verifications_unique_user_active 
        ON student_verifications(user_id) 
        WHERE status IN ('verified', 'pending');
    END IF;

    -- 3. 创建验证历史表 (verification_history)
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'verification_history') THEN
        CREATE TABLE verification_history (
            id SERIAL PRIMARY KEY,
            verification_id INTEGER NOT NULL REFERENCES student_verifications(id) ON DELETE CASCADE,
            user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            university_id INTEGER NOT NULL REFERENCES universities(id),
            email VARCHAR(255) NOT NULL,
            action VARCHAR(50) NOT NULL,
            previous_status VARCHAR(50),
            new_status VARCHAR(50),
            ip_address VARCHAR(45),
            user_agent TEXT,
            created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
        );

        -- 添加字段注释
        COMMENT ON COLUMN verification_history.action IS '操作: verified, expired, revoked, renewed';

        -- 创建索引（使用表名前缀确保唯一性）
        CREATE INDEX IF NOT EXISTS idx_verification_history_user_id ON verification_history(user_id);
        CREATE INDEX IF NOT EXISTS idx_verification_history_action ON verification_history(action);
        CREATE INDEX IF NOT EXISTS idx_verification_history_created_at ON verification_history(created_at);
    END IF;

    -- 4. 创建更新时间触发器函数（如果不存在）
    CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS $$
    BEGIN
        NEW.updated_at = CURRENT_TIMESTAMP;
        RETURN NEW;
    END;
    $$ language 'plpgsql';

    -- 为表添加更新时间触发器
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_student_verifications_updated_at') THEN
        CREATE TRIGGER update_student_verifications_updated_at
            BEFORE UPDATE ON student_verifications
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_universities_updated_at') THEN
        CREATE TRIGGER update_universities_updated_at
            BEFORE UPDATE ON universities
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END;
$body$;
