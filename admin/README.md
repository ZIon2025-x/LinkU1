# LinkU Admin Dashboard

独立的管理后台应用，部署在 `admin.link2ur.com` 子域名下。

## 项目结构

```
admin/
├── public/                    # 静态资源
│   ├── index.html
│   ├── favicon.ico
│   └── manifest.json
├── src/
│   ├── api.ts                 # 管理员专用 API 客户端
│   ├── App.tsx                # 主应用路由
│   ├── config.ts              # API 配置
│   ├── index.tsx              # 入口文件
│   ├── components/            # 可复用组件
│   │   ├── AdminRoute.tsx         # 认证路由守卫
│   │   ├── CustomerServiceManagement.tsx  # 客服管理
│   │   ├── LazyImage.tsx          # 图片懒加载
│   │   ├── NotificationBell.tsx   # 通知铃铛
│   │   ├── NotificationModal.tsx  # 通知弹窗
│   │   ├── SystemSettings.tsx     # 系统设置
│   │   └── TaskManagement.tsx     # 任务管理
│   ├── pages/                 # 页面组件
│   │   ├── AdminLogin.tsx         # 登录页面
│   │   ├── AdminDashboard.tsx     # 管理仪表盘（主页面）
│   │   └── JobPositionManagement.tsx  # 岗位管理
│   ├── styles/                # 样式文件
│   │   ├── index.css              # 全局样式
│   │   └── AdminDashboard.module.css  # 仪表盘模块样式
│   └── utils/                 # 工具函数
│       ├── errorHandler.ts        # 错误处理
│       ├── formatUtils.ts         # 格式化工具
│       ├── imageCompression.ts    # 图片压缩
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
cd admin
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

开发服务器运行在 http://localhost:3001

## 生产环境部署

### Vercel 部署

1. 在 Vercel 创建新项目
2. 配置以下环境变量：
   - `REACT_APP_API_URL`: `https://api.link2ur.com`
   - `REACT_APP_WS_URL`: `wss://api.link2ur.com`
   - `REACT_APP_MAIN_SITE_URL`: `https://www.link2ur.com`
3. 配置域名为 `admin.link2ur.com`
4. 部署

### 手动构建

```bash
npm run build
```

构建产物位于 `build/` 目录。

## 主要功能

### 仪表盘
- 数据概览（用户数、任务数、收入等统计）
- 一键清理已完成任务文件

### 用户管理
- 用户列表与搜索
- 用户等级调整（普通/VIP/超级VIP）
- 用户封禁/暂停操作

### 人员管理
- 管理员账号管理
- 客服账号管理
- 发送提醒通知

### 任务管理
- 任务列表与筛选
- 任务详情查看与编辑
- 批量操作（更新/删除）

### 任务达人管理
- 达人列表管理
- 申请审核
- 信息修改请求审核
- 服务和活动管理

### 邀请码管理
- 创建/编辑/删除邀请码
- 设置奖励类型和数量
- 状态筛选

### 论坛管理
- 板块管理
- 帖子管理
- 板块申请审核
- 举报处理

### 跳蚤市场管理
- 商品管理
- 举报处理

### Banner 管理
- Banner 创建/编辑/删除
- 排序和状态控制

### 排行榜管理
- 投票记录查看
- 榜单审核
- 竞品管理

### 争议处理
- 争议列表查看
- 争议处理（解决/驳回）

### 系统设置
- VIP 功能控制
- 自动升级阈值
- 积分设置
- 会员权益描述

### 岗位管理
- 招聘岗位的 CRUD
- 岗位状态切换

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
- 401 未授权自动跳转登录页

## 后端 CORS 配置

后端已配置允许 `admin.link2ur.com` 和 `localhost:3001` 的跨域请求。

相关文件：
- `backend/app/config.py` - ALLOWED_ORIGINS
- `backend/app/main.py` - CORS 中间件

## 注意事项

1. **Cookie 域名**: 生产环境使用 `.link2ur.com` 作为 Cookie 域，确保主站和管理后台共享认证状态
2. **安全性**: 只有管理员账号才能访问此应用
3. **独立部署**: 此应用与主前端 (`frontend/`) 完全独立，可以单独部署和更新

## 从主前端移除管理员路由

迁移完成后，可以考虑从主前端 (`frontend/src/App.tsx`) 移除以下路由：
- `/admin/login`
- `/admin`
- `/admin/auth`

以及相关组件：
- `frontend/src/pages/AdminDashboard.tsx`
- `frontend/src/pages/AdminLogin.tsx`
- `frontend/src/components/AdminRoute.tsx`
- 等

这将减少主前端的包大小和复杂度。

## 许可证

私有项目，仅供内部使用。
