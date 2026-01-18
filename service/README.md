# LinkU Customer Service System

客服系统独立子域名应用 - `service.link2ur.com`

## 项目结构

```
service/
├── public/                    # 静态资源
│   ├── index.html
│   ├── robots.txt
│   └── manifest.json
├── src/
│   ├── api.ts                 # 客服专用 API 客户端
│   ├── App.tsx                # 主应用路由
│   ├── config.ts              # API 配置
│   ├── index.tsx              # 入口文件
│   ├── components/            # 可复用组件
│   │   ├── CustomerServiceRoute.tsx  # 认证路由守卫
│   │   ├── LazyImage.tsx          # 图片懒加载
│   │   ├── NotificationBell.tsx     # 通知铃铛
│   │   └── NotificationModal.tsx    # 通知弹窗
│   ├── pages/                 # 页面组件
│   │   ├── CustomerServiceLogin.tsx # 登录页面
│   │   ├── CustomerService.tsx      # 客服管理主页面
│   │   └── CustomerService.css      # 样式文件
│   ├── styles/                # 全局样式
│   │   └── index.css
│   └── utils/                 # 工具函数
│       ├── errorHandler.ts        # 错误处理
│       └── timeUtils.ts           # 时间处理
├── package.json               # 项目配置
├── tsconfig.json              # TypeScript 配置
├── vercel.json                # Vercel 部署配置
├── env.template               # 环境变量模板
└── README.md                  # 项目文档
```

## 开发环境设置

### 1. 安装依赖

```bash
cd service
npm install
```

### 2. 配置环境变量

复制环境变量模板并配置：

```bash
cp env.template .env.local
```

编辑 `.env.local`：
```env
REACT_APP_API_URL=http://localhost:8000
REACT_APP_WS_URL=ws://localhost:8000
REACT_APP_MAIN_SITE_URL=http://localhost:3000
```

### 3. 启动开发服务器

```bash
npm start
```

开发服务器运行在 http://localhost:3002

## 生产环境部署

### Vercel 部署

1. 在 Vercel 创建新项目
2. 配置以下环境变量：
   - `REACT_APP_API_URL`: `https://api.link2ur.com`
   - `REACT_APP_WS_URL`: `wss://api.link2ur.com`
   - `REACT_APP_MAIN_SITE_URL`: `https://www.link2ur.com`
3. 配置域名为 `service.link2ur.com`
4. 部署

### 手动构建

```bash
npm run build
```

构建产物位于 `build/` 目录。

## 主要功能

### 客服会话管理
- 实时聊天界面
- 消息已读/未读状态
- 会话超时管理
- 会话结束功能

### 任务管理
- 任务取消请求审核
- 任务详情查看
- 任务状态管理

### 后台管理请求
- 提交管理请求
- 与后台工作人员实时聊天
- 请求状态跟踪

### 通知系统
- 实时通知提醒
- 未读消息统计
- 通知历史记录

### 用户管理
- 用户信息查看
- 用户状态管理

## 技术栈

- **框架**: React 18 + TypeScript
- **UI 库**: Ant Design 5
- **路由**: React Router 6
- **HTTP 客户端**: Axios
- **日期处理**: Day.js
- **样式**: CSS Modules

## API 通信

所有 API 请求通过 `src/api.ts` 统一管理，包含：
- CSRF Token 自动管理
- 请求/响应拦截器
- 401 未授权自动刷新 token
- 统一错误处理

## 后端 CORS 配置

后端已配置允许 `service.link2ur.com` 和 `localhost:3002` 的跨域请求。

相关文件：
- `backend/app/config.py` - ALLOWED_ORIGINS
- `backend/app/main.py` - CORS 中间件

## 安全特性

1. **Cookie 认证**: 使用 HttpOnly Cookie 进行身份认证
2. **CSRF 保护**: 所有写操作都需要 CSRF Token
3. **Token 刷新**: 自动刷新过期的认证 token
4. **SEO 禁用**: 配置了 robots.txt 和 meta 标签防止搜索引擎索引

## 注意事项

1. **独立部署**: 此应用与主前端 (`frontend/`) 完全独立，可以单独部署和更新
2. **端口配置**: 开发环境使用端口 3002，避免与主前端 (3000) 和管理后台 (3001) 冲突
3. **环境变量**: 生产环境需要在 Vercel 中配置环境变量
4. **DNS 配置**: 需要在域名服务商配置 CNAME 记录指向 Vercel

## 许可证

私有项目，仅供内部使用。
