import React, { useState, useEffect, useCallback } from 'react';
import { message } from 'antd';
import { AdminTable, AdminPagination, AdminModal, Column } from '../../../components/admin';
import {
  getNewbieTasksConfig,
  updateNewbieTaskConfig,
  getStageBonusConfig,
  updateStageBonusConfig,
} from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

interface NewbieTask {
  task_key: string;
  stage: number;
  title_zh: string;
  title_en: string;
  reward_amount: number;
  is_active: boolean;
}

interface StageBonus {
  stage: number;
  title_zh: string;
  title_en: string;
  reward_type: string;
  reward_amount: number;
  is_active: boolean;
}

interface EditForm {
  task_key: string;
  title_zh: string;
  title_en: string;
  reward_amount: number;
  is_active: boolean;
}

interface StageBonusForm {
  stage: number;
  reward_amount: number;
  is_active: boolean;
}

const NewbieTaskConfig: React.FC = () => {
  const [tasks, setTasks] = useState<NewbieTask[]>([]);
  const [stageBonuses, setStageBonuses] = useState<StageBonus[]>([]);
  const [loading, setLoading] = useState(false);
  const [editModalOpen, setEditModalOpen] = useState(false);
  const [editForm, setEditForm] = useState<EditForm>({ task_key: '', title_zh: '', title_en: '', reward_amount: 0, is_active: true });
  const [editLoading, setEditLoading] = useState(false);
  const [stageBonusModalOpen, setStageBonusModalOpen] = useState(false);
  const [stageBonusForm, setStageBonusForm] = useState<StageBonusForm>({ stage: 1, reward_amount: 0, is_active: true });
  const [stageBonusEditLoading, setStageBonusEditLoading] = useState(false);

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [tasksRes, bonusRes] = await Promise.all([
        getNewbieTasksConfig(),
        getStageBonusConfig(),
      ]);
      setTasks(tasksRes.items || tasksRes || []);
      setStageBonuses(bonusRes.items || bonusRes || []);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  const handleEdit = (task: NewbieTask) => {
    setEditForm({
      task_key: task.task_key,
      title_zh: task.title_zh,
      title_en: task.title_en,
      reward_amount: task.reward_amount,
      is_active: task.is_active,
    });
    setEditModalOpen(true);
  };

  const handleEditSubmit = async () => {
    setEditLoading(true);
    try {
      await updateNewbieTaskConfig(editForm.task_key, {
        title_zh: editForm.title_zh,
        title_en: editForm.title_en,
        reward_amount: editForm.reward_amount,
        is_active: editForm.is_active,
      });
      message.success('Newbie task config updated');
      setEditModalOpen(false);
      fetchData();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setEditLoading(false);
    }
  };

  const handleEditStageBonus = (bonus: StageBonus) => {
    setStageBonusForm({
      stage: bonus.stage,
      reward_amount: bonus.reward_amount,
      is_active: bonus.is_active,
    });
    setStageBonusModalOpen(true);
  };

  const handleStageBonusSubmit = async () => {
    setStageBonusEditLoading(true);
    try {
      await updateStageBonusConfig(stageBonusForm.stage, {
        reward_amount: stageBonusForm.reward_amount,
        is_active: stageBonusForm.is_active,
      });
      message.success('Stage bonus config updated');
      setStageBonusModalOpen(false);
      fetchData();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setStageBonusEditLoading(false);
    }
  };

  const taskColumns: Column<NewbieTask>[] = [
    { key: 'task_key', title: 'Task Key', dataIndex: 'task_key', width: 180 },
    { key: 'stage', title: 'Stage', dataIndex: 'stage', width: 80, align: 'center' },
    { key: 'title_zh', title: 'Title (ZH)', dataIndex: 'title_zh', width: 200 },
    { key: 'title_en', title: 'Title (EN)', dataIndex: 'title_en', width: 200 },
    { key: 'reward_amount', title: 'Reward', dataIndex: 'reward_amount', width: 100, align: 'right' },
    {
      key: 'is_active', title: 'Active', dataIndex: 'is_active', width: 80, align: 'center',
      render: (val: boolean) => (
        <span style={{ color: val ? '#28a745' : '#dc3545', fontWeight: 500 }}>
          {val ? 'Yes' : 'No'}
        </span>
      ),
    },
    {
      key: 'actions', title: 'Actions', width: 100, align: 'center',
      render: (_: any, record: NewbieTask) => (
        <button
          onClick={() => handleEdit(record)}
          style={{ padding: '4px 12px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
        >
          Edit
        </button>
      ),
    },
  ];

  const bonusColumns: Column<StageBonus>[] = [
    { key: 'stage', title: 'Stage', dataIndex: 'stage', width: 100, align: 'center' },
    { key: 'reward_amount', title: 'Reward Amount', dataIndex: 'reward_amount', width: 150, align: 'right' },
    {
      key: 'is_active', title: 'Active', dataIndex: 'is_active', width: 80, align: 'center',
      render: (val: boolean) => (
        <span style={{ color: val ? '#28a745' : '#dc3545', fontWeight: 500 }}>
          {val ? 'Yes' : 'No'}
        </span>
      ),
    },
    {
      key: 'actions', title: 'Actions', width: 100, align: 'center',
      render: (_: any, record: StageBonus) => (
        <button
          onClick={() => handleEditStageBonus(record)}
          style={{ padding: '4px 12px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '12px' }}
        >
          Edit
        </button>
      ),
    },
  ];

  const editFooter = (
    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
      <button
        onClick={() => setEditModalOpen(false)}
        style={{ padding: '8px 16px', border: '1px solid #d9d9d9', borderRadius: '4px', background: 'white', cursor: 'pointer' }}
      >
        Cancel
      </button>
      <button
        onClick={handleEditSubmit}
        disabled={editLoading}
        style={{ padding: '8px 16px', border: 'none', borderRadius: '4px', background: '#007bff', color: 'white', cursor: editLoading ? 'not-allowed' : 'pointer', opacity: editLoading ? 0.7 : 1 }}
      >
        {editLoading ? 'Saving...' : 'Save'}
      </button>
    </div>
  );

  const stageBonusFooter = (
    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
      <button
        onClick={() => setStageBonusModalOpen(false)}
        style={{ padding: '8px 16px', border: '1px solid #d9d9d9', borderRadius: '4px', background: 'white', cursor: 'pointer' }}
      >
        Cancel
      </button>
      <button
        onClick={handleStageBonusSubmit}
        disabled={stageBonusEditLoading}
        style={{ padding: '8px 16px', border: 'none', borderRadius: '4px', background: '#007bff', color: 'white', cursor: stageBonusEditLoading ? 'not-allowed' : 'pointer', opacity: stageBonusEditLoading ? 0.7 : 1 }}
      >
        {stageBonusEditLoading ? 'Saving...' : 'Save'}
      </button>
    </div>
  );

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
        <h2 style={{ margin: 0 }}>Newbie Task Configuration</h2>
        <button
          onClick={fetchData}
          style={{ padding: '8px 16px', border: '1px solid #007bff', background: 'white', color: '#007bff', borderRadius: '4px', cursor: 'pointer', fontSize: '14px' }}
        >
          Refresh
        </button>
      </div>

      {/* Newbie Tasks Table */}
      <AdminTable<NewbieTask>
        columns={taskColumns}
        data={tasks}
        loading={loading}
        rowKey="task_key"
      />

      {/* Stage Bonus Section */}
      <div style={{ marginTop: '40px' }}>
        <h3 style={{ marginBottom: '16px' }}>Stage Completion Bonus</h3>
        <AdminTable<StageBonus>
          columns={bonusColumns}
          data={stageBonuses}
          loading={loading}
          rowKey="stage"
        />
      </div>

      {/* Edit Task Modal */}
      <AdminModal
        isOpen={editModalOpen}
        onClose={() => setEditModalOpen(false)}
        title={`Edit Task: ${editForm.task_key}`}
        footer={editFooter}
        width="500px"
      >
        <div style={{ padding: '20px 0' }}>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Title (ZH)</label>
            <input
              type="text"
              value={editForm.title_zh}
              onChange={(e) => setEditForm(f => ({ ...f, title_zh: e.target.value }))}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Title (EN)</label>
            <input
              type="text"
              value={editForm.title_en}
              onChange={(e) => setEditForm(f => ({ ...f, title_en: e.target.value }))}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Reward Amount</label>
            <input
              type="number"
              value={editForm.reward_amount}
              onChange={(e) => setEditForm(f => ({ ...f, reward_amount: parseInt(e.target.value) || 0 }))}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={editForm.is_active}
                onChange={(e) => setEditForm(f => ({ ...f, is_active: e.target.checked }))}
              />
              <span>Active</span>
            </label>
          </div>
        </div>
      </AdminModal>

      {/* Edit Stage Bonus Modal */}
      <AdminModal
        isOpen={stageBonusModalOpen}
        onClose={() => setStageBonusModalOpen(false)}
        title={`Edit Stage ${stageBonusForm.stage} Bonus`}
        footer={stageBonusFooter}
        width="400px"
      >
        <div style={{ padding: '20px 0' }}>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>Bonus Amount</label>
            <input
              type="number"
              value={stageBonusForm.reward_amount}
              onChange={(e) => setStageBonusForm(f => ({ ...f, reward_amount: parseInt(e.target.value) || 0 }))}
              style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
            />
          </div>
          <div style={{ marginBottom: '15px' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={stageBonusForm.is_active}
                onChange={(e) => setStageBonusForm(f => ({ ...f, is_active: e.target.checked }))}
              />
              <span>Active</span>
            </label>
          </div>
        </div>
      </AdminModal>
    </div>
  );
};

export default NewbieTaskConfig;
