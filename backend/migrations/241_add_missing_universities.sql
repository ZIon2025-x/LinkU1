-- ===========================================
-- 迁移文件 241: 学生认证白名单清理 — 去掉 name UNIQUE + 补 3 个缺漏注册域
--
-- 背景: 2026-05-19 BCU 学生 yujun.liu@mail.bcu.ac.uk 提交学生认证被拒,触发
--       121 条 seed 系统审计。结论:
--       - 没有"官网域当邮件域"的错条目(Birmingham bham.ac.uk 等都是对的)
--       - 但有 3 个机构缺漏需补:
--         1. Birmingham City University (post-92,seed 漏录)
--         2. Norwich University of the Arts: nua.ac.uk → norwichuni.ac.uk 过渡中
--         3. University of Central Lancashire 已 rebrand 为 University of
--            Lancashire,新域 lancashire.ac.uk
--
-- 同时去掉 universities.name 的 UNIQUE 约束 — rebrand 场景(Norwich/UCLan)需要
-- 同一机构有两行(不同 email_domain,同 name),UNIQUE 反而碍事。重名防护改靠
-- email_domain UNIQUE 兜底(admin 手动写错名字不会触发兼容问题)。
--
-- domain_pattern 字段配合 .ac.uk open-by-suffix matcher 不再被新代码读取,仅为
-- 兼容旧 schema 保留占位。
-- ===========================================

-- 0. 去掉 name UNIQUE 约束(rebrand 场景需要)
ALTER TABLE universities DROP CONSTRAINT IF EXISTS universities_name_key;

-- 1. Birmingham City University (post-92,seed 漏录)
INSERT INTO universities (name, name_cn, email_domain, domain_pattern, is_active)
VALUES ('Birmingham City University', '伯明翰城市大学', 'bcu.ac.uk', '@*.bcu.ac.uk', TRUE)
ON CONFLICT (email_domain) DO NOTHING;

-- 2. Norwich University of the Arts 新域 (与 nua.ac.uk 共享 name,靠 0 步去 UNIQUE)
INSERT INTO universities (name, name_cn, email_domain, domain_pattern, is_active)
VALUES ('Norwich University of the Arts', '诺里奇艺术大学', 'norwichuni.ac.uk', '@*.norwichuni.ac.uk', TRUE)
ON CONFLICT (email_domain) DO NOTHING;

-- 3. University of Lancashire 新域 (与 uclan.ac.uk 并存,name 不同所以不存在 UNIQUE 问题)
INSERT INTO universities (name, name_cn, email_domain, domain_pattern, is_active)
VALUES ('University of Lancashire', '兰开夏大学', 'lancashire.ac.uk', '@*.lancashire.ac.uk', TRUE)
ON CONFLICT (email_domain) DO NOTHING;
