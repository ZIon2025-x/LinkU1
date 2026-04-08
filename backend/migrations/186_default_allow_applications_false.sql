-- 186: 将 experts.allow_applications 列默认值改为 false
-- 背景：达人团队默认不接受加入申请，由 owner 在管理中心主动开启
-- 仅修改默认值，不回填已有数据（已有团队保持原状态）

ALTER TABLE experts ALTER COLUMN allow_applications SET DEFAULT false;
