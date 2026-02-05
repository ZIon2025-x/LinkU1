# 🚀 AdminDashboard 重构 - 快速开始

## 5分钟上手指南

### 📦 新增的工具

#### 1. Hooks

```typescript
// 表格数据管理
import { useAdminTable } from './hooks';

const table = useAdminTable({
  fetchData: async ({ page, pageSize, filters }) => ({
    data: [...],
    total: 100,
  }),
});

// 使用
<AdminTable data={table.data} loading={table.loading} />
<AdminPagination {...table} />
```

```typescript
// 表单管理
import { useModalForm } from './hooks';

const modal = useModalForm({
  initialValues: { name: '', email: '' },
  onSubmit: async (values, isEdit) => {
    await saveApi(values);
  },
});

// 使用
<button onClick={() => modal.open()}>创建</button>
<button onClick={() => modal.open(editData)}>编辑</button>
<AdminModal isOpen={modal.isOpen} onClose={modal.close}>
  <input value={modal.formData.name}
         onChange={(e) => modal.updateField('name', e.target.value)} />
</AdminModal>
```

```typescript
// API 调用
import { useAdminApi } from './hooks';

const { execute, loading } = useAdminApi({
  apiFunction: deleteItem,
  successMessage: '删除成功',
  onSuccess: () => table.refresh(),
});

await execute(itemId);
```

#### 2. 组件

```typescript
import {
  AdminTable,
  AdminModal,
  AdminPagination,
  StatusBadge
} from './components/admin';

// 表格
<AdminTable
  columns={[
    { key: 'id', title: 'ID', dataIndex: 'id' },
    { key: 'name', title: '名称', dataIndex: 'name' },
  ]}
  data={data}
  loading={loading}
/>

// 状态标签
<StatusBadge text="激活" variant="success" />
<StatusBadge text="停用" variant="secondary" />
```

### 📝 创建新模块（3步）

#### 步骤 1: 创建文件结构

```bash
mkdir -p admin/src/pages/admin/my-module
cd admin/src/pages/admin/my-module

touch MyModule.tsx
touch types.ts
touch MyModule.module.css
touch index.ts
```

#### 步骤 2: 编写代码

**types.ts**
```typescript
export interface MyData {
  id: number;
  name: string;
  status: 'active' | 'inactive';
}
```

**MyModule.tsx**
```typescript
import React from 'react';
import { useAdminTable } from '../../../hooks';
import { AdminTable, AdminPagination } from '../../../components/admin';
import { MyData } from './types';
import styles from './MyModule.module.css';

export const MyModule: React.FC = () => {
  const table = useAdminTable<MyData>({
    fetchData: async ({ page, pageSize }) => {
      const res = await fetch(`/api/my-data?page=${page}&limit=${pageSize}`);
      const data = await res.json();
      return { data: data.items, total: data.total };
    },
  });

  const columns = [
    { key: 'id', title: 'ID', dataIndex: 'id' },
    { key: 'name', title: '名称', dataIndex: 'name' },
  ];

  return (
    <div className={styles.container}>
      <h2>我的模块</h2>
      <AdminTable columns={columns} data={table.data} loading={table.loading} />
      <AdminPagination {...table} />
    </div>
  );
};
```

**index.ts**
```typescript
export { MyModule } from './MyModule';
```

#### 步骤 3: 添加路由

在 `admin/src/routes/adminRoutes.tsx`:

```typescript
const MyModule = lazy(() => import('../pages/admin/my-module').then(m => ({ default: m.MyModule })));

// 在 Routes 中添加
<Route path="/my-module" element={<MyModule />} />
```

在 `admin/src/layouts/AdminLayout.tsx` 的 `defaultMenuItems` 中添加菜单项：

```typescript
{
  key: 'my-module',
  label: '我的模块',
  icon: '📦',
  path: '/admin/my-module',
}
```

### ✅ 完成！

访问 `/admin/my-module` 即可看到你的新模块。

## 🔍 常见模式

### 带筛选的表格

```typescript
const [statusFilter, setStatusFilter] = useState('');

const table = useAdminTable({
  fetchData: async ({ page, pageSize, filters }) => {
    const res = await api.get('/data', {
      params: { page, limit: pageSize, status: filters.status }
    });
    return { data: res.data.items, total: res.data.total };
  },
});

// 更新筛选
const handleFilterChange = (status: string) => {
  setStatusFilter(status);
  table.setFilters({ status });
};
```

### 带创建/编辑的表格

```typescript
const table = useAdminTable({ ... });

const modal = useModalForm({
  initialValues: { name: '', email: '' },
  onSubmit: async (values, isEdit) => {
    if (isEdit) {
      await updateApi(values.id, values);
    } else {
      await createApi(values);
    }
    table.refresh();
  },
});

// 按钮
<button onClick={() => modal.open()}>创建</button>
<button onClick={() => modal.open(record)}>编辑</button>
```

### 删除操作

```typescript
const handleDelete = async (id: number) => {
  if (!window.confirm('确定要删除吗？')) return;

  try {
    await deleteApi(id);
    message.success('删除成功');
    table.refresh();
  } catch (error) {
    message.error('删除失败');
  }
};
```

## 📖 更多信息

- 完整指南: [REFACTORING_GUIDE.md](./REFACTORING_GUIDE.md)
- 项目总结: [REFACTORING_SUMMARY.md](./REFACTORING_SUMMARY.md)
- 原始计划: [REFACTORING_PLAN.md](./REFACTORING_PLAN.md)

## 🆘 遇到问题？

1. 查看优惠券模块示例: `admin/src/pages/admin/coupons/`
2. 阅读 Hooks 源码中的注释
3. 查看 REFACTORING_GUIDE.md 的"常见问题"部分

---

**Happy Coding! 🎉**
