-- 创建岗位表
CREATE TABLE IF NOT EXISTS job_positions (
    id SERIAL PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    department VARCHAR(50) NOT NULL,
    type VARCHAR(20) NOT NULL,
    location VARCHAR(100) NOT NULL,
    experience VARCHAR(50) NOT NULL,
    salary VARCHAR(50) NOT NULL,
    description TEXT NOT NULL,
    requirements TEXT NOT NULL,  -- JSON格式存储
    tags TEXT,  -- JSON格式存储
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(5) NOT NULL REFERENCES admin_users(id)
);

-- 创建索引
CREATE INDEX IF NOT EXISTS ix_job_positions_title ON job_positions(title);
CREATE INDEX IF NOT EXISTS ix_job_positions_department ON job_positions(department);
CREATE INDEX IF NOT EXISTS ix_job_positions_type ON job_positions(type);
CREATE INDEX IF NOT EXISTS ix_job_positions_location ON job_positions(location);
CREATE INDEX IF NOT EXISTS ix_job_positions_is_active ON job_positions(is_active);
CREATE INDEX IF NOT EXISTS ix_job_positions_created_at ON job_positions(created_at);

-- 插入一些示例数据
INSERT INTO job_positions (title, department, type, location, experience, salary, description, requirements, tags, created_by) VALUES
('前端开发工程师', '技术部', '全职', '北京/远程', '3-5年', '15-25K', '负责平台前端开发，参与产品设计和用户体验优化', '["熟练掌握 React、Vue 等前端框架", "熟悉 TypeScript、ES6+ 语法", "有移动端开发经验优先", "具备良好的代码规范和团队协作能力"]', '["React", "TypeScript", "Vue", "前端"]', 'A0001'),
('后端开发工程师', '技术部', '全职', '北京/远程', '3-5年', '18-30K', '负责平台后端开发，API设计和数据库优化', '["熟练掌握 Python 及相关框架", "熟悉 FastAPI、Django 等 Web 框架", "有数据库设计和优化经验", "了解微服务架构和云服务"]', '["Python", "FastAPI", "PostgreSQL", "Redis"]', 'A0001'),
('产品经理', '产品部', '全职', '北京', '2-4年', '12-20K', '负责产品规划和设计，用户需求分析和产品迭代', '["有互联网产品经验", "熟悉产品设计流程", "具备数据分析能力", "有平台类产品经验优先"]', '["产品设计", "用户研究", "数据分析", "产品"]', 'A0001'),
('UI/UX 设计师', '设计部', '全职', '北京/远程', '2-4年', '10-18K', '负责产品界面设计和用户体验优化', '["熟练掌握设计工具", "有移动端设计经验", "了解设计规范和用户心理", "有平台类产品设计经验优先"]', '["UI设计", "UX设计", "Figma", "设计"]', 'A0001'),
('运营专员', '运营部', '全职', '北京', '1-3年', '8-15K', '负责用户运营和内容运营，提升用户活跃度', '["有互联网运营经验", "熟悉社交媒体运营", "具备数据分析能力", "有社区运营经验优先"]', '["用户运营", "内容运营", "数据分析", "运营"]', 'A0001'),
('客服专员', '客服部', '全职', '北京/远程', '1-2年', '6-10K', '负责用户咨询和问题处理，维护用户关系', '["具备良好的沟通能力", "有客服工作经验", "熟悉在线客服工具", "有耐心和责任心"]', '["客户服务", "沟通能力", "问题解决", "客服"]', 'A0001');
