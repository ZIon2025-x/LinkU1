-- ===========================================
-- 迁移文件031：修复索引名称冲突
-- 问题：两个表都使用了 idx_user_id，导致索引名称冲突
-- 解决：重命名索引，添加表名前缀确保唯一性
-- ===========================================

DO $body$
BEGIN
    -- 重命名 student_verifications 表的索引
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_user_id' AND tablename = 'student_verifications') THEN
        ALTER INDEX idx_user_id RENAME TO idx_student_verifications_user_id;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_university_id' AND tablename = 'student_verifications') THEN
        ALTER INDEX idx_university_id RENAME TO idx_student_verifications_university_id;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_email' AND tablename = 'student_verifications') THEN
        ALTER INDEX idx_email RENAME TO idx_student_verifications_email;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_status' AND tablename = 'student_verifications') THEN
        ALTER INDEX idx_status RENAME TO idx_student_verifications_status;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_expires_at' AND tablename = 'student_verifications') THEN
        ALTER INDEX idx_expires_at RENAME TO idx_student_verifications_expires_at;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_verification_token' AND tablename = 'student_verifications') THEN
        ALTER INDEX idx_verification_token RENAME TO idx_student_verifications_token;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_verification_user_status' AND tablename = 'student_verifications') THEN
        ALTER INDEX idx_verification_user_status RENAME TO idx_student_verifications_user_status;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_verification_expires_status' AND tablename = 'student_verifications') THEN
        ALTER INDEX idx_verification_expires_status RENAME TO idx_student_verifications_expires_status;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_verification_token_unique' AND tablename = 'student_verifications') THEN
        ALTER INDEX idx_verification_token_unique RENAME TO idx_student_verifications_token_unique;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'unique_user_active' AND tablename = 'student_verifications') THEN
        ALTER INDEX unique_user_active RENAME TO idx_student_verifications_unique_user_active;
    END IF;
    
    -- 重命名 verification_history 表的索引
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_user_id' AND tablename = 'verification_history') THEN
        ALTER INDEX idx_user_id RENAME TO idx_verification_history_user_id;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_action' AND tablename = 'verification_history') THEN
        ALTER INDEX idx_action RENAME TO idx_verification_history_action;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_created_at' AND tablename = 'verification_history') THEN
        ALTER INDEX idx_created_at RENAME TO idx_verification_history_created_at;
    END IF;
    
    -- 重命名 universities 表的索引
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_email_domain' AND tablename = 'universities') THEN
        ALTER INDEX idx_email_domain RENAME TO idx_universities_email_domain;
    END IF;
    
    IF EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_is_active' AND tablename = 'universities') THEN
        ALTER INDEX idx_is_active RENAME TO idx_universities_is_active;
    END IF;
END;
$body$;

