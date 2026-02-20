import React, { useState, useCallback } from 'react';
import { message } from 'antd';
import { useAdminTable } from '../../../hooks';
import { AdminTable, AdminPagination, StatusBadge, Column } from '../../../components/admin';
import { getForumReports, processForumReport, getFleaMarketReports, processFleaMarketReport } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

type SubTab = 'forum' | 'flea_market';

interface ForumReport {
  id: number;
  target_type: 'post' | 'reply' | string;
  target_id: number;
  reason: string;
  description?: string;
  status: 'pending' | 'processed' | 'rejected' | 'reviewing' | 'resolved' | string;
  reporter_id?: number;
  reporter_name?: string;
  created_at?: string;
}

interface FleaReport {
  id: number;
  item_id: number;
  item_title?: string;
  reason: string;
  description?: string;
  status: 'pending' | 'resolved' | 'rejected' | string;
  reporter_id?: number;
  reporter_name?: string;
  created_at?: string;
}

const reportStatusMap: Record<string, { text: string; variant: 'warning' | 'success' | 'danger' | 'info' }> = {
  pending: { text: '待处理', variant: 'warning' },
  processed: { text: '已处理', variant: 'success' },
  rejected: { text: '已拒绝', variant: 'danger' },
  reviewing: { text: '审核中', variant: 'info' },
  resolved: { text: '已解决', variant: 'success' },
};

/**
 * 举报管理组件
 * 管理论坛和跳蚤市场的举报
 */
