# 学生认证系统初始化指南

## 📋 初始化方式

### 📦 前置条件

**安装依赖**（如果尚未安装）：
```bash
cd backend
pip install -r requirements.txt
```

**重要依赖说明**：
- `pyahocorasick` - 学生认证系统性能优化（可选，推荐）
  - 用于大学匹配缓存优化，性能提升10倍+
  - 如果不安装，系统会自动回退到字典匹配
  - 已在 `requirements.txt` 中，部署时会自动安装

### ✅ 方式1：自动初始化（推荐）

**系统会在启动时自动完成以下初始化：**

1. **数据库迁移**（自动执行）
   - 应用启动时自动执行所有迁移脚本
   - 通过 `AUTO_MIGRATE` 环境变量控制（默认：`true`）
   - 迁移脚本：`backend/migrations/030_add_student_verification_tables.sql`

2. **大学数据初始化**（自动执行）
   - 应用启动时检测 `universities` 表是否为空
   - 如果为空，自动从 `scripts/university_email_domains.json` 导入数据
   - 如果已有数据，跳过初始化

**无需手动操作！** 只需启动应用即可。

### 📝 方式2：手动初始化（可选）

如果需要手动控制初始化过程：

#### 步骤1：执行数据库迁移

```bash
# 方式1：使用 psql
psql -U postgres -d linku_db -f backend/migrations/030_add_student_verification_tables.sql

# 方式2：使用 Python
cd backend
python -c "from app.database import sync_engine; from app.db_migrations import run_migrations; run_migrations(sync_engine, force=False)"
```

#### 步骤2：初始化大学数据

```bash
cd backend
python scripts/init_universities.py
```

## 🔧 环境变量配置

### 自动迁移控制

```env
# 启用自动迁移（默认）
AUTO_MIGRATE=true

# 禁用自动迁移
AUTO_MIGRATE=false
```

**注意**：即使禁用自动迁移，大学数据初始化仍会在启动时自动执行（如果表为空）。

## 📊 初始化检查

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

```bash
# 获取大学列表
curl http://localhost:8000/api/student-verification/universities

# 查询认证状态（需要登录）
curl http://localhost:8000/api/student-verification/status \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## 🚀 部署流程

### 首次部署

1. **设置环境变量**
   ```env
   AUTO_MIGRATE=true  # 启用自动迁移（默认）
   DATABASE_URL=postgresql+psycopg2://...
   ```

2. **启动应用**
   ```bash
   python -m uvicorn app.main:app --reload
   ```

3. **查看日志**
   - 检查是否有 "数据库迁移执行完成！" 日志
   - 检查是否有 "大学数据自动初始化完成！" 或 "大学数据已存在" 日志

### 后续部署

- **数据库迁移**：自动执行（只执行未执行的迁移）
- **大学数据**：自动检测，如果表为空则初始化

## ⚠️ 注意事项

1. **自动初始化条件**
   - 大学数据只在表**完全为空**时自动初始化
   - 如果表中已有部分数据，不会自动初始化
   - 此时需要手动运行 `init_universities.py` 补充数据

2. **迁移幂等性**
   - 所有迁移脚本都具有幂等性
   - 可以安全地多次执行
   - 已执行的迁移不会重复执行

3. **错误处理**
   - 迁移失败不会阻止应用启动
   - 大学数据初始化失败会记录警告日志
   - 建议查看日志确认初始化状态

## 🔍 故障排查

### 问题1：迁移未执行

**症状**：表不存在或结构不完整

**解决方案**：
1. 检查 `AUTO_MIGRATE` 环境变量是否为 `true`
2. 查看应用启动日志，确认迁移是否执行
3. 手动执行迁移脚本

### 问题2：大学数据未初始化

**症状**：`universities` 表为空

**解决方案**：
1. 检查 `scripts/university_email_domains.json` 文件是否存在
2. 查看应用启动日志，确认初始化是否执行
3. 手动运行 `python backend/scripts/init_universities.py`

### 问题3：部分大学数据缺失

**症状**：表中只有部分大学数据

**解决方案**：
- 手动运行 `init_universities.py`，脚本会自动跳过已存在的记录

## 📚 相关文档

- 快速启动：`backend/scripts/QUICK_START.md`
- 详细文档：`backend/scripts/README_STUDENT_VERIFICATION.md`
- 系统总结：`backend/scripts/SYSTEM_SUMMARY.md`

