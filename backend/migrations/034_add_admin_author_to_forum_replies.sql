-- 为论坛回复添加管理员作者支持
-- 创建时间: 2025-12-10
-- 说明: 允许管理员在后台直接回复帖子，新增 admin_author_id，放宽 author_id 为空，并添加必要的约束与索引

DO $$
BEGIN
    -- 1. 将 author_id 改为可空（支持管理员回复时 author_id 为空）
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'forum_replies'
          AND column_name = 'author_id'
          AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE forum_replies
        ALTER COLUMN author_id DROP NOT NULL;
        RAISE NOTICE '已将 forum_replies.author_id 改为可空';
    ELSE
        RAISE NOTICE 'forum_replies.author_id 已可空，跳过';
    END IF;

    -- 2. 添加 admin_author_id 字段
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'forum_replies'
          AND column_name = 'admin_author_id'
    ) THEN
        ALTER TABLE forum_replies
        ADD COLUMN admin_author_id VARCHAR(5);
        RAISE NOTICE '已添加 forum_replies.admin_author_id 字段';
    ELSE
        RAISE NOTICE 'forum_replies.admin_author_id 已存在，跳过';
    END IF;

    -- 3. 添加外键约束（管理员回复关联 admin_users）
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'forum_replies_admin_author_id_fkey'
    ) THEN
        ALTER TABLE forum_replies
        ADD CONSTRAINT forum_replies_admin_author_id_fkey
        FOREIGN KEY (admin_author_id) REFERENCES admin_users(id) ON DELETE CASCADE;
        RAISE NOTICE '已添加 forum_replies_admin_author_id_fkey 外键约束';
    ELSE
        RAISE NOTICE 'forum_replies_admin_author_id_fkey 已存在，跳过';
    END IF;

    -- 4. 添加索引（用于管理员回复筛选）
    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE tablename = 'forum_replies'
          AND indexname = 'idx_forum_replies_admin_author'
    ) THEN
        CREATE INDEX idx_forum_replies_admin_author
        ON forum_replies(admin_author_id, is_deleted, is_visible);
        RAISE NOTICE '已添加 idx_forum_replies_admin_author 索引';
    ELSE
        RAISE NOTICE 'idx_forum_replies_admin_author 已存在，跳过';
    END IF;

    -- 5. 添加 Check 约束：确保至少有普通用户作者或管理员作者
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'check_reply_has_author'
    ) THEN
        ALTER TABLE forum_replies
        ADD CONSTRAINT check_reply_has_author
        CHECK ((author_id IS NOT NULL) OR (admin_author_id IS NOT NULL));
        RAISE NOTICE '已添加 check_reply_has_author 约束';
    ELSE
        RAISE NOTICE 'check_reply_has_author 已存在，跳过';
    END IF;

    -- 6. 字段注释
    COMMENT ON COLUMN forum_replies.admin_author_id IS '管理员作者ID，后台官方回复使用';
    COMMENT ON COLUMN forum_replies.author_id IS '普通用户作者ID，管理员回复可为空';
END $$;


