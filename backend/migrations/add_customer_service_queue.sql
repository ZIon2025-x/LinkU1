-- 客服排队系统表创建迁移脚本
-- 执行时间：2024-12-28

-- 创建客服排队表
CREATE TABLE IF NOT EXISTS customer_service_queue (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(20) NOT NULL,
    status VARCHAR(20) DEFAULT 'waiting',
    queued_at TIMESTAMPTZ DEFAULT NOW(),
    assigned_service_id VARCHAR(20),
    assigned_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    version INTEGER DEFAULT 0
);

-- 添加注释
COMMENT ON TABLE customer_service_queue IS '客服排队系统表';
COMMENT ON COLUMN customer_service_queue.user_id IS '用户ID';
COMMENT ON COLUMN customer_service_queue.status IS '状态: waiting, assigned, cancelled';
COMMENT ON COLUMN customer_service_queue.queued_at IS '排队时间';
COMMENT ON COLUMN customer_service_queue.assigned_service_id IS '分配的客服ID';
COMMENT ON COLUMN customer_service_queue.assigned_at IS '分配时间';
COMMENT ON COLUMN customer_service_queue.cancelled_at IS '取消时间';
COMMENT ON COLUMN customer_service_queue.version IS '版本号，用于乐观锁';

-- 创建索引
CREATE INDEX IF NOT EXISTS ix_customer_service_queue_user_id 
ON customer_service_queue(user_id);

CREATE INDEX IF NOT EXISTS ix_customer_service_queue_status 
ON customer_service_queue(status);

CREATE INDEX IF NOT EXISTS ix_customer_service_queue_queued_at 
ON customer_service_queue(queued_at);

-- 复合索引：用于按状态和排队时间排序查询
CREATE INDEX IF NOT EXISTS ix_customer_service_queue_status_queued_at 
ON customer_service_queue(status, queued_at);

