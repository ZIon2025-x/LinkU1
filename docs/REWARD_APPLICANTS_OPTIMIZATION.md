# 奖励申请者功能优化总结

## 概述
本文档总结了奖励申请者功能的完善和优化工作，包括积分奖励、现金奖励、积分返还等功能的实现和优化。

## 功能实现

### 1. 积分奖励功能

#### 1.1 创建活动时预扣积分
- **位置**：`backend/app/multi_participant_routes.py::create_expert_activity`
- **逻辑**：
  - 计算需要预扣的积分总额 = 每人积分奖励 × 最大参与人数
  - 使用 `SELECT FOR UPDATE` 锁定积分账户，防止并发问题
  - 检查积分余额是否足够
  - 创建 `spend` 类型的积分交易记录
  - 保存预扣积分总额到 `reserved_points_total` 字段

#### 1.2 任务完成时发放积分奖励
- **位置**：`backend/app/routers.py::confirm_task_completion`
- **逻辑**：
  - 检查任务是否关联活动
  - 检查活动是否设置了奖励申请者积分
  - 使用幂等键防止重复发放
  - 发放积分给任务接受者
  - 更新活动的 `distributed_points_total` 字段
  - 发送通知给申请者

#### 1.3 删除活动时返还积分
- **位置**：`backend/app/multi_participant_routes.py::delete_expert_activity`
- **逻辑**：
  - 计算应返还的积分 = 预扣积分 - 已发放积分
  - 如果应返还积分 > 0，创建 `refund` 类型的积分交易记录
  - 返还积分给活动创建者（达人）

### 2. 现金奖励功能（新增）

#### 2.1 任务完成时发放现金奖励
- **位置**：`backend/app/routers.py::confirm_task_completion`
- **逻辑**：
  - 检查活动是否设置了现金奖励（`applicant_reward_amount`）
  - 使用幂等键防止重复发放
  - 检查任务接受者是否有 Stripe Connect 账户
  - 验证 Stripe Connect 账户状态（已完成设置且已启用收款）
  - 执行 Stripe Transfer 转账现金奖励
  - 创建转账记录到数据库
  - 发送通知给申请者

### 3. 管理员删除活动时的积分返还（优化）

#### 3.1 问题
- 管理员删除活动时没有处理积分返还逻辑

#### 3.2 优化
- **位置**：`backend/app/routers.py::delete_expert_activity_admin`
- **逻辑**：
  - 在删除活动前，检查是否有预扣积分
  - 计算应返还的积分 = 预扣积分 - 已发放积分
  - 如果应返还积分 > 0，创建 `refund` 类型的积分交易记录
  - 返还积分给活动创建者（达人）
  - 记录详细的日志信息

## 优化内容

### 1. 现金奖励发放
- ✅ 添加了现金奖励的发放逻辑
- ✅ 使用 Stripe Transfer 转账现金奖励
- ✅ 验证 Stripe Connect 账户状态
- ✅ 使用幂等键防止重复发放
- ✅ 创建转账记录到数据库

### 2. 通知功能
- ✅ 积分奖励发放时发送通知
- ✅ 现金奖励发放时发送通知
- ✅ 包含推送通知和数据库通知

### 3. 错误处理
- ✅ 完善的错误处理和日志记录
- ✅ 奖励发放失败不影响任务完成流程
- ✅ 详细的错误信息记录

### 4. 管理员删除活动
- ✅ 添加了积分返还逻辑
- ✅ 与普通用户删除活动保持一致的处理逻辑

## 数据库字段

### Activity 表相关字段
- `reward_applicants` (Boolean): 是否奖励申请者
- `applicant_reward_amount` (DECIMAL): 申请者现金奖励金额
- `applicant_points_reward` (BigInteger): 申请者积分奖励
- `reserved_points_total` (BigInteger): 预扣积分总额
- `distributed_points_total` (BigInteger): 已发放积分总额

## 积分交易类型

1. **spend** (`activity_points_reserve`): 创建活动时预扣积分
2. **earn** (`activity_applicant_reward`): 任务完成时发放积分奖励
3. **refund** (`activity_points_refund`): 删除活动时返还未使用的积分

## 通知类型

1. **activity_reward_points**: 活动奖励积分已发放
2. **activity_reward_cash**: 活动现金奖励已发放

## 幂等性保证

所有奖励发放操作都使用幂等键，防止重复发放：

- 积分奖励：`activity_reward_points_{activity_id}_{task_id}_{user_id}`
- 现金奖励：`activity_reward_cash_{activity_id}_{task_id}_{user_id}`
- 积分返还：`activity_refund_{activity_id}_{refund_points}`

## 测试建议

1. **积分奖励测试**：
   - 创建带积分奖励的活动，检查预扣是否正确
   - 完成任务后检查积分是否发放
   - 删除活动后检查积分是否返还

2. **现金奖励测试**：
   - 创建带现金奖励的活动
   - 完成任务后检查现金是否转账
   - 检查通知是否正确发送

3. **并发测试**：
   - 多个任务同时完成，检查积分发放是否正确
   - 检查幂等性是否有效

4. **错误处理测试**：
   - 测试积分余额不足的情况
   - 测试 Stripe Connect 账户未设置的情况
   - 测试转账失败的情况

## 相关文件

- `backend/app/multi_participant_routes.py`：活动创建和删除
- `backend/app/routers.py`：任务完成和奖励发放
- `backend/app/models.py`：Activity 模型定义
- `backend/migrations/056_add_reward_applicants_to_activities.sql`：数据库迁移

## 后续优化建议

1. **统计功能**：添加积分奖励和现金奖励的统计信息
2. **监控**：添加奖励发放的监控指标
3. **配置化**：将奖励相关配置（如最大奖励金额）配置化
4. **批量处理**：优化批量发放奖励的性能
5. **审计日志**：添加更详细的奖励发放审计日志
