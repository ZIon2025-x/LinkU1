# Tasks.tsx 优化指南

## 当前问题

1. **文件过大**：3615行代码，难以维护
2. **大量内联样式**：影响可读性和性能
3. **重复逻辑**：排序、筛选等逻辑可以复用
4. **缺少组件拆分**：所有UI都在一个文件中

## 已完成的优化

### 1. 提取的组件
- ✅ `TaskCard.tsx` - 任务卡片组件（已创建并在 Tasks.tsx 中使用）
- ✅ `SortControls.tsx` - 排序控制组件（已创建并在 Tasks.tsx 中使用）
- ✅ `CategoryIcons.tsx` - 分类图标组件（已创建并在 Tasks.tsx 中使用）

### 2. 提取的 Hooks
- ✅ `useTaskSorting.ts` - 排序逻辑 hook（已创建）
- ✅ `useTaskFilters.ts` - 筛选逻辑 hook（已创建）

### 3. 样式文件
- ✅ `Tasks.styles.ts` - 样式常量（已创建）

## 建议的优化步骤

### 步骤 1: 使用已创建的组件和 Hooks

在 `Tasks.tsx` 中替换现有代码：

```typescript
// 导入新组件和 hooks
import TaskCard from '../components/TaskCard';
import { useTaskSorting } from '../hooks/useTaskSorting';
import { useTaskFilters } from '../hooks/useTaskFilters';
import { injectTasksStyles } from '../styles/Tasks.styles';

// 在组件中使用
const Tasks: React.FC = () => {
  // 注入样式（只需调用一次）
  useEffect(() => {
    injectTasksStyles();
  }, []);

  // 使用排序 hook
  const sorting = useTaskSorting(loadTasks);
  
  // 使用筛选 hook
  const filters = useTaskFilters(t('tasks.levels.all'));
  
  // ... 其他代码
  
  // 在渲染中使用 TaskCard
  {filteredTasks.map(task => (
    <TaskCard
      key={task.id}
      task={task}
      isMobile={isMobile}
      language={language}
      onViewTask={handleViewTask}
      getTaskTypeLabel={getTaskTypeLabel}
      getRemainTime={getRemainTime}
      isExpired={isExpired}
      isExpiringSoon={isExpiringSoon}
      getTaskLevelColor={getTaskLevelColor}
      getTaskLevelLabel={getTaskLevelLabel}
      t={t}
    />
  ))}
}
```

### 步骤 2: 提取更多组件（待完成）

#### SortControls 组件
- 包含所有排序按钮（最新、金额、截止时间）
- 使用 `useTaskSorting` hook

#### CategoryIcons 组件
- 包含任务类型图标行
- 可复用，减少重复代码

#### TaskHeader 组件
- 顶部导航栏
- Logo、位置选择、通知按钮等

### 步骤 3: 性能优化

1. **使用 React.memo**
   - TaskCard 已使用 React.memo
   - 其他组件也应该使用

2. **优化 useMemo**
   - `filteredTasks` 已使用 useMemo
   - 确保依赖项正确

3. **懒加载**
   - 考虑使用 React.lazy 加载大型组件

### 步骤 4: 代码清理

1. **移除未使用的导入**
2. **提取常量**
   - TASK_TYPES, CITIES 已提取
   - 其他常量也可以提取

3. **统一错误处理**
   - 创建统一的错误处理函数

## 优化结果

优化完成：
- ✅ 主文件从 3615 行减少到 2383 行（减少约 1232 行，34%）
- ✅ 代码可维护性提升
- ✅ 组件可复用性提升
- ✅ 性能优化（React.memo, useMemo）
- ✅ 样式管理更清晰
- ✅ 所有组件已提取并在 Tasks.tsx 中使用

## 注意事项

1. 保持向后兼容
2. 确保所有功能正常工作
3. 逐步迁移，不要一次性修改太多
4. 测试每个提取的组件

