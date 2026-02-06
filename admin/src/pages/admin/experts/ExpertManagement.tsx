import React, { useState, useEffect, useCallback } from 'react';
import { message, Modal } from 'antd';
import {
  getTaskExperts,
  getTaskExpertApplications,
  reviewTaskExpertApplication,
  getProfileUpdateRequests,
  reviewProfileUpdateRequest
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

type SubTab = 'list' | 'applications' | 'profile_updates';

/**
 * 专家管理组件
 * 管理任务达人列表、申请审核和资料修改审核
 */
const ExpertManagement: React.FC = () => {
  const [subTab, setSubTab] = useState<SubTab>('list');
  
  // 达人列表
  const [experts, setExperts] = useState<any[]>([]);
  const [expertsLoading, setExpertsLoading] = useState(false);
  const [expertsPage, setExpertsPage] = useState(1);
  const [expertsTotal, setExpertsTotal] = useState(0);

  // 申请列表
  const [applications, setApplications] = useState<any[]>([]);
  const [applicationsLoading, setApplicationsLoading] = useState(false);

  // 资料修改请求
  const [profileUpdates, setProfileUpdates] = useState<any[]>([]);
  const [profileUpdatesLoading, setProfileUpdatesLoading] = useState(false);

  // 审核模态框
  const [showReviewModal, setShowReviewModal] = useState(false);
  const [reviewItem, setReviewItem] = useState<any>(null);
  const [reviewType, setReviewType] = useState<'application' | 'profile'>('application');
  const [reviewAction, setReviewAction] = useState<'approve' | 'reject'>('approve');
  const [reviewComment, setReviewComment] = useState('');

  const loadExperts = useCallback(async () => {
    setExpertsLoading(true);
    try {
      const response = await getTaskExperts({ page: expertsPage, limit: 20 });
      setExperts(response.items || []);
      setExpertsTotal(response.total || 0);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setExpertsLoading(false);
    }
  }, [expertsPage]);

  const loadApplications = useCallback(async () => {
    setApplicationsLoading(true);
    try {
      const response = await getTaskExpertApplications({ status: 'pending' });
      setApplications(response.items || []);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setApplicationsLoading(false);
    }
  }, []);

  const loadProfileUpdates = useCallback(async () => {
    setProfileUpdatesLoading(true);
    try {
      const response = await getProfileUpdateRequests({ status: 'pending' });
      setProfileUpdates(response.items || []);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setProfileUpdatesLoading(false);
    }
  }, []);

  useEffect(() => {
    if (subTab === 'list') loadExperts();
    else if (subTab === 'applications') loadApplications();
    else if (subTab === 'profile_updates') loadProfileUpdates();
  }, [subTab, loadExperts, loadApplications, loadProfileUpdates]);

  const openReview = (item: any, type: 'application' | 'profile', action: 'approve' | 'reject') => {
    setReviewItem(item);
    setReviewType(type);
    setReviewAction(action);
    setReviewComment('');
    setShowReviewModal(true);
  };

  const handleReview = async () => {
    if (!reviewItem) return;

    try {
      if (reviewType === 'application') {
        await reviewTaskExpertApplication(reviewItem.id, {
          action: reviewAction,
          comment: reviewComment || undefined
        });
      } else {
        await reviewProfileUpdateRequest(reviewItem.id, {
          action: reviewAction,
          comment: reviewComment || undefined
        });
      }
      message.success(reviewAction === 'approve' ? '已批准' : '已拒绝');
      setShowReviewModal(false);
      if (reviewType === 'application') loadApplications();
      else loadProfileUpdates();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const renderExperts = () => (
    <div style={{ background: 'white', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', overflow: 'hidden' }}>
      {expertsLoading ? (
        <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
      ) : experts.length === 0 ? (
        <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无达人数据</div>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ background: '#f8f9fa' }}>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>用户</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>擅长领域</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>城市</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>评分</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>状态</th>
            </tr>
          </thead>
          <tbody>
            {experts.map((expert: any) => (
              <tr key={expert.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                <td style={{ padding: '12px' }}>{expert.id}</td>
                <td style={{ padding: '12px' }}>{expert.user_name || expert.user_id}</td>
                <td style={{ padding: '12px' }}>{expert.expertise?.join(', ') || '-'}</td>
                <td style={{ padding: '12px' }}>{expert.city || '-'}</td>
                <td style={{ padding: '12px' }}>{expert.rating?.toFixed(1) || '-'}</td>
                <td style={{ padding: '12px' }}>
                  <span style={{
                    padding: '4px 8px',
                    borderRadius: '4px',
                    background: expert.is_active ? '#d4edda' : '#f8d7da',
                    color: expert.is_active ? '#155724' : '#721c24',
                    fontSize: '12px'
                  }}>
                    {expert.is_active ? '活跃' : '停用'}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );

  const renderApplications = () => (
    <div style={{ background: 'white', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', overflow: 'hidden' }}>
      {applicationsLoading ? (
        <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
      ) : applications.length === 0 ? (
        <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无待审核申请</div>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ background: '#f8f9fa' }}>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>申请人</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>擅长领域</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>自我介绍</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>申请时间</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {applications.map((app: any) => (
              <tr key={app.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                <td style={{ padding: '12px' }}>{app.id}</td>
                <td style={{ padding: '12px' }}>{app.user_name || app.user_id}</td>
                <td style={{ padding: '12px' }}>{app.expertise?.join(', ') || '-'}</td>
                <td style={{ padding: '12px', maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{app.bio || '-'}</td>
                <td style={{ padding: '12px' }}>{new Date(app.created_at).toLocaleString('zh-CN')}</td>
                <td style={{ padding: '12px' }}>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <button onClick={() => openReview(app, 'application', 'approve')} style={{ padding: '4px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>批准</button>
                    <button onClick={() => openReview(app, 'application', 'reject')} style={{ padding: '4px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>拒绝</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );

  const renderProfileUpdates = () => (
    <div style={{ background: 'white', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)', overflow: 'hidden' }}>
      {profileUpdatesLoading ? (
        <div style={{ padding: '40px', textAlign: 'center' }}>加载中...</div>
      ) : profileUpdates.length === 0 ? (
        <div style={{ padding: '40px', textAlign: 'center', color: '#999' }}>暂无待审核资料修改请求</div>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ background: '#f8f9fa' }}>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>ID</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>达人</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>修改内容</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>申请时间</th>
              <th style={{ padding: '12px', textAlign: 'left', borderBottom: '1px solid #dee2e6', fontWeight: '600' }}>操作</th>
            </tr>
          </thead>
          <tbody>
            {profileUpdates.map((update: any) => (
              <tr key={update.id} style={{ borderBottom: '1px solid #dee2e6' }}>
                <td style={{ padding: '12px' }}>{update.id}</td>
                <td style={{ padding: '12px' }}>{update.expert_name || update.expert_id}</td>
                <td style={{ padding: '12px', maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{JSON.stringify(update.changes || {})}</td>
                <td style={{ padding: '12px' }}>{new Date(update.created_at).toLocaleString('zh-CN')}</td>
                <td style={{ padding: '12px' }}>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <button onClick={() => openReview(update, 'profile', 'approve')} style={{ padding: '4px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>批准</button>
                    <button onClick={() => openReview(update, 'profile', 'reject')} style={{ padding: '4px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}>拒绝</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );

  const totalPages = Math.ceil(expertsTotal / 20);

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>任务达人管理</h2>

      {/* 子标签页 */}
      <div style={{ display: 'flex', gap: '10px', marginBottom: '20px' }}>
        {(['list', 'applications', 'profile_updates'] as SubTab[]).map((tab) => (
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
            {tab === 'list' ? '达人列表' : tab === 'applications' ? '申请审核' : '资料修改审核'}
          </button>
        ))}
      </div>

      {/* 内容 */}
      {subTab === 'list' && (
        <>
          {renderExperts()}
          {expertsTotal > 20 && (
            <div style={{ marginTop: '20px', display: 'flex', justifyContent: 'center', gap: '10px' }}>
              <button onClick={() => expertsPage > 1 && setExpertsPage(expertsPage - 1)} disabled={expertsPage === 1} style={{ padding: '8px 16px', border: '1px solid #ddd', background: expertsPage === 1 ? '#f5f5f5' : 'white', borderRadius: '4px', cursor: expertsPage === 1 ? 'not-allowed' : 'pointer' }}>上一页</button>
              <span style={{ padding: '8px 16px', alignSelf: 'center' }}>第 {expertsPage} 页，共 {totalPages} 页</span>
              <button onClick={() => expertsPage < totalPages && setExpertsPage(expertsPage + 1)} disabled={expertsPage >= totalPages} style={{ padding: '8px 16px', border: '1px solid #ddd', background: expertsPage >= totalPages ? '#f5f5f5' : 'white', borderRadius: '4px', cursor: expertsPage >= totalPages ? 'not-allowed' : 'pointer' }}>下一页</button>
            </div>
          )}
        </>
      )}
      {subTab === 'applications' && renderApplications()}
      {subTab === 'profile_updates' && renderProfileUpdates()}

      {/* 审核模态框 */}
      <Modal
        title={reviewAction === 'approve' ? '批准确认' : '拒绝确认'}
        open={showReviewModal}
        onCancel={() => setShowReviewModal(false)}
        onOk={handleReview}
        okText={reviewAction === 'approve' ? '批准' : '拒绝'}
        cancelText="取消"
      >
        <div style={{ padding: '20px 0' }}>
          <p>确定要{reviewAction === 'approve' ? '批准' : '拒绝'}这个{reviewType === 'application' ? '申请' : '资料修改请求'}吗？</p>
          <div style={{ marginTop: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>备注（可选）</label>
            <textarea
              value={reviewComment}
              onChange={(e) => setReviewComment(e.target.value)}
              placeholder="请输入备注..."
              rows={3}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical' }}
            />
          </div>
        </div>
      </Modal>
    </div>
  );
};

export default ExpertManagement;
