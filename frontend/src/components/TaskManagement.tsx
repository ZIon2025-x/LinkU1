import React, { useState, useEffect } from 'react';
import { 
  getAdminTasks, 
  getAdminTaskDetail, 
  updateAdminTask, 
  deleteAdminTask,
  batchUpdateAdminTasks,
  batchDeleteAdminTasks
} from '../api';
import dayjs from 'dayjs';
import { TimeHandlerV2 } from '../utils/timeUtils';

// 实际的任务类型和城市定义
const TASK_TYPES = [
  "Housekeeping", "Campus Life", "Second-hand & Rental", "Errand Running", 
  "Skill Service", "Social Help", "Transportation", "Pet Care", "Life Convenience", "Other"
];

const CITIES = [
  "Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", "Bristol", 
  "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton", "Liverpool", 
  "Cardiff", "Coventry", "Exeter", "Leicester", "York", "Aberdeen", "Bath", 
  "Dundee", "Reading", "St Andrews", "Belfast", "Brighton", "Durham", "Norwich", 
  "Swansea", "Loughborough", "Lancaster", "Warwick", "Cambridge", "Oxford", "Other"
];

interface Task {
  id: number;
  title: string;
  description: string;
  reward: number;
  location: string;
  task_type: string;
  status: string;
  poster_id: string;
  taker_id?: string;
  created_at: string;
  deadline: string;
  is_paid: number;
  is_confirmed: number;
  task_level: string;
}

interface TaskManagementProps {
  onClose: () => void;
}

