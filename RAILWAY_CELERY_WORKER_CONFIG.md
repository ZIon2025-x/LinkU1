# Railway Celery Worker 配置指南

## 🔴 问题

Railway 从 `railway.json` 文件中读取启动命令，覆盖了手动输入的 Celery Worker 命令。

## ✅ 解决方案

### 方法 1：在 Railway 界面中覆盖（推荐）

在 Railway 的 **Celery Worker 服务**中：

1. **进入 Worker 服务**
2. **点击 Settings → Deploy**
3. **在 Custom Start Command 字段中：**
   - 清空现有内容（如果有）
   - 输入：`celery -A app.celery_app worker --loglevel=info --concurrency=2`
   - **重要**：确保输入框中的命令完全替换了 `railway.json` 中的命令
4. **点击 Save** 保存
5. **确认保存成功**：检查命令是否保持为你输入的 Celery 命令

### 方法 2：使用环境变量覆盖（如果方法1不行）

Railway 支持通过环境变量覆盖启动命令：

1. **进入 Worker 服务**
2. **点击 Variables 标签页**
3. **添加环境变量：**
   - 变量名：`RAILWAY_START_COMMAND`
   - 变量值：`celery -A app.celery_app worker --loglevel=info --concurrency=2`
4. **保存并重新部署**

### 方法 3：使用单独的配置文件（推荐，最可靠）

如果方法1和方法2都不行，使用单独的配置文件：

**步骤 1：创建配置文件**

我已经创建了两个配置文件：
- `backend/railway-worker.json` - Celery Worker 配置
- `backend/railway-beat.json` - Celery Beat 配置

**步骤 2：在 Railway 中配置服务使用不同的配置文件**

#### 对于 Celery Worker 服务：

1. **进入 Worker 服务**
2. **点击 Settings → Source**
3. **找到 "Railway Config File" 或 "Config File" 选项**
4. **设置为：** `railway-worker.json`
5. **保存并重新部署**

#### 对于 Celery Beat 服务：

1. **进入 Beat 服务**
2. **点击 Settings → Source**
3. **找到 "Railway Config File" 或 "Config File" 选项**
4. **设置为：** `railway-beat.json`
5. **保存并重新部署**

**步骤 3：如果找不到 "Railway Config File" 选项**

如果 Railway 界面中没有 "Railway Config File" 选项，可以尝试：

1. **使用启动脚本方式**（见方法4）
2. **或者联系 Railway 支持**，询问如何为不同服务指定不同的配置文件

## 📝 配置步骤详解

### Celery Worker 服务配置

**Custom Start Command：**
```bash
celery -A app.celery_app worker --loglevel=info --concurrency=2
```

**环境变量：**
- `REDIS_URL` - 必须与主服务相同
- `USE_REDIS=true`
- 其他必要的环境变量（从主服务复制）

### Celery Beat 服务配置

**Custom Start Command：**
```bash
celery -A app.celery_app beat --loglevel=info
```

**环境变量：**
- `REDIS_URL` - 必须与主服务相同
- `USE_REDIS=true`
- 其他必要的环境变量（从主服务复制）

## ⚠️ 重要提示

1. **不要使用 `$PORT`**：Celery Worker 和 Beat 不需要端口
2. **确保命令正确**：命令应该是 `celery -A app.celery_app worker ...`，不是 `uvicorn`
3. **保存后验证**：保存后检查命令是否保持为你输入的 Celery 命令
4. **检查日志**：部署后查看日志确认 Worker 是否成功启动

## 🔍 验证配置

### 检查启动命令

1. 进入服务
2. Settings → Deploy
3. 查看 Custom Start Command 字段
4. 确认显示的是 Celery 命令，不是 FastAPI 命令

### 检查日志

Worker 服务日志应该显示：
```
[INFO] celery@xxx ready.
[INFO] Connected to redis://...
```

不应该看到：
```
Error: Invalid value for '--port': '$PORT' is not a valid integer.
Usage: python -m uvicorn [OPTIONS] APP
```

## 🎯 快速修复步骤

1. **进入 Celery Worker 服务**
2. **Settings → Deploy**
3. **Custom Start Command 字段中输入：**
   ```
   celery -A app.celery_app worker --loglevel=info --concurrency=2
   ```
4. **点击 Save**
5. **等待重新部署**
6. **查看 Logs 确认 Worker 启动成功**

### 方法 4：使用启动脚本（如果方法3不行）

如果 Railway 不支持服务特定的配置文件，可以使用启动脚本：

**步骤 1：创建启动脚本**

我已经创建了 `backend/start_celery.sh` 脚本。

**步骤 2：在 Railway 中配置**

#### 对于 Celery Worker 服务：

1. **进入 Worker 服务**
2. **Settings → Deploy → Custom Start Command：**
   ```
   bash start_celery.sh
   ```
3. **Variables → 添加环境变量：**
   - 变量名：`CELERY_TYPE`
   - 变量值：`worker`
4. **保存并重新部署**

#### 对于 Celery Beat 服务：

1. **进入 Beat 服务**
2. **Settings → Deploy → Custom Start Command：**
   ```
   bash start_celery.sh
   ```
3. **Variables → 添加环境变量：**
   - 变量名：`CELERY_TYPE`
   - 变量值：`beat`
4. **保存并重新部署**

**注意：** 确保脚本有执行权限，Railway 通常会自动处理。

## 📚 Railway 配置优先级

Railway 的配置优先级（从高到低）：
1. **界面中的 Custom Start Command**（最高优先级）
2. **环境变量 `RAILWAY_START_COMMAND`**
3. **railway.json 文件中的 startCommand**

**问题：** Railway 可能会在每次部署时重新读取 `railway.json`，覆盖界面设置。

**解决方案：**
- ✅ 使用单独的配置文件（方法3）
- ✅ 使用启动脚本（方法4）
- ✅ 或者修改 `railway.json`，移除 `startCommand`，让每个服务自己配置

