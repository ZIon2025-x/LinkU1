# Redis 数据格式分析

## 概述

本文档分析了系统中所有写入 Redis 的数据格式，以及可能导致解析问题的数据。

## 数据格式分类

### 1. Pickle 格式（通过 `redis_cache.set`）

**使用位置：**
- `redis_cache.py` - `RedisCache._serialize()` 方法
- `cache_strategies.py` - 通过 `redis_cache.set()` 写入

**键模式：**
- `user:{user_id}` - 用户信息缓存
- `user_tasks:{user_id}:*` - 用户任务缓存
- `user_profile:{user_id}` - 用户资料缓存
- `user_notifications:{user_id}` - 用户通知缓存
- `user_reviews:{user_id}` - 用户评价缓存

**特点：**
- 使用 `pickle.dumps()` 序列化
- 如果 pickle 失败，回退到 `json.dumps().encode('utf-8')`
- 二进制格式，不能直接作为字符串读取

### 2. JSON 格式（直接使用 `json.dumps`）

**使用位置：**
- `secure_auth.py` - 会话数据
- `security.py` - refresh token 数据
- `service_auth.py` - 服务认证数据
- `admin_auth.py` - 管理员认证数据
- `task_chat_business_logic.py` - 协商 token 数据
- 各种验证码管理器

**键模式：**
- `session:{session_id}` - 用户会话
- `refresh_token:{refresh_jti}` - 刷新令牌
- `service_refresh_token:{refresh_token}` - 服务刷新令牌
- `negotiation_token:{token}` - 协商令牌
- `email_update_code:{user_id}:{email}` - 邮箱更新验证码
- `phone_update_code:{user_id}:{phone}` - 手机更新验证码
- `verification_code:{email/phone}` - 验证码

**特点：**
- 使用 `json.dumps()` 序列化为字符串
- 字符串格式，可以直接读取
- 需要 `json.loads()` 解析

### 3. orjson 格式（使用 `orjson.dumps`）

**使用位置：**
- `cache_decorators.py` - 任务详情缓存

**键模式：**
- `task:{version}:detail:{task_id}` - 任务详情缓存

**特点：**
- 使用 `orjson.dumps()` 序列化
- 二进制格式，但兼容标准 JSON
- 可以使用 `json.loads()` 或 `orjson.loads()` 解析

### 4. 特殊标记字符串

**使用位置：**
- `cache_decorators.py` - 空值标记
- `security.py` - 黑名单标记

**键模式：**
- `task:{version}:detail:{task_id}` - 可能包含 `"__NULL__"` 标记
- `blacklist:{jti}` - 包含 `"1"` 标记

**特点：**
- 纯字符串，不是 JSON 或 pickle
- `"__NULL__"` - 表示空值缓存（防止缓存穿透）
- `"1"` - 表示黑名单标记
- 这些不是字典数据，清理时应该跳过或特殊处理

## 可能导致解析问题的数据

### 1. 格式不匹配

**问题：**
- `user:*` 键使用 pickle 格式
- 清理代码如果只尝试 JSON 解析会失败

**解决方案：**
- ✅ 已修复：`_get_redis_data()` 现在支持 pickle → JSON → orjson 的解析顺序

### 2. 特殊标记字符串

**问题：**
- `"__NULL__"` 和 `"1"` 等标记不是字典格式
- 尝试解析为字典会失败

**解决方案：**
- ✅ 已修复：在解析前检查特殊标记，直接返回 None

### 3. 双重编码

**问题：**
- 某些数据可能被 JSON 编码两次
- 例如：`json.dumps(json.dumps(data))`

**解决方案：**
- ✅ 已修复：如果解析得到字符串，会再次尝试解析

### 4. 空值或损坏数据

**问题：**
- Redis 中可能存在空字符串或损坏的数据
- 这些数据无法解析

**解决方案：**
- ✅ 已修复：无法解析的数据会被标记为需要清理，并在清理时删除

## 清理策略

### 用户缓存清理（`user:*`）

**格式：** 主要是 pickle 格式（通过 `redis_cache.set`）

**清理逻辑：**
1. 尝试 pickle 反序列化
2. 如果失败，尝试 JSON 解析
3. 如果都失败，标记为无法解析，直接删除
4. 如果可以解析，检查是否过期

### 会话数据清理（`session:*`）

**格式：** JSON 格式（`json.dumps`）

**清理逻辑：**
1. 尝试 JSON 解析
2. 如果失败，标记为无法解析，直接删除
3. 如果可以解析，检查是否过期（24小时）

### Refresh Token 清理（`refresh_token:*`）

**格式：** JSON 格式（`json.dumps`）

**清理逻辑：**
1. 尝试 JSON 解析
2. 如果失败，标记为无法解析，直接删除
3. 如果可以解析，检查是否过期

## 建议

### 1. 统一序列化方式

**当前状态：**
- 用户缓存使用 pickle
- 会话和 token 使用 JSON
- 任务缓存使用 orjson

**建议：**
- 保持现状，但确保清理代码支持所有格式（✅ 已实现）

### 2. 添加数据验证

**建议：**
- 写入时验证数据格式
- 读取时验证数据完整性
- 清理时自动修复或删除损坏数据（✅ 已实现）

### 3. 监控和日志

**建议：**
- 记录无法解析的数据数量
- 监控不同格式的数据分布
- 定期清理损坏数据（✅ 已实现）

## 总结

✅ **已修复的问题：**
1. 支持 pickle、JSON、orjson 三种格式
2. 正确处理特殊标记字符串
3. 自动清理无法解析的损坏数据
4. 改进错误处理和日志记录

✅ **当前状态：**
- 清理代码可以正确处理所有数据格式
- 无法解析的数据会被自动清理
- 不再出现 JSON 解析错误日志

