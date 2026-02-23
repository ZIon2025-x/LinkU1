import React, { useState, useCallback } from 'react';
import { message, Modal, Tag } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, StatusBadge, Column } from '../../../components/admin';
import {
  getTaskExperts,
  updateTaskExpert,
  deleteTaskExpert,
  getTaskExpertApplications,
  reviewTaskExpertApplication,
  createExpertFromApplication,
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

interface ExpertEditForm {
  id: string;
  name: string;
  bio: string;
  bio_en: string;
  category: string;
  location: string;
  display_order: number;
  is_active: boolean;
  is_featured: boolean;
  is_verified: boolean;
}

const initialEditForm: ExpertEditForm = {
  id: '',
  name: '',
  bio: '',
  bio_en: '',
  category: '',
  location: '',
  display_order: 0,
  is_active: true,
  is_featured: true,
  is_verified: false,
};

const ExpertManagement: React.FC = () => {
  const [subTab, setSubTab] = useState<SubTab>('list');
  const [detailExpert, setDetailExpert] = useState<any>(null);

  // ==================== 达人列表 ====================
  const fetchExperts = useCallback(async ({ page, pageSize }: { page: number; pageSize: number }) => {
    const response = await getTaskExperts({ page, size: pageSize });
    return {
      data: response.task_experts || [],
      total: response.total || 0,
    };
  }, []);

  const expertsTable = useAdminTable<any>({
    fetchData: fetchExperts,
    initialPageSize: 20,
    onError: (error) => message.error(getErrorMessage(error)),
  });

  // ==================== 申请列表 ====================
  const fetchApplications = useCallback(async () => {
    const response = await getTaskExpertApplications({ status: 'pending' });
    return {
      data: response.items || [],
      total: response.total || (response.items || []).length,
    };
  }, []);

  const applicationsTable = useAdminTable<any>({
    fetchData: fetchApplications,
    initialPageSize: 100,
    onError: (error) => message.error(getErrorMessage(error)),
  });

  // ==================== 资料修改请求列表 ====================
  const fetchProfileUpdates = useCallback(async () => {
    const response = await getProfileUpdateRequests({ status: 'pending' });
    return {
      data: response.items || [],
      total: response.total || (response.items || []).length,
    };
  }, []);

  const profileUpdatesTable = useAdminTable<any>({
    fetchData: fetchProfileUpdates,
    initialPageSize: 100,
    onError: (error) => message.error(getErrorMessage(error)),
  });

  // ==================== 审核模态框 ====================
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
    onError: (error) => message.error(getErrorMessage(error)),
  });

  const openReview = (item: any, type: 'application' | 'profile', action: 'approve' | 'reject') => {
    reviewModal.open({ action, reviewType: type, reviewComment: '', item });
  };

  // ==================== 编辑模态框 ====================
  const editModal = useModalForm<ExpertEditForm>({
    initialValues: initialEditForm,
    onSubmit: async (values) => {
      await updateTaskExpert(values.id, {
        name: values.name,
        bio: values.bio || undefined,
        bio_en: values.bio_en || undefined,
        category: values.category || undefined,
        location: values.location || undefined,
        display_order: values.display_order,
        is_active: values.is_active ? 1 : 0,
        is_featured: values.is_featured ? 1 : 0,
        is_verified: values.is_verified ? 1 : 0,
      });
      message.success('达人信息已更新');
      expertsTable.refresh();
    },
    onError: (error) => message.error(getErrorMessage(error)),
  });

  const handleEdit = (expert: any) => {
    editModal.open({
      id: expert.id,
      name: expert.name || '',
      bio: expert.bio || '',
      bio_en: expert.bio_en || '',
      category: expert.category || '',
      location: expert.location || '',
      display_order: expert.display_order || 0,
      is_active: !!expert.is_active,
      is_featured: !!expert.is_featured,
      is_verified: !!expert.is_verified,
    });
  };

  const handleDelete = (expertId: string, expertName: string) => {
    Modal.confirm({
      title: '确认删除',
      content: `确定要删除达人「${expertName}」吗？此操作不可撤销。`,
      okText: '确定删除',
      cancelText: '取消',
      okButtonProps: { danger: true },
      onOk: async () => {
        try {
          await deleteTaskExpert(expertId);
          message.success('达人已删除');
          expertsTable.refresh();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        }
      }
    });
  };

  const handleCreateFeatured = async (applicationId: number) => {
    try {
      await createExpertFromApplication(applicationId);
      message.success('已创建特色任务达人');
      applicationsTable.refresh();
      expertsTable.refresh();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  // ==================== 达人列表列定义 ====================
  const expertColumns: Column<any>[] = [
    {
      key: 'id',
      title: 'ID',
      width: 100,
      render: (_, record) => (
        <span style={{ fontSize: '12px', fontFamily: 'monospace' }}>
          {record.id?.substring(0, 8)}...
        </span>
      ),
    },
    {
      key: 'name',
      title: '达人名称',
      width: 140,
      render: (_, record) => (
        <button
          onClick={() => setDetailExpert(record)}
          style={{ background: 'none', border: 'none', color: '#007bff', cursor: 'pointer', fontWeight: 500, fontSize: '13px', padding: 0 }}
        >
          {record.name || '-'}
        </button>
      ),
    },
    {
      key: 'expertise_areas',
      title: '擅长领域',
      width: 200,
      render: (_, record) => {
        const areas = record.expertise_areas || [];
        if (!areas.length) return <span style={{ color: '#999' }}>-</span>;
        return (
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
            {areas.slice(0, 3).map((a: string, i: number) => (
              <Tag key={i} color="blue" style={{ margin: 0 }}>{a}</Tag>
            ))}
            {areas.length > 3 && <Tag style={{ margin: 0 }}>+{areas.length - 3}</Tag>}
          </div>
        );
      },
    },
    {
      key: 'location',
      title: '城市',
      width: 90,
      render: (_, record) => record.location || '-',
    },
    {
      key: 'avg_rating',
      title: '评分',
      width: 70,
      render: (_, record) => record.avg_rating ? Number(record.avg_rating).toFixed(1) : '-',
    },
    {
      key: 'completed_tasks',
      title: '完成数',
      width: 80,
      render: (_, record) => record.completed_tasks ?? 0,
    },
    {
      key: 'is_active',
      title: '状态',
      width: 80,
      render: (_, record) => (
        <StatusBadge
          text={record.is_active ? '活跃' : '停用'}
          variant={record.is_active ? 'success' : 'danger'}
        />
      ),
    },
    {
      key: 'is_featured',
      title: '精选',
      width: 70,
      render: (_, record) => (
        <StatusBadge
          text={record.is_featured ? '是' : '否'}
          variant={record.is_featured ? 'info' : 'default'}
        />
      ),
    },
    {
      key: 'display_order',
      title: '排序',
      dataIndex: 'display_order',
      width: 60,
    },
    {
      key: 'actions',
      title: '操作',
      width: 130,
      align: 'center',
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '6px', justifyContent: 'center' }}>
          <button
            onClick={() => handleEdit(record)}
            style={{ padding: '3px 8px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            编辑
          </button>
          <button
            onClick={() => handleDelete(record.id, record.name)}
            style={{ padding: '3px 8px', border: '1px solid #dc3545', background: 'white', color: '#dc3545', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            删除
          </button>
        </div>
      ),
    },
  ];

  // ==================== 申请列表列定义 ====================
  const applicationColumns: Column<any>[] = [
    {
      key: 'id',
      title: 'ID',
      dataIndex: 'id',
      width: 60,
    },
    {
      key: 'user',
      title: '申请人',
      width: 130,
      render: (_, record) => record.user_name || record.user_id?.substring(0, 8),
    },
    {
      key: 'expertise',
      title: '擅长领域',
      width: 200,
      render: (_, record) => {
        const areas = record.expertise || record.expertise_areas || [];
        if (typeof areas === 'string') return areas;
        return Array.isArray(areas) ? areas.join(', ') : '-';
      },
    },
    {
      key: 'application_message',
      title: '申请说明',
      width: 220,
      render: (_, record) => (
        <span style={{ maxWidth: '220px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block' }}>
          {record.application_message || record.bio || '-'}
        </span>
      ),
    },
    {
      key: 'created_at',
      title: '申请时间',
      width: 150,
      render: (_, record) => record.created_at ? new Date(record.created_at).toLocaleString('zh-CN') : '-',
    },
    {
      key: 'actions',
      title: '操作',
      width: 200,
      align: 'center',
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '6px', justifyContent: 'center' }}>
          <button
            onClick={() => openReview(record, 'application', 'approve')}
            style={{ padding: '3px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            批准
          </button>
          <button
            onClick={() => openReview(record, 'application', 'reject')}
            style={{ padding: '3px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            拒绝
          </button>
          {record.status === 'approved' && (
            <button
              onClick={() => handleCreateFeatured(record.id)}
              style={{ padding: '3px 8px', border: 'none', background: '#007bff', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
            >
              创建特色达人
            </button>
          )}
        </div>
      ),
    },
  ];

  // ==================== 资料修改请求列定义 ====================
  const profileUpdateColumns: Column<any>[] = [
    {
      key: 'id',
      title: 'ID',
      dataIndex: 'id',
      width: 60,
    },
    {
      key: 'expert',
      title: '达人',
      width: 130,
      render: (_, record) => record.expert?.expert_name || record.expert_name || record.expert_id?.substring(0, 8) || '-',
    },
    {
      key: 'changes',
      title: '修改内容',
      width: 300,
      render: (_, record) => {
        const parts: string[] = [];
        if (record.new_expert_name) parts.push(`名称: ${record.new_expert_name}`);
        if (record.new_bio) parts.push(`简介: ${record.new_bio.substring(0, 30)}...`);
        if (record.new_avatar) parts.push('头像: 已更新');
        if (!parts.length) return <span style={{ color: '#999' }}>-</span>;
        return (
          <span style={{ maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: 'block' }}>
            {parts.join(' | ')}
          </span>
        );
      },
    },
    {
      key: 'created_at',
      title: '申请时间',
      width: 150,
      render: (_, record) => record.created_at ? new Date(record.created_at).toLocaleString('zh-CN') : '-',
    },
    {
      key: 'actions',
      title: '操作',
      width: 130,
      align: 'center',
      render: (_, record) => (
        <div style={{ display: 'flex', gap: '6px', justifyContent: 'center' }}>
          <button
            onClick={() => openReview(record, 'profile', 'approve')}
            style={{ padding: '3px 8px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            批准
          </button>
          <button
            onClick={() => openReview(record, 'profile', 'reject')}
            style={{ padding: '3px 8px', border: 'none', background: '#dc3545', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
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
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical', boxSizing: 'border-box' }}
            />
          </div>
        </div>
      </Modal>

      {/* 编辑模态框 */}
      <Modal
        title="编辑达人信息"
        open={editModal.isOpen}
        onCancel={editModal.close}
        onOk={editModal.handleSubmit}
        confirmLoading={editModal.loading}
        okText="保存"
        cancelText="取消"
        width={600}
      >
        <div style={{ padding: '20px 0', display: 'flex', flexDirection: 'column', gap: '15px' }}>
          <div>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>达人名称</label>
            <input
              type="text"
              value={editModal.formData.name}
              onChange={(e) => editModal.updateField('name', e.target.value)}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>简介（中文）</label>
            <textarea
              value={editModal.formData.bio}
              onChange={(e) => editModal.updateField('bio', e.target.value)}
              rows={3}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical', boxSizing: 'border-box' }}
            />
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>简介（英文）</label>
            <textarea
              value={editModal.formData.bio_en}
              onChange={(e) => editModal.updateField('bio_en', e.target.value)}
              rows={3}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical', boxSizing: 'border-box' }}
            />
          </div>
          <div style={{ display: 'flex', gap: '15px' }}>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>分类</label>
              <input
                type="text"
                value={editModal.formData.category}
                onChange={(e) => editModal.updateField('category', e.target.value)}
                placeholder="如：学术辅导"
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              />
            </div>
            <div style={{ flex: 1 }}>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>城市</label>
              <input
                type="text"
                value={editModal.formData.location}
                onChange={(e) => editModal.updateField('location', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
              />
            </div>
          </div>
          <div>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>排序（数字越小越靠前）</label>
            <input
              type="number"
              value={editModal.formData.display_order}
              onChange={(e) => editModal.updateField('display_order', parseInt(e.target.value) || 0)}
              style={{ width: '120px', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', boxSizing: 'border-box' }}
            />
          </div>
          <div style={{ display: 'flex', gap: '20px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
              <input type="checkbox" checked={editModal.formData.is_active} onChange={(e) => editModal.updateField('is_active', e.target.checked)} />
              <span>启用</span>
            </label>
            <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
              <input type="checkbox" checked={editModal.formData.is_featured} onChange={(e) => editModal.updateField('is_featured', e.target.checked)} />
              <span>精选</span>
            </label>
            <label style={{ display: 'flex', alignItems: 'center', gap: '6px', cursor: 'pointer' }}>
              <input type="checkbox" checked={editModal.formData.is_verified} onChange={(e) => editModal.updateField('is_verified', e.target.checked)} />
              <span>已认证</span>
            </label>
          </div>
        </div>
      </Modal>

      {/* 详情模态框 */}
      <Modal
        title="达人详情"
        open={!!detailExpert}
        onCancel={() => setDetailExpert(null)}
        footer={null}
        width={650}
      >
        {detailExpert && (
          <div style={{ padding: '10px 0' }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px 24px' }}>
              <div><strong>ID：</strong><span style={{ fontFamily: 'monospace', fontSize: '12px' }}>{detailExpert.id}</span></div>
              <div><strong>名称：</strong>{detailExpert.name || '-'}</div>
              <div><strong>评分：</strong>{detailExpert.avg_rating ? Number(detailExpert.avg_rating).toFixed(1) : '-'}</div>
              <div><strong>完成任务：</strong>{detailExpert.completed_tasks ?? 0}</div>
              <div><strong>总任务：</strong>{detailExpert.total_tasks ?? 0}</div>
              <div><strong>完成率：</strong>{detailExpert.completion_rate ? `${(detailExpert.completion_rate * 100).toFixed(0)}%` : '-'}</div>
              <div><strong>成功率：</strong>{detailExpert.success_rate ? `${(detailExpert.success_rate * 100).toFixed(0)}%` : '-'}</div>
              <div><strong>城市：</strong>{detailExpert.location || '-'}</div>
              <div><strong>分类：</strong>{detailExpert.category || '-'}</div>
              <div><strong>排序：</strong>{detailExpert.display_order}</div>
              <div><strong>响应时间：</strong>{detailExpert.response_time || '-'}</div>
              <div><strong>等级：</strong>{detailExpert.user_level || '-'}</div>
            </div>
            <div style={{ marginTop: '12px' }}>
              <strong>擅长领域：</strong>
              <div style={{ marginTop: '4px', display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
                {(detailExpert.expertise_areas || []).map((a: string, i: number) => (
                  <Tag key={i} color="blue">{a}</Tag>
                ))}
                {!(detailExpert.expertise_areas || []).length && <span style={{ color: '#999' }}>-</span>}
              </div>
            </div>
            <div style={{ marginTop: '12px' }}>
              <strong>技能：</strong>
              <div style={{ marginTop: '4px', display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
                {(detailExpert.featured_skills || []).map((s: string, i: number) => (
                  <Tag key={i} color="green">{s}</Tag>
                ))}
                {!(detailExpert.featured_skills || []).length && <span style={{ color: '#999' }}>-</span>}
              </div>
            </div>
            <div style={{ marginTop: '12px' }}>
              <strong>简介：</strong>
              <p style={{ marginTop: '4px', color: '#555' }}>{detailExpert.bio || '-'}</p>
            </div>
            <div style={{ marginTop: '8px', display: 'flex', gap: '10px' }}>
              <StatusBadge text={detailExpert.is_active ? '活跃' : '停用'} variant={detailExpert.is_active ? 'success' : 'danger'} />
              <StatusBadge text={detailExpert.is_featured ? '精选' : '非精选'} variant={detailExpert.is_featured ? 'info' : 'default'} />
              <StatusBadge text={detailExpert.is_verified ? '已认证' : '未认证'} variant={detailExpert.is_verified ? 'success' : 'default'} />
            </div>
            <div style={{ marginTop: '12px', color: '#999', fontSize: '12px' }}>
              创建时间：{detailExpert.created_at ? new Date(detailExpert.created_at).toLocaleString('zh-CN') : '-'}
              {' | '}
              更新时间：{detailExpert.updated_at ? new Date(detailExpert.updated_at).toLocaleString('zh-CN') : '-'}
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
};

export default ExpertManagement;
