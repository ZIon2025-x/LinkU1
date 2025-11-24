# 异步数据库连接池优化文档

## 📋 问题概述

在部署环境中，应用关闭或重启时会出现以下错误：

1. **事件循环关闭错误** (`RuntimeError: Event loop is closed`)
2. **协程未等待警告** (`RuntimeWarning: coroutine 'Connection._cancel' was never awaited`)
3. **SQLAlchemy 连接池终止错误** (`Exception terminating connection`)

这些错误**不影响应用功能**，但会在日志中产生噪音，可能影响问题排查。

## 🔍 问题原因

### 1. 事件循环生命周期问题

当应用关闭时，FastAPI/Uvicorn 会关闭事件循环，但：
- SQLAlchemy 的异步连接池仍在尝试关闭连接
- asyncpg 的连接对象尝试取消等待的操作
- 这些操作需要事件循环，但事件循环已经关闭

### 2. 异步/同步混用

应用同时使用：
- **同步数据库连接** (`SessionLocal`) - 用于传统路由（⚠️ 已标记为弃用）
- **异步数据库连接** (`AsyncSessionLocal`) - 用于高性能路由

这增加了连接池管理的复杂度。

**中长期计划**:
- ✅ 新接口一律使用 `AsyncSessionLocal`（异步模式）
- ✅ 老接口逐步迁移到异步模式
- ✅ `SessionLocal` 已标记为弃用，使用时会显示警告
- ✅ 最终只保留一套异步访问层，简化连接池管理

### 3. 连接池关闭时机

连接池关闭发生在：
- 应用关闭时 (`shutdown_event`)
- 连接回收时 (`pool_recycle`)
- 连接超时时 (`pool_timeout`)

如果此时事件循环已关闭，就会产生错误。

## ✅ 已实施的解决方案

### 1. 全局关停标记机制

**文件**: `backend/app/state.py`

使用全局关停标记代替到处判断事件循环状态，逻辑更清晰：

```python
# 全局关停标记
is_shutting_down = False

def mark_shutting_down():
    """标记应用正在关停"""
    global is_shutting_down
    is_shutting_down = True

def is_app_shutting_down() -> bool:
    """检查应用是否正在关停"""
    return is_shutting_down
```

**改进点**:
- ✅ 避免在业务代码中到处捕获 `RuntimeError`
- ✅ 只在确认关停时才优雅降级
- ✅ 不会误吞真正的 `RuntimeError`

### 2. 精简数据库连接池关闭逻辑

**文件**: `backend/app/database.py`

```python
async def close_database_pools():
    """
    安全关闭所有数据库连接池（假设此时事件循环仍可用）
    
    注意：调用此函数前应确保事件循环仍然可用。
    如果事件循环已关闭，此函数会捕获相关错误并优雅处理。
    """
    # 可选：给正在运行的协程一点时间结束
    await asyncio.sleep(0.1)  # 从 0.5 秒减少到 0.1 秒
    
    try:
        await async_engine.dispose(close=True)
        logger.info("异步数据库连接池已关闭")
    except RuntimeError as e:
        if "Event loop is closed" in str(e):
            logger.debug("关闭连接池时事件循环已关闭，忽略该错误")
        else:
            logger.exception("关闭连接池时出现 RuntimeError")
```

**改进点**:
- ✅ 减少多重判断和睡眠时间
- ✅ 将"是否关停/loop 状态判断"放在调用端（`shutdown_event`）
- ✅ 函数本身假设 loop 还活着，只对极端情况做兜底

### 3. 改进应用关闭流程

**文件**: `backend/app/main.py`

```python
@app.on_event("shutdown")
async def shutdown_event():
    """应用关闭时清理资源"""
    # 标记应用正在关停
    mark_shutting_down()
    
    # 1. 停止连接池监控任务
    # 2. 停止异步清理任务
    # 3. 关闭所有活跃的 WebSocket 连接
    # 4. 关闭数据库连接池（在事件循环关闭之前）
    
    try:
        loop = asyncio.get_running_loop()
        if not loop.is_closed():
            await close_database_pools()
    except RuntimeError:
        logger.debug("没有运行中的事件循环，跳过数据库连接池关闭")
```

**改进点**:
- ✅ 使用全局关停标记
- ✅ 在关闭数据库连接池前检查事件循环状态
- ✅ 确保关闭顺序正确

### 4. 精确的日志过滤器

**文件**: `backend/app/main.py`

```python
class SQLAlchemyPoolErrorFilter(logging.Filter):
    def filter(self, record):
        # 只处理 SQLAlchemy 内部连接池的日志
        if not record.name.startswith("sqlalchemy.pool"):
            return True
        
        msg = record.getMessage()
        
        # 过滤掉连接池关闭时的事件循环错误
        if "Exception terminating connection" in msg:
            if any(keyword in msg for keyword in [
                "Event loop is closed",
                "loop is closed",
            ]):
                record.levelno = logging.DEBUG
                record.levelname = "DEBUG"
                return True
            # "attached to a different loop" 需要关注，不降级
            if "attached to a different loop" in msg:
                return True  # 保持原始级别
        
        # 过滤掉 asyncpg 的协程未等待警告
        if "coroutine" in msg and "was never awaited" in msg and "Connection._cancel" in msg:
            record.levelno = logging.DEBUG
            record.levelname = "DEBUG"
            return True
        
        return True
```

