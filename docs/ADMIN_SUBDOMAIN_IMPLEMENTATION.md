# 管理后台子域名拆分方案

## 概述

将管理后台从主应用中分离，部署到独立子域名 `admin.link2ur.com`。

**目标架构：**
```
www.link2ur.com      → 用户端 React 应用
admin.link2ur.com    → 管理后台 React 应用
api.link2ur.com      → 后端 API（不变）
```

---

## 一、项目结构

### 1.1 新建管理后台目录

```
LinkU1/
├── frontend/                    # 用户端应用（已有）
├── admin/                       # 管理后台应用（新建）
│   ├── package.json
│   ├── tsconfig.json
│   ├── vercel.json
│   ├── public/
│   │   ├── index.html
│   │   ├── favicon.ico
│   │   └── manifest.json
│   └── src/
│       ├── index.tsx
│       ├── App.tsx
│       ├── api.ts               # 管理员专用 API
│       ├── config.ts
│       ├── pages/
│       │   ├── AdminLogin.tsx
│       │   ├── AdminDashboard.tsx
│       │   └── JobPositionManagement.tsx
│       ├── components/
│       │   ├── AdminRoute.tsx
│       │   ├── AdminAuth.tsx
│       │   ├── TaskManagement.tsx
│       │   ├── CustomerServiceManagement.tsx
│       │   ├── SystemSettings.tsx
│       │   └── NotificationBell.tsx
│       ├── styles/
│       │   └── AdminDashboard.module.css
│       ├── contexts/
│       │   └── AdminAuthContext.tsx
│       └── utils/
│           ├── errorHandler.ts
│           ├── imageCompression.ts
│           └── formatUtils.ts
└── backend/                     # 后端（需更新 CORS）
```

---

## 二、需要迁移的文件清单

### 2.1 页面组件（Pages）

| 源文件 | 目标路径 | 说明 |
|--------|----------|------|
| `frontend/src/pages/AdminLogin.tsx` | `admin/src/pages/AdminLogin.tsx` | 管理员登录页 |
| `frontend/src/pages/AdminDashboard.tsx` | `admin/src/pages/AdminDashboard.tsx` | 主控制台 (10000+ 行) |
| `frontend/src/pages/AdminDashboard.module.css` | `admin/src/styles/AdminDashboard.module.css` | 样式文件 |
| `frontend/src/pages/JobPositionManagement.tsx` | `admin/src/pages/JobPositionManagement.tsx` | 职位管理 |

### 2.2 业务组件（Components）

| 源文件 | 目标路径 | 说明 |
|--------|----------|------|
| `frontend/src/components/AdminRoute.tsx` | `admin/src/components/AdminRoute.tsx` | 权限路由守卫 |
| `frontend/src/components/AdminAuth.tsx` | `admin/src/components/AdminAuth.tsx` | 管理员认证 |
| `frontend/src/components/AdminLoginWithVerification.tsx` | `admin/src/components/AdminLoginWithVerification.tsx` | 带验证的登录 |
| `frontend/src/components/TaskManagement.tsx` | `admin/src/components/TaskManagement.tsx` | 任务管理 |
| `frontend/src/components/CustomerServiceManagement.tsx` | `admin/src/components/CustomerServiceManagement.tsx` | 客服管理 |
| `frontend/src/components/SystemSettings.tsx` | `admin/src/components/SystemSettings.tsx` | 系统设置 |
| `frontend/src/components/NotificationBell.tsx` | `admin/src/components/NotificationBell.tsx` | 通知铃铛 |
| `frontend/src/components/NotificationModal.tsx` | `admin/src/components/NotificationModal.tsx` | 通知弹窗 |
| `frontend/src/components/LazyImage.tsx` | `admin/src/components/LazyImage.tsx` | 懒加载图片 |

### 2.3 工具函数（Utils）

从 `frontend/src/utils/` 复制以下文件：

- `errorHandler.ts` - 错误处理
- `imageCompression.ts` - 图片压缩
- `formatUtils.ts` - 格式化工具
- `timeUtils.ts` - 时间工具

### 2.4 API 提取

从 `frontend/src/api.ts` 中提取管理员相关的 API 函数（约 80+ 个函数）：

**核心 API 函数列表：**

