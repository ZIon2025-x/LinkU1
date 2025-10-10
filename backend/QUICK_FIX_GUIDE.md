# 快速修复指南

## 问题分析

出现500内部服务器错误的原因是：
1. **数据库字段缺失**: `messages`表缺少`created_at_tz`和`local_time`字段
2. **代码查询新字段**: 但数据库还没有这些字段
3. **CORS错误**: 由于500错误导致的连锁反应

## 修复步骤

### 1. 立即修复（已实施）

#### 临时禁用新字段
```python
# 在 models.py 中注释掉新字段
class Message(Base):
    # ...
    created_at = Column(DateTime, default=lambda: datetime.utcnow())
    # 暂时注释掉新字段，避免数据库错误
    # created_at_tz = Column(String(50), default="UTC")
    # local_time = Column(Text, nullable=True)
```

#### 更新CRUD函数
```python
# 在 crud.py 中暂时不使用新字段
msg = Message(
    sender_id=sender_id, 
    receiver_id=receiver_id, 
    content=content,
    created_at=utc_time
    # 暂时注释掉新字段
    # created_at_tz=tz_info,
    # local_time=local_time
)
```

### 2. 添加数据库字段

#### 运行迁移脚本
```bash
# 在Railway环境中运行
railway run python add_message_fields.py

# 或在本地运行
python add_message_fields.py
```

#### 手动添加字段（如果脚本失败）
```sql
-- 连接到数据库
ALTER TABLE messages ADD COLUMN created_at_tz VARCHAR(50) DEFAULT 'UTC';
ALTER TABLE messages ADD COLUMN local_time TEXT;

-- 更新现有数据
UPDATE messages SET created_at_tz = 'Europe/London (Legacy)' WHERE created_at_tz IS NULL;
```

### 3. 重新启用新字段

#### 更新模型
```python
# 在 models.py 中重新启用字段
class Message(Base):
    # ...
    created_at = Column(DateTime, default=lambda: datetime.utcnow())
    created_at_tz = Column(String(50), default="UTC")  # 重新启用
    local_time = Column(Text, nullable=True)  # 重新启用
```

#### 更新CRUD函数
```python
# 在 crud.py 中重新启用字段
msg = Message(
    sender_id=sender_id, 
    receiver_id=receiver_id, 
    content=content,
    created_at=utc_time,
    created_at_tz=tz_info,  # 重新启用
    local_time=local_time   # 重新启用
)
```

## 验证修复

### 1. 检查API状态
```bash
# 检查健康状态
curl https://api.link2ur.com/health

# 检查时间API
curl https://api.link2ur.com/health/time-check/simple
```

### 2. 检查数据库
```sql
-- 检查messages表结构
\d messages

-- 检查字段是否存在
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'messages';
```

### 3. 测试消息发送
1. 打开前端应用
2. 尝试发送消息
3. 检查是否还有500错误
4. 检查CORS错误是否消失

## 故障排除

### 如果仍然有500错误

#### 检查数据库连接
```python
# 测试数据库连接
from sqlalchemy import create_engine, text
engine = create_engine(DATABASE_URL)
with engine.connect() as conn:
    result = conn.execute(text("SELECT 1"))
    print("数据库连接正常")
```

#### 检查字段是否存在
```python
# 检查字段是否存在
from sqlalchemy import inspect
inspector = inspect(engine)
columns = inspector.get_columns('messages')
column_names = [col['name'] for col in columns]
print(f"messages表字段: {column_names}")
```

### 如果CORS错误持续

#### 检查CORS配置
```python
# 在 main.py 中检查CORS配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://www.link2ur.com"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

#### 检查中间件顺序
```python
# 确保CORS中间件在其他中间件之前
app.add_middleware(CORSMiddleware, ...)  # 第一个
app.add_middleware(其他中间件, ...)      # 其他中间件
```

## 部署建议

### 1. 分阶段部署
1. **阶段1**: 部署修复代码（禁用新字段）
2. **阶段2**: 运行数据库迁移
3. **阶段3**: 重新启用新字段

### 2. 回滚计划
如果出现问题，可以：
1. 回滚到修复前的代码
2. 删除新添加的字段
3. 恢复原有功能

### 3. 监控
部署后监控：
- API响应状态
- 数据库查询性能
- 错误日志
- 用户反馈

## 总结

通过分阶段修复，我们确保了：
1. **立即修复**: 500错误消失
2. **功能恢复**: 消息发送正常工作
3. **渐进升级**: 逐步添加新功能
4. **风险控制**: 可以随时回滚

现在系统应该可以正常工作了！