**改进点**:
- ✅ 利用 logger 名称缩小范围，避免误伤其他错误
- ✅ "attached to a different loop" 不降级，保持原始级别
- ✅ 只处理 SQLAlchemy 连接池相关的日志

### 5. 改进异步 CRUD 错误处理

**文件**: `backend/app/async_crud.py`

```python
@staticmethod
async def get_user_by_id(db: AsyncSession, user_id: str) -> Optional[models.User]:
    """根据ID获取用户"""
    try:
        result = await db.execute(
            select(models.User).where(models.User.id == user_id)
        )
        return result.scalar_one_or_none()
    except RuntimeError as e:
        # 只在确认应用正在关停时才优雅降级
        from app.state import is_app_shutting_down
        error_str = str(e)
        
        if is_app_shutting_down() and (
            "Event loop is closed" in error_str or "loop is closed" in error_str
        ):
            logger.debug(f"事件循环已关闭，跳过查询用户 {user_id}（应用正在关闭）")
            return None
        
        # 其它 RuntimeError 应该继续抛出，避免吞掉真正的问题
        raise
```

**改进点**:
- ✅ 使用关停标记判断，而不是捕获所有 `RuntimeError`
- ✅ 只在确认关停时才优雅降级
- ✅ 不会误吞真正的 `RuntimeError`

### 6. 连接池监控

**文件**: `backend/app/database.py`

添加了连接池状态监控，每分钟检查一次，如果压力偏高则记录警告：

```python
async def monitor_pool_state():
    """监控连接池状态，如果压力偏高则记录警告日志"""
    while not is_app_shutting_down():
        pool = async_engine.pool
        pool_size = pool.size()
        checked_out = pool.checkedout()
        overflow = pool.overflow()
        
        # 检查连接池压力
        if overflow > 0:
            logger.warning("数据库连接池压力偏高: overflow=%d", overflow)
        elif checked_out > pool_size * 0.8:
            logger.warning("数据库连接池使用率较高: checked_out=%d, pool_size=%d", 
                         checked_out, pool_size)
        
        await asyncio.sleep(60)
```

**改进点**:
- ✅ 自动监控连接池状态
- ✅ 压力偏高时自动告警
- ✅ 帮助运维人员及时发现连接池配置问题

## ⚙️ 相关配置

### 数据库连接池配置

**文件**: `backend/app/database.py`

```python
# 生产环境配置
POOL_SIZE = 30              # 连接池大小
MAX_OVERFLOW = 40            # 最大溢出连接数
POOL_TIMEOUT = 30            # 获取连接超时时间（秒）
POOL_RECYCLE = 1800          # 连接回收时间（30分钟）
POOL_PRE_PING = True         # 连接前检查
QUERY_TIMEOUT = 30           # 查询超时时间（秒）

# 开发环境配置
POOL_SIZE = 10
MAX_OVERFLOW = 20
POOL_RECYCLE = 3600          # 1小时
```

### 环境变量

```bash
# 数据库配置
DATABASE_URL=postgresql+psycopg2://...
ASYNC_DATABASE_URL=postgresql+asyncpg://...

# 连接池配置（可选）
DB_POOL_SIZE=30
DB_MAX_OVERFLOW=40
DB_POOL_TIMEOUT=30
DB_POOL_RECYCLE=1800
DB_POOL_PRE_PING=true
DB_QUERY_TIMEOUT=30

# 环境标识
ENVIRONMENT=production
```

## 📊 错误分类

### 1. 可忽略的错误（已处理）

这些错误在应用关闭时是正常的，已被降级为 DEBUG：

- ✅ `RuntimeError: Event loop is closed`
- ✅ `RuntimeWarning: coroutine 'Connection._cancel' was never awaited`
- ✅ `Exception terminating connection` (当包含事件循环关闭信息时)

### 2. 需要关注的错误

这些错误可能表示实际问题：

- ⚠️ `RuntimeError: attached to a different loop` - 可能表示连接池配置问题
- ⚠️ `asyncio.TimeoutError` - 可能表示连接池过小或查询超时
- ⚠️ `asyncpg.exceptions.PostgresError` - 数据库层面的错误

## 🔧 故障排查

### 检查连接池状态

```bash
# 访问连接池状态端点
curl http://api.link2ur.com/api/system/database/pool
```

响应示例：
```json
{
  "pool_size": 30,
  "checked_in": 25,
  "checked_out": 5,
  "overflow": 0,
  "invalid": 0
}
```

### 检查日志级别

确保生产环境日志级别设置为 `INFO` 或 `WARNING`，这样 DEBUG 级别的错误不会出现在日志中：

```python
# 生产环境
logging.basicConfig(level=logging.INFO)

# 开发环境
logging.basicConfig(level=logging.DEBUG)
```

### 监控连接池使用情况

