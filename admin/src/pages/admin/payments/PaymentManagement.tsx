import React, { useState, useCallback, useEffect } from 'react';
import { message } from 'antd';
import { useAdminTable } from '../../../hooks';
import { AdminTable, AdminPagination, Column } from '../../../components/admin';
import {
  getAdminPayments,
  getAdminPaymentStats,
  getAdminPaymentDetail,
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface Payment {
  id: string;
  user_id: string;
  amount: number;
  currency: string;
  status: string;
  payment_type: string;
  payment_intent_id?: string;
  created_at: string;
  updated_at?: string;
}

interface PaymentStats {
  total_amount?: number;
  total_count?: number;
  today_amount?: number;
  today_count?: number;
}

const PaymentManagement: React.FC = () => {
  const [stats, setStats] = useState<PaymentStats | null>(null);
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [userFilter, setUserFilter] = useState<string>('');

  const fetchPayments = useCallback(
    async ({ page, pageSize }: { page: number; pageSize: number }) => {
      const res = await getAdminPayments({
        page,
        size: pageSize,
        status: statusFilter || undefined,
        user_id: userFilter || undefined,
      });
      return {
        data: res.payments || [],
        total: res.total ?? 0,
      };
    },
    [statusFilter, userFilter]
  );

  const table = useAdminTable<Payment>({
    fetchData: fetchPayments,
    initialPageSize: 20,
    onError: (e) => message.error(getErrorMessage(e)),
  });

  const loadStats = useCallback(async () => {
    try {
      const s = await getAdminPaymentStats();
      setStats(s);
    } catch (e) {
      message.error(getErrorMessage(e));
    }
  }, []);

  useEffect(() => {
    loadStats();
  }, [loadStats]);

  const columns: Column<Payment>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 80, render: (v) => String(v).slice(0, 12) + '...' },
    { key: 'user_id', title: '用户ID', dataIndex: 'user_id', width: 100 },
    {
      key: 'amount',
      title: '金额',
      width: 100,
      render: (_, r) => `${r.currency || 'GBP'} ${Number(r.amount || 0).toFixed(2)}`,
    },
    { key: 'status', title: '状态', dataIndex: 'status', width: 100 },
    { key: 'payment_type', title: '类型', dataIndex: 'payment_type', width: 100 },
    {
      key: 'created_at',
      title: '创建时间',
      dataIndex: 'created_at',
      width: 160,
      render: (v) => (v ? new Date(v).toLocaleString('zh-CN') : '-'),
    },
  ];

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>支付管理</h2>

      {stats && (
        <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap', marginBottom: '20px' }}>
          <div style={{ background: '#f0f9ff', padding: '16px 20px', borderRadius: '8px', minWidth: '160px' }}>
            <div style={{ color: '#666', fontSize: '12px' }}>总交易额</div>
            <div style={{ fontWeight: 'bold', fontSize: '18px' }}>£{Number(stats.total_amount || 0).toFixed(2)}</div>
          </div>
          <div style={{ background: '#f0fdf4', padding: '16px 20px', borderRadius: '8px', minWidth: '160px' }}>
            <div style={{ color: '#666', fontSize: '12px' }}>总笔数</div>
            <div style={{ fontWeight: 'bold', fontSize: '18px' }}>{stats.total_count ?? 0}</div>
          </div>
          <div style={{ background: '#fefce8', padding: '16px 20px', borderRadius: '8px', minWidth: '160px' }}>
            <div style={{ color: '#666', fontSize: '12px' }}>今日交易额</div>
            <div style={{ fontWeight: 'bold', fontSize: '18px' }}>£{Number(stats.today_amount || 0).toFixed(2)}</div>
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
          <option value="succeeded">成功</option>
          <option value="pending">待处理</option>
          <option value="failed">失败</option>
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

      <AdminTable
        columns={columns}
        data={table.data}
        loading={table.loading}
        refreshing={table.fetching}
        rowKey="id"
        emptyText="暂无支付记录"
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

export default PaymentManagement;
