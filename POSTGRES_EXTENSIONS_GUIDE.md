# PostgreSQL 扩展使用指南

## 已安装的扩展

### 1. **plpgsql** (v1.0) ✅
- **状态**: 已安装（标准扩展）
- **用途**: PostgreSQL 过程语言，执行存储过程和函数
- **使用**: 自动启用，无需额外配置

### 2. **pg_trgm** (v1.6) ✅
- **用途**: 文本相似度匹配和模糊搜索
- **优化领域**: 
  - 任务标题/描述搜索
  - 用户姓名/邮箱搜索
  - 自动纠错功能

**使用示例** (在 `backend/app/crud.py` 中):
```python
from sqlalchemy import func

# 优化前（当前使用的方法）
query.filter(Task.title.ilike(f"%{keyword}%"))

# 优化后（使用 pg_trgm）
# 只搜索相似度 > 0.3 的结果，并按相似度排序
query.filter(
    func.similarity(Task.title, keyword) > 0.3
).order_by(
    func.similarity(Task.title, keyword).desc()
)
```

**创建索引优化** (在 Railway 数据库执行):
```sql
-- 为任务标题创建 trgm 索引
CREATE INDEX idx_tasks_title_trgm ON tasks USING gin(title gin_trgm_ops);

-- 为任务描述创建 trgm 索引
CREATE INDEX idx_tasks_description_trgm ON tasks USING gin(description gin_trgm_ops);

-- 为用户名字段创建 trgm 索引
CREATE INDEX idx_users_name_trgm ON users USING gin(name gin_trgm_ops);
```

### 3. **pgcrypto** (v1.3) ✅
- **用途**: 加密函数
- **使用**: 当前已通过 Python 的 `bcrypt` 实现密码加密
- **可选用途**:
```python
# 如果需要数据库层加密
from sqlalchemy import text
result = db.execute(text("SELECT crypt('password', gen_salt('bf'))"))
```

### 4. **pg_stat_statements** (v1.11) ✅
- **用途**: SQL 性能监控
- **使用方式**:
```sql
-- 查看最慢的 10 个查询
SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- 查看特定表的统计信息
SELECT 
    schemaname,
    tablename,
    idx_scan,
    idx_tup_fetch,
    seq_scan,
    seq_tup_read
FROM pg_stat_user_tables
WHERE tablename IN ('tasks', 'users');
```

### 5. **amcheck** (v1.4) ✅
- **用途**: 验证关系和索引完整性
- **使用场景**: 数据库维护和故障排查
```sql
-- 检查索引完整性
SELECT * FROM amcheck_verify_index('tasks_pkey');

-- 检查表完整性
SELECT * FROM amcheck_verify_heap('tasks');
```

## 优化建议

### 立即优化（使用 pg_trgm）

**在 `backend/app/crud.py` 的 `list_tasks` 函数中**:

当前代码 (337-347行):
```python
if keyword and keyword.strip():
    keyword_pattern = f"%{keyword.strip()}%"
    query = query.filter(
        or_(
            Task.title.ilike(keyword_pattern),
            Task.description.ilike(keyword_pattern),
            Task.task_type.ilike(keyword_pattern),
            Task.location.ilike(keyword_pattern)
        )
    )
```

**建议改为**:
```python
from sqlalchemy import func

if keyword and keyword.strip():
    keyword_clean = keyword.strip()
    # 使用相似度匹配，只返回相似度 > 0.2 的结果
    # 并且按相似度排序，最相关的在前面
    query = query.filter(
        func.similarity(Task.title, keyword_clean) > 0.2
    ).order_by(
        func.similarity(Task.title, keyword_clean).desc(),
        Task.created_at.desc()
    )
```

### 用户搜索优化

在 `backend/app/crud.py` 的 `get_users_for_admin` 函数中:

当前代码 (1241-1248行):
```python
if search:
    query = query.filter(
        or_(
            models.User.id.contains(search),
            models.User.name.contains(search),
            models.User.email.contains(search),
        )
    )
```

**建议改为**:
```python
if search:
    from sqlalchemy import func
    query = query.filter(
        or_(
            func.similarity(models.User.name, search) > 0.2,
            func.similarity(models.User.email, search) > 0.2,
            models.User.id.contains(search)
        )
    ).order_by(
        func.similarity(models.User.name, search).desc()
    )
```

## 索引创建 SQL

在 Railway 数据库控制台执行以下 SQL 来创建索引：

```sql
-- 1. 为任务搜索创建 GIN 索引（使用 pg_trgm）
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- 任务标题索引
CREATE INDEX IF NOT EXISTS idx_tasks_title_trgm 
ON tasks USING gin(title gin_trgm_ops);

-- 任务描述索引  
CREATE INDEX IF NOT EXISTS idx_tasks_description_trgm 
ON tasks USING gin(description gin_trgm_ops);

-- 任务类型索引
CREATE INDEX IF NOT EXISTS idx_tasks_type_trgm 
ON tasks USING gin(task_type gin_trgm_ops);

-- 任务地点索引
CREATE INDEX IF NOT EXISTS idx_tasks_location_trgm 
ON tasks USING gin(location gin_trgm_ops);

-- 2. 用户搜索索引
CREATE INDEX IF NOT EXISTS idx_users_name_trgm 
ON users USING gin(name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_users_email_trgm 
ON users USING gin(email gin_trgm_ops);

-- 3. 查看索引大小
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
FROM pg_indexes
WHERE tablename IN ('tasks', 'users')
ORDER BY pg_relation_size(indexname::regclass) DESC;
```

## 性能监控查询

### 查看慢查询
```sql
-- 查看执行时间最长的查询
SELECT 
    left(query, 80) as query_snippet,
    calls,
    round(total_exec_time::numeric, 2) as total_time,
    round(mean_exec_time::numeric, 2) as mean_time,
    round(max_exec_time::numeric, 2) as max_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;
```

### 查看索引使用情况
```sql
-- 查看索引使用统计
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;
```

### 查看表统计
```sql
-- 查看表大小和统计
SELECT 
    relname as table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS size,
    n_live_tup as row_count,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```

## 故障排查

### 检查数据库健康
```sql
-- 检查未使用的索引（可以删除的索引）
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND schemaname = 'public';

-- 检查索引膨胀
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;
```

## 注意事项

1. **pg_trgm 索引会占用额外空间**，但可以大幅提升模糊搜索性能
2. **相似度阈值**建议设置为 0.2-0.3，太低会有大量无关结果
3. **pg_stat_statements** 需要定期重置，避免占用过多内存
4. **定期执行 VACUUM ANALYZE** 保持索引效率

## 重置统计信息

```sql
-- 重置 pg_stat_statements（可选）
SELECT pg_stat_statements_reset();

-- 更新表统计信息
VACUUM ANALYZE tasks;
VACUUM ANALYZE users;
```