如果经常看到 `overflow > 0`，可能需要：
1. 增加 `POOL_SIZE`
2. 增加 `MAX_OVERFLOW`
3. 检查是否有连接泄漏

## 📈 性能优化建议

### 1. 连接池大小调优

**当前配置**:
- 生产: `POOL_SIZE=30, MAX_OVERFLOW=40`
- 开发: `POOL_SIZE=10, MAX_OVERFLOW=20`

**调优策略**:
```
POOL_SIZE ≈ 2~4 × CPU 核数（如果是 I/O 密集可以适当放大）
MAX_OVERFLOW ≈ POOL_SIZE ~ 2 × POOL_SIZE
```

**具体建议**:
- ✅ 如果 `overflow` 经常 > 0 且查询不算很慢 → 考虑加大 `POOL_SIZE`
- ✅ 如果 `checked_out` 常年 << `POOL_SIZE/2` → 可以适当减小，节省数据库连接
- ✅ 监控 `checked_out` 和 `overflow` 指标（通过 `/api/system/database/pool` 端点）

### 2. 连接回收时间

**当前配置**: `POOL_RECYCLE=1800` (30分钟)

**调优建议**:
- PostgreSQL 默认连接超时为 10 小时
- 建议设置为 `POOL_RECYCLE < 数据库连接超时`
- 如果数据库连接超时设置为 1 小时，建议 `POOL_RECYCLE=3600`

### 3. 查询超时

**当前配置**: `QUERY_TIMEOUT=30` (30秒)

**调优建议**:
- 根据业务需求调整
- 简单查询: 5-10秒
- 复杂查询: 30-60秒
- 报表查询: 60-120秒

### 4. 连接池监控

**自动监控**:
- ✅ 每分钟自动检查连接池状态
- ✅ 如果 `overflow > 0` 或 `checked_out > pool_size * 0.8`，记录警告日志
- ✅ 帮助运维人员及时发现连接池配置问题

**手动检查**:
```bash
# 访问连接池状态端点
curl http://api.link2ur.com/api/system/database/pool
```

## 🚀 最佳实践

### 1. 使用异步路由处理高并发请求

```python
# ✅ 推荐：使用异步路由
@async_router.get("/tasks")
async def get_tasks(db: AsyncSession = Depends(get_async_db_dependency)):
    tasks = await async_crud.async_task_crud.get_tasks(db)
    return tasks

# ❌ 不推荐：在异步路由中使用同步数据库
@router.get("/tasks")
def get_tasks(db: Session = Depends(get_db)):
    tasks = crud.get_tasks(db)
    return tasks
```

### 2. 正确关闭数据库会话

```python
# ✅ 推荐：使用依赖注入自动关闭
async def get_tasks(db: AsyncSession = Depends(get_async_db_dependency)):
    tasks = await async_crud.get_tasks(db)
    return tasks  # 会话会自动关闭

# ❌ 不推荐：手动管理会话（容易泄漏）
async def get_tasks():
    async with AsyncSessionLocal() as db:
        tasks = await async_crud.get_tasks(db)
    return tasks
```

### 3. 处理事件循环关闭错误

```python
# ✅ 推荐：捕获并优雅处理
try:
    result = await db.execute(query)
except RuntimeError as e:
    if "Event loop is closed" in str(e):
        logger.debug("事件循环已关闭，跳过查询")
        return None
    raise

# ❌ 不推荐：忽略所有错误
try:
    result = await db.execute(query)
except:
    return None  # 可能隐藏真正的错误
```

## 📝 总结

### 已解决的问题

1. ✅ 使用全局关停标记，避免到处判断事件循环状态
2. ✅ 精简连接池关闭逻辑，减少多重判断和睡眠时间
3. ✅ 精确的日志过滤器，避免误伤其他错误
4. ✅ 连接池自动监控，及时发现配置问题
5. ✅ 异步 CRUD 错误处理改进，不会误吞真正的错误
6. ✅ SessionLocal 标记为弃用，引导使用异步模式

### 仍需关注

1. ⚠️ 监控连接池使用情况
2. ⚠️ 根据实际负载调整连接池大小
3. ⚠️ 定期检查连接泄漏

### 影响评估

- **功能影响**: 无（错误已被优雅处理）
- **性能影响**: 无（不影响正常运行）
- **日志影响**: 减少（错误降级为 DEBUG）

## 🔗 相关文件

- `backend/app/state.py` - 应用状态管理（关停标记）
- `backend/app/database.py` - 数据库连接池配置、关闭逻辑和监控
- `backend/app/main.py` - 应用启动/关闭事件和日志过滤器
- `backend/app/async_crud.py` - 异步 CRUD 操作和错误处理
- `backend/app/deps.py` - 数据库依赖注入

## 📚 参考资料

- [SQLAlchemy 异步引擎文档](https://docs.sqlalchemy.org/en/14/core/engines.html#asyncio)
- [asyncpg 文档](https://magicstack.github.io/asyncpg/current/)
- [FastAPI 数据库文档](https://fastapi.tiangolo.com/tutorial/sql-databases/)

