# Vercel前端部署指南

## 🚀 部署步骤

### 1. 准备代码
确保frontend目录包含所有必要文件：
- src/ (React应用源码)
- public/ (静态资源)
- package.json (Node.js依赖)
- vercel.json (Vercel配置)

### 2. 创建Vercel项目
1. 访问 https://vercel.com
2. 点击 "New Project"
3. 选择 "Import Git Repository" 或 "Browse All Templates"
4. 如果选择GitHub，连接你的仓库
5. 选择frontend目录作为根目录

### 3. 配置环境变量
在Vercel控制台的Environment Variables标签页添加：

```env
REACT_APP_API_URL=https://your-railway-app.railway.app
REACT_APP_WS_URL=wss://your-railway-app.railway.app
```

### 4. 配置构建设置
- **Framework Preset**: Create React App
- **Root Directory**: frontend
- **Build Command**: npm run build
- **Output Directory**: build

### 5. 部署
1. 点击 "Deploy" 开始部署
2. 等待构建完成
3. 检查部署日志确保没有错误

### 6. 测试部署
1. 访问提供的Vercel URL
2. 测试登录功能
3. 测试API调用

## 🔧 配置说明

### vercel.json
```json
{
  "version": 2,
  "builds": [
    {
      "src": "package.json",
      "use": "@vercel/static-build",
      "config": {
        "distDir": "build"
      }
    }
  ],
  "routes": [
    {
      "src": "/api/(.*)",
      "dest": "https://your-railway-app.railway.app/api/$1"
    },
    {
      "src": "/(.*)",
      "dest": "/$1"
    }
  ],
  "env": {
    "REACT_APP_API_URL": "https://your-railway-app.railway.app"
  }
}
```

### package.json
确保包含正确的脚本：
```json
{
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  }
}
```

## 🚨 故障排除

### 常见错误
1. **Build failed**: 检查package.json和依赖
2. **API calls failed**: 检查REACT_APP_API_URL
3. **CORS error**: 检查后端ALLOWED_ORIGINS
4. **404 on refresh**: 检查路由配置

### 查看日志
1. 在Vercel控制台点击Deployments
2. 选择最新的部署
3. 查看Function Logs和Build Logs

### 重新部署
1. 在Vercel控制台点击Deployments
2. 点击 "Redeploy" 重新部署

## 🔄 自动部署

### GitHub集成
1. 连接GitHub仓库
2. 选择frontend目录
3. 每次push到main分支自动部署

### 手动部署
1. 在Vercel控制台点击 "Deploy"
2. 选择要部署的提交
3. 等待部署完成
