-- ===========================================
-- 迁移文件076：法律文档库 (隐私政策、用户协议、Cookie 政策)
-- 用于 Web / iOS 统一展示，支持按语言拉取
-- ===========================================

DO $body$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'legal_documents') THEN
        CREATE TABLE legal_documents (
            id SERIAL PRIMARY KEY,
            type VARCHAR(20) NOT NULL,
            lang VARCHAR(10) NOT NULL,
            content_json JSONB NOT NULL DEFAULT '{}',
            version VARCHAR(50),
            effective_at DATE,
            updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
            created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
            CONSTRAINT uq_legal_documents_type_lang UNIQUE (type, lang)
        );
        COMMENT ON TABLE legal_documents IS '法律文档库：隐私政策、用户协议、Cookie 政策等，按 type+lang 存储 JSON 内容';
        CREATE INDEX idx_legal_documents_type_lang ON legal_documents(type, lang);
        RAISE NOTICE '✅ legal_documents 表创建成功';
    END IF;

    -- 插入 6 条占位（空 content_json），运行 scripts/seed_legal_from_locales.py 后会有完整内容
    INSERT INTO legal_documents (type, lang, content_json, version)
    VALUES
        ('privacy', 'zh', '{}', 'v1.0'),
        ('privacy', 'en', '{}', 'v1.0'),
        ('terms', 'zh', '{}', 'v1.0'),
        ('terms', 'en', '{}', 'v1.0'),
        ('cookie', 'zh', '{}', 'v1.0'),
        ('cookie', 'en', '{}', 'v1.0')
    ON CONFLICT (type, lang) DO NOTHING;

    RAISE NOTICE '✅ legal_documents 占位行已就绪（请运行 scripts/seed_legal_from_locales.py 从前端 locale 导入完整内容）';
END;
$body$;
