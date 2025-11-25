# Celery Beat/Worker asyncpg 编译错误解决方案

## 🔴 问题

在安装依赖时，`asyncpg` 构建失败，导致 Celery Beat/Worker 服务无法启动。

**错误信息：**
```
Building wheel for asyncpg (pyproject.toml): finished with status 'error'
error: subprocess-exited-with-error
```

## ✅ 解决方案

### 方案 1：使用轻量级依赖文件（推荐）

对于 Celery Beat 和 Celery Worker 服务，使用 `requirements-celery.txt`，它不包含 `asyncpg`：

**在 Railway 中配置：**

1. **进入 Celery Beat/Worker 服务**
2. **Settings → Build**
3. **Build Command** 设置为：
   ```bash
   pip install -r requirements-celery.txt
   ```

或者使用环境变量：
- 变量名：`RAILWAY_BUILD_COMMAND`
- 变量值：`pip install -r requirements-celery.txt`

### 方案 2：跳过 asyncpg 安装（如果方案1不行）

如果 Railway 不支持自定义 Build Command，可以：

1. **修改安装命令**，跳过 asyncpg：
   ```bash
   pip install -r requirements.txt --ignore-installed asyncpg || pip install -r requirements.txt
   ```

2. **或者手动安装依赖**（不推荐，但可行）：
   ```bash
   pip install celery[redis] redis sqlalchemy pydantic aiopg psycopg2-binary python-dotenv pytz requests orjson passlib[bcrypt] bcrypt PyJWT
   ```

## 📋 为什么 Celery 不需要 asyncpg？

1. **Celery Beat** 只是调度器，不直接访问数据库
2. **Celery Worker** 执行任务时使用同步数据库操作（通过 `SessionLocal`）
3. **代码已支持回退**：如果 `asyncpg` 不可用，`ASYNC_AVAILABLE=False`，系统会自动使用同步模式

## 🔍 验证

部署后，检查日志应该看到：
- Celery Beat/Worker 正常启动
- 没有 asyncpg 相关的错误
- 任务正常执行

如果看到 `⚠️ asyncpg not available, using sync mode only`，这是正常的，不影响 Celery 功能。

## 📝 注意事项

- **主服务（FastAPI）** 仍然使用 `requirements.txt`（包含 asyncpg）
- **Celery 服务** 使用 `requirements-celery.txt`（不包含 asyncpg）
- 代码已完全支持 asyncpg 可选，不会影响功能

