# 英国时区处理完整指南

## 问题背景

英国时区是最复杂的情况之一，需要特别小心处理：

1. **春季跳时**（每年3月最后一个周日）01:00 → 02:00
   - 例如 "01:30" 这个时间根本不存在
   
2. **秋季回拨**（每年10月最后一个周日）02:00 → 01:00
   - 例如 "01:30" 会出现两次（一次BST、一次GMT）
   - 这是歧义时间

## 解决方案架构

### 核心原则

1. **存储用UTC**：后端数据库永远保存UTC时间
2. **携带时区信息**：传递IANA时区字符串（如Europe/London）
3. **解析要可控**：遇到歧义/不存在的时间，由后端用规则消歧
4. **展示按用户时区**：渲染前从UTC → 用户时区

### 数据模型

```sql
-- 消息表
CREATE TABLE messages (
    id SERIAL PRIMARY KEY,
    sender_id VARCHAR(8),
    receiver_id VARCHAR(8),
    content TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),  -- UTC时间
    created_at_tz VARCHAR(50) DEFAULT 'UTC',      -- 时区信息
    local_time TEXT,                              -- 原始本地时间（可选）
    is_read INTEGER DEFAULT 0
);
```

## 实现细节

### 1. 后端时间处理（Python）

#### 时间工具类 (`app/time_utils.py`)

```python
class TimeHandler:
    @staticmethod
    def parse_local_time_to_utc(local_time_str, timezone_str, disambiguation="later"):
        """将本地时间转换为UTC，处理歧义时间"""
        
    @staticmethod
    def _handle_uk_time_ambiguity(local_dt, zone, disambiguation):
        """处理英国时区的歧义时间"""
        # 使用fold参数处理歧义
        if disambiguation == "earlier":
            dt_with_tz = local_dt.replace(tzinfo=zone, fold=0)  # BST
        else:
            dt_with_tz = local_dt.replace(tzinfo=zone, fold=1)  # GMT
        
        return dt_with_tz.astimezone(timezone.utc)
    
    @staticmethod
    def validate_time_input(local_time_str, timezone_str):
        """验证时间输入，检查歧义和无效时间"""
```

#### 歧义时间处理

```python
# 秋季回拨当天 01:30（歧义）
ldt = datetime(2025, 10, 26, 1, 30)

# 选择"早"的那次（BST → 偏移 +01:00）
dt_earlier = ldt.replace(tzinfo=zone, fold=0)

# 选择"晚"的那次（GMT → 偏移 +00:00）
dt_later = ldt.replace(tzinfo=zone, fold=1)
```

### 2. 前端时间处理（JavaScript）

#### 时区检测

```javascript
const getUserTimezone = () => {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone;
  } catch (error) {
    return 'Europe/London'; // 默认英国时区
  }
};
```

#### 时间格式化

```javascript
const formatTimeForDisplay = (utcTimeString, timezone) => {
  const utcTime = new Date(utcTimeString);
  const localTime = new Intl.DateTimeFormat('en-GB', {
    timeZone: timezone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  }).format(utcTime);
  
  // 检查是否夏令时
  const isDST = utcTime.toLocaleString('en-GB', { timeZone: timezone }).includes('BST');
  const tzDisplay = timezone === 'Europe/London' ? (isDST ? 'BST' : 'GMT') : timezone;
  
  return `${localTime} (${tzDisplay})`;
};
```

### 3. 数据传输格式

#### 前端发送消息

```javascript
const messageData = {
  receiver_id: activeContact.id,
  content: messageContent,
  message_id: messageId,
  timezone: userTimezone,  // IANA时区
  local_time: new Date().toLocaleString('en-GB', { timeZone: userTimezone })
};
```

#### 后端存储

```python
# 解析时间
utc_time, tz_info, local_time = TimeHandler.parse_local_time_to_utc(
    local_time_str, timezone_str, "later"
)

# 存储到数据库
msg = Message(
    sender_id=sender_id,
    receiver_id=receiver_id,
    content=content,
    created_at=utc_time,        # UTC时间
    created_at_tz=tz_info,      # 时区信息
    local_time=local_time       # 原始本地时间
)
```

## API端点

### 时间验证端点

```python
@router.post("/validate-time")
async def validate_time(request: TimeValidationRequest):
    """验证时间输入，检查歧义和无效时间"""

@router.get("/dst-info/{year}")
async def get_dst_info(year: int):
    """获取指定年份的夏令时切换信息"""

@router.post("/convert-to-utc")
async def convert_to_utc(request: TimeValidationRequest):
    """将本地时间转换为UTC时间"""
```

