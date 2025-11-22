# Android 应用架构说明

## 📋 应用定位

**LinkU Android 应用是纯用户端应用**，专注于普通用户的功能需求。

### 包含的功能
- ✅ 用户注册/登录
- ✅ 任务浏览、发布、管理
- ✅ 跳蚤市场浏览、发布、管理
- ✅ 实时消息聊天（WebSocket）
- ✅ 个人中心（我的任务、我的发布、钱包）
- ✅ 设置与配置

### 不包含的功能
- ❌ **客服功能** - 仅在 Web 端提供
- ❌ **管理员功能** - 仅在 Web 端提供

## 🏗️ 架构设计

### MVVM 架构

```
UI (Compose)
  ↓
ViewModel (StateFlow)
  ↓
Repository / Service
  ↓
DataSource (API, Local DB)
```

### 目录结构

```
app/src/main/java/com/linku/app/
├── data/                    # 数据层
│   ├── models/              # 数据模型
│   ├── api/                 # API接口
│   └── websocket/           # WebSocket服务
├── ui/                      # UI层
│   ├── screens/             # 屏幕（用户端）
│   │   ├── login/
│   │   ├── home/
│   │   ├── tasks/
│   │   ├── fleamarket/
│   │   ├── message/
│   │   └── profile/         # 个人中心（用户端功能）
│   ├── navigation/           # 导航
│   └── theme/               # 主题
├── viewmodel/               # 视图模型
│   ├── AuthViewModel.kt
│   ├── TasksViewModel.kt
│   └── MessageViewModel.kt
└── utils/                   # 工具类
    └── TokenManager.kt
```

## 🔐 认证流程

1. 用户登录 → 获取 accessToken
2. Token 存储在 DataStore/SharedPreferences 中
3. 自动连接 WebSocket（使用 userId）
4. 所有 API 请求自动携带 Token

## 📡 网络通信

### HTTP API
- 使用 `Retrofit` + `OkHttp`
- 统一错误处理
- 自动 Token 注入

### WebSocket
- 实时消息推送
- 自动重连机制
- 心跳保活

## 🎯 用户端功能模块

### 1. 认证模块
- 登录/注册
- Token 管理
- 自动登录

### 2. 任务模块
- 任务列表（浏览、筛选、搜索）
- 任务详情
- 任务发布
- 我的任务管理

### 3. 跳蚤市场模块
- 商品列表（浏览、筛选、搜索）
- 商品详情
- 商品发布
- 我的发布管理

### 4. 消息模块
- 对话列表
- 实时聊天（WebSocket）
- 消息发送/接收

### 5. 个人中心
- 用户信息
- 我的任务
- 我的发布
- 钱包（待实现）
- 设置

## 🚫 明确不包含的功能

### 客服功能
- 客服登录
- 客服对话管理
- 客服工单系统

**原因**: 客服功能需要复杂的管理界面和权限控制，更适合在 Web 端实现。

### 管理员功能
- 管理员登录
- 用户管理
- 内容审核
- 系统配置

**原因**: 管理员功能需要高级权限和复杂操作，仅在 Web 端提供。

## 📱 与 Web 端的区别

| 功能 | Android 应用 | Web 端 |
|------|------------|--------|
| 用户注册/登录 | ✅ | ✅ |
| 任务浏览/发布 | ✅ | ✅ |
| 跳蚤市场 | ✅ | ✅ |
| 消息聊天 | ✅ | ✅ |
| 个人中心 | ✅ | ✅ |
| 客服功能 | ❌ | ✅ |
| 管理员功能 | ❌ | ✅ |

## 🔄 数据同步

- Android 应用与 Web 端共享同一后端 API
- 数据实时同步（通过 WebSocket）
- 用户可以在 Android 和 Web 端无缝切换

## 📝 开发原则

1. **专注用户端**: 只实现普通用户需要的功能
2. **简洁高效**: 保持应用轻量，专注于核心功能
3. **原生体验**: 充分利用 Android 原生特性
4. **实时通信**: WebSocket 确保消息实时性

