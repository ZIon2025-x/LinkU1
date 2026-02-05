import React, { useState } from 'react';
import { message } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, StatusBadge, Column } from '../../../components/admin';
import { getCoupons, createCoupon, updateCoupon, deleteCoupon } from '../../../api';
import { Coupon, CouponForm, initialCouponForm } from './types';
import { CouponFormModal } from './CouponFormModal';
import styles from './CouponManagement.module.css';

export const CouponManagement: React.FC = () => {
  const [statusFilter, setStatusFilter] = useState<string>('');

  // 使用共享的表格 Hook
  const table = useAdminTable<Coupon>({
    fetchData: async ({ page, pageSize, searchTerm, filters }) => {
      const response = await getCoupons({
        page,
        limit: pageSize,
        status: filters?.status as 'active' | 'inactive' | 'expired' | undefined,
      });
      return {
        data: response.data || [],
        total: response.total || 0,
      };
    },
    initialPageSize: 20,
    onError: (error) => {
      message.error('加载优惠券列表失败');
      console.error(error);
    },
  });

  // 使用共享的模态框表单 Hook
  const modal = useModalForm<CouponForm>({
    initialValues: initialCouponForm,
    onSubmit: async (values, isEdit) => {
      // 构建符合 CouponData 接口的数据
      const data: any = {
        code: values.code && values.code.trim() ? values.code.toUpperCase() : undefined,
        name: values.name,
        description: values.description || undefined,
        type: values.type,
        discount_value: values.discount_value,
        min_amount: values.min_amount || 0,
        max_discount: values.max_discount,
        currency: values.currency,
        total_quantity: values.total_quantity,
        per_user_limit: values.per_user_limit || 1,
        can_combine: values.can_combine,
        combine_limit: values.combine_limit || 1,
        apply_order: values.apply_order || 0,
        valid_from: values.valid_from,
        valid_until: values.valid_until,
        // usage_conditions 包含 points_required, locations, task_types
        usage_conditions: (() => {
          const conditions: any = {};
          if (values.points_required) conditions.points_required = values.points_required;
          if (values.task_types.length > 0) conditions.task_types = values.task_types;
          if (values.locations.length > 0) conditions.locations = values.locations;
          // 注意：CouponData 接口中 usage_conditions 只有这3个字段
          return Object.keys(conditions).length > 0 ? conditions : undefined;
        })(),
        per_device_limit: values.per_device_limit,
        per_ip_limit: values.per_ip_limit,
        per_day_limit: values.per_day_limit,
        eligibility_type: values.eligibility_type || undefined,
        eligibility_value: values.eligibility_value || undefined,
        per_user_limit_window: values.per_user_limit_window || undefined,
        per_user_per_window_limit: values.per_user_per_window_limit ?? undefined,
      };

      if (isEdit && values.id) {
        await updateCoupon(values.id, data);
        message.success('优惠券更新成功');
      } else {
        await createCoupon(data);
        message.success('优惠券创建成功');
      }

      table.refresh();
    },
    onError: (error) => {
      message.error(`操作失败：${error.response?.data?.detail || error.message}`);
    },
  });

  // 处理删除
  const handleDelete = async (coupon: Coupon) => {
    if (!window.confirm(`确定要删除优惠券"${coupon.name}"吗？`)) {
      return;
    }

    try {
      await deleteCoupon(coupon.id);
      message.success('优惠券删除成功');
      table.refresh();
    } catch (error: any) {
      message.error(`删除失败：${error.response?.data?.detail || error.message}`);
    }
  };

  // 处理编辑
  const handleEdit = (coupon: Coupon) => {
    const formData: CouponForm = {
      id: coupon.id,
      code: coupon.code,
      name: coupon.name,
      description: coupon.description || '',
      type: coupon.type,
      discount_value: coupon.discount_value,
      min_amount: coupon.min_amount,
      max_discount: coupon.max_discount,
      currency: coupon.currency,
      total_quantity: coupon.total_quantity,
      per_user_limit: coupon.per_user_limit,
      per_device_limit: undefined,
      per_ip_limit: undefined,
      can_combine: coupon.can_combine,
      combine_limit: 1,
      apply_order: 0,
      valid_from: coupon.valid_from,
      valid_until: coupon.valid_until,
      points_required: coupon.points_required,
      eligibility_type: '',
      eligibility_value: '',
      per_day_limit: undefined,
      per_user_limit_window: '',
      per_user_per_window_limit: undefined,
      vat_category: '',
      applicable_scenarios: coupon.applicable_scenarios || [],
      task_types: coupon.usage_conditions?.task_types || [],
      locations: coupon.usage_conditions?.locations || [],
      excluded_task_types: coupon.usage_conditions?.excluded_task_types || [],
      min_task_amount: coupon.usage_conditions?.min_task_amount,
      max_task_amount: coupon.usage_conditions?.max_task_amount,
    };
    modal.open(formData);
  };

  // 表格列定义
  const columns: Column<Coupon>[] = [
    {
      key: 'id',
      title: 'ID',
      dataIndex: 'id',
      width: 80,
    },
    {
      key: 'code',
      title: '代码',
      dataIndex: 'code',
      width: 120,
      render: (value) => <code className={styles.code}>{value}</code>,
    },
    {
      key: 'name',
      title: '名称',
      dataIndex: 'name',
      width: 200,
    },
    {
      key: 'type',
      title: '类型',
      dataIndex: 'type',
      width: 100,
      render: (value) => (value === 'fixed_amount' ? '满减' : '折扣'),
    },
    {
      key: 'discount',
      title: '折扣值',
      width: 120,
      render: (_, record) =>
        record.type === 'fixed_amount'
          ? `£${(record.discount_value / 100).toFixed(2)}`
          : `${(record.discount_value / 100).toFixed(2)}%`,
    },
    {
      key: 'points',
      title: '积分',
      dataIndex: 'points_required',
      width: 100,
      render: (value) => value || '-',
    },
    {
      key: 'usage',
      title: '使用量',
      width: 120,
      render: (_, record) => {
        const total = record.total_quantity || '∞';
        return `${record.used_quantity} / ${total}`;
      },
    },
    {
      key: 'status',
      title: '状态',
      dataIndex: 'status',
      width: 100,
      render: (value) => {
        const statusMap: Record<string, { text: string; variant: any }> = {
          active: { text: '激活', variant: 'success' },
          inactive: { text: '停用', variant: 'secondary' },
          expired: { text: '过期', variant: 'danger' },
        };
        const config = statusMap[value] || { text: value, variant: 'default' };
        return <StatusBadge text={config.text} variant={config.variant} />;
      },
    },
    {
      key: 'validity',
      title: '有效期',
      width: 200,
      render: (_, record) => (
        <div className={styles.validity}>
          <div>{new Date(record.valid_from).toLocaleDateString()}</div>
          <div>至</div>
          <div>{new Date(record.valid_until).toLocaleDateString()}</div>
        </div>
      ),
    },
    {
      key: 'actions',
      title: '操作',
      width: 150,
      align: 'center',
      render: (_, record) => (
        <div className={styles.actions}>
          <button className={styles.btnEdit} onClick={() => handleEdit(record)}>
            编辑
          </button>
          <button className={styles.btnDelete} onClick={() => handleDelete(record)}>
            删除
          </button>
        </div>
      ),
    },
  ];

  // 更新筛选条件
  const handleStatusFilterChange = (status: string) => {
    setStatusFilter(status);
    table.setFilters({ status: status || undefined });
  };

  return (
    <div className={styles.container}>
      {/* Header */}
      <div className={styles.header}>
        <h2 className={styles.title}>优惠券管理</h2>
        <button className={styles.btnCreate} onClick={() => modal.open()}>
          + 创建优惠券
        </button>
      </div>

      {/* Filters */}
      <div className={styles.filters}>
        <div className={styles.filterGroup}>
          <label>状态筛选：</label>
          <select
            value={statusFilter}
            onChange={(e) => handleStatusFilterChange(e.target.value)}
            className={styles.select}
          >
            <option value="">全部状态</option>
            <option value="active">激活</option>
            <option value="inactive">停用</option>
            <option value="expired">过期</option>
          </select>
        </div>
      </div>

      {/* Table */}
      <AdminTable
        columns={columns}
        data={table.data}
        loading={table.loading}
        rowKey="id"
        emptyText="暂无优惠券数据"
        className={styles.table}
      />

      {/* Pagination */}
      <AdminPagination
        currentPage={table.currentPage}
        totalPages={table.totalPages}
        total={table.total}
        pageSize={table.pageSize}
        onPageChange={table.setCurrentPage}
        onPageSizeChange={table.setPageSize}
      />

      {/* Form Modal */}
      <CouponFormModal
        isOpen={modal.isOpen}
        isEdit={modal.isEdit}
        formData={modal.formData}
        loading={modal.loading}
        onClose={modal.close}
        onSubmit={modal.handleSubmit}
        setFormData={modal.setFormData}
      />
    </div>
  );
};

export default CouponManagement;
