-- ===========================================
-- 迁移文件052：为任务翻译表添加content_hash字段
-- 用于快速检测翻译是否过期（原始内容是否已更改）
-- ===========================================

DO $body$
BEGIN
    -- 检查content_hash字段是否存在
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'task_translations' 
        AND column_name = 'content_hash'
    ) THEN
        -- 添加content_hash字段
        ALTER TABLE task_translations 
        ADD COLUMN content_hash VARCHAR(64);
        
        -- 为现有数据计算content_hash（使用SHA256）
        -- 注意：这可能需要一些时间，取决于数据量
        UPDATE task_translations 
        SET content_hash = encode(digest(original_text, 'sha256'), 'hex')
        WHERE content_hash IS NULL;
        
        -- 创建索引以提升查询性能
        CREATE INDEX idx_task_translations_content_hash ON task_translations(content_hash);
        
        -- 添加字段注释
        COMMENT ON COLUMN task_translations.content_hash IS '原始文本的SHA256哈希值，用于快速检测翻译是否过期';
        
        RAISE NOTICE 'content_hash字段添加成功';
    ELSE
        RAISE NOTICE 'content_hash字段已存在，跳过添加';
    END IF;
END $body$;
