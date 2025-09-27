import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { getMyTasks, fetchCurrentUser, completeTask, cancelTask, confirmTaskCompletion, createReview, getTaskReviews, updateTaskVisibility, deleteTask } from '../api';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import LoginModal from '../components/LoginModal';

// 配置dayjs插件
dayjs.extend(utc);
dayjs.extend(timezone);

interface Task {
  id: number;
  title: string;
  description: string;
  deadline: string;
  reward: number;
  location: string;
  task_type: string;
  task_level?: string;
  poster_id: string;
  taker_id?: string;
  status: string;
  created_at: string;
  is_public?: number;
}

const MyTasks: React.FC = () => {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(true);
  const [user, setUser] = useState<any>(null);
  const [activeTab, setActiveTab] = useState<'all' | 'posted' | 'taken'>('all');
  const [actionLoading, setActionLoading] = useState<number | null>(null);
  const [showReviewModal, setShowReviewModal] = useState(false);
  const [reviewRating, setReviewRating] = useState(5);
  const [hoverRating, setHoverRating] = useState(0);
  const [reviewComment, setReviewComment] = useState('');
  const [isAnonymous, setIsAnonymous] = useState(false);
  const [currentReviewTask, setCurrentReviewTask] = useState<Task | null>(null);
  const [taskReviews, setTaskReviews] = useState<{[key: number]: any[]}>({});
  const [showTaskReviews, setShowTaskReviews] = useState<{[key: number]: boolean}>({});
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    // 直接获取用户信息，HttpOnly Cookie会自动发送
    fetchCurrentUser().then(setUser).catch(() => {
      setUser(null);
      setShowLoginModal(true);
    });
  }, [navigate]);

  useEffect(() => {
    if (user) {
      loadTasks();
    }
  }, [user]);

  const loadTasks = async () => {
    setLoading(true);
    try {
      const tasksData = await getMyTasks();
      setTasks(tasksData);
      
      const completedTasks = tasksData.filter((task: Task) => task.status === 'completed');
      for (const task of completedTasks) {
        await loadTaskReviews(task.id);
      }
    } catch (error) {
      console.error('获取任务失败:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleCompleteTask = async (taskId: number) => {
    setActionLoading(taskId);
    try {
      await completeTask(taskId);
      alert('任务已标记为完成，等待发布者确认！');
      loadTasks();
    } catch (error: any) {
      alert(error.response?.data?.detail || '操作失败');
    } finally {
      setActionLoading(null);
    }
  };

  const handleConfirmCompletion = async (taskId: number) => {
    setActionLoading(taskId);
    try {
      await confirmTaskCompletion(taskId);
      alert('任务已确认完成！');
      loadTasks();
    } catch (error: any) {
      alert(error.response?.data?.detail || '操作失败');
    } finally {
      setActionLoading(null);
    }
  };

  const handleCancelTask = async (taskId: number) => {
    const reason = prompt('请输入取消原因（可选）：');
    setActionLoading(taskId);
    try {
      await cancelTask(taskId, reason || undefined);
      alert('任务已取消');
      loadTasks();
    } catch (error: any) {
      alert(error.response?.data?.detail || '操作失败');
    } finally {
      setActionLoading(null);
    }
  };

  const handleUpdateVisibility = async (taskId: number, isPublic: number) => {
    setActionLoading(taskId);
    try {
      await updateTaskVisibility(taskId, isPublic);
      alert('任务可见性已更新！');
      loadTasks();
    } catch (error: any) {
      alert(error.response?.data?.detail || '更新可见性失败');
    } finally {
      setActionLoading(null);
    }
  };

  const handleDeleteTask = async (taskId: number) => {
    if (!window.confirm('确定要删除这个任务吗？删除后无法恢复。')) {
      return;
    }
    
    setActionLoading(taskId);
    try {
      await deleteTask(taskId);
      alert('任务已删除！');
      loadTasks();
    } catch (error: any) {
      alert(error.response?.data?.detail || '删除失败');
    } finally {
      setActionLoading(null);
    }
  };

  const handleViewTask = (taskId: number) => {
    navigate(`/tasks/${taskId}`);
  };

  const handleChat = (userId: string) => {
    navigate(`/message?uid=${userId}`);
  };

  const handleReviewTask = (task: Task) => {
    setCurrentReviewTask(task);
    setShowReviewModal(true);
  };

  const handleSubmitReview = async () => {
    if (!currentReviewTask) return;
    
    setActionLoading(currentReviewTask.id);
    try {
      await createReview(currentReviewTask.id, reviewRating, reviewComment, isAnonymous);
      alert('评价提交成功！');
      setShowReviewModal(false);
      setReviewRating(5);
      setReviewComment('');
      setIsAnonymous(false);
      setCurrentReviewTask(null);
      await loadTasks();
    } catch (error: any) {
      alert(error.response?.data?.detail || '评价提交失败');
    } finally {
      setActionLoading(null);
    }
  };

  const loadTaskReviews = async (taskId: number) => {
    try {
      const reviews = await getTaskReviews(taskId);
      setTaskReviews(prev => ({ ...prev, [taskId]: reviews }));
    } catch (error) {
      console.error('加载评价失败:', error);
    }
  };

  const toggleTaskReviews = (taskId: number) => {
    setShowTaskReviews(prev => ({
      ...prev,
      [taskId]: !prev[taskId]
    }));
  };

  const canReview = (task: Task) => {
    if (!user || !task) return false;
    return (task.poster_id === user.id || task.taker_id === user.id) && task.status === 'completed';
  };

  const hasReviewed = (task: Task) => {
    if (!user || !taskReviews[task.id]) return false;
    return taskReviews[task.id].some((review: any) => review.user_id === user.id);
  };

  const getStatusText = (status: string) => {
    switch (status) {
      case 'open': return '开放中';
      case 'taken': return '已接受';
      case 'in_progress': return '进行中';
      case 'pending_confirmation': return '待确认';
      case 'completed': return '已完成';
      case 'cancelled': return '已取消';
      default: return status;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'open': return '#10b981';
      case 'taken': return '#f59e0b';
      case 'in_progress': return '#3b82f6';
      case 'pending_confirmation': return '#f59e0b';
      case 'completed': return '#6b7280';
      case 'cancelled': return '#3b82f6';
      default: return '#6b7280';
    }
  };

  const getTaskLevelText = (level: string) => {
    switch (level) {
      case 'vip':
        return '⭐ VIP';
      case 'super':
        return '🔥 超级';
      default:
        return '普通';
    }
  };

  const getTaskLevelStyle = (level: string) => {
    switch (level) {
      case 'vip':
        return {
          background: 'linear-gradient(135deg, #fbbf24, #f59e0b)',
          color: '#92400e',
          border: '1px solid #f59e0b'
        };
      case 'super':
        return {
          background: 'linear-gradient(135deg, #8b5cf6, #7c3aed)',
          color: '#fff',
          border: '1px solid #7c3aed'
        };
      default:
        return {
          background: '#f3f4f6',
          color: '#6b7280',
          border: '1px solid #d1d5db'
        };
    }
  };

  const filteredTasks = tasks.filter(task => {
    if (activeTab === 'posted') return task.poster_id === user?.id;
    if (activeTab === 'taken') return task.taker_id === user?.id;
    return true;
  });

  if (loading) {
    return (
      <div style={{ 
        minHeight: '100vh', 
        background: '#fff',
        display: 'flex', 
        justifyContent: 'center', 
        alignItems: 'center',
        fontSize: 18,
        color: '#333'
      }}>
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 48, marginBottom: 16 }}>⏳</div>
          <div>加载中...</div>
        </div>
      </div>
    );
  }

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: '#f8fafc',
      padding: '40px 20px'
    }}>
      <div style={{ 
        maxWidth: '1400px', 
        margin: '0 auto',
        background: '#fff',
        borderRadius: '8px',
        boxShadow: '0 1px 3px rgba(0,0,0,0.1)',
        overflow: 'hidden'
      }}>
        {/* 页面头部 */}
        <div style={{
          background: '#fff',
          color: '#1f2937',
          padding: '32px 40px',
          borderBottom: '1px solid #e5e7eb',
          position: 'relative'
        }}>
          <button
            onClick={() => navigate('/')}
            style={{
              position: 'absolute',
              left: '40px',
              top: '32px',
              background: '#3b82f6',
              border: 'none',
              color: '#fff',
              padding: '8px 16px',
              borderRadius: '6px',
              cursor: 'pointer',
              fontSize: '14px',
              fontWeight: '500',
              transition: 'all 0.2s ease'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = '#1d4ed8';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = '#3b82f6';
            }}
          >
            ← 返回首页
          </button>
          
          <div style={{ 
            display: 'flex', 
            alignItems: 'center', 
            justifyContent: 'center',
            gap: '12px',
            marginBottom: '8px'
          }}>
            <div style={{ fontSize: '24px' }}>📋</div>
            <h1 style={{ 
              margin: 0, 
              fontSize: '28px', 
              fontWeight: '600',
              color: '#1f2937'
            }}>
              我的任务
            </h1>
          </div>
          <p style={{ 
            fontSize: '16px', 
            color: '#6b7280',
            margin: 0,
            textAlign: 'center'
          }}>
            管理您发布和接受的任务
          </p>
        </div>

        {/* 统计概览 */}
        <div style={{ 
          padding: '24px 40px',
          background: '#f9fafb',
          borderBottom: '1px solid #e5e7eb'
        }}>
          <div style={{ 
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: '16px'
          }}>
            <div style={{
              background: '#fff',
              padding: '16px',
              borderRadius: '6px',
              textAlign: 'center',
              boxShadow: '0 1px 2px rgba(0,0,0,0.05)',
              border: '1px solid #e5e7eb'
            }}>
                   <div style={{ fontSize: '20px', fontWeight: '600', color: '#3b82f6', marginBottom: '4px' }}>
                     {tasks.length}
                   </div>
              <div style={{ fontSize: '13px', color: '#6b7280' }}>总任务数</div>
            </div>
            
            <div style={{
              background: '#fff',
              padding: '16px',
              borderRadius: '6px',
              textAlign: 'center',
              boxShadow: '0 1px 2px rgba(0,0,0,0.05)',
              border: '1px solid #e5e7eb'
            }}>
              <div style={{ fontSize: '20px', fontWeight: '600', color: '#10b981', marginBottom: '4px' }}>
                {tasks.filter(t => t.poster_id === user?.id).length}
              </div>
              <div style={{ fontSize: '13px', color: '#6b7280' }}>我发布的</div>
            </div>
            
            <div style={{
              background: '#fff',
              padding: '16px',
              borderRadius: '6px',
              textAlign: 'center',
              boxShadow: '0 1px 2px rgba(0,0,0,0.05)',
              border: '1px solid #e5e7eb'
            }}>
              <div style={{ fontSize: '20px', fontWeight: '600', color: '#f59e0b', marginBottom: '4px' }}>
                {tasks.filter(t => t.taker_id === user?.id).length}
              </div>
              <div style={{ fontSize: '13px', color: '#6b7280' }}>我接受的</div>
            </div>
            
            <div style={{
              background: '#fff',
              padding: '16px',
              borderRadius: '6px',
              textAlign: 'center',
              boxShadow: '0 1px 2px rgba(0,0,0,0.05)',
              border: '1px solid #e5e7eb'
            }}>
              <div style={{ fontSize: '20px', fontWeight: '600', color: '#6b7280', marginBottom: '4px' }}>
                {tasks.filter(t => t.status === 'completed').length}
              </div>
              <div style={{ fontSize: '13px', color: '#6b7280' }}>已完成</div>
            </div>
          </div>
        </div>

        {/* 标签页 */}
        <div style={{ 
          padding: '16px 40px 0 40px',
          borderBottom: '1px solid #e5e7eb'
        }}>
          <div style={{ 
            display: 'flex', 
            gap: '8px'
          }}>
            {[
              { key: 'all', label: '全部任务', count: tasks.length, icon: '📋' },
              { key: 'posted', label: '我发布的', count: tasks.filter(t => t.poster_id === user?.id).length, icon: '📤' },
              { key: 'taken', label: '我接受的', count: tasks.filter(t => t.taker_id === user?.id).length, icon: '📥' }
            ].map(tab => (
              <button
                key={tab.key}
                onClick={() => setActiveTab(tab.key as any)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  padding: '8px 16px',
                  border: 'none',
                  borderRadius: '6px',
                       background: activeTab === tab.key ? '#3b82f6' : '#f3f4f6',
                       color: activeTab === tab.key ? '#fff' : '#374151',
                  cursor: 'pointer',
                  fontWeight: '500',
                  fontSize: '14px',
                  transition: 'all 0.2s ease',
                  boxShadow: activeTab === tab.key ? '0 1px 2px rgba(59, 130, 246, 0.2)' : 'none'
                }}
                onMouseEnter={(e) => {
                  if (activeTab !== tab.key) {
                    e.currentTarget.style.background = '#e5e7eb';
                  }
                }}
                onMouseLeave={(e) => {
                  if (activeTab !== tab.key) {
                    e.currentTarget.style.background = '#f3f4f6';
                  }
                }}
              >
                <span>{tab.icon}</span>
                <span>{tab.label}</span>
                <span style={{
                  background: activeTab === tab.key ? 'rgba(255,255,255,0.2)' : '#d1d5db',
                  color: activeTab === tab.key ? '#fff' : '#6b7280',
                  padding: '2px 6px',
                  borderRadius: '4px',
                  fontSize: '12px',
                  fontWeight: '500'
                }}>
                  {tab.count}
                </span>
              </button>
            ))}
          </div>
        </div>

        {/* 任务列表 */}
        <div style={{ padding: '24px 40px' }}>
          {filteredTasks.length === 0 ? (
            <div style={{ 
              textAlign: 'center', 
              padding: '80px 20px',
              color: '#64748b'
            }}>
              <div style={{ fontSize: 64, marginBottom: 20 }}>📭</div>
              <div style={{ fontSize: 18, fontWeight: '600', marginBottom: 8 }}>
                {activeTab === 'all' && '暂无任务'}
                {activeTab === 'posted' && '您还没有发布过任务'}
                {activeTab === 'taken' && '您还没有接受过任务'}
              </div>
              <div style={{ fontSize: 14 }}>
                {activeTab === 'posted' && '点击首页的"发布任务"按钮开始发布您的第一个任务'}
                {activeTab === 'taken' && '浏览首页的任务列表，接受您感兴趣的任务'}
              </div>
            </div>
          ) : (
            <div style={{ 
              display: 'grid', 
              gridTemplateColumns: 'repeat(auto-fill, minmax(400px, 1fr))',
              gap: '24px'
            }}>
              {filteredTasks.map(task => {
                const isPoster = task.poster_id === user?.id;
                const isTaker = task.taker_id === user?.id;
                
                return (
                  <div key={task.id} style={{
                    background: '#fff',
                    borderRadius: '16px',
                    padding: '24px',
                    boxShadow: '0 4px 12px rgba(0,0,0,0.05)',
                    border: '1px solid #e2e8f0',
                    transition: 'all 0.3s ease',
                    position: 'relative',
                    overflow: 'hidden'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.transform = 'translateY(-4px)';
                    e.currentTarget.style.boxShadow = '0 8px 25px rgba(0,0,0,0.1)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.transform = 'translateY(0)';
                    e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.05)';
                  }}
                  >
                    {/* 任务等级装饰 */}
                    {task.task_level && task.task_level !== 'normal' && (
                      <div style={{
                        position: 'absolute',
                        top: '0',
                        right: '0',
                        width: '0',
                        height: '0',
                        borderLeft: '40px solid transparent',
                        borderTop: `40px solid ${task.task_level === 'vip' ? '#f59e0b' : '#8b5cf6'}`,
                        opacity: 0.1
                      }} />
                    )}

                    {/* 任务标题和状态 */}
                    <div style={{ 
                      display: 'flex', 
                      justifyContent: 'space-between', 
                      alignItems: 'flex-start',
                      marginBottom: '16px'
                    }}>
                      <div style={{ flex: 1, marginRight: '12px' }}>
                        <h3 style={{ 
                          fontSize: '18px', 
                          fontWeight: '700', 
                          color: '#1e293b',
                          margin: '0 0 8px 0',
                          lineHeight: '1.4'
                        }}>
                          {task.title}
                        </h3>
                        {/* 任务等级标签 */}
                        {task.task_level && task.task_level !== 'normal' && (
                          <div style={{
                            display: 'inline-block',
                            padding: '4px 8px',
                            borderRadius: '8px',
                            fontSize: '11px',
                            fontWeight: '600',
                            marginRight: '8px',
                            ...getTaskLevelStyle(task.task_level)
                          }}>
                            {getTaskLevelText(task.task_level)}
                          </div>
                        )}
                      </div>
                      <span style={{
                        padding: '6px 12px',
                        borderRadius: '8px',
                        fontSize: '12px',
                        fontWeight: '600',
                        color: '#fff',
                        background: getStatusColor(task.status),
                        whiteSpace: 'nowrap'
                      }}>
                        {getStatusText(task.status)}
                      </span>
                    </div>

                    {/* 任务信息 */}
                    <div style={{ marginBottom: '16px' }}>
                      <div style={{ 
                        display: 'grid',
                        gridTemplateColumns: '1fr 1fr',
                        gap: '8px',
                        marginBottom: '12px'
                      }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <span style={{ fontSize: '14px', color: '#64748b' }}>💰</span>
                          <span style={{ fontSize: '14px', color: '#1e293b', fontWeight: '600' }}>£{task.reward}</span>
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <span style={{ fontSize: '14px', color: '#64748b' }}>📍</span>
                          <span style={{ fontSize: '14px', color: '#1e293b' }}>{task.location}</span>
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <span style={{ fontSize: '14px', color: '#64748b' }}>🏷️</span>
                          <span style={{ fontSize: '14px', color: '#1e293b' }}>{task.task_type}</span>
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <span style={{ fontSize: '14px', color: '#64748b' }}>👤</span>
                          <span style={{ fontSize: '14px', color: '#1e293b' }}>
                            {isPoster ? '发布者' : isTaker ? '接受者' : '未知'}
                          </span>
                        </div>
                      </div>
                      
                      <div style={{ 
                        display: 'flex', 
                        alignItems: 'center', 
                        gap: '6px',
                        marginBottom: '8px'
                      }}>
                        <span style={{ fontSize: '14px', color: '#64748b' }}>⏰</span>
                        <span style={{ fontSize: '14px', color: '#1e293b' }}>
                          {task.deadline && dayjs(task.deadline).tz('Europe/London').format('MM/DD HH:mm')}
                        </span>
                      </div>
                    </div>

                    {/* 任务描述 */}
                    <div style={{ 
                      marginBottom: '20px',
                      padding: '12px',
                      background: '#f8fafc',
                      borderRadius: '8px',
                      fontSize: '14px',
                      color: '#475569',
                      lineHeight: '1.5',
                      border: '1px solid #e2e8f0'
                    }}>
                      {task.description.length > 120 
                        ? `${task.description.substring(0, 120)}...` 
                        : task.description
                      }
                    </div>

                    {/* 操作按钮 */}
                    <div style={{ 
                      display: 'flex', 
                      gap: '12px',
                      flexWrap: 'wrap',
                      marginTop: '16px',
                      paddingTop: '16px',
                      borderTop: '1px solid #f3f4f6'
                    }}>
                      <button
                        onClick={() => handleViewTask(task.id)}
                        style={{
                          padding: '10px 18px',
                          border: '1px solid #667eea',
                          borderRadius: '6px',
                          background: 'transparent',
                          color: '#667eea',
                          cursor: 'pointer',
                          fontSize: '13px',
                          fontWeight: '500',
                          transition: 'all 0.2s ease',
                          minWidth: '80px'
                        }}
                        onMouseEnter={(e) => {
                          e.currentTarget.style.background = '#667eea';
                          e.currentTarget.style.color = '#fff';
                        }}
                        onMouseLeave={(e) => {
                          e.currentTarget.style.background = 'transparent';
                          e.currentTarget.style.color = '#667eea';
                        }}
                      >
                        查看详情
                      </button>

                      {/* 可见性控制按钮 */}
                      {isPoster && task.status === 'completed' && (
                        <button
                          onClick={() => handleUpdateVisibility(task.id, task.is_public === 1 ? 0 : 1)}
                          disabled={actionLoading === task.id}
                          style={{
                            padding: '10px 18px',
                            border: 'none',
                            borderRadius: '6px',
                            background: task.is_public === 1 ? '#3b82f6' : '#10b981',
                            color: '#fff',
                            cursor: actionLoading === task.id ? 'not-allowed' : 'pointer',
                            fontSize: '13px',
                            fontWeight: '500',
                            opacity: actionLoading === task.id ? 0.6 : 1,
                            transition: 'all 0.2s ease',
                            minWidth: '80px'
                          }}
                        >
                          {actionLoading === task.id ? '处理中...' : (task.is_public === 1 ? '设为私密' : '设为公开')}
                        </button>
                      )}

                      {/* 根据任务状态和用户角色显示不同按钮 */}
                      {task.status === 'taken' && isTaker && (
                        <div style={{
                          background: '#fff3cd',
                          border: '1px solid #ffeaa7',
                          borderRadius: '8px',
                          padding: '12px 16px',
                          color: '#856404',
                          fontSize: '14px',
                          fontWeight: '600',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '8px',
                          marginBottom: '8px'
                        }}>
                          <span style={{fontSize: '16px'}}>⏳</span>
                          <span>等待发布者同意</span>
                        </div>
                      )}

                      {task.status === 'in_progress' && isTaker && (
                        <button
                          onClick={() => handleCompleteTask(task.id)}
                          disabled={actionLoading === task.id}
                          style={{
                            padding: '10px 18px',
                            border: 'none',
                            borderRadius: '6px',
                            background: '#10b981',
                            color: '#fff',
                            cursor: actionLoading === task.id ? 'not-allowed' : 'pointer',
                            fontSize: '13px',
                            fontWeight: '500',
                            opacity: actionLoading === task.id ? 0.6 : 1,
                            transition: 'all 0.2s ease',
                            minWidth: '80px'
                          }}
                        >
                          {actionLoading === task.id ? '处理中...' : '标记完成'}
                        </button>
                      )}

                      {task.status === 'pending_confirmation' && isPoster && (
                        <button
                          onClick={() => handleConfirmCompletion(task.id)}
                          disabled={actionLoading === task.id}
                          style={{
                            padding: '10px 18px',
                            border: 'none',
                            borderRadius: '6px',
                            background: '#10b981',
                            color: '#fff',
                            cursor: actionLoading === task.id ? 'not-allowed' : 'pointer',
                            fontSize: '13px',
                            fontWeight: '500',
                            opacity: actionLoading === task.id ? 0.6 : 1,
                            transition: 'all 0.2s ease',
                            minWidth: '80px'
                          }}
                        >
                          {actionLoading === task.id ? '处理中...' : '确认完成'}
                        </button>
                      )}

                      {(task.status === 'open' || task.status === 'taken' || task.status === 'pending_confirmation') && (
                        <button
                          onClick={() => handleCancelTask(task.id)}
                          disabled={actionLoading === task.id}
                          style={{
                            padding: '10px 18px',
                            border: 'none',
                            borderRadius: '6px',
                            background: '#3b82f6',
                            color: '#fff',
                            cursor: actionLoading === task.id ? 'not-allowed' : 'pointer',
                            fontSize: '13px',
                            fontWeight: '500',
                            opacity: actionLoading === task.id ? 0.6 : 1,
                            transition: 'all 0.2s ease',
                            minWidth: '80px'
                          }}
                        >
                          {actionLoading === task.id ? '处理中...' : '取消任务'}
                        </button>
                      )}

                      {/* 聊天按钮 */}
                      {(task.status === 'taken' || task.status === 'pending_confirmation') && (
                        <button
                          onClick={() => handleChat(isPoster ? task.taker_id! : task.poster_id)}
                          style={{
                            padding: '10px 18px',
                            border: 'none',
                            borderRadius: '6px',
                            background: '#3b82f6',
                            color: '#fff',
                            cursor: 'pointer',
                            fontSize: '13px',
                            fontWeight: '500',
                            transition: 'all 0.2s ease',
                            minWidth: '80px'
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.background = '#2563eb';
                            e.currentTarget.style.transform = 'translateY(-1px)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.background = '#3b82f6';
                            e.currentTarget.style.transform = 'translateY(0)';
                          }}
                        >
                          联系{isPoster ? '接受者' : '发布者'}
                        </button>
                      )}

                      {/* 评价按钮 */}
                      {canReview(task) && !hasReviewed(task) && (
                        <button
                          onClick={() => handleReviewTask(task)}
                          style={{
                            padding: '10px 18px',
                            border: 'none',
                            borderRadius: '6px',
                            background: '#f59e0b',
                            color: '#fff',
                            cursor: 'pointer',
                            fontSize: '13px',
                            fontWeight: '500',
                            transition: 'all 0.2s ease',
                            minWidth: '80px'
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.background = '#d97706';
                            e.currentTarget.style.transform = 'translateY(-1px)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.background = '#f59e0b';
                            e.currentTarget.style.transform = 'translateY(0)';
                          }}
                        >
                          ⭐ 评价
                        </button>
                      )}

                      {/* 查看评价按钮 */}
                      {task.status === 'completed' && taskReviews[task.id] && taskReviews[task.id].length > 0 && (
                        <button
                          onClick={() => toggleTaskReviews(task.id)}
                          style={{
                            padding: '8px 16px',
                            border: 'none',
                            borderRadius: '8px',
                            background: '#06b6d4',
                            color: '#fff',
                            cursor: 'pointer',
                            fontSize: '12px',
                            fontWeight: '600',
                            transition: 'all 0.3s ease'
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.background = '#0891b2';
                            e.currentTarget.style.transform = 'translateY(-1px)';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.background = '#06b6d4';
                            e.currentTarget.style.transform = 'translateY(0)';
                          }}
                        >
                          {showTaskReviews[task.id] ? '隐藏评价' : `查看评价 (${taskReviews[task.id].length})`}
                        </button>
                      )}

                      {/* 删除按钮 */}
                      {task.status === 'cancelled' && isPoster && (
                        <button
                          onClick={() => handleDeleteTask(task.id)}
                          disabled={actionLoading === task.id}
                          style={{
                            padding: '8px 16px',
                            border: 'none',
                            borderRadius: '8px',
                            background: '#3b82f6',
                            color: '#fff',
                            cursor: actionLoading === task.id ? 'not-allowed' : 'pointer',
                            fontSize: '12px',
                            fontWeight: '600',
                            opacity: actionLoading === task.id ? 0.6 : 1,
                            transition: 'all 0.3s ease'
                          }}
                        >
                          {actionLoading === task.id ? '删除中...' : '🗑️ 删除'}
                        </button>
                      )}
                    </div>

                    {/* 评价列表 */}
                    {showTaskReviews[task.id] && taskReviews[task.id] && taskReviews[task.id].length > 0 && (
                      <div style={{
                        marginTop: '20px',
                        padding: '16px',
                        background: '#f8fafc',
                        borderRadius: '12px',
                        border: '1px solid #e2e8f0'
                      }}>
                        <h4 style={{
                          marginBottom: '12px',
                          color: '#667eea',
                          fontSize: '14px',
                          fontWeight: '600'
                        }}>
                          任务评价
                        </h4>
                        {taskReviews[task.id].map((review: any, index: number) => (
                          <div key={index} style={{
                            padding: '12px',
                            background: '#fff',
                            borderRadius: '8px',
                            marginBottom: '8px',
                            border: '1px solid #e2e8f0'
                          }}>
                            <div style={{
                              display: 'flex',
                              justifyContent: 'space-between',
                              alignItems: 'center',
                              marginBottom: '6px'
                            }}>
                              <div style={{
                                fontWeight: '600',
                                color: '#1e293b',
                                fontSize: '13px'
                              }}>
                                用户 {review.user_id}
                              </div>
                              <div style={{
                                color: '#f59e0b',
                                fontSize: '14px'
                              }}>
                                {Array.from({length: Math.floor(review.rating)}, (_, i) => '⭐').join('')}
                                {review.rating % 1 !== 0 && '☆'}
                                {Array.from({length: 5 - Math.ceil(review.rating)}, (_, i) => '☆').join('')}
                              </div>
                            </div>
                            {review.comment && (
                              <div style={{
                                color: '#64748b',
                                fontSize: '12px',
                                lineHeight: '1.4'
                              }}>
                                {review.comment}
                              </div>
                            )}
                            <div style={{
                              color: '#94a3b8',
                              fontSize: '11px',
                              marginTop: '6px'
                            }}>
                              {new Date(review.created_at).toLocaleString()}
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* 评价弹窗 */}
      {showReviewModal && currentReviewTask && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0,0,0,0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          backdropFilter: 'blur(4px)'
        }}>
          <div style={{
            background: '#fff',
            borderRadius: '20px',
            padding: '40px',
            maxWidth: '500px',
            width: '90%',
            maxHeight: '80vh',
            overflow: 'auto',
            boxShadow: '0 20px 40px rgba(0,0,0,0.2)'
          }}>
            <h2 style={{
              marginBottom: '24px', 
              color: '#667eea', 
              textAlign: 'center',
              fontSize: '24px',
              fontWeight: 'bold'
            }}>
              评价任务: {currentReviewTask.title}
            </h2>
            
            <div style={{marginBottom: '24px'}}>
              <label style={{
                display: 'block', 
                marginBottom: '12px', 
                fontWeight: '600', 
                color: '#1e293b',
                fontSize: '16px'
              }}>
                评分 (0.5-5星)
              </label>
              <div style={{
                display: 'flex', 
                gap: '6px', 
                justifyContent: 'center', 
                alignItems: 'center',
                marginBottom: '12px'
              }}>
                {[0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5].map(star => (
                  <button
                    key={star}
                    onClick={() => setReviewRating(star)}
                    onMouseEnter={() => setHoverRating(star)}
                    onMouseLeave={() => setHoverRating(0)}
                    style={{
                      background: 'none',
                      border: 'none',
                      fontSize: star % 1 === 0 ? 28 : 20,
                      cursor: 'pointer',
                      color: star <= (hoverRating || reviewRating) ? '#f59e0b' : '#d1d5db',
                      transition: 'all 0.3s ease',
                      padding: '4px',
                      transform: star <= (hoverRating || reviewRating) ? 'scale(1.2)' : 'scale(1)',
                      filter: star <= (hoverRating || reviewRating) ? 'drop-shadow(0 0 8px rgba(245, 158, 11, 0.6))' : 'none'
                    }}
                  >
                    {star <= (hoverRating || reviewRating) ? '⭐' : '☆'}
                  </button>
                ))}
              </div>
              <div style={{
                textAlign: 'center', 
                color: '#64748b', 
                fontSize: '16px',
                fontWeight: '600',
                opacity: reviewRating > 0 ? 1 : 0.7,
                transform: reviewRating > 0 ? 'scale(1.05)' : 'scale(1)',
                transition: 'all 0.3s ease'
              }}>
                当前评分: {reviewRating} 星
              </div>
            </div>

            <div style={{marginBottom: '32px'}}>
              <label style={{
                display: 'block', 
                marginBottom: '12px', 
                fontWeight: '600', 
                color: '#1e293b',
                fontSize: '16px'
              }}>
                评价内容 (可选)
              </label>
              <textarea
                value={reviewComment}
                onChange={(e) => setReviewComment(e.target.value)}
                placeholder="请分享您对这次任务的体验..."
                style={{
                  width: '100%',
                  minHeight: '120px',
                  padding: '16px',
                  border: '2px solid #e2e8f0',
                  borderRadius: '12px',
                  fontSize: '14px',
                  resize: 'vertical',
                  fontFamily: 'inherit',
                  transition: 'border-color 0.3s ease'
                }}
                onFocus={(e) => {
                  e.currentTarget.style.borderColor = '#667eea';
                }}
                onBlur={(e) => {
                  e.currentTarget.style.borderColor = '#e2e8f0';
                }}
              />
            </div>

            <div style={{marginBottom: '24px'}}>
              <label style={{display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer'}}>
                <input
                  type="checkbox"
                  checked={isAnonymous}
                  onChange={(e) => setIsAnonymous(e.target.checked)}
                  style={{transform: 'scale(1.2)'}}
                />
                <span style={{fontWeight: '600', color: '#1e293b'}}>
                  匿名评价
                </span>
                <span style={{fontSize: '12px', color: '#64748b'}}>
                  (选择匿名后，您的评价将不会显示您的身份信息)
                </span>
              </label>
            </div>

            <div style={{
              display: 'flex', 
              gap: '16px', 
              justifyContent: 'center'
            }}>
              <button
                onClick={handleSubmitReview}
                disabled={actionLoading === currentReviewTask.id}
                style={{
                  background: 'linear-gradient(135deg, #10b981, #059669)',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '12px',
                  padding: '16px 32px',
                  fontWeight: '600',
                  fontSize: '16px',
                  cursor: actionLoading === currentReviewTask.id ? 'not-allowed' : 'pointer',
                  opacity: actionLoading === currentReviewTask.id ? 0.6 : 1,
                  transition: 'all 0.3s ease',
                  boxShadow: '0 4px 12px rgba(16, 185, 129, 0.3)'
                }}
                onMouseEnter={(e) => {
                  if (actionLoading !== currentReviewTask.id) {
                    e.currentTarget.style.transform = 'translateY(-2px)';
                    e.currentTarget.style.boxShadow = '0 8px 20px rgba(16, 185, 129, 0.4)';
                  }
                }}
                onMouseLeave={(e) => {
                  if (actionLoading !== currentReviewTask.id) {
                    e.currentTarget.style.transform = 'translateY(0)';
                    e.currentTarget.style.boxShadow = '0 4px 12px rgba(16, 185, 129, 0.3)';
                  }
                }}
              >
                {actionLoading === currentReviewTask.id ? '提交中...' : '提交评价'}
              </button>
              <button
                onClick={() => {
                  setShowReviewModal(false);
                  setReviewRating(5);
                  setReviewComment('');
                  setIsAnonymous(false);
                  setCurrentReviewTask(null);
                }}
                style={{
                  background: '#f1f5f9',
                  color: '#64748b',
                  border: '2px solid #e2e8f0',
                  borderRadius: '12px',
                  padding: '16px 32px',
                  fontWeight: '600',
                  fontSize: '16px',
                  cursor: 'pointer',
                  transition: 'all 0.3s ease'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = '#e2e8f0';
                  e.currentTarget.style.borderColor = '#cbd5e1';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = '#f1f5f9';
                  e.currentTarget.style.borderColor = '#e2e8f0';
                }}
              >
                取消
              </button>
            </div>
          </div>
        </div>
      )}
      
      {/* 登录弹窗 */}
      <LoginModal 
        isOpen={showLoginModal}
        onClose={() => {
          setShowLoginModal(false);
          navigate('/');
        }}
        onSuccess={() => {
          window.location.reload();
        }}
        onReopen={() => {
          setShowLoginModal(true);
        }}
        showForgotPassword={showForgotPasswordModal}
        onShowForgotPassword={() => {
          setShowForgotPasswordModal(true);
        }}
        onHideForgotPassword={() => {
          setShowForgotPasswordModal(false);
        }}
      />
    </div>
  );
};

export default MyTasks;