# 数据库设计说明：管理员、客服和用户的关系

## 系统中有三个独立的表：

### 1. **users 表**（普通用户）
- **ID 格式**：8位数字（如：`27167013`）
- **用途**：存储平台上的普通用户（发布任务、接受任务的用户）

### 2. **admin_users 表**（管理员）
- **ID 格式**：`A` + 4位数字（如：`A0001`）
- **用途**：存储系统管理员账号
- **位置**：独立的管理员表，**不在 users 表中**

### 3. **customer_service 表**（客服）
- **ID 格式**：`CS` + 4位数字（如：`CS8888`）
- **用途**：存储客服账号
- **位置**：独立的客服表，**不在 users 表中**

## 问题所在

### TaskCancelRequest 表的 `admin_id` 字段设计问题

```python
class TaskCancelRequest(Base):
    admin_id = Column(
        String(8), ForeignKey("users.id"), nullable=True
    )  # 审核的管理员ID
```

**这个设计有两个问题**：

1. **命名误导**：字段名叫 `admin_id`，但实际上管理员ID不在 `users.id` 中
   - 管理员ID在 `admin_users.id`（格式：`A0001`）
   - 但外键却指向 `users.id`（格式：8位数字）

2. **功能限制**：只能存储 `users.id`，无法存储：
   - 管理员ID（`admin_users.id`，格式如 `A0001`）
   - 客服ID（`customer_service.id`，格式如 `CS8888`）

### 实际情况

从代码看，这个字段最初可能设计的用途是：
- 让某个普通用户（在 `users` 表中）充当"审核员"
- 或者设计时认为管理员也在 `users` 表中（但实际没有）

但现在：
- **管理员审核**：管理员ID是 `A0001`（在 `admin_users` 表中），无法存入
- **客服审核**：客服ID是 `CS8888`（在 `customer_service` 表中），也无法存入

## 解决方案

移除外键约束，让 `admin_id` 字段可以存储：
- 管理员ID（格式：`A0001`，来自 `admin_users` 表）
- 客服ID（格式：`CS8888`，来自 `customer_service` 表）
- 或者普通用户ID（格式：8位数字，来自 `users` 表）

这样字段名可以理解为"审核者ID"，而不仅仅是"管理员ID"。

## 其他类似的表

`AdminRequest` 表也有类似的问题：

```python
class AdminRequest(Base):
    admin_id = Column(
        String(8), ForeignKey("users.id"), nullable=True
    )  # 处理的管理员ID
```

这里的管理员ID也指向 `users.id`，但实际管理员在 `admin_users` 表中。

## 总结

这是一个**设计不一致**的问题：
- 管理员和客服都有独立的表
- 但某些外键字段却错误地指向 `users.id`
- 移除外键约束是快速有效的解决方案
- 更完善的方案是重新设计字段名和约束（比如改为 `reviewer_id` 并移除外键）

