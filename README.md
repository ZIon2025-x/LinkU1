# 前端应用

这是任务管理平台的前端React应用。

## 功能特性

- 用户注册和登录
- 任务发布和管理
- 实时聊天系统
- 客服系统
- 管理员面板
- 响应式设计

## 技术栈

- React 18
- TypeScript
- React Router
- Axios
- WebSocket
- CSS3

## 快速开始

### 本地开发

1. 安装依赖：
```bash
npm install
```

2. 启动开发服务器：
```bash
npm start
```

应用将在 http://localhost:3000 启动

### 构建生产版本

```bash
npm run build
```

### Docker部署

1. 构建镜像：
```bash
docker build -t task-platform-frontend .
```

2. 运行容器：
```bash
docker run -p 3000:80 task-platform-frontend
```

### Docker Compose部署

```bash
docker-compose up -d
```

## 环境变量

- `REACT_APP_API_URL`: 后端API地址
- `REACT_APP_WS_URL`: WebSocket地址

## 部署到生产环境

1. 设置环境变量：
```bash
export REACT_APP_API_URL=https://your-backend-domain.com
export REACT_APP_WS_URL=wss://your-backend-domain.com
```

2. 构建生产版本：
```bash
npm run build
```

3. 部署到Web服务器（Nginx、Apache等）

## 与后端通信

前端通过以下方式与后端通信：
- REST API（通过Axios）
- WebSocket（实时聊天）
- Cookie认证

## 项目结构

```
src/
├── components/     # 可复用组件
├── pages/         # 页面组件
├── config.ts      # 配置文件
├── api.ts         # API客户端
└── App.tsx        # 主应用组件
```