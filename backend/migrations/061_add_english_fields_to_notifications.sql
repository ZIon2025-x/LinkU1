-- 迁移文件 061：为 notifications 表添加英文标题和内容字段

DO $$
BEGIN
    -- 1. 添加 title_en 字段
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'title_en') THEN
        ALTER TABLE notifications ADD COLUMN title_en VARCHAR(200);
        COMMENT ON COLUMN notifications.title_en IS '英文标题（可选）';
    END IF;

    -- 2. 添加 content_en 字段
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'notifications' AND column_name = 'content_en') THEN
        ALTER TABLE notifications ADD COLUMN content_en TEXT;
        COMMENT ON COLUMN notifications.content_en IS '英文内容（可选）';
    END IF;

END
$$;
