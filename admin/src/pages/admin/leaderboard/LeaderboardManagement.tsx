import React, { useState, useEffect, useCallback } from 'react';
import { message, Modal } from 'antd';
import {
  getLeaderboardVotesAdmin,
  getLeaderboardItemsAdmin,
  createLeaderboardItemAdmin,
  updateLeaderboardItemAdmin,
  deleteLeaderboardItemAdmin,
  getCustomLeaderboardsAdmin,
  reviewCustomLeaderboard
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

/**
 * 排行榜管理组件
 */
const LeaderboardManagement: React.FC = () => {
  const [subTab, setSubTab] = useState<SubTab>('items');

  // 投票记录
  const [votes, setVotes] = useState<Vote[]>([]);
  const [votesLoading, setVotesLoading] = useState(false);
  const [votesPage, setVotesPage] = useState(1);
  const [votesFilter, setVotesFilter] = useState<{ item_id?: number; leaderboard_id?: number; is_anonymous?: boolean; keyword?: string }>({});

  // 竞品管理
  const [items, setItems] = useState<LeaderboardItem[]>([]);
  const [itemsLoading, setItemsLoading] = useState(false);
  const [itemsPage, setItemsPage] = useState(1);
  const [itemsTotal, setItemsTotal] = useState(0);
  const [showItemModal, setShowItemModal] = useState(false);
  const [itemForm, setItemForm] = useState<Partial<LeaderboardItem>>({});

  // 审核队列
  const [reviews, setReviews] = useState<any[]>([]);
  const [reviewsLoading, setReviewsLoading] = useState(false);

  const loadVotes = useCallback(async () => {
    setVotesLoading(true);
    try {
      const response = await getLeaderboardVotesAdmin({ page: votesPage, limit: 50, ...votesFilter });
      setVotes(response.items || []);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setVotesLoading(false);
    }
  }, [votesPage, votesFilter]);

  const loadItems = useCallback(async () => {
    setItemsLoading(true);
    try {
      const response = await getLeaderboardItemsAdmin({ page: itemsPage, limit: 20 });
      setItems(response.items || []);
      setItemsTotal(response.total || 0);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setItemsLoading(false);
    }
  }, [itemsPage]);

  const loadReviews = useCallback(async () => {
    setReviewsLoading(true);
    try {
      const response = await getCustomLeaderboardsAdmin({ status: 'pending' });
      setReviews(response.items || []);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setReviewsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (subTab === 'votes') loadVotes();
    else if (subTab === 'items') loadItems();
    else if (subTab === 'reviews') loadReviews();
  }, [subTab, loadVotes, loadItems, loadReviews]);

  const handleSaveItem = async () => {
    if (!itemForm.name) {
      message.warning('请填写竞品名称');
      return;
    }
    try {
      if (itemForm.id) {
        await updateLeaderboardItemAdmin(itemForm.id, itemForm);
        message.success('竞品更新成功');
      } else {
        await createLeaderboardItemAdmin(itemForm as any);
        message.success('竞品创建成功');
      }
      setShowItemModal(false);
      setItemForm({});
      loadItems();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const handleDeleteItem = (id: number) => {
    Modal.confirm({
      title: '确认删除',
      content: '确定要删除这个竞品吗？',
      okText: '确定',
      cancelText: '取消',
      onOk: async () => {
        try {
          await deleteLeaderboardItemAdmin(id);
          message.success('竞品删除成功');
          loadItems();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      }
    });
  };

  const handleReview = async (id: number, action: 'approve' | 'reject') => {
    try {
      await reviewCustomLeaderboard(id, action);
      message.success(action === 'approve' ? '已批准' : '已拒绝');
      loadReviews();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const renderVotes = () => (
    <div>
      {/* 筛选 */}
      <div style={{ background: 'white', padding: '20px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', marginBottom: '20px', display: 'flex', flexWrap: 'wrap', gap: '10px', alignItems: 'center' }}>
        <input type="number" placeholder="竞品ID" value={votesFilter.item_id || ''} onChange={(e) => setVotesFilter({ ...votesFilter, item_id: e.target.value ? parseInt(e.target.value) : undefined })} style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd', width: '120px' }} />
        <input type="number" placeholder="榜单ID" value={votesFilter.leaderboard_id || ''} onChange={(e) => setVotesFilter({ ...votesFilter, leaderboard_id: e.target.value ? parseInt(e.target.value) : undefined })} style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd', width: '120px' }} />
        <select value={votesFilter.is_anonymous === undefined ? '' : votesFilter.is_anonymous ? 'true' : 'false'} onChange={(e) => setVotesFilter({ ...votesFilter, is_anonymous: e.target.value === '' ? undefined : e.target.value === 'true' })} style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd' }}>
          <option value="">全部</option>
          <option value="true">匿名</option>
          <option value="false">非匿名</option>
        </select>
        <input type="text" placeholder="搜索用户名/留言内容" value={votesFilter.keyword || ''} onChange={(e) => setVotesFilter({ ...votesFilter, keyword: e.target.value || undefined })} style={{ padding: '8px', borderRadius: '4px', border: '1px solid #ddd', flex: 1, minWidth: '200px' }} />
        <button onClick={() => { setVotesPage(1); loadVotes(); }} style={{ padding: '8px 16px', border: 'none', background: '#007bff', color: 'white', borderRadius: '4px', cursor: 'pointer' }}>搜索</button>
        <button onClick={() => { setVotesFilter({}); setVotesPage(1); loadVotes(); }} style={{ padding: '8px 16px', border: 'none', background: '#6c757d', color: 'white', borderRadius: '4px', cursor: 'pointer' }}>重置</button>
      </div>

      {/* 列表 */}
      <div style={{ background: 'white', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', overflow: 'auto' }}>
        {votesLoading ? (
          <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
        ) : votes.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无投票记录</div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: '800px' }}>
            <thead>
              <tr style={{ background: '#f8f9fa' }}>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>竞品ID</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>用户ID</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>投票类型</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>留言</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>匿名</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>创建时间</th>
              </tr>
            </thead>
            <tbody>
              {votes.map((vote) => (
                <tr key={vote.id} style={{ borderBottom: '1px solid #f0f0f0' }}>
                  <td style={{ padding: '12px' }}>{vote.id}</td>
                  <td style={{ padding: '12px' }}>{vote.item_id}</td>
                  <td style={{ padding: '12px' }}>{vote.is_anonymous ? <span style={{ color: '#999', fontStyle: 'italic' }}>匿名</span> : vote.user_id}</td>
                  <td style={{ padding: '12px' }}>
                    <span style={{ padding: '4px 8px', borderRadius: '4px', background: vote.vote_type === 'upvote' ? '#52c41a' : '#ff4d4f', color: 'white', fontSize: '12px' }}>
                      {vote.vote_type === 'upvote' ? '👍 点赞' : '👎 点踩'}
                    </span>
                  </td>
                  <td style={{ padding: '12px', maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{vote.comment || <span style={{ color: '#999', fontStyle: 'italic' }}>（无留言）</span>}</td>
                  <td style={{ padding: '12px' }}>{vote.is_anonymous ? <span style={{ color: '#ff4d4f', fontWeight: 'bold' }}>是</span> : <span style={{ color: '#52c41a' }}>否</span>}</td>
                  <td style={{ padding: '12px', fontSize: '12px', color: '#666' }}>{new Date(vote.created_at).toLocaleString('zh-CN')}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* 分页 */}
      <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'center' }}>
        <button onClick={() => votesPage > 1 && setVotesPage(votesPage - 1)} disabled={votesPage === 1} style={{ padding: '8px 16px', margin: '0 4px', border: '1px solid #ddd', background: votesPage === 1 ? '#f0f0f0' : 'white', cursor: votesPage === 1 ? 'not-allowed' : 'pointer', borderRadius: '4px' }}>上一页</button>
        <span style={{ padding: '8px 16px' }}>第 {votesPage} 页</span>
        <button onClick={() => votes.length === 50 && setVotesPage(votesPage + 1)} disabled={votes.length < 50} style={{ padding: '8px 16px', margin: '0 4px', border: '1px solid #ddd', background: votes.length < 50 ? '#f0f0f0' : 'white', cursor: votes.length < 50 ? 'not-allowed' : 'pointer', borderRadius: '4px' }}>下一页</button>
      </div>
    </div>
  );

  const renderItems = () => (
    <div>
      <div style={{ marginBottom: '20px' }}>
        <button onClick={() => { setItemForm({}); setShowItemModal(true); }} style={{ padding: '10px 20px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '14px', fontWeight: '500' }}>创建竞品</button>
      </div>

      <div style={{ background: 'white', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', overflow: 'hidden' }}>
        {itemsLoading ? (
          <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
        ) : items.length === 0 ? (
          <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无竞品</div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#f8f9fa' }}>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>名称</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>描述</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>榜单ID</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>票数</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
                <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
              </tr>
            </thead>
            <tbody>
              {items.map((item) => (
                <tr key={item.id} style={{ borderBottom: '1px solid #f0f0f0' }}>
                  <td style={{ padding: '12px' }}>{item.id}</td>
                  <td style={{ padding: '12px', fontWeight: '500' }}>{item.name}</td>
                  <td style={{ padding: '12px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.description || '-'}</td>
                  <td style={{ padding: '12px' }}>{item.leaderboard_id}</td>
                  <td style={{ padding: '12px' }}>{item.vote_count}</td>
                  <td style={{ padding: '12px' }}>
                    <span style={{ padding: '4px 8px', borderRadius: '4px', background: item.status === 'active' ? '#d4edda' : '#f8d7da', color: item.status === 'active' ? '#155724' : '#721c24', fontSize: '12px' }}>{item.status}</span>
                  </td>
                  <td style={{ padding: '12px' }}>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      <button onClick={() => { setItemForm(item); setShowItemModal(true); }} style={{ padding: '4px 8px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>编辑</button>
                      <button onClick={() => handleDeleteItem(item.id)} style={{ padding: '4px 8px', border: '1px solid #dc3545', background: 'white', color: '#dc3545', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>删除</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* 分页 */}
      {itemsTotal > 20 && (
        <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'center', gap: '10px' }}>
          <button onClick={() => itemsPage > 1 && setItemsPage(itemsPage - 1)} disabled={itemsPage === 1} style={{ padding: '8px 16px', border: '1px solid #ddd', borderRadius: '4px', cursor: itemsPage === 1 ? 'not-allowed' : 'pointer' }}>上一页</button>
          <span style={{ padding: '8px 16px', alignSelf: 'center' }}>第 {itemsPage} 页，共 {Math.ceil(itemsTotal / 20)} 页</span>
          <button onClick={() => itemsPage < Math.ceil(itemsTotal / 20) && setItemsPage(itemsPage + 1)} disabled={itemsPage >= Math.ceil(itemsTotal / 20)} style={{ padding: '8px 16px', border: '1px solid #ddd', borderRadius: '4px', cursor: itemsPage >= Math.ceil(itemsTotal / 20) ? 'not-allowed' : 'pointer' }}>下一页</button>
        </div>
      )}

      {/* 模态框 */}
      <Modal title={itemForm.id ? '编辑竞品' : '创建竞品'} open={showItemModal} onCancel={() => { setShowItemModal(false); setItemForm({}); }} onOk={handleSaveItem} okText={itemForm.id ? '更新' : '创建'} cancelText="取消" width={500}>
        <div style={{ padding: '20px 0' }}>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>名称 <span style={{ color: 'red' }}>*</span></label>
            <input type="text" value={itemForm.name || ''} onChange={(e) => setItemForm({ ...itemForm, name: e.target.value })} placeholder="请输入竞品名称" style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }} />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>描述</label>
            <textarea value={itemForm.description || ''} onChange={(e) => setItemForm({ ...itemForm, description: e.target.value })} placeholder="请输入竞品描述" rows={3} style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical' }} />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>图片URL</label>
            <input type="text" value={itemForm.image_url || ''} onChange={(e) => setItemForm({ ...itemForm, image_url: e.target.value })} placeholder="请输入图片URL" style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }} />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>榜单ID <span style={{ color: 'red' }}>*</span></label>
            <input type="number" value={itemForm.leaderboard_id || ''} onChange={(e) => setItemForm({ ...itemForm, leaderboard_id: parseInt(e.target.value) })} placeholder="请输入榜单ID" style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }} />
          </div>
        </div>
      </Modal>
    </div>
  );

  const renderReviews = () => (
    <div style={{ background: 'white', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', overflow: 'hidden' }}>
      {reviewsLoading ? (
        <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
      ) : reviews.length === 0 ? (
        <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无待审核竞品</div>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ background: '#f8f9fa' }}>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>名称</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>描述</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>提交时间</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {reviews.map((item: any) => (
              <tr key={item.id} style={{ borderBottom: '1px solid #f0f0f0' }}>
                <td style={{ padding: '12px' }}>{item.id}</td>
                <td style={{ padding: '12px', fontWeight: '500' }}>{item.name}</td>
                <td style={{ padding: '12px', maxWidth: '250px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.description || '-'}</td>
                <td style={{ padding: '12px', fontSize: '12px', color: '#666' }}>{new Date(item.created_at).toLocaleString('zh-CN')}</td>
                <td style={{ padding: '12px' }}>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <button onClick={() => handleReview(item.id, 'approve')} style={{ padding: '4px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>批准</button>
                    <button onClick={() => handleReview(item.id, 'reject')} style={{ padding: '4px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>拒绝</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
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
              fontWeight: '500'
            }}
          >
            {tab === 'items' ? '竞品管理' : tab === 'votes' ? '投票记录' : '审核队列'}
          </button>
        ))}
      </div>

      {/* 内容 */}
      {subTab === 'votes' && renderVotes()}
      {subTab === 'items' && renderItems()}
      {subTab === 'reviews' && renderReviews()}
    </div>
  );
};

export default LeaderboardManagement;
