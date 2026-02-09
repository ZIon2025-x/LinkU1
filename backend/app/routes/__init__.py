"""
路由包 — 按领域拆分的 API 路由模块

迁移计划：将 app/routers.py (12,748 行) 按以下结构逐步拆分：

  routes/
  ├── __init__.py          # 本文件 — 统一导出 combined_router
  ├── task_routes.py       # 任务 CRUD、搜索、推荐 (lines 1074-2240)
  ├── refund_routes.py     # 退款、争议 (lines 2361-4162)
  ├── profile_routes.py    # 用户资料、设置 (lines 4278-4949)
  ├── message_routes.py    # 消息 (lines 5153-5332)
  ├── payment_routes.py    # 支付、Stripe webhook (lines 5809-7007)
  ├── cs_routes.py         # 客服相关 (lines 7195-9513)
  └── translation_routes.py# 翻译 (lines 11486-12711)

迁移策略：
  1. 每次迁移一个域，创建新的 routes/<domain>_routes.py
  2. 在新文件中创建 router = APIRouter()，复制相关路由
  3. 在 app/main.py 中注册新路由
  4. 从 app/routers.py 中删除已迁移的路由
  5. 运行测试确认行为不变
  6. 最终 app/routers.py 仅保留无法归类的路由和向后兼容的重导出

注意：app/routers.py 的 router 同时挂载在 /api/users 和 /api 两个前缀下，
迁移时需注意路径前缀的兼容性。
"""
