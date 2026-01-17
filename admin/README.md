# LinkU 管理后台

独立的管理后台应用，部署到 `admin.link2ur.com`。

## 快速开始

### 1. 安装依赖

```bash
cd admin
npm install
```

### 2. 启动开发服务器

```bash
npm start
```

应用将在 `http://localhost:3001` 启动（端口与主站 3000 区分）。

### 3. 构建生产版本

```bash
npm run build
```

## 项目结构

```
admin/
├── package.json          # 依赖配置
├── tsconfig.json         # TypeScript 配置
├── vercel.json           # Vercel 部署配置
├── env.template          # 环境变量模板
├── public/
│   ├── index.html        # HTML 入口
│   ├── favicon.ico       # 图标
│   └── manifest.json     # PWA 配置
└── src/
    ├── index.tsx         # 应用入口
    ├── App.tsx           # 路由配置
    ├── api.ts            # API 函数（已完成）
    ├── config.ts         # 配置
    ├── components/
    │   ├── AdminRoute.tsx        # 权限守卫（已完成）
    │   ├── LazyImage.tsx         # 懒加载图片（已完成）
    │   ├── NotificationBell.tsx  # 通知铃铛（已完成）
    │   └── NotificationModal.tsx # 通知弹窗（已完成）
    ├── pages/
    │   ├── AdminLogin.tsx        # 登录页（已完成）
    │   └── AdminDashboard.tsx    # 控制台（骨架版本）
    ├── styles/
    │   ├── index.css             # 全局样式
    │   └── AdminDashboard.module.css  # 控制台样式
    └── utils/
        ├── errorHandler.ts       # 错误处理
        ├── imageCompression.ts   # 图片压缩
        └── formatUtils.ts        # 格式化工具

```

## 待迁移的功能

以下功能需要从 `frontend/src/pages/AdminDashboard.tsx` 迁移：

### 高优先级

- [ ] 用户管理（搜索、查看、编辑、禁用）
- [ ] 管理员管理（添加、删除）
- [ ] 客服管理（添加、删除）
- [ ] 仪表盘统计数据

### 中优先级

- [ ] 任务达人管理
  - 达人列表
  - 申请审核
  - 资料修改审核
  - 服务/活动管理
- [ ] 论坛管理
  - 板块管理
  - 帖子管理
  - 举报处理
- [ ] 跳蚤市场管理
  - 商品管理
  - 举报处理

### 低优先级

- [ ] 邀请码管理
- [ ] Banner 管理
- [ ] 排行榜管理
- [ ] 任务争议处理
- [ ] 岗位管理
- [ ] 系统设置

## 部署

### Vercel 部署

1. 在 Vercel 创建新项目
2. 连接 Git 仓库
3. 设置 Root Directory 为 `admin`
4. 添加自定义域名 `admin.link2ur.com`
5. 配置环境变量：
   - `REACT_APP_API_URL=https://api.link2ur.com`
   - `REACT_APP_WS_URL=wss://api.link2ur.com`
   - `REACT_APP_MAIN_SITE_URL=https://www.link2ur.com`

### DNS 配置

添加 CNAME 记录：
```
admin.link2ur.com -> cname.vercel-dns.com
```

## 开发指南

### 添加新功能模块

1. 在 `src/pages/AdminDashboard.tsx` 的 `menuItems` 中添加菜单项
2. 在 `renderContent()` 函数中添加对应的内容渲染
3. 如需独立页面，在 `src/App.tsx` 中添加路由

### API 调用

所有 API 函数已在 `src/api.ts` 中定义，直接导入使用：

```typescript
import { getDashboardStats, getUsersForAdmin } from '../api';

// 使用
const stats = await getDashboardStats();
const users = await getUsersForAdmin(1, 20, '搜索关键词');
```

### 样式

- 使用 Ant Design 组件库
- CSS Modules 用于页面样式
- 全局样式在 `styles/index.css`

## 安全说明

- 所有页面都需要管理员权限
- Cookie 使用 HttpOnly 和 Secure 标志
- CORS 已配置允许 `admin.link2ur.com`