const ReportManagement: React.FC = () => {
  const [subTab, setSubTab] = useState<SubTab>('forum');

  // 论坛举报表格
  const forumTable = useAdminTable<ForumReport>({
    fetchData: useCallback(async ({ page, pageSize, filters }: { page: number; pageSize: number; filters?: Record<string, any> }) => {
      const res = await getForumReports({
        status_filter: filters?.status || undefined,
        page,
        page_size: pageSize
      });
      return { data: res.reports || res.items || [], total: res.total || 0 };
    }, []),
    initialPageSize: 20,
    onError: useCallback((err: any) => message.error(getErrorMessage(err)), []),
  });

  // 跳蚤市场举报表格
  const fleaTable = useAdminTable<FleaReport>({
    fetchData: useCallback(async ({ page, pageSize, filters }: { page: number; pageSize: number; filters?: Record<string, any> }) => {
      const res = await getFleaMarketReports({
        status_filter: filters?.status || undefined,
        page,
        page_size: pageSize
      });
      return { data: res.reports || res.items || [], total: res.total || 0 };
    }, []),
    initialPageSize: 20,
    onError: useCallback((err: any) => message.error(getErrorMessage(err)), []),
  });

  const handleProcessForumReport = async (reportId: number, status: 'processed' | 'rejected', action?: string) => {
    try {
      await processForumReport(reportId, { status, action });
      message.success('举报处理成功');
      forumTable.refresh();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const handleProcessFleaReport = async (reportId: number, status: 'resolved' | 'rejected') => {
    try {
      await processFleaMarketReport(reportId, { status });
      message.success('举报处理成功');
      fleaTable.refresh();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const handleStatusFilterChange = (value: string) => {
    if (subTab === 'forum') {
      forumTable.setFilters({ status: value || undefined });
    } else {
      fleaTable.setFilters({ status: value || undefined });
    }
  };

  const currentStatusFilter = subTab === 'forum'
    ? (forumTable.filters?.status || '')
    : (fleaTable.filters?.status || '');

  const forumColumns: Column<ForumReport>[] = [
    {
      key: 'id',
      title: 'ID',
      dataIndex: 'id',
      width: 80,
    },
    {
      key: 'target_type',
      title: '类型',
      dataIndex: 'target_type',
      width: 100,
      render: (value) => value === 'post' ? '帖子' : '回复',
    },
    {
      key: 'target_id',
      title: '目标ID',
      dataIndex: 'target_id',
      width: 100,
    },
    {
      key: 'reason',
      title: '举报原因',
      dataIndex: 'reason',
      width: 150,
    },
    {
      key: 'description',
      title: '描述',
      dataIndex: 'description',
      width: 200,
      render: (value) => (
        <span style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block' }}>
          {value || '-'}
        </span>
      ),
    },
    {
      key: 'status',
      title: '状态',
      dataIndex: 'status',
      width: 100,
      render: (value) => {
        const config = reportStatusMap[value] || { text: value, variant: 'default' as const };
        return <StatusBadge text={config.text} variant={config.variant} />;
      },
    },
    {
      key: 'actions',
      title: '操作',
      width: 150,
      render: (_, record) => (
        record.status === 'pending' ? (
          <div style={{ display: 'flex', gap: '8px' }}>
            <button
              onClick={() => handleProcessForumReport(record.id, 'processed')}
              style={{ padding: '4px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
            >
              处理
            </button>
            <button
              onClick={() => handleProcessForumReport(record.id, 'rejected')}
              style={{ padding: '4px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
            >
              拒绝
            </button>
          </div>
        ) : null
      ),
    },
  ];

  const fleaColumns: Column<FleaReport>[] = [
    {
      key: 'id',
      title: 'ID',
      dataIndex: 'id',
      width: 80,
    },
    {
      key: 'item_id',
      title: '商品ID',
      dataIndex: 'item_id',
      width: 100,
    },
    {
      key: 'item_title',
      title: '商品标题',
      dataIndex: 'item_title',
      width: 200,
      render: (value) => (
        <span style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block' }}>
          {value || '-'}
        </span>
      ),
    },
    {
      key: 'reason',
      title: '举报原因',
      dataIndex: 'reason',
      width: 150,
    },
    {
      key: 'description',
      title: '描述',
      dataIndex: 'description',
      width: 200,
      render: (value) => (
        <span style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block' }}>
          {value || '-'}
        </span>
      ),
    },
    {
      key: 'status',
      title: '状态',
      dataIndex: 'status',
      width: 100,
      render: (value) => {
        const config = reportStatusMap[value] || { text: value, variant: 'default' as const };
        return <StatusBadge text={config.text} variant={config.variant} />;
      },
    },
    {
      key: 'actions',
      title: '操作',
      width: 150,
      render: (_, record) => (
        record.status === 'pending' ? (
          <div style={{ display: 'flex', gap: '8px' }}>
            <button
              onClick={() => handleProcessFleaReport(record.id, 'resolved')}
              style={{ padding: '4px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
            >
              处理
            </button>
            <button
              onClick={() => handleProcessFleaReport(record.id, 'rejected')}
              style={{ padding: '4px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
            >
              拒绝
            </button>
          </div>
        ) : null
      ),
    },
  ];

  const activeTable = subTab === 'forum' ? forumTable : fleaTable;

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>举报管理</h2>

      {/* 子标签页 */}
      <div style={{ display: 'flex', gap: '10px', marginBottom: '20px' }}>
        <button
          onClick={() => setSubTab('forum')}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: subTab === 'forum' ? '#007bff' : '#f0f0f0',
            color: subTab === 'forum' ? 'white' : 'black',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500'
          }}
        >
          论坛举报
        </button>
        <button
          onClick={() => setSubTab('flea_market')}
          style={{
            padding: '10px 20px',
            border: 'none',
            background: subTab === 'flea_market' ? '#007bff' : '#f0f0f0',
            color: subTab === 'flea_market' ? 'white' : 'black',
            cursor: 'pointer',
            borderRadius: '5px',
            fontSize: '14px',
            fontWeight: '500'
          }}
        >
          商品举报
        </button>
      </div>

      {/* 筛选 */}
      <div style={{ background: 'white', padding: '16px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', marginBottom: '20px' }}>
        <select
          value={currentStatusFilter}
          onChange={(e) => handleStatusFilterChange(e.target.value)}
          style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
        >
          <option value="">全部状态</option>
          <option value="pending">待处理</option>
          <option value={subTab === 'forum' ? 'processed' : 'resolved'}>
            {subTab === 'forum' ? '已处理' : '已解决'}
          </option>
          <option value="rejected">已拒绝</option>
        </select>
        <button
          onClick={() => activeTable.refresh()}
          style={{ marginLeft: '10px', padding: '8px 16px', border: 'none', background: '#007bff', color: 'white', borderRadius: '4px', cursor: 'pointer' }}
        >
          刷新
        </button>
      </div>

      {/* 内容 */}
      {subTab === 'forum' ? (
        <>
          <AdminTable
            columns={forumColumns}
            data={forumTable.data}
            loading={forumTable.loading}
            rowKey="id"
            emptyText="暂无举报"
          />
          <AdminPagination
            currentPage={forumTable.currentPage}
            totalPages={forumTable.totalPages}
            total={forumTable.total}
            pageSize={forumTable.pageSize}
            onPageChange={forumTable.setCurrentPage}
            onPageSizeChange={forumTable.setPageSize}
          />
        </>
      ) : (
        <>
          <AdminTable
            columns={fleaColumns}
            data={fleaTable.data}
            loading={fleaTable.loading}
            rowKey="id"
            emptyText="暂无举报"
          />
          <AdminPagination
            currentPage={fleaTable.currentPage}
            totalPages={fleaTable.totalPages}
            total={fleaTable.total}
            pageSize={fleaTable.pageSize}
            onPageChange={fleaTable.setCurrentPage}
            onPageSizeChange={fleaTable.setPageSize}
          />
        </>
      )}
    </div>
  );
};

export default ReportManagement;
