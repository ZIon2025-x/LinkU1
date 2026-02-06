import React, { useState, useEffect, useCallback } from 'react';
import { message, Modal } from 'antd';
import dayjs from 'dayjs';
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

interface FilterType {
  keyword?: string;
  status?: string;
  category?: string;
}

const statusColors: Record<string, string> = {
  active: '#52c41a',
  sold: '#1890ff',
  deleted: '#ff4d4f',
  pending: '#faad14'
};

const statusLabels: Record<string, string> = {
  active: '在售',
  sold: '已售出',
  deleted: '已删除',
  pending: '待审核'
};

/**
 * 跳蚤市场管理组件
 */
const FleaMarketManagement: React.FC = () => {
  const [items, setItems] = useState<FleaMarketItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [filter, setFilter] = useState<FilterType>({});
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState<Partial<FleaMarketItem>>({});

  const loadItems = useCallback(async () => {
    setLoading(true);
    try {
      const response = await getFleaMarketItemsAdmin({
        page,
        page_size: 20,
        keyword: filter.keyword,
        status_filter: filter.status,
        category: filter.category
      });
      setItems(response.items || []);
      setTotal(response.total || 0);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }, [page, filter]);

  useEffect(() => {
    loadItems();
  }, [loadItems]);

  const handleEdit = (item: FleaMarketItem) => {
    setForm({ ...item });
    setShowModal(true);
  };

  const handleSave = async () => {
    if (!form.id) return;
    try {
      await updateFleaMarketItemAdmin(String(form.id), {
        title: form.title,
        description: form.description,
        price: form.price,
        category: form.category,
        location: form.location,
        status: form.status
      });
      message.success('商品更新成功');
      setShowModal(false);
      loadItems();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
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
          loadItems();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      }
    });
  };

  const totalPages = Math.ceil(total / 20);

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>跳蚤市场管理</h2>

      {/* 筛选器 */}
      <div style={{ marginBottom: '20px', display: 'flex', gap: '10px', flexWrap: 'wrap', alignItems: 'center' }}>
        <input
          type="text"
          placeholder="搜索关键词（标题/描述）"
          value={filter.keyword || ''}
          onChange={(e) => setFilter({ ...filter, keyword: e.target.value })}
          style={{ padding: '8px', border: '1px solid #ddd', borderRadius: '4px', width: '200px' }}
          onKeyPress={(e) => {
            if (e.key === 'Enter') {
              setPage(1);
              loadItems();
            }
          }}
        />
        <select
          value={filter.status || ''}
          onChange={(e) => setFilter({ ...filter, status: e.target.value || undefined })}
          style={{ padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
        >
          <option value="">全部状态</option>
          <option value="active">在售</option>
          <option value="sold">已售出</option>
          <option value="deleted">已删除</option>
          <option value="pending">待审核</option>
        </select>
        <select
          value={filter.category || ''}
          onChange={(e) => setFilter({ ...filter, category: e.target.value || undefined })}
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
          onClick={() => { setPage(1); loadItems(); }}
          style={{ padding: '8px 16px', background: '#007bff', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
        >
          搜索
        </button>
      </div>

      {/* 列表 */}
      <div style={{ background: 'white', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', overflow: 'hidden' }}>
        {loading ? (
          <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
        ) : items.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无商品</div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#f8f9fa' }}>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>商品ID</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>标题</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>价格</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>分类</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>卖家</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>创建时间</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
              </tr>
            </thead>
            <tbody>
              {items.map((item) => (
                <tr key={item.id} style={{ borderBottom: '1px solid #f0f0f0' }}>
                  <td style={{ padding: '12px' }}>{item.id}</td>
                  <td style={{ padding: '12px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {item.title}
                  </td>
                  <td style={{ padding: '12px' }}>£{item.price}</td>
                  <td style={{ padding: '12px' }}>{item.category}</td>
                  <td style={{ padding: '12px' }}>{item.seller_name || '-'}</td>
                  <td style={{ padding: '12px' }}>
                    <span style={{
                      padding: '4px 8px',
                      borderRadius: '4px',
                      background: statusColors[item.status] || '#999',
                      color: 'white',
                      fontSize: '12px'
                    }}>
                      {statusLabels[item.status] || item.status}
                    </span>
                  </td>
                  <td style={{ padding: '12px', fontSize: '12px', color: '#666' }}>
                    {dayjs(item.created_at).format('YYYY-MM-DD HH:mm')}
                  </td>
                  <td style={{ padding: '12px' }}>
                    <button onClick={() => handleEdit(item)} style={{ marginRight: '8px', padding: '4px 8px', background: '#007bff', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>编辑</button>
                    {item.status !== 'deleted' && (
                      <button onClick={() => handleDelete(item.id)} style={{ padding: '4px 8px', background: '#ff4d4f', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>删除</button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* 分页 */}
      <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <span style={{ color: '#666' }}>共 {total} 条记录</span>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button onClick={() => page > 1 && setPage(page - 1)} disabled={page === 1} style={{ padding: '8px 16px', border: '1px solid #ddd', borderRadius: '4px', cursor: page === 1 ? 'not-allowed' : 'pointer', opacity: page === 1 ? 0.5 : 1 }}>上一页</button>
          <span style={{ padding: '8px', color: '#666' }}>第 {page} 页，共 {totalPages} 页</span>
          <button onClick={() => page < totalPages && setPage(page + 1)} disabled={page >= totalPages} style={{ padding: '8px 16px', border: '1px solid #ddd', borderRadius: '4px', cursor: page >= totalPages ? 'not-allowed' : 'pointer', opacity: page >= totalPages ? 0.5 : 1 }}>下一页</button>
        </div>
      </div>

      {/* 编辑模态框 */}
      <Modal
        title="编辑商品"
        open={showModal}
        onOk={handleSave}
        onCancel={() => { setShowModal(false); setForm({}); }}
        okText="保存"
        cancelText="取消"
        width={600}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', padding: '20px 0' }}>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>标题：</label>
            <input type="text" value={form.title || ''} onChange={(e) => setForm({ ...form, title: e.target.value })} style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }} />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>描述：</label>
            <textarea value={form.description || ''} onChange={(e) => setForm({ ...form, description: e.target.value })} style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', minHeight: '100px' }} />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>价格：</label>
            <input type="number" value={form.price || ''} onChange={(e) => setForm({ ...form, price: parseFloat(e.target.value) })} style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }} />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>分类：</label>
            <select value={form.category || ''} onChange={(e) => setForm({ ...form, category: e.target.value })} style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}>
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
            <input type="text" value={form.location || ''} onChange={(e) => setForm({ ...form, location: e.target.value })} style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }} />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold' }}>状态：</label>
            <select value={form.status || 'active'} onChange={(e) => setForm({ ...form, status: e.target.value as any })} style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}>
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
