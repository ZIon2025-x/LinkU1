# 学生认证与用户绑定关系说明

## 📋 绑定关系概述

**是的，学生认证与用户是绑定的。**

学生认证系统设计为**一对一绑定关系**：每个用户账户只能有一个活跃的学生认证。

## 🔗 绑定机制

### 1. 数据库层面

**外键约束**：
```python
user_id = Column(String(8), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
```

**关系定义**：
```python
user = relationship("User", backref="student_verifications")
```

**特点**：
- `user_id` 是必填字段（`nullable=False`）
- 外键约束确保数据完整性
- `ondelete="CASCADE"` 表示删除用户时，其认证记录也会被删除

### 2. 业务逻辑层面

**部分唯一索引**：
```python
Index('idx_student_verifications_unique_user_active', 'user_id', unique=True, 
      postgresql_where=text("status IN ('verified', 'pending')"))
```

**约束规则**：
- 同一用户只能有一个**活跃的**认证（`pending` 或 `verified` 状态）
- 允许有多个**非活跃的**认证记录（`expired` 或 `revoked` 状态，用于历史记录）

### 3. API层面

**所有接口都需要用户认证**：
- `GET /status` - 需要登录，返回当前用户的认证状态
- `POST /submit` - 需要登录，为当前用户提交认证
- `GET /verify/{token}` - 通过令牌验证，但令牌与用户绑定
- `POST /renew` - 需要登录，为当前用户续期
- `POST /change-email` - 需要登录，为当前用户更换邮箱

**用户识别**：
```python
current_user: models.User = Depends(get_current_user_secure_sync_csrf)
```

所有操作都基于当前登录用户，无法为其他用户操作。

## 📊 绑定关系详解

### 一对一关系（活跃认证）

**规则**：
- ✅ 一个用户只能有一个**活跃的**学生认证（`pending` 或 `verified`）
- ✅ 一个学生邮箱在同一时间只能被一个用户验证
- ✅ 用户删除时，其认证记录也会被删除（CASCADE）

**实现方式**：
1. **部分唯一索引**：数据库层面强制约束
2. **业务逻辑检查**：提交前检查是否已有活跃认证
3. **邮箱唯一性检查**：确保邮箱不被其他用户使用

### 历史记录保留

**规则**：
- ✅ 允许保留多个**非活跃的**认证记录（`expired` 或 `revoked`）
- ✅ 这些记录用于审计和历史追踪
- ✅ 不影响新的认证申请

**示例场景**：
```
用户A的认证历史：
1. 2024-01-15: verified (已过期，状态变为 expired)
2. 2025-01-15: verified (当前活跃)
```

## 🔐 安全机制

### 1. 用户身份验证

**所有接口都需要登录**：
- 使用 `get_current_user_secure_sync_csrf` 依赖
- 确保只有登录用户才能操作自己的认证
- 防止未授权访问

### 2. 邮箱唯一性

**全局唯一性**：
- 同一个学生邮箱在同一时间只能被一个用户验证
- 认证过期后，邮箱可以被其他用户重新验证
- 实时检查，确保数据一致性

### 3. 令牌绑定

**令牌与用户绑定**：
- 验证令牌在创建时绑定到特定用户和邮箱
- 验证时检查令牌、邮箱、用户的一致性
- 一次性使用，防止重放攻击

## 📝 使用场景

### 场景1：用户首次认证

```
1. 用户登录系统
2. 提交学生邮箱（如：student@bristol.ac.uk）
3. 系统创建 pending 记录，绑定到该用户
4. 用户点击邮件链接验证
5. 记录状态变为 verified，绑定到该用户
```

### 场景2：用户续期

```
1. 用户登录系统
2. 检查是否有已验证的认证（绑定到该用户）
3. 如果距离过期30天内，允许续期
4. 创建新的 pending 记录，绑定到同一用户
5. 验证后更新为 verified
```

### 场景3：用户更换邮箱

```
1. 用户登录系统
2. 检查是否有已验证的认证（绑定到该用户）
3. 撤销旧认证（状态变为 revoked）
4. 创建新认证（绑定到同一用户）
5. 验证新邮箱
```

### 场景4：用户删除

```
1. 用户账户被删除
2. 数据库 CASCADE 删除该用户的所有认证记录
3. 邮箱立即释放，可以被其他用户使用
```

## 🔍 查询示例

### 查询用户的所有认证记录

```python
# 通过用户ID查询
verifications = db.query(StudentVerification).filter(
    StudentVerification.user_id == user_id
).all()

# 通过关系查询
user = db.query(User).filter(User.id == user_id).first()
verifications = user.student_verifications  # 通过 backref
```

### 查询用户的活跃认证

```python
active_verification = db.query(StudentVerification).filter(
    StudentVerification.user_id == user_id,
    StudentVerification.status.in_(['pending', 'verified'])
).first()
```

## ⚠️ 重要注意事项

### 1. 不能跨用户操作

**限制**：
- ❌ 用户A不能为用户B提交认证
- ❌ 用户A不能查看用户B的认证状态
- ❌ 所有操作都基于当前登录用户

**原因**：
- API接口使用 `current_user` 依赖
- 数据库外键约束
- 业务逻辑检查

### 2. 邮箱可以转移

**规则**：
- ✅ 认证过期后，邮箱可以被其他用户使用
- ✅ 撤销认证后，邮箱立即释放
- ✅ 同一邮箱在不同时间可以被不同用户验证

**示例**：
```
2024年：用户A验证 student@bristol.ac.uk
2025年：用户A的认证过期
2025年：用户B可以验证 student@bristol.ac.uk（如果邮箱被重新分配）
```

### 3. 历史记录保留

**规则**：
- ✅ 过期和撤销的记录不会自动删除
- ✅ 保留用于审计和历史追踪
- ✅ 不影响新的认证申请

## 📊 数据模型关系图

```
User (用户)
  │
  ├── user_id (外键)
  │
  └── StudentVerification (学生认证)
        │
        ├── 一对一关系（活跃认证）
        │   └── 部分唯一索引：user_id + status IN ('pending', 'verified')
        │
        └── 一对多关系（历史记录）
            └── 可以有多个 expired/revoked 记录
```

## ✅ 总结

**学生认证与用户是强绑定的**：

1. **数据库层面**：外键约束 + 部分唯一索引
2. **业务逻辑层面**：所有操作都基于当前登录用户
3. **安全层面**：用户身份验证 + 邮箱唯一性检查

**绑定特点**：
- ✅ 一个用户只能有一个活跃认证
- ✅ 所有操作都需要用户登录
- ✅ 用户删除时，认证记录也会被删除
- ✅ 邮箱可以转移（过期后）
- ✅ 历史记录保留（用于审计）

这种设计确保了：
- **数据完整性**：每个认证都明确绑定到特定用户
- **安全性**：用户只能操作自己的认证
- **灵活性**：邮箱可以在不同用户间转移（过期后）

