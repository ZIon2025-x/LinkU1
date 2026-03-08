import React, { useCallback } from 'react';
import { message } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, AdminModal, Column } from '../../../components/admin';
import { getCheckinRewards, createCheckinReward, updateCheckinReward } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface CheckinReward {
  id: number;
  consecutive_days: number;
  reward_type: string;
  points_reward: number;
  is_active: boolean;
  created_at?: string;
}

interface CheckinRewardForm {
  id?: number;
  consecutive_days: number;
  reward_type: string;
  points_reward: number;
  is_active: boolean;
}

const initialForm: CheckinRewardForm = {
  consecutive_days: 1,
  reward_type: 'points',
  points_reward: 0,
  is_active: true,
};

const CheckinRewardConfig: React.FC = () => {
  const fetchRewards = useCallback(async ({ page, pageSize }: { page: number; pageSize: number }) => {
    const response = await getCheckinRewards();
    // This endpoint may return all items without pagination
    const items = response.items || response.data || response || [];
    return {
      data: Array.isArray(items) ? items : [],
      total: Array.isArray(items) ? items.length : 0,
    };
  }, []);

  const table = useAdminTable<CheckinReward>({
    fetchData: fetchRewards,
    initialPageSize: 50,
    onError: (error) => message.error(getErrorMessage(error)),
  });

  const modal = useModalForm<CheckinRewardForm>({
    initialValues: initialForm,
    onSubmit: async (values, isEdit) => {
      if (values.consecutive_days <= 0) {
        message.warning('Consecutive days must be > 0');
        throw new Error('validation');
      }

      const payload = {
        consecutive_days: values.consecutive_days,
        reward_type: values.reward_type,
        points_reward: values.points_reward,
        is_active: values.is_active,
      };

      if (isEdit && values.id) {
        await updateCheckinReward(values.id, payload);
        message.success('Check-in reward updated');
      } else {
        await createCheckinReward(payload);
        message.success('Check-in reward created');
      }
      table.refresh();
    },
    onError: (error: any) => {
      if (error?.message !== 'validation') {
        message.error(getErrorMessage(error));
      }
    },
  });

  const handleEdit = (reward: CheckinReward) => {
    modal.open({
      id: reward.id,
      consecutive_days: reward.consecutive_days,
      reward_type: reward.reward_type,
      points_reward: reward.points_reward,
      is_active: reward.is_active,
    });
  };

  const columns: Column<CheckinReward>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 60 },
    { key: 'consecutive_days', title: 'Consecutive Days', dataIndex: 'consecutive_days', width: 140, align: 'center' },
    { key: 'reward_type', title: 'Reward Type', dataIndex: 'reward_type', width: 120 },
    { key: 'points_reward', title: 'Points Reward', dataIndex: 'points_reward', width: 120, align: 'right' },
    {
      key: 'is_active', title: 'Active', dataIndex: 'is_active', width: 80, align: 'center',
      render: (val: boolean) => (
        <span style={{ color: val ? '#28a745' : '#dc3545', fontWeight: 500 }}>
          {val ? 'Yes' : 'No'}
        </span>
      ),
    },
    {
      key: 'actions', title: 'Actions', width: 100, align: 'center',
      render: (_: any, record: CheckinReward) => (
        <button
          onClick={() => handleEdit(record)}
          style={{ padding: '4px 12px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
        >
          Edit
        </button>
      ),
    },
  ];

  const modalFooter = (
    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
      <button
        onClick={modal.close}
        style={{ padding: '8px 16px', border: '1px solid #d9d9d9', borderRadius: '4px', background: 'white', cursor: 'pointer' }}
      >
        Cancel
      </button>
      <button
        onClick={modal.handleSubmit}
        disabled={modal.loading}
        style={{ padding: '8px 16px', border: 'none', borderRadius: '4px', background: '#007bff', color: 'white', cursor: modal.loading ? 'not-allowed' : 'pointer', opacity: modal.loading ? 0.7 : 1 }}
      >
        {modal.loading ? 'Submitting...' : modal.isEdit ? 'Update' : 'Create'}
      </button>
    </div>
  );

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>Check-in Reward Configuration</h2>
        <button
          onClick={() => modal.open()}
          style={{ padding: '10px 20px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '14px', fontWeight: '500' }}
        >
          Add Reward
        </button>
      </div>

      <AdminTable<CheckinReward>
        columns={columns}
        data={table.data}
        loading={table.loading}
        rowKey="id"
      />

      <AdminPagination
        currentPage={table.currentPage}
        totalPages={table.totalPages}
        total={table.total}
        pageSize={table.pageSize}
        onPageChange={table.setCurrentPage}
        onPageSizeChange={table.setPageSize}
      />

      <AdminModal
        isOpen={modal.isOpen}
        onClose={modal.close}
        title={modal.isEdit ? 'Edit Check-in Reward' : 'Add Check-in Reward'}
        footer={modalFooter}
        width="450px"
      >
        <div style={{ padding: '20px 0' }}>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              Consecutive Days <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="number"
              value={modal.formData.consecutive_days}
              onChange={(e) => modal.updateField('consecutive_days', parseInt(e.target.value) || 0)}
              min={1}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Reward Type</label>
            <select
              value={modal.formData.reward_type}
              onChange={(e) => modal.updateField('reward_type', e.target.value)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            >
              <option value="points">Points</option>
              <option value="coupon">Coupon</option>
              <option value="badge">Badge</option>
            </select>
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Points Reward</label>
            <input
              type="number"
              value={modal.formData.points_reward}
              onChange={(e) => modal.updateField('points_reward', parseInt(e.target.value) || 0)}
              min={0}
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
              <span>Active</span>
            </label>
          </div>
        </div>
      </AdminModal>
    </div>
  );
};

export default CheckinRewardConfig;
