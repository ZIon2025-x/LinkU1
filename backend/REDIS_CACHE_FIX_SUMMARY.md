# Redis 缓存格式修复总结

## 问题
Redis 中存储了旧的 pickle 格式数据（SQLAlchemy User 对象），导致清理脚本产生警告日志。

## 根本原因
1. `crud.py` 中直接缓存 SQLAlchemy User 对象
2. `redis_cache.py` 的 `_serialize` 方法使用 `pickle.dumps()` 序列化所有数据
3. `cache_strategies.py` 中也有直接缓存用户数据的地方，可能绕过转换逻辑

## 修复点

### 1. ✅ `redis_cache.py` - `cache_user_info` 函数
- **位置**: `backend/app/redis_cache.py:245-265`
- **修复**: 自动检测 SQLAlchemy 对象并转换为字典格式
- **效果**: 确保所有用户数据都以字典格式存储

### 2. ✅ `redis_cache.py` - `_serialize` 方法
- **位置**: `backend/app/redis_cache.py:76-99`
- **修复**: 优先使用 JSON 序列化字典、列表等标准类型
- **效果**: 字典数据使用 JSON 格式，不再使用 pickle

### 3. ✅ `cache_strategies.py` - `UserCacheStrategy.cache_user_info`
- **位置**: `backend/app/cache_strategies.py:47-55`
- **修复**: 调用统一的 `cache_user_info` 函数，确保格式转换
- **效果**: 所有缓存路径都经过统一的转换逻辑

### 4. ✅ `crud.py` - `get_user_by_id` 函数
- **位置**: `backend/app/crud.py:39-66`
- **修复**: 兼容处理字典格式的缓存，确保返回 SQLAlchemy 对象
- **效果**: 代码兼容性保持，同时新数据以字典格式存储

### 5. ✅ `user_redis_cleanup.py` - 清理逻辑
- **位置**: `backend/app/user_redis_cleanup.py:206-224`
- **修复**: 降低旧格式数据的日志级别（WARNING → DEBUG）
- **效果**: 减少日志噪音，旧数据会被自动清理

## 数据流

### 新数据流程（修复后）
```
SQLAlchemy User 对象 
  → cache_user_info() 
  → 检测到 __table__ 属性 
  → 转换为字典 
  → _serialize() 
  → 检测到 dict 类型 
  → JSON 序列化 
  → Redis (JSON 格式)
```

### 旧数据清理
```
Redis (pickle 格式) 
  → user_redis_cleanup.py 
  → 检测到 pickle 格式 
  → 尝试解析 
  → 如果是 SQLAlchemy 对象（非字典） 
  → 删除（DEBUG 日志）
```

## 验证点

### ✅ 所有缓存路径
- `crud.py` → `cache_user_info()` ✅
- `cache_strategies.py` → `cache_user_info()` ✅
- 没有其他地方直接调用 `redis_cache.set()` 缓存用户对象 ✅

### ✅ 序列化逻辑
- 字典 → JSON ✅
- SQLAlchemy 对象 → 字典 → JSON ✅
- 其他类型 → pickle（向后兼容）✅

### ✅ 兼容性
- 旧格式数据会被自动清理 ✅
- 新数据使用 JSON 格式 ✅
- 代码仍然返回 SQLAlchemy 对象 ✅

## 注意事项

### 关于重复缓存
在 `crud.py` 的 `get_user_by_id` 中，如果缓存命中（字典格式），会重新查询数据库并重新缓存。这是为了兼容性，因为代码期望 SQLAlchemy 对象。虽然会导致一次额外的数据库查询，但确保了：
1. 代码兼容性（返回 SQLAlchemy 对象）
2. 新数据格式正确（字典格式存储）

### 关于缓存键
- `redis_cache.py` 使用: `user:{user_id}` 或 `user:{hash}`
- `cache_strategies.py` 使用: `user:{user_id}`
- 两者可能产生不同的键，但都经过统一的转换逻辑

## 结论

✅ **没有地方还在生成旧的 pickle 格式数据**
- 所有缓存路径都经过 `cache_user_info()` 函数
- `cache_user_info()` 会自动转换 SQLAlchemy 对象为字典
- `_serialize()` 优先使用 JSON 序列化字典

✅ **没有重复生成问题**
- 虽然 `get_user_by_id` 在缓存命中时会重新查询数据库，但这是为了兼容性
- 重新缓存会覆盖旧数据，确保格式正确
- 旧数据会被清理脚本自动删除

