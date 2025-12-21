-- 迁移文件37：为任务和跳蚤市场商品添加位置坐标字段
-- 支持地图选点和基于距离的搜索

DO $body$
BEGIN
    -- 1. 为 tasks 表添加坐标字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tasks' AND column_name = 'latitude'
    ) THEN
        ALTER TABLE tasks 
        ADD COLUMN latitude DECIMAL(10, 8),
        ADD COLUMN longitude DECIMAL(11, 8);
        
        -- 添加注释
        COMMENT ON COLUMN tasks.latitude IS '纬度（用于地图选点和距离计算）';
        COMMENT ON COLUMN tasks.longitude IS '经度（用于地图选点和距离计算）';
        
        -- 添加检查约束：确保坐标在有效范围内
        ALTER TABLE tasks 
        ADD CONSTRAINT check_latitude_range 
        CHECK (latitude IS NULL OR (latitude >= -90 AND latitude <= 90));
        
        ALTER TABLE tasks 
        ADD CONSTRAINT check_longitude_range 
        CHECK (longitude IS NULL OR (longitude >= -180 AND longitude <= 180));
        
        -- 添加索引以支持基于距离的查询（使用 GiST 索引支持空间查询）
        CREATE INDEX IF NOT EXISTS idx_tasks_location_coordinates 
        ON tasks USING GIST (point(longitude, latitude)) 
        WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
    END IF;
    
    -- 2. 为 flea_market_items 表添加坐标字段
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'flea_market_items' AND column_name = 'latitude'
    ) THEN
        ALTER TABLE flea_market_items 
        ADD COLUMN latitude DECIMAL(10, 8),
        ADD COLUMN longitude DECIMAL(11, 8);
        
        -- 添加注释
        COMMENT ON COLUMN flea_market_items.latitude IS '纬度（用于地图选点和距离计算）';
        COMMENT ON COLUMN flea_market_items.longitude IS '经度（用于地图选点和距离计算）';
        
        -- 添加检查约束：确保坐标在有效范围内
        ALTER TABLE flea_market_items 
        ADD CONSTRAINT check_flea_market_latitude_range 
        CHECK (latitude IS NULL OR (latitude >= -90 AND latitude <= 90));
        
        ALTER TABLE flea_market_items 
        ADD CONSTRAINT check_flea_market_longitude_range 
        CHECK (longitude IS NULL OR (longitude >= -180 AND longitude <= 180));
        
        -- 添加索引以支持基于距离的查询
        CREATE INDEX IF NOT EXISTS idx_flea_market_items_location_coordinates 
        ON flea_market_items USING GIST (point(longitude, latitude)) 
        WHERE latitude IS NOT NULL AND longitude IS NOT NULL;
    END IF;
    
    -- 3. 启用 PostGIS 扩展（如果可用，用于更高级的空间查询）
    -- 注意：如果数据库没有安装 PostGIS，这部分会失败，但不影响基本功能
    BEGIN
        CREATE EXTENSION IF NOT EXISTS postgis;
    EXCEPTION
        WHEN OTHERS THEN
            -- PostGIS 不可用，使用基本的 point 类型即可
            NULL;
    END;
END;
$body$;