```typescript
// 认证相关
- adminLogout
- getCSRFToken

// 用户管理
- getDashboardStats
- getUsersForAdmin
- updateUserByAdmin

// 管理员管理
- createAdminUser
- deleteAdminUser
- getAdminUsersForAdmin

// 客服管理
- createCustomerService
- deleteCustomerService
- getCustomerServicesForAdmin

// 通知管理
- sendAdminNotification
- notifyCustomerService
- sendStaffNotification

// 任务达人管理
- getTaskExperts
- getTaskExpertForAdmin
- createTaskExpert
- updateTaskExpert
- deleteTaskExpert
- getTaskExpertApplications
- reviewTaskExpertApplication
- createExpertFromApplication
- getProfileUpdateRequests
- reviewProfileUpdateRequest
- getExpertServicesAdmin
- updateExpertServiceAdmin
- deleteExpertServiceAdmin
- getExpertActivitiesAdmin
- updateExpertActivityAdmin
- deleteExpertActivityAdmin

// 邀请码管理
- createInvitationCode
- getInvitationCodes
- getInvitationCodeDetail
- updateInvitationCode
- deleteInvitationCode

// 论坛管理
- getForumCategories
- createForumCategory
- updateForumCategory
- deleteForumCategory
- getCategoryRequests
- reviewCategoryRequest
- getForumPosts
- getForumPost
- createForumPost
- updateForumPost
- deleteForumPost
- pinForumPost / unpinForumPost
- featureForumPost / unfeatureForumPost
- lockForumPost / unlockForumPost
- restoreForumPost
- hideForumPost / unhideForumPost
- getForumReports
- processForumReport
- getForumReplies
- createForumReply

// 跳蚤市场管理
- getFleaMarketReports
- processFleaMarketReport
- getFleaMarketItemsAdmin
- updateFleaMarketItemAdmin
- deleteFleaMarketItemAdmin

// 排行榜管理
- getLeaderboardVotesAdmin
- getCustomLeaderboardsAdmin
- reviewCustomLeaderboard
- getLeaderboardItemsAdmin
- deleteLeaderboardItemAdmin

// Banner 管理
- getBannersAdmin
- getBannerDetailAdmin
- createBanner
- updateBanner
- deleteBanner
- toggleBannerStatus
- batchDeleteBanners
- batchUpdateBannerOrder
- uploadBannerImage

// 争议处理
- getAdminTaskDisputes
- getAdminTaskDisputeDetail
- resolveTaskDispute
- dismissTaskDispute
```

---

## 三、配置文件

### 3.1 admin/package.json

```json
{
  "name": "linku-admin",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@tanstack/react-query": "^5.90.7",
    "antd": "^5.26.6",
    "axios": "^1.10.0",
    "browser-image-compression": "^2.0.2",
    "dayjs": "^1.11.13",
    "dompurify": "^3.3.0",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.30.1",
    "react-scripts": "5.0.1",
    "typescript": "^4.9.5"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test"
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
```

### 3.2 admin/src/config.ts

```typescript
// API 配置
const isProduction = process.env.NODE_ENV === 'production';

export const API_BASE_URL = isProduction 
  ? process.env.REACT_APP_API_URL || 'https://api.link2ur.com'
  : 'http://localhost:8000';

export const MAIN_SITE_URL = isProduction
  ? 'https://www.link2ur.com'
  : 'http://localhost:3000';

// 管理员专用端点
export const API_ENDPOINTS = {
  ADMIN_LOGIN: '/api/admin/login',
  ADMIN_REFRESH: '/api/admin/refresh',
  ADMIN_PROFILE: '/api/auth/admin/profile',
  ADMIN_LOGOUT: '/api/admin/logout',
  
  // 仪表盘
  DASHBOARD_STATS: '/api/admin/dashboard/stats',
  
  // 用户管理
  USERS: '/api/admin/users',
  
  // 其他管理端点...
} as const;
```

### 3.3 admin/vercel.json

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
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        },
        {
          "key": "X-XSS-Protection",
          "value": "1; mode=block"
        },
        {
          "key": "Content-Security-Policy",
          "value": "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' https://api.link2ur.com data: blob:; connect-src 'self' https://api.link2ur.com wss://api.link2ur.com"
        }
      ]
    }
  ],
  "rewrites": [
    {
      "source": "/api/(.*)",
      "destination": "https://api.link2ur.com/api/$1"
    },
    {
      "source": "/uploads/(.*)",
      "destination": "https://api.link2ur.com/uploads/$1"
    },
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ],
  "env": {
    "REACT_APP_API_URL": "https://api.link2ur.com",
    "REACT_APP_MAIN_SITE_URL": "https://www.link2ur.com"
  }
}
```

---

## 四、后端 CORS 配置更新

### 4.1 更新 backend/app/config.py

```python
# CORS配置 - 安全配置
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
IS_PRODUCTION = ENVIRONMENT == "production"

if IS_PRODUCTION:
    # 生产环境：允许主站和管理后台
    ALLOWED_ORIGINS = os.getenv(
        "ALLOWED_ORIGINS", 
        "https://www.link2ur.com,https://link2ur.com,https://admin.link2ur.com"
    ).split(",")
else:
    # 开发环境：允许本地开发服务器
    ALLOWED_ORIGINS = os.getenv(
        "ALLOWED_ORIGINS", 
        "http://localhost:3000,http://localhost:3001,http://localhost:8080,http://127.0.0.1:3000"
    ).split(",")
