# AdminDashboard 重构计划

## 当前状态
- **文件大小**: 540KB
- **行数**: 12,571 行
- **状态变量**: 177 个
- **主要模块**: 18 个

## 问题
1. 文件过大，难以维护
2. 过多的状态变量和逻辑混合在一起
3. 代码复用困难
4. 性能问题（所有模块都在一个组件中）

## 重构策略

### 阶段 1：创建共享组件和hooks（高优先级）

#### 1.1 创建共享 hooks
```
admin/src/hooks/
  ├── useAdminTable.ts      - 通用表格逻辑（分页、筛选、排序）
  ├── useModalForm.ts       - 通用模态框表单逻辑
  └── useAdminApi.ts        - 统一的 API 调用逻辑
```

#### 1.2 创建共享组件
```
admin/src/components/admin/
  ├── AdminTable.tsx        - 通用表格组件
  ├── AdminModal.tsx        - 通用模态框组件
  ├── AdminPagination.tsx   - 分页组件
  └── StatusBadge.tsx       - 状态标签组件
```

### 阶段 2：按功能模块拆分（中优先级）

#### 2.1 优惠券管理模块
```
admin/src/pages/admin/coupons/
  ├── CouponManagement.tsx     - 主组件
  ├── CouponForm.tsx           - 表单组件
  ├── CouponTable.tsx          - 表格组件
  └── useCouponForm.ts         - 表单逻辑 hook
```

**字段数据结构优化**：
- `points_required`: 顶层字段（已添加到模型）
- `applicable_scenarios`: 顶层字段（已添加到模型）
- `usage_conditions`: JSONB 字段存储详细配置
  - `task_types`: 适用的任务类型
  - `locations`: 地点限制
  - `excluded_task_types`: 排除的任务类型
  - `min_task_amount`: 最低任务金额
  - `max_task_amount`: 最高任务金额

#### 2.2 其他主要模块
每个模块使用类似的结构：

1. **用户管理** (`admin/src/pages/admin/users/`)
2. **专家管理** (`admin/src/pages/admin/experts/`)
3. **纠纷管理** (`admin/src/pages/admin/disputes/`)
4. **退款管理** (`admin/src/pages/admin/refunds/`)
5. **通知管理** (`admin/src/pages/admin/notifications/`)
6. **邀请码管理** (`admin/src/pages/admin/invitations/`)
7. **论坛管理** (`admin/src/pages/admin/forum/`)
8. **跳蚤市场** (`admin/src/pages/admin/flea-market/`)
9. **排行榜** (`admin/src/pages/admin/leaderboard/`)
10. **Banner管理** (`admin/src/pages/admin/banners/`)
11. **举报管理** (`admin/src/pages/admin/reports/`)

### 阶段 3：创建主框架（低优先级）

#### 3.1 创建 AdminLayout
```tsx
admin/src/layouts/AdminLayout.tsx
  - 侧边栏导航
  - 顶部栏
  - 面包屑
  - 用户菜单
```

#### 3.2 创建路由配置
```tsx
admin/src/routes/adminRoutes.tsx
  - 使用 React Router 的路由配置
  - 懒加载各个模块
```

#### 3.3 更新 AdminDashboard.tsx
将 AdminDashboard.tsx 从一个巨大的组件转变为一个路由容器：

```tsx
// 新的 AdminDashboard.tsx 结构
import { Routes, Route } from 'react-router-dom';
import { AdminLayout } from '../layouts/AdminLayout';

// 懒加载各个模块
const Dashboard = lazy(() => import('./dashboard/Dashboard'));
const CouponManagement = lazy(() => import('./coupons/CouponManagement'));
const UserManagement = lazy(() => import('./users/UserManagement'));
// ... 其他模块

export const AdminDashboard = () => {
  return (
    <AdminLayout>
      <Suspense fallback={<Loading />}>
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/coupons" element={<CouponManagement />} />
          <Route path="/users" element={<UserManagement />} />
          {/* ... 其他路由 */}
        </Routes>
      </Suspense>
    </AdminLayout>
  );
};
```

## 实施顺序

### 立即执行（已完成）
✅ 1. 添加 `points_required` 和 `applicable_scenarios` 字段到模型
✅ 2. 创建数据库迁移文件
✅ 3. 更新后端 schemas
✅ 4. 优化前端优惠券表单 UI（添加折叠功能）

### 短期目标（1-2天）
⏳ 5. 创建共享的 hooks 和组件
⏳ 6. 提取优惠券管理模块（作为示例）
⏳ 7. 测试优惠券模块的独立性

### 中期目标（1周）
⏳ 8. 逐步提取其他模块
⏳ 9. 创建 AdminLayout 框架
⏳ 10. 配置路由系统

### 长期目标（2周）
⏳ 11. 完全迁移所有模块
⏳ 12. 删除旧的 AdminDashboard.tsx 代码
⏳ 13. 性能优化和测试

## 优势

### 性能优势
- 懒加载：只加载当前需要的模块
- 减少重渲染：模块之间状态隔离
- 代码分割：减小初始包体积

### 开发体验
- 代码更易维护和理解
- 模块独立，测试更容易
- 团队协作更高效（不同人可以同时编辑不同模块）

### 可扩展性
- 添加新功能更容易
- 组件复用性提高
- 更容易实现功能权限控制

## 风险和注意事项

1. **迁移过程中的向后兼容**
   - 保持旧的 API 接口不变
   - 逐步迁移，确保每个模块都能独立工作

2. **状态管理**
   - 考虑使用 Context API 或状态管理库（如 Zustand）来共享全局状态
   - 避免 prop drilling

3. **测试**
   - 每个模块提取后都要进行完整测试
   - 确保 API 调用正常工作

## 当前进度

### 已完成
- ✅ 数据库字段对齐（`points_required`, `applicable_scenarios`）
- ✅ 优惠券表单 UI 优化（添加折叠分组）
- ✅ 创建目录结构
- ✅ 创建 CouponManagement 组件框架

### 下一步
1. 提取完整的优惠券表单组件
2. 创建共享的 hooks
3. 创建共享的表格组件
4. 测试优惠券模块

## 估算工作量

- 阶段 1（共享组件）: 2-3 天
- 阶段 2（模块拆分）: 5-7 天
- 阶段 3（主框架）: 2-3 天
- 测试和优化: 2-3 天

**总计**: 约 2-3 周完成完整重构
