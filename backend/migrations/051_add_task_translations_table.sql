-- ===========================================
-- 迁移文件051：创建任务翻译表
-- 用于存储任务标题和描述的翻译，供所有用户共享使用
-- ===========================================

DO $body$
BEGIN
    -- 创建任务翻译表
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'task_translations') THEN
        CREATE TABLE task_translations (
            id SERIAL PRIMARY KEY,
            task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
            field_type VARCHAR(20) NOT NULL,  -- 'title' 或 'description'
            original_text TEXT NOT NULL,
            translated_text TEXT NOT NULL,
            source_language VARCHAR(10) NOT NULL DEFAULT 'auto',
            target_language VARCHAR(10) NOT NULL,
            created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
            
            -- 唯一约束：同一任务的同一字段的同一语言翻译只能有一条记录
            CONSTRAINT uq_task_translation UNIQUE (task_id, field_type, target_language)
        );

        -- 创建索引
        CREATE INDEX idx_task_translations_task ON task_translations(task_id);
        CREATE INDEX idx_task_translations_field ON task_translations(field_type);
        CREATE INDEX idx_task_translations_target_lang ON task_translations(target_language);
        CREATE INDEX idx_task_translations_lookup ON task_translations(task_id, field_type, target_language);

        -- 添加字段注释
        COMMENT ON TABLE task_translations IS '任务翻译表 - 存储任务标题和描述的翻译，供所有用户共享使用';
        COMMENT ON COLUMN task_translations.task_id IS '关联的任务ID';
        COMMENT ON COLUMN task_translations.field_type IS '字段类型：title 或 description';
        COMMENT ON COLUMN task_translations.original_text IS '原始文本';
        COMMENT ON COLUMN task_translations.translated_text IS '翻译后的文本';
        COMMENT ON COLUMN task_translations.source_language IS '源语言代码';
        COMMENT ON COLUMN task_translations.target_language IS '目标语言代码';
        
        RAISE NOTICE '任务翻译表创建成功';
    ELSE
        RAISE NOTICE '任务翻译表已存在，跳过创建';
    END IF;
END $body$;
