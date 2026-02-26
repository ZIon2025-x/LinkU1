import React, { useState, useCallback } from 'react';
import { message, Modal } from 'antd';
import { useAdminTable } from '../../../hooks';
import { AdminTable, AdminPagination, Column } from '../../../components/admin';
import {
  getAdminVipSubscriptions,
  getAdminVipSubscriptionStats,
  updateAdminVipSubscription,
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface VipSubscription {
  id: number;
  user_id: string;
  product_id?: string;
  status: string;
  purchase_date?: string;
  expires_date?: string;
  environment?: string;
  created_at?: string;
}

const VipManagement: React.FC = () => {
  const [stats, setStats] = useState<Record<string, any> | null>(null);
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [userFilter, setUserFilter] = useState<string>('');

  const fetchList = useCallback(
    async ({ page, pageSize }: { page: number; pageSize: number }) => {
      const res = await getAdminVipSubscriptions({
        skip: (page - 1) * pageSize,
        limit: pageSize,
        status: statusFilter || undefined,
        user_id: userFilter || undefined,
      });
      return { data: res.items || [], total: res.total ?? 0 };
    },
    [statusFilter, userFilter]
  );

  const table = useAdminTable<VipSubscription>({
    fetchData: fetchList,
    initialPageSize: 20,
    onError: (e) => message.error(getErrorMessage(e)),
  });

  const loadStats = useCallback(async () => {
    try {
      const s = await getAdminVipSubscriptionStats();
      setStats(s);
    } catch (e) {
      message.error(getErrorMessage(e));
    }
  }, []);

  React.useEffect(() => {
    loadStats();
  }, [loadStats]);

  const handleUpdateStatus = (record: VipSubscription) => {
    const newStatus = record.status === 'active' ? 'expired' : 'active';
    Modal.confirm({
      title: '修改订阅状态',
      content: `确定将订阅 #${record.id} 状态改为「${newStatus}」吗？`,
      onOk: async () => {
        try {
          await updateAdminVipSubscription(record.id, { status: newStatus });
          message.success('已更新');
          table.refresh();
          loadStats();
        } catch (e) {
          message.error(getErrorMessage(e));
        }
      },
    });
  };

  const columns: Column<VipSubscription>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 70 },
    { key: 'user_id', title: '用户ID', dataIndex: 'user_id', width: 100 },
    { key: 'status', title: '状态', dataIndex: 'status', width: 90 },
    {
      key: 'expires_date',
      title: '到期时间',
      dataIndex: 'expires_date',
      width: 160,
      render: (v) => (v ? new Date(v).toLocaleString('zh-CN') : '-'),
    },
    {
      key: 'created_at',
      title: '创建时间',
      dataIndex: 'created_at',
      width: 160,
      render: (v) => (v ? new Date(v).toLocaleString('zh-CN') : '-'),
    },
    {
      key: 'actions',
      title: '操作',
      width: 100,
      render: (_, record) => (
        <button
          type="button"
          onClick={() => handleUpdateStatus(record)}
          style={{ padding: '4px 8px', fontSize: '12px', border: '1px solid #1890ff', background: 'white', color: '#1890ff', borderRadius: '4px', cursor: 'pointer' }}
        >
          更新状态
        </button>
      ),
    },
  ];

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>VIP 订阅管理</h2>

      {stats && (
        <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap', marginBottom: '20px' }}>
          <div style={{ background: '#f0f9ff', padding: '16px 20px', borderRadius: '8px', minWidth: '140px' }}>
            <div style={{ color: '#666', fontSize: '12px' }}>订阅总数</div>
            <div style={{ fontWeight: 'bold', fontSize: '18px' }}>{stats.total_subscriptions ?? 0}</div>
          </div>
          <div style={{ background: '#f0fdf4', padding: '16px 20px', borderRadius: '8px', minWidth: '140px' }}>
            <div style={{ color: '#666', fontSize: '12px' }}>当前 VIP 用户数</div>
            <div style={{ fontWeight: 'bold', fontSize: '18px' }}>{stats.active_vip_users ?? 0}</div>
          </div>
        </div>
      )}

      <div style={{ marginBottom: '16px', display: 'flex', gap: '8px', alignItems: 'center', flexWrap: 'wrap' }}>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          style={{ padding: '6px 10px', borderRadius: '4px', border: '1px solid #ddd' }}
        >
          <option value="">全部状态</option>
          <option value="active">有效</option>
          <option value="expired">已过期</option>
          <option value="cancelled">已取消</option>
        </select>
        <input
          type="text"
          placeholder="用户ID"
          value={userFilter}
          onChange={(e) => setUserFilter(e.target.value)}
          style={{ padding: '6px 10px', borderRadius: '4px', border: '1px solid #ddd', width: '120px' }}
        />
        <button
          type="button"
          onClick={() => table.refresh()}
          style={{ padding: '6px 16px', background: '#1890ff', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
        >
          查询
        </button>
      </div>

      <AdminTable columns={columns} data={table.data} loading={table.loading} refreshing={table.fetching} rowKey="id" emptyText="暂无订阅记录" />
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

export default VipManagement;
