"""
CRUD 模块包 — 按领域拆分的数据库操作

迁移计划：将 app/crud.py (5,536 行) 按以下结构逐步拆分：

  crud_modules/
  ├── __init__.py       # 本文件 — 统一重导出
  ├── user.py           # 用户 CRUD
  ├── task.py           # 任务 CRUD
  ├── message.py        # 消息 CRUD
  ├── payment.py        # 支付 CRUD
  └── notification.py   # 通知 CRUD

迁移策略：
  1. 从 app/crud.py 提取相关函数到对应模块
  2. 在本文件中重导出，保持 `from app.crud_modules import xxx` 可用
  3. app/crud.py 最终改为从此包导入并重导出（向后兼容）
"""
