# 后端服务

这是任务管理平台的后端API服务。

## 功能特性

- 用户认证和授权
- 任务管理（发布、接受、完成）
- 客服系统
- 管理员功能
- 实时聊天（WebSocket）
- 文件上传
- 通知系统
- **学生认证系统**（新增）
  - 英国大学邮箱验证（.ac.uk）
  - 自动过期和续期
  - 过期提醒邮件（30天、7天、1天前）
  - 性能优化（Aho-Corasick算法）

## 技术栈

- FastAPI
- SQLAlchemy
- SQLite/PostgreSQL
- JWT认证
- WebSocket
- 自动数据库迁移

## 快速开始

### 本地开发

1. 安装依赖：
```bash
pip install -r requirements.txt
```

**重要依赖说明**：
- `pyahocorasick` - 学生认证系统性能优化（可选，推荐）
  - 用于大学匹配缓存优化，性能提升10倍+
  - 如果不安装，系统会自动回退到字典匹配
  - 已在 `requirements.txt` 中，部署时会自动安装

2. 运行数据库迁移：
```bash
python migrate.py
```

3. 启动服务：
```bash
python main.py
```

服务将在 http://localhost:8000 启动

### Docker部署

1. 构建镜像：
```bash
docker build -t task-platform-backend .
```

2. 运行容器：
```bash
docker run -p 8000:8000 task-platform-backend
```

### Docker Compose部署

```bash
docker-compose up -d
```

## 环境变量

- `DATABASE_URL`: 数据库连接字符串
- `SECRET_KEY`: JWT密钥
- `USE_REDIS`: 是否使用Redis（true/false）

## API文档

启动服务后访问：
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 部署到生产环境

1. 修改环境变量
2. 配置数据库（推荐PostgreSQL）
3. 配置反向代理（Nginx）
4. 配置SSL证书
5. 设置监控和日志
