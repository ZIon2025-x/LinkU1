-- 修复 notifications 表两个 type 列长度不足的问题
--
-- 背景：
--   生产 2026-05-13 08:51 出现 StringDataRightTruncationError:
--     value too long for type character varying(20)
--   触发场景：闲鱼商品咨询创建 notification 时 type/related_type 写入
--   'flea_market_consultation'（24 字符），超过列实际长度 20，导致 INSERT 失败、
--   卖家收不到买家咨询通知。
--
--   原因是 schema drift：
--     - related_type 在 migration 060 建为 VARCHAR(20)
--     - models.py 里 type / related_type 都标为 String(32)
--   migration 060 之后没有把 DB 跟上模型，'flea_market_consultation' 这种较长的
--   type 标识符直接越界。
--
-- 修复：两列统一拉到 VARCHAR(32)，与 models.py 对齐。
ALTER TABLE notifications ALTER COLUMN type TYPE VARCHAR(32);
ALTER TABLE notifications ALTER COLUMN related_type TYPE VARCHAR(32);
