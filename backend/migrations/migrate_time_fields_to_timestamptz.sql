-- ============================================================
-- 时间字段迁移脚本：将 TIMESTAMP 转换为 TIMESTAMPTZ
-- ============================================================
-- 
-- 迁移策略：
-- 1. 假设所有旧数据是欧洲/伦敦时区（Europe/London）的墙钟时间
-- 2. 将字段类型从 TIMESTAMP 转换为 TIMESTAMPTZ
-- 3. 转换现有数据：将 naive timestamp 解释为伦敦时间，然后转换为 UTC
--
-- ⚠️ 重要提示：
-- - 本脚本假设所有旧数据都是伦敦时区
-- - 如果数据来源不是伦敦时区，请修改转换策略
-- - 每张表独立事务，失败自动回滚
-- - 脚本具有幂等性，可以安全地多次执行
--
-- ============================================================

-- ============================================================
-- 表：users
-- ============================================================
DO $$
BEGIN
    -- 检查字段类型，如果是 TIMESTAMP 则迁移
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        -- 添加新列
        ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        
        -- 转换数据：假设旧数据是伦敦时区，转换为UTC
        UPDATE users 
        SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC'
        WHERE created_at IS NOT NULL;
        
        -- 回填NULL值
        UPDATE users 
        SET created_at_new = COALESCE(created_at_new, NOW())
        WHERE created_at_new IS NULL;
        
        -- 删除旧列，重命名新列
        ALTER TABLE users DROP COLUMN created_at;
        ALTER TABLE users RENAME COLUMN created_at_new TO created_at;
        
        -- 添加NOT NULL约束（如果需要）
        ALTER TABLE users ALTER COLUMN created_at SET NOT NULL;
        
        RAISE NOTICE '✅ users.created_at 迁移完成';
    ELSE
        RAISE NOTICE 'ℹ️ users.created_at 已经是 TIMESTAMPTZ，跳过';
    END IF;
    
    -- 迁移 suspend_until
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'suspend_until' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE users ADD COLUMN IF NOT EXISTS suspend_until_new TIMESTAMPTZ;
        UPDATE users SET suspend_until_new = suspend_until AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE suspend_until IS NOT NULL;
        ALTER TABLE users DROP COLUMN suspend_until;
        ALTER TABLE users RENAME COLUMN suspend_until_new TO suspend_until;
        RAISE NOTICE '✅ users.suspend_until 迁移完成';
    END IF;
    
    -- 迁移 terms_agreed_at
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'terms_agreed_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE users ADD COLUMN IF NOT EXISTS terms_agreed_at_new TIMESTAMPTZ;
        UPDATE users SET terms_agreed_at_new = terms_agreed_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE terms_agreed_at IS NOT NULL;
        ALTER TABLE users DROP COLUMN terms_agreed_at;
        ALTER TABLE users RENAME COLUMN terms_agreed_at_new TO terms_agreed_at;
        RAISE NOTICE '✅ users.terms_agreed_at 迁移完成';
    END IF;
    
    -- 迁移 name_updated_at
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' 
        AND column_name = 'name_updated_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE users ADD COLUMN IF NOT EXISTS name_updated_at_new TIMESTAMPTZ;
        UPDATE users SET name_updated_at_new = name_updated_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE name_updated_at IS NOT NULL;
        ALTER TABLE users DROP COLUMN name_updated_at;
        ALTER TABLE users RENAME COLUMN name_updated_at_new TO name_updated_at;
        RAISE NOTICE '✅ users.name_updated_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：tasks