const TaskManagement: React.FC<TaskManagementProps> = ({ onClose }) => {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(false);
  const [selectedTasks, setSelectedTasks] = useState<number[]>([]);
  const [showTaskDetail, setShowTaskDetail] = useState(false);
  const [selectedTask, setSelectedTask] = useState<Task | null>(null);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showBatchModal, setShowBatchModal] = useState(false);
  
  // 筛选和搜索状态
  const [filters, setFilters] = useState({
    status: '',
    task_type: '',
    location: '',
    keyword: ''
  });
  
  // 分页状态
  const [pagination, setPagination] = useState({
    skip: 0,
    limit: 20,
    total: 0
  });

  const loadTasks = async () => {
    try {
      setLoading(true);
      const response = await getAdminTasks({
        skip: pagination.skip,
        limit: pagination.limit,
        ...filters
      });
      setTasks(response.tasks || []);
      setPagination(prev => ({ ...prev, total: response.total || 0 }));
    } catch (error) {
      console.error('加载任务列表失败:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadTasks();
  }, [pagination.skip, pagination.limit, filters]);

  const handleTaskSelect = (taskId: number) => {
    setSelectedTasks(prev => 
      prev.includes(taskId) 
        ? prev.filter(id => id !== taskId)
        : [...prev, taskId]
    );
  };

  const handleSelectAll = () => {
    if (selectedTasks.length === tasks.length) {
      setSelectedTasks([]);
    } else {
      setSelectedTasks(tasks.map(task => task.id));
    }
  };

  const handleViewTask = async (taskId: number) => {
    try {
      const response = await getAdminTaskDetail(taskId);
      setSelectedTask(response.task);
      setShowTaskDetail(true);
    } catch (error) {
      console.error('获取任务详情失败:', error);
    }
  };

  const handleEditTask = (task: Task) => {
    setSelectedTask(task);
    setShowEditModal(true);
  };

  const handleDeleteTask = async (taskId: number) => {
    if (window.confirm('确定要删除这个任务吗？')) {
      try {
        await deleteAdminTask(taskId);
        await loadTasks();
        alert('任务删除成功');
      } catch (error) {
        console.error('删除任务失败:', error);
        alert('删除任务失败');
      }
    }
  };

  const handleBatchUpdate = async (updateData: any) => {
    try {
      const response = await batchUpdateAdminTasks(selectedTasks, updateData);
      alert(response.message);
      setSelectedTasks([]);
      setShowBatchModal(false);
      await loadTasks();
    } catch (error) {
      console.error('批量更新失败:', error);
      alert('批量更新失败');
    }
  };

  const handleBatchDelete = async () => {
    if (window.confirm(`确定要删除选中的 ${selectedTasks.length} 个任务吗？`)) {
      try {
        const response = await batchDeleteAdminTasks(selectedTasks);
        alert(response.message);
        setSelectedTasks([]);
        await loadTasks();
      } catch (error) {
        console.error('批量删除失败:', error);
        alert('批量删除失败');
      }
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'open': return '#28a745';
      case 'taken': return '#ffc107';
      case 'in_progress': return '#17a2b8';
      case 'completed': return '#6f42c1';
      case 'cancelled': return '#dc3545';
      default: return '#6c757d';
    }
  };

  const getStatusText = (status: string) => {
    switch (status) {
      case 'open': return '开放';
      case 'taken': return '已接受';
      case 'in_progress': return '进行中';
      case 'completed': return '已完成';
      case 'cancelled': return '已取消';
      default: return status;
    }
  };

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      zIndex: 1000
    }}>
      <div style={{
        backgroundColor: 'white',
        borderRadius: '8px',
        padding: '20px',
        maxWidth: '1200px',
        width: '95%',
        maxHeight: '90vh',
        overflow: 'auto',
        boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
      }}>
        {/* 头部 */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '20px',
          paddingBottom: '10px',
          borderBottom: '1px solid #eee'
        }}>
          <h2 style={{ margin: 0, color: '#333' }}>任务管理</h2>
          <button
            onClick={onClose}
            style={{
              padding: '8px 16px',
              border: 'none',
              background: '#dc3545',
              color: 'white',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            关闭
          </button>
        </div>

        {/* 筛选和搜索 */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '10px',
          marginBottom: '20px',
          padding: '15px',
          backgroundColor: '#f8f9fa',
          borderRadius: '6px'
        }}>
          <select
            value={filters.status}
            onChange={(e) => setFilters(prev => ({ ...prev, status: e.target.value }))}
            style={{ padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
          >
            <option value="">全部状态</option>
            <option value="open">开放</option>
            <option value="taken">已接受</option>
            <option value="in_progress">进行中</option>
            <option value="completed">已完成</option>
            <option value="cancelled">已取消</option>
          </select>
          
          <select
            value={filters.task_type}
            onChange={(e) => setFilters(prev => ({ ...prev, task_type: e.target.value }))}
            style={{ padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
          >
            <option value="">全部类型</option>
            {TASK_TYPES.map(type => (
              <option key={type} value={type}>{type}</option>
            ))}
          </select>
          
          <select
            value={filters.location}
            onChange={(e) => setFilters(prev => ({ ...prev, location: e.target.value }))}
            style={{ padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
          >
            <option value="">全部城市</option>
            {CITIES.map(city => (
              <option key={city} value={city}>{city}</option>
            ))}
          </select>
          
          <input
            type="text"
            placeholder="搜索关键词..."
            value={filters.keyword}
            onChange={(e) => setFilters(prev => ({ ...prev, keyword: e.target.value }))}
            style={{ padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
          />
        </div>

        {/* 批量操作 */}
        {selectedTasks.length > 0 && (
          <div style={{
            display: 'flex',
            gap: '10px',
            marginBottom: '20px',
            padding: '10px',
            backgroundColor: '#e3f2fd',
            borderRadius: '6px'
          }}>
            <span>已选择 {selectedTasks.length} 个任务</span>
            <button
              onClick={() => setShowBatchModal(true)}
              style={{
                padding: '6px 12px',
                border: 'none',
                background: '#2196f3',
                color: 'white',
                borderRadius: '4px',
                cursor: 'pointer'
              }}
            >
              批量更新
            </button>
            <button
              onClick={handleBatchDelete}
              style={{
                padding: '6px 12px',
                border: 'none',
                background: '#f44336',
                color: 'white',
                borderRadius: '4px',
                cursor: 'pointer'
              }}
            >
              批量删除
            </button>
          </div>
        )}

        {/* 任务列表 */}
        <div style={{ overflow: 'auto', maxHeight: '500px' }}>
          {loading ? (
            <div style={{ textAlign: 'center', padding: '20px' }}>加载中...</div>
          ) : tasks.length === 0 ? (
            <div style={{ textAlign: 'center', padding: '20px', color: '#666' }}>
              暂无任务
            </div>
          ) : (
            <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ backgroundColor: '#f8f9fa' }}>
                  <th style={{ padding: '10px', border: '1px solid #ddd', textAlign: 'left' }}>
                    <input
                      type="checkbox"
                      checked={selectedTasks.length === tasks.length && tasks.length > 0}
                      onChange={handleSelectAll}
                    />
                  </th>
                  <th style={{ padding: '10px', border: '1px solid #ddd', textAlign: 'left' }}>ID</th>
                  <th style={{ padding: '10px', border: '1px solid #ddd', textAlign: 'left' }}>标题</th>
                  <th style={{ padding: '10px', border: '1px solid #ddd', textAlign: 'left' }}>类型</th>
                  <th style={{ padding: '10px', border: '1px solid #ddd', textAlign: 'left' }}>状态</th>
                  <th style={{ padding: '10px', border: '1px solid #ddd', textAlign: 'left' }}>奖励</th>
                  <th style={{ padding: '10px', border: '1px solid #ddd', textAlign: 'left' }}>位置</th>
                  <th style={{ padding: '10px', border: '1px solid #ddd', textAlign: 'left' }}>创建时间</th>
                  <th style={{ padding: '10px', border: '1px solid #ddd', textAlign: 'left' }}>操作</th>
                </tr>
              </thead>
              <tbody>
                {tasks.map(task => (
                  <tr key={task.id}>
                    <td style={{ padding: '10px', border: '1px solid #ddd' }}>
                      <input
                        type="checkbox"
                        checked={selectedTasks.includes(task.id)}
                        onChange={() => handleTaskSelect(task.id)}
                      />
                    </td>
                    <td style={{ padding: '10px', border: '1px solid #ddd' }}>{task.id}</td>
                    <td style={{ padding: '10px', border: '1px solid #ddd' }}>
                      <div style={{ maxWidth: '200px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {task.title}
                      </div>
                    </td>
                    <td style={{ padding: '10px', border: '1px solid #ddd' }}>{task.task_type}</td>
                    <td style={{ padding: '10px', border: '1px solid #ddd' }}>
                      <span style={{
                        padding: '4px 8px',
                        borderRadius: '4px',
                        color: 'white',
                        backgroundColor: getStatusColor(task.status),
                        fontSize: '12px'
                      }}>
                        {getStatusText(task.status)}
                      </span>
                    </td>
                    <td style={{ padding: '10px', border: '1px solid #ddd' }}>£{task.reward.toFixed(2)}</td>
                    <td style={{ padding: '10px', border: '1px solid #ddd' }}>{task.location}</td>
                    <td style={{ padding: '10px', border: '1px solid #ddd' }}>
                      {TimeHandlerV2.formatUtcToLocal(task.created_at, 'YYYY-MM-DD HH:mm', 'Europe/London')} (英国时间)
                    </td>
                    <td style={{ padding: '10px', border: '1px solid #ddd' }}>
                      <div style={{ display: 'flex', gap: '5px' }}>
                        <button
                          onClick={() => handleViewTask(task.id)}
                          style={{
                            padding: '4px 8px',
                            border: 'none',
                            background: '#17a2b8',
                            color: 'white',
                            borderRadius: '3px',
                            cursor: 'pointer',
                            fontSize: '12px'
                          }}
                        >
                          查看
                        </button>
                        <button
                          onClick={() => handleEditTask(task)}
                          style={{
                            padding: '4px 8px',
                            border: 'none',
                            background: '#28a745',
                            color: 'white',
                            borderRadius: '3px',
                            cursor: 'pointer',
                            fontSize: '12px'
                          }}
                        >
                          编辑
                        </button>
                        <button
                          onClick={() => handleDeleteTask(task.id)}
                          style={{
                            padding: '4px 8px',
                            border: 'none',
                            background: '#dc3545',
                            color: 'white',
                            borderRadius: '3px',
                            cursor: 'pointer',
                            fontSize: '12px'
                          }}
                        >
                          删除
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>

        {/* 分页 */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginTop: '20px',
          paddingTop: '10px',
          borderTop: '1px solid #eee'
        }}>
          <div>
            显示 {pagination.skip + 1} - {Math.min(pagination.skip + pagination.limit, pagination.total)} 条，
            共 {pagination.total} 条
          </div>
          <div style={{ display: 'flex', gap: '10px' }}>
            <button
              onClick={() => setPagination(prev => ({ ...prev, skip: Math.max(0, prev.skip - prev.limit) }))}
              disabled={pagination.skip === 0}
              style={{
                padding: '6px 12px',
                border: '1px solid #ddd',
                background: pagination.skip === 0 ? '#f8f9fa' : 'white',
                cursor: pagination.skip === 0 ? 'not-allowed' : 'pointer',
                borderRadius: '4px'
              }}
            >
              上一页
            </button>
            <button
              onClick={() => setPagination(prev => ({ ...prev, skip: prev.skip + prev.limit }))}
              disabled={pagination.skip + pagination.limit >= pagination.total}
              style={{
                padding: '6px 12px',
                border: '1px solid #ddd',
                background: pagination.skip + pagination.limit >= pagination.total ? '#f8f9fa' : 'white',
                cursor: pagination.skip + pagination.limit >= pagination.total ? 'not-allowed' : 'pointer',
                borderRadius: '4px'
              }}
            >
              下一页
            </button>
          </div>
        </div>
      </div>

      {/* 任务详情弹窗 */}
      {showTaskDetail && selectedTask && (
        <TaskDetailModal
          task={selectedTask}
          onClose={() => setShowTaskDetail(false)}
        />
      )}

      {/* 任务编辑弹窗 */}
      {showEditModal && selectedTask && (
        <TaskEditModal
          task={selectedTask}
          onClose={() => setShowEditModal(false)}
          onSave={async (updateData) => {
            try {
              await updateAdminTask(selectedTask.id, updateData);
              await loadTasks();
              setShowEditModal(false);
              alert('任务更新成功');
            } catch (error) {
              console.error('更新任务失败:', error);
              alert('更新任务失败');
            }
          }}
        />
      )}

      {/* 批量操作弹窗 */}
      {showBatchModal && (
        <BatchUpdateModal
          onClose={() => setShowBatchModal(false)}
          onSave={handleBatchUpdate}
        />
      )}
    </div>
  );
};

// 任务详情组件
const TaskDetailModal: React.FC<{ task: Task; onClose: () => void }> = ({ task, onClose }) => {
  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      zIndex: 1100
    }}>
      <div style={{
        backgroundColor: 'white',
        borderRadius: '8px',
        padding: '20px',
        maxWidth: '600px',
        width: '90%',
        maxHeight: '80vh',
        overflow: 'auto',
        boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
      }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '20px',
          paddingBottom: '10px',
          borderBottom: '1px solid #eee'
        }}>
          <h3 style={{ margin: 0 }}>任务详情</h3>
          <button
            onClick={onClose}
            style={{
              padding: '6px 12px',
              border: 'none',
              background: '#dc3545',
              color: 'white',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            关闭
          </button>
        </div>
        
        <div style={{ display: 'grid', gap: '15px' }}>
          <div>
            <strong>标题：</strong>
            <div style={{ marginTop: '5px', padding: '10px', backgroundColor: '#f8f9fa', borderRadius: '4px' }}>
              {task.title}
            </div>
          </div>
          
          <div>
            <strong>描述：</strong>
            <div style={{ marginTop: '5px', padding: '10px', backgroundColor: '#f8f9fa', borderRadius: '4px' }}>
              {task.description}
            </div>
          </div>
          
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px' }}>
            <div>
              <strong>任务ID：</strong>
              <div style={{ marginTop: '5px' }}>{task.id}</div>
            </div>
            <div>
              <strong>状态：</strong>
              <div style={{ marginTop: '5px' }}>{task.status}</div>
            </div>
            <div>
              <strong>类型：</strong>
              <div style={{ marginTop: '5px' }}>{task.task_type}</div>
            </div>
            <div>
              <strong>奖励：</strong>
              <div style={{ marginTop: '5px' }}>£{task.reward.toFixed(2)}</div>
            </div>
            <div>
              <strong>位置：</strong>
              <div style={{ marginTop: '5px' }}>{task.location}</div>
            </div>
            <div>
              <strong>发布者ID：</strong>
              <div style={{ marginTop: '5px' }}>{task.poster_id}</div>
            </div>
            <div>
              <strong>接受者ID：</strong>
              <div style={{ marginTop: '5px' }}>{task.taker_id || '未接受'}</div>
            </div>
            <div>
              <strong>创建时间：</strong>
              <div style={{ marginTop: '5px' }}>{TimeHandlerV2.formatUtcToLocal(task.created_at, 'YYYY-MM-DD HH:mm:ss', 'Europe/London')} (英国时间)</div>
            </div>
            <div>
              <strong>截止时间：</strong>
              <div style={{ marginTop: '5px' }}>{TimeHandlerV2.formatUtcToLocal(task.deadline, 'YYYY-MM-DD HH:mm:ss', 'Europe/London')} (英国时间)</div>
            </div>
            <div>
              <strong>是否已支付：</strong>
              <div style={{ marginTop: '5px' }}>{task.is_paid ? '是' : '否'}</div>
            </div>
            <div>
              <strong>是否已确认：</strong>
              <div style={{ marginTop: '5px' }}>{task.is_confirmed ? '是' : '否'}</div>
            </div>
            <div>
              <strong>任务等级：</strong>
              <div style={{ marginTop: '5px' }}>{task.task_level}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

// 任务编辑组件
const TaskEditModal: React.FC<{ 
  task: Task; 
  onClose: () => void; 
  onSave: (data: any) => void; 
}> = ({ task, onClose, onSave }) => {
  const [formData, setFormData] = useState({
    title: task.title,
    description: task.description,
    reward: task.reward,
    location: task.location,
    task_type: task.task_type,
    status: task.status,
    task_level: task.task_level
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSave(formData);
  };

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      zIndex: 1100
    }}>
      <div style={{
        backgroundColor: 'white',
        borderRadius: '8px',
        padding: '20px',
        maxWidth: '500px',
        width: '90%',
        maxHeight: '80vh',
        overflow: 'auto',
        boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
      }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '20px',
          paddingBottom: '10px',
          borderBottom: '1px solid #eee'
        }}>
          <h3 style={{ margin: 0 }}>编辑任务</h3>
          <button
            onClick={onClose}
            style={{
              padding: '6px 12px',
              border: 'none',
              background: '#dc3545',
              color: 'white',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            关闭
          </button>
        </div>
        
        <form onSubmit={handleSubmit}>
          <div style={{ display: 'grid', gap: '15px' }}>
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>标题：</label>
              <input
                type="text"
                value={formData.title}
                onChange={(e) => setFormData(prev => ({ ...prev, title: e.target.value }))}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
                required
              />
            </div>
            
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>描述：</label>
              <textarea
                value={formData.description}
                onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px', minHeight: '100px' }}
                required
              />
            </div>
            
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px' }}>
              <div>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>奖励：</label>
                <input
                  type="number"
                  step="0.01"
                  value={formData.reward}
                  onChange={(e) => setFormData(prev => ({ ...prev, reward: parseFloat(e.target.value) }))}
                  style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
                  required
                />
              </div>
              
              <div>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>城市：</label>
                <select
                  value={formData.location}
                  onChange={(e) => setFormData(prev => ({ ...prev, location: e.target.value }))}
                  style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
                  required
                >
                  {CITIES.map(city => (
                    <option key={city} value={city}>{city}</option>
                  ))}
                </select>
              </div>
              
              <div>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>类型：</label>
                <select
                  value={formData.task_type}
                  onChange={(e) => setFormData(prev => ({ ...prev, task_type: e.target.value }))}
                  style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
                >
                  {TASK_TYPES.map(type => (
                    <option key={type} value={type}>{type}</option>
                  ))}
                </select>
              </div>
              
              <div>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>状态：</label>
                <select
                  value={formData.status}
                  onChange={(e) => setFormData(prev => ({ ...prev, status: e.target.value }))}
                  style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
                >
                  <option value="open">开放</option>
                  <option value="taken">已接受</option>
                  <option value="in_progress">进行中</option>
                  <option value="completed">已完成</option>
                  <option value="cancelled">已取消</option>
                </select>
              </div>
              
              <div>
                <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>等级：</label>
                <select
                  value={formData.task_level}
                  onChange={(e) => setFormData(prev => ({ ...prev, task_level: e.target.value }))}
                  style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
                >
                  <option value="low">低</option>
                  <option value="medium">中</option>
                  <option value="high">高</option>
                </select>
              </div>
            </div>
          </div>
          
          <div style={{
            display: 'flex',
            justifyContent: 'flex-end',
            gap: '10px',
            marginTop: '20px',
            paddingTop: '15px',
            borderTop: '1px solid #eee'
          }}>
            <button
              type="button"
              onClick={onClose}
              style={{
                padding: '8px 16px',
                border: '1px solid #ddd',
                background: 'white',
                borderRadius: '4px',
                cursor: 'pointer'
              }}
            >
              取消
            </button>
            <button
              type="submit"
              style={{
                padding: '8px 16px',
                border: 'none',
                background: '#28a745',
                color: 'white',
                borderRadius: '4px',
                cursor: 'pointer'
              }}
            >
              保存
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

// 批量更新组件
const BatchUpdateModal: React.FC<{ 
  onClose: () => void; 
  onSave: (data: any) => void; 
}> = ({ onClose, onSave }) => {
  const [formData, setFormData] = useState({
    status: '',
    task_level: ''
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const updateData = Object.fromEntries(
      Object.entries(formData).filter(([_, value]) => value !== '')
    );
    if (Object.keys(updateData).length === 0) {
      alert('请至少选择一个要更新的字段');
      return;
    }
    onSave(updateData);
  };

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      zIndex: 1100
    }}>
      <div style={{
        backgroundColor: 'white',
        borderRadius: '8px',
        padding: '20px',
        maxWidth: '400px',
        width: '90%',
        boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
      }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '20px',
          paddingBottom: '10px',
          borderBottom: '1px solid #eee'
        }}>
          <h3 style={{ margin: 0 }}>批量更新</h3>
          <button
            onClick={onClose}
            style={{
              padding: '6px 12px',
              border: 'none',
              background: '#dc3545',
              color: 'white',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            关闭
          </button>
        </div>
        
        <form onSubmit={handleSubmit}>
          <div style={{ display: 'grid', gap: '15px' }}>
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>状态：</label>
              <select
                value={formData.status}
                onChange={(e) => setFormData(prev => ({ ...prev, status: e.target.value }))}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
              >
                <option value="">不更新</option>
                <option value="open">开放</option>
                <option value="taken">已接受</option>
                <option value="in_progress">进行中</option>
                <option value="completed">已完成</option>
                <option value="cancelled">已取消</option>
              </select>
            </div>
            
            <div>
              <label style={{ display: 'block', marginBottom: '5px', fontWeight: 'bold' }}>等级：</label>
              <select
                value={formData.task_level}
                onChange={(e) => setFormData(prev => ({ ...prev, task_level: e.target.value }))}
                style={{ width: '100%', padding: '8px', border: '1px solid #ddd', borderRadius: '4px' }}
              >
                <option value="">不更新</option>
                <option value="low">低</option>
                <option value="medium">中</option>
                <option value="high">高</option>
              </select>
            </div>
          </div>
          
          <div style={{
            display: 'flex',
            justifyContent: 'flex-end',
            gap: '10px',
            marginTop: '20px',
            paddingTop: '15px',
            borderTop: '1px solid #eee'
          }}>
            <button
              type="button"
              onClick={onClose}
              style={{
                padding: '8px 16px',
                border: '1px solid #ddd',
                background: 'white',
                borderRadius: '4px',
                cursor: 'pointer'
              }}
            >
              取消
            </button>
            <button
              type="submit"
              style={{
                padding: '8px 16px',
                border: 'none',
                background: '#28a745',
                color: 'white',
                borderRadius: '4px',
                cursor: 'pointer'
              }}
            >
              更新
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default TaskManagement;
