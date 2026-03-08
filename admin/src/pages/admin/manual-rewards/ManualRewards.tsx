import React, { useState, useCallback } from 'react';
import { message } from 'antd';
import { useAdminTable } from '../../../hooks';
import { AdminTable, AdminPagination, Column } from '../../../components/admin';
import { sendManualReward, getRewardLogs } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface RewardLog {
  id: number;
  user_id: string;
  user_name?: string;
  reward_type: string;
  amount: number;
  reason: string;
  admin_id?: string;
  created_at: string;
}

const ManualRewards: React.FC = () => {
  const [userSearch, setUserSearch] = useState('');
  const [rewardForm, setRewardForm] = useState({
    user_id: '',
    reward_type: 'points',
    amount: 0,
    reason: '',
  });
  const [sending, setSending] = useState(false);

  const fetchLogs = useCallback(async ({ page, pageSize }: { page: number; pageSize: number }) => {
    const response = await getRewardLogs({ offset: (page - 1) * pageSize, limit: pageSize });
    return {
      data: response.items || response.data || [],
      total: response.total || 0,
    };
  }, []);

  const table = useAdminTable<RewardLog>({
    fetchData: fetchLogs,
    initialPageSize: 20,
    onError: (error) => message.error(getErrorMessage(error)),
  });

  const handleSendReward = async () => {
    if (!rewardForm.user_id) {
      message.warning('Please enter a User ID');
      return;
    }
    if (rewardForm.amount <= 0) {
      message.warning('Amount must be greater than 0');
      return;
    }
    if (!rewardForm.reason) {
      message.warning('Please provide a reason');
      return;
    }

    if (!window.confirm(`Send ${rewardForm.amount} ${rewardForm.reward_type} to user ${rewardForm.user_id}?`)) {
      return;
    }

    setSending(true);
    try {
      await sendManualReward(rewardForm);
      message.success('Reward sent successfully');
      setRewardForm({ user_id: '', reward_type: 'points', amount: 0, reason: '' });
      table.refresh();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setSending(false);
    }
  };

  const logColumns: Column<RewardLog>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 60 },
    { key: 'user_id', title: 'User ID', dataIndex: 'user_id', width: 200 },
    { key: 'user_name', title: 'User Name', dataIndex: 'user_name', width: 120 },
    { key: 'reward_type', title: 'Type', dataIndex: 'reward_type', width: 100 },
    { key: 'amount', title: 'Amount', dataIndex: 'amount', width: 80, align: 'right' },
    { key: 'reason', title: 'Reason', dataIndex: 'reason', width: 250 },
    {
      key: 'created_at', title: 'Date', dataIndex: 'created_at', width: 160,
      render: (val: string) => val ? new Date(val).toLocaleString() : '-',
    },
  ];

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>Manual Rewards</h2>

      {/* Send Reward Form */}
      <div style={{
        background: 'white',
        borderRadius: '8px',
        padding: '24px',
        marginBottom: '24px',
        boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
      }}>
        <h3 style={{ marginTop: 0, marginBottom: '16px' }}>Send Reward</h3>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: '16px', alignItems: 'end' }}>
          <div>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold', fontSize: '13px' }}>
              User ID <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="text"
              value={rewardForm.user_id}
              onChange={(e) => setRewardForm(f => ({ ...f, user_id: e.target.value }))}
              placeholder="User ID or email"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold', fontSize: '13px' }}>
              Reward Type
            </label>
            <select
              value={rewardForm.reward_type}
              onChange={(e) => setRewardForm(f => ({ ...f, reward_type: e.target.value }))}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            >
              <option value="points">Points</option>
              <option value="coupon">Coupon</option>
              <option value="badge">Badge</option>
            </select>
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold', fontSize: '13px' }}>
              Amount <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="number"
              value={rewardForm.amount || ''}
              onChange={(e) => setRewardForm(f => ({ ...f, amount: parseInt(e.target.value) || 0 }))}
              placeholder="Amount"
              min={1}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold', fontSize: '13px' }}>
              Reason <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="text"
              value={rewardForm.reason}
              onChange={(e) => setRewardForm(f => ({ ...f, reason: e.target.value }))}
              placeholder="Reason for reward"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
        </div>
        <div style={{ marginTop: '16px', textAlign: 'right' }}>
          <button
            onClick={handleSendReward}
            disabled={sending}
            style={{
              padding: '10px 24px',
              border: 'none',
              background: sending ? '#6c757d' : '#28a745',
              color: 'white',
              borderRadius: '4px',
              cursor: sending ? 'not-allowed' : 'pointer',
              fontSize: '14px',
              fontWeight: '500',
            }}
          >
            {sending ? 'Sending...' : 'Send Reward'}
          </button>
        </div>
      </div>

      {/* Reward Logs */}
      <h3 style={{ marginBottom: '16px' }}>Reward Logs</h3>
      <AdminTable<RewardLog>
        columns={logColumns}
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
    </div>
  );
};

export default ManualRewards;
