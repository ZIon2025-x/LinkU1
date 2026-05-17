-- 236_widen_messages_type_check.sql
-- 扩展 messages.message_type CHECK 白名单,允许新增 text/image/video/file
--
-- 背景:
-- 2026-05-15 任务聊天加视频/PDF 功能时,Critical fix #2
-- (SendMessageRequest 增加 message_type 字段) 让客户端可以传:
--   - 'text'  (ChatSendMessage 默认)
--   - 'image' (图片消息)
--   - 'video' (视频消息,新)
--   - 'file'  (PDF 消息,新)
-- 但 DB CHECK constraint 历史白名单只到:
--   normal, system, price_proposal, negotiation, quote, counter_offer,
--   negotiation_accepted, negotiation_rejected
-- 任何 text/image/video/file 写入会 CHECK VIOLATION → 500。
--
-- 本 migration 拓宽白名单,保留所有现有值 + 加 4 个新值。
--
-- 影响范围:仅 messages 表的 message_type 列。无数据回填(白名单只放宽不收紧)。
-- 安全性:旧客户端仍写 'normal',行为不变;新客户端可写新类型。

ALTER TABLE messages DROP CONSTRAINT IF EXISTS ck_messages_type;

ALTER TABLE messages ADD CONSTRAINT ck_messages_type
    CHECK (message_type IN (
        -- 历史已有
        'normal',
        'system',
        'price_proposal',
        'negotiation',
        'quote',
        'counter_offer',
        'negotiation_accepted',
        'negotiation_rejected',
        -- 2026-05-17 新增:Critical #2 修复后客户端按 messageType 传入
        'text',
        'image',
        'video',
        'file'
    ));
