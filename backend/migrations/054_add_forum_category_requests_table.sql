-- 添加论坛板块申请表
-- 迁移文件：054_add_forum_category_requests_table.sql

-- 创建论坛板块申请表
CREATE TABLE IF NOT EXISTS forum_category_requests (
    id SERIAL PRIMARY KEY,
    requester_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT NULL,
    icon VARCHAR(200) NULL,
    type VARCHAR(20) DEFAULT 'general' NOT NULL,
    country VARCHAR(10) NULL,
    university_code VARCHAR(50) NULL,
    status VARCHAR(20) DEFAULT 'pending' NOT NULL,
    admin_id VARCHAR(5) NULL REFERENCES admin_users(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMP WITH TIME ZONE NULL,
    review_comment TEXT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 添加约束
ALTER TABLE forum_category_requests
    ADD CONSTRAINT check_forum_category_request_status 
    CHECK (status IN ('pending', 'approved', 'rejected'));

ALTER TABLE forum_category_requests
    ADD CONSTRAINT check_forum_category_request_type 
    CHECK (type IN ('general', 'root', 'university'));

-- 添加索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_forum_category_requests_requester ON forum_category_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_forum_category_requests_status ON forum_category_requests(status);
CREATE INDEX IF NOT EXISTS idx_forum_category_requests_created ON forum_category_requests(created_at);
CREATE INDEX IF NOT EXISTS idx_forum_category_requests_admin ON forum_category_requests(admin_id) WHERE admin_id IS NOT NULL;

-- 添加注释
COMMENT ON TABLE forum_category_requests IS '论坛板块申请表，记录用户申请新建板块的请求';
COMMENT ON COLUMN forum_category_requests.id IS '申请ID';
COMMENT ON COLUMN forum_category_requests.requester_id IS '申请人用户ID';
COMMENT ON COLUMN forum_category_requests.name IS '申请的板块名称';
COMMENT ON COLUMN forum_category_requests.description IS '申请的板块描述';
COMMENT ON COLUMN forum_category_requests.icon IS '申请的板块图标（emoji或URL）';
COMMENT ON COLUMN forum_category_requests.type IS '板块类型：general(普通), root(国家/地区级大板块), university(大学级小板块)';
COMMENT ON COLUMN forum_category_requests.country IS '国家代码（如 UK），仅 type=root 时使用';
COMMENT ON COLUMN forum_category_requests.university_code IS '大学编码（如 UOB），仅 type=university 时使用';
COMMENT ON COLUMN forum_category_requests.status IS '申请状态：pending(待审核), approved(已通过), rejected(已拒绝)';
COMMENT ON COLUMN forum_category_requests.admin_id IS '审核的管理员ID';
COMMENT ON COLUMN forum_category_requests.reviewed_at IS '审核时间';
COMMENT ON COLUMN forum_category_requests.review_comment IS '审核意见';
COMMENT ON COLUMN forum_category_requests.created_at IS '创建时间';
COMMENT ON COLUMN forum_category_requests.updated_at IS '更新时间';
