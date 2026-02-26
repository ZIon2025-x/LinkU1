import React, { useState, useCallback, useEffect } from 'react';
import { message, Modal } from 'antd';
import { getAdminCancelRequests, reviewAdminCancelRequest } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface CancelRequest {
  id: number;
  task_id: number;
  requester_id: number;
  status: string;
  admin_comment?: string;
  created_at: string;
  reviewed_at?: string;
}

const CancelRequestsManagement: React.FC = () => {
  const [list, setList] = useState<CancelRequest[]>([]);
  const [loading, setLoading] = useState(false);

  const loadList = useCallback(async () => {
    setLoading(true);
    try {
      const res = await getAdminCancelRequests();
      setList(Array.isArray(res) ? res : []);
    } catch (e) {
      message.error(getErrorMessage(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadList();
  }, [loadList]);

  const [reviewModal, setReviewModal] = useState<{ request: CancelRequest; decision: 'approve' | 'reject' } | null>(null);
  const [reviewComment, setReviewComment] = useState('');

  const handleReview = (request: CancelRequest, decision: 'approve' | 'reject') => {
    setReviewModal({ request, decision });
    setReviewComment('');
  };

  const submitReview = async () => {
    if (!reviewModal) return;
    try {
      await reviewAdminCancelRequest(reviewModal.request.id, {
        decision: reviewModal.decision,
        admin_comment: reviewComment.trim() || undefined,
      });
      message.success(reviewModal.decision === 'approve' ? '已批准' : '已拒绝');
      setReviewModal(null);
      loadList();
    } catch (e) {
      message.error(getErrorMessage(e));
    }
  };

  const pending = list.filter((r) => r.status === 'pending');

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>任务取消申请</h2>
      <p style={{ color: '#666', marginBottom: '16px' }}>待处理: {pending.length} 条</p>

      <div style={{ overflowX: 'auto' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', background: 'white', boxShadow: '0 2px 4px rgba(0,0,0,0.08)', borderRadius: '8px' }}>
          <thead>
            <tr style={{ borderBottom: '1px solid #eee' }}>
              <th style={{ padding: '12px', textAlign: 'left', width: '80px' }}>ID</th>
              <th style={{ padding: '12px', textAlign: 'left', width: '100px' }}>任务ID</th>
              <th style={{ padding: '12px', textAlign: 'left', width: '100px' }}>申请人</th>
              <th style={{ padding: '12px', textAlign: 'left', width: '90px' }}>状态</th>
              <th style={{ padding: '12px', textAlign: 'left', width: '160px' }}>申请时间</th>
              <th style={{ padding: '12px', textAlign: 'left' }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {loading && (
              <tr>
                <td colSpan={6} style={{ padding: '24px', textAlign: 'center', color: '#999' }}>加载中...</td>
              </tr>
            )}
            {!loading && list.length === 0 && (
              <tr>
                <td colSpan={6} style={{ padding: '24px', textAlign: 'center', color: '#999' }}>暂无取消申请</td>
              </tr>
            )}
            {!loading && list.map((r) => (
              <tr key={r.id} style={{ borderBottom: '1px solid #f0f0f0' }}>
                <td style={{ padding: '12px' }}>{r.id}</td>
                <td style={{ padding: '12px' }}>{r.task_id}</td>
                <td style={{ padding: '12px' }}>{r.requester_id}</td>
                <td style={{ padding: '12px' }}>{r.status}</td>
                <td style={{ padding: '12px' }}>{r.created_at ? new Date(r.created_at).toLocaleString('zh-CN') : '-'}</td>
                <td style={{ padding: '12px' }}>
                  {r.status === 'pending' && (
                    <>
                      <button
                        type="button"
                        onClick={() => handleReview(r, 'approve')}
                        style={{ marginRight: '8px', padding: '4px 8px', fontSize: '12px', background: '#52c41a', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
                      >
                        批准
                      </button>
                      <button
                        type="button"
                        onClick={() => handleReview(r, 'reject')}
                        style={{ padding: '4px 8px', fontSize: '12px', background: '#ff4d4f', color: 'white', border: 'none', borderRadius: '4px', cursor: 'pointer' }}
                      >
                        拒绝
                      </button>
                    </>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {reviewModal && (
        <Modal
          title={reviewModal.decision === 'approve' ? '批准取消申请' : '拒绝取消申请'}
          open={!!reviewModal}
          onCancel={() => setReviewModal(null)}
          onOk={submitReview}
          okText={reviewModal.decision === 'approve' ? '批准' : '拒绝'}
        >
          <p>申请 #{reviewModal.request.id}，任务 ID: {reviewModal.request.task_id}，申请人: {reviewModal.request.requester_id}</p>
          <textarea
            placeholder="管理员备注（选填）"
            rows={3}
            value={reviewComment}
            onChange={(e) => setReviewComment(e.target.value)}
            style={{ width: '100%', marginTop: '8px', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
          />
        </Modal>
      )}
    </div>
  );
};

export default CancelRequestsManagement;
