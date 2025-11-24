# Celery Worker 检测问题诊断指南

## ✅ 当前状态

- ✅ TaskScheduler 已成功启动（导入错误已修复）
- ✅ 定时任务正常执行
- ⚠️ Celery Worker 检测不到

## 🔍 诊断步骤

### 步骤 1：检查 Worker 服务日志

在 Railway 的 **Celery Worker 服务**中：

1. 进入 Worker 服务
2. 点击 **Logs** 标签页
3. 查看是否有以下日志：

**正常启动应该看到：**
```
[INFO] celery@xxx ready.
[INFO] Connected to redis://...
```

**如果有错误，可能看到：**
```
[ERROR] Connection to broker lost. Trying to re-establish the connection...
[ERROR] Cannot connect to redis://...
```

### 步骤 2：验证环境变量一致性

确保 **所有服务**（主服务、Worker、Beat）都有相同的环境变量：

#### 必须一致的环境变量：

1. **REDIS_URL** - 必须完全相同
   - 主服务：`redis://xxx:xxx@xxx:xxx/0`
   - Worker 服务：`redis://xxx:xxx@xxx:xxx/0` （必须相同）
   - Beat 服务：`redis://xxx:xxx@xxx:xxx/0` （必须相同）

2. **USE_REDIS** - 必须都是 `true`

#### 检查方法：

在 Railway 中：
1. 进入每个服务
2. 点击 **Variables** 标签页
3. 对比 `REDIS_URL` 是否完全一致

### 步骤 3：检查 Worker 启动命令

在 Worker 服务的 **Settings** → **Deploy** → **Custom Start Command** 中：

**正确的命令：**
```bash
celery -A app.celery_app worker --loglevel=info --concurrency=2
```

**错误的命令（会导致问题）：**
```bash
# ❌ 错误：包含端口
celery -A app.celery_app worker --port $PORT

# ❌ 错误：使用了 FastAPI 命令
python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT
```

**⚠️ 重要：如果命令被 railway.json 覆盖**

如果发现 Custom Start Command 被 `railway.json` 中的命令覆盖：

1. **清空 Custom Start Command 字段**
2. **重新输入 Celery 命令**
3. **点击 Save 保存**
4. **或者使用环境变量覆盖**：添加 `RAILWAY_START_COMMAND=celery -A app.celery_app worker --loglevel=info --concurrency=2`

### 步骤 4：检查服务启动顺序

**问题：** 如果主服务启动时 Worker 还未准备好，检测会失败。

**解决方案：**
1. 先启动 Worker 服务
2. 等待 Worker 完全启动（查看日志确认）
3. 然后启动主服务

或者：
- 等待几秒钟后，主服务会自动重试检测（通过健康检查端点）

### 步骤 5：手动测试 Worker 连接

如果可以在 Railway 终端运行命令：

```bash
# 进入 Worker 服务
# 运行以下命令测试

# 1. 测试 Redis 连接
python -c "import redis; r = redis.from_url('$REDIS_URL'); print(r.ping())"

# 2. 测试 Celery Worker 状态
celery -A app.celery_app inspect active

# 3. 查看注册的任务
celery -A app.celery_app inspect registered
```

## 🛠️ 常见问题解决方案

### 问题 1：Worker 日志显示连接失败

**症状：**
```
[ERROR] Cannot connect to redis://...
```

**解决方案：**
1. 检查 `REDIS_URL` 是否正确
2. 确认 Redis 服务正在运行
3. 检查网络连接

### 问题 2：Worker 启动但主服务检测不到

**可能原因：**
1. **不同的 Redis URL** - 最常见的原因
2. **Worker 启动时间慢** - 主服务启动时 Worker 还未准备好
3. **网络延迟** - Railway 服务之间的网络延迟

**解决方案：**
1. **确保 REDIS_URL 一致**：
   - 在 Railway 中，所有服务应该使用相同的 Redis 服务
   - 使用 **"Add from..."** → **"Add from [Redis服务名]"** 来确保一致性

2. **增加检测超时时间**（已修复）：
   - 已从 2 秒增加到 5 秒
   - 如果还是检测不到，可以进一步增加

3. **使用健康检查端点验证**：
   ```bash
   curl https://api.link2ur.com/health
   ```
   查看 `celery_worker` 字段

### 问题 3：Worker 服务不断重启

**可能原因：**
1. Worker 启动命令错误
2. 缺少必要的环境变量
3. 代码错误导致崩溃

**解决方案：**
1. 检查 Worker 服务的日志
2. 确认启动命令正确
3. 确保所有环境变量都已设置

## 📊 验证 Worker 是否正常工作

### 方法 1：健康检查端点

```bash
curl https://api.link2ur.com/health
```

应该看到：
```json
{
  "status": "healthy",
  "checks": {
    "celery_worker": "ok (1 workers)"
  }
}
```

### 方法 2：查看主服务日志

如果 Worker 被检测到，应该看到：
```
✅ Redis 连接成功，Celery Worker 在线 (1 workers)，将使用 Celery 执行定时任务
```

### 方法 3：查看 Worker 日志

Worker 服务日志中应该看到：
```
[INFO] celery@xxx ready.
[INFO] Connected to redis://...
```

## 🔄 如果 Worker 仍然检测不到

### 临时解决方案

当前系统已经回退到 **TaskScheduler**，这是完全正常的：
- ✅ 所有定时任务正常执行
- ✅ 功能完全正常
- ✅ 无需额外操作

### 长期解决方案

如果需要使用 Celery（推荐用于生产环境）：

1. **确保所有服务使用相同的 Redis URL**
   - 在 Railway 中，使用共享的 Redis 服务
   - 所有服务从同一个 Redis 服务获取 `REDIS_URL`

2. **检查服务启动顺序**
   - 先启动 Worker
   - 再启动 Beat
   - 最后启动主服务

3. **验证 Worker 配置**
   - 启动命令正确
   - 环境变量完整
   - 日志无错误

## 📝 检查清单

在 Railway 上配置 Celery Worker 时，请确认：

- [ ] Worker 服务的启动命令：`celery -A app.celery_app worker --loglevel=info --concurrency=2`
- [ ] Beat 服务的启动命令：`celery -A app.celery_app beat --loglevel=info`
- [ ] 所有服务都有 `REDIS_URL` 环境变量
- [ ] 所有服务的 `REDIS_URL` 完全相同
- [ ] 所有服务都有 `USE_REDIS=true`
- [ ] Worker 服务日志显示成功连接 Redis
- [ ] Worker 服务日志显示 "ready" 状态

## 🎯 总结

**当前状态：**
- ✅ TaskScheduler 正常工作（导入错误已修复）
- ⚠️ Celery Worker 检测不到（但系统已自动回退）

**下一步：**
1. 检查 Worker 服务的日志和环境变量
2. 确保所有服务使用相同的 Redis URL
3. 如果 Worker 正常运行，等待几秒后检查健康状态