```

### 4.2 更新 backend/app/main.py 中的 CORS 中间件

```python
@app.middleware("http")
async def custom_cors_middleware(request: Request, call_next):
    """自定义CORS中间件，覆盖Railway默认设置"""
    origin = request.headers.get("origin")
    allowed_domains = [
        "https://link-u1", 
        "http://localhost", 
        "https://www.link2ur.com", 
        "https://link2ur.com",
        "https://admin.link2ur.com",  # 新增：管理后台
        "https://api.link2ur.com"
    ]
    # ... 其余代码不变
```

### 4.3 Cookie Domain 配置

确保管理员 Session Cookie 可以跨子域名共享：

```python
# backend/app/admin_auth_routes.py 或相关认证文件

# 设置 Cookie 时使用根域名
response.set_cookie(
    key="admin_session",
    value=session_token,
    httponly=True,
    secure=True,
    samesite="lax",
    domain=".link2ur.com",  # 注意前面的点，允许所有子域名访问
    max_age=3600 * 24 * 7  # 7 天
)
```

---

## 五、从主应用中移除管理员代码

### 5.1 更新 frontend/src/App.tsx

移除管理员相关的路由：

```tsx
// 移除这些 import
// import AdminRoute from './components/AdminRoute';
// import AdminAuth from './components/AdminAuth';
// import { AdminGuard } from './components/AuthGuard';

// 移除这些懒加载
// const AdminDashboard = lazy(() => import('./pages/AdminDashboard'));
// const AdminLogin = lazy(() => import('./pages/AdminLogin'));

// 移除这些路由
// <Route path={`/${lang}/admin/login`} element={<AdminLogin />} />
// <Route path={`/${lang}/admin/auth`} element={...} />
// <Route path={`/${lang}/admin`} element={...} />

// 可选：添加重定向到新管理后台
<Route path={`/${lang}/admin/*`} element={
  <Navigate to="https://admin.link2ur.com" replace />
} />
```

### 5.2 从 frontend/src/api.ts 中移除管理员 API

移除所有 `ForAdmin` 后缀的函数和管理员专用 API，可以减少约 1000+ 行代码。

### 5.3 删除不再需要的文件

```bash
# 从 frontend 中删除
rm frontend/src/pages/AdminDashboard.tsx
rm frontend/src/pages/AdminDashboard.module.css
rm frontend/src/pages/AdminLogin.tsx
rm frontend/src/components/AdminRoute.tsx
rm frontend/src/components/AdminAuth.tsx
rm frontend/src/components/AdminLoginWithVerification.tsx
# ... 其他管理员专用组件
```

---

## 六、部署步骤

### 6.1 Vercel 部署（推荐）

1. **创建新项目**
   - 在 Vercel 中创建新项目
   - 连接到同一个 Git 仓库
   - 设置 Root Directory 为 `admin`

2. **配置域名**
   - 添加自定义域名 `admin.link2ur.com`
   - 配置 DNS CNAME 记录指向 Vercel

3. **环境变量**
   ```
   REACT_APP_API_URL=https://api.link2ur.com
   REACT_APP_MAIN_SITE_URL=https://www.link2ur.com
   NODE_ENV=production
   ```

### 6.2 Railway 部署（如果使用）

在 `railway.json` 中添加新服务配置，或创建独立的服务。

---

## 七、安全加固建议

### 7.1 IP 白名单

在 Cloudflare 或 Vercel 层面配置 IP 白名单，只允许特定 IP 访问 `admin.link2ur.com`。

### 7.2 二次认证

考虑为管理后台添加：
- Google Authenticator / TOTP
- 硬件密钥 (WebAuthn)
- 邮件验证码

### 7.3 访问日志

确保所有管理员操作都有完整的审计日志。

---

## 八、实施时间线

| 阶段 | 任务 | 预计时间 |
|------|------|----------|
| 1 | 创建 admin 目录结构 | 0.5 天 |
| 2 | 迁移页面和组件 | 1 天 |
| 3 | 提取 API 函数 | 0.5 天 |
| 4 | 更新后端 CORS | 0.5 天 |
| 5 | 本地测试 | 1 天 |
| 6 | 部署到 Vercel | 0.5 天 |
| 7 | 从主应用清理代码 | 1 天 |
| **总计** | | **5 天** |

---

## 九、预期收益

| 指标 | 预期改善 |
|------|----------|
| **主站打包体积** | 减少 30-40% (移除 AdminDashboard 10000+ 行) |
| **首屏加载时间** | 减少 0.5-1s |
| **安全性** | 独立的 Cookie 作用域，减少攻击面 |
| **维护性** | 管理后台可独立迭代，不影响用户端 |
| **扩展性** | 可以为管理后台使用不同的技术栈或 CDN 策略 |

---

## 十、回滚方案

如果新方案出现问题，可以快速回滚：

1. 将 `admin.link2ur.com` DNS 指向主站
2. 在主站恢复管理员路由
3. 从 Git 历史恢复被删除的文件

建议保留原代码 30 天后再完全删除。
