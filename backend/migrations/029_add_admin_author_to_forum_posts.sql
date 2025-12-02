-- 为论坛帖子添加管理员作者支持
-- 创建时间: 2025-01-27
-- 说明: 添加 admin_author_id 字段，允许管理员直接发帖，不依赖普通用户账户

DO $$
BEGIN
    -- 1. 将 author_id 改为可空（支持管理员发帖时 author_id 为空）
    -- 注意：如果表中已有数据，需要确保数据完整性
    -- 先检查是否已经是可空的
    IF EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'forum_posts' 
        AND column_name = 'author_id' 
        AND is_nullable = 'NO'
    ) THEN
        -- 修改 author_id 为可空
        ALTER TABLE forum_posts 
        ALTER COLUMN author_id DROP NOT NULL;
        
        RAISE NOTICE '已将 author_id 改为可空';
    ELSE
        RAISE NOTICE 'author_id 已经是可空的，跳过';
    END IF;

    -- 2. 添加 admin_author_id 字段
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'forum_posts' 
        AND column_name = 'admin_author_id'
    ) THEN
        ALTER TABLE forum_posts 
        ADD COLUMN admin_author_id VARCHAR(5);
        
        RAISE NOTICE '已添加 admin_author_id 字段';
    ELSE
        RAISE NOTICE 'admin_author_id 字段已存在，跳过';
    END IF;

    -- 3. 添加外键约束（如果不存在）
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'forum_posts_admin_author_id_fkey'
    ) THEN
        ALTER TABLE forum_posts 
        ADD CONSTRAINT forum_posts_admin_author_id_fkey 
        FOREIGN KEY (admin_author_id) REFERENCES admin_users(id) ON DELETE SET NULL;
        
        RAISE NOTICE '已添加 admin_author_id 外键约束';
    ELSE
        RAISE NOTICE 'admin_author_id 外键约束已存在，跳过';
    END IF;

    -- 4. 添加索引（如果不存在）
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_indexes 
        WHERE tablename = 'forum_posts' 
        AND indexname = 'idx_forum_posts_admin_author'
    ) THEN
        CREATE INDEX idx_forum_posts_admin_author 
        ON forum_posts(admin_author_id, is_deleted, is_visible);
        
        RAISE NOTICE '已添加 admin_author_id 索引';
    ELSE
        RAISE NOTICE 'admin_author_id 索引已存在，跳过';
    END IF;

    -- 5. 添加 CheckConstraint 确保至少有一个作者（如果不存在）
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_constraint 
        WHERE conname = 'check_forum_post_has_author'
    ) THEN
        ALTER TABLE forum_posts 
        ADD CONSTRAINT check_forum_post_has_author 
        CHECK ((author_id IS NOT NULL) OR (admin_author_id IS NOT NULL));
        
        RAISE NOTICE '已添加 check_forum_post_has_author 约束';
    ELSE
        RAISE NOTICE 'check_forum_post_has_author 约束已存在，跳过';
    END IF;

    -- 6. 添加字段注释
    COMMENT ON COLUMN forum_posts.admin_author_id IS '管理员作者ID，当管理员发帖时使用此字段，author_id 为空';
    COMMENT ON COLUMN forum_posts.author_id IS '普通用户作者ID，可为空（当管理员发帖时）';

END $$;

