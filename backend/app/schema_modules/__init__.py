"""
Schema 模块包 — 按领域拆分的 Pydantic 模型

迁移计划：将 app/schemas.py (3,821 行) 按以下结构逐步拆分：

  schema_modules/
  ├── __init__.py       # 本文件 — 统一重导出
  ├── user.py           # 用户相关 schema
  ├── task.py           # 任务相关 schema
  ├── payment.py        # 支付相关 schema
  └── common.py         # 共享基础 schema

迁移策略：同 crud_modules
"""
