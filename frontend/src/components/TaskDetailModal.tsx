import React, { useEffect, useState } from 'react';
import api, { fetchCurrentUser, applyForTask, completeTask, confirmTaskCompletion, createReview, getTaskReviews, approveTaskTaker, rejectTaskTaker, getTaskApplications, acceptApplication, rejectApplication, getUserApplications } from '../api';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import { TimeHandlerV2 } from '../utils/timeUtils';
import LoginModal from './LoginModal';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { useTranslation } from '../hooks/useTranslation';

// 配置dayjs插件
dayjs.extend(utc);
dayjs.extend(timezone);

interface TaskDetailModalProps {
  isOpen: boolean;
  onClose: () => void;
  taskId: number | null;
}

const TaskDetailModal: React.FC<TaskDetailModalProps> = ({ isOpen, onClose, taskId }) => {
  const { t, language } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const { translate } = useTranslation();
  const [task, setTask] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [user, setUser] = useState<any>(null);
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
  const [enlargedImage, setEnlargedImage] = useState<string | null>(null);
  const [currentImageIndex, setCurrentImageIndex] = useState<number>(0);
  // 申请任务弹窗状态
  const [showApplyModal, setShowApplyModal] = useState(false);
  const [applyMessage, setApplyMessage] = useState('');
  const [negotiatedPrice, setNegotiatedPrice] = useState<number | undefined>();
  const [isNegotiateChecked, setIsNegotiateChecked] = useState(false);
  // 翻译相关状态
  const [translatedTitle, setTranslatedTitle] = useState<string | null>(null);
  const [translatedDescription, setTranslatedDescription] = useState<string | null>(null);
  const [isTranslatingTitle, setIsTranslatingTitle] = useState(false);
  const [isTranslatingDescription, setIsTranslatingDescription] = useState(false);

  // 当弹窗打开且taskId存在时加载任务数据
  useEffect(() => {
    if (isOpen && taskId) {
      loadTaskData();
    }
  }, [isOpen, taskId]);

  // 键盘事件处理（用于图片放大弹窗）
  useEffect(() => {
    if (!enlargedImage || !task || !task.images) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setEnlargedImage(null);
      } else if (e.key === 'ArrowLeft' && currentImageIndex > 0) {
        const prevIndex = currentImageIndex - 1;
        setCurrentImageIndex(prevIndex);
        setEnlargedImage(task.images[prevIndex]);
      } else if (e.key === 'ArrowRight' && currentImageIndex < task.images.length - 1) {
        const nextIndex = currentImageIndex + 1;
        setCurrentImageIndex(nextIndex);
        setEnlargedImage(task.images[nextIndex]);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [enlargedImage, task, currentImageIndex]);

  const loadTaskData = async () => {
    if (!taskId) return;
    
    setLoading(true);
    setError('');
    
    try {
      const res = await api.get(`/api/tasks/${taskId}`);
      setTask(res.data);
      
      // 如果任务已完成，加载评价
      if (res.data.status === 'completed') {
        loadTaskReviews();
      }
    } catch (error: any) {
      console.error('获取任务详情失败:', error);
      console.error('错误详情:', error.response?.data);
      setError(t('taskDetail.taskNotFound'));
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
      return;
    }
    
    try {
      const userApplications = await getUserApplications();
      const userApp = userApplications.find((app: any) => app.task_id === task.id);
      setUserApplication(userApp);
    } catch (error) {
      console.error('检查用户申请状态失败:', error);
    }
  };

  const loadTaskReviews = async () => {
    if (!taskId) return;
    
    try {
      const reviewsData = await getTaskReviews(taskId);
      setReviews(reviewsData);
    } catch (error) {
      console.error('加载评价失败:', error);
    }
  };

  const loadApplications = async () => {
    if (!user || !task || user.id !== task.poster_id || !taskId) {
      return;
    }
    
    setLoadingApplications(true);
    try {
      const res = await getTaskApplications(taskId);
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
    
    // 任务发布者可以查看自己发布的所有任务，无论任务等级如何
    if (user.id === task.poster_id) {
      return true;
    }
    
    // 任务接受者可以查看自己接受的任务，无论任务等级如何
    if (user.id === task.taker_id) {
      return true;
    }
    
    // 其他用户需要满足等级要求
    const levelHierarchy = { 'normal': 1, 'vip': 2, 'super': 3 };
    const userLevelValue = levelHierarchy[user.user_level as keyof typeof levelHierarchy] || 1;
    const taskLevelValue = levelHierarchy[task.task_level as keyof typeof levelHierarchy] || 1;
    
    return userLevelValue >= taskLevelValue;
  };

  // 检查用户是否已接受任务
  const hasAcceptedTask = (user: any, task: any) => {
    return user && task && task.taker_id === user.id;
  };

  // 当任务加载或语言改变时,重置翻译
  useEffect(() => {
    setTranslatedTitle(null);
    setTranslatedDescription(null);
  }, [task, language]);

  const handleApproveApplication = async (applicationId: number) => {
    if (!window.confirm(t('taskDetail.confirmApprove'))) {
      return;
    }

    setActionLoading(true);
    try {
      await acceptApplication(taskId!, applicationId);
      alert(t('taskDetail.approveSuccess'));
      
      // 重新加载任务信息和申请者列表
      const res = await api.get(`/api/tasks/${taskId}`);
      setTask(res.data);
      await loadApplications();
    } catch (error: any) {
      console.error('批准申请者失败:', error);
      alert(error.response?.data?.detail || t('taskDetail.approveFailed'));
    } finally {
      setActionLoading(false);
    }
  };

  const handleRejectApplication = async (applicationId: number) => {
    if (!window.confirm(t('taskDetail.confirmRejectApplication'))) {
      return;
    }

    setActionLoading(true);
    try {
      await rejectApplication(taskId!, applicationId);
      alert(t('taskDetail.rejectApplicationSuccess'));
      
      // 重新加载申请者列表
      await loadApplications();
    } catch (error: any) {
      console.error('拒绝申请者失败:', error);
      alert(error.response?.data?.detail || t('taskDetail.rejectApplicationFailed'));
    } finally {
      setActionLoading(false);
    }
  };

  const handleAcceptTask = () => {
    if (!user) {
      setShowLoginModal(true);
      return;
    }
    
    // 显示申请弹窗
    // 重置议价相关状态
    setNegotiatedPrice(undefined);
    setIsNegotiateChecked(false);
    setShowApplyModal(true);
    setApplyMessage('');
  };
  
  // 提交申请
  const handleSubmitApplication = async () => {
    if (!taskId) return;
    
    // 验证议价金额：如果勾选了议价，金额必须大于0
    if (isNegotiateChecked && (negotiatedPrice === undefined || negotiatedPrice === null || negotiatedPrice <= 0)) {
      alert('如果选择议价，请输入大于0的议价金额');
      return;
    }
    
    if (!task) return;
    
    const currency = task?.currency || 'GBP';
    const baseReward = task?.base_reward ?? task?.reward ?? 0;
    
    // 如果没有勾选议价或输入框为空，则不发送议价金额（保持原本金额）
    const finalNegotiatedPrice = (isNegotiateChecked && negotiatedPrice !== undefined && negotiatedPrice !== null && negotiatedPrice > 0) 
      ? negotiatedPrice 
      : undefined;
    
    // 如果议价金额小于原本金额，提示用户确认
    if (finalNegotiatedPrice !== undefined && finalNegotiatedPrice < baseReward) {
      const confirmed = window.confirm(
        `您输入的议价金额（£${finalNegotiatedPrice.toFixed(2)}）低于任务原本金额（£${baseReward.toFixed(2)}）。\n\n` +
        `这将降低您获得的金额。是否确定要继续？`
      );
      if (!confirmed) {
        return;
      }
    }
    
    setActionLoading(true);
    try {
      
      await applyForTask(
        taskId,
        applyMessage || undefined,
        finalNegotiatedPrice,
        currency
      );
      
      alert(t('taskDetail.taskApplySuccess'));
      
      // 隐藏申请按钮
      setHasApplied(true);
      
      // 关闭弹窗
      setShowApplyModal(false);
      setApplyMessage('');
      setNegotiatedPrice(undefined);
      setIsNegotiateChecked(false);
      
      // 重新获取任务信息
      const res = await api.get(`/api/tasks/${taskId}`);
      setTask(res.data);
    } catch (error: any) {
      console.error('申请任务失败:', error);
      
      // 重新获取任务信息以更新状态
      try {
        const res = await api.get(`/api/tasks/${taskId}`);
        setTask(res.data);
        
        // 检查是否已经申请过
        alert(error.response?.data?.detail || t('taskDetail.taskApplyFailed'));
      } catch (refreshError) {
        console.error('重新获取任务信息失败:', refreshError);
        alert(error.response?.data?.detail || t('taskDetail.taskApplyFailed'));
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
      alert(t('taskDetail.taskMarkedComplete'));
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
      alert(t('taskDetail.taskConfirmedComplete'));
      const res = await api.get(`/api/tasks/${taskId}`);
      setTask(res.data);
    } catch (error: any) {
      alert(error.response?.data?.detail || '操作失败');
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
      alert(t('taskDetail.takerApproved'));
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
    if (!window.confirm(t('taskDetail.confirmReject'))) {
      return;
    }
    setActionLoading(true);
    try {
      await rejectTaskTaker(taskId!);
      alert(t('taskDetail.rejectSuccess'));
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
      alert(t('taskDetail.selectValidRating'));
      return;
    }
    setActionLoading(true);
    try {
      await createReview(taskId!, reviewRating, reviewComment, isAnonymous);
      alert(t('taskDetail.reviewSubmitted'));
      setShowReviewModal(false);
      setReviewRating(5);
      setReviewComment('');
      setIsAnonymous(false);
      
      // 重新加载评价数据和任务数据
      await loadTaskReviews();
      
      // 强制重新检查用户申请状态和刷新任务状态
      if (user && task) {
        await checkUserApplication();
      }
      
      // 重新加载任务信息，确保状态更新
      if (taskId) {
        await loadTaskData();
      }
      
    } catch (error: any) {
      alert(error.response?.data?.detail || t('taskDetail.reviewSubmitFailed'));
    } finally {
      setActionLoading(false);
    }
  };

  const canReview = () => {
    if (!user || !task) return false;
    return (task.poster_id === user.id || task.taker_id === user.id) && task.status === 'completed';
  };

  const hasUserReviewed = () => {
    if (!user || !task) {
      return false;
    }
    // 直接从 reviews 数组中查找当前用户的评价
    const userReview = reviews.find(review => review.user_id === user.id);
    const hasReviewed = !!userReview;
    return hasReviewed;
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
          <div style={{ fontSize: 18, color: '#333' }}>{t('taskDetail.loading')}</div>
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
          <div style={{ fontSize: 18, color: 'red', marginBottom: 20 }}>{error || t('taskDetail.taskNotFound')}</div>
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
            {t('taskDetail.close')}
          </button>
        </div>
      </div>
    );
  }

  const isTaskPoster = user && user.id === task.poster_id;
  const isTaskTaker = user && user.id === task.taker_id;
  // 是否可以显示申请按钮（包括未登录用户）
  const canShowApplyButton = (task.status === 'open' || task.status === 'taken') && 
    canViewTask(user, task) &&
    (!user || user.id !== task.poster_id) && // 未登录或不是发布者
    !userApplication && // 如果已经申请过，不能再次申请
    !hasApplied; // 如果已经申请过，隐藏按钮

  // 是否可以申请任务（需要登录）
  const canAcceptTask = user && 
    user.id !== task.poster_id && 
    (task.status === 'open' || task.status === 'taken') && 
    canViewTask(user, task) &&
    !userApplication &&
    !hasApplied;

  // 判断是否应该对非相关用户隐藏真实状态（显示为open）
  const shouldHideStatus = () => {
    if (!task || !user) return false;
    const isPoster = task.poster_id === user.id;
    const isTaker = task.taker_id === user.id;
    const isApplicant = hasApplied || userApplication;
    
    // 如果用户不是发布者、接收者或申请者，且状态是taken，应显示为open
    if (!isPoster && !isTaker && !isApplicant && task.status === 'taken') {
      return true;
    }
    return false;
  };

  const getStatusText = (status: string) => {
    // 对非相关用户，taken状态显示为open
    if (shouldHideStatus()) {
      status = 'open';
    }
    
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

  // 翻译标题
  const handleTranslateTitle = async () => {
    if (!task || !task.title) {
      console.log('翻译标题: 任务或标题不存在');
      return;
    }
    
    // 如果已有翻译，重置为原文
    if (translatedTitle) {
      console.log('翻译标题: 重置为原文');
      setTranslatedTitle(null);
      return;
    }
    
    console.log('翻译标题: 开始翻译', { title: task.title, language, task });
    setIsTranslatingTitle(true);
    try {
      // 检测文本语言，然后翻译成当前界面语言
      const textLang = detectTextLanguage(task.title);
      // 如果文本语言和界面语言相同，不需要翻译（这不应该发生，因为按钮应该只在needsTranslation时显示）
      if (textLang === language) {
        console.log('翻译标题: 文本语言和界面语言相同，无需翻译');
        setTranslatedTitle(null);
        return;
      }
      // 目标语言就是当前界面语言（这样用户就能看到自己语言版本的文本）
      const targetLang = language;
      console.log('翻译标题: 调用translate函数', { title: task.title, textLang, targetLang });
      const translated = await translate(task.title, targetLang, textLang);
      console.log('翻译标题: 翻译成功', { original: task.title, translated });
      setTranslatedTitle(translated);
    } catch (error: any) {
      console.error('翻译标题失败:', error);
      console.error('错误详情:', error.response?.data);
      alert('翻译失败: ' + (error.response?.data?.detail || error.message || '未知错误'));
    } finally {
      setIsTranslatingTitle(false);
    }
  };

  // 翻译描述
  const handleTranslateDescription = async () => {
    if (!task || !task.description) {
      console.log('翻译描述: 任务或描述不存在');
      return;
    }
    
    // 如果已有翻译，重置为原文
    if (translatedDescription) {
      console.log('翻译描述: 重置为原文');
      setTranslatedDescription(null);
      return;
    }
    
    console.log('翻译描述: 开始翻译', { description: task.description.substring(0, 50), language });
    setIsTranslatingDescription(true);
    try {
      // 检测文本语言，然后翻译成当前界面语言
      const textLang = detectTextLanguage(task.description);
      // 如果文本语言和界面语言相同，不需要翻译（这不应该发生，因为按钮应该只在needsTranslation时显示）
      if (textLang === language) {
        console.log('翻译描述: 文本语言和界面语言相同，无需翻译');
        setTranslatedDescription(null);
        return;
      }
      // 目标语言就是当前界面语言（这样用户就能看到自己语言版本的文本）
      const targetLang = language;
      console.log('翻译描述: 调用translate函数', { textLang, targetLang });
      const translated = await translate(task.description, targetLang, textLang);
      console.log('翻译描述: 翻译成功', { translated: translated.substring(0, 50) });
      setTranslatedDescription(translated);
    } catch (error: any) {
      console.error('翻译描述失败:', error);
      console.error('错误详情:', error.response?.data);
      alert('翻译失败: ' + (error.response?.data?.detail || error.message || '未知错误'));
    } finally {
      setIsTranslatingDescription(false);
    }
  };

  // 简单的语言检测：检查是否包含中文字符
  const detectTextLanguage = (text: string): 'zh' | 'en' => {
    if (!text || !text.trim()) return 'en';
    const hasChinese = /[\u4e00-\u9fff]/.test(text);
    return hasChinese ? 'zh' : 'en';
  };

  // 检查是否需要翻译（文本语言和界面语言不同时需要翻译）
  const needsTranslation = (text: string): boolean => {
    const detectedLang = detectTextLanguage(text);
    return detectedLang !== language;
  };

  // 重置翻译(显示原文)
  const handleResetTranslation = (type: 'title' | 'description') => {
    if (type === 'title') {
      setTranslatedTitle(null);
    } else {
      setTranslatedDescription(null);
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
            {!user ? t('taskDetail.loginRequired') : t('taskDetail.insufficientPermissions')}
          </h2>
          <p style={{ fontSize: 16, color: '#666', marginBottom: 20 }}>
            {!user ? t('taskDetail.loginToView') : t('taskDetail.upgradeRequired').replace('{level}', task.task_level === 'vip' ? 'VIP' : '超级VIP')}
          </p>
          {user && (
            <p style={{ fontSize: 14, color: '#999', marginBottom: 30 }}>
              {t('taskDetail.currentLevel').replace('{level}', user.user_level === 'normal' ? '普通用户' : user.user_level === 'vip' ? 'VIP用户' : '超级VIP用户')}
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
              {t('taskDetail.close')}
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
                {t('taskDetail.loginNow')}
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
        {/* 关闭按钮和分享按钮 */}
        <div style={{
          position: 'absolute',
          top: '16px',
          right: '16px',
          display: 'flex',
          gap: '8px',
          zIndex: 10
        }}>
          {/* 分享按钮 */}
          <button
            onClick={async () => {
              if (taskId && task) {
                // 构建分享URL（使用当前语言）
                const basePath = `/${language}/tasks/${taskId}`;
                const shareUrl = `${window.location.origin}${basePath}`;
                const shareTitle = `${task.title} - Link²Ur任务平台`;
                const displayReward = task.agreed_reward ?? task.base_reward ?? task.reward ?? 0;
                const shareText = `${task.title}\n\n${task.description.substring(0, 100)}${task.description.length > 100 ? '...' : ''}\n\n任务类型: ${task.task_type}\n地点: ${task.location}\n金额: ${displayReward.toFixed(2)} ${task.currency || 'CNY'}\n\n立即查看: ${shareUrl}`;
                
                // 先尝试使用Web Share API（需要在用户交互上下文中）
                if (navigator.share) {
                  try {
                    await navigator.share({
                      title: shareTitle,
                      text: shareText,
                      url: shareUrl
                    });
                    // 分享成功后关闭弹窗并跳转
                    onClose();
                    navigate(`/tasks/${taskId}`);
                    return;
                  } catch (error: any) {
                    // 如果用户取消分享，不做任何操作
                    if (error.name === 'AbortError') {
                      return;
                    }
                    // 如果出错，继续执行跳转逻辑
                    console.log('分享失败，跳转到详情页:', error);
                  }
                }
                
                // 如果Web Share API不可用或失败，先关闭弹窗，然后跳转到详情页
                onClose();
                navigate(`/tasks/${taskId}?share=true`);
              } else if (taskId) {
                // 如果任务数据还没加载，先跳转到详情页再触发分享
                onClose();
                navigate(`/tasks/${taskId}?share=true`);
              }
            }}
            style={{
              background: 'linear-gradient(135deg, #667eea, #764ba2)',
              border: 'none',
              fontSize: '20px',
              cursor: 'pointer',
              color: '#fff',
              width: '40px',
              height: '40px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              borderRadius: '50%',
              transition: 'all 0.2s',
              boxShadow: '0 2px 8px rgba(102, 126, 234, 0.3)'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'scale(1.1)';
              e.currentTarget.style.boxShadow = '0 4px 12px rgba(102, 126, 234, 0.5)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'scale(1)';
              e.currentTarget.style.boxShadow = '0 2px 8px rgba(102, 126, 234, 0.3)';
            }}
            title={t('taskDetail.shareTask') || '分享任务'}
          >
            📤
          </button>
          {/* 关闭按钮 */}
          <button
            onClick={onClose}
            style={{
              background: 'none',
              border: 'none',
              fontSize: '24px',
              cursor: 'pointer',
              color: '#666',
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
        </div>
        
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
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '8px', flexWrap: 'wrap' }}>
              <h2 style={{
                fontSize: '32px',
                fontWeight: '800',
                background: 'linear-gradient(135deg, #667eea, #764ba2)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                margin: 0,
                lineHeight: 1.2,
                flex: 1,
                minWidth: '200px'
              }}>
                {translatedTitle || task.title}
              </h2>
              <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                {translatedTitle ? (
                  <button
                    onClick={() => handleResetTranslation('title')}
                    disabled={isTranslatingTitle}
                    style={{
                      background: '#ef4444',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '8px',
                      padding: '8px 12px',
                      fontSize: '12px',
                      fontWeight: '600',
                      cursor: isTranslatingTitle ? 'not-allowed' : 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      opacity: isTranslatingTitle ? 0.6 : 1
                    }}
                    title={t('taskDetail.showOriginal')}
                  >
                    🔄 {t('taskDetail.showOriginal')}
                  </button>
                ) : needsTranslation(task.title) ? (
                  <button
                    onClick={handleTranslateTitle}
                    disabled={isTranslatingTitle}
                    style={{
                      background: '#3b82f6',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '8px',
                      padding: '8px 12px',
                      fontSize: '12px',
                      fontWeight: '600',
                      cursor: isTranslatingTitle ? 'not-allowed' : 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      opacity: isTranslatingTitle ? 0.6 : 1
                    }}
                    title={t('taskDetail.translateTitle')}
                  >
                    {isTranslatingTitle ? '⏳' : '🌐'} {t('taskDetail.translateTitle')}
                  </button>
                ) : null}
              </div>
            </div>
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
                background: shouldHideStatus() ? '#d1fae5' :
                           (task.status === 'open' || task.status === 'taken') ? '#d1fae5' : 
                           task.status === 'in_progress' ? '#dbeafe' :
                           task.status === 'completed' ? '#d1fae5' : '#fee2e2',
                color: shouldHideStatus() ? '#065f46' :
                       (task.status === 'open' || task.status === 'taken') ? '#065f46' : 
                       task.status === 'in_progress' ? '#1e40af' :
                       task.status === 'completed' ? '#065f46' : '#991b1b',
                border: `1px solid ${shouldHideStatus() ? '#a7f3d0' :
                                   (task.status === 'open' || task.status === 'taken') ? '#a7f3d0' : 
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
            <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>{t('taskDetail.taskTypeLabel')}</div>
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
              {task.location === 'Online' ? t('taskDetail.onlineTaskMethod') : t('taskDetail.offlineLocation')}
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
            <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>{t('taskDetail.rewardLabel')}</div>
            <div style={{ fontSize: '20px', fontWeight: '700', color: '#059669' }}>
              {(task.agreed_reward ?? task.base_reward ?? task.reward ?? 0).toFixed(2)} {task.currency || 'CNY'}
            </div>
            {task.agreed_reward && task.agreed_reward !== task.base_reward && (
              <div style={{ fontSize: '12px', color: '#6b7280', marginTop: '4px' }}>
                原价: {task.base_reward?.toFixed(2) || '0.00'} {task.currency || 'CNY'}
              </div>
            )}
          </div>
          
          <div style={{
            background: '#f8fafc',
            padding: '20px',
            borderRadius: '16px',
            border: '2px solid #e2e8f0',
            textAlign: 'center'
          }}>
            <div style={{ fontSize: '24px', marginBottom: '8px' }}>⏰</div>
            <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>{t('taskDetail.deadlineLabel')}</div>
            <div style={{ fontSize: '16px', fontWeight: '600', color: '#1e293b' }}>
              {TimeHandlerV2.formatUtcToLocal(task.deadline, 'MM/DD HH:mm', 'Europe/London')} {t('taskDetail.ukTime')}
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
            justifyContent: 'space-between',
            gap: '12px',
            marginBottom: '16px'
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <div style={{ fontSize: '20px' }}>📝</div>
              <h3 style={{
                fontSize: '18px',
                fontWeight: '600',
                color: '#1e293b',
                margin: 0
              }}>{t('taskDetail.descriptionLabel')}</h3>
            </div>
            <div>
              {translatedDescription ? (
                <button
                  onClick={() => handleResetTranslation('description')}
                  disabled={isTranslatingDescription}
                  style={{
                    background: '#ef4444',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '8px',
                    padding: '6px 12px',
                    fontSize: '12px',
                    fontWeight: '600',
                    cursor: isTranslatingDescription ? 'not-allowed' : 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    opacity: isTranslatingDescription ? 0.6 : 1
                  }}
                  title={t('taskDetail.showOriginal')}
                >
                  🔄 {t('taskDetail.showOriginal')}
                </button>
              ) : needsTranslation(task.description) ? (
                <button
                  onClick={handleTranslateDescription}
                  disabled={isTranslatingDescription}
                  style={{
                    background: '#3b82f6',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '8px',
                    padding: '6px 12px',
                    fontSize: '12px',
                    fontWeight: '600',
                    cursor: isTranslatingDescription ? 'not-allowed' : 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    opacity: isTranslatingDescription ? 0.6 : 1
                  }}
                  title={t('taskDetail.translateDescription')}
                >
                  {isTranslatingDescription ? '⏳' : '🌐'} {t('taskDetail.translateDescription')}
                </button>
              ) : null}
            </div>
          </div>
          <div style={{
            fontSize: '16px',
            lineHeight: 1.6,
            color: '#374151',
            whiteSpace: 'pre-wrap'
          }}>{translatedDescription || task.description}</div>
        </div>
        {/* 任务图片 */}
        {task.images && Array.isArray(task.images) && task.images.length > 0 && (
          <div style={{
            marginTop: '24px',
            padding: '20px',
            background: '#f8f9fa',
            borderRadius: '12px'
          }}>
            <h3 style={{
              fontSize: '18px',
              fontWeight: '700',
              marginBottom: '16px',
              color: '#1f2937'
            }}>📷 {t('taskDetail.imagesLabel') || '任务图片'}</h3>
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))',
              gap: '12px'
            }}>
              {task.images.map((imageUrl: string, index: number) => (
                <div
                  key={index}
                  style={{
                    position: 'relative',
                    borderRadius: '8px',
                    overflow: 'hidden',
                    aspectRatio: '1',
                    background: '#e5e7eb',
                    border: '1px solid #d1d5db',
                    cursor: 'pointer',
                    transition: 'transform 0.2s ease'
                  }}
                  onClick={() => {
                    // 点击图片放大查看
                    setEnlargedImage(imageUrl);
                    setCurrentImageIndex(index);
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.transform = 'scale(1.02)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.transform = 'scale(1)';
                  }}
                >
                  <img
                    src={imageUrl}
                    alt={`任务图片 ${index + 1}`}
                    style={{
                      width: '100%',
                      height: '100%',
                      objectFit: 'cover',
                      display: 'block'
                    }}
                    loading="lazy"
                    onError={(e) => {
                      // 图片加载失败时显示占位符（使用 data URI 或隐藏图片）
                      e.currentTarget.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iI2U1ZTdlYiIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IiM5Y2EzYWYiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGR5PSIuM2VtIj7lm77niYfliqDovb3lpLHotKU8L3RleHQ+PC9zdmc+';
                      e.currentTarget.onerror = null; // 防止无限循环
                    }}
                  />
                </div>
              ))}
            </div>
          </div>
        )}

        {/* 金额显示区域 */}
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
            }}>{t('taskDetail.rewardDisplay')}</span>
            <span style={{
              fontSize: '24px',
              fontWeight: '700',
              color: '#059669'
            }}>
              {(task.agreed_reward ?? task.base_reward ?? task.reward ?? 0).toFixed(2)} {task.currency || 'CNY'}
            </span>
            {task.agreed_reward && task.agreed_reward !== task.base_reward && (
              <span style={{
                fontSize: '14px',
                color: '#6b7280',
                marginLeft: '8px',
                textDecoration: 'line-through'
              }}>
                原价: {(task.base_reward ?? 0).toFixed(2)} {task.currency || 'CNY'}
              </span>
            )}
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
          {canShowApplyButton && (
            <button
              onClick={handleAcceptTask}
              disabled={actionLoading && user}
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
                  {t('taskDetail.processing')}
                </>
              ) : (
                <>
                  <span>✅</span>
                  {t('taskDetail.applyTaskButton')}
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
                  {userApplication.status === 'pending' ? t('taskDetail.waitingApproval') :
                   userApplication.status === 'approved' ? 
                     (task.status === 'completed' ? t('taskDetail.taskCompleted') : 
                      task.status === 'pending_confirmation' ? (isTaskTaker ? t('taskDetail.taskCompleted') : t('taskDetail.waitingConfirmation')) : 
                      t('taskDetail.applicationPassed')) : 
                   t('taskDetail.applicationRejected')}
                </div>
                <div style={{fontSize: '14px', fontWeight: 'normal', lineHeight: 1.5}}>
                  {userApplication.status === 'pending' ? t('taskDetail.waitingApprovalDesc') :
                   userApplication.status === 'approved' ? 
                     (task.status === 'completed' ? 
                       (canReview() && !hasUserReviewed() ? t('taskDetail.completedNeedReview') : t('taskDetail.taskCompletedDesc')) :
                      task.status === 'pending_confirmation' ? 
                       (isTaskTaker ? t('taskDetail.taskCompletedDesc') : t('taskDetail.waitingConfirmationDesc')) : 
                       t('taskDetail.applicationPassedDesc')) :
                   t('taskDetail.applicationRejectedDesc')}
                </div>
                {userApplication.message && (
                  <div style={{fontSize: '12px', marginTop: '8px', fontStyle: 'italic'}}>
                    {t('taskDetail.applicationMessage')}{userApplication.message}
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
                  {t('taskDetail.waitingPublisherApproval')}
                </div>
                <div style={{fontSize: '14px', fontWeight: 'normal', lineHeight: 1.5}}>
                  {t('taskDetail.waitingApprovalDescOld')}
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
                {t('taskDetail.applicantList').replace('{count}', applications.length.toString())}
              </h3>
              
              {loadingApplications ? (
                <div style={{ textAlign: 'center', padding: '20px' }}>
                  {t('taskDetail.loadingApplicants')}
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
                  {t('taskDetail.noApplicants')}
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
                        {(app.negotiated_price !== undefined && app.negotiated_price !== null) && (
                          <div style={{
                            fontSize: '13px',
                            fontWeight: 600,
                            color: '#92400e',
                            padding: '4px 8px',
                            background: '#fef3c7',
                            borderRadius: '4px',
                            display: 'inline-block',
                            marginBottom: '4px',
                            marginTop: '4px'
                          }}>
                            议价: {app.negotiated_price} {app.currency || 'GBP'}
                          </div>
                        )}
                        <div style={{ color: '#999', fontSize: '12px' }}>
                          {t('taskDetail.applicationTime')}: {TimeHandlerV2.formatUtcToLocal(app.created_at)}
                        </div>
                      </div>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <button
                          onClick={() => handleApproveApplication(app.id)}
                          disabled={actionLoading || app.status !== 'pending'}
                          style={{
                            background: app.status !== 'pending' ? '#6c757d' : '#28a745',
                            color: '#fff',
                            border: 'none',
                            borderRadius: '6px',
                            padding: '8px 16px',
                            fontWeight: '600',
                            cursor: (actionLoading || app.status !== 'pending') ? 'not-allowed' : 'pointer',
                            opacity: (actionLoading || app.status !== 'pending') ? 0.6 : 1,
                            fontSize: '14px'
                          }}
                        >
                          {actionLoading ? t('taskDetail.processing') : t('taskDetail.approve')}
                        </button>
                        <button
                          onClick={() => handleRejectApplication(app.id)}
                          disabled={actionLoading || app.status !== 'pending'}
                          style={{
                            background: app.status !== 'pending' ? '#6c757d' : '#dc3545',
                            color: '#fff',
                            border: 'none',
                            borderRadius: '6px',
                            padding: '8px 16px',
                            fontWeight: '600',
                            cursor: (actionLoading || app.status !== 'pending') ? 'not-allowed' : 'pointer',
                            opacity: (actionLoading || app.status !== 'pending') ? 0.6 : 1,
                            fontSize: '14px'
                          }}
                        >
                          {actionLoading ? t('taskDetail.processing') : t('taskDetail.reject')}
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
              {actionLoading ? t('taskDetail.processing') : t('taskDetail.markCompleteButton')}
            </button>
          )}

          {/* 任务进行中时，发布者可以联系接收者 */}
          {task.status === 'in_progress' && isTaskPoster && task.taker_id && (
            <button
              onClick={() => taskId && navigate(`/message?taskId=${taskId}`)}
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
              💬 {t('taskDetail.contactTaker')}
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
              {actionLoading ? t('taskDetail.processing') : t('taskDetail.confirmCompleteButton')}
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
              ⭐ {t('taskDetail.reviewTaskButton')}
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
              <h2 style={{marginBottom: 24, color: '#A67C52', textAlign: 'center'}}>{t('taskDetail.reviewModal.title')}</h2>
              
              <div style={{marginBottom: 20}}>
                <label style={{display: 'block', marginBottom: 8, fontWeight: 600, color: '#333'}}>
                  {t('taskDetail.reviewModal.ratingLabel')}
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
                  {t('taskDetail.reviewModal.currentRating').replace('{rating}', reviewRating.toString())}
                </div>
              </div>

              <div style={{marginBottom: 24}}>
                <label style={{display: 'block', marginBottom: 8, fontWeight: 600, color: '#333'}}>
                  {t('taskDetail.reviewModal.commentLabel')}
                </label>
                <textarea
                  value={reviewComment}
                  onChange={(e) => setReviewComment(e.target.value)}
                  placeholder={t('taskDetail.reviewModal.commentPlaceholder')}
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
                    {t('taskDetail.reviewModal.anonymousLabel')}
                  </span>
                  <span style={{fontSize: 12, color: '#666'}}>
                    {t('taskDetail.reviewModal.anonymousNote')}
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
                  {actionLoading ? t('taskDetail.reviewModal.submitting') : t('taskDetail.reviewModal.submit')}
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
                  {t('taskDetail.reviewModal.cancel')}
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

        {/* 申请任务弹窗 */}
        {showApplyModal && taskId && (
          <div style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0, 0, 0, 0.5)',
            zIndex: 10000,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '20px'
          }}
          onClick={() => {
            setShowApplyModal(false);
            setApplyMessage('');
            setNegotiatedPrice(undefined);
            setIsNegotiateChecked(false);
          }}
          >
            <div style={{
              background: '#fff',
              borderRadius: '16px',
              padding: '24px',
              maxWidth: '500px',
              width: '100%',
              maxHeight: '90vh',
              overflowY: 'auto',
              boxShadow: '0 20px 60px rgba(0,0,0,0.3)'
            }}
            onClick={(e) => e.stopPropagation()}
            >
              <h3 style={{ margin: '0 0 20px 0', fontSize: '20px', fontWeight: 600 }}>申请任务</h3>
              
              <div style={{ marginBottom: '20px' }}>
                <label style={{
                  display: 'block',
                  marginBottom: '8px',
                  fontSize: '14px',
                  fontWeight: 600,
                  color: '#374151'
                }}>
                  申请留言（可选）
                </label>
                <textarea
                  value={applyMessage}
                  onChange={(e) => setApplyMessage(e.target.value)}
                  placeholder="请输入申请留言..."
                  style={{
                    width: '100%',
                    minHeight: '100px',
                    padding: '12px',
                    border: '2px solid #e5e7eb',
                    borderRadius: '8px',
                    fontSize: '14px',
                    fontFamily: 'inherit',
                    resize: 'vertical',
                    outline: 'none',
                    transition: 'border-color 0.2s ease'
                  }}
                  onFocus={(e) => {
                    e.currentTarget.style.borderColor = '#3b82f6';
                  }}
                  onBlur={(e) => {
                    e.currentTarget.style.borderColor = '#e5e7eb';
                  }}
                />
              </div>

              <div style={{ marginBottom: '20px' }}>
                <label style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  fontSize: '14px',
                  fontWeight: 600,
                  color: '#374151',
                  cursor: 'pointer'
                }}>
                  <input
                    type="checkbox"
                    checked={isNegotiateChecked}
                    onChange={(e) => {
                      setIsNegotiateChecked(e.target.checked);
                      if (e.target.checked) {
                        // 如果勾选，设置默认值为任务金额
                        const defaultPrice = task?.agreed_reward ?? task?.base_reward ?? task?.reward;
                        setNegotiatedPrice(defaultPrice);
                      } else {
                        setNegotiatedPrice(undefined);
                      }
                    }}
                    style={{ width: '18px', height: '18px', cursor: 'pointer' }}
                  />
                  <span>我想议价</span>
                </label>
                
                {isNegotiateChecked && (
                <div style={{ marginTop: '12px' }}>
                  <label style={{
                    display: 'block',
                    marginBottom: '8px',
                    fontSize: '14px',
                    fontWeight: 600,
                    color: '#374151'
                  }}>
                    议价金额
                  </label>
                  <input
                    type="number"
                    value={negotiatedPrice !== undefined ? negotiatedPrice : ''}
                    onChange={(e) => {
                      const value = e.target.value ? parseFloat(e.target.value) : undefined;
                      setNegotiatedPrice(value);
                    }}
                    placeholder="请输入议价金额（必须大于0）"
                    min="0.01"
                    step="0.01"
                    style={{
                      width: '100%',
                      padding: '12px',
                      border: '2px solid #e5e7eb',
                      borderRadius: '8px',
                      fontSize: '14px',
                      outline: 'none',
                      transition: 'border-color 0.2s ease'
                    }}
                    onFocus={(e) => {
                      e.currentTarget.style.borderColor = '#3b82f6';
                    }}
                    onBlur={(e) => {
                      e.currentTarget.style.borderColor = '#e5e7eb';
                    }}
                  />
                </div>
                )}
              </div>

              <div style={{
                display: 'flex',
                gap: '12px',
                justifyContent: 'flex-end'
              }}>
                <button
                  onClick={() => {
                    setShowApplyModal(false);
                    setApplyMessage('');
                    setNegotiatedPrice(undefined);
                    setIsNegotiateChecked(false);
                  }}
                  style={{
                    padding: '12px 24px',
                    background: '#f3f4f6',
                    color: '#374151',
                    border: 'none',
                    borderRadius: '8px',
                    fontSize: '14px',
                    fontWeight: 600,
                    cursor: 'pointer',
                    transition: 'all 0.2s ease'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.background = '#e5e7eb';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.background = '#f3f4f6';
                  }}
                >
                  取消
                </button>
                <button
                  onClick={handleSubmitApplication}
                  disabled={actionLoading}
                  style={{
                    padding: '12px 24px',
                    background: actionLoading ? '#9ca3af' : 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '8px',
                    fontSize: '14px',
                    fontWeight: 600,
                    cursor: actionLoading ? 'not-allowed' : 'pointer',
                    transition: 'all 0.2s ease'
                  }}
                  onMouseEnter={(e) => {
                    if (!actionLoading) {
                      e.currentTarget.style.transform = 'translateY(-1px)';
                      e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.3)';
                    }
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.transform = 'translateY(0)';
                    e.currentTarget.style.boxShadow = 'none';
                  }}
                >
                  {actionLoading ? '提交中...' : '提交申请'}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* 图片放大弹窗 */}
        {enlargedImage && task && task.images && (
          <div
            style={{
              position: 'fixed',
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              backgroundColor: 'rgba(0, 0, 0, 0.9)',
              zIndex: 2000,
              display: 'flex',
              justifyContent: 'center',
              alignItems: 'center',
              cursor: 'pointer'
            }}
            onClick={() => setEnlargedImage(null)}
          >
            {/* 关闭按钮 */}
            <button
              onClick={(e) => {
                e.stopPropagation();
                setEnlargedImage(null);
              }}
              style={{
                position: 'absolute',
                top: '20px',
                right: '20px',
                width: '40px',
                height: '40px',
                borderRadius: '50%',
                border: 'none',
                backgroundColor: 'rgba(255, 255, 255, 0.9)',
                color: '#000',
                fontSize: '24px',
                cursor: 'pointer',
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                zIndex: 2001,
                transition: 'all 0.2s ease'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 1)';
                e.currentTarget.style.transform = 'scale(1.1)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.9)';
                e.currentTarget.style.transform = 'scale(1)';
              }}
            >
              ×
            </button>

            {/* 上一张按钮 */}
            {task.images.length > 1 && currentImageIndex > 0 && (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  const prevIndex = currentImageIndex - 1;
                  setCurrentImageIndex(prevIndex);
                  setEnlargedImage(task.images[prevIndex]);
                }}
                style={{
                  position: 'absolute',
                  left: '20px',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  width: '50px',
                  height: '50px',
                  borderRadius: '50%',
                  border: 'none',
                  backgroundColor: 'rgba(255, 255, 255, 0.9)',
                  color: '#000',
                  fontSize: '24px',
                  cursor: 'pointer',
                  display: 'flex',
                  justifyContent: 'center',
                  alignItems: 'center',
                  zIndex: 2001,
                  transition: 'all 0.2s ease'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 1)';
                  e.currentTarget.style.transform = 'translateY(-50%) scale(1.1)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.9)';
                  e.currentTarget.style.transform = 'translateY(-50%) scale(1)';
                }}
              >
                ‹
              </button>
            )}

            {/* 下一张按钮 */}
            {task.images.length > 1 && currentImageIndex < task.images.length - 1 && (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  const nextIndex = currentImageIndex + 1;
                  setCurrentImageIndex(nextIndex);
                  setEnlargedImage(task.images[nextIndex]);
                }}
                style={{
                  position: 'absolute',
                  right: '20px',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  width: '50px',
                  height: '50px',
                  borderRadius: '50%',
                  border: 'none',
                  backgroundColor: 'rgba(255, 255, 255, 0.9)',
                  color: '#000',
                  fontSize: '24px',
                  cursor: 'pointer',
                  display: 'flex',
                  justifyContent: 'center',
                  alignItems: 'center',
                  zIndex: 2001,
                  transition: 'all 0.2s ease'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 1)';
                  e.currentTarget.style.transform = 'translateY(-50%) scale(1.1)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.backgroundColor = 'rgba(255, 255, 255, 0.9)';
                  e.currentTarget.style.transform = 'translateY(-50%) scale(1)';
                }}
              >
                ›
              </button>
            )}

            {/* 图片索引指示器 */}
            {task.images.length > 1 && (
              <div
                style={{
                  position: 'absolute',
                  bottom: '20px',
                  left: '50%',
                  transform: 'translateX(-50%)',
                  color: '#fff',
                  fontSize: '16px',
                  backgroundColor: 'rgba(0, 0, 0, 0.5)',
                  padding: '8px 16px',
                  borderRadius: '20px',
                  zIndex: 2001
                }}
              >
                {currentImageIndex + 1} / {task.images.length}
              </div>
            )}

            {/* 放大的图片 */}
            <img
              src={enlargedImage}
              alt="放大图片"
              onClick={(e) => e.stopPropagation()}
              style={{
                maxWidth: '90%',
                maxHeight: '90%',
                objectFit: 'contain',
                borderRadius: '8px',
                userSelect: 'none'
              }}
              onError={(e) => {
                // 图片加载失败时显示占位符（使用 data URI）
                e.currentTarget.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iI2U1ZTdlYiIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTQiIGZpbGw9IiM5Y2EzYWYiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGR5PSIuM2VtIj7lm77niYfliqDovb3lpLHotKU8L3RleHQ+PC9zdmc+';
                e.currentTarget.onerror = null;
              }}
            />
          </div>
        )}
        </div>
      </div>
    </div>
  );
};

export default TaskDetailModal;
