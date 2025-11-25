# Railway Celery 部署配置指南

## 🔴 问题

Railway 在每次部署时都会读取 `railway.json` 文件中的配置，覆盖服务级别的设置：
1. `startCommand` 会覆盖 Custom Start Command
2. `healthcheckPath` 会应用到所有服务，导致 Celery Worker/Beat 健康检查失败

## ✅ 解决方案

我已经从 `railway.json` 中移除了：
1. `startCommand` - 现在每个服务可以独立配置启动命令
2. `healthcheckPath` 和 `healthcheckTimeout` - 现在每个服务可以在 Railway Dashboard 中单独配置健康检查

这样：
- **App Service** 可以设置健康检查路径为 `/health`
- **Celery Worker/Beat** 可以禁用健康检查（因为它们不提供 HTTP 服务）

---

## 📋 服务配置步骤

### 1. App Service（主服务 - FastAPI）

**配置位置：** Railway Dashboard → App Service → Settings → Deploy

**Custom Start Command：**
```bash
python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --http h11
```

**Root Directory：** `backend`

**健康检查配置：**
- **Healthcheck Path：** `/health`
- **Healthcheck Timeout：** `300`（秒）

**环境变量（重要）：**
- **Redis 配置（必需，用于 Celery 检测）：**
  - `REDIS_URL=${{Redis.REDIS_URL}}` （必须与 Celery Worker/Beat 完全相同）
  - `USE_REDIS=true` （必须设置为 true）
- **数据库配置：**
  - `DATABASE_URL=${{Postgres.DATABASE_URL}}`
- **其他必需配置：**
  - `SECRET_KEY=your-secret-key`
  - `ENVIRONMENT=production`
  - 其他应用需要的环境变量

**⚠️ 重要：** `REDIS_URL` 必须在所有服务（主程序、Worker、Beat）中**完全相同**，否则主程序无法检测到 Celery Worker。

详细环境变量配置请参考：[Celery 环境变量配置指南](./CELERY_ENV_VARS_GUIDE.md)

**验证：**
- 服务应该有公共域名
- 日志应该显示 FastAPI 启动信息

---

### 2. Celery Beat Service（定时任务调度器）

**配置位置：** Railway Dashboard → Celery Beat Service → Settings → Deploy

**Custom Start Command：**
```bash
celery -A app.celery_app beat --loglevel=info
```

**Root Directory：** `backend`

**依赖安装（重要）：**
如果遇到 `asyncpg` 编译错误，可以使用轻量级依赖文件：
- 在 Railway 的 Build Command 中设置：
  ```bash
  pip install -r requirements-celery.txt
  ```
- 或者使用环境变量 `RAILWAY_BUILD_COMMAND`：
  ```
  pip install -r requirements-celery.txt
  ```

**注意：** `requirements-celery.txt` 不包含 `asyncpg`，因为：
- Celery Beat/Worker 不需要异步数据库
- Celery 任务使用同步数据库操作
- 代码已支持 `asyncpg` 可选（会自动回退到同步模式）

**健康检查配置（重要）：**
- **Healthcheck Path：** 留空或设置为 `/`（Celery Beat 不提供 HTTP 服务）
- **Healthcheck Timeout：** 可以设置为 `0` 或留空以禁用健康检查
- 或者：在 Railway Dashboard 中禁用健康检查（如果支持）

**注意：** 由于 `railway.json` 中已移除 `healthcheckPath`，现在每个服务可以在 Railway Dashboard 中单独配置健康检查。对于 Celery Beat 这种不提供 HTTP 服务的后台任务，建议禁用健康检查。

**环境变量：**
- 复制 App Service 的所有环境变量
- 特别是：
  - `REDIS_URL=${{Redis.REDIS_URL}}`
  - `USE_REDIS=true`
  - 数据库配置
  - 其他应用需要的环境变量

**验证：**
部署后查看日志，应该看到：
```
[INFO] celery beat v5.x.x is starting.
[INFO] Scheduler: Sending due task check-and-end-activities...
```

**不应该看到：**
```
Error: Invalid value for '--port': '$PORT' is not a valid integer.
Usage: python -m uvicorn [OPTIONS] APP
1/1 replicas never became healthy!
```

---

### 3. Celery Worker Service（后台任务处理器）

**配置位置：** Railway Dashboard → Celery Worker Service → Settings → Deploy

**Custom Start Command：**
```bash
celery -A app.celery_app worker --loglevel=info --concurrency=2
```

**Root Directory：** `backend`

**依赖安装（重要）：**
如果遇到 `asyncpg` 编译错误，可以使用轻量级依赖文件：
- 在 Railway 的 Build Command 中设置：
  ```bash
  pip install -r requirements-celery.txt
  ```
- 或者使用环境变量 `RAILWAY_BUILD_COMMAND`：
  ```
  pip install -r requirements-celery.txt
  ```

**注意：** `requirements-celery.txt` 不包含 `asyncpg`，因为：
- Celery Beat/Worker 不需要异步数据库
- Celery 任务使用同步数据库操作
- 代码已支持 `asyncpg` 可选（会自动回退到同步模式）

**健康检查配置（重要）：**
- **Healthcheck Path：** 留空或设置为 `/`（Celery Worker 不提供 HTTP 服务）
- **Healthcheck Timeout：** 可以设置为 `0` 或留空以禁用健康检查
- 或者：在 Railway Dashboard 中禁用健康检查（如果支持）

