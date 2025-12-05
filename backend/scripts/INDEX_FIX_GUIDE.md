# 索引名称冲突修复指南

## 🐛 问题描述

**错误信息**：
```
psycopg2.errors.DuplicateTable: relation "idx_user_id" already exists
```

**原因**：
- `student_verifications` 表和 `verification_history` 表都定义了名为 `idx_user_id` 的索引
- PostgreSQL 要求索引名称在整个数据库中唯一
- 当 SQLAlchemy 的 `Base.metadata.create_all()` 尝试创建索引时，发现索引已存在，导致冲突

## ✅ 修复方案

### 1. 修改迁移脚本

**文件**：`backend/migrations/030_add_student_verification_tables.sql`

**修改内容**：
- 所有索引都添加了表名前缀，确保唯一性
- 使用 `CREATE INDEX IF NOT EXISTS` 确保幂等性

**示例**：
```sql
-- 修改前
CREATE INDEX idx_user_id ON student_verifications(user_id);
CREATE INDEX idx_user_id ON verification_history(user_id);

-- 修改后
CREATE INDEX IF NOT EXISTS idx_student_verifications_user_id ON student_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_verification_history_user_id ON verification_history(user_id);
```

### 2. 修改模型定义

**文件**：`backend/app/models.py`

**修改内容**：
- 所有索引名称都添加了表名前缀
- 与迁移脚本保持一致

**示例**：
```python
# 修改前
Index('idx_user_id', 'user_id')

# 修改后
Index('idx_student_verifications_user_id', 'user_id')
Index('idx_verification_history_user_id', 'user_id')
```

### 3. 修改 create_all 行为

**文件**：`backend/app/main.py`

**修改内容**：
- 添加 `checkfirst=True` 参数，避免重复创建已存在的对象

```python
# 修改前
Base.metadata.create_all(bind=sync_engine)

# 修改后
Base.metadata.create_all(bind=sync_engine, checkfirst=True)
```

### 4. 创建修复迁移脚本

**文件**：`backend/migrations/031_fix_index_names.sql`

**作用**：
- 重命名已存在的索引，使其与新的命名规范一致
- 幂等性：如果索引已重命名，则跳过

## 🚀 部署步骤

### 方式1：自动修复（推荐）

系统会在启动时自动执行迁移脚本，包括：
1. `030_add_student_verification_tables.sql` - 创建表（使用新的索引名称）
2. `031_fix_index_names.sql` - 修复已存在的索引名称

**无需手动操作！**

### 方式2：手动修复

如果自动修复失败，可以手动执行：

```bash
# 执行修复迁移脚本
psql -U postgres -d linku_db -f backend/migrations/031_fix_index_names.sql
```

## ✅ 验证修复

### 检查索引名称

```sql
-- 检查 student_verifications 表的索引
SELECT indexname 
FROM pg_indexes 
WHERE tablename = 'student_verifications'
ORDER BY indexname;

-- 检查 verification_history 表的索引
SELECT indexname 
FROM pg_indexes 
WHERE tablename = 'verification_history'
ORDER BY indexname;

-- 检查是否有重复的索引名称
SELECT indexname, COUNT(*) 
FROM pg_indexes 
WHERE schemaname = 'public'
GROUP BY indexname 
HAVING COUNT(*) > 1;
```

**期望结果**：
- 所有索引名称都包含表名前缀
- 没有重复的索引名称

### 检查应用启动

启动应用后，查看日志：
```
✅ 数据库表创建完成！
✅ 数据库迁移执行完成！
```

**不应该出现**：
```
❌ 数据库初始化失败: relation "idx_user_id" already exists
```

## 📋 索引命名规范

为了避免未来的冲突，遵循以下命名规范：

**格式**：`idx_{表名}_{字段名}`

**示例**：
- `idx_student_verifications_user_id`
- `idx_verification_history_user_id`
- `idx_universities_email_domain`

**复合索引**：
- `idx_student_verifications_user_status`（user_id, status）
- `idx_student_verifications_expires_status`（expires_at, status）

## 🔍 故障排查

### 问题1：修复后仍然报错

**可能原因**：
- 旧的索引仍然存在
- 迁移脚本未执行

**解决方案**：
1. 手动执行修复脚本：`031_fix_index_names.sql`
2. 检查迁移记录表：`SELECT * FROM schema_migrations;`
3. 查看应用日志确认迁移是否执行

### 问题2：索引名称不一致

**可能原因**：
- 模型定义和迁移脚本不一致

**解决方案**：
1. 检查 `models.py` 中的索引名称
2. 检查迁移脚本中的索引名称
3. 确保两者一致

### 问题3：create_all 仍然报错

**可能原因**：
- `checkfirst=True` 未生效
- SQLAlchemy 版本问题

**解决方案**：
1. 确认 `checkfirst=True` 已添加
2. 升级 SQLAlchemy 到最新版本
3. 或者禁用 `create_all`，只使用迁移脚本

## 📝 注意事项

1. **索引名称唯一性**：PostgreSQL 要求索引名称在整个数据库中唯一
2. **命名规范**：使用表名前缀可以避免冲突
3. **幂等性**：使用 `IF NOT EXISTS` 和 `checkfirst=True` 确保可以安全地重复执行
4. **向后兼容**：修复脚本会重命名已存在的索引，不影响现有数据

## ✨ 修复完成

修复后，系统应该能够正常启动，不再出现索引名称冲突错误。

