-- ===========================================
-- 迁移文件 241: 补录学生认证白名单缺失的 3 个注册域
--
-- 背景: 2026-05-19 BCU 学生 yujun.liu@mail.bcu.ac.uk 提交学生认证被拒,触发
--       121 条 seed 系统审计。结论:
--       - 没有"官网域当邮件域"的错条目(Birmingham bham.ac.uk 等都是对的)
--       - 但有 3 个机构缺漏需补:
--         1. Birmingham City University (post-92 学校,seed 漏录)
--         2. Norwich University of the Arts 2025-08 起从 nua.ac.uk 迁移到
--            norwichuni.ac.uk,seed 里只有旧的
--         3. University of Central Lancashire 已 rebrand 为 University of
--            Lancashire,新域 lancashire.ac.uk,seed 里只有旧的 uclan.ac.uk
--
-- domain_pattern 字段配合即将上线的 .ac.uk open-by-suffix matcher (注册域取
-- 最后 3 段) 不再被新代码读取,仅为兼容旧 schema 保留占位。
-- ===========================================

-- 1. Birmingham City University (post-92 学校,seed 漏录)
INSERT INTO universities (name, name_cn, email_domain, domain_pattern, is_active)
VALUES ('Birmingham City University', '伯明翰城市大学', 'bcu.ac.uk', '@*.bcu.ac.uk', TRUE)
ON CONFLICT (email_domain) DO NOTHING;

-- 2. Norwich University of the Arts 新域 (与 nua.ac.uk 并存)
INSERT INTO universities (name, name_cn, email_domain, domain_pattern, is_active)
VALUES ('Norwich University of the Arts', '诺里奇艺术大学', 'norwichuni.ac.uk', '@*.norwichuni.ac.uk', TRUE)
ON CONFLICT (email_domain) DO NOTHING;

-- 3. University of Lancashire 新域 (与 uclan.ac.uk 并存)
INSERT INTO universities (name, name_cn, email_domain, domain_pattern, is_active)
VALUES ('University of Lancashire', '兰开夏大学', 'lancashire.ac.uk', '@*.lancashire.ac.uk', TRUE)
ON CONFLICT (email_domain) DO NOTHING;