## 使用示例

### 1. 正常时间处理

```javascript
// 前端发送
const messageData = {
  content: "Hello",
  timezone: "Europe/London",
  local_time: "2025-10-10 14:30"
};

// 后端处理
utc_time, tz_info, local_time = TimeHandler.parse_local_time_to_utc(
    "2025-10-10 14:30", "Europe/London", "later"
);
// 结果: utc_time = 2025-10-10 13:30:00, tz_info = "Europe/London (BST)"
```

### 2. 歧义时间处理

```javascript
// 秋季回拨当天
const messageData = {
  content: "Hello",
  timezone: "Europe/London",
  local_time: "2025-10-26 01:30"  // 歧义时间
};

// 后端自动选择"later"（GMT）
utc_time, tz_info, local_time = TimeHandler.parse_local_time_to_utc(
    "2025-10-26 01:30", "Europe/London", "later"
);
// 结果: utc_time = 2025-10-26 01:30:00, tz_info = "Europe/London (GMT)"
```

### 3. 无效时间处理

```javascript
// 春季跳时当天
const messageData = {
  content: "Hello",
  timezone: "Europe/London",
  local_time: "2025-03-30 01:30"  // 不存在的时间
};

// 后端验证
validation = TimeHandler.validate_time_input(
    "2025-03-30 01:30", "Europe/London"
);
// 结果: is_invalid = true, suggestions = ["此时间不存在，请选择02:00或之后的时间"]
```

## 测试验证

### 1. 功能测试

```bash
# 测试时间验证
curl -X POST "https://api.link2ur.com/validate-time" \
  -H "Content-Type: application/json" \
  -d '{"local_time": "2025-10-26 01:30", "timezone": "Europe/London"}'

# 测试DST信息
curl "https://api.link2ur.com/dst-info/2025"

# 测试时间转换
curl -X POST "https://api.link2ur.com/convert-to-utc" \
  -H "Content-Type: application/json" \
  -d '{"local_time": "2025-10-26 01:30", "timezone": "Europe/London", "disambiguation": "later"}'
```

### 2. 边界情况测试

- 春季跳时：2025-03-30 01:30（不存在）
- 秋季回拨：2025-10-26 01:30（歧义）
- 正常时间：2025-10-10 14:30（正常）
- 跨时区：不同用户时区

## 监控和告警

### 关键指标

- 时间解析成功率：> 99%
- 歧义时间处理准确率：100%
- 时区转换准确性：> 99.9%

### 告警设置

- 时间解析失败率 > 1%
- 歧义时间处理错误
- 时区信息丢失

## 部署注意事项

### 1. 数据库迁移

```sql
-- 添加时区字段
ALTER TABLE messages ADD COLUMN created_at_tz VARCHAR(50) DEFAULT 'UTC';
ALTER TABLE messages ADD COLUMN local_time TEXT;

-- 更新现有数据
UPDATE messages SET created_at_tz = 'Europe/London' WHERE created_at_tz IS NULL;
```

### 2. 环境变量

```bash
# 默认时区
DEFAULT_TIMEZONE=Europe/London

# 消歧策略
DEFAULT_DISAMBIGUATION=later

# 时区验证
ENABLE_TIMEZONE_VALIDATION=true
```

### 3. 依赖更新

```bash
# Python依赖
pip install zoneinfo  # Python 3.9+
# 或
pip install pytz      # 向后兼容

# 前端依赖
# 使用原生Intl API，无需额外依赖
```

## 故障排除

### 常见问题

1. **时间显示错误**
   - 检查时区检测是否正确
   - 验证UTC转换逻辑
   - 确认前端格式化函数

2. **歧义时间处理错误**
   - 检查fold参数使用
   - 验证消歧策略
   - 确认时区规则更新

3. **性能问题**
   - 缓存时区信息
   - 优化时间解析
   - 减少API调用

### 调试工具

```python
# 调试时间解析
from app.time_utils import TimeHandler

# 测试歧义时间
result = TimeHandler.parse_local_time_to_utc(
    "2025-10-26 01:30", "Europe/London", "later"
)
print(f"UTC时间: {result[0]}")
print(f"时区信息: {result[1]}")
print(f"本地时间: {result[2]}")

# 测试时间验证
validation = TimeHandler.validate_time_input(
    "2025-03-30 01:30", "Europe/London"
)
print(f"验证结果: {validation}")
```

---

**总结**：这套方案彻底解决了英国时区的复杂问题，确保时间处理的准确性和可靠性。通过UTC存储、时区信息携带、歧义时间处理和用户时区显示，实现了"防弹"的时间处理系统。
