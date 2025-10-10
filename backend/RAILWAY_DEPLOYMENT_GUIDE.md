# Railway 部署指南 - 在线时间功能

## 快速开始

### 1. 无需额外配置
**好消息！** 在线时间获取功能在Railway上开箱即用，无需设置任何环境变量。

### 2. 部署步骤
1. 将代码推送到GitHub
2. 在Railway中连接GitHub仓库
3. Railway会自动检测Python项目并部署
4. 系统会自动使用在线时间API获取准确的英国时间

## 可选配置

如果您想自定义配置，可以在Railway控制台添加以下环境变量：

### 基本配置
```bash
# 启用在线时间获取（默认：true）
ENABLE_ONLINE_TIME=true

# API超时时间，秒（默认：3）
TIME_API_TIMEOUT=3

# 最大重试次数（默认：3）
TIME_API_MAX_RETRIES=3

# 失败时回退到本地时间（默认：true）
FALLBACK_TO_LOCAL_TIME=true
```

### 高级配置
```bash
# 自定义时间API（可选）
CUSTOM_TIME_APIS="MyAPI:https://api.example.com/time"
```

## 验证部署

### 1. 检查日志
在Railway控制台查看部署日志，应该看到类似信息：
```
尝试使用 WorldTimeAPI 获取英国时间...
成功从 WorldTimeAPI 获取英国时间: 2024-01-15 14:30:25+00:00
```

### 2. 运行检查脚本
```bash
# 在Railway环境中运行
railway run python check_railway_deployment.py
```

### 3. 测试API端点
访问您的API健康检查端点，确认服务正常运行。

## 故障排除

### 问题1: 时间不准确
**原因**: 网络API可能失败，回退到本地时间
**解决**: 
- 检查Railway日志
- 确认网络连接正常
- 系统会自动重试

### 问题2: 部署失败
**原因**: 缺少依赖
**解决**:
- 确保 `requirements.txt` 包含 `requests>=2.31.0`
- 检查Python版本兼容性

### 问题3: 性能问题
**原因**: API调用超时
**解决**:
- 设置 `TIME_API_TIMEOUT=2` 减少超时时间
- 设置 `TIME_API_MAX_RETRIES=2` 减少重试次数

## 监控建议

### 1. 日志监控
- 监控API调用成功率
- 关注时间获取失败的日志

### 2. 性能监控
- 监控API响应时间
- 设置告警当所有API都失败时

### 3. 准确性检查
- 定期验证时间准确性
- 对比不同API返回的时间

## 生产环境优化

### 1. 推荐配置
```bash
ENABLE_ONLINE_TIME=true
TIME_API_TIMEOUT=2
TIME_API_MAX_RETRIES=2
FALLBACK_TO_LOCAL_TIME=true
```

### 2. 监控设置
- 设置健康检查端点
- 监控时间获取成功率
- 设置告警机制

### 3. 备用方案
- 保持本地时间回退启用
- 定期同步服务器时间
- 考虑使用NTP服务

## 支持

如果遇到问题：
1. 查看Railway部署日志
2. 运行检查脚本诊断问题
3. 参考详细文档：`RAILWAY_ENV_VARS.md`
4. 联系技术支持并提供相关日志

---

**注意**: 此功能设计为即插即用，在大多数情况下无需额外配置即可正常工作。
