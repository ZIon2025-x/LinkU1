"""达人团队收款与责任声明 — 当前版本号

版本号变更流程：
1. 写新的 legal_documents seed migration（参考 230_seed_expert_terms_legal_document.sql）
2. 跑 migration 把新版本写入 DB
3. 更新这里的 EXPERT_TERMS_VERSION 与 SQL 里的 version 字段保持一致
4. push 代码：现存 pending application 提交时会被拒，强制用户重读

content_json 不在 Python 侧维护，统一从 legal_documents 表读取
（路由：GET /api/legal/expert_terms?lang=zh|en）。
"""

EXPERT_TERMS_TYPE = "expert_terms"
EXPERT_TERMS_VERSION = "v1.0"
