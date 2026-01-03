# 修复 metadata 保留字冲突的部署说明

## 问题

SQLAlchemy 的 Declarative API 中 `metadata` 是保留字，不能用作模型属性名。

错误信息：
```
sqlalchemy.exc.InvalidRequestError: Attribute name 'metadata' is reserved when using the Declarative API.
```

## 修复内容

### 1. 模型定义修复

**文件**: `backend/app/models.py`

将 `PaymentTransfer` 模型中的 `metadata` 列改为 `extra_metadata`：

```python
# 修复前
metadata = Column(JSONB, nullable=True)

# 修复后
extra_metadata = Column(JSONB, nullable=True)  # 使用 extra_metadata 避免与 SQLAlchemy 的 metadata 属性冲突
```

### 2. 代码更新

**文件**: `backend/app/payment_transfer_service.py`

更新 `create_transfer_record` 函数：

```python
transfer_record = models.PaymentTransfer(
    # ...
    extra_metadata=metadata or {}  # 使用 extra_metadata
)
```

### 3. 数据库迁移

如果数据库表已经存在，需要运行迁移文件：

```bash
psql -d your_database -f backend/migrations/043_rename_payment_transfer_metadata.sql
```

如果表还没有创建，使用更新后的迁移文件：

```bash
psql -d your_database -f backend/migrations/041_add_payment_transfer_table.sql
```

## 部署步骤

### 1. 清除 Python 缓存（如果存在）

在部署环境中，清除 Python 缓存文件：

```bash
find . -type d -name __pycache__ -exec rm -r {} +
find . -name "*.pyc" -delete
```

### 2. 确保代码已更新

确认以下文件已更新：
- ✅ `backend/app/models.py` - `PaymentTransfer` 模型使用 `extra_metadata`
- ✅ `backend/app/payment_transfer_service.py` - 使用 `extra_metadata`
- ✅ `backend/migrations/041_add_payment_transfer_table.sql` - 使用 `extra_metadata`

### 3. 运行数据库迁移（如果表已存在）

```bash
psql -d your_database -f backend/migrations/043_rename_payment_transfer_metadata.sql
```

### 4. 重新部署

确保部署环境使用最新的代码，清除所有缓存后重新部署。

## 验证

部署后，验证模型是否可以正常导入：

```python
from app.models import PaymentTransfer
print("✅ PaymentTransfer 模型导入成功")
```

## 相关文件

- `backend/app/models.py` - 模型定义
- `backend/app/payment_transfer_service.py` - 转账服务
- `backend/migrations/041_add_payment_transfer_table.sql` - 初始迁移
- `backend/migrations/043_rename_payment_transfer_metadata.sql` - 重命名迁移

