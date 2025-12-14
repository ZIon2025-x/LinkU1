-- ===========================================
-- 迁移文件036：创建滚动广告表 (banners)
-- 用于 iOS app 的滚动广告功能
-- ===========================================

DO $body$
BEGIN
    -- 创建 banners 表
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'banners') THEN
        CREATE TABLE banners (
            id SERIAL PRIMARY KEY,
            image_url VARCHAR(500) NOT NULL,
            title VARCHAR(200) NOT NULL,
            subtitle VARCHAR(300),
            link_url VARCHAR(500),
            link_type VARCHAR(20) DEFAULT 'internal',
            "order" INTEGER DEFAULT 0,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
        );

        -- 添加字段注释
        COMMENT ON TABLE banners IS '滚动广告表，用于 iOS app 的滚动广告功能';
        COMMENT ON COLUMN banners.image_url IS '广告图片URL';
        COMMENT ON COLUMN banners.title IS '广告标题';
        COMMENT ON COLUMN banners.subtitle IS '副标题';
        COMMENT ON COLUMN banners.link_url IS '跳转链接';
        COMMENT ON COLUMN banners.link_type IS '链接类型：internal（内部链接）或 external（外部链接）';
        COMMENT ON COLUMN banners."order" IS '排序顺序，数字越小越靠前';
        COMMENT ON COLUMN banners.is_active IS '是否启用';

        -- 创建索引
        CREATE INDEX IF NOT EXISTS idx_banners_order ON banners("order");
        CREATE INDEX IF NOT EXISTS idx_banners_is_active ON banners(is_active);
        CREATE INDEX IF NOT EXISTS idx_banners_active_order ON banners(is_active, "order");

        -- 创建 updated_at 自动更新触发器
        CREATE OR REPLACE FUNCTION update_banners_updated_at()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = CURRENT_TIMESTAMP;
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;

        CREATE TRIGGER trigger_update_banners_updated_at
            BEFORE UPDATE ON banners
            FOR EACH ROW
            EXECUTE FUNCTION update_banners_updated_at();

        RAISE NOTICE '✅ banners 表创建成功';
    ELSE
        RAISE NOTICE '⚠️ banners 表已存在，跳过创建';
    END IF;
END;
$body$;

