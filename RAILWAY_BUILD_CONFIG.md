# Railway 构建配置指南

## 📋 构建器选择

Railway 支持两种构建方式：

### 1. NIXPACKS（推荐）

**优点：**
- ✅ 不需要 Docker Hub 认证
- ✅ 自动检测项目类型
- ✅ 自动优化构建
- ✅ 更快的构建速度
- ✅ 更好的缓存机制
- ✅ 避免 Docker Hub 速率限制

**配置：**
```json
{
  "build": {
    "builder": "NIXPACKS"
  }
}
```

**要求：**
- 项目根目录有 `requirements.txt`（Python 项目）
- NIXPACKS 会自动检测 Python 版本

### 2. Dockerfile

**优点：**
- ✅ 完全控制构建过程
- ✅ 自定义构建步骤

**缺点：**
- ❌ 需要 Docker Hub 认证（避免速率限制）
- ❌ 构建时间较长
- ❌ 需要维护 Dockerfile

**配置：**
```json
{
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "Dockerfile"
  }
}
```

## 🔧 当前配置

项目已配置为使用 **NIXPACKS** 构建器，这样可以：
1. 避免 Docker Hub 速率限制
2. 自动检测和构建 Python 项目
3. 更快的部署速度

## 📝 自定义启动命令

即使使用 NIXPACKS，你仍然可以在 Railway Dashboard 中设置 Custom Start Command：

**App Service：**
```bash
python -m uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --http h11
```

**Celery Beat：**
```bash
celery -A app.celery_app beat --loglevel=info
```

**Celery Worker：**
```bash
celery -A app.celery_app worker --loglevel=info --concurrency=2
```

## ⚠️ 注意事项

1. **Root Directory**：如果使用 NIXPACKS，确保在 Railway Dashboard 中设置正确的 Root Directory（通常是 `backend`）
2. **requirements.txt**：确保 `requirements.txt` 在正确的位置
3. **环境变量**：所有必要的环境变量都需要在 Railway Dashboard 中配置

## 🔄 切换构建器

如果需要切换回 Dockerfile：

1. **修改 `railway.json`**：
   ```json
   {
     "build": {
       "builder": "DOCKERFILE",
       "dockerfilePath": "Dockerfile"
     }
   }
   ```

2. **配置 Docker Hub 认证**（避免速率限制）：
   - Settings → Variables
   - 添加 `DOCKER_USERNAME` 和 `DOCKER_PASSWORD`

