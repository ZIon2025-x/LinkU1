import React, { useState, useCallback } from 'react';
import { message, Modal } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, Column } from '../../../components/admin';
import {
  getTaskExperts,
  getTaskExpertApplications,
  reviewTaskExpertApplication,
  getProfileUpdateRequests,
  reviewProfileUpdateRequest
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

type SubTab = 'list' | 'applications' | 'profile_updates';

interface ReviewForm {
  action: 'approve' | 'reject';
  reviewType: 'application' | 'profile';
  reviewComment: string;
  item: any;
}

const initialReviewForm: ReviewForm = {
  action: 'approve',
  reviewType: 'application',
  reviewComment: '',
  item: null,
};

/**
 * 专家管理组件
 * 管理任务达人列表、申请审核和资料修改审核
 */
const ExpertManagement: React.FC = () => {
  const [subTab, setSubTab] = useState<SubTab>('list');

  // 达人列表
  const fetchExperts = useCallback(async ({ page, pageSize }: { page: number; pageSize: number }) => {
    const response = await getTaskExperts({ page, size: pageSize });
    return {
      data: response.items || [],
      total: response.total || 0,
    };
  }, []);

  const handleExpertsError = useCallback((error: any) => {
    message.error(getErrorMessage(error));
  }, []);

  const expertsTable = useAdminTable<any>({
    fetchData: fetchExperts,
    initialPageSize: 20,
    onError: handleExpertsError,
  });

  // 申请列表（固定获取 pending 状态，无分页）
  const fetchApplications = useCallback(async () => {
    const response = await getTaskExpertApplications({ status: 'pending' });
    return {
      data: response.items || [],
      total: response.total || (response.items || []).length,
    };
  }, []);

  const handleApplicationsError = useCallback((error: any) => {
    message.error(getErrorMessage(error));
  }, []);

  const applicationsTable = useAdminTable<any>({
    fetchData: fetchApplications,
    initialPageSize: 100,
    onError: handleApplicationsError,
  });

  // 资料修改请求列表（固定获取 pending 状态，无分页）
  const fetchProfileUpdates = useCallback(async () => {
    const response = await getProfileUpdateRequests({ status: 'pending' });
    return {
      data: response.items || [],
      total: response.total || (response.items || []).length,
    };
  }, []);

  const handleProfileUpdatesError = useCallback((error: any) => {
    message.error(getErrorMessage(error));
  }, []);

  const profileUpdatesTable = useAdminTable<any>({
    fetchData: fetchProfileUpdates,
    initialPageSize: 100,
    onError: handleProfileUpdatesError,
  });

  // 审核模态框
  const reviewModal = useModalForm<ReviewForm>({
    initialValues: initialReviewForm,
    onSubmit: async (values) => {
      if (!values.item) return;
      if (values.reviewType === 'application') {
        await reviewTaskExpertApplication(values.item.id, {
          action: values.action,
          review_comment: values.reviewComment || undefined
        });
      } else {
        await reviewProfileUpdateRequest(values.item.id, {
          action: values.action,
          review_comment: values.reviewComment || undefined
        });
      }
      message.success(values.action === 'approve' ? '已批准' : '已拒绝');
      if (values.reviewType === 'application') {
        applicationsTable.refresh();
      } else {
        profileUpdatesTable.refresh();
      }
    },
    onError: (error) => {
      message.error(getErrorMessage(error));
    },
  });

  const openReview = (item: any, type: 'application' | 'profile', action: 'approve' | 'reject') => {
    reviewModal.open({ action, reviewType: type, reviewComment: '', item });
  };

  // 达人列表列定义
  const expertColumns: Column<any>[] = [
    {
      key: 'id',
      title: 'ID',
      dataIndex: 'id',
      width: 80,
    },
    {
      key: 'user',
      title: '用户',
      width: 150,
      render: (_, record) => record.user_name || record.user_id,
    },
    {
      key: 'expertise',
      title: '擅长领域',
      width: 200,
      render: (_, record) => record.expertise?.join(', ') || '-',
    },
    {
      key: 'city',
      title: '城市',
      dataIndex: 'city',
      width: 100,
      render: (value) => value || '-',
    },
    {
      key: 'rating',
      title: '评分',
      width: 80,
      render: (_, record) => record.rating?.toFixed(1) || '-',
    },
    {
      key: 'status',
      title: '状态',
      width: 100,
      render: (_, record) => (
        <span style={{
          padding: '4px 8px',
          borderRadius: '4px',
          background: record.is_active ? '#d4edda' : '#f8d7da',
          color: record.is_active ? '#155724' : '#721c24',
          fontSize: '12px'
        }}>
          {record.is_active ? '活跃' : '停用'}
        </span>
      ),
    },
  ];

  // 申请列表列定义
  const applicationColumns: Column<any>[] = [
    {
      key: 'id',
      title: 'ID',
      dataIndex: 'id',
      width: 80,
    },
    {
      key: 'user',
      title: '申请人',
      width: 150,
      render: (_, record) => record.user_name || record.user_id,
    },
    {
      key: 'expertise',
      title: '擅长领域',
      width: 200,
      render: (_, record) => record.expertise?.join(', ') || '-',
    },
    {
      key: 'bio',
      title: '自我介绍',
      width: 200,
      render: (_, record) => (
        <span style={{ maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block' }}>
          {record.bio || '-'}
        </span>
      ),
    },
    {
      key: 'created_at',
      title: '申请时间',
      width: 160,
      render: (_, record) => new Date(record.created_at).toLocaleString('zh-CN'),
    },
    {
      key: 'actions',
      title: '操作',
      width: 140,
      align: 'center',
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
          <button
            onClick={() => openReview(record, 'application', 'approve')}
            style={{ padding: '4px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            批准
          </button>
          <button
            onClick={() => openReview(record, 'application', 'reject')}
            style={{ padding: '4px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            拒绝
          </button>
        </div>
      ),
    },
  ];

  // 资料修改请求列定义
  const profileUpdateColumns: Column<any>[] = [
    {
      key: 'id',
      title: 'ID',
      dataIndex: 'id',
      width: 80,
    },
    {
      key: 'expert',
      title: '达人',
      width: 150,
      render: (_, record) => record.expert_name || record.expert_id,
    },
    {
      key: 'changes',
      title: '修改内容',
      width: 300,
      render: (_, record) => (
        <span style={{ maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block' }}>
          {JSON.stringify(record.changes || {})}
        </span>
      ),
    },
    {
      key: 'created_at',
      title: '申请时间',
      width: 160,
      render: (_, record) => new Date(record.created_at).toLocaleString('zh-CN'),
    },
    {
      key: 'actions',
      title: '操作',
      width: 140,
      align: 'center',
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '8px', justifyContent: 'center' }}>
          <button
            onClick={() => openReview(record, 'profile', 'approve')}
            style={{ padding: '4px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            批准
          </button>
          <button
            onClick={() => openReview(record, 'profile', 'reject')}
            style={{ padding: '4px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            拒绝
          </button>
        </div>
      ),
    },
  ];

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

      {/* 达人列表 */}
      {subTab === 'list' && (
        <>
          <AdminTable
            columns={expertColumns}
            data={expertsTable.data}
            loading={expertsTable.loading}
            rowKey="id"
            emptyText="暂无达人数据"
          />
          <AdminPagination
            currentPage={expertsTable.currentPage}
            totalPages={expertsTable.totalPages}
            total={expertsTable.total}
            pageSize={expertsTable.pageSize}
            onPageChange={expertsTable.setCurrentPage}
            onPageSizeChange={expertsTable.setPageSize}
          />
        </>
      )}

      {/* 申请列表 */}
      {subTab === 'applications' && (
        <AdminTable
          columns={applicationColumns}
          data={applicationsTable.data}
          loading={applicationsTable.loading}
          rowKey="id"
          emptyText="暂无待审核申请"
        />
      )}

      {/* 资料修改请求列表 */}
      {subTab === 'profile_updates' && (
        <AdminTable
          columns={profileUpdateColumns}
          data={profileUpdatesTable.data}
          loading={profileUpdatesTable.loading}
          rowKey="id"
          emptyText="暂无待审核资料修改请求"
        />
      )}

      {/* 审核模态框 */}
      <Modal
        title={reviewModal.formData.action === 'approve' ? '批准确认' : '拒绝确认'}
        open={reviewModal.isOpen}
        onCancel={reviewModal.close}
        onOk={reviewModal.handleSubmit}
        confirmLoading={reviewModal.loading}
        okText={reviewModal.formData.action === 'approve' ? '批准' : '拒绝'}
        cancelText="取消"
      >
        <div style={{ padding: '20px 0' }}>
          <p>确定要{reviewModal.formData.action === 'approve' ? '批准' : '拒绝'}这个{reviewModal.formData.reviewType === 'application' ? '申请' : '资料修改请求'}吗？</p>
          <div style={{ marginTop: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>备注（可选）</label>
            <textarea
              value={reviewModal.formData.reviewComment}
              onChange={(e) => reviewModal.updateField('reviewComment', e.target.value)}
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
