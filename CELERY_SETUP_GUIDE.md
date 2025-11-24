# Celery 任务队列设置指南

## 📋 概述

本项目已迁移到 Celery 任务队列系统，用于执行定时任务。Celery 提供了更好的任务管理、监控和扩展能力。

## 🚀 快速开始

### 1. 环境要求

- Python 3.8+
- Redis（作为消息代理）
- Celery 5.3.0+

### 2. 安装依赖

```bash
pip install -r requirements.txt
```

依赖已包含：
- `celery[redis]>=5.3.0`
- `redis>=4.5.0`

### 3. 配置环境变量

确保设置了以下环境变量：

```bash
REDIS_URL=redis://localhost:6379/0
USE_REDIS=true
```

### 4. 启动服务

#### 方式一：使用 Celery（推荐）

**启动 FastAPI 应用：**
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

**启动 Celery Worker（新终端）：**
```bash
celery -A app.celery_app worker --loglevel=info
```

**启动 Celery Beat（新终端）：**
```bash
celery -A app.celery_app beat --loglevel=info
```

#### 方式二：回退到 TaskScheduler（如果 Celery 不可用）

如果 Redis 不可用或 Celery 未安装，系统会自动回退到 TaskScheduler（线程调度器），无需额外配置。

## 📊 定时任务列表

### 高频任务（30秒-1分钟）

| 任务名称 | 频率 | 说明 |
|---------|------|------|
| `process-customer-service-queue` | 30秒 | 处理客服排队 |
| `auto-end-timeout-chats` | 30秒 | 自动结束超时对话 |
| `send-timeout-warnings` | 30秒 | 发送超时预警 |
| `cancel-expired-tasks` | 1分钟 | 取消过期任务 |

### 中频任务（5分钟）

| 任务名称 | 频率 | 说明 |
|---------|------|------|
| `check-expired-coupons` | 5分钟 | 检查过期优惠券 |
| `check-expired-invitation-codes` | 5分钟 | 检查过期邀请码 |
| `check-expired-points` | 5分钟 | 检查过期积分 |
| `check-and-end-activities` | 5分钟 | 检查并结束活动 |

### 低频任务（10分钟）

| 任务名称 | 频率 | 说明 |
|---------|------|------|
| `update-all-users-statistics` | 10分钟 | 更新所有用户统计信息 |

### 每日任务

| 任务名称 | 执行时间 | 说明 |
|---------|---------|------|
| `cleanup-long-inactive-chats` | 每天凌晨2点 | 清理长期无活动对话 |
| `update-featured-task-experts-response-time` | 每天凌晨3点 | 更新特征任务达人的响应时间 |

## 🔍 监控和调试

### 检查 Celery Worker 状态

```bash
# 查看活跃的 Worker
celery -A app.celery_app inspect active

# 查看注册的任务
celery -A app.celery_app inspect registered

# 查看 Worker 统计信息
celery -A app.celery_app inspect stats
```

### 健康检查端点

访问 `/health` 端点可以查看 Celery Worker 状态：

```bash
curl http://localhost:8000/health
```

响应示例：
```json
{
  "status": "healthy",
  "checks": {
    "database": "ok",
    "redis": "ok",
    "celery_worker": "ok (1 workers)"
  }
}
```

### Prometheus 指标

访问 `/metrics` 端点可以查看 Prometheus 格式的指标：

```bash
curl http://localhost:8000/metrics
```

## 🛠️ 故障排除

### 问题1：Celery Worker 未启动

**症状**：健康检查显示 `celery_worker: "no active workers"`

**解决方案**：
1. 检查 Redis 是否运行：`redis-cli ping`
2. 启动 Celery Worker：`celery -A app.celery_app worker --loglevel=info`
3. 检查日志中的错误信息

### 问题2：任务未执行

**症状**：定时任务没有按预期执行

**解决方案**：
1. 确认 Celery Beat 已启动
2. 检查 `celery_app.conf.beat_schedule` 配置
3. 查看 Celery Worker 日志

### 问题3：Redis 连接失败

**症状**：系统回退到 TaskScheduler

**解决方案**：
1. 检查 `REDIS_URL` 环境变量
2. 确认 Redis 服务正在运行
3. 测试连接：`redis-cli -u $REDIS_URL ping`

## 📝 开发建议

### 添加新任务

1. 在 `backend/app/celery_tasks.py` 中添加任务函数
2. 使用 `@celery_app.task` 装饰器
3. 在 `backend/app/celery_app.py` 的 `beat_schedule` 中注册

示例：
```python
@celery_app.task(name='app.celery_tasks.my_new_task', bind=True)
def my_new_task(self):
    """我的新任务"""
    # 任务逻辑
    return {"status": "success"}
```

然后在 `celery_app.py` 中：
```python
celery_app.conf.beat_schedule = {
    # ... 其他任务
    'my-new-task': {
        'task': 'app.celery_tasks.my_new_task',
        'schedule': 300.0,  # 5分钟
    },
}
```

## 🔄 回退机制

系统实现了智能回退机制：

1. **优先使用 Celery**：如果 Redis 可用且 Celery 已安装，使用 Celery
2. **自动回退**：如果 Celery 不可用，自动使用 TaskScheduler
3. **无缝切换**：回退过程对用户透明，无需手动配置

## 📚 相关文档

- [Celery 官方文档](https://docs.celeryproject.org/)
- [Redis 官方文档](https://redis.io/docs/)
- [日志分析与优化文档](./LOG_ANALYSIS_AND_OPTIMIZATION.md)

