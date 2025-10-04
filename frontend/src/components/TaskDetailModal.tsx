import React, { useEffect, useState } from 'react';
import api, { fetchCurrentUser, applyForTask, updateTaskReward, completeTask, confirmTaskCompletion, createReview, getTaskReviews, approveTaskTaker, rejectTaskTaker, sendMessage, getTaskApplications, approveApplication, getUserApplications } from '../api';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import LoginModal from './LoginModal';

// 配置dayjs插件
dayjs.extend(utc);
dayjs.extend(timezone);

interface TaskDetailModalProps {
  isOpen: boolean;
  onClose: () => void;
  taskId: number | null;
}

const TaskDetailModal: React.FC<TaskDetailModalProps> = ({ isOpen, onClose, taskId }) => {
  const [task, setTask] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [user, setUser] = useState<any>(null);
  const [showPriceEdit, setShowPriceEdit] = useState(false);
  const [newPrice, setNewPrice] = useState('');
  const [actionLoading, setActionLoading] = useState(false);
  const [showReviewModal, setShowReviewModal] = useState(false);
  const [reviewRating, setReviewRating] = useState(5);
  const [hoverRating, setHoverRating] = useState(0);
  const [reviewComment, setReviewComment] = useState('');
  const [isAnonymous, setIsAnonymous] = useState(false);
  const [reviews, setReviews] = useState<any[]>([]);
  const [showReviews, setShowReviews] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const [applications, setApplications] = useState<any[]>([]);
  const [loadingApplications, setLoadingApplications] = useState(false);
  const [userApplication, setUserApplication] = useState<any>(null);
  const [hasApplied, setHasApplied] = useState(false);

  // 当弹窗打开且taskId存在时加载任务数据
  useEffect(() => {
    if (isOpen && taskId) {
      loadTaskData();
    }
  }, [isOpen, taskId]);

  const loadTaskData = async () => {
    if (!taskId) return;
    
    console.log('任务详情弹窗加载，任务ID:', taskId);
    setLoading(true);
    setError('');
    
    try {
      const res = await api.get(`/api/tasks/${taskId}`);
      console.log('任务详情API响应:', res.data);
      setTask(res.data);
      setNewPrice(res.data.reward.toString());
      
      // 如果任务已完成，加载评价
      if (res.data.status === 'completed') {
        loadTaskReviews();
      }
    } catch (error: any) {
      console.error('获取任务详情失败:', error);
      console.error('错误详情:', error.response?.data);
      setError('任务不存在');
    } finally {
      setLoading(false);
    }
    
    // 加载用户信息
    try {
      const userData = await fetchCurrentUser();
      setUser(userData);
    } catch (error) {
      setUser(null);
    }
  };

  // 当用户信息加载后，如果是任务发布者，加载申请者列表
  useEffect(() => {
    if (user && task && task.poster_id === user.id) {
      loadApplications();
    }
  }, [user, task]);

  // 检查当前用户是否已经申请了此任务
  useEffect(() => {
    if (user && task) {
      checkUserApplication();
    }
  }, [user, task]);

  const checkUserApplication = async () => {
    if (!user || !task || user.id === task.poster_id) {
      console.log('不是申请者或没有登录，跳过申请状态检查');
      return;
    }
    
    console.log('开始检查用户申请状态...', { userId: user.id, taskId: task.id });
    try {
      const userApplications = await getUserApplications();
      console.log('用户申请记录:', userApplications);
      const userApp = userApplications.find((app: any) => app.task_id === task.id);
      console.log('当前任务的申请状态:', userApp);
      setUserApplication(userApp);
    } catch (error) {
      console.error('检查用户申请状态失败:', error);
    }
  };

  const loadTaskReviews = async () => {
    if (!taskId) return;
    
    try {
      console.log('开始加载任务评价数据，任务ID:', taskId);
      const reviewsData = await getTaskReviews(taskId);
      console.log('评价数据加载成功:', reviewsData);
      setReviews(reviewsData);
    } catch (error) {
      console.error('加载评价失败:', error);
    }
  };

  const loadApplications = async () => {
    if (!user || !task || user.id !== task.poster_id || !taskId) {
      console.log('不是任务发布者，跳过加载申请者列表');
      return;
    }
    
    console.log('开始加载申请者列表...');
    setLoadingApplications(true);
    try {
      const res = await getTaskApplications(taskId);
      console.log('申请者列表加载成功:', res);
      setApplications(res);
    } catch (error) {
      console.error('加载申请者列表失败:', error);
    } finally {
      setLoadingApplications(false);
    }
  };

  // 检查用户等级是否满足任务等级要求
  const canViewTask = (user: any, task: any) => {
    if (!task) return false;
    
    // 如果用户未登录，只能查看普通任务
    if (!user) {
      return task.task_level === 'normal';
    }
    
    const levelHierarchy = { 'normal': 1, 'vip': 2, 'super': 3 };
    const userLevelValue = levelHierarchy[user.user_level as keyof typeof levelHierarchy] || 1;
    const taskLevelValue = levelHierarchy[task.task_level as keyof typeof levelHierarchy] || 1;
    
    return userLevelValue >= taskLevelValue;
  };

  // 检查用户是否已接受任务
  const hasAcceptedTask = (user: any, task: any) => {
    return user && task && task.taker_id === user.id;
  };

  const handleApproveApplication = async (applicantId: string) => {
    if (!window.confirm('确定要批准这个申请者吗？批准后其他申请者将被自动拒绝。')) {
      return;
    }

    setActionLoading(true);
    try {
      await approveApplication(taskId!, applicantId);
      alert('申请者批准成功！');
      
      // 重新加载任务信息和申请者列表
      const res = await api.get(`/api/tasks/${taskId}`);
      setTask(res.data);
      await loadApplications();
    } catch (error: any) {
      console.error('批准申请者失败:', error);
      alert(error.response?.data?.detail || '批准申请者失败');
    } finally {
      setActionLoading(false);
    }
  };

  const handleChat = async () => {
    if (!task?.poster_id) {
      alert('无法获取发布者信息，请联系客服');
      return;
    }

    // 如果用户还没有接受任务，自动发送一条消息
    if (!hasAcceptedTask(user, task)) {
      try {
        const messageContent = `你好，我们可以聊聊"${task.title}"吗？`;
        await sendMessage({
          receiver_id: task.poster_id,
          content: messageContent
        });
        console.log('已自动发送消息:', messageContent);
      } catch (error) {
        console.error('自动发送消息失败:', error);
      }
    }

    // 关闭弹窗并跳转到消息页面
    onClose();
    window.open(`/message?uid=${task.poster_id}`, '_blank');
  };

  const handleAcceptTask = async () => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    setActionLoading(true);
    try {
      console.log('开始接受任务...', { taskId, currentStatus: task?.status });
      const result = await applyForTask(taskId!);
      console.log('接受任务API调用成功:', result);
      
      alert('任务申请成功！\n\n请等待任务发布者审核您的申请，审核通过后您就可以开始执行任务了。');
      
      // 隐藏申请按钮
      setHasApplied(true);
      
      // 重新获取任务信息
      const res = await api.get(`/api/tasks/${taskId}`);
      setTask(res.data);
    } catch (error: any) {
      console.error('接受任务失败:', error);
      
      // 重新获取任务信息以更新状态
      try {
        const res = await api.get(`/api/tasks/${taskId}`);
        setTask(res.data);
        
        if (res.data.status === 'taken' && res.data.taker_id === user.id) {
          alert('您已经接受过这个任务了！\n\n请等待任务发布者同意您接受此任务。');
        } else {
          alert(error.response?.data?.detail || '接受任务失败');
        }
      } catch (refreshError) {
        console.error('重新获取任务信息失败:', refreshError);
        alert(error.response?.data?.detail || '接受任务失败');
      }
    } finally {
      setActionLoading(false);
    }
  };

  const handleCompleteTask = async () => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    setActionLoading(true);
    try {
      await completeTask(taskId!);
      alert('任务已标记为完成，等待发布者确认！');
      const res = await api.get(`/api/tasks/${taskId}`);
      setTask(res.data);
    } catch (error: any) {
      alert(error.response?.data?.detail || '操作失败');
    } finally {
      setActionLoading(false);
    }
  };

  const handleConfirmCompletion = async () => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    setActionLoading(true);
    try {
      await confirmTaskCompletion(taskId!);
      alert('任务已确认完成！');
      const res = await api.get(`/api/tasks/${taskId}`);
      setTask(res.data);
    } catch (error: any) {
      alert(error.response?.data?.detail || '操作失败');
    } finally {
      setActionLoading(false);
    }
  };

  const handleUpdatePrice = async () => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    const price = parseFloat(newPrice);
    if (isNaN(price) || price <= 0) {
      alert('请输入有效的价格');
      return;
    }
    setActionLoading(true);
    try {
      await updateTaskReward(taskId!, price);
      alert('价格更新成功！');
      setShowPriceEdit(false);
      const res = await api.get(`/api/tasks/${taskId}`);
      setTask(res.data);
      setNewPrice(res.data.reward.toString());
    } catch (error: any) {
      alert(error.response?.data?.detail || '更新价格失败');
    } finally {
      setActionLoading(false);
    }
  };

  const handleApproveTaker = async () => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    setActionLoading(true);
    try {
      await approveTaskTaker(taskId!);
      alert('已同意接受者进行任务！');
      const res = await api.get(`/api/tasks/${taskId}`);
      setTask(res.data);
    } catch (error: any) {
      alert(error.response?.data?.detail || '操作失败');
    } finally {
      setActionLoading(false);
    }
  };

  const handleRejectTaker = async () => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    if (!window.confirm('确定要拒绝这个接受者吗？任务将重新开放给其他人。')) {
      return;
    }
    setActionLoading(true);
    try {
      await rejectTaskTaker(taskId!);
      alert('已拒绝接受者，任务重新开放！');
      const res = await api.get(`/api/tasks/${taskId}`);
      setTask(res.data);
    } catch (error: any) {
      alert(error.response?.data?.detail || '操作失败');
    } finally {
      setActionLoading(false);
    }
  };

  const handleSubmitReview = async () => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    if (reviewRating < 1 || reviewRating > 5) {
      alert('请选择有效的评分');
      return;
    }
    setActionLoading(true);
    try {
      await createReview(taskId!, reviewRating, reviewComment, isAnonymous);
      alert('评价提交成功！');
      setShowReviewModal(false);
      setReviewRating(5);
      setReviewComment('');
      setIsAnonymous(false);
      await loadTaskReviews();
    } catch (error: any) {
      alert(error.response?.data?.detail || '评价提交失败');
    } finally {
      setActionLoading(false);
    }
  };

  const canReview = () => {
    if (!user || !task) return false;
    return (task.poster_id === user.id || task.taker_id === user.id) && task.status === 'completed';
  };

  const hasUserReviewed = () => {
    if (!user) return false;
    return reviews.some(review => review.user_id === user.id);
  };

  // 如果弹窗未打开，不渲染任何内容
  if (!isOpen) return null;

  if (loading) {
    return (
      <div style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 1000,
        padding: '20px'
      }}>
        <div style={{
          backgroundColor: '#fff',
          borderRadius: '16px',
          padding: '40px',
          textAlign: 'center',
          maxWidth: '400px',
          width: '100%'
        }}>
          <div style={{ fontSize: 48, marginBottom: 20 }}>⏳</div>
          <div style={{ fontSize: 18, color: '#333' }}>加载中...</div>
        </div>
      </div>
    );
  }

  if (error || !task) {
    return (
      <div style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 1000,
        padding: '20px'
      }}>
        <div style={{
          backgroundColor: '#fff',
          borderRadius: '16px',
          padding: '40px',
          textAlign: 'center',
          maxWidth: '400px',
          width: '100%'
        }}>
          <div style={{ fontSize: 48, marginBottom: 20, color: 'red' }}>❌</div>
          <div style={{ fontSize: 18, color: 'red', marginBottom: 20 }}>{error || '任务不存在'}</div>
          <button
            onClick={onClose}
            style={{
              background: '#3b82f6',
              color: '#fff',
              border: 'none',
              borderRadius: '8px',
              padding: '12px 24px',
              fontSize: '16px',
              cursor: 'pointer'
            }}
          >
            关闭
          </button>
        </div>
      </div>
    );
  }

  const isTaskPoster = user && user.id === task.poster_id;
  const isTaskTaker = user && user.id === task.taker_id;
  const canAcceptTask = user && 
    user.id !== task.poster_id && 
    (task.status === 'open' || task.status === 'taken') && 
    canViewTask(user, task) &&
    !userApplication &&
    !hasApplied;

  const getStatusText = (status: string) => {
    switch (status) {
      case 'open': return '开放中';
      case 'taken': return '开放中';
      case 'in_progress': return '进行中';
      case 'pending_confirmation': return '待确认';
      case 'completed': return '已完成';
      case 'cancelled': return '已取消';
      default: return status;
    }
  };

  const getTaskLevelText = (level: string) => {
    switch (level) {
      case 'vip':
        return '⭐ VIP任务';
      case 'super':
        return '🔥 超级任务';
      default:
        return '普通任务';
    }
  };

  const getTaskLevelStyle = (level: string) => {
    switch (level) {
      case 'vip':
        return {
          background: 'linear-gradient(135deg, #FFD700, #FFA500)',
          color: '#8B4513',
          border: '2px solid #FFD700',
          boxShadow: '0 2px 8px rgba(255, 215, 0, 0.3)'
        };
      case 'super':
        return {
          background: 'linear-gradient(135deg, #FF6B6B, #FF4757)',
          color: '#fff',
          border: '2px solid #FF4757',
          boxShadow: '0 2px 8px rgba(255, 107, 107, 0.3)'
        };
      default:
        return {
          background: '#f8f9fa',
          color: '#6c757d',
          border: '1px solid #dee2e6'
        };
    }
  };

  // 如果用户等级不满足任务等级要求，显示权限不足页面
  if (task && !canViewTask(user, task)) {
    return (
      <div style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.5)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 1000,
        padding: '20px'
      }}>
        <div style={{
          backgroundColor: '#fff',
          borderRadius: '16px',
          padding: '40px',
          textAlign: 'center',
          maxWidth: '500px',
          width: '100%'
        }}>
          <div style={{ fontSize: 48, marginBottom: 20 }}>🔒</div>
          <h2 style={{ fontSize: 24, fontWeight: 800, color: '#A67C52', marginBottom: 16 }}>
            {!user ? '需要登录' : '权限不足'}
          </h2>
          <p style={{ fontSize: 16, color: '#666', marginBottom: 20 }}>
            {!user ? '此任务需要登录后才能查看' : `此任务需要${task.task_level === 'vip' ? 'VIP' : '超级VIP'}用户才能查看`}
          </p>
          {user && (
            <p style={{ fontSize: 14, color: '#999', marginBottom: 30 }}>
              您的当前等级：{user.user_level === 'normal' ? '普通用户' : user.user_level === 'vip' ? 'VIP用户' : '超级VIP用户'}
            </p>
          )}
          <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
            <button
              onClick={onClose}
              style={{
                background: 'linear-gradient(135deg, #A67C52, #8B4513)',
                color: '#fff',
                border: 'none',
                borderRadius: 8,
                padding: '12px 24px',
                fontSize: 16,
                fontWeight: 600,
                cursor: 'pointer'
              }}
            >
              关闭
            </button>
            {!user && (
              <button
                onClick={() => setShowLoginModal(true)}
                style={{
                  background: 'linear-gradient(135deg, #6EC1E4, #4A90E2)',
                  color: '#fff',
                  border: 'none',
                  borderRadius: 8,
                  padding: '12px 24px',
                  fontSize: 16,
                  fontWeight: 600,
                  cursor: 'pointer'
                }}
              >
                立即登录
              </button>
            )}
          </div>
        </div>
      </div>
    );
  }

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000,
      padding: '20px'
    }}>
      <div style={{
        backgroundColor: '#fff',
        borderRadius: '24px',
        boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
        maxWidth: '900px',
        width: '100%',
        maxHeight: '90vh',
        position: 'relative',
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden'
      }}>
        {/* 关闭按钮 */}
        <button
          onClick={onClose}
          style={{
            position: 'absolute',
            top: '16px',
            right: '16px',
            background: 'none',
            border: 'none',
            fontSize: '24px',
            cursor: 'pointer',
            color: '#666',
            zIndex: 10,
            width: '32px',
            height: '32px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            borderRadius: '50%',
            transition: 'background-color 0.2s'
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.backgroundColor = '#f0f0f0';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.backgroundColor = 'transparent';
          }}
        >
          ×
        </button>
        
        <div style={{
          padding: '40px',
          overflow: 'auto',
          flex: 1,
          height: 0
        }}>

        {/* 标题区域 */}
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '20px',
          marginBottom: '32px',
          flexWrap: 'wrap',
          position: 'relative',
          zIndex: 1
        }}>
          <div style={{ flex: 1 }}>
            <h2 style={{
              fontSize: '32px',
              fontWeight: '800',
              background: 'linear-gradient(135deg, #667eea, #764ba2)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              margin: '0 0 8px 0',
              lineHeight: 1.2
            }}>{task.title}</h2>
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '16px',
              flexWrap: 'wrap'
            }}>
              {/* 任务等级标签 */}
              {task.task_level && task.task_level !== 'normal' && (
                <div style={{
                  padding: '8px 16px',
                  borderRadius: '20px',
                  fontSize: '14px',
                  fontWeight: '700',
                  ...getTaskLevelStyle(task.task_level)
                }}>
                  {getTaskLevelText(task.task_level)}
                </div>
              )}
              {/* 状态标签 */}
              <div style={{
                padding: '6px 12px',
                borderRadius: '16px',
                fontSize: '12px',
                fontWeight: '600',
                background: (task.status === 'open' || task.status === 'taken') ? '#d1fae5' : 
                           task.status === 'in_progress' ? '#dbeafe' :
                           task.status === 'completed' ? '#d1fae5' : '#fee2e2',
                color: (task.status === 'open' || task.status === 'taken') ? '#065f46' : 
                       task.status === 'in_progress' ? '#1e40af' :
                       task.status === 'completed' ? '#065f46' : '#991b1b',
                border: `1px solid ${(task.status === 'open' || task.status === 'taken') ? '#a7f3d0' : 
                                   task.status === 'in_progress' ? '#93c5fd' :
                                   task.status === 'completed' ? '#a7f3d0' : '#fecaca'}`
              }}>
                {getStatusText(task.status)}
              </div>
            </div>
          </div>
        </div>

        {/* 任务信息卡片 */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: '20px',
          marginBottom: '32px',
          position: 'relative',
          zIndex: 1
        }}>
          <div style={{
            background: '#f8fafc',
            padding: '20px',
            borderRadius: '16px',
            border: '2px solid #e2e8f0',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '24px', marginBottom: '8px' }}>📋</div>
            <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>任务类型</div>
            <div style={{ fontSize: '16px', fontWeight: '600', color: '#1e293b' }}>{task.task_type}</div>
          </div>
          
          <div style={{
            background: task.location === 'Online' ? '#e6f3ff' : '#f8fafc',
            padding: '20px',
            borderRadius: '16px',
            border: task.location === 'Online' ? '2px solid #93c5fd' : '2px solid #e2e8f0',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '24px', marginBottom: '8px' }}>
              {task.location === 'Online' ? '🌐' : '📍'}
            </div>
            <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>
              {task.location === 'Online' ? '任务类型' : '所在城市'}
            </div>
            <div style={{ 
              fontSize: '16px', 
              fontWeight: '600', 
              color: task.location === 'Online' ? '#2563eb' : '#1e293b' 
            }}>
              {task.location}
            </div>
          </div>
          
          <div style={{
            background: '#f8fafc',
            padding: '20px',
            borderRadius: '16px',
            border: '2px solid #e2e8f0',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '24px', marginBottom: '8px' }}>💰</div>
            <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>任务赏金</div>
            <div style={{ fontSize: '20px', fontWeight: '700', color: '#059669' }}>£{task.reward.toFixed(2)}</div>
          </div>
          
          <div style={{
            background: '#f8fafc',
            padding: '20px',
            borderRadius: '16px',
            border: '2px solid #e2e8f0',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '24px', marginBottom: '8px' }}>⏰</div>
            <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>截止时间</div>
            <div style={{ fontSize: '16px', fontWeight: '600', color: '#1e293b' }}>
              {dayjs(task.deadline).tz('Europe/London').format('MM/DD HH:mm')} (英国时间)
            </div>
          </div>
        </div>
        
        {/* 任务描述 */}
        <div style={{
          background: '#f8fafc',
          padding: '24px',
          borderRadius: '16px',
          border: '2px solid #e2e8f0',
          marginBottom: '32px',
          position: 'relative',
          zIndex: 1
        }}>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            marginBottom: '16px'
          }}>
            <div style={{ fontSize: '20px' }}>📝</div>
            <h3 style={{
              fontSize: '18px',
              fontWeight: '600',
              color: '#1e293b',
              margin: 0
            }}>任务描述</h3>
          </div>
          <div style={{
            fontSize: '16px',
            lineHeight: 1.6,
            color: '#374151',
            whiteSpace: 'pre-wrap'
          }}>{task.description}</div>
        </div>

        {/* 价格编辑区域 */}
        {showPriceEdit && (
          <div style={{
            background: '#fef3c7',
            padding: '20px',
            borderRadius: '16px',
            border: '2px solid #f59e0b',
            marginBottom: '24px',
            position: 'relative',
            zIndex: 1
          }}>
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '12px',
              marginBottom: '16px'
            }}>
              <div style={{ fontSize: '20px' }}>💰</div>
              <h3 style={{
                fontSize: '18px',
                fontWeight: '600',
                color: '#92400e',
                margin: 0
              }}>修改赏金</h3>
            </div>
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '12px',
              flexWrap: 'wrap'
            }}>
              <input
                type="number"
                value={newPrice}
                onChange={(e) => setNewPrice(e.target.value)}
                style={{
                  border: '2px solid #f59e0b',
                  borderRadius: '12px',
                  padding: '12px 16px',
                  fontSize: '16px',
                  outline: 'none',
                  background: '#fff',
                  minWidth: '120px'
                }}
                placeholder="新价格"
              />
              <button
                onClick={handleUpdatePrice}
                disabled={actionLoading}
                style={{
                  background: actionLoading ? '#cbd5e1' : '#f59e0b',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '12px',
                  padding: '12px 20px',
                  fontSize: '14px',
                  fontWeight: '600',
                  cursor: actionLoading ? 'not-allowed' : 'pointer',
                  transition: 'all 0.3s ease'
                }}
              >
                {actionLoading ? '更新中...' : '确认修改'}
              </button>
              <button
                onClick={() => {
                  setShowPriceEdit(false);
                  setNewPrice(task.reward.toString());
                }}
                style={{
                  background: '#6b7280',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '12px',
                  padding: '12px 20px',
                  fontSize: '14px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  transition: 'all 0.3s ease'
                }}
              >
                取消
              </button>
            </div>
          </div>
        )}
        
        {/* 赏金显示区域 */}
        {!showPriceEdit && (
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            marginBottom: '24px',
            position: 'relative',
            zIndex: 1
          }}>
            <div style={{ fontSize: '20px' }}>💰</div>
            <span style={{
              fontSize: '18px',
              fontWeight: '600',
              color: '#1e293b'
            }}>赏金：</span>
            <span style={{
              fontSize: '24px',
              fontWeight: '700',
              color: '#059669'
            }}>£{task.reward.toFixed(2)}</span>
            {isTaskPoster && (task.status === 'open' || task.status === 'taken') && (
              <button
                onClick={() => setShowPriceEdit(true)}
                style={{
                  background: '#f59e0b',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '8px',
                  padding: '6px 12px',
                  fontSize: '12px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  marginLeft: '8px',
                  transition: 'all 0.3s ease'
                }}
              >
                修改
              </button>
            )}
          </div>
        )}

        {/* 其他任务信息 */}
        <div style={{
          background: '#f8fafc',
          padding: '20px',
          borderRadius: '16px',
          border: '2px solid #e2e8f0',
          marginBottom: '32px',
          position: 'relative',
          zIndex: 1
        }}>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            marginBottom: '16px'
          }}>
            <div style={{ fontSize: '20px' }}>ℹ️</div>
            <h3 style={{
              fontSize: '18px',
              fontWeight: '600',
              color: '#1e293b',
              margin: 0
            }}>任务详情</h3>
          </div>
          
          <div style={{
            display: 'grid',
            gap: '12px'
          }}>
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              fontSize: '14px'
            }}>
              <span style={{ color: '#64748b', minWidth: '80px' }}>截止时间：</span>
              <span style={{ color: '#1e293b', fontWeight: '500' }}>
                {task.deadline && dayjs(task.deadline).tz('Europe/London').format('YYYY/MM/DD HH:mm:ss')} (英国时间)
              </span>
            </div>
            
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              fontSize: '14px'
            }}>
              <span style={{ color: '#64748b', minWidth: '80px' }}>任务等级：</span>
              <span style={{ color: '#1e293b', fontWeight: '500' }}>
                {getTaskLevelText(task.task_level || 'normal')}
              </span>
            </div>
            
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              fontSize: '14px'
            }}>
              <span style={{ color: '#64748b', minWidth: '80px' }}>可见性：</span>
              <span style={{
                color: task.is_public === 1 ? '#059669' : '#dc2626',
                fontWeight: '600',
                padding: '2px 8px',
                borderRadius: '8px',
                background: task.is_public === 1 ? '#d1fae5' : '#fee2e2',
                border: `1px solid ${task.is_public === 1 ? '#a7f3d0' : '#fecaca'}`
              }}>
                {task.is_public === 1 ? '🌍 公开显示' : '🔒 仅自己可见'}
              </span>
            </div>
            
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              fontSize: '14px'
            }}>
              <span style={{ color: '#64748b', minWidth: '80px' }}>发布者：</span>
              <span style={{ color: '#1e293b', fontWeight: '500' }}>
                {task.poster_id}
                {task.poster_id && (
                  <span style={{ marginLeft: '8px', fontSize: '12px', color: '#6b7280' }}>
                    (点击下方按钮进行沟通)
                  </span>
                )}
              </span>
            </div>
          </div>
        </div>
        
        {/* 操作按钮区域 */}
        <div style={{
          display: 'flex',
          gap: '16px',
          flexWrap: 'wrap',
          justifyContent: 'center',
          position: 'relative',
          zIndex: 1
        }}>
          {canAcceptTask && (
            <button
              onClick={handleAcceptTask}
              disabled={actionLoading}
              style={{
                background: actionLoading 
                  ? 'linear-gradient(135deg, #cbd5e1, #94a3b8)' 
                  : 'linear-gradient(135deg, #10b981, #059669)',
                color: '#fff',
                border: 'none',
                borderRadius: '16px',
                padding: '16px 32px',
                fontWeight: '700',
                fontSize: '16px',
                cursor: actionLoading ? 'not-allowed' : 'pointer',
                transition: 'all 0.3s ease',
                boxShadow: actionLoading 
                  ? '0 4px 12px rgba(0,0,0,0.1)' 
                  : '0 8px 24px rgba(16, 185, 129, 0.3)',
                display: 'flex',
                alignItems: 'center',
                gap: '8px'
              }}
              onMouseEnter={(e) => {
                if (!actionLoading) {
                  e.currentTarget.style.transform = 'translateY(-2px)';
                  e.currentTarget.style.boxShadow = '0 12px 32px rgba(16, 185, 129, 0.4)';
                }
              }}
              onMouseLeave={(e) => {
                if (!actionLoading) {
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 8px 24px rgba(16, 185, 129, 0.3)';
                }
              }}
            >
              {actionLoading ? (
                <>
                  <span>⏳</span>
                  处理中...
                </>
              ) : (
                <>
                  <span>✅</span>
                  申请任务
                </>
              )}
            </button>
          )}

          {/* 显示申请状态 */}
          {user && user.id !== task.poster_id && userApplication && (
            <div style={{
              background: userApplication.status === 'pending' 
                ? 'linear-gradient(135deg, #fef3c7, #fde68a)' 
                : userApplication.status === 'approved'
                ? (task.status === 'pending_confirmation' 
                    ? 'linear-gradient(135deg, #e0e7ff, #c7d2fe)'
                    : 'linear-gradient(135deg, #d1fae5, #a7f3d0)')
                : 'linear-gradient(135deg, #fee2e2, #fecaca)',
              border: userApplication.status === 'pending'
                ? '2px solid #f59e0b'
                : userApplication.status === 'approved'
                ? (task.status === 'pending_confirmation' 
                    ? '2px solid #6366f1'
                    : '2px solid #10b981')
                : '2px solid #ef4444',
              borderRadius: '16px',
              padding: '20px 24px',
              color: userApplication.status === 'pending'
                ? '#92400e'
                : userApplication.status === 'approved'
                ? (task.status === 'pending_confirmation' 
                    ? '#3730a3'
                    : '#065f46')
                : '#991b1b',
              fontSize: '16px',
              fontWeight: '600',
              display: 'flex',
              alignItems: 'center',
              gap: '16px',
              maxWidth: '600px',
              margin: '0 auto',
              boxShadow: userApplication.status === 'pending'
                ? '0 4px 12px rgba(245, 158, 11, 0.2)'
                : userApplication.status === 'approved'
                ? (task.status === 'pending_confirmation'
                    ? '0 4px 12px rgba(99, 102, 241, 0.2)'
                    : '0 4px 12px rgba(16, 185, 129, 0.2)')
                : '0 4px 12px rgba(239, 68, 68, 0.2)'
            }}>
              <div style={{fontSize: '32px'}}>
                {userApplication.status === 'pending' ? '⏳' : 
                 userApplication.status === 'approved' ? 
                   (task.status === 'pending_confirmation' ? '⏰' : '✅') : '❌'}
              </div>
              <div>
                <div style={{fontWeight: 'bold', marginBottom: '8px', fontSize: '18px'}}>
                  {userApplication.status === 'pending' ? '等待发布者审核' :
                   userApplication.status === 'approved' ? 
                     (task.status === 'pending_confirmation' ? '任务已完成' : '申请已通过') : 
                   '申请被拒绝'}
                </div>
                <div style={{fontSize: '14px', fontWeight: 'normal', lineHeight: 1.5}}>
                  {userApplication.status === 'pending' ? '您已成功申请此任务，请等待任务发布者审核您的申请。' :
                   userApplication.status === 'approved' ? 
                     (task.status === 'pending_confirmation' ? 
                       '恭喜！您已完成任务，请等待发布者确认任务完成。' : 
                       '恭喜！您的申请已通过，现在可以开始执行任务了。') :
                   '很抱歉，您的申请被拒绝了。'}
                </div>
                {userApplication.message && (
                  <div style={{fontSize: '12px', marginTop: '8px', fontStyle: 'italic'}}>
                    申请留言：{userApplication.message}
                  </div>
                )}
              </div>
            </div>
          )}

          {/* 兼容旧的显示逻辑 */}
          {task.status === 'taken' && isTaskTaker && !userApplication && (
            <div style={{
              background: 'linear-gradient(135deg, #fef3c7, #fde68a)',
              border: '2px solid #f59e0b',
              borderRadius: '16px',
              padding: '20px 24px',
              color: '#92400e',
              fontSize: '16px',
              fontWeight: '600',
              display: 'flex',
              alignItems: 'center',
              gap: '16px',
              maxWidth: '600px',
              margin: '0 auto',
              boxShadow: '0 4px 12px rgba(245, 158, 11, 0.2)'
            }}>
              <div style={{fontSize: '32px'}}>⏳</div>
              <div>
                <div style={{fontWeight: 'bold', marginBottom: '8px', fontSize: '18px'}}>
                  等待发布者同意
                </div>
                <div style={{fontSize: '14px', fontWeight: 'normal', lineHeight: 1.5}}>
                  您已成功接受此任务，请等待任务发布者同意后即可开始执行。
                </div>
              </div>
            </div>
          )}

          {/* 申请者列表 - 仅任务发布者可见 */}
          {isTaskPoster && (task.status === 'taken' || task.status === 'open') && (
            <div style={{
              marginTop: '20px',
              padding: '20px',
              background: '#f8f9fa',
              borderRadius: '12px',
              border: '1px solid #e9ecef'
            }}>
              <h3 style={{ margin: '0 0 16px 0', color: '#333', fontSize: '18px' }}>
                申请者列表 ({applications.length})
              </h3>
              
              {loadingApplications ? (
                <div style={{ textAlign: 'center', padding: '20px' }}>
                  加载中...
                </div>
              ) : applications.length === 0 ? (
                <div style={{ 
                  textAlign: 'center', 
                  padding: '20px', 
                  color: '#666',
                  background: '#fff',
                  borderRadius: '8px',
                  border: '1px solid #e9ecef'
                }}>
                  暂无申请者
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  {applications.map((app) => (
                    <div key={app.id} style={{
                      background: '#fff',
                      padding: '16px',
                      borderRadius: '8px',
                      border: '1px solid #e9ecef',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center'
                    }}>
                      <div>
                        <div style={{ fontWeight: '600', color: '#333', marginBottom: '4px' }}>
                          {app.applicant_name}
                        </div>
                        {app.message && (
                          <div style={{ color: '#666', fontSize: '14px', marginBottom: '4px' }}>
                            "{app.message}"
                          </div>
                        )}
                        <div style={{ color: '#999', fontSize: '12px' }}>
                          申请时间: {new Date(app.created_at).toLocaleString()}
                        </div>
                      </div>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <button
                          onClick={() => window.open(`/message?uid=${app.applicant_id}`, '_blank')}
                          style={{
                            background: '#007bff',
                            color: '#fff',
                            border: 'none',
                            borderRadius: '6px',
                            padding: '8px 16px',
                            fontWeight: '600',
                            cursor: 'pointer',
                            fontSize: '14px'
                          }}
                        >
                          联系
                        </button>
                        <button
                          onClick={() => handleApproveApplication(app.applicant_id)}
                          disabled={actionLoading}
                          style={{
                            background: '#28a745',
                            color: '#fff',
                            border: 'none',
                            borderRadius: '6px',
                            padding: '8px 16px',
                            fontWeight: '600',
                            cursor: actionLoading ? 'not-allowed' : 'pointer',
                            opacity: actionLoading ? 0.6 : 1,
                            fontSize: '14px'
                          }}
                        >
                          {actionLoading ? '处理中...' : '批准'}
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* 其他操作按钮 */}
          {task.status === 'in_progress' && isTaskTaker && (
            <button
              onClick={handleCompleteTask}
              disabled={actionLoading}
              style={{
                background: '#28a745',
                color: '#fff',
                border: 'none',
                borderRadius: 8,
                padding: '10px 32px',
                fontWeight: 700,
                fontSize: 18,
                cursor: actionLoading ? 'not-allowed' : 'pointer',
                opacity: actionLoading ? 0.6 : 1
              }}
            >
              {actionLoading ? '处理中...' : '标记完成'}
            </button>
          )}

          {/* 任务进行中时，发布者可以联系接收者 */}
          {task.status === 'in_progress' && isTaskPoster && task.taker_id && (
            <button
              onClick={() => window.open(`/message?uid=${task.taker_id}`, '_blank')}
              style={{
                background: '#007bff',
                color: '#fff',
                border: 'none',
                borderRadius: 8,
                padding: '10px 32px',
                fontWeight: 700,
                fontSize: 18,
                cursor: 'pointer',
                marginRight: '16px'
              }}
            >
              💬 联系接收者
            </button>
          )}

          {task.status === 'pending_confirmation' && isTaskPoster && (
            <button
              onClick={handleConfirmCompletion}
              disabled={actionLoading}
              style={{
                background: '#28a745',
                color: '#fff',
                border: 'none',
                borderRadius: 8,
                padding: '10px 32px',
                fontWeight: 700,
                fontSize: 18,
                cursor: actionLoading ? 'not-allowed' : 'pointer',
                opacity: actionLoading ? 0.6 : 1
              }}
            >
              {actionLoading ? '处理中...' : '确认完成'}
            </button>
          )}
          
          {user && user.id !== task.poster_id && canViewTask(user, task) && (
            <button
              onClick={handleChat}
              style={{
                background: '#A67C52',
                color: '#fff',
                border: 'none',
                borderRadius: 8,
                padding: '10px 32px',
                fontWeight: 700,
                fontSize: 18,
                cursor: 'pointer'
              }}
              title="点击联系任务发布者进行沟通"
            >
              联系发布者
            </button>
          )}

          {/* 评价按钮 */}
          {canReview() && !hasUserReviewed() && (
            <button
              onClick={() => setShowReviewModal(true)}
              style={{
                background: '#ffc107',
                color: '#000',
                border: 'none',
                borderRadius: 8,
                padding: '10px 32px',
                fontWeight: 700,
                fontSize: 18,
                cursor: 'pointer'
              }}
            >
              ⭐ 评价任务
            </button>
          )}
        </div>

        {/* 评价弹窗 */}
        {showReviewModal && (
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
            zIndex: 1001
          }}>
            <div style={{
              background: '#fff',
              borderRadius: 16,
              padding: 32,
              maxWidth: 500,
              width: '90%',
              maxHeight: '80vh',
              overflow: 'auto'
            }}>
              <h2 style={{marginBottom: 24, color: '#A67C52', textAlign: 'center'}}>评价任务</h2>
              
              <div style={{marginBottom: 20}}>
                <label style={{display: 'block', marginBottom: 8, fontWeight: 600, color: '#333'}}>
                  评分 (0.5-5星)
                </label>
                <div style={{display: 'flex', gap: 4, justifyContent: 'center', alignItems: 'center'}}>
                  {[0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5].map(star => (
                    <button
                      key={star}
                      onClick={() => setReviewRating(star)}
                      onMouseEnter={() => setHoverRating(star)}
                      onMouseLeave={() => setHoverRating(0)}
                      style={{
                        background: 'none',
                        border: 'none',
                        fontSize: star % 1 === 0 ? 24 : 18,
                        cursor: 'pointer',
                        color: star <= (hoverRating || reviewRating) ? '#ffc107' : '#ddd',
                        transition: 'all 0.3s ease',
                        padding: '2px',
                        transform: star <= (hoverRating || reviewRating) ? 'scale(1.2)' : 'scale(1)',
                        filter: star <= (hoverRating || reviewRating) ? 'drop-shadow(0 0 8px rgba(255, 193, 7, 0.6))' : 'none'
                      }}
                    >
                      {star <= (hoverRating || reviewRating) ? '⭐' : '☆'}
                    </button>
                  ))}
                </div>
                <div style={{
                  textAlign: 'center', 
                  marginTop: 8, 
                  color: '#666', 
                  fontSize: 14,
                  fontWeight: 600,
                  opacity: reviewRating > 0 ? 1 : 0.7,
                  transform: reviewRating > 0 ? 'scale(1.05)' : 'scale(1)',
                  transition: 'all 0.3s ease'
                }}>
                  当前评分: {reviewRating} 星
                </div>
              </div>

              <div style={{marginBottom: 24}}>
                <label style={{display: 'block', marginBottom: 8, fontWeight: 600, color: '#333'}}>
                  评价内容 (可选)
                </label>
                <textarea
                  value={reviewComment}
                  onChange={(e) => setReviewComment(e.target.value)}
                  placeholder="请分享您对这次任务的体验..."
                  style={{
                    width: '100%',
                    minHeight: 100,
                    padding: 12,
                    border: '1px solid #ddd',
                    borderRadius: 8,
                    fontSize: 14,
                    resize: 'vertical'
                  }}
                />
              </div>

              <div style={{marginBottom: 24}}>
                <label style={{display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer'}}>
                  <input
                    type="checkbox"
                    checked={isAnonymous}
                    onChange={(e) => setIsAnonymous(e.target.checked)}
                    style={{transform: 'scale(1.2)'}}
                  />
                  <span style={{fontWeight: 600, color: '#333'}}>
                    匿名评价
                  </span>
                  <span style={{fontSize: 12, color: '#666'}}>
                    (选择匿名后，您的评价将不会显示您的身份信息)
                  </span>
                </label>
              </div>

              <div style={{display: 'flex', gap: 12, justifyContent: 'center'}}>
                <button
                  onClick={handleSubmitReview}
                  disabled={actionLoading}
                  style={{
                    background: '#28a745',
                    color: '#fff',
                    border: 'none',
                    borderRadius: 8,
                    padding: '12px 24px',
                    fontWeight: 600,
                    fontSize: 16,
                    cursor: actionLoading ? 'not-allowed' : 'pointer',
                    opacity: actionLoading ? 0.6 : 1
                  }}
                >
                  {actionLoading ? '提交中...' : '提交评价'}
                </button>
                <button
                  onClick={() => {
                    setShowReviewModal(false);
                    setReviewRating(5);
                    setReviewComment('');
                    setIsAnonymous(false);
                  }}
                  style={{
                    background: '#6c757d',
                    color: '#fff',
                    border: 'none',
                    borderRadius: 8,
                    padding: '12px 24px',
                    fontWeight: 600,
                    fontSize: 16,
                    cursor: 'pointer'
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
          onClose={() => setShowLoginModal(false)}
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
      </div>
    </div>
  );
};

export default TaskDetailModal;
