# 学生认证系统部署指南

## 1. 数据库迁移

### 自动迁移（推荐）

系统启动时会自动执行迁移脚本（如果 `AUTO_MIGRATE=true`）。

### 手动迁移

如果需要手动执行迁移：

```bash
# 使用 psql 执行迁移脚本
psql -U postgres -d linku_db -f backend/migrations/030_add_student_verification_tables.sql
```

或者通过 Python 脚本执行：

```python
from app.database import sync_engine
from app.db_migrations import run_migrations

run_migrations(sync_engine, force=False)
```

## 2. 初始化大学数据

执行以下命令初始化大学数据（从 `scripts/university_email_domains.json` 导入）：

```bash
cd backend
python scripts/init_universities.py
```

或者：

```bash
python -m backend.scripts.init_universities
```

## 3. 验证安装

### 检查数据库表

```sql
-- 检查表是否存在
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('universities', 'student_verifications', 'verification_history');

-- 检查大学数据
SELECT COUNT(*) FROM universities;
```

### 检查API接口

启动应用后，访问以下接口验证：

- `GET /api/student-verification/universities` - 获取大学列表
- `GET /api/student-verification/status` - 查询认证状态（需要登录）

## 4. 功能说明

### 核心接口

1. **提交认证申请**
   - `POST /api/student-verification/submit`
   - 需要登录，提供学生邮箱

2. **验证邮箱**
   - `GET /api/student-verification/verify/{token}`
   - 通过邮件中的链接访问

3. **查询认证状态**
   - `GET /api/student-verification/status`
   - 返回认证信息，包括 `renewable_from` 字段

4. **申请续期**
   - `POST /api/student-verification/renew`
   - 过期前30天内可以续期

5. **更换邮箱**
   - `POST /api/student-verification/change-email`
   - 已验证用户可以更换邮箱

6. **获取大学列表**
   - `GET /api/student-verification/universities`
   - 支持搜索和分页

### 核心优化

1. **续期窗口提前到8月1日**
   - 8月1日~10月1日期间认证的，过期时间为次年10月1日
   - 覆盖英国A-Level放榜后的早期用户

2. **续期开始时间字段**
   - `/status` 接口返回 `renewable_from` 字段
   - 表示从哪天开始可以续期（过期前30天）

## 5. 注意事项

1. **邮箱唯一性**
   - 邮箱唯一性在应用层实现，允许过期后立即释放
   - 同一邮箱在同一时间只能被一个用户使用

2. **验证令牌**
   - 令牌存储在 Redis（15分钟TTL）和数据库（用于审计）
   - 验证时使用原子操作（GETDEL）确保一次性使用

3. **过期时间计算**
   - 使用 `calculate_expires_at` 函数计算
   - 8月1日~10月1日认证 → 次年10月1日过期
   - 其他时间 → 最近的下一个10月1日过期

4. **部分唯一索引**
   - `unique_user_active` 确保同一用户只能有一个活跃认证
   - 使用 PostgreSQL 的部分唯一索引实现

## 6. 故障排查

### 迁移失败

如果迁移失败，检查：
1. 数据库连接是否正常
2. 是否有足够的权限创建表和索引
3. 检查迁移记录表 `schema_migrations`

### 大学数据未导入

如果大学数据未导入：
1. 检查 `scripts/university_email_domains.json` 文件是否存在
2. 检查数据库连接
3. 查看脚本输出的错误信息

### API接口错误

如果API接口返回错误：
1. 检查数据库表是否创建成功
2. 检查路由是否已注册（`main.py`）
3. 查看应用日志

## 7. 测试

### 运行测试脚本

```bash
cd backend
python scripts/test_student_verification.py
```

测试脚本会验证：
- 过期时间计算函数（8月1日优化）
- 续期开始时间计算
- 续期判断逻辑
- 数据库模型和表结构

## 8. 定时任务

### 已实现的定时任务

1. **处理过期认证** (`process_expired_verifications`)
   - 执行频率：每小时
   - 作用：批量处理过期记录（兜底机制）
   - 位置：
     - `backend/app/scheduled_tasks.py`
     - `backend/app/celery_tasks.py` (Celery包装)
     - `backend/app/celery_app.py` (Celery Beat配置)
     - `backend/app/task_scheduler.py` (TaskScheduler注册)

### 已实现的定时任务

- [x] 过期提醒邮件（30天、7天、1天前）
- [x] 过期通知邮件（过期当天）

**实现位置**：
- `backend/app/scheduled_tasks.py` - 核心逻辑
- `backend/app/celery_tasks_expiry.py` - Celery任务包装
- `backend/app/celery_app.py` - Celery Beat配置
- `backend/app/email_templates_student_verification.py` - 邮件模板

**执行时间**：
- 30天前提醒：每天凌晨2:00
- 7天前提醒：每天凌晨2:05
- 1天前提醒：每天凌晨2:10
- 过期通知：每天凌晨2:15

## 9. 后续工作

- [ ] 添加监控和日志
- [ ] 性能优化（大学匹配缓存）
- [ ] API限流（针对学生认证接口）

