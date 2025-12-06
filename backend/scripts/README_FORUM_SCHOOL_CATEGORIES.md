# 论坛学校板块初始化脚本使用说明

## 概述

`init_forum_school_categories.py` 脚本用于自动初始化论坛学校板块功能所需的数据：

1. **为所有英国大学填充编码** (`universities.code` 字段)
2. **为每个英国大学创建对应的论坛板块** (`forum_categories` 表)

## 使用方法

### 前置条件

1. 确保已运行数据库迁移脚本 `032_add_forum_school_access_control.sql`
2. 确保数据库中已有大学数据（可通过 `init_universities.py` 初始化）

### 运行脚本

```bash
# 从项目根目录运行
python backend/scripts/init_forum_school_categories.py

# 或从 backend 目录运行
cd backend
python scripts/init_forum_school_categories.py
```

### 脚本功能

#### 1. 初始化大学编码

脚本会：
- 查询所有英国大学（`country='UK'` 或 `email_domain` 以 `.ac.uk` 结尾）
- 为没有编码的大学自动生成编码
- 使用预定义的编码映射表（如 `bristol.ac.uk` -> `UOB`）
- 如果编码冲突，自动添加后缀避免重复

#### 2. 创建论坛板块

脚本会：
- 为每个有编码的英国大学创建对应的论坛板块
- 板块名称使用大学的中文名称（如果有）或英文名称
- 板块类型设置为 `university`
- 自动关联 `university_code` 字段

#### 3. 数据一致性验证

脚本会：
- 验证所有大学板块都有对应的大学
- 验证所有英国大学都有对应的板块
- 报告任何不一致的问题

## 编码规则

### 预定义编码映射

脚本包含常见英国大学的编码映射：

| 大学 | Email Domain | 编码 |
|------|-------------|------|
| 布里斯托大学 | bristol.ac.uk | UOB |
| 牛津大学 | ox.ac.uk | UOX |
| 剑桥大学 | cam.ac.uk | UCAM |
| 帝国理工学院 | imperial.ac.uk | ICL |
| 伦敦政治经济学院 | lse.ac.uk | LSE |
| ... | ... | ... |

### 自动生成规则

对于没有预定义映射的大学，脚本会：
1. 从 `email_domain` 提取主要部分（去掉 `.ac.uk` 和 `student.` 前缀）
2. 转换为大写作为编码
3. 如果编码太短，从大学名称中提取首字母

示例：
- `leeds.ac.uk` -> `LEED` -> `UOL` (如果冲突)
- `student.gla.ac.uk` -> `GLA` -> `UOG`

## 输出示例

```
============================================================
论坛学校板块初始化脚本
============================================================
开始初始化大学编码...
✓ University of Bristol (bristol.ac.uk) -> UOB
✓ University of Oxford (ox.ac.uk) -> UOX
✓ University of Cambridge (cam.ac.uk) -> UCAM
...
✅ 大学编码初始化完成: 更新 20 个，跳过 5 个
开始初始化论坛学校板块...
✓ 创建板块: 布里斯托大学 (UOB)
✓ 创建板块: 牛津大学 (UOX)
...
✅ 论坛板块初始化完成: 创建 20 个，跳过 0 个
开始验证数据一致性...
✅ 数据一致性验证通过
============================================================
✅ 初始化完成！
============================================================
```

## 注意事项

1. **幂等性**：脚本可以安全地多次运行，已存在的编码和板块会被跳过
2. **编码唯一性**：如果编码冲突，脚本会自动添加后缀（如 `UOB1`, `UOB2`）
3. **数据备份**：在生产环境运行前，建议先备份数据库
4. **手动调整**：如果自动生成的编码不符合要求，可以手动修改数据库

## 手动调整

如果需要手动调整编码或板块：

### 修改大学编码

```sql
UPDATE universities 
SET code = 'YOUR_CODE' 
WHERE email_domain = 'example.ac.uk';
```

### 修改板块信息

```sql
UPDATE forum_categories 
SET name = '新名称', description = '新描述' 
WHERE university_code = 'UOB';
```

### 删除板块

```sql
DELETE FROM forum_categories 
WHERE university_code = 'UOB' AND type = 'university';
```

## 故障排查

### 问题：找不到大学数据

**解决方案**：
1. 先运行 `init_universities.py` 初始化大学数据
2. 确保 `country` 字段已设置为 `'UK'`（迁移脚本会自动设置）

### 问题：编码冲突

**解决方案**：
- 脚本会自动处理冲突，添加后缀
- 如需手动指定编码，可以在运行脚本前先更新数据库

### 问题：板块创建失败

**可能原因**：
- 大学编码未设置
- 数据库约束冲突

**解决方案**：
- 检查日志输出
- 确保已运行数据库迁移脚本
- 检查 `forum_categories` 表的约束

## 相关文件

- `backend/migrations/032_add_forum_school_access_control.sql` - 数据库迁移脚本
- `backend/scripts/init_universities.py` - 大学数据初始化脚本
- `scripts/university_email_domains.json` - 大学数据源文件

