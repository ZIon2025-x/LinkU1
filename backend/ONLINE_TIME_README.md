# 在线英国时间获取功能

## 概述

后端现在支持通过网络API获取真实的英国时间，确保时间显示的准确性，特别是在处理夏令时/冬令时转换时。

## 功能特点

- 🌐 **多API备用**: 使用3个不同的时间API作为备用
- ⏰ **自动时区转换**: 正确处理英国夏令时/冬令时
- 🔄 **智能回退**: API失败时自动回退到本地时间
- 📊 **详细日志**: 记录API调用状态和错误信息

## 使用的API

1. **WorldTimeAPI** (主要)
   - URL: `http://worldtimeapi.org/api/timezone/Europe/London`
   - 特点: 稳定、准确、支持时区信息

2. **TimeAPI** (备用1)
   - URL: `http://timeapi.io/api/Time/current/zone?timeZone=Europe/London`
   - 特点: 快速响应

3. **WorldClockAPI** (备用2)
   - URL: `http://worldclockapi.com/api/json/utc/now`
   - 特点: 全球时间服务

## 新增函数

### `get_uk_time_online()`
通过网络获取真实的英国时间，使用多个API作为备用。

```python
from app.models import get_uk_time_online

# 获取在线英国时间
uk_time = get_uk_time_online()
print(uk_time)  # 2024-01-15 14:30:25+00:00
```

### `get_uk_time_naive()` (已更新)
获取用于数据库存储的英国时间，现在使用在线时间作为源。

```python
from app.models import get_uk_time_naive

# 获取数据库存储时间
db_time = get_uk_time_naive()
print(db_time)  # 2024-01-15 14:30:25 (无时区信息)
```

## 安装和配置

### 1. 安装依赖

```bash
# 运行安装脚本
chmod +x install_dependencies.sh
./install_dependencies.sh

# 或手动安装
pip install requests>=2.31.0
pip install -r requirements.txt
```

### 2. 测试功能

```bash
# 运行测试脚本
python test_online_time.py
```

## 错误处理

- **网络超时**: 每个API调用超时时间为3秒
- **API失败**: 自动尝试下一个API
- **全部失败**: 回退到本地时间计算
- **详细日志**: 记录所有API调用状态

## 日志示例

```
尝试使用 WorldTimeAPI 获取英国时间...
成功从 WorldTimeAPI 获取英国时间: 2024-01-15 14:30:25+00:00
```

## 时区处理

- **夏令时 (BST)**: UTC+1 (3月最后一个周日 - 10月最后一个周日)
- **冬令时 (GMT)**: UTC+0 (10月最后一个周日 - 3月最后一个周日)
- **自动检测**: 系统自动处理时区转换

## 性能考虑

- **缓存**: 建议在生产环境中添加时间缓存机制
- **异步**: 可以考虑使用异步HTTP客户端提高性能
- **监控**: 建议监控API调用成功率和响应时间

## 故障排除

### 常见问题

1. **所有API都失败**
   - 检查网络连接
   - 检查防火墙设置
   - 系统会自动回退到本地时间

2. **时间不准确**
   - 检查服务器时区设置
   - 验证API返回的时间格式

3. **性能问题**
   - 考虑添加缓存机制
   - 减少API调用频率

### 调试模式

在代码中添加调试信息：

```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## 更新历史

- **v1.0**: 初始实现，支持多API备用
- **v1.1**: 添加详细日志和错误处理
- **v1.2**: 优化API选择和超时处理
