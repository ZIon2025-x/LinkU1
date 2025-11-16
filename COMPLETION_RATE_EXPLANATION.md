# 任务达人完成率计算说明

## 完成率计算公式

完成率 = (完成的接受任务数 / 接受过的任务数) × 100%

### 详细说明

1. **完成的接受任务数** (`completed_taken_tasks`)：
   - 统计用户作为 `taker_id`（接受者）且状态为 `completed` 的任务数量
   - 查询条件：`Task.taker_id == user_id AND Task.status == "completed"`

2. **接受过的任务数** (`taken_tasks`)：
   - 统计用户作为 `taker_id`（接受者）的所有任务数量
   - 包括所有状态的任务（open, taken, in_progress, completed, cancelled等）
   - 查询条件：`Task.taker_id == user_id`

3. **计算公式**：
   ```python
   completion_rate = (completed_taken_tasks / taken_tasks * 100.0) if taken_tasks > 0 else 0.0
   ```

### 代码位置

- **后端计算逻辑**：
  - `backend/app/crud.py` 第93行：`update_user_statistics` 函数
  - `backend/app/crud.py` 第216行：`update_task_expert_bio` 函数
  - `backend/app/routers.py` 第1743行：`user_profile` 函数

- **前端显示**：
  - `frontend/src/pages/TaskExperts.tsx` 第995行：显示 `{expert.completion_rate}%`

### 注意事项

1. **分母不包括发布的任务**：完成率只计算作为接受者的任务，不包括作为发布者的任务
2. **包括已取消的任务**：接受过的任务数包括所有状态的任务，包括已取消的任务
3. **零除保护**：如果用户从未接受过任务（`taken_tasks == 0`），完成率默认为 `0.0`
4. **数据更新时机**：
   - 任务状态变更为 `completed` 时，会调用 `update_user_statistics` 更新完成率
   - 任务达人更新 bio 时，会调用 `update_task_expert_bio` 更新完成率

### 示例

假设一个任务达人：
- 接受了 10 个任务（`taken_tasks = 10`）
- 完成了 8 个任务（`completed_taken_tasks = 8`）
- 完成率 = (8 / 10) × 100% = 80%

