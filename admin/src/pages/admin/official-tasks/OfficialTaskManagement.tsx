import React, { useState, useCallback } from 'react';
import { message } from 'antd';
import { useAdminTable, useModalForm } from '../../../hooks';
import { AdminTable, AdminPagination, AdminModal, Column } from '../../../components/admin';
import {
  getOfficialTasks,
  createOfficialTask,
  updateOfficialTask,
  deleteOfficialTask,
  getOfficialTaskStats,
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface OfficialTask {
  id: number;
  title_zh: string;
  title_en: string;
  description_zh?: string;
  description_en?: string;
  topic_tag?: string;
  task_type: string;
  reward_type: string;
  reward_amount: number;
  max_per_user?: number;
  valid_from?: string;
  valid_until?: string;
  is_active: boolean;
  created_at?: string;
}

interface TaskForm {
  id?: number;
  title_zh: string;
  title_en: string;
  description_zh: string;
  description_en: string;
  topic_tag: string;
  task_type: string;
  reward_type: string;
  reward_amount: number;
  max_per_user: number | '';
  valid_from: string;
  valid_until: string;
  is_active: boolean;
}

const initialForm: TaskForm = {
  title_zh: '',
  title_en: '',
  description_zh: '',
  description_en: '',
  topic_tag: '',
  task_type: 'one_time',
  reward_type: 'points',
  reward_amount: 0,
  max_per_user: '',
  valid_from: '',
  valid_until: '',
  is_active: true,
};

interface TaskStats {
  total_completions: number;
  unique_users: number;
  total_rewards_given: number;
}

const OfficialTaskManagement: React.FC = () => {
  const [statsModal, setStatsModal] = useState<{ open: boolean; taskId?: number; stats?: TaskStats; loading: boolean }>({
    open: false,
    loading: false,
  });

  const fetchTasks = useCallback(async ({ page, pageSize }: { page: number; pageSize: number }) => {
    const response = await getOfficialTasks({ offset: (page - 1) * pageSize, limit: pageSize });
    return {
      data: response.items || response.data || [],
      total: response.total || 0,
    };
  }, []);

  const table = useAdminTable<OfficialTask>({
    fetchData: fetchTasks,
    initialPageSize: 20,
    onError: (error) => message.error(getErrorMessage(error)),
  });

  const modal = useModalForm<TaskForm>({
    initialValues: initialForm,
    onSubmit: async (values, isEdit) => {
      if (!values.title_zh || !values.title_en) {
        message.warning('Please fill in both Chinese and English titles');
        throw new Error('validation');
      }

      const payload: Record<string, any> = {
        title_zh: values.title_zh,
        title_en: values.title_en,
        description_zh: values.description_zh || undefined,
        description_en: values.description_en || undefined,
        topic_tag: values.topic_tag || undefined,
        task_type: values.task_type,
        reward_type: values.reward_type,
        reward_amount: values.reward_amount,
        max_per_user: values.max_per_user !== '' ? Number(values.max_per_user) : undefined,
        valid_from: values.valid_from || undefined,
        valid_until: values.valid_until || undefined,
        is_active: values.is_active,
      };

      if (isEdit && values.id) {
        await updateOfficialTask(values.id, payload);
        message.success('Official task updated');
      } else {
        await createOfficialTask(payload as any);
        message.success('Official task created');
      }
      table.refresh();
    },
    onError: (error: any) => {
      if (error?.message !== 'validation') {
        message.error(getErrorMessage(error));
      }
    },
  });

  const handleEdit = (task: OfficialTask) => {
    modal.open({
      id: task.id,
      title_zh: task.title_zh,
      title_en: task.title_en,
      description_zh: task.description_zh || '',
      description_en: task.description_en || '',
      topic_tag: task.topic_tag || '',
      task_type: task.task_type,
      reward_type: task.reward_type,
      reward_amount: task.reward_amount,
      max_per_user: task.max_per_user ?? '',
      valid_from: task.valid_from || '',
      valid_until: task.valid_until || '',
      is_active: task.is_active,
    });
  };

  const handleDelete = (id: number) => {
    if (!window.confirm('Are you sure you want to deactivate this task?')) return;
    deleteOfficialTask(id)
      .then(() => {
        message.success('Task deactivated');
        table.refresh();
      })
      .catch((error: any) => message.error(getErrorMessage(error)));
  };

  const handleViewStats = async (id: number) => {
    setStatsModal({ open: true, taskId: id, loading: true });
    try {
      const stats = await getOfficialTaskStats(id);
      setStatsModal({ open: true, taskId: id, stats, loading: false });
    } catch (error: any) {
      message.error(getErrorMessage(error));
      setStatsModal({ open: false, loading: false });
    }
  };

  const columns: Column<OfficialTask>[] = [
    { key: 'id', title: 'ID', dataIndex: 'id', width: 60 },
    { key: 'title_zh', title: 'Title (ZH)', dataIndex: 'title_zh', width: 200 },
    { key: 'title_en', title: 'Title (EN)', dataIndex: 'title_en', width: 200 },
    { key: 'task_type', title: 'Type', dataIndex: 'task_type', width: 100 },
    { key: 'reward_type', title: 'Reward Type', dataIndex: 'reward_type', width: 100 },
    { key: 'reward_amount', title: 'Reward', dataIndex: 'reward_amount', width: 80, align: 'right' },
    {
      key: 'is_active', title: 'Active', dataIndex: 'is_active', width: 70, align: 'center',
      render: (val: boolean) => (
        <span style={{ color: val ? '#28a745' : '#dc3545', fontWeight: 500 }}>
          {val ? 'Yes' : 'No'}
        </span>
      ),
    },
    {
      key: 'valid_until', title: 'Valid Until', dataIndex: 'valid_until', width: 120,
      render: (val: string) => val ? new Date(val).toLocaleDateString() : '-',
    },
    {
      key: 'actions', title: 'Actions', width: 200, align: 'center',
      render: (_: any, record: OfficialTask) => (
        <div style={{ display: 'flex', gap: '6px', justifyContent: 'center' }}>
          <button
            onClick={() => handleEdit(record)}
            style={{ padding: '4px 10px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            Edit
          </button>
          <button
            onClick={() => handleViewStats(record.id)}
            style={{ padding: '4px 10px', border: '1px solid #17a2b8', background: 'white', color: '#17a2b8', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            Stats
          </button>
          <button
            onClick={() => handleDelete(record.id)}
            style={{ padding: '4px 10px', border: '1px solid #dc3545', background: 'white', color: '#dc3545', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
          >
            Delete
          </button>
        </div>
      ),
    },
  ];

  const modalFooter = (
    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
      <button
        onClick={modal.close}
        style={{ padding: '8px 16px', border: '1px solid #d9d9d9', borderRadius: '4px', background: 'white', cursor: 'pointer' }}
      >
        Cancel
      </button>
      <button
        onClick={modal.handleSubmit}
        disabled={modal.loading}
        style={{ padding: '8px 16px', border: 'none', borderRadius: '4px', background: '#007bff', color: 'white', cursor: modal.loading ? 'not-allowed' : 'pointer', opacity: modal.loading ? 0.7 : 1 }}
      >
        {modal.loading ? 'Submitting...' : modal.isEdit ? 'Update' : 'Create'}
      </button>
    </div>
  );

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>Official Task Management</h2>
        <button
          onClick={() => modal.open()}
          style={{ padding: '10px 20px', border: 'none', background: '#28a745', color: 'white', borderRadius: '4px', cursor: 'pointer', fontSize: '14px', fontWeight: '500' }}
        >
          Create Task
        </button>
      </div>

      <AdminTable<OfficialTask>
        columns={columns}
        data={table.data}
        loading={table.loading}
        rowKey="id"
      />

      <AdminPagination
        currentPage={table.currentPage}
        totalPages={table.totalPages}
        total={table.total}
        pageSize={table.pageSize}
        onPageChange={table.setCurrentPage}
        onPageSizeChange={table.setPageSize}
      />

      {/* Create/Edit Modal */}
      <AdminModal
        isOpen={modal.isOpen}
        onClose={modal.close}
        title={modal.isEdit ? 'Edit Official Task' : 'Create Official Task'}
        footer={modalFooter}
        width="700px"
      >
        <div style={{ padding: '20px 0', maxHeight: '60vh', overflowY: 'auto' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px' }}>
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                Title (ZH) <span style={{ color: 'red' }}>*</span>
              </label>
              <input
                type="text"
                value={modal.formData.title_zh}
                onChange={(e) => modal.updateField('title_zh', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
              />
            </div>
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>
                Title (EN) <span style={{ color: 'red' }}>*</span>
              </label>
              <input
                type="text"
                value={modal.formData.title_en}
                onChange={(e) => modal.updateField('title_en', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
              />
            </div>
          </div>
          <div style={{ marginTop: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Description (ZH)</label>
            <textarea
              value={modal.formData.description_zh}
              onChange={(e) => modal.updateField('description_zh', e.target.value)}
              rows={3}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical' }}
            />
          </div>
          <div style={{ marginTop: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Description (EN)</label>
            <textarea
              value={modal.formData.description_en}
              onChange={(e) => modal.updateField('description_en', e.target.value)}
              rows={3}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', resize: 'vertical' }}
            />
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px', marginTop: '15px' }}>
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Topic Tag</label>
              <input
                type="text"
                value={modal.formData.topic_tag}
                onChange={(e) => modal.updateField('topic_tag', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
              />
            </div>
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Task Type</label>
              <select
                value={modal.formData.task_type}
                onChange={(e) => modal.updateField('task_type', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
              >
                <option value="one_time">One Time</option>
                <option value="daily">Daily</option>
                <option value="weekly">Weekly</option>
                <option value="recurring">Recurring</option>
              </select>
            </div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '15px', marginTop: '15px' }}>
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Reward Type</label>
              <select
                value={modal.formData.reward_type}
                onChange={(e) => modal.updateField('reward_type', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
              >
                <option value="points">Points</option>
                <option value="coupon">Coupon</option>
                <option value="badge">Badge</option>
              </select>
            </div>
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Reward Amount</label>
              <input
                type="number"
                value={modal.formData.reward_amount}
                onChange={(e) => modal.updateField('reward_amount', parseInt(e.target.value) || 0)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
              />
            </div>
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Max Per User</label>
              <input
                type="number"
                value={modal.formData.max_per_user}
                onChange={(e) => modal.updateField('max_per_user', e.target.value ? parseInt(e.target.value) : '' as any)}
                placeholder="Unlimited"
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
              />
            </div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px', marginTop: '15px' }}>
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Valid From</label>
              <input
                type="datetime-local"
                value={modal.formData.valid_from}
                onChange={(e) => modal.updateField('valid_from', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
              />
            </div>
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Valid Until</label>
              <input
                type="datetime-local"
                value={modal.formData.valid_until}
                onChange={(e) => modal.updateField('valid_until', e.target.value)}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
              />
            </div>
          </div>
          <div style={{ marginTop: '15px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={modal.formData.is_active}
                onChange={(e) => modal.updateField('is_active', e.target.checked)}
              />
              <span>Active</span>
            </label>
          </div>
        </div>
      </AdminModal>

      {/* Stats Modal */}
      <AdminModal
        isOpen={statsModal.open}
        onClose={() => setStatsModal({ open: false, loading: false })}
        title={`Task #${statsModal.taskId} Statistics`}
        width="400px"
      >
        <div style={{ padding: '20px 0' }}>
          {statsModal.loading ? (
            <div style={{ textAlign: 'center', padding: '20px' }}>Loading...</div>
          ) : statsModal.stats ? (
            <div style={{ display: 'grid', gap: '16px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '12px', background: '#f8f9fa', borderRadius: '8px' }}>
                <span style={{ fontWeight: 500 }}>Total Completions</span>
                <span style={{ fontSize: '18px', fontWeight: 'bold', color: '#007bff' }}>{statsModal.stats.total_completions}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '12px', background: '#f8f9fa', borderRadius: '8px' }}>
                <span style={{ fontWeight: 500 }}>Unique Users</span>
                <span style={{ fontSize: '18px', fontWeight: 'bold', color: '#28a745' }}>{statsModal.stats.unique_users}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', padding: '12px', background: '#f8f9fa', borderRadius: '8px' }}>
                <span style={{ fontWeight: 500 }}>Total Rewards Given</span>
                <span style={{ fontSize: '18px', fontWeight: 'bold', color: '#ffc107' }}>{statsModal.stats.total_rewards_given}</span>
              </div>
            </div>
          ) : (
            <div style={{ textAlign: 'center', color: '#999' }}>No stats available</div>
          )}
        </div>
      </AdminModal>
    </div>
  );
};

export default OfficialTaskManagement;
