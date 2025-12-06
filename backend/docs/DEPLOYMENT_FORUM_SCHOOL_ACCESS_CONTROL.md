# 论坛学校板块访问控制功能部署文档

## 📋 概述

本文档说明如何部署论坛学校板块访问控制功能，包括数据库迁移、数据初始化、功能验证等步骤。

## 🎯 功能说明

本功能实现了基于学生认证状态的论坛板块访问控制：
- **普通板块** (`type='general'`)：所有用户可见
- **国家/地区级大板块** (`type='root'`)：仅对应国家的认证学生可见（如"英国留学生"）
- **大学级小板块** (`type='university'`)：仅对应大学的认证学生可见（如"布里斯托大学"）

## 📦 前置条件

1. **数据库备份**（生产环境必须）
   ```bash
   pg_dump -U your_user -d your_database > backup_$(date +%Y%m%d_%H%M%S).sql
   ```

2. **确认数据库版本**
   - PostgreSQL 12+ 推荐
   - 确保已安装 `pg_trgm` 扩展（用于搜索功能，可选）

3. **确认 Redis 可用**（用于缓存，可选但推荐）
   - 缓存可见板块列表，提升性能
   - 如果 Redis 不可用，功能仍可正常工作，但性能会下降

## 🚀 部署步骤

### 步骤 1：数据库迁移

运行数据库迁移脚本：

```bash
# 方式1：使用 psql 直接执行
psql -U your_user -d your_database -f backend/migrations/032_add_forum_school_access_control.sql

# 方式2：如果使用 Alembic 等迁移工具，将 SQL 脚本转换为 Alembic 迁移
```

**迁移脚本内容**：
- 为 `forum_categories` 表添加 `type`, `country`, `university_code` 字段
- 为 `universities` 表添加 `country`, `code` 字段
- 添加必要的约束和索引
- 创建默认的"英国留学生"根板块

**验证迁移**：
```sql
-- 检查字段是否添加成功
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'forum_categories' 
AND column_name IN ('type', 'country', 'university_code');

SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'universities' 
AND column_name IN ('country', 'code');

-- 检查约束是否添加成功
SELECT conname, contype 
FROM pg_constraint 
WHERE conrelid = 'forum_categories'::regclass 
AND conname LIKE 'chk_forum%';
```

### 步骤 2：初始化大学编码和学校板块

运行自动化初始化脚本：

```bash
# 从项目根目录运行
python backend/scripts/init_forum_school_categories.py

# 或从 backend 目录运行
cd backend
python scripts/init_forum_school_categories.py
```

**脚本功能**：
1. 为所有英国大学填充 `country='UK'` 和 `code` 字段
2. 为每个英国大学创建对应的论坛板块（`type='university'`）
3. 验证数据一致性

**脚本输出示例**：
```
开始初始化论坛学校板块...
查询到 150 个英国大学
已更新 150 个大学的编码
已创建 150 个大学板块
验证完成：所有大学都有对应的板块
初始化完成！
```

**注意事项**：
- 脚本支持幂等性，可以安全地多次运行
- 如果某个大学已有编码或板块，脚本会跳过，不会重复创建
- 如果编码冲突，脚本会自动添加后缀避免重复

### 步骤 3：验证数据初始化

```sql
-- 检查大学编码
SELECT COUNT(*) FROM universities WHERE country = 'UK' AND code IS NOT NULL;

-- 检查学校板块
SELECT COUNT(*) FROM forum_categories WHERE type = 'university';

-- 检查根板块
SELECT * FROM forum_categories WHERE type = 'root' AND country = 'UK';

-- 验证数据一致性（每个有编码的英国大学都应该有对应的板块）
SELECT 
    u.id, 
    u.name, 
    u.code,
    CASE WHEN fc.id IS NULL THEN '缺少板块' ELSE '正常' END as status
FROM universities u
LEFT JOIN forum_categories fc ON u.code = fc.university_code AND fc.type = 'university'
WHERE u.country = 'UK' AND u.code IS NOT NULL
ORDER BY u.name;
```

### 步骤 4：重启应用服务

```bash
# 如果使用 systemd
sudo systemctl restart your-app-service

# 如果使用 Docker
docker-compose restart backend

# 如果使用 PM2
pm2 restart your-app
```

### 步骤 5：验证功能

#### 5.1 测试 API 端点

