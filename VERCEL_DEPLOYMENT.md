# Vercel 部署指南

## 📋 概述

本项目使用 Vercel 部署前端，Railway 部署后端。前端和后端分离部署，通过 API 进行通信。

## 🚀 部署步骤

### 1. 准备环境

确保你有以下账户：
- [Vercel](https://vercel.com) 账户
- [GitHub](https://github.com) 账户（用于代码托管）

### 2. 连接 GitHub 仓库

1. 登录 [Vercel Dashboard](https://vercel.com/dashboard)
2. 点击 "New Project"
3. 选择你的 GitHub 仓库 `ZIon2025-x/LinkU1`
4. 点击 "Import"

### 3. 配置项目设置

Vercel 会自动检测到 `vercel.json` 配置文件，但你需要确认以下设置：

#### 构建设置
- **Framework Preset**: Create React App
- **Root Directory**: `frontend` (重要！)
- **Build Command**: `npm run build`
- **Output Directory**: `build`

#### 环境变量
在 Vercel 项目设置中添加以下环境变量：

```bash
REACT_APP_API_URL=https://linku1-production.up.railway.app
REACT_APP_WS_URL=wss://linku1-production.up.railway.app
NODE_ENV=production
```

### 4. 部署

1. 点击 "Deploy" 按钮
2. 等待构建完成
3. 访问生成的 Vercel URL

## 🔧 配置文件说明

### vercel.json
```json
{
  "version": 2,
  "builds": [
    {
      "src": "frontend/package.json",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "build"
      }
    }
  ],
  "routes": [
    {
      "src": "/api/(.*)",
      "dest": "https://linku1-production.up.railway.app/api/$1"
    },
    {
      "src": "/(.*)",
      "dest": "/frontend/$1"
    }
  ],
  "env": {
    "REACT_APP_API_URL": "https://linku1-production.up.railway.app",
    "REACT_APP_WS_URL": "wss://linku1-production.up.railway.app"
  }
}
```

**配置说明：**
- `builds`: 指定从 `frontend/package.json` 构建
- `routes`: API 请求代理到 Railway 后端
- `env`: 设置环境变量

## 🌐 域名配置

### 自定义域名
1. 在 Vercel 项目设置中点击 "Domains"
2. 添加你的自定义域名
3. 配置 DNS 记录

### 子域名
- 生产环境：`https://your-domain.com`
- 预览环境：`https://your-project-git-branch.vercel.app`

## 🔄 自动部署

Vercel 会自动：
- 监听 `main` 分支的推送
- 自动触发重新部署
- 为每个 PR 创建预览环境

## 🐛 故障排除

### 构建失败
1. 检查 `frontend/package.json` 是否存在
2. 确认 Node.js 版本兼容性
3. 查看构建日志中的错误信息

### API 连接问题
1. 确认 `REACT_APP_API_URL` 环境变量正确
2. 检查 Railway 后端是否正常运行
3. 验证 CORS 配置

### 路由问题
1. 确认 `vercel.json` 中的路由配置
2. 检查前端路由是否与 Vercel 路由冲突

## 📊 监控和日志

- **部署日志**: Vercel Dashboard → Functions → View Function Logs
- **性能监控**: Vercel Analytics
- **错误追踪**: Vercel 内置错误监控

## 🔐 安全配置

### 环境变量安全
- 敏感信息使用 Vercel 环境变量
- 不要在前端代码中硬编码 API 密钥

### CORS 配置
后端已配置允许 Vercel 域名的 CORS 请求。

## 📝 更新部署

每次推送代码到 `main` 分支时，Vercel 会自动重新部署。你也可以：

1. 手动触发部署：Vercel Dashboard → Deployments → Redeploy
2. 预览部署：创建 Pull Request 时会自动生成预览链接

## 🆘 支持

如果遇到问题：
1. 查看 Vercel 构建日志
2. 检查 GitHub 仓库状态
3. 确认环境变量配置
4. 验证后端 API 可用性