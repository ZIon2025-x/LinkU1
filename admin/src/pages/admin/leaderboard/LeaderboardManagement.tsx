import React, { useState, useCallback } from 'react';
import { message } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, AdminModal, Column } from '../../../components/admin';
import {
  getLeaderboardVotesAdmin,
  getLeaderboardItemsAdmin,
  createLeaderboardItemAdmin,
  updateLeaderboardItemAdmin,
  deleteLeaderboardItemAdmin,
  getCustomLeaderboardsAdmin,
  reviewCustomLeaderboard,
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

type SubTab = 'votes' | 'items' | 'reviews';

interface Vote {
  id: number;
  item_id: number;
  user_id: number;
  vote_type: 'upvote' | 'downvote';
  comment?: string;
  is_anonymous: boolean;
  created_at: string;
}

interface LeaderboardItem {
  id: number;
  name: string;
  description?: string;
  image_url?: string;
  leaderboard_id: number;
  vote_count: number;
  status: string;
  created_at: string;
}

interface ItemForm {
  id?: number;
  name: string;
  description: string;
  image_url: string;
  leaderboard_id: number | '';
}

const initialItemForm: ItemForm = {
  name: '',
  description: '',
  image_url: '',
  leaderboard_id: '',
};

/**
 * 排行榜管理组件
 */
const LeaderboardManagement: React.FC = () => {
  const [subTab, setSubTab] = useState<SubTab>('items');
  const [votesFilter, setVotesFilter] = useState<{
    item_id?: number;
    leaderboard_id?: number;
    is_anonymous?: boolean;
    keyword?: string;
  }>({});

  // ---------- 投票记录 ----------
  const fetchVotes = useCallback(async ({ page, pageSize }: { page: number; pageSize: number }) => {
    const response = await getLeaderboardVotesAdmin({
      offset: (page - 1) * pageSize,
      limit: pageSize,
      ...votesFilter,
    });
    const items = response.items || [];
    return { data: items, total: items.length < pageSize ? (page - 1) * pageSize + items.length : page * pageSize + 1 };
  }, [votesFilter]);

  const votesTable = useAdminTable<Vote>({
    fetchData: fetchVotes,
    initialPageSize: 50,
    onError: (error) => message.error(getErrorMessage(error)),
    enabled: subTab === 'votes',
  });

  // ---------- 竞品管理 ----------
  const fetchItems = useCallback(async ({ page, pageSize }: { page: number; pageSize: number }) => {
    const response = await getLeaderboardItemsAdmin({ offset: (page - 1) * pageSize, limit: pageSize });
    return { data: response.items || [], total: response.total || 0 };
  }, []);

  const itemsTable = useAdminTable<LeaderboardItem>({
    fetchData: fetchItems,
    initialPageSize: 20,
    onError: (error) => message.error(getErrorMessage(error)),
    enabled: subTab === 'items',
  });

  const itemModal = useModalForm<ItemForm>({
    initialValues: initialItemForm,
    onSubmit: async (values, isEdit) => {
      if (!values.name) {
        message.warning('请填写竞品名称');
        throw new Error('validation');
      }
      const payload = {
        name: values.name,
        description: values.description || undefined,
        image_url: values.image_url || undefined,
        leaderboard_id: values.leaderboard_id !== '' ? Number(values.leaderboard_id) : undefined,
      };
      if (isEdit && values.id) {
        await updateLeaderboardItemAdmin(values.id, payload);
        message.success('竞品更新成功');
      } else {
        await createLeaderboardItemAdmin(payload as any);
        message.success('竞品创建成功');
      }
      itemsTable.refresh();
    },
    onError: (error: any) => {
      if (error?.message !== 'validation') {
        message.error(getErrorMessage(error));
      }
    },
  });

  // ---------- 审核队列 ----------
  const fetchReviews = useCallback(async ({ page, pageSize }: { page: number; pageSize: number }) => {
    const response = await getCustomLeaderboardsAdmin({ status: 'pending', offset: (page - 1) * pageSize, limit: pageSize });
    return { data: response.items || [], total: response.total || (response.items || []).length };
  }, []);

  const reviewsTable = useAdminTable<any>({
    fetchData: fetchReviews,
    initialPageSize: 20,
    onError: (error) => message.error(getErrorMessage(error)),
    enabled: subTab === 'reviews',
  });

  const handleDeleteItem = useCallback((id: number) => {
    if (!window.confirm('确定要删除这个竞品吗？')) return;
    deleteLeaderboardItemAdmin(id)
      .then(() => {
        message.success('竞品删除成功');
        itemsTable.refresh();
      })
      .catch((error: any) => message.error(getErrorMessage(error)));
  }, [itemsTable]);

  const handleReview = useCallback(async (id: number, action: 'approve' | 'reject') => {
    try {
      await reviewCustomLeaderboard(id, action);
      message.success(action === 'approve' ? '已批准' : '已拒绝');
      reviewsTable.refresh();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  }, [reviewsTable]);

  // ---------- 列定义 ----------
  const votesColumns: Column<Vote>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 60 },
    { key: 'item_id', title: '竞品ID', dataIndex: 'item_id', width: 80 },
    {
      key: 'user_id',
      title: '用户ID',
      width: 100,
      render: (_, record) =>
        record.is_anonymous ? (
          <span style={{ color: '#999', fontStyle: 'italic' }}>匿名</span>
        ) : (
          <>{record.user_id}</>
        ),
    },
    {
      key: 'vote_type',
      title: '投票类型',
      dataIndex: 'vote_type',
      width: 100,
      render: (value) => (
        <span style={{
          padding: '4px 8px',
          borderRadius: '4px',
          background: value === 'upvote' ? '#52c41a' : '#ff4d4f',
          color: 'white',
          fontSize: '12px',
        }}>
          {value === 'upvote' ? '👍 点赞' : '👎 点踩'}
        </span>
      ),
    },
    {
      key: 'comment',
      title: '留言',
      width: 300,
      render: (_, record) =>
        record.comment || <span style={{ color: '#999', fontStyle: 'italic' }}>（无留言）</span>,
    },
    {
      key: 'is_anonymous',
      title: '匿名',
      dataIndex: 'is_anonymous',
      width: 60,
      render: (value) =>
        value ? (
          <span style={{ color: '#ff4d4f', fontWeight: 'bold' }}>是</span>
        ) : (
          <span style={{ color: '#52c41a' }}>否</span>
        ),
    },
    {
      key: 'created_at',
      title: '创建时间',
      dataIndex: 'created_at',
      width: 150,
      render: (value) => (
        <span style={{ fontSize: '12px', color: '#666' }}>
          {new Date(value).toLocaleString('zh-CN')}
        </span>
      ),
    },
  ];

  const itemsColumns: Column<LeaderboardItem>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 60 },
    { key: 'name', title: '名称', dataIndex: 'name', width: 160 },
    {
      key: 'description',
      title: '描述',
      dataIndex: 'description',
      width: 200,
      render: (value) => (
        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block', maxWidth: '200px' }}>
          {value || '-'}
        </span>
      ),
    },
    { key: 'leaderboard_id', title: '榜单ID', dataIndex: 'leaderboard_id', width: 80 },
    { key: 'vote_count', title: '票数', dataIndex: 'vote_count', width: 80 },
    {
      key: 'status',
      title: '状态',
      dataIndex: 'status',
      width: 80,
      render: (value) => (
        <span style={{
          padding: '4px 8px',
          borderRadius: '4px',
          background: value === 'active' ? '#d4edda' : '#f8d7da',
          color: value === 'active' ? '#155724' : '#721c24',
          fontSize: '12px',
        }}>
          {value}
        </span>
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
            onClick={() => itemModal.open({
              id: record.id,
              name: record.name,
              description: record.description || '',
              image_url: record.image_url || '',
              leaderboard_id: record.leaderboard_id,
            })}
            style={{ padding: '4px 8px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            编辑
          </button>
          <button
            onClick={() => handleDeleteItem(record.id)}
            style={{ padding: '4px 8px', border: '1px solid #dc3545', background: 'white', color: '#dc3545', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            删除
          </button>
        </div>
      ),
    },
  ];

  const reviewsColumns: Column<any>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 60 },
    { key: 'name', title: '名称', dataIndex: 'name', width: 160 },
    {
      key: 'description',
      title: '描述',
      width: 250,
      render: (_, record) => (
        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block', maxWidth: '250px' }}>
          {record.description || '-'}
        </span>
      ),
    },
    {
      key: 'created_at',
      title: '提交时间',
      dataIndex: 'created_at',
      width: 150,
      render: (value) => (
        <span style={{ fontSize: '12px', color: '#666' }}>{new Date(value).toLocaleString('zh-CN')}</span>
      ),
    },
    {
      key: 'actions',
      title: '操作',
      width: 140,
      align: 'center',
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
          <button
            onClick={() => handleReview(record.id, 'approve')}
            style={{ padding: '4px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            批准
          </button>
          <button
            onClick={() => handleReview(record.id, 'reject')}
            style={{ padding: '4px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            拒绝
          </button>
        </div>
      ),
    },
  ];

  const itemModalFooter = (
    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
      <button
        onClick={itemModal.close}
        style={{ padding: '8px 16px', border: '1px solid #d9d9d9', borderRadius: '4px', background: 'white', cursor: 'pointer' }}
      >
        取消
      </button>
      <button
        onClick={itemModal.handleSubmit}
        disabled={itemModal.loading}
        style={{ padding: '8px 16px', border: 'none', borderRadius: '4px', background: '#007bff', color: 'white', cursor: itemModal.loading ? 'not-allowed' : 'pointer', opacity: itemModal.loading ? 0.7 : 1 }}
      >
        {itemModal.loading ? '提交中...' : itemModal.isEdit ? '更新' : '创建'}
      </button>
    </div>
  );

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>排行榜管理</h2>

      {/* 子标签页 */}
      <div style={{ display: 'flex', gap: '10px', marginBottom: '20px' }}>
        {(['items', 'votes', 'reviews'] as SubTab[]).map((tab) => (
          <button
            key={tab}
            onClick={() => setSubTab(tab)}
            style={{
              padding: '10px 20px',
              border: 'none',
              background: subTab === tab ? '#007bff' : '#f0f0f0',
              color: subTab === tab ? 'white' : 'black',
              cursor: 'pointer',
              borderRadius: '5px',
              fontSize: '14px',
              fontWeight: '500',
            }}
          >
            {tab === 'items' ? '竞品管理' : tab === 'votes' ? '投票记录' : '审核队列'}
          </button>
        ))}
      </div>

      {/* 竞品管理 */}
      {subTab === 'items' && (
        <div>
          <div style={{ marginBottom: '20px' }}>
            <button
              onClick={() => itemModal.open()}
              style={{ padding: '10px 20px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '14px', fontWeight: '500' }}
            >
              创建竞品
            </button>
          </div>
          <AdminTable
            columns={itemsColumns}
            data={itemsTable.data}
            loading={itemsTable.loading}
            refreshing={itemsTable.fetching}
            rowKey="id"
            emptyText="暂无竞品"
          />
          <AdminPagination
            currentPage={itemsTable.currentPage}
            totalPages={itemsTable.totalPages}
            total={itemsTable.total}
            pageSize={itemsTable.pageSize}
            onPageChange={itemsTable.setCurrentPage}
            onPageSizeChange={itemsTable.setPageSize}
          />
        </div>
      )}

      {/* 投票记录 */}
      {subTab === 'votes' && (
        <div>
          {/* 筛选器 */}
          <div style={{ background: 'white', padding: '20px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', marginBottom: '20px', display: 'flex', flexWrap: 'wrap', gap: '10px', alignItems: 'center' }}>
            <input
              type="number"
              placeholder="竞品ID"
              value={votesFilter.item_id || ''}
              onChange={(e) => setVotesFilter({ ...votesFilter, item_id: e.target.value ? parseInt(e.target.value) : undefined })}
              style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd', width: '120px' }}
            />
            <input
              type="number"
              placeholder="榜单ID"
              value={votesFilter.leaderboard_id || ''}
              onChange={(e) => setVotesFilter({ ...votesFilter, leaderboard_id: e.target.value ? parseInt(e.target.value) : undefined })}
              style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd', width: '120px' }}
            />
            <select
              value={votesFilter.is_anonymous === undefined ? '' : votesFilter.is_anonymous ? 'true' : 'false'}
              onChange={(e) => setVotesFilter({ ...votesFilter, is_anonymous: e.target.value === '' ? undefined : e.target.value === 'true' })}
              style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}
            >
              <option value="">全部</option>
              <option value="true">匿名</option>
              <option value="false">非匿名</option>
            </select>
            <input
              type="text"
              placeholder="搜索用户名/留言内容"
              value={votesFilter.keyword || ''}
              onChange={(e) => setVotesFilter({ ...votesFilter, keyword: e.target.value || undefined })}
              style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd', flex: 1, minWidth: '200px' }}
            />
            <button
              onClick={() => votesTable.refresh()}
              style={{ padding: '8px 16px', border: 'none', background: '#007bff', color: 'white', borderRadius: '4px', cursor: 'pointer' }}
            >
              搜索
            </button>
            <button
              onClick={() => { setVotesFilter({}); votesTable.refresh(); }}
              style={{ padding: '8px 16px', border: 'none', background: '#6c757d', color: 'white', borderRadius: '4px', cursor: 'pointer' }}
            >
              重置
            </button>
          </div>

          <AdminTable
            columns={votesColumns}
            data={votesTable.data}
            loading={votesTable.loading}
            refreshing={votesTable.fetching}
            rowKey="id"
            emptyText="暂无投票记录"
          />
          <AdminPagination
            currentPage={votesTable.currentPage}
            totalPages={votesTable.totalPages}
            total={votesTable.total}
            pageSize={votesTable.pageSize}
            onPageChange={votesTable.setCurrentPage}
            onPageSizeChange={votesTable.setPageSize}
          />
        </div>
      )}

      {/* 审核队列 */}
      {subTab === 'reviews' && (
        <div>
          <AdminTable
            columns={reviewsColumns}
            data={reviewsTable.data}
            loading={reviewsTable.loading}
            refreshing={reviewsTable.fetching}
            rowKey="id"
            emptyText="暂无待审核竞品"
          />
          <AdminPagination
            currentPage={reviewsTable.currentPage}
            totalPages={reviewsTable.totalPages}
            total={reviewsTable.total}
            pageSize={reviewsTable.pageSize}
            onPageChange={reviewsTable.setCurrentPage}
            onPageSizeChange={reviewsTable.setPageSize}
          />
        </div>
      )}

      {/* 竞品编辑模态框 */}
      <AdminModal
        isOpen={itemModal.isOpen}
        onClose={itemModal.close}
        title={itemModal.isEdit ? '编辑竞品' : '创建竞品'}
        footer={itemModalFooter}
        width="500px"
      >
        <div style={{ padding: '20px 0' }}>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              名称 <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="text"
              value={itemModal.formData.name}
              onChange={(e) => itemModal.updateField('name', e.target.value)}
              placeholder="请输入竞品名称"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>描述</label>
            <textarea
              value={itemModal.formData.description}
              onChange={(e) => itemModal.updateField('description', e.target.value)}
              placeholder="请输入竞品描述"
              rows={3}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>图片URL</label>
            <input
              type="text"
              value={itemModal.formData.image_url}
              onChange={(e) => itemModal.updateField('image_url', e.target.value)}
              placeholder="请输入图片URL"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
              榜单ID <span style={{ color: 'red' }}>*</span>
            </label>
            <input
              type="number"
              value={itemModal.formData.leaderboard_id}
              onChange={(e) => itemModal.updateField('leaderboard_id', e.target.value ? parseInt(e.target.value) : '')}
              placeholder="请输入榜单ID"
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
        </div>
      </AdminModal>
    </div>
  );
};

export default LeaderboardManagement;
