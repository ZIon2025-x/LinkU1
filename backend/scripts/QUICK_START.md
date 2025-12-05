# 学生认证系统快速启动指南

## 🚀 快速部署（3步）

### 前置条件：安装依赖

```bash
cd backend
pip install -r requirements.txt
```

**重要说明**：
- `pyahocorasick` 已在 `requirements.txt` 中（可选，推荐）
- 用于学生认证系统性能优化，提升大学匹配性能10倍+
- 如果不安装，系统会自动回退到字典匹配

### 步骤1：执行数据库迁移

系统启动时会自动执行迁移脚本（如果 `AUTO_MIGRATE=true`）。

如果需要手动执行：

```bash
# 方式1：使用 psql
psql -U postgres -d linku_db -f backend/migrations/030_add_student_verification_tables.sql

# 方式2：使用 Python（推荐）
cd backend
python -c "from app.database import sync_engine; from app.db_migrations import run_migrations; run_migrations(sync_engine, force=False)"
```

### 步骤2：初始化大学数据

```bash
cd backend
python scripts/init_universities.py
```

### 步骤3：验证安装

```bash
# 运行测试脚本
python scripts/test_student_verification.py

# 或检查API接口
curl http://localhost:8000/api/student-verification/universities
```

## ✅ 验证清单

- [ ] 数据库表已创建（`universities`, `student_verifications`, `verification_history`）
- [ ] 大学数据已导入（检查 `SELECT COUNT(*) FROM universities;`）
- [ ] API接口可访问（`GET /api/student-verification/universities`）
- [ ] 测试脚本通过（`test_student_verification.py`）

## 📋 API接口列表

### 用户接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/student-verification/status` | GET | 查询认证状态（包含 `renewable_from`） |
| `/api/student-verification/submit` | POST | 提交认证申请 |
| `/api/student-verification/verify/{token}` | GET | 验证邮箱 |
| `/api/student-verification/renew` | POST | 申请续期 |
| `/api/student-verification/change-email` | POST | 更换邮箱 |
| `/api/student-verification/universities` | GET | 获取大学列表 |

### 管理接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/admin/student-verification/{id}/revoke` | POST | 撤销认证 |
| `/api/admin/student-verification/{id}/extend` | POST | 延长认证 |

## 🔧 环境变量配置

确保以下环境变量已配置：

```env
# 数据库
DATABASE_URL=postgresql+psycopg2://user:password@host:port/dbname

# Redis（可选，用于令牌存储）
REDIS_URL=redis://localhost:6379/0
USE_REDIS=true

# 邮件服务（必需）
EMAIL_FROM=no-reply@link2ur.com
# 使用 Resend（推荐）
USE_RESEND=true
RESEND_API_KEY=your-resend-api-key
# 或使用 SendGrid
USE_SENDGRID=true
SENDGRID_API_KEY=your-sendgrid-api-key

# 前端URL（用于生成验证链接）
FRONTEND_URL=https://www.link2ur.com
```

## 🎯 核心功能

### 1. 续期窗口提前到8月1日

- **8月1日~10月1日**期间认证的，过期时间为**次年10月1日**
- 覆盖英国A-Level放榜后的早期用户

### 2. 续期开始时间字段

- `/status` 接口返回 `renewable_from` 字段
- 表示从哪天开始可以续期（过期前30天）

## 📝 使用示例

### 提交认证申请

```bash
curl -X POST http://localhost:8000/api/student-verification/submit \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"email": "student@bristol.ac.uk"}'
```

### 查询认证状态

```bash
curl http://localhost:8000/api/student-verification/status \
  -H "Authorization: Bearer YOUR_TOKEN"
```

响应示例：
```json
{
  "code": 200,
  "data": {
    "is_verified": true,
    "status": "verified",
    "university": {
      "id": 1,
      "name": "University of Bristol",
      "name_cn": "布里斯托大学"
    },
    "email": "student@bristol.ac.uk",
    "expires_at": "2026-10-01T00:00:00Z",
    "days_remaining": 28,
    "can_renew": true,
    "renewable_from": "2026-09-01T00:00:00Z"
  }
}
```

## 🐛 常见问题

### Q: 迁移失败怎么办？

A: 检查：
1. 数据库连接是否正常
2. 是否有足够的权限
3. 查看迁移记录表 `schema_migrations`

### Q: 大学数据未导入？

A: 检查：
1. `scripts/university_email_domains.json` 文件是否存在
2. 数据库连接是否正常
3. 查看脚本输出的错误信息

### Q: API接口返回404？

A: 检查：
1. 路由是否已注册（`main.py`）
2. 应用是否正常启动
3. 查看应用日志

### Q: 邮件发送失败？

A: 检查：
1. 邮件服务配置是否正确（Resend/SendGrid）
2. API Key是否有效
3. `EMAIL_FROM` 是否配置
4. 查看邮件发送日志

## 📚 更多信息

详细文档请参考：`backend/scripts/README_STUDENT_VERIFICATION.md`

