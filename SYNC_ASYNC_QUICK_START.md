# 同步/异步混用 - 快速入门

## 🎯 问题是什么？

你的后端同时使用了两种数据库访问模式：

1. **同步模式** - 传统方式，阻塞I/O
2. **异步模式** - 现代方式，非阻塞I/O

这会导致性能和复杂度问题。

## 🚀 已实施的解决方案

### 1. 创建了适配器模块

文件：`backend/app/async_adapter.py`

这个模块允许你在异步路由中安全地调用同步CRUD操作。

### 2. 增加了连接池大小

修改了 `backend/app/database.py` 中的连接池配置：

**开发环境**:
- 之前：POOL_SIZE=5, MAX_OVERFLOW=10
- 现在：POOL_SIZE=10, MAX_OVERFLOW=20

**生产环境**:
- 之前：POOL_SIZE=20, MAX_OVERFLOW=30  
- 现在：POOL_SIZE=30, MAX_OVERFLOW=40

## 📖 如何使用

### 在异步路由中调用同步CRUD

```python
from app.async_adapter import sync_to_async
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.deps import get_async_db_dependency

@router.post("/tasks/legacy")
async def create_task_using_legacy_crud(
    task: schemas.TaskCreate,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user = Depends(get_current_user_secure_async_csrf)
):
    """
    在异步路由中使用同步CRUD操作的示例
    """
    # 方式1: 先获取同步session
    from app.database import sync_engine
    from sqlalchemy.orm import sessionmaker
    SessionLocal = sessionmaker(bind=sync_engine)
    
    # 在同步context中使用
    with SessionLocal() as sync_db:
        # 使用适配器调用同步CRUD
        db_task = await sync_to_async.create_task(
            sync_db, current_user.id, task
        )
    
    return db_task
```

### 直接使用异步CRUD（推荐）

```python
from app import async_crud
from app.deps import get_async_db_dependency

@router.post("/tasks/new")
async def create_task_using_async_crud(
    task: schemas.TaskCreate,
    db: AsyncSession = Depends(get_async_db_dependency),
    current_user = Depends(get_current_user_secure_async_csrf)
):
    """
    推荐方式：直接使用异步CRUD
    """
    db_task = await async_crud.async_task_crud.create_task(
        db, task, current_user.id
    )
    
    return db_task
```

## 🎓 最佳实践

### ✅ 推荐做法

1. **新路由优先使用异步CRUD**
   ```python
   # 推荐
   @router.get("/tasks")
   async def list_tasks(db: AsyncSession = Depends(get_async_db_dependency)):
       tasks = await async_crud.async_task_crud.get_tasks(db)
       return tasks
   ```

2. **旧路由保持同步，逐步迁移**
   ```python
   # 也可以接受
   @router.get("/tasks/legacy")  
   def list_tasks_legacy(db: Session = Depends(get_db)):
       tasks = crud.list_tasks(db)
       return tasks
   ```

### ❌ 避免的做法

1. **不要混用同步和异步CRUD在同一路由中**
   ```python
   # 错误示例
   async def bad():
       user = await async_crud.get_user(db)  # 异步
       task = crud.create_task(sync_db)      # 同步
   ```

2. **不要在同一事务中切换同步/异步**
   ```python
   # 错误示例
   async def bad():
       async with db.begin():
           user = await async_crud.get_user(db)      # 异步
           crud.update_user(sync_db, user)          # 同步
   ```

## 🔄 迁移计划

### 第一阶段（已完成）
- ✅ 创建适配器模块
- ✅ 增加连接池配置
- ✅ 提供文档和示例

### 第二阶段（进行中）
- [ ] 识别高频API
- [ ] 优先迁移任务相关API
- [ ] 迁移用户信息API

### 第三阶段（未来）
- [ ] 逐步迁移所有路由
- [ ] 移除同步依赖
- [ ] 完全异步化

## 📊 性能监控

添加以下代码监控连接池状态：

```python
from app.database import get_pool_status

@router.get("/admin/pool-status")
async def get_db_pool_status():
    status = await get_pool_status()
    return status
```

## 🎯 总结

### 立即生效
1. ✅ 适配器已经就绪，可以在异步路由中使用
2. ✅ 连接池已增大，支持混合使用
3. ✅ 有明确的迁移路径

### 未来优化
1. 逐步迁移高频API到异步
2. 移除适配器（不再需要时）
3. 完全异步化

## 📚 相关文档

- `SYNC_ASYNC_MIXED_SOLUTION.md` - 完整解决方案
- `HIGH_PRIORITY_FIXES_COMPLETE.md` - 已完成的优化
- `BACKEND_BUILD_OPTIMIZATION_ANALYSIS.md` - 优化分析

## ⚠️ 重要提示

1. **不要同时进行大量同步和异步操作**
   - 这会耗尽连接池

2. **监控连接池使用情况**
   - 如果看到连接池耗尽，需要进一步增加

3. **优先迁移高频API**
   - 这些API影响最大用户
   - 异步化它们能带来最大的性能提升

