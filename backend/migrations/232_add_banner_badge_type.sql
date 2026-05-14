-- banners 表增加 badge_type 列,控制首页瀑布流穿插 banner 的角标显示
--
-- 当前支持的值(后端不严校验,admin UI 用下拉框约束):
--   'promotion'  → 推广(红/橙)
--   'new'        → 新(绿)
--   'hot'        → 热门(火橙)
--   'limited'    → 限时(紫)
--   NULL         → 无角标(默认)
--
-- 长度 16 给"limited"/"promotion"留点余量,也方便未来扩展(例如 "featured")。
ALTER TABLE banners
ADD COLUMN badge_type VARCHAR(16) NULL;

COMMENT ON COLUMN banners.badge_type IS '角标类型: promotion/new/hot/limited/NULL,NULL 表示无角标';
