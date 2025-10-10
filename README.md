# Link²Ur平台完整部署包

这是一个包含前端、后端和所有必要配置文件的完整部署包。

## 📁 目录结构

```
deployment-package/
├── backend/                    # 后端代码 (Railway部署)
│   ├── app/                   # FastAPI应用
│   ├── alembic/              # 数据库迁移
│   ├── requirements.txt      # Python依赖
│   └── ...
├── frontend/                  # 前端代码 (Vercel部署)
│   ├── src/                  # React应用
│   ├── public/               # 静态资源
│   ├── package.json          # Node.js依赖
│   └── ...
├── 配置文件
│   ├── railway.json          # Railway配置
│   ├── vercel.json           # Vercel配置
│   ├── nixpacks.toml         # Railway构建配置
│   └── ...
├── 环境变量模板
│   ├── railway.env.template  # Railway环境变量
│   └── vercel.env.template   # Vercel环境变量
├── 部署脚本
│   ├── deploy-local.bat      # Windows本地部署
│   └── deploy-local.sh       # Linux/Mac本地部署
└── 部署指南
    ├── DEPLOYMENT_GUIDE.md   # 完整部署指南
    ├── RAILWAY_DEPLOYMENT.md # Railway部署指南
    └── VERCEL_DEPLOYMENT.md  # Vercel部署指南
```

## 🚀 快速开始

### 1. 本地测试部署

**Windows用户**：
```bash
# 双击运行
deploy-local.bat
```

**Linux/Mac用户**：
```bash
# 给脚本执行权限
chmod +x deploy-local.sh
# 运行脚本
./deploy-local.sh
```

### 2. 生产环境部署

#### 后端部署到Railway
1. 访问 https://railway.app
2. 创建新项目
3. 上传backend文件夹或连接GitHub
4. 配置环境变量（参考railway.env.template）
5. 添加PostgreSQL和Redis服务

#### 前端部署到Vercel
1. 访问 https://vercel.com
2. 创建新项目
3. 上传frontend文件夹或连接GitHub
4. 配置环境变量（参考vercel.env.template）

## 📋 环境变量配置

### Railway后端环境变量
```env
SECRET_KEY=your-super-secure-random-secret-key
DATABASE_URL=postgresql://username:password@host:port/database
REDIS_URL=redis://host:port/0
USE_REDIS=true
COOKIE_SECURE=true
COOKIE_SAMESITE=strict
ALLOWED_ORIGINS=https://your-vercel-app.vercel.app
```

### Vercel前端环境变量
```env
REACT_APP_API_URL=https://your-railway-app.railway.app
REACT_APP_WS_URL=wss://your-railway-app.railway.app
```

## 🔧 技术栈

### 后端
- **框架**: FastAPI
- **数据库**: PostgreSQL + SQLAlchemy
- **缓存**: Redis
- **认证**: JWT + CSRF
- **部署**: Railway

### 前端
- **框架**: React + TypeScript
- **UI库**: Ant Design
- **路由**: React Router
- **HTTP客户端**: Axios
- **部署**: Vercel

## 📚 详细文档

- [完整部署指南](DEPLOYMENT_GUIDE.md) - 详细的部署步骤和配置说明
- [Railway部署指南](RAILWAY_DEPLOYMENT.md) - 后端部署到Railway的详细步骤
- [Vercel部署指南](VERCEL_DEPLOYMENT.md) - 前端部署到Vercel的详细步骤

## 🚨 常见问题

### 1. 本地部署失败
- 检查Node.js和Python是否正确安装
- 检查端口8000和3000是否被占用
- 查看错误日志进行排查

### 2. Railway部署失败
- 检查环境变量配置
- 查看Railway构建日志
- 确保数据库服务正常运行

### 3. Vercel部署失败
- 检查环境变量配置
- 查看Vercel构建日志
- 确保API URL配置正确

### 4. API调用失败
- 检查CORS配置
- 检查API URL是否正确
- 查看浏览器控制台错误

## 🎯 下一步

1. **完成部署** - 按照指南完成Railway和Vercel部署
2. **配置域名** - 设置自定义域名（可选）
3. **监控设置** - 配置应用监控和告警
4. **性能优化** - 根据使用情况优化性能
5. **安全加固** - 定期更新依赖和检查安全配置

## 📞 技术支持

如果遇到问题，请：
1. 查看相关部署指南
2. 检查环境变量配置
3. 查看服务日志
4. 参考常见问题解决方案

---

**注意**: 这是一个完整的生产就绪部署包，包含了所有必要的配置和文档。请按照指南进行部署，并确保在生产环境中使用强密码和安全配置。
