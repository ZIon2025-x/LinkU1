import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useLanguage } from '../contexts/LanguageContext';
import { getMyTasks, fetchCurrentUser, completeTask, cancelTask, confirmTaskCompletion, createReview, getTaskReviews, updateTaskVisibility, deleteTask, getNotifications, getUnreadNotifications, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, getPublicSystemSettings, logout, getUserApplications } from '../api';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import LoginModal from '../components/LoginModal';
import TaskDetailModal from '../components/TaskDetailModal';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';

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

interface Notification {
  id: number;
  content: string;
  is_read: number;
  created_at: string;
  type?: string;
}

const MyTasks: React.FC = () => {
  const { t } = useLanguage();
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loading, setLoading] = useState(true);
  const [user, setUser] = useState<any>(null);
  const [activeTab, setActiveTab] = useState<'all' | 'posted' | 'taken' | 'pending' | 'completed' | 'cancelled'>('all');
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
  
  // 分页相关状态
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize] = useState(12);
  const [totalTasks, setTotalTasks] = useState(0);
  
  // 通知相关状态
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  
  // 系统设置状态
  const [systemSettings, setSystemSettings] = useState<any>({
    vip_button_visible: false
  });
  
  // 申请状态相关
  const [applications, setApplications] = useState<any[]>([]);
  const [loadingApplications, setLoadingApplications] = useState(false);
  
  // 已操作任务状态
  const [completedTasks, setCompletedTasks] = useState<Set<number>>(new Set());
  
  // 任务详情弹窗状态
  const [showTaskDetailModal, setShowTaskDetailModal] = useState(false);
  const [selectedTaskId, setSelectedTaskId] = useState<number | null>(null);
  
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
      loadNotificationsAndSettings();
      loadUserApplications();
    }
  }, [user]);

  // 加载通知和系统设置
  const loadNotificationsAndSettings = async () => {
    if (user) {
      try {
        const [notificationsData, unreadCountData, settingsData] = await Promise.all([
          getNotificationsWithRecentRead(10),
          getUnreadNotificationCount(),
          getPublicSystemSettings()
        ]);
        
        setNotifications(notificationsData);
        setUnreadCount(unreadCountData.unread_count);
        setSystemSettings(settingsData);
      } catch (error) {
        console.error('加载通知或系统设置失败:', error);
      }
    }
  };

  // 加载用户的申请记录
  const loadUserApplications = async () => {
    if (!user) return;
    
    console.log('开始加载用户申请记录...');
    setLoadingApplications(true);
    try {
      const applicationsData = await getUserApplications();
      console.log('申请记录加载成功:', applicationsData);
      setApplications(applicationsData);
    } catch (error) {
      console.error('加载申请记录失败:', error);
    } finally {
      setLoadingApplications(false);
    }
  };

  const loadTasks = async () => {
    setLoading(true);
    try {
      const tasksData = await getMyTasks();
      setTasks(tasksData);
      setTotalTasks(tasksData.length);
      
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

  // 处理通知标记为已读
  const handleMarkAsRead = async (notificationId: number) => {
    try {
      await markNotificationRead(notificationId);
      setNotifications(prev => 
        prev.map(notif => 
          notif.id === notificationId ? { ...notif, is_read: 1 } : notif
        )
      );
      setUnreadCount(prev => Math.max(0, prev - 1));
      console.log('通知标记为已读成功');
    } catch (error) {
      console.error('标记通知为已读失败:', error);
      // 可以添加用户提示，比如toast通知
      alert(t('myTasks.alerts.markReadFailed'));
    }
  };

  // 处理标记所有通知为已读
  const handleMarkAllRead = async () => {
    try {
      await markAllNotificationsRead();
      setNotifications(prev => 
        prev.map(notif => ({ ...notif, is_read: 1 }))
      );
      setUnreadCount(0);
      console.log('所有通知标记为已读成功');
    } catch (error) {
      console.error('标记所有通知已读失败:', error);
      // 可以添加用户提示，比如toast通知
      alert(t('myTasks.alerts.markAllReadFailed'));
    }
  };

  const handleCompleteTask = async (taskId: number) => {
    setActionLoading(taskId);
    try {
      await completeTask(taskId);
      alert(t('myTasks.alerts.taskMarkedComplete'));
      // 将任务添加到已标记完成列表，隐藏按钮
      setCompletedTasks(prev => new Set([...Array.from(prev), taskId]));
      loadTasks();
    } catch (error: any) {
      alert(error.response?.data?.detail || t('myTasks.alerts.operationFailed'));
    } finally {
      setActionLoading(null);
    }
  };

  const handleConfirmCompletion = async (taskId: number) => {
    setActionLoading(taskId);
    try {
      await confirmTaskCompletion(taskId);
      alert(t('myTasks.alerts.taskConfirmedComplete'));
      loadTasks();
    } catch (error: any) {
      alert(error.response?.data?.detail || t('myTasks.alerts.operationFailed'));
    } finally {
      setActionLoading(null);
    }
  };

  const handleCancelTask = async (taskId: number) => {
    const reason = prompt(t('myTasks.cancelReason'));
    setActionLoading(taskId);
    try {
      await cancelTask(taskId, reason || undefined);
      alert(t('myTasks.alerts.taskCancelled'));
      loadTasks();
    } catch (error: any) {
      alert(error.response?.data?.detail || t('myTasks.alerts.operationFailed'));
    } finally {
      setActionLoading(null);
    }
  };

  const handleUpdateVisibility = async (taskId: number, isPublic: number) => {
    setActionLoading(taskId);
    try {
      await updateTaskVisibility(taskId, isPublic);
      alert(t('myTasks.alerts.visibilityUpdated'));
      loadTasks();
    } catch (error: any) {
      alert(error.response?.data?.detail || t('myTasks.alerts.updateVisibilityFailed'));
    } finally {
      setActionLoading(null);
    }
  };

  const handleDeleteTask = async (taskId: number) => {
    if (!window.confirm(t('myTasks.confirmDelete'))) {
      return;
    }
    
    setActionLoading(taskId);
    try {
      await deleteTask(taskId);
      alert(t('myTasks.alerts.taskDeleted'));
      loadTasks();
    } catch (error: any) {
      alert(error.response?.data?.detail || t('myTasks.alerts.deleteFailed'));
    } finally {
      setActionLoading(null);
    }
  };

  const handleViewTask = (taskId: number) => {
    setSelectedTaskId(taskId);
    setShowTaskDetailModal(true);
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
      alert(t('myTasks.alerts.reviewSubmitted'));
      // 评价提交成功，任务数据会重新加载
      setShowReviewModal(false);
      setReviewRating(5);
      setReviewComment('');
      setIsAnonymous(false);
      setCurrentReviewTask(null);
      await loadTasks();
    } catch (error: any) {
      alert(error.response?.data?.detail || t('myTasks.alerts.reviewSubmitFailed'));
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
    if (!user) return false;
    
    // 如果评价数据还没有加载，先加载它
    if (!taskReviews[task.id]) {
      loadTaskReviews(task.id);
      return false; // 暂时返回false，等数据加载完成后再重新渲染
    }
    
    return taskReviews[task.id].some((review: any) => review.user_id === user.id);
  };

  const getStatusText = (status: string) => {
    switch (status) {
      case 'open': return t('myTasks.taskStatus.open');
      case 'taken': return t('myTasks.taskStatus.taken');
      case 'in_progress': return t('myTasks.taskStatus.in_progress');
      case 'pending_confirmation': return t('myTasks.taskStatus.pending_confirmation');
      case 'completed': return t('myTasks.taskStatus.completed');
      case 'cancelled': return t('myTasks.taskStatus.cancelled');
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
        return t('myTasks.taskLevel.super');
      default:
        return t('myTasks.taskLevel.normal');
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

  // 根据标签页过滤数据
  const getFilteredData = () => {
    if (activeTab === 'pending') {
      return applications.filter(app => app.status === 'pending');
    }
    return tasks.filter(task => {
      if (activeTab === 'posted') return task.poster_id === user?.id;
      if (activeTab === 'taken') return task.taker_id === user?.id;
      if (activeTab === 'completed') return task.status === 'completed';
      if (activeTab === 'cancelled') return task.status === 'cancelled';
      return true;
    });
  };

  const filteredData = getFilteredData();
  const totalPages = Math.ceil(filteredData.length / pageSize);
  const startIndex = (currentPage - 1) * pageSize;
  const endIndex = startIndex + pageSize;
  const paginatedData = filteredData.slice(startIndex, endIndex);

  // 当切换标签页时重置到第一页
  useEffect(() => {
    setCurrentPage(1);
  }, [activeTab]);

  // 当切换到已完成标签页时，加载所有已完成任务的评价数据
  useEffect(() => {
    if (activeTab === 'completed' && user) {
      const completedTasks = tasks.filter(task => task.status === 'completed');
      completedTasks.forEach(task => {
        if (!taskReviews[task.id]) {
          loadTaskReviews(task.id);
        }
      });
    }
  }, [activeTab, tasks, user, taskReviews]);

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
          <div>{t('myTasks.loading')}</div>
        </div>
      </div>
    );
  }

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: '#f8fafc'
    }}>
      {/* 顶部导航栏 */}
      <header style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100%',
        background: '#fff',
        zIndex: 100,
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
        padding: '12px 16px'
      }}>
        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          maxWidth: '1200px',
          margin: '0 auto',
          gap: '8px',
          minHeight: '44px'
        }}>
          {/* Logo */}
          <div 
            style={{
              fontWeight: 'bold',
              fontSize: '24px',
              color: '#6EC1E4',
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              padding: '4px 8px',
              borderRadius: '8px',
              flexShrink: 0
            }}
            onClick={() => navigate('/')}
            onMouseEnter={(e) => {
              e.currentTarget.style.color = '#4A90E2';
              e.currentTarget.style.background = 'rgba(110, 193, 228, 0.1)';
              e.currentTarget.style.transform = 'scale(1.05)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.color = '#6EC1E4';
              e.currentTarget.style.background = 'transparent';
              e.currentTarget.style.transform = 'scale(1)';
            }}
          >
            Link2Ur
          </div>

          {/* 通知按钮和汉堡菜单 */}
          <div style={{display: 'flex', alignItems: 'center', gap: '8px'}}>
            <NotificationButton
              user={user}
              unreadCount={unreadCount}
              onNotificationClick={() => setShowNotifications(prev => !prev)}
            />
            <HamburgerMenu
              user={user}
              onLogout={async () => {
                try {
                  await logout();
                } catch (error) {
                  console.log('登出请求失败:', error);
                }
                window.location.reload();
              }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={systemSettings}
            />
          </div>
        </div>
      </header>

          {/* 主要内容区域 */}
          <div className="main-content" style={{
            marginTop: '80px',
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
              <div className="page-header" style={{
                background: '#fff',
                color: '#1f2937',
                padding: '32px 40px',
                borderBottom: '1px solid #e5e7eb',
                position: 'relative'
              }}>
                <button
                  className="back-button"
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
{t('myTasks.buttons.backToHome')}
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
{t('myTasks.title')}
            </h1>
          </div>
          <p style={{ 
            fontSize: '16px', 
            color: '#6b7280',
            margin: '0 0 16px 0',
            textAlign: 'center'
          }}>
{t('myTasks.subtitle')}
          </p>
        </div>

              {/* 统计概览 */}
              <div className="stats-section" style={{ 
                padding: '24px 40px',
                background: '#f9fafb',
                borderBottom: '1px solid #e5e7eb',
                marginTop: '0px'
              }}>
                <div className="stats-grid" style={{ 
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
                  gap: '16px'
                }}>
                  <div className="stat-item" style={{
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
                    <div style={{ fontSize: '13px', color: '#6b7280' }}>{t('myTasks.stats.totalTasks')}</div>
                  </div>
            
                  <div className="stat-item" style={{
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
                    <div style={{ fontSize: '13px', color: '#6b7280' }}>{t('myTasks.stats.posted')}</div>
                  </div>
            
                  <div className="stat-item" style={{
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
                    <div style={{ fontSize: '13px', color: '#6b7280' }}>{t('myTasks.stats.taken')}</div>
                  </div>
            
                  <div className="stat-item" style={{
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
                    <div style={{ fontSize: '13px', color: '#6b7280' }}>{t('myTasks.stats.completed')}</div>
                  </div>
          </div>
        </div>

              {/* 标签页 */}
              <div className="tabs-section" style={{ 
                padding: '16px 40px 0 40px',
                borderBottom: '1px solid #e5e7eb'
              }}>
                <div className="tabs-container" style={{ 
                  display: 'flex', 
                  gap: '8px'
                }}>
            {[
              { key: 'all', label: t('myTasks.tabs.all'), count: tasks.length, icon: '📋' },
              { key: 'posted', label: t('myTasks.tabs.posted'), count: tasks.filter(t => t.poster_id === user?.id).length, icon: '📤' },
              { key: 'taken', label: t('myTasks.tabs.taken'), count: tasks.filter(t => t.taker_id === user?.id).length, icon: '📥' },
              { key: 'pending', label: t('myTasks.tabs.pending'), count: applications.filter(app => app.status === 'pending').length, icon: '⏳' },
              { key: 'completed', label: t('myTasks.tabs.completed'), count: tasks.filter(t => t.status === 'completed').length, icon: '✅' },
              { key: 'cancelled', label: t('myTasks.tabs.cancelled'), count: tasks.filter(t => t.status === 'cancelled').length, icon: '❌' }
            ].map(tab => (
                    <button
                      key={tab.key}
                      className="tab-button"
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
              <div className="tasks-section" style={{ padding: '24px 40px' }}>
          {paginatedData.length === 0 ? (
            <div style={{ 
              textAlign: 'center', 
              padding: '80px 20px',
              color: '#64748b'
            }}>
              <div style={{ fontSize: 64, marginBottom: 20 }}>📭</div>
              <div style={{ fontSize: 18, fontWeight: '600', marginBottom: 8 }}>
                {activeTab === 'all' && t('myTasks.emptyStates.noTasks')}
                {activeTab === 'posted' && t('myTasks.emptyStates.noPosted')}
                {activeTab === 'taken' && t('myTasks.emptyStates.noTaken')}
                {activeTab === 'pending' && '暂无等待审核的申请'}
                {activeTab === 'completed' && t('myTasks.emptyStates.noCompleted')}
                {activeTab === 'cancelled' && t('myTasks.emptyStates.noCancelled')}
              </div>
              <div style={{ fontSize: 14 }}>
                {activeTab === 'posted' && t('myTasks.emptyStates.postFirst')}
                {activeTab === 'taken' && t('myTasks.emptyStates.browseTasks')}
                {activeTab === 'pending' && '您还没有申请任何任务，去任务大厅看看吧！'}
                {activeTab === 'completed' && '完成任务后，它们会出现在这里'}
                {activeTab === 'cancelled' && '取消的任务会显示在这里'}
              </div>
            </div>
          ) : (
                  <div className="tasks-grid" style={{ 
                    display: 'grid', 
                    gridTemplateColumns: 'repeat(auto-fill, minmax(400px, 1fr))',
                    gap: '24px'
                  }}>
              {paginatedData.map((item, index) => {
                // 如果是申请记录，需要特殊处理
                if (activeTab === 'pending') {
                  const application = item;
                  return (
                    <div key={application.id} className="application-card" style={{
                      background: '#fff',
                      borderRadius: '16px',
                      padding: '24px',
                      boxShadow: '0 4px 12px rgba(0,0,0,0.05)',
                      border: '1px solid #e2e8f0',
                      transition: 'all 0.3s ease',
                      position: 'relative',
                      overflow: 'hidden'
                    }}>
                      {/* 申请状态指示器 */}
                      <div style={{
                        position: 'absolute',
                        top: '16px',
                        right: '16px',
                        background: '#fef3c7',
                        color: '#92400e',
                        padding: '4px 12px',
                        borderRadius: '20px',
                        fontSize: '12px',
                        fontWeight: '600',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '4px'
                      }}>
                        <span>⏳</span>
                        <span>等待审核</span>
                      </div>

                      {/* 任务标题 */}
                      <h3 style={{
                        margin: '0 0 12px 0',
                        fontSize: '18px',
                        fontWeight: '600',
                        color: '#1f2937',
                        lineHeight: '1.4',
                        paddingRight: '100px'
                      }}>
                        {application.task_title}
                      </h3>

                      {/* 任务信息 */}
                      <div style={{ marginBottom: '16px' }}>
                        <div style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '8px',
                          marginBottom: '8px',
                          fontSize: '14px',
                          color: '#6b7280'
                        }}>
                          <span>💰</span>
                          <span>奖励: £{application.task_reward}</span>
                        </div>
                        <div style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '8px',
                          marginBottom: '8px',
                          fontSize: '14px',
                          color: '#6b7280'
                        }}>
                          <span>📍</span>
                          <span>{application.task_location}</span>
                        </div>
                        <div style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '8px',
                          fontSize: '14px',
                          color: '#6b7280'
                        }}>
                          <span>📅</span>
                          <span>申请时间: {dayjs(application.created_at).format('YYYY-MM-DD HH:mm')}</span>
                        </div>
                      </div>

                      {/* 申请留言 */}
                      {application.message && (
                        <div style={{
                          background: '#f8fafc',
                          padding: '12px',
                          borderRadius: '8px',
                          marginBottom: '16px',
                          border: '1px solid #e2e8f0'
                        }}>
                          <div style={{
                            fontSize: '12px',
                            color: '#64748b',
                            marginBottom: '4px',
                            fontWeight: '500'
                          }}>
                            申请留言:
                          </div>
                          <div style={{
                            fontSize: '14px',
                            color: '#374151',
                            lineHeight: '1.5'
                          }}>
                            {application.message}
                          </div>
                        </div>
                      )}

                      {/* 操作按钮 */}
                      <div style={{
                        display: 'flex',
                        gap: '8px',
                        justifyContent: 'flex-end'
                      }}>
                        <button
                          onClick={() => navigate(`/tasks/${application.task_id}`)}
                          style={{
                            padding: '8px 16px',
                            border: '1px solid #d1d5db',
                            borderRadius: '6px',
                            background: '#fff',
                            color: '#374151',
                            cursor: 'pointer',
                            fontSize: '14px',
                            fontWeight: '500',
                            transition: 'all 0.2s ease'
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.background = '#f9fafb';
                            e.currentTarget.style.borderColor = '#9ca3af';
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.background = '#fff';
                            e.currentTarget.style.borderColor = '#d1d5db';
                          }}
                        >
                          查看任务
                        </button>
                      </div>
                    </div>
                  );
                }

                // 原有的任务卡片逻辑
                const task = item;
                const isPoster = task.poster_id === user?.id;
                const isTaker = task.taker_id === user?.id;
                
                return (
                        <div key={task.id} className="task-card" style={{
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
                            <div className="task-info-grid" style={{ 
                              display: 'grid',
                              gridTemplateColumns: '1fr 1fr',
                              gap: '8px',
                              marginBottom: '12px'
                            }}>
                        <div className="task-info-item" style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <span style={{ fontSize: '14px', color: '#64748b' }}>💰</span>
                          <span style={{ fontSize: '14px', color: '#1e293b', fontWeight: '600' }}>£{task.reward}</span>
                        </div>
                        <div className="task-info-item" style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <span style={{ fontSize: '14px', color: '#64748b' }}>
                            {task.location === 'Online' ? '🌐' : '📍'}
                          </span>
                          <span style={{ 
                            fontSize: '14px', 
                            color: task.location === 'Online' ? '#2563eb' : '#1e293b',
                            fontWeight: task.location === 'Online' ? '600' : 'normal'
                          }}>
                            {task.location}
                          </span>
                        </div>
                        <div className="task-info-item" style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <span style={{ fontSize: '14px', color: '#64748b' }}>🏷️</span>
                          <span style={{ fontSize: '14px', color: '#1e293b' }}>{task.task_type}</span>
                        </div>
                        <div className="task-info-item" style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                          <span style={{ fontSize: '14px', color: '#64748b' }}>👤</span>
                          <span style={{ fontSize: '14px', color: '#1e293b' }}>
                            {isPoster ? t('myTasks.userRole.poster') : isTaker ? t('myTasks.userRole.taker') : t('myTasks.userRole.unknown')}
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
                          <div className="task-description" style={{ 
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
                          <div className="task-actions" style={{ 
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
{t('myTasks.actions.viewDetails')}
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
                          {actionLoading === task.id ? t('myTasks.actions.processing') : (task.is_public === 1 ? t('myTasks.actions.setPrivate') : t('myTasks.actions.setPublic'))}
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
                          <span>{t('myTasks.actions.waitingApproval')}</span>
                        </div>
                      )}

                      {task.status === 'in_progress' && isTaker && !completedTasks.has(task.id) && (
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
                          {actionLoading === task.id ? t('myTasks.actions.processing') : t('myTasks.actions.markComplete')}
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
                          {actionLoading === task.id ? t('myTasks.actions.processing') : t('myTasks.actions.confirmComplete')}
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
                          {actionLoading === task.id ? t('myTasks.actions.processing') : t('myTasks.actions.cancelTask')}
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
{t('myTasks.actions.contactTaker')}
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
{t('myTasks.actions.review')}
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
{showTaskReviews[task.id] ? t('myTasks.actions.hideReviews') : `${t('myTasks.actions.viewReviews')} (${taskReviews[task.id].length})`}
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
                          {actionLoading === task.id ? t('myTasks.actions.processing') : `🗑️ ${t('myTasks.actions.deleteTask')}`}
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
{t('myTasks.actions.viewReviews')}
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

                {/* 分页组件 */}
                {totalPages > 1 && (
                  <div className="pagination" style={{
                    display: 'flex',
                    justifyContent: 'center',
                    alignItems: 'center',
                    gap: '12px',
                    marginTop: '32px',
                    padding: '16px',
                    background: '#f9fafb',
                    borderRadius: '8px',
                    border: '1px solid #e5e7eb'
                  }}>
              <button
                onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                disabled={currentPage === 1}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  borderRadius: '8px',
                  background: currentPage === 1 ? '#f3f4f6' : '#3b82f6',
                  color: currentPage === 1 ? '#9ca3af' : '#fff',
                  cursor: currentPage === 1 ? 'not-allowed' : 'pointer',
                  fontSize: '14px',
                  fontWeight: '500',
                  transition: 'all 0.2s ease'
                }}
              >
                ← 上一页
              </button>
              
                    <div className="page-numbers" style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                      padding: '0 16px'
                    }}>
                {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                  const pageNum = i + 1;
                  const isActive = pageNum === currentPage;
                  return (
                    <button
                      key={pageNum}
                      onClick={() => setCurrentPage(pageNum)}
                      style={{
                        width: '32px',
                        height: '32px',
                        border: 'none',
                        borderRadius: '6px',
                        background: isActive ? '#3b82f6' : 'transparent',
                        color: isActive ? '#fff' : '#6b7280',
                        cursor: 'pointer',
                        fontSize: '14px',
                        fontWeight: '500',
                        transition: 'all 0.2s ease'
                      }}
                    >
                      {pageNum}
                    </button>
                  );
                })}
              </div>
              
              <button
                onClick={() => setCurrentPage(prev => prev + 1)}
                disabled={currentPage >= totalPages}
                style={{
                  padding: '10px 20px',
                  border: 'none',
                  borderRadius: '8px',
                  background: currentPage >= totalPages ? '#f3f4f6' : '#3b82f6',
                  color: currentPage >= totalPages ? '#9ca3af' : '#fff',
                  cursor: currentPage >= totalPages ? 'not-allowed' : 'pointer',
                  fontSize: '14px',
                  fontWeight: '500',
                  transition: 'all 0.2s ease'
                }}
              >
                下一页 →
              </button>
            </div>
          )}
        </div>
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
              <div className="review-modal" style={{
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
{t('myTasks.actions.review')}: {currentReviewTask.title}
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
{t('myTasks.reviewPlaceholder')} (可选)
              </label>
              <textarea
                value={reviewComment}
                onChange={(e) => setReviewComment(e.target.value)}
                placeholder={t('myTasks.reviewPlaceholder')}
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
{t('myTasks.actions.review')}
                </span>
                <span style={{fontSize: '12px', color: '#64748b'}}>
{t('myTasks.anonymousReviewNote')}
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
                {actionLoading === currentReviewTask.id ? t('myTasks.actions.processing') : t('myTasks.actions.review')}
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
{t('myTasks.actions.cancelTask')}
              </button>
            </div>
          </div>
        </div>
      )}
      
      {/* 通知弹窗 */}
      <NotificationPanel
        isOpen={showNotifications && !!user}
        onClose={() => setShowNotifications(false)}
        notifications={notifications}
        unreadCount={unreadCount}
        onMarkAsRead={handleMarkAsRead}
        onMarkAllRead={handleMarkAllRead}
      />
      
      {/* 任务详情弹窗 */}
      <TaskDetailModal
        isOpen={showTaskDetailModal}
        onClose={() => {
          setShowTaskDetailModal(false);
          setSelectedTaskId(null);
        }}
        taskId={selectedTaskId}
      />
      
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

      {/* 移动端响应式样式 */}
      <style>
        {`
          /* 移动端适配 */
          @media (max-width: 768px) {
            /* 顶部导航栏移动端优化 */
            header {
              padding: 8px 12px !important;
            }
            
            header > div {
              gap: 4px !important;
              min-height: 40px !important;
            }
            
            /* Logo移动端优化 */
            header > div > div:first-child {
              font-size: 20px !important;
              padding: 2px 4px !important;
            }
            
            /* 主要内容区域移动端优化 */
            .main-content {
              margin-top: 60px !important;
              padding: 20px 12px !important;
            }
            
            .main-content > div {
              border-radius: 6px !important;
            }
            
            /* 页面头部移动端优化 */
            .page-header {
              padding: 20px 16px !important;
            }
            
            .page-header h1 {
              font-size: 24px !important;
            }
            
            .page-header p {
              font-size: 14px !important;
            }
            
            /* 返回按钮移动端优化 */
            .back-button {
              position: static !important;
              margin-bottom: 16px !important;
              padding: 6px 12px !important;
              font-size: 12px !important;
            }
            
            /* 统计概览移动端优化 */
            .stats-section {
              padding: 16px !important;
            }
            
            .stats-grid {
              grid-template-columns: repeat(2, 1fr) !important;
              gap: 12px !important;
            }
            
            .stat-item {
              padding: 12px !important;
            }
            
            .stat-item > div:first-child {
              font-size: 18px !important;
            }
            
            .stat-item > div:last-child {
              font-size: 12px !important;
            }
            
            /* 标签页移动端优化 */
            .tabs-section {
              padding: 12px 16px 0 16px !important;
            }
            
            .tabs-container {
              gap: 6px !important;
              overflow-x: auto !important;
              scrollbar-width: none !important;
              -ms-overflow-style: none !important;
            }
            
            .tabs-container::-webkit-scrollbar {
              display: none !important;
            }
            
            .tab-button {
              padding: 6px 12px !important;
              font-size: 12px !important;
              white-space: nowrap !important;
              flex-shrink: 0 !important;
            }
            
            .tab-button span:last-child {
              font-size: 10px !important;
              padding: 1px 4px !important;
            }
            
            /* 任务列表移动端优化 */
            .tasks-section {
              padding: 16px !important;
            }
            
            .tasks-grid {
              grid-template-columns: 1fr !important;
              gap: 16px !important;
            }
            
            /* 任务卡片移动端优化 */
            .task-card {
              padding: 16px !important;
              border-radius: 12px !important;
            }
            
            .task-card h3 {
              font-size: 16px !important;
              margin-bottom: 6px !important;
            }
            
            .task-info-grid {
              grid-template-columns: 1fr !important;
              gap: 6px !important;
              margin-bottom: 8px !important;
            }
            
            .task-info-item {
              font-size: 12px !important;
            }
            
            .task-description {
              font-size: 13px !important;
              padding: 8px !important;
              margin-bottom: 12px !important;
            }
            
            .task-actions {
              flex-direction: column !important;
              gap: 8px !important;
              margin-top: 12px !important;
              padding-top: 12px !important;
            }
            
            .task-actions button {
              width: 100% !important;
              padding: 10px !important;
              font-size: 12px !important;
              min-width: auto !important;
            }
            
            /* 分页移动端优化 */
            .pagination {
              flex-direction: column !important;
              gap: 8px !important;
              margin-top: 24px !important;
              padding: 12px !important;
            }
            
            .pagination button {
              padding: 8px 16px !important;
              font-size: 12px !important;
            }
            
            .pagination .page-numbers {
              flex-wrap: wrap !important;
              justify-content: center !important;
              gap: 6px !important;
            }
            
            .pagination .page-numbers button {
              width: 28px !important;
              height: 28px !important;
              font-size: 12px !important;
            }
            
            /* 评价弹窗移动端优化 */
            .review-modal {
              padding: 20px !important;
              width: 95% !important;
              max-width: 400px !important;
            }
            
            .review-modal h2 {
              font-size: 20px !important;
              margin-bottom: 16px !important;
            }
            
            .review-modal label {
              font-size: 14px !important;
              margin-bottom: 8px !important;
            }
            
            .review-modal textarea {
              min-height: 80px !important;
              padding: 12px !important;
              font-size: 13px !important;
            }
            
            .review-modal button {
              padding: 12px 24px !important;
              font-size: 14px !important;
            }
            
            /* 通知弹窗移动端优化 */
            .notification-container {
              right: 10px !important;
              left: 10px !important;
              top: 70px !important;
              min-width: auto !important;
              max-width: none !important;
            }
          }
          
          /* 超小屏幕优化 */
          @media (max-width: 480px) {
            .main-content {
              padding: 16px 8px !important;
            }
            
            .page-header {
              padding: 16px 12px !important;
            }
            
            .page-header h1 {
              font-size: 20px !important;
            }
            
            .stats-grid {
              grid-template-columns: 1fr !important;
              gap: 8px !important;
            }
            
            .stat-item {
              padding: 8px !important;
            }
            
            .task-card {
              padding: 12px !important;
            }
            
            .task-card h3 {
              font-size: 14px !important;
            }
            
            .task-actions button {
              padding: 8px !important;
              font-size: 11px !important;
            }
          }
          
          /* 极小屏幕优化 */
          @media (max-width: 360px) {
            header {
              padding: 6px 8px !important;
            }
            
            .main-content {
              padding: 12px 6px !important;
            }
            
            .page-header {
              padding: 12px 8px !important;
            }
            
            .page-header h1 {
              font-size: 18px !important;
            }
            
            .task-card {
              padding: 10px !important;
            }
          }
        `}
      </style>

    </div>
  );
};

export default MyTasks;