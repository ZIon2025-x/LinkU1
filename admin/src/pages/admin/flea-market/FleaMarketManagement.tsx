import React, { useState, useCallback } from 'react';
import { message, Modal } from 'antd';
import dayjs from 'dayjs';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, StatusBadge, Column } from '../../../components/admin';
import { getFleaMarketItemsAdmin, updateFleaMarketItemAdmin, deleteFleaMarketItemAdmin } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface FleaMarketItem {
  id: number;
  title: string;
  description?: string;
  price: number;
  category: string;
  seller_name?: string;
  seller_id?: number;
  status: 'active' | 'sold' | 'deleted' | 'pending';
  location?: string;
  created_at: string;
}

const statusVariantMap: Record<string, { text: string; variant: 'success' | 'primary' | 'danger' | 'warning' }> = {
  active: { text: '在售', variant: 'success' },
  sold: { text: '已售出', variant: 'primary' },
  deleted: { text: '已删除', variant: 'danger' },
  pending: { text: '待审核', variant: 'warning' }
};

/**
 * 跳蚤市场管理组件
 */
const FleaMarketManagement: React.FC = () => {
  const [keyword, setKeyword] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('');

  const fetchItems = useCallback(async ({ page, pageSize, filters }: { page: number; pageSize: number; filters?: Record<string, any> }) => {
    const response = await getFleaMarketItemsAdmin({
      page,
      page_size: pageSize,
      keyword: filters?.keyword,
      status_filter: filters?.status,
      category: filters?.category
    });
    return {
      data: response.items || [],
      total: response.total || 0
    };
  }, []);

  const handleFetchError = useCallback((error: any) => {
    message.error(getErrorMessage(error));
  }, []);

  const table = useAdminTable<FleaMarketItem>({
    fetchData: fetchItems,
    initialPageSize: 20,
    onError: handleFetchError,
  });

  const modal = useModalForm<Partial<FleaMarketItem>>({
    initialValues: {},
    onSubmit: async (values) => {
      if (!values.id) return;
      await updateFleaMarketItemAdmin(String(values.id), {
        title: values.title,
        description: values.description,
        price: values.price,
        category: values.category,
        location: values.location,
        status: values.status
      });
      message.success('商品更新成功');
      table.refresh();
    },
    onError: (error) => {
      message.error(getErrorMessage(error));
    },
  });

  const handleEdit = (item: FleaMarketItem) => {
    modal.open({ ...item });
  };

  const handleDelete = (id: number) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除这个商品吗？',
      okText: '确定',
      cancelText: '取消',
      okButtonProps: { danger: true },
      onOk: async () => {
        try {
          await deleteFleaMarketItemAdmin(String(id));
          message.success('商品删除成功');
          table.refresh();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      }
    });
  };

  const handleSearch = () => {
    table.setFilters({
      keyword: keyword || undefined,
      status: statusFilter || undefined,
      category: categoryFilter || undefined
    });
  };

  const columns: Column<FleaMarketItem>[] = [
    {
      key: 'id',
      title: '商品ID',
      dataIndex: 'id',
      width: 90,
    },
    {
      key: 'title',
      title: '标题',
      dataIndex: 'title',
      width: 200,
      render: (value) => (
        <span style={{ maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block' }}>
          {value}
        </span>
      ),
    },
    {
      key: 'price',
      title: '价格',
      dataIndex: 'price',
      width: 100,
      render: (value) => `£${value}`,
    },
    {
      key: 'category',
      title: '分类',
      dataIndex: 'category',
      width: 120,
    },
    {
      key: 'seller_name',
      title: '卖家',
      dataIndex: 'seller_name',
      width: 120,
      render: (value) => value || '-',
    },
    {
      key: 'status',
      title: '状态',
      dataIndex: 'status',
      width: 100,
      render: (value) => {
        const config = statusVariantMap[value] || { text: value, variant: 'default' as const };
        return <StatusBadge text={config.text} variant={config.variant} />;
      },
    },
    {
      key: 'created_at',
      title: '创建时间',
      dataIndex: 'created_at',
      width: 150,
      render: (value) => (
        <span style={{ fontSize: '12px', color: '#666' }}>
          {dayjs(value).format('YYYY-MM-DD HH:mm')}
        </span>
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
            onClick={() => handleEdit(record)}
            style={{ padding: '4px 8px', background: '#007bff', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            编辑
          </button>
          {record.status !== 'deleted' && (
            <button
              onClick={() => handleDelete(record.id)}
              style={{ padding: '4px 8px', background: '#ff4d4f', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
            >
              删除
            </button>
          )}
        </div>
      ),
    },
  ];

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>跳蚤市场管理</h2>

      {/* 筛选器 */}
      <div style={{ marginBottom: '20px', display: 'flex', gap: '10px', flexWrap: 'wrap', alignItems: 'center' }}>
        <input
          type="text"
          placeholder="搜索关键词（标题/描述）"
          value={keyword}
          onChange={(e) => setKeyword(e.target.value)}
          onKeyPress={(e) => { if (e.key === 'Enter') handleSearch(); }}
          style={{ padding: '8px', border: '1px solid #ddd', borderRadius: '4px', width: '200px' }}
        />
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          style={{ padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
        >
          <option value="">全部状态</option>
          <option value="active">在售</option>
          <option value="sold">已售出</option>
          <option value="deleted">已删除</option>
          <option value="pending">待审核</option>
        </select>
        <select
          value={categoryFilter}
          onChange={(e) => setCategoryFilter(e.target.value)}
          style={{ padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
        >
          <option value="">全部分类</option>
          <option value="Electronics">电子产品</option>
          <option value="Furniture">家具</option>
          <option value="Clothing">服装</option>
          <option value="Books">书籍</option>
          <option value="Sports">运动用品</option>
          <option value="Other">其他</option>
        </select>
        <button
          onClick={handleSearch}
          style={{ padding: '8px 16px', background: '#007bff', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
        >
          搜索
        </button>
      </div>

      <AdminTable
        columns={columns}
        data={table.data}
        loading={table.loading}
        rowKey="id"
        emptyText="暂无商品"
      />

      <AdminPagination
        currentPage={table.currentPage}
        totalPages={table.totalPages}
        total={table.total}
        pageSize={table.pageSize}
        onPageChange={table.setCurrentPage}
        onPageSizeChange={table.setPageSize}
      />

      {/* 编辑模态框 */}
      <Modal
        title="编辑商品"
        open={modal.isOpen}
        onOk={modal.handleSubmit}
        onCancel={modal.close}
        confirmLoading={modal.loading}
        okText="保存"
        cancelText="取消"
        width={600}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', padding: '20px 0' }}>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>标题：</label>
            <input
              type="text"
              value={modal.formData.title || ''}
              onChange={(e) => modal.updateField('title', e.target.value)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>描述：</label>
            <textarea
              value={modal.formData.description || ''}
              onChange={(e) => modal.updateField('description', e.target.value)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', minHeight: '100px', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>价格：</label>
            <input
              type="number"
              value={modal.formData.price || ''}
              onChange={(e) => modal.updateField('price', parseFloat(e.target.value))}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>分类：</label>
            <select
              value={modal.formData.category || ''}
              onChange={(e) => modal.updateField('category', e.target.value)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            >
              <option value="Electronics">电子产品</option>
              <option value="Furniture">家具</option>
              <option value="Clothing">服装</option>
              <option value="Books">书籍</option>
              <option value="Sports">运动用品</option>
              <option value="Other">其他</option>
            </select>
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>位置：</label>
            <input
              type="text"
              value={modal.formData.location || ''}
              onChange={(e) => modal.updateField('location', e.target.value)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>状态：</label>
            <select
              value={modal.formData.status || 'active'}
              onChange={(e) => modal.updateField('status', e.target.value as FleaMarketItem['status'])}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            >
              <option value="active">在售</option>
              <option value="sold">已售出</option>
              <option value="deleted">已删除</option>
              <option value="pending">待审核</option>
            </select>
          </div>
        </div>
      </Modal>
    </div>
  );
};

export default FleaMarketManagement;