**注意：** 由于 `railway.json` 中已移除 `healthcheckPath`，现在每个服务可以在 Railway Dashboard 中单独配置健康检查。对于 Celery Worker 这种不提供 HTTP 服务的后台任务，建议禁用健康检查。

**环境变量：**
- 复制 App Service 的所有环境变量
- 特别是：
  - `REDIS_URL=${{Redis.REDIS_URL}}`
  - `USE_REDIS=true`
  - 数据库配置
  - 其他应用需要的环境变量

**验证：**
部署后查看日志，应该看到：
```
[INFO] celery@xxx ready.
[INFO] Connected to redis://...
```

**不应该看到：**
```
Error: Invalid value for '--port': '$PORT' is not a valid integer.
Usage: python -m uvicorn [OPTIONS] APP
1/1 replicas never became healthy!
```

---

## 🔧 如果 Custom Start Command 仍然被覆盖

如果移除 `startCommand` 后，Custom Start Command 仍然被覆盖，尝试以下方法：

### 方法 A：使用环境变量覆盖

在 Celery 服务的 Variables 中添加：

**对于 Celery Beat：**
- 变量名：`RAILWAY_START_COMMAND`
- 变量值：`celery -A app.celery_app beat --loglevel=info`

**对于 Celery Worker：**
- 变量名：`RAILWAY_START_COMMAND`
- 变量值：`celery -A app.celery_app worker --loglevel=info --concurrency=2`

### 方法 B：使用启动脚本（最可靠）

如果方法 A 不行，使用启动脚本：

**步骤 1：确保脚本存在**

项目根目录已经有 `start_celery.sh` 脚本。

**步骤 2：配置 Celery Beat 服务**

1. **Custom Start Command：**
   ```bash
   bash start_celery.sh
   ```

2. **环境变量：**
   - `CELERY_TYPE=beat`
   - 其他所有必要的环境变量

3. **Root Directory：** 留空（脚本会自动切换到 backend）

**步骤 3：配置 Celery Worker 服务**

1. **Custom Start Command：**
   ```bash
   bash start_celery.sh
   ```

2. **环境变量：**
   - `CELERY_TYPE=worker`
   - 其他所有必要的环境变量

3. **Root Directory：** 留空（脚本会自动切换到 backend）

---

## 📝 配置检查清单

### App Service
- [ ] Custom Start Command 设置为 uvicorn 命令
- [ ] Root Directory 设置为 `backend`
- [ ] 有公共域名
- [ ] 所有环境变量已配置

### Celery Beat Service
- [ ] Custom Start Command 设置为 `celery -A app.celery_app beat --loglevel=info`
- [ ] Root Directory 设置为 `backend`
- [ ] 环境变量已复制（包括 REDIS_URL）
- [ ] 日志显示 Celery Beat 启动成功

### Celery Worker Service
- [ ] Custom Start Command 设置为 `celery -A app.celery_app worker --loglevel=info --concurrency=2`
- [ ] Root Directory 设置为 `backend`
- [ ] 环境变量已复制（包括 REDIS_URL）
- [ ] 日志显示 Celery Worker 启动成功

### Redis Service
- [ ] Redis 服务已创建
- [ ] Redis URL 已配置到所有服务

---

## 🚨 常见问题

### Q1: 部署后 Celery 服务仍然使用 uvicorn 命令

**原因：** Railway 可能缓存了旧的配置。

**解决：**
1. 确认 `railway.json` 中已移除 `startCommand`
2. 在服务设置中重新输入 Custom Start Command
3. 点击 Save
4. 手动触发重新部署

### Q2: Celery 服务无法连接到 Redis

**原因：** 环境变量配置不正确。

**解决：**
1. 检查 Redis 服务是否已创建
2. 在 Celery 服务的 Variables 中添加：
   - `REDIS_URL=${{Redis.REDIS_URL}}`
   - `USE_REDIS=true`
3. 重新部署

### Q3: Celery 服务启动失败

**原因：** 可能是依赖问题或配置错误。

**解决：**
1. 查看服务日志，找到具体错误
2. 确认 `requirements.txt` 包含 `celery` 和 `redis`
3. 确认 Root Directory 设置为 `backend`
4. 确认所有环境变量已正确配置

---

## 📚 Railway 配置优先级

Railway 的配置优先级（从高到低）：

1. **环境变量 `RAILWAY_START_COMMAND`**（最高优先级）
2. **界面中的 Custom Start Command**
3. **railway.json 文件中的 startCommand**（已移除）

现在 `railway.json` 中没有 `startCommand`，所以每个服务可以独立配置。

---

## ✅ 验证部署成功

部署成功后，你应该看到：

1. **App Service 日志：**
   ```
   INFO:     Started server process
   INFO:     Uvicorn running on http://0.0.0.0:8000
   ```

2. **Celery Beat 日志：**
   ```
   [INFO] celery beat v5.x.x is starting.
   [INFO] Scheduler: Sending due task check-and-end-activities...
   ```

3. **Celery Worker 日志：**
   ```
   [INFO] celery@xxx ready.
   [INFO] Connected to redis://...
   ```

如果看到这些日志，说明部署成功！🎉

