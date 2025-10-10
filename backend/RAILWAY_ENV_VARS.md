# Railway 环境变量配置指南

## 在线时间获取功能环境变量

### 必需的环境变量

**无需设置** - 系统会自动使用默认配置

### 可选的环境变量

#### 1. 启用/禁用在线时间获取
```bash
ENABLE_ONLINE_TIME=true
```
- **默认值**: `true`
- **说明**: 是否启用在线时间获取功能
- **建议**: 保持 `true` 以获得准确时间

#### 2. API超时时间
```bash
TIME_API_TIMEOUT=3
```
- **默认值**: `3`
- **说明**: 每个API调用的超时时间（秒）
- **建议**: 3-5秒，避免过长的等待

#### 3. 最大重试次数
```bash
TIME_API_MAX_RETRIES=3
```
- **默认值**: `3`
- **说明**: 所有API失败后的重试次数
- **建议**: 3-5次，平衡性能和可靠性

#### 4. 本地时间回退
```bash
FALLBACK_TO_LOCAL_TIME=true
```
- **默认值**: `true`
- **说明**: 所有API失败时是否回退到本地时间
- **建议**: 保持 `true` 确保系统稳定性

#### 5. 自定义时间API（高级）
```bash
CUSTOM_TIME_APIS="MyAPI:https://api.example.com/time,AnotherAPI:https://api2.example.com/time"
```
- **默认值**: 空（使用默认API）
- **说明**: 自定义时间API列表，格式为 "名称:URL,名称:URL"
- **建议**: 仅在需要特定API时使用

## Railway 部署配置

### 1. 在Railway控制台设置环境变量

1. 登录 [Railway](https://railway.app)
2. 选择您的项目
3. 进入 "Variables" 标签页
4. 添加以下环境变量（可选）：

```
ENABLE_ONLINE_TIME=true
TIME_API_TIMEOUT=3
TIME_API_MAX_RETRIES=3
FALLBACK_TO_LOCAL_TIME=true
```

### 2. 使用Railway CLI设置

```bash
# 安装Railway CLI
npm install -g @railway/cli

# 登录
railway login

# 链接项目
railway link

# 设置环境变量
railway variables set ENABLE_ONLINE_TIME=true
railway variables set TIME_API_TIMEOUT=3
railway variables set TIME_API_MAX_RETRIES=3
railway variables set FALLBACK_TO_LOCAL_TIME=true
```

### 3. 使用railway.json配置

在项目根目录创建 `railway.json`：

```json
{
  "deploy": {
    "startCommand": "uvicorn app.main:app --host 0.0.0.0 --port $PORT",
    "healthcheckPath": "/health"
  },
  "variables": {
    "ENABLE_ONLINE_TIME": "true",
    "TIME_API_TIMEOUT": "3",
    "TIME_API_MAX_RETRIES": "3",
    "FALLBACK_TO_LOCAL_TIME": "true"
  }
}
```

## 监控和调试

### 1. 查看日志
```bash
# 使用Railway CLI查看日志
railway logs

# 或在线查看
# 在Railway控制台的 "Deployments" 标签页查看日志
```

### 2. 测试时间获取
```bash
# 在Railway环境中运行测试
railway run python test_online_time.py
```

### 3. 常见问题排查

#### 问题1: 所有API都失败
**症状**: 日志显示 "所有在线时间API都失败，使用本地时间"
**解决方案**:
- 检查网络连接
- 增加超时时间: `TIME_API_TIMEOUT=5`
- 增加重试次数: `TIME_API_MAX_RETRIES=5`

#### 问题2: 时间不准确
**症状**: 显示的时间与英国实际时间不符
**解决方案**:
- 检查服务器时区设置
- 验证API返回的时间格式
- 考虑使用自定义API

#### 问题3: 性能问题
**症状**: 时间获取导致响应缓慢
**解决方案**:
- 减少超时时间: `TIME_API_TIMEOUT=2`
- 减少重试次数: `TIME_API_MAX_RETRIES=2`
- 禁用在线时间: `ENABLE_ONLINE_TIME=false`

## 生产环境建议

### 1. 性能优化
```bash
# 生产环境推荐配置
ENABLE_ONLINE_TIME=true
TIME_API_TIMEOUT=2
TIME_API_MAX_RETRIES=2
FALLBACK_TO_LOCAL_TIME=true
```

### 2. 监控设置
- 监控API调用成功率
- 设置时间获取失败的告警
- 定期检查时间准确性

### 3. 备用方案
- 保持 `FALLBACK_TO_LOCAL_TIME=true`
- 定期同步服务器时间
- 考虑使用NTP服务

## 故障排除

### 1. 检查环境变量
```bash
# 在Railway环境中检查
railway run python -c "import os; print('ENABLE_ONLINE_TIME:', os.getenv('ENABLE_ONLINE_TIME', 'true'))"
```

### 2. 测试网络连接
```bash
# 测试API连接
railway run python -c "import requests; print(requests.get('http://worldtimeapi.org/api/timezone/Europe/London', timeout=5).status_code)"
```

### 3. 查看详细日志
在代码中添加调试信息：
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## 联系支持

如果遇到问题，请提供：
1. Railway项目ID
2. 环境变量配置
3. 相关错误日志
4. 问题复现步骤