-- ============================================================
DO $$
BEGIN
    -- 迁移 deadline
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tasks' 
        AND column_name = 'deadline' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE tasks ADD COLUMN IF NOT EXISTS deadline_new TIMESTAMPTZ;
        UPDATE tasks SET deadline_new = deadline AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE deadline IS NOT NULL;
        ALTER TABLE tasks DROP COLUMN deadline;
        ALTER TABLE tasks RENAME COLUMN deadline_new TO deadline;
        RAISE NOTICE '✅ tasks.deadline 迁移完成';
    END IF;
    
    -- 迁移 created_at
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tasks' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE tasks ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE tasks SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE tasks SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE tasks DROP COLUMN created_at;
        ALTER TABLE tasks RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE tasks ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ tasks.created_at 迁移完成';
    END IF;
    
    -- 迁移 accepted_at
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tasks' 
        AND column_name = 'accepted_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE tasks ADD COLUMN IF NOT EXISTS accepted_at_new TIMESTAMPTZ;
        UPDATE tasks SET accepted_at_new = accepted_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE accepted_at IS NOT NULL;
        ALTER TABLE tasks DROP COLUMN accepted_at;
        ALTER TABLE tasks RENAME COLUMN accepted_at_new TO accepted_at;
        RAISE NOTICE '✅ tasks.accepted_at 迁移完成';
    END IF;
    
    -- 迁移 completed_at
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tasks' 
        AND column_name = 'completed_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE tasks ADD COLUMN IF NOT EXISTS completed_at_new TIMESTAMPTZ;
        UPDATE tasks SET completed_at_new = completed_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE completed_at IS NOT NULL;
        ALTER TABLE tasks DROP COLUMN completed_at;
        ALTER TABLE tasks RENAME COLUMN completed_at_new TO completed_at;
        RAISE NOTICE '✅ tasks.completed_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：task_reviews (reviews)
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'task_reviews' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE task_reviews ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE task_reviews SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE task_reviews SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE task_reviews DROP COLUMN created_at;
        ALTER TABLE task_reviews RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE task_reviews ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ task_reviews.created_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：task_history
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'task_history' 
        AND column_name = 'timestamp' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE task_history ADD COLUMN IF NOT EXISTS timestamp_new TIMESTAMPTZ;
        UPDATE task_history SET timestamp_new = timestamp AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE timestamp IS NOT NULL;
        UPDATE task_history SET timestamp_new = COALESCE(timestamp_new, NOW()) WHERE timestamp_new IS NULL;
        ALTER TABLE task_history DROP COLUMN timestamp;
        ALTER TABLE task_history RENAME COLUMN timestamp_new TO timestamp;
        ALTER TABLE task_history ALTER COLUMN timestamp SET NOT NULL;
        RAISE NOTICE '✅ task_history.timestamp 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：messages
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'messages' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE messages ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE messages SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE messages SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE messages DROP COLUMN created_at;
        ALTER TABLE messages RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE messages ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ messages.created_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：notifications
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE notifications ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE notifications SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE notifications SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE notifications DROP COLUMN created_at;
        ALTER TABLE notifications RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE notifications ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ notifications.created_at 迁移完成';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'notifications' 
        AND column_name = 'read_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE notifications ADD COLUMN IF NOT EXISTS read_at_new TIMESTAMPTZ;
        UPDATE notifications SET read_at_new = read_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE read_at IS NOT NULL;
        ALTER TABLE notifications DROP COLUMN read_at;
        ALTER TABLE notifications RENAME COLUMN read_at_new TO read_at;
        RAISE NOTICE '✅ notifications.read_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：task_cancel_requests
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'task_cancel_requests' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE task_cancel_requests ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE task_cancel_requests SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE task_cancel_requests SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE task_cancel_requests DROP COLUMN created_at;
        ALTER TABLE task_cancel_requests RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE task_cancel_requests ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ task_cancel_requests.created_at 迁移完成';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'task_cancel_requests' 
        AND column_name = 'reviewed_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE task_cancel_requests ADD COLUMN IF NOT EXISTS reviewed_at_new TIMESTAMPTZ;
        UPDATE task_cancel_requests SET reviewed_at_new = reviewed_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE reviewed_at IS NOT NULL;
        ALTER TABLE task_cancel_requests DROP COLUMN reviewed_at;
        ALTER TABLE task_cancel_requests RENAME COLUMN reviewed_at_new TO reviewed_at;
        RAISE NOTICE '✅ task_cancel_requests.reviewed_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：customer_service
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE customer_service ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE customer_service SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE customer_service SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE customer_service DROP COLUMN created_at;
        ALTER TABLE customer_service RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE customer_service ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ customer_service.created_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：admin_requests
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'admin_requests' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE admin_requests ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE admin_requests SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE admin_requests SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE admin_requests DROP COLUMN created_at;
        ALTER TABLE admin_requests RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE admin_requests ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ admin_requests.created_at 迁移完成';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'admin_requests' 
        AND column_name = 'updated_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE admin_requests ADD COLUMN IF NOT EXISTS updated_at_new TIMESTAMPTZ;
        UPDATE admin_requests SET updated_at_new = updated_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE updated_at IS NOT NULL;
        ALTER TABLE admin_requests DROP COLUMN updated_at;
        ALTER TABLE admin_requests RENAME COLUMN updated_at_new TO updated_at;
        RAISE NOTICE '✅ admin_requests.updated_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：admin_users
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'admin_users' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE admin_users SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE admin_users SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE admin_users DROP COLUMN created_at;
        ALTER TABLE admin_users RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE admin_users ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ admin_users.created_at 迁移完成';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'admin_users' 
        AND column_name = 'last_login' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE admin_users ADD COLUMN IF NOT EXISTS last_login_new TIMESTAMPTZ;
        UPDATE admin_users SET last_login_new = last_login AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE last_login IS NOT NULL;
        ALTER TABLE admin_users DROP COLUMN last_login;
        ALTER TABLE admin_users RENAME COLUMN last_login_new TO last_login;
        RAISE NOTICE '✅ admin_users.last_login 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：staff_notifications
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'staff_notifications' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE staff_notifications ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE staff_notifications SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE staff_notifications SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE staff_notifications DROP COLUMN created_at;
        ALTER TABLE staff_notifications RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE staff_notifications ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ staff_notifications.created_at 迁移完成';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'staff_notifications' 
        AND column_name = 'read_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE staff_notifications ADD COLUMN IF NOT EXISTS read_at_new TIMESTAMPTZ;
        UPDATE staff_notifications SET read_at_new = read_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE read_at IS NOT NULL;
        ALTER TABLE staff_notifications DROP COLUMN read_at;
        ALTER TABLE staff_notifications RENAME COLUMN read_at_new TO read_at;
        RAISE NOTICE '✅ staff_notifications.read_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：system_settings
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_settings' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE system_settings SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE system_settings SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE system_settings DROP COLUMN created_at;
        ALTER TABLE system_settings RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE system_settings ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ system_settings.created_at 迁移完成';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'system_settings' 
        AND column_name = 'updated_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS updated_at_new TIMESTAMPTZ;
        UPDATE system_settings SET updated_at_new = updated_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE updated_at IS NOT NULL;
        UPDATE system_settings SET updated_at_new = COALESCE(updated_at_new, NOW()) WHERE updated_at_new IS NULL;
        ALTER TABLE system_settings DROP COLUMN updated_at;
        ALTER TABLE system_settings RENAME COLUMN updated_at_new TO updated_at;
        ALTER TABLE system_settings ALTER COLUMN updated_at SET NOT NULL;
        RAISE NOTICE '✅ system_settings.updated_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：customer_service_chats
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service_chats' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE customer_service_chats ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE customer_service_chats SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE customer_service_chats SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE customer_service_chats DROP COLUMN created_at;
        ALTER TABLE customer_service_chats RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE customer_service_chats ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ customer_service_chats.created_at 迁移完成';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service_chats' 
        AND column_name = 'ended_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE customer_service_chats ADD COLUMN IF NOT EXISTS ended_at_new TIMESTAMPTZ;
        UPDATE customer_service_chats SET ended_at_new = ended_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE ended_at IS NOT NULL;
        ALTER TABLE customer_service_chats DROP COLUMN ended_at;
        ALTER TABLE customer_service_chats RENAME COLUMN ended_at_new TO ended_at;
        RAISE NOTICE '✅ customer_service_chats.ended_at 迁移完成';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service_chats' 
        AND column_name = 'last_message_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE customer_service_chats ADD COLUMN IF NOT EXISTS last_message_at_new TIMESTAMPTZ;
        UPDATE customer_service_chats SET last_message_at_new = last_message_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE last_message_at IS NOT NULL;
        UPDATE customer_service_chats SET last_message_at_new = COALESCE(last_message_at_new, NOW()) WHERE last_message_at_new IS NULL;
        ALTER TABLE customer_service_chats DROP COLUMN last_message_at;
        ALTER TABLE customer_service_chats RENAME COLUMN last_message_at_new TO last_message_at;
        ALTER TABLE customer_service_chats ALTER COLUMN last_message_at SET NOT NULL;
        RAISE NOTICE '✅ customer_service_chats.last_message_at 迁移完成';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service_chats' 
        AND column_name = 'rated_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE customer_service_chats ADD COLUMN IF NOT EXISTS rated_at_new TIMESTAMPTZ;
        UPDATE customer_service_chats SET rated_at_new = rated_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE rated_at IS NOT NULL;
        ALTER TABLE customer_service_chats DROP COLUMN rated_at;
        ALTER TABLE customer_service_chats RENAME COLUMN rated_at_new TO rated_at;
        RAISE NOTICE '✅ customer_service_chats.rated_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：customer_service_messages
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'customer_service_messages' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE customer_service_messages ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE customer_service_messages SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE customer_service_messages SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE customer_service_messages DROP COLUMN created_at;
        ALTER TABLE customer_service_messages RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE customer_service_messages ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ customer_service_messages.created_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：pending_users
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pending_users' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE pending_users ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE pending_users SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE pending_users SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE pending_users DROP COLUMN created_at;
        ALTER TABLE pending_users RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE pending_users ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ pending_users.created_at 迁移完成';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pending_users' 
        AND column_name = 'expires_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE pending_users ADD COLUMN IF NOT EXISTS expires_at_new TIMESTAMPTZ;
        UPDATE pending_users SET expires_at_new = expires_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE expires_at IS NOT NULL;
        ALTER TABLE pending_users DROP COLUMN expires_at;
        ALTER TABLE pending_users RENAME COLUMN expires_at_new TO expires_at;
        ALTER TABLE pending_users ALTER COLUMN expires_at SET NOT NULL;
        RAISE NOTICE '✅ pending_users.expires_at 迁移完成';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pending_users' 
        AND column_name = 'terms_agreed_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE pending_users ADD COLUMN IF NOT EXISTS terms_agreed_at_new TIMESTAMPTZ;
        UPDATE pending_users SET terms_agreed_at_new = terms_agreed_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE terms_agreed_at IS NOT NULL;
        ALTER TABLE pending_users DROP COLUMN terms_agreed_at;
        ALTER TABLE pending_users RENAME COLUMN terms_agreed_at_new TO terms_agreed_at;
        RAISE NOTICE '✅ pending_users.terms_agreed_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：task_applications
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'task_applications' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE task_applications ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE task_applications SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE task_applications SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE task_applications DROP COLUMN created_at;
        ALTER TABLE task_applications RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE task_applications ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ task_applications.created_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：job_positions
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'job_positions' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE job_positions ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE job_positions SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE job_positions SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE job_positions DROP COLUMN created_at;
        ALTER TABLE job_positions RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE job_positions ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ job_positions.created_at 迁移完成';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'job_positions' 
        AND column_name = 'updated_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE job_positions ADD COLUMN IF NOT EXISTS updated_at_new TIMESTAMPTZ;
        UPDATE job_positions SET updated_at_new = updated_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE updated_at IS NOT NULL;
        UPDATE job_positions SET updated_at_new = COALESCE(updated_at_new, NOW()) WHERE updated_at_new IS NULL;
        ALTER TABLE job_positions DROP COLUMN updated_at;
        ALTER TABLE job_positions RENAME COLUMN updated_at_new TO updated_at;
        ALTER TABLE job_positions ALTER COLUMN updated_at SET NOT NULL;
        RAISE NOTICE '✅ job_positions.updated_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：featured_task_experts
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'featured_task_experts' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE featured_task_experts ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE featured_task_experts SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE featured_task_experts SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE featured_task_experts DROP COLUMN created_at;
        ALTER TABLE featured_task_experts RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE featured_task_experts ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ featured_task_experts.created_at 迁移完成';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'featured_task_experts' 
        AND column_name = 'updated_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE featured_task_experts ADD COLUMN IF NOT EXISTS updated_at_new TIMESTAMPTZ;
        UPDATE featured_task_experts SET updated_at_new = updated_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE updated_at IS NOT NULL;
        UPDATE featured_task_experts SET updated_at_new = COALESCE(updated_at_new, NOW()) WHERE updated_at_new IS NULL;
        ALTER TABLE featured_task_experts DROP COLUMN updated_at;
        ALTER TABLE featured_task_experts RENAME COLUMN updated_at_new TO updated_at;
        ALTER TABLE featured_task_experts ALTER COLUMN updated_at SET NOT NULL;
        RAISE NOTICE '✅ featured_task_experts.updated_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：user_preferences
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_preferences' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE user_preferences SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE user_preferences SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE user_preferences DROP COLUMN created_at;
        ALTER TABLE user_preferences RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE user_preferences ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ user_preferences.created_at 迁移完成';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_preferences' 
        AND column_name = 'updated_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS updated_at_new TIMESTAMPTZ;
        UPDATE user_preferences SET updated_at_new = updated_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE updated_at IS NOT NULL;
        UPDATE user_preferences SET updated_at_new = COALESCE(updated_at_new, NOW()) WHERE updated_at_new IS NULL;
        ALTER TABLE user_preferences DROP COLUMN updated_at;
        ALTER TABLE user_preferences RENAME COLUMN updated_at_new TO updated_at;
        ALTER TABLE user_preferences ALTER COLUMN updated_at SET NOT NULL;
        RAISE NOTICE '✅ user_preferences.updated_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：message_read
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'message_read' 
        AND column_name = 'read_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE message_read ADD COLUMN IF NOT EXISTS read_at_new TIMESTAMPTZ;
        UPDATE message_read SET read_at_new = read_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE read_at IS NOT NULL;
        UPDATE message_read SET read_at_new = COALESCE(read_at_new, NOW()) WHERE read_at_new IS NULL;
        ALTER TABLE message_read DROP COLUMN read_at;
        ALTER TABLE message_read RENAME COLUMN read_at_new TO read_at;
        ALTER TABLE message_read ALTER COLUMN read_at SET NOT NULL;
        RAISE NOTICE '✅ message_read.read_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：message_attachments
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'message_attachments' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE message_attachments ADD COLUMN IF NOT EXISTS created_at_new TIMESTAMPTZ;
        UPDATE message_attachments SET created_at_new = created_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE created_at IS NOT NULL;
        UPDATE message_attachments SET created_at_new = COALESCE(created_at_new, NOW()) WHERE created_at_new IS NULL;
        ALTER TABLE message_attachments DROP COLUMN created_at;
        ALTER TABLE message_attachments RENAME COLUMN created_at_new TO created_at;
        ALTER TABLE message_attachments ALTER COLUMN created_at SET NOT NULL;
        RAISE NOTICE '✅ message_attachments.created_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：negotiation_response_log
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'negotiation_response_log' 
        AND column_name = 'responded_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE negotiation_response_log ADD COLUMN IF NOT EXISTS responded_at_new TIMESTAMPTZ;
        UPDATE negotiation_response_log SET responded_at_new = responded_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE responded_at IS NOT NULL;
        UPDATE negotiation_response_log SET responded_at_new = COALESCE(responded_at_new, NOW()) WHERE responded_at_new IS NULL;
        ALTER TABLE negotiation_response_log DROP COLUMN responded_at;
        ALTER TABLE negotiation_response_log RENAME COLUMN responded_at_new TO responded_at;
        ALTER TABLE negotiation_response_log ALTER COLUMN responded_at SET NOT NULL;
        RAISE NOTICE '✅ negotiation_response_log.responded_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 表：message_read_cursor
-- ============================================================
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'message_read_cursor' 
        AND column_name = 'updated_at' 
        AND data_type = 'timestamp without time zone'
    ) THEN
        ALTER TABLE message_read_cursor ADD COLUMN IF NOT EXISTS updated_at_new TIMESTAMPTZ;
        UPDATE message_read_cursor SET updated_at_new = updated_at AT TIME ZONE 'Europe/London' AT TIME ZONE 'UTC' WHERE updated_at IS NOT NULL;
        UPDATE message_read_cursor SET updated_at_new = COALESCE(updated_at_new, NOW()) WHERE updated_at_new IS NULL;
        ALTER TABLE message_read_cursor DROP COLUMN updated_at;
        ALTER TABLE message_read_cursor RENAME COLUMN updated_at_new TO updated_at;
        ALTER TABLE message_read_cursor ALTER COLUMN updated_at SET NOT NULL;
        RAISE NOTICE '✅ message_read_cursor.updated_at 迁移完成';
    END IF;
END $$;

-- ============================================================
-- 迁移完成
-- ============================================================
DO $$
BEGIN
    RAISE NOTICE '✅ 所有时间字段迁移完成！';
    RAISE NOTICE '⚠️ 请验证数据正确性，确认时间转换无误';
END $$;

