import React, { useState, useCallback } from 'react';
import { message } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, AdminModal, Column, StatusBadge } from '../../../components/admin';
import {
  getInvitationCodes,
  createInvitationCode,
  updateInvitationCode,
  deleteInvitationCode,
  getInvitationCodeDetail,
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface InvitationCode {
  id: number;
  code: string;
  name?: string;
  description?: string;
  reward_type: 'points' | 'coupon' | 'both';
  points_reward?: number;
  points_reward_display?: string;
  coupon_id?: number;
  used_count: number;
  max_uses?: number;
  valid_from: string;
  valid_until: string;
  is_active: boolean;
}

interface FormData {
  id?: number;
  code: string;
  name: string;
  description: string;
  reward_type: 'points' | 'coupon' | 'both';
  points_reward: number;
  coupon_id?: number;
  max_uses?: number;
  valid_from: string;
  valid_until: string;
  is_active: boolean;
}

const initialForm: FormData = {
  code: '',
  name: '',
  description: '',
  reward_type: 'points',
  points_reward: 0,
  coupon_id: undefined,
  max_uses: undefined,
  valid_from: '',
  valid_until: '',
  is_active: true,
};

/**
 * 邀请码管理组件
 */
const InvitationManagement: React.FC = () => {
  const [statusFilter, setStatusFilter] = useState<string>('');

  const fetchCodes = useCallback(async ({ page, pageSize, filters }: { page: number; pageSize: number; filters?: Record<string, any> }) => {
    const response = await getInvitationCodes({
      page,
      limit: pageSize,
      status: filters?.status as 'active' | 'inactive' | undefined,
    });
    return {
      data: response.data || response.items || [],
      total: response.total || 0,
    };
  }, []);

  const handleFetchError = useCallback((error: any) => {
    message.error(getErrorMessage(error));
  }, []);

  const table = useAdminTable<InvitationCode>({
    fetchData: fetchCodes,
    initialPageSize: 20,
    onError: handleFetchError,
  });

  const modal = useModalForm<FormData>({
    initialValues: initialForm,
    onSubmit: async (values, isEdit) => {
      if (!values.code || !values.valid_from || !values.valid_until) {
        message.warning('请填写邀请码、有效期开始时间和结束时间');
        throw new Error('validation');
      }

      if (isEdit && values.id) {
        await updateInvitationCode(values.id, {
          name: values.name || undefined,
          description: values.description || undefined,
          is_active: values.is_active,
          max_uses: values.max_uses,
          valid_from: values.valid_from ? new Date(values.valid_from).toISOString() : undefined,
          valid_until: values.valid_until ? new Date(values.valid_until).toISOString() : undefined,
          points_reward: values.points_reward || undefined,
          coupon_id: values.coupon_id,
        });
        message.success('邀请码更新成功！');
      } else {
        await createInvitationCode({
          code: values.code,
          name: values.name || undefined,
          description: values.description || undefined,
          reward_type: values.reward_type,
          points_reward: values.points_reward || undefined,
          coupon_id: values.coupon_id,
          max_uses: values.max_uses,
          valid_from: new Date(values.valid_from).toISOString(),
          valid_until: new Date(values.valid_until).toISOString(),
          is_active: values.is_active,
        });
        message.success('邀请码创建成功！');
      }

      table.refresh();
    },
    onError: (error: any) => {
      if (error?.message !== 'validation') {
        message.error(getErrorMessage(error));
      }
    },
  });

  const handleEdit = useCallback(async (id: number) => {
    try {
      const detail = await getInvitationCodeDetail(id);
      modal.open({
        id: detail.id,
        code: detail.code,
        name: detail.name || '',
        description: detail.description || '',
        reward_type: detail.reward_type,
        points_reward: detail.points_reward || 0,
        coupon_id: detail.coupon_id,
        max_uses: detail.max_uses,
        valid_from: detail.valid_from ? new Date(detail.valid_from).toISOString().slice(0, 16) : '',
        valid_until: detail.valid_until ? new Date(detail.valid_until).toISOString().slice(0, 16) : '',
        is_active: detail.is_active,
      });
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  }, [modal]);

  const handleDelete = useCallback((id: number) => {
    if (!window.confirm('确定要删除这个邀请码吗？')) return;
    deleteInvitationCode(id)
      .then(() => {
        message.success('邀请码删除成功！');
        table.refresh();
      })
      .catch((error: any) => {
        message.error(getErrorMessage(error));
      });
  }, [table]);

  const handleStatusFilterChange = useCallback((status: string) => {
    setStatusFilter(status);
    table.setFilters({ status: status || undefined });
  }, [table]);

  const columns: Column<InvitationCode>[] = [
    {
      key: 'code',
      title: '邀请码',
      dataIndex: 'code',
      width: 120,
    },
    {
      key: 'name',
      title: '名称',
      dataIndex: 'name',
      width: 140,
      render: (value) => value || '-',
    },
    {
      key: 'reward_type',
      title: '奖励类型',
      dataIndex: 'reward_type',
      width: 120,
      render: (value) =>
        value === 'points' ? '积分' : value === 'coupon' ? '优惠券' : '积分+优惠券',
    },
    {
      key: 'points_reward',
      title: '积分奖励',
      dataIndex: 'points_reward_display',
      width: 100,
      render: (value) => value || '0.00',
    },
    {
      key: 'usage',
      title: '使用次数',
      width: 100,
      render: (_, record) => `${record.used_count || 0} / ${record.max_uses || '∞'}`,
    },
    {
      key: 'validity',
      title: '有效期',
      width: 200,
      render: (_, record) => (
        <span style={{ fontSize: '12px' }}>
          {new Date(record.valid_from).toLocaleString('zh-CN')} ~<br />
          {new Date(record.valid_until).toLocaleString('zh-CN')}
        </span>
      ),
    },
    {
      key: 'status',
      title: '状态',
      dataIndex: 'is_active',
      width: 80,
      render: (value) => (
        <StatusBadge
          text={value ? '启用' : '禁用'}
          variant={value ? 'success' : 'danger'}
        />
      ),
    },
    {
      key: 'actions',
      title: '操作',
      width: 120,
      align: 'center',
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
          <button
            onClick={() => handleEdit(record.id)}
            style={{ padding: '4px 8px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            编辑
          </button>
          <button
            onClick={() => handleDelete(record.id)}
            style={{ padding: '4px 8px', border: '1px solid #dc3545', background: 'white', color: '#dc3545', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            删除
          </button>
        </div>
      ),
    },
  ];

  const modalFooter = (
    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
      <button
        onClick={modal.close}
        style={{ padding: '8px 16px', border: '1px solid #d9d9d9', borderRadius: '4px', background: 'white', cursor: 'pointer' }}
      >
        取消
      </button>
      <button
        onClick={modal.handleSubmit}
        disabled={modal.loading}
        style={{ padding: '8px 16px', border: 'none', borderRadius: '4px', background: '#007bff', color: 'white', cursor: modal.loading ? 'not-allowed' : 'pointer', opacity: modal.loading ? 0.7 : 1 }}
      >
        {modal.loading ? '提交中...' : modal.isEdit ? '更新' : '创建'}
      </button>
    </div>
  );

  return (
    <div>
      {/* Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>邀请码管理</h2>
        <button
          onClick={() => modal.open()}
          style={{ padding: '10px 20px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '14px', fontWeight: '500' }}
        >
          创建邀请码
        </button>
      </div>

      {/* 筛选器 */}
      <div style={{ marginBottom: '20px', display: 'flex', gap: '10px', alignItems: 'center' }}>
        <label style={{ fontWeight: 'bold' }}>状态筛选：</label>
        <select
          value={statusFilter}
          onChange={(e) => handleStatusFilterChange(e.target.value)}
          style={{ padding: '8px 12px', border: '1px solid #ddd', borderRadius: '4px', fontSize: '14px' }}
        >
          <option value="">全部</option>
          <option value="active">启用</option>
          <option value="inactive">禁用</option>
        </select>
      </div>

      {/* 表格 */}
      <AdminTable
        columns={columns}
        data={table.data}
        loading={table.loading}
        rowKey="id"
        emptyText="暂无邀请码数据"
      />

      {/* 分页 */}
      <AdminPagination
        currentPage={table.currentPage}
        totalPages={table.totalPages}
        total={table.total}
        pageSize={table.pageSize}
        onPageChange={table.setCurrentPage}
        onPageSizeChange={table.setPageSize}
      />

      {/* 模态框 */}
      <AdminModal
        isOpen={modal.isOpen}
        onClose={modal.close}
        title={modal.isEdit ? '编辑邀请码' : '创建邀请码'}
        footer={modalFooter}
        width="600px"
      >
        <div style={{ padding: '20px 0' }}>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              邀请码 <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="text"
              value={modal.formData.code}
              onChange={(e) => modal.updateField('code', e.target.value.toUpperCase())}
              disabled={modal.isEdit}
              placeholder="请输入邀请码"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>名称</label>
            <input
              type="text"
              value={modal.formData.name}
              onChange={(e) => modal.updateField('name', e.target.value)}
              placeholder="请输入名称"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              奖励类型 <span style={{ color: 'red' }}>*</span>
            </label>
            <select
              value={modal.formData.reward_type}
              onChange={(e) => modal.updateField('reward_type', e.target.value as FormData['reward_type'])}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            >
              <option value="points">积分</option>
              <option value="coupon">优惠券</option>
              <option value="both">积分+优惠券</option>
            </select>
          </div>
          {(modal.formData.reward_type === 'points' || modal.formData.reward_type === 'both') && (
            <div style={{ marginBottom: '15px' }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>积分奖励（分）</label>
              <input
                type="number"
                value={modal.formData.points_reward}
                onChange={(e) => modal.updateField('points_reward', parseInt(e.target.value) || 0)}
                placeholder="100分=1.00"
                min="0"
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
              />
            </div>
          )}
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              有效期开始时间 <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="datetime-local"
              value={modal.formData.valid_from}
              onChange={(e) => modal.updateField('valid_from', e.target.value)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              有效期结束时间 <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="datetime-local"
              value={modal.formData.valid_until}
              onChange={(e) => modal.updateField('valid_until', e.target.value)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={modal.formData.is_active}
                onChange={(e) => modal.updateField('is_active', e.target.checked)}
              />
              <span>启用状态</span>
            </label>
          </div>
        </div>
      </AdminModal>
    </div>
  );
};

export default InvitationManagement;