```bash
# 1. 测试可见板块接口（未登录用户）
curl -X GET "http://localhost:8000/api/forum/forums/visible"

# 2. 测试可见板块接口（已登录但未认证的英国学生）
curl -X GET "http://localhost:8000/api/forum/forums/visible" \
  -H "Cookie: your_session_cookie"

# 3. 测试可见板块接口（已认证的英国学生）
# 应该能看到"英国留学生"大板块和对应大学的板块
curl -X GET "http://localhost:8000/api/forum/forums/visible" \
  -H "Cookie: your_session_cookie"
```

#### 5.2 测试权限控制

**场景1：未登录用户访问学校板块**
```bash
# 应该返回 404（隐藏存在性）
curl -X GET "http://localhost:8000/api/forum/categories/{university_category_id}"
```

**场景2：已登录但未认证用户访问学校板块**
```bash
# 应该返回 404（隐藏存在性）
curl -X GET "http://localhost:8000/api/forum/categories/{university_category_id}" \
  -H "Cookie: your_session_cookie"
```

**场景3：已认证的英国学生访问学校板块**
```bash
# 应该返回 200 和板块信息
curl -X GET "http://localhost:8000/api/forum/categories/{university_category_id}" \
  -H "Cookie: your_session_cookie"
```

**场景4：管理员访问**
```bash
# 管理员可以访问所有板块
curl -X GET "http://localhost:8000/api/forum/forums/visible?include_all=true" \
  -H "Cookie: admin_session_cookie"
```

#### 5.3 测试前端界面

1. **未登录用户**：
   - 访问论坛首页，应该只看到普通板块
   - 不应该看到"英国留学生"大板块和任何大学板块

2. **已登录但未认证用户**：
   - 访问论坛首页，应该只看到普通板块
   - 不应该看到学校板块

3. **已认证的英国学生**：
   - 访问论坛首页，应该看到：
     - 所有普通板块
     - "英国留学生"大板块
     - 自己大学的板块（如"布里斯托大学"）
   - 不应该看到其他大学的板块

4. **管理员**：
   - 可以在管理员后台创建/编辑/删除板块
   - 可以设置板块类型（general/root/university）
   - 可以查看所有板块

## 🔧 配置说明

### Redis 缓存配置（可选但推荐）

如果启用了 Redis，可见板块列表会被缓存 5 分钟，提升性能。

**缓存键格式**：`visible_forums:v2:{user_id}`

**缓存失效时机**：
- 学生认证状态变更（verified/expired/revoked）
- 用户更换邮箱导致认证状态变更
- 管理员撤销学生认证

**如果 Redis 不可用**：
- 功能仍可正常工作
- 每次请求都会查询数据库，性能会下降
- 建议在生产环境启用 Redis

### 数据库索引

迁移脚本已自动创建以下索引：
- `idx_forum_categories_type_country`：用于查询特定国家的根板块
- `idx_forum_categories_university_code`：用于查询特定大学的板块
- `idx_universities_country`：用于查询特定国家的大学
- `idx_universities_code`：用于查询特定编码的大学

## 🐛 故障排查

### 问题1：迁移脚本执行失败

**症状**：字段已存在或约束冲突

**解决方案**：
```sql
-- 检查字段是否已存在
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'forum_categories' AND column_name = 'type';

-- 如果字段已存在但默认值不同，手动更新
ALTER TABLE forum_categories ALTER COLUMN type SET DEFAULT 'general';
```

### 问题2：初始化脚本执行失败

**症状**：编码冲突或数据不一致

**解决方案**：
1. 检查日志输出，找到具体错误
2. 手动修复数据：
```sql
-- 查看冲突的编码
SELECT code, COUNT(*) FROM universities 
WHERE code IS NOT NULL 
GROUP BY code 
HAVING COUNT(*) > 1;

-- 手动修复（示例）
UPDATE universities SET code = 'UOB2' WHERE id = 123 AND code = 'UOB';
```

3. 重新运行脚本（脚本支持幂等性）

### 问题3：用户看不到学校板块

**可能原因**：
1. 用户未通过学生认证
2. 用户认证的大学不是英国大学
3. 缓存未失效（如果启用了 Redis）

