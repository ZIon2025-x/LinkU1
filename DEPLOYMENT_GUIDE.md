# LinkU平台完整部署指南

## 📁 项目结构

```
deployment-package/
├── backend/              # 后端代码 (Railway部署)
│   ├── app/             # FastAPI应用
│   ├── alembic/         # 数据库迁移
│   ├── requirements.txt # Python依赖
│   └── ...
├── frontend/             # 前端代码 (Vercel部署)
│   ├── src/             # React应用
│   ├── public/          # 静态资源
│   ├── package.json     # Node.js依赖
│   └── ...
├── railway.json         # Railway配置
├── vercel.json          # Vercel配置
├── nixpacks.toml        # Railway构建配置
├── docker-compose.yml   # Docker配置
├── requirements.txt     # 根目录依赖
├── env.example          # 环境变量模板
├── railway.env.example  # Railway环境变量模板
└── 部署脚本和说明文档
```

## 🚀 快速部署

### 后端部署 (Railway)

1. **准备代码**：
   ```bash
   cd backend
   ```

2. **在Railway创建项目**：
   - 访问 https://railway.app
   - 创建新项目
   - 连接GitHub仓库或直接上传代码

3. **配置环境变量**：
   参考 `railway.env.example` 文件

4. **添加服务**：
   - PostgreSQL数据库
   - Redis缓存

### 前端部署 (Vercel)

1. **准备代码**：
   ```bash
   cd frontend
   npm install
   npm run build
   ```

2. **在Vercel创建项目**：
   - 访问 https://vercel.com
   - 创建新项目
   - 连接GitHub仓库或直接上传代码

3. **配置环境变量**：
   ```env
   REACT_APP_API_URL=https://your-railway-app.railway.app
   ```

## 🔧 详细配置

### Railway后端配置

**必需环境变量**：
```env
SECRET_KEY=your-super-secure-random-secret-key
DATABASE_URL=postgresql://username:password@host:port/database
REDIS_URL=redis://host:port/0
USE_REDIS=true
COOKIE_SECURE=true
COOKIE_SAMESITE=strict
ALLOWED_ORIGINS=https://your-vercel-app.vercel.app
```

**可选环境变量**：
```env
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=30
COOKIE_DOMAIN=your-domain.com
```

### Vercel前端配置

**必需环境变量**：
```env
REACT_APP_API_URL=https://your-railway-app.railway.app
```

**可选环境变量**：
```env
REACT_APP_WS_URL=wss://your-railway-app.railway.app
```

## 📋 部署检查清单

### 后端部署检查
- [ ] 代码已上传到Railway
- [ ] 环境变量已配置
- [ ] PostgreSQL服务已添加
- [ ] Redis服务已添加
- [ ] 数据库迁移已运行
- [ ] 应用启动成功
- [ ] API端点可访问

### 前端部署检查
- [ ] 代码已上传到Vercel
- [ ] 环境变量已配置
- [ ] 构建成功
- [ ] 前端可访问
- [ ] API调用正常

## 🚨 常见问题解决

### 1. Railway部署失败
**问题**: 找不到模块或依赖
**解决**: 检查requirements.txt和启动命令

### 2. Vercel构建失败
**问题**: 构建错误或依赖问题
**解决**: 检查package.json和构建日志

### 3. API调用失败
**问题**: CORS错误或404错误
**解决**: 检查ALLOWED_ORIGINS和API URL配置

### 4. 数据库连接失败
**问题**: 无法连接PostgreSQL
**解决**: 检查DATABASE_URL环境变量

## 🔄 更新和维护

### 更新后端
1. 修改backend/目录中的代码
2. 提交到GitHub
3. Railway自动重新部署

### 更新前端
1. 修改frontend/目录中的代码
2. 提交到GitHub
3. Vercel自动重新部署

## 📞 技术支持

如果遇到问题，请检查：
1. 环境变量配置是否正确
2. 服务是否正常运行
3. 日志中的错误信息
4. 网络连接是否正常

## 🎯 下一步

1. 完成Railway后端部署
2. 完成Vercel前端部署
3. 配置自定义域名（可选）
4. 设置监控和告警
5. 性能优化和测试
