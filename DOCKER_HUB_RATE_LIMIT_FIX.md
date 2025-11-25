# Docker Hub 拉取速率限制解决方案

## 🔴 问题

Railway 构建时遇到 Docker Hub 速率限制：
```
429 Too Many Requests
You have reached your unauthenticated pull rate limit
```

## ✅ 解决方案

### 方案 1：使用 NIXPACKS 构建器（推荐，最简单）

Railway 的 NIXPACKS 构建器不需要拉取 Docker 镜像，会自动检测项目类型并构建。

**步骤：**

1. **修改 `railway.json`**：
   ```json
   {
     "$schema": "https://railway.app/railway.schema.json",
     "build": {
       "builder": "NIXPACKS"
     },
     "deploy": {
       "restartPolicyType": "ON_FAILURE",
       "restartPolicyMaxRetries": 10
     }
   }
   ```

2. **或者在 Railway Dashboard 中：**
   - Settings → Build
   - Builder: 选择 **NIXPACKS**（而不是 Dockerfile）

### 方案 2：配置 Docker Hub 认证

如果必须使用 Dockerfile，可以配置 Docker Hub 认证：

1. **在 Railway Dashboard 中：**
   - Settings → Variables
   - 添加以下环境变量：
     - `DOCKER_USERNAME`: 你的 Docker Hub 用户名
     - `DOCKER_PASSWORD`: 你的 Docker Hub 密码或访问令牌

2. **Railway 会自动使用这些凭证进行认证**

### 方案 3：使用镜像代理（如果 Railway 支持）

某些平台支持配置镜像代理，但 Railway 可能不支持。可以尝试：

1. 在 Railway 中配置环境变量：
   - `DOCKER_REGISTRY_MIRROR`: 镜像代理地址

### 方案 4：等待后重试

Docker Hub 的速率限制是每小时重置的：
- 未认证用户：每 6 小时 100 次拉取
- 认证用户：每 6 小时 200 次拉取

可以等待一段时间后重试。

### 方案 5：使用其他基础镜像源

修改 Dockerfile 使用其他镜像源（需要 Railway 支持）：

```dockerfile
# 使用阿里云镜像（如果 Railway 支持）
FROM registry.cn-hangzhou.aliyuncs.com/library/python:3.11-slim
```

**注意：** Railway 可能不支持自定义镜像源。

## 🎯 推荐方案

**对于 Railway 部署，强烈推荐使用 NIXPACKS：**

1. ✅ 不需要 Docker Hub 认证
2. ✅ 自动检测项目类型
3. ✅ 自动优化构建
4. ✅ 更快的构建速度
5. ✅ 更好的缓存机制

## 📝 实施步骤

### 切换到 NIXPACKS

1. **修改 `railway.json`**：
   ```json
   {
     "$schema": "https://railway.app/railway.schema.json",
     "build": {
       "builder": "NIXPACKS"
     },
     "deploy": {
       "restartPolicyType": "ON_FAILURE",
       "restartPolicyMaxRetries": 10
     }
   }
   ```

2. **或者在 Railway Dashboard 中：**
   - 进入服务
   - Settings → Build
   - Builder: 选择 **NIXPACKS**
   - 保存并重新部署

3. **确保有 `requirements.txt`**：
   - NIXPACKS 会自动检测 Python 项目
   - 自动安装 `requirements.txt` 中的依赖

## ⚠️ 注意事项

- NIXPACKS 会自动检测 Python 版本（从 `requirements.txt` 或 `runtime.txt`）
- 如果使用 NIXPACKS，不需要 Dockerfile
- NIXPACKS 会自动设置启动命令（可以覆盖）

## 🔍 验证

部署后检查日志：
- 应该看到 NIXPACKS 构建日志
- 没有 Docker Hub 速率限制错误
- 构建成功完成