**排查步骤**：
```sql
-- 1. 检查用户认证状态
SELECT sv.*, u.name as university_name, u.country 
FROM student_verifications sv
JOIN universities u ON sv.university_id = u.id
WHERE sv.user_id = 'user_id_here' AND sv.status = 'verified';

-- 2. 检查大学编码
SELECT code, country FROM universities WHERE id = university_id_here;

-- 3. 检查板块是否存在
SELECT * FROM forum_categories 
WHERE type = 'university' AND university_code = 'UOB';
```

**解决方案**：
- 清除用户缓存（如果启用了 Redis）：
```bash
redis-cli DEL "visible_forums:v2:{user_id}"
```

### 问题4：管理员无法创建学校板块

**症状**：管理员后台创建板块时，无法选择大学编码

**解决方案**：
1. 确保已运行初始化脚本，为大学填充了编码
2. 检查前端是否正确加载了大学列表：
   - 打开浏览器开发者工具
   - 查看 Network 标签页
   - 检查 `/api/student-verification/universities` 接口是否返回数据

## 📊 性能监控

### 缓存命中率

如果启用了 Redis，可以监控缓存命中率：

```bash
# 查看缓存键数量
redis-cli KEYS "visible_forums:v2:*" | wc -l

# 查看特定用户的缓存
redis-cli GET "visible_forums:v2:{user_id}"
```

### 数据库查询性能

```sql
-- 查看慢查询（需要启用 pg_stat_statements）
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
WHERE query LIKE '%forum_categories%'
ORDER BY mean_time DESC
LIMIT 10;
```

## 🔄 回滚方案

如果部署后出现问题，可以回滚：

### 1. 回滚数据库迁移（谨慎操作）

```sql
BEGIN;

-- 删除新增的字段（注意：会丢失数据）
ALTER TABLE forum_categories 
DROP COLUMN IF EXISTS type,
DROP COLUMN IF EXISTS country,
DROP COLUMN IF EXISTS university_code;

ALTER TABLE universities 
DROP COLUMN IF EXISTS country,
DROP COLUMN IF EXISTS code;

-- 删除约束
ALTER TABLE forum_categories DROP CONSTRAINT IF EXISTS chk_forum_type;
ALTER TABLE forum_categories DROP CONSTRAINT IF EXISTS chk_forum_type_university_code;

-- 删除索引
DROP INDEX IF EXISTS idx_forum_categories_type_country;
DROP INDEX IF EXISTS idx_forum_categories_university_code;
DROP INDEX IF EXISTS idx_universities_country;
DROP INDEX IF EXISTS idx_universities_code;

COMMIT;
```

### 2. 回滚代码

```bash
# 使用 Git 回滚到之前的版本
git checkout <previous_commit_hash>

# 重启服务
sudo systemctl restart your-app-service
```

## 📝 后续维护

### 添加新大学

1. **手动添加**：
   - 在管理员后台添加大学信息
   - 设置 `country='UK'` 和 `code`（如 'UOX'）
   - 运行初始化脚本创建对应的论坛板块

2. **批量导入**：
   - 更新 `scripts/university_email_domains.json`
   - 运行 `init_universities.py` 导入大学
   - 运行 `init_forum_school_categories.py` 创建板块

### 修改大学编码

如果需要修改某个大学的编码：

```sql
BEGIN;

-- 1. 更新大学编码
UPDATE universities SET code = 'NEW_CODE' WHERE id = university_id;

-- 2. 更新对应的板块
UPDATE forum_categories 
SET university_code = 'NEW_CODE' 
WHERE university_code = 'OLD_CODE' AND type = 'university';

COMMIT;

-- 3. 清除所有用户的缓存（如果启用了 Redis）
redis-cli --scan --pattern "visible_forums:v2:*" | xargs redis-cli DEL
```

## ✅ 部署检查清单

- [ ] 数据库备份已完成
- [ ] 数据库迁移脚本已执行
- [ ] 初始化脚本已运行
- [ ] 数据验证通过（大学编码、板块创建）
- [ ] 应用服务已重启
- [ ] API 端点测试通过
- [ ] 前端界面测试通过
- [ ] 权限控制测试通过
- [ ] Redis 缓存配置正确（如启用）
- [ ] 监控和日志配置正确

## 📞 支持

如遇到问题，请：
1. 查看日志文件：`backend/logs/app.log`
2. 检查数据库错误日志
3. 联系开发团队

---

**文档版本**：1.0  
**最后更新**：2025-12-06

