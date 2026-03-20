import React, { useEffect, useState, useCallback } from 'react';
import { message, Modal } from 'antd';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { useUnreadMessages } from '../contexts/UnreadMessageContext';
import { fetchCurrentUser, completeTask, cancelTask, confirmTaskCompletion, createReview, getTaskReviews, updateTaskVisibility, deleteTask, getNotificationsWithRecentRead, getUnreadNotificationCount, markNotificationRead, markAllNotificationsRead, getPublicSystemSettings, logout, getUserApplications, getTaskApplications, requestExitFromTask, getTaskParticipants } from '../api';
import WebSocketManager from '../utils/WebSocketManager';
import { WS_BASE_URL } from '../config';
import api from '../api';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';
import { TimeHandlerV2 } from '../utils/timeUtils';
import LoginModal from '../components/LoginModal';
import TaskDetailModal from '../components/TaskDetailModal';
import HamburgerMenu from '../components/HamburgerMenu';
import NotificationButton from '../components/NotificationButton';
import NotificationPanel from '../components/NotificationPanel';
import LazyImage from '../components/LazyImage';
import { getErrorMessage } from '../utils/errorHandler';
import { obfuscateLocation } from '../utils/formatUtils';
import SEOHead from '../components/SEOHead';
import styles from './MyTasks.module.css';

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
  is_multi_participant?: boolean;
  time_slot_start_datetime?: string;
  time_slot_end_datetime?: string;
  time_slot_id?: number;
}

interface Notification {
  id: number;
  content: string;
  is_read: number;
  created_at: string;
  type?: string;
}

const MyTasks: React.FC = () => {
  const { t, language } = useLanguage();
  const { navigate } = useLocalizedNavigation();
  const { unreadCount: messageUnreadCount } = useUnreadMessages();
  
  
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
  const [selectedTags, setSelectedTags] = useState<string[]>([]);
  const [taskReviews, setTaskReviews] = useState<{[key: number]: any[]}>({});
  const [showTaskReviews, setShowTaskReviews] = useState<{[key: number]: boolean}>({});
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  
  // 分页相关状态
  const [currentPage, setCurrentPage] = useState(1);
  const [pageSize] = useState(12);
  const [, setTotalTasks] = useState(0);
  
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
  void loadingApplications;
  // 任务申请信息（taskId -> applications数组）
  const [taskApplicationsMap, setTaskApplicationsMap] = useState<{[key: number]: any[]}>({});
  
  // 已操作任务状态
  const [completedTasks, setCompletedTasks] = useState<Set<number>>(new Set());
  
  // 已提交取消审核的任务
  const [pendingCancelTasks, setPendingCancelTasks] = useState<Set<number>>(new Set());
  
  // 多人任务参与者信息（taskId -> participant）
  const [taskParticipants, setTaskParticipants] = useState<{[key: number]: any}>({});
  
  // 任务详情弹窗状态
  const [showTaskDetailModal, setShowTaskDetailModal] = useState(false);
  const [selectedTaskId, setSelectedTaskId] = useState<number | null>(null);

  useEffect(() => {
    // 直接获取用户信息，HttpOnly Cookie会自动发送
    fetchCurrentUser().then(setUser).catch(() => {
      setUser(null);
      setShowLoginModal(true);
    });
  }, []);

  useEffect(() => {
    if (user) {
      loadTasks();
      loadNotificationsAndSettings();
      loadUserApplications();
    }
  }, [user]);

  // 页面重新获得焦点时刷新任务列表
  useEffect(() => {
    const handleFocus = () => {
      if (user) {
        loadTasks(true); // 强制刷新
      }
    };

    window.addEventListener('focus', handleFocus);
    return () => window.removeEventListener('focus', handleFocus);
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
        setUnreadCount(unreadCountData);
        setSystemSettings(settingsData);
      } catch (error) {
              }
    }
  };

  // 定期更新未读通知数量
  useEffect(() => {
    if (user) {
      const interval = setInterval(() => {
        // 只在页面可见时才更新
        if (!document.hidden) {
          getUnreadNotificationCount().then(count => {
            setUnreadCount(count);
          }).catch(() => {});
        }
      }, 30000); // 每30秒更新一次
      return () => clearInterval(interval);
    }
    return;
  }, [user]);

  // 当通知面板打开时，定期刷新通知列表
  useEffect(() => {
    if (showNotifications && user) {
      // 打开时立即刷新一次
      const loadNotificationsList = async () => {
        try {
          const notificationsData = await getNotificationsWithRecentRead(10);
          setNotifications(notificationsData);
        } catch {
        }
      };
      loadNotificationsList();
      
      // 每10秒刷新一次通知列表（比未读数量刷新更频繁）
      const interval = setInterval(() => {
        if (!document.hidden) {
          loadNotificationsList();
        }
      }, 10000);
      
      return () => clearInterval(interval);
    }
    return;
  }, [showNotifications, user]);

  // WebSocket实时更新通知（监听notification_created事件）
  useEffect(() => {
    if (!user) return;

    // 初始化WebSocket管理器
    WebSocketManager.initialize(WS_BASE_URL);
    WebSocketManager.connect(user.id);

    // 订阅WebSocket消息
    const unsubscribe = WebSocketManager.subscribe((msg) => {
      // 处理通知创建事件
      if (msg.type === 'notification_created') {
        // 立即刷新未读通知数量
        getUnreadNotificationCount().then(count => {
          setUnreadCount(count);
        }).catch(() => {
        });

        // 如果通知面板已打开，刷新通知列表
        if (showNotifications) {
          getNotificationsWithRecentRead(10).then(notificationsData => {
            setNotifications(notificationsData);
          }).catch(() => {
          });
        }
      }
    });

    return () => {
      unsubscribe();
      // 注意：不断开连接，因为可能其他组件也在使用
    };
  }, [user, showNotifications]);

  // 加载用户的申请记录
  const loadUserApplications = async () => {
    if (!user) return;
    
    setLoadingApplications(true);
    try {
      const applicationsData = await getUserApplications();
      setApplications(applicationsData);
    } catch (error) {
          } finally {
      setLoadingApplications(false);
    }
  };

  const loadTasks = async (forceRefresh = false) => {
    setLoading(true);
    try {
      // 如果需要强制刷新，添加时间戳参数
      const response = forceRefresh 
        ? await api.get('/api/users/my-tasks', { 
            params: { _t: Date.now() } 
          })
        : await api.get('/api/users/my-tasks');
      
      // 确保返回的数据是数组格式
      let tasksData = response.data;
      if (!Array.isArray(tasksData)) {
                // 尝试从可能的嵌套结构中提取数组
        if (tasksData && Array.isArray(tasksData.tasks)) {
          tasksData = tasksData.tasks;
        } else if (tasksData && Array.isArray(tasksData.data)) {
          tasksData = tasksData.data;
        } else {
                    tasksData = [];
        }
      }
        
      setTasks(tasksData);
      setTotalTasks(tasksData.length);
      
      // 性能优化：并行加载评价和申请信息，不阻塞主任务列表显示
      const completedTasks = tasksData.filter((task: Task) => task.status === 'completed');
      const postedOpenTasks = user ? tasksData.filter((task: Task) => 
        task.poster_id === user.id && task.status === 'open'
      ) : [];
      
      // 获取多人任务的参与者信息
      const multiParticipantTasks = user ? tasksData.filter((task: any) => 
        task.is_multi_participant && task.poster_id !== user.id
      ) : [];
      
      // 并行加载所有非关键数据
      Promise.all([
        // 并行加载所有已完成任务的评价
        ...completedTasks.map((task: Task) => 
          loadTaskReviews(task.id).catch(() => {}) // 静默处理错误
        ),
        // 并行加载所有open任务的申请信息
        ...postedOpenTasks.map(async (task: Task) => {
          try {
            const apps = await getTaskApplications(task.id);
            return { taskId: task.id, applications: apps.applications || apps || [] };
          } catch (error) {
            return { taskId: task.id, applications: [] };
          }
        }),
        // 并行加载多人任务的参与者信息
        ...multiParticipantTasks.map(async (task: any) => {
          try {
            const participantsData = await getTaskParticipants(task.id);
            const userPart = participantsData.participants?.find((p: any) => p.user_id === user?.id);
            return { taskId: task.id, participant: userPart || null };
          } catch (error) {
            return { taskId: task.id, participant: null };
          }
        })
      ]).then(results => {
        // 处理申请信息结果
        const applicationsMap: {[key: number]: any[]} = {};
        const participantsMap: {[key: number]: any} = {};
        results.forEach(result => {
          if (result && 'taskId' in result) {
            if ('applications' in result) {
              applicationsMap[result.taskId] = result.applications;
            } else if ('participant' in result && result.participant) {
              participantsMap[result.taskId] = result.participant;
            }
          }
        });
        if (Object.keys(applicationsMap).length > 0) {
          setTaskApplicationsMap(applicationsMap);
        }
        if (Object.keys(participantsMap).length > 0) {
          setTaskParticipants(prev => ({ ...prev, ...participantsMap }));
        }
      }).catch(() => {
        // 静默处理错误
      });
    } catch (error: any) {
            // 显示错误信息给用户
      if (error.response) {
                message.error(getErrorMessage(error));
      } else if (error.request) {
                message.error('网络错误，请检查网络连接');
      } else {
                message.error('加载任务失败，请刷新页面重试');
      }
      // 设置空数组，避免显示错误
      setTasks([]);
      setTotalTasks(0);
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
    } catch (error) {
            // 可以添加用户提示，比如toast通知
      message.error(t('myTasks.alerts.markReadFailed'));
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
    } catch (error) {
            // 可以添加用户提示，比如toast通知
      message.error(t('myTasks.alerts.markAllReadFailed'));
    }
  };

  const handleCompleteTask = async (taskId: number) => {
    // 确认提示
    const confirmMessage = t('myTasks.alerts.confirmCompleteTask') || '确定是否已经完成？';
    if (!window.confirm(confirmMessage)) {
      return;
    }
    
    setActionLoading(taskId);
    try {
      await completeTask(taskId);
      message.success(t('myTasks.alerts.taskMarkedComplete'));
      // 将任务添加到已标记完成列表，隐藏按钮
      setCompletedTasks(prev => new Set([...Array.from(prev), taskId]));
      loadTasks();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setActionLoading(null);
    }
  };

  const handleConfirmCompletion = async (taskId: number) => {
    setActionLoading(taskId);
    try {
      await confirmTaskCompletion(taskId);
      message.success(t('myTasks.alerts.taskConfirmedComplete'));
      
      // 强制刷新任务列表，避免缓存
      await loadTasks(true);
      
      // 额外延迟刷新，确保后端状态已更新
      setTimeout(async () => {
        await loadTasks(true);
      }, 1000);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setActionLoading(null);
    }
  };

  // 加载多人任务的参与者信息（预留，暂未调用）
  // @ts-expect-error TS6133 - 预留供后续多人任务详情使用
  const loadTaskParticipants = async (taskIds: number[]) => {
    if (!user) return;
    
    const participantsMap: {[key: number]: any} = {};
    for (const taskId of taskIds) {
      try {
        const participantsData = await getTaskParticipants(taskId);
        const userPart = participantsData.participants?.find((p: any) => p.user_id === user.id);
        if (userPart) {
          participantsMap[taskId] = userPart;
        }
      } catch {
      }
    }
    setTaskParticipants(prev => ({ ...prev, ...participantsMap }));
  };

  // 申请退出多人任务
  const handleRequestExit = async (taskId: number) => {
    const reason = prompt(t('myTasks.cancelReason') || '请输入退出原因（可选）');
    if (reason === null) return; // 用户取消了输入
    
    setActionLoading(taskId);
    try {
      const idempotencyKey = `${user?.id}_${taskId}_exit_${Date.now()}`;
      await requestExitFromTask(taskId, {
        idempotency_key: idempotencyKey,
        reason: reason || undefined
      });
      message.success('申请退出已提交，等待任务达人审核');
      await loadTasks();
    } catch (error: any) {
            message.error(getErrorMessage(error));
    } finally {
      setActionLoading(null);
    }
  };

  const handleCancelTask = useCallback((taskId: number) => {
    // 使用 Modal 替代 prompt，避免阻塞主线程
    Modal.confirm({
      title: t('myTasks.cancelReason') || '请输入取消原因（可选）',
      content: (
        <input
          type="text"
          id={`cancel-reason-input-${taskId}`}
          placeholder={t('myTasks.cancelReason') || '请输入取消原因（可选）'}
          style={{
            width: '100%',
            padding: '8px',
            marginTop: '8px',
            border: '1px solid #d9d9d9',
            borderRadius: '4px'
          }}
          autoFocus
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault();
              const input = document.getElementById(`cancel-reason-input-${taskId}`) as HTMLInputElement;
              const reason = input?.value || undefined;
              Modal.destroyAll();
              executeCancelTask(taskId, reason);
            }
          }}
        />
      ),
      okText: '确定',
      cancelText: '取消',
      onOk: () => {
        const input = document.getElementById(`cancel-reason-input-${taskId}`) as HTMLInputElement;
        const reason = input?.value || undefined;
        executeCancelTask(taskId, reason);
      }
    });
  }, [t]);

  const executeCancelTask = useCallback(async (taskId: number, reason?: string) => {
    setActionLoading(taskId);
    try {
      const result = await cancelTask(taskId, reason);
      
      // 检查返回的消息，判断是直接取消还是提交审核
      if (result && (result.request_id || result.message?.includes('review') || result.message?.includes('审核'))) {
        // 已提交审核请求，添加到待审核列表
        setPendingCancelTasks(prev => new Set(Array.from(prev).concat(taskId)));
        message.success('已成功提交取消审核请求，等待客服审核');
      } else {
        // 直接取消成功
        message.success(t('myTasks.alerts.taskCancelled'));
      }
      
      // 延迟加载任务列表，避免阻塞UI
      setTimeout(() => {
        loadTasks();
      }, 100);
    } catch (error: any) {
      // 检查是否是 CSRF token 错误
      if (error.response?.status === 401) {
        if (error.response?.data?.detail?.includes('CSRF')) {
          message.error('验证失败，请刷新页面后重试');
          // 清除 CSRF token 缓存，下次会重新获取
          window.location.reload();
          return;
        }
      }
      
      // 获取详细的错误信息
      const errorMsg = getErrorMessage(error);
      const errorStatus = error.response?.status;
      
      // 处理不同类型的错误
      if (errorStatus === 400) {
        if (errorMsg.includes('already pending') || errorMsg.includes('正在审核') || errorMsg.includes('待审核')) {
          // 如果已经有待审核请求，也添加到列表中
          setPendingCancelTasks(prev => new Set(Array.from(prev).concat(taskId)));
          message.info('您的取消请求正在审核中，请耐心等待');
          setTimeout(() => {
            loadTasks();
          }, 100);
        } else if (errorMsg.includes('cannot be cancelled') || errorMsg.includes('不能取消') || errorMsg.includes('状态')) {
          // 任务状态不允许取消
          let cancelErrorMsg = '该任务当前状态不允许取消';
          if (errorMsg.includes('current status')) {
            cancelErrorMsg += '。只有"待接取"状态的任务可以直接取消，已被接受或进行中的任务需要等待客服审核。';
          }
          message.error(cancelErrorMsg);
        } else if (errorMsg) {
          message.error(errorMsg);
        } else {
          message.error('取消任务失败，请检查任务状态后重试');
        }
      } else if (errorStatus === 403) {
        message.error('您没有权限取消此任务。只有任务发布者或接受者可以取消任务。');
      } else if (errorStatus === 404) {
        message.error('任务不存在或已被删除');
      } else {
        // 其他错误
        message.error(errorMsg || t('myTasks.alerts.operationFailed'));
      }
    } finally {
      setActionLoading(null);
    }
  }, [t]);

  const handleUpdateVisibility = async (taskId: number, isPublic: number) => {
    setActionLoading(taskId);
    try {
      await updateTaskVisibility(taskId, isPublic);
      message.success(t('myTasks.alerts.visibilityUpdated'));
      loadTasks();
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setActionLoading(null);
    }
  };

  const handleDeleteTask = async (taskId: number) => {
    Modal.confirm({
      title: t('myTasks.confirmDelete'),
      okText: '确定',
      cancelText: '取消',
      onOk: async () => {
        setActionLoading(taskId);
        try {
          await deleteTask(taskId);
          message.success(t('myTasks.alerts.taskDeleted'));
          loadTasks();
        } catch (error: any) {
          message.error(getErrorMessage(error));
        } finally {
          setActionLoading(null);
        }
      }
    });
  };

  const handleViewTask = (taskId: number) => {
    setSelectedTaskId(taskId);
    setShowTaskDetailModal(true);
  };

  const handleChat = (taskId: number) => {
    // 跳转到任务聊天页面，使用任务ID
    navigate(`/message?taskId=${taskId}`);
  };

  const handleReviewTask = (task: Task) => {
    setCurrentReviewTask(task);
    setShowReviewModal(true);
  };

  // 根据角色获取标签选项
  const getReviewTags = (task: Task | null) => {
    if (!task || !user) return [];
    
    const isPoster = task.poster_id === user.id;
    const isTaker = task.taker_id === user.id;
    
    // 如果是发布者（评价接收者）
    if (isPoster) {
      return [
        t('myTasks.reviewTags.taker.workQuality'),
        t('myTasks.reviewTags.taker.punctual'),
        t('myTasks.reviewTags.taker.responsible'),
        t('myTasks.reviewTags.taker.goodAttitude'),
        t('myTasks.reviewTags.taker.skilled'),
        t('myTasks.reviewTags.taker.reliable'),
        t('myTasks.reviewTags.taker.recommend'),
        t('myTasks.reviewTags.taker.excellent')
      ];
    }
    
    // 如果是接收者（评价发布者）
    if (isTaker) {
      return [
        t('myTasks.reviewTags.poster.taskClear'),
        t('myTasks.reviewTags.poster.communicationTimely'),
        t('myTasks.reviewTags.poster.paymentTimely'),
        t('myTasks.reviewTags.poster.requirementsReasonable'),
        t('myTasks.reviewTags.poster.cooperationPleasant'),
        t('myTasks.reviewTags.poster.recommend'),
        t('myTasks.reviewTags.poster.trustworthy'),
        t('myTasks.reviewTags.poster.professionalEfficient')
      ];
    }
    
    return [];
  };

  // 根据评分获取描述文本
  const getRatingText = (rating: number) => {
    return t(`myTasks.ratingText.${rating}`) || '';
  };

  const handleSubmitReview = async () => {
    if (!currentReviewTask) return;
    
    const taskId = currentReviewTask.id;
    setActionLoading(taskId);
    try {
      // 将选择的标签添加到评论中
      let finalComment = reviewComment;
      if (selectedTags.length > 0) {
        const tagsText = selectedTags.join('、');
        if (finalComment) {
          finalComment = `${tagsText}\n\n${finalComment}`;
        } else {
          finalComment = tagsText;
        }
      }
      
      await createReview(taskId, reviewRating, finalComment, isAnonymous);
      message.success(t('myTasks.alerts.reviewSubmitted'));
      // 评价提交成功，任务数据会重新加载
      setShowReviewModal(false);
      setReviewRating(5);
      setReviewComment('');
      setSelectedTags([]);
      setIsAnonymous(false);
      setCurrentReviewTask(null);
      
      // 重新加载任务和评价数据
      await loadTasks();
      
      // 强制重新加载该任务的评价数据
      await loadTaskReviews(taskId);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setActionLoading(null);
    }
  };

  // 切换标签选择
  const toggleTag = (tag: string) => {
    setSelectedTags(prev => 
      prev.includes(tag) 
        ? prev.filter(t => t !== tag)
        : [...prev, tag]
    );
  };

  const loadTaskReviews = async (taskId: number) => {
    try {
      const reviews = await getTaskReviews(taskId);
      setTaskReviews(prev => ({ ...prev, [taskId]: reviews }));
    } catch (error) {
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
    
    const reviews = taskReviews[task.id];
    // 如果评价数据还没有加载，先加载它
    if (!reviews) {
      loadTaskReviews(task.id);
      return false; // 暂时返回false，等数据加载完成后再重新渲染
    }
    
    // 检查是否有用户自己的评价（即使匿名评价也会记录user_id）
    return reviews.some((review: any) => review.user_id === user.id);
  };

  const getStatusText = (task: Task) => {
    // ⚠️ 只要任务有pending申请，无论是发布者还是申请者，都显示"申请中"
    // 注意：只有在任务状态为'open'且没有taker_id时才应该显示"申请中"
    if (task.status === 'open' && !task.taker_id) {
      const taskApps = taskApplicationsMap[task.id] || [];
      // 检查是否有pending状态的申请（排除已拒绝和已批准的申请）
      const hasPendingApplications = taskApps.some((app: any) => 
        app && app.status === 'pending'
      );
      if (hasPendingApplications) {
        const translated = t('myTasks.taskStatus.pending_applications');
        // 如果翻译失败（返回原始键），使用英文作为后备
        if (translated === 'myTasks.taskStatus.pending_applications') {
          return 'Pending Applications';
        }
        return translated;
      }
    }
    
    switch (task.status) {
      case 'open': return t('myTasks.taskStatus.open');
      case 'taken': return t('myTasks.taskStatus.taken');
      case 'in_progress': return t('myTasks.taskStatus.in_progress');
      case 'pending_payment': return language === 'zh' ? '待支付' : 'Pending Payment';
      case 'pending_confirmation': return t('myTasks.taskStatus.pending_confirmation');
      case 'completed': return t('myTasks.taskStatus.completed');
      case 'cancelled': return t('myTasks.taskStatus.cancelled');
      default: return task.status;
    }
  };

  const getStatusColor = (task: Task) => {
    // ⚠️ 只要任务有pending申请，无论是发布者还是申请者，都使用"申请中"的颜色
    // 注意：只有在任务状态为'open'且没有taker_id时才应该显示"申请中"的颜色
    if (task.status === 'open' && !task.taker_id) {
      const taskApps = taskApplicationsMap[task.id] || [];
      // 检查是否有pending状态的申请（排除已拒绝和已批准的申请）
      const hasPendingApplications = taskApps.some((app: any) => 
        app && app.status === 'pending'
      );
      if (hasPendingApplications) {
        return '#f59e0b'; // 使用与taken相同的颜色
      }
    }
    
    switch (task.status) {
      case 'open': return '#10b981';
      case 'taken': return '#f59e0b';
      case 'in_progress': return '#3b82f6';
      case 'pending_payment': return '#f59e0b'; // 待支付 - 橙色
      case 'pending_confirmation': return '#f59e0b';
      case 'completed': return '#6b7280';
      case 'cancelled': return '#ef4444'; // 红色
      default: return '#6b7280';
    }
  };

  const getTaskLevelText = (level: string) => {
    switch (level) {
      case 'vip':
        return `⭐ ${t('myTasks.taskLevel.vip')}`;
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
  void getTaskLevelStyle;

  // 根据标签页过滤数据
  const getFilteredData = () => {
    if (activeTab === 'pending') {
      // 过滤掉任务已取消的申请记录
      return applications.filter(app => 
        app.status === 'pending' && 
        app.task_status !== 'cancelled'
      );
    }
    return tasks.filter(task => {
      if (activeTab === 'posted') return task.poster_id === user?.id && task.status !== 'cancelled';
      if (activeTab === 'taken') return task.taker_id === user?.id && task.status !== 'cancelled';
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
      <div className={styles.loadingContainer}>
        <div className={styles.loadingContent}>
          <div className={styles.loadingIcon}>⏳</div>
          <div>{t('myTasks.loading')}</div>
        </div>
      </div>
    );
  }

  return (
    <div className={styles.pageContainer}>
      <SEOHead noindex={true} />
      {/* 顶部导航栏 */}
      <header className={styles.header}>
        <div className={styles.headerContainer}>
          {/* Logo */}
          <div 
            className={styles.logo}
            onClick={() => navigate('/')}
          >
            Link²Ur
          </div>

          {/* 通知按钮和汉堡菜单 */}
          <div className={styles.headerRight}>
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
                }
                window.location.reload();
              }}
              onLoginClick={() => setShowLoginModal(true)}
              systemSettings={systemSettings}
              unreadCount={messageUnreadCount}
            />
          </div>
          
          {/* 移动端样式调整 */}
          <style>{`
            @media (max-width: 480px) {
              /* 缩小Logo字体 */
              header > div > div:first-child {
                font-size: 18px !important;
                padding: 2px 4px !important;
              }
              
              /* 缩小通知按钮 */
              .notification-btn {
                width: 38px !important;
                height: 38px !important;
                min-width: 38px !important;
                flex-shrink: 0 !important;
              }
              
              /* 汉堡菜单按钮使用标准大小（与首页一致） */
              /* 移除覆盖，使用组件默认的 24px x 18px */
            }
          `}</style>
        </div>
      </header>

          {/* 主要内容区域 */}
          <div className={styles.mainContent}>
        <div className={styles.contentWrapper}>
              {/* 页面头部 */}
              <div className={styles.pageHeader}>
                <button
                  className={styles.backButton}
                  onClick={() => navigate('/')}
                >
                  {t('myTasks.buttons.backToHome')}
                </button>
          
                <div className={styles.pageHeaderTitle}>
                  <div className={styles.pageHeaderIcon}>📋</div>
                  <h1 className={styles.seoH1}>
                    {t('myTasks.title')}
                  </h1>
                </div>
                <p className={styles.pageHeaderSubtitle}>
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
                <div className={styles.statsGrid}>
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
                      {tasks.filter(t => t.poster_id === user?.id && t.status !== 'cancelled').length}
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
                      {tasks.filter(t => t.taker_id === user?.id && t.status !== 'cancelled').length}
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
              <div className={styles.tabsSection}>
                <div className={styles.tabsContainer}>
            {[
              { key: 'all', label: t('myTasks.tabs.all'), count: tasks.length, icon: '📋' },
              { key: 'posted', label: t('myTasks.tabs.posted'), count: tasks.filter(t => t.poster_id === user?.id && t.status !== 'cancelled').length, icon: '📤' },
              { key: 'taken', label: t('myTasks.tabs.taken'), count: tasks.filter(t => t.taker_id === user?.id && t.status !== 'cancelled').length, icon: '📥' },
              { key: 'pending', label: t('myTasks.tabs.pending'), count: applications.filter(app => app.status === 'pending' && app.task_status !== 'cancelled').length, icon: '⏳' },
              { key: 'completed', label: t('myTasks.tabs.completed'), count: tasks.filter(t => t.status === 'completed').length, icon: '✅' },
              { key: 'cancelled', label: t('myTasks.tabs.cancelled'), count: tasks.filter(t => t.status === 'cancelled').length, icon: '❌' }
            ].map(tab => (
                    <button
                      key={tab.key}
                      className={`${styles.tabButton} ${activeTab === tab.key ? styles.tabButtonActive : styles.tabButtonInactive}`}
                      onClick={() => setActiveTab(tab.key as any)}
                    >
                <span>{tab.icon}</span>
                <span>{tab.label}</span>
                <span className={activeTab === tab.key ? styles.tabBadgeActive : styles.tabBadgeInactive}>
                  {tab.count}
                </span>
              </button>
            ))}
          </div>
        </div>

              {/* 任务列表 */}
              <div className={styles.tasksSection}>
          {paginatedData.length === 0 ? (
            <div className={styles.emptyState}>
              <div className={styles.emptyStateIcon}>📭</div>
              <div className={styles.emptyStateTitle}>
                {activeTab === 'all' && t('myTasks.emptyStates.noTasks')}
                {activeTab === 'posted' && t('myTasks.emptyStates.noPosted')}
                {activeTab === 'taken' && t('myTasks.emptyStates.noTaken')}
                {activeTab === 'pending' && t('myTasks.emptyStates.noPendingApplications')}
                {activeTab === 'completed' && t('myTasks.emptyStates.noCompleted')}
                {activeTab === 'cancelled' && t('myTasks.emptyStates.noCancelled')}
              </div>
              <div className={styles.emptyStateText}>
                {activeTab === 'posted' && t('myTasks.emptyStates.postFirst')}
                {activeTab === 'taken' && t('myTasks.emptyStates.browseTasks')}
                {activeTab === 'pending' && t('myTasks.emptyStates.noPendingApplicationsDesc')}
                {activeTab === 'completed' && t('myTasks.emptyStates.completedTasksDesc')}
                {activeTab === 'cancelled' && t('myTasks.emptyStates.cancelledTasksDesc')}
              </div>
            </div>
          ) : (
                  <div className={styles.tasksGrid}>
              {paginatedData.map((item) => {
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
                        <span>{t('myTasks.tabs.pending')}</span>
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
                          <span>{t('tasks.taskReward')}: £{application.task_reward}</span>
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
                          <span>{t('myTasks.applicationTime')}: {TimeHandlerV2.formatUtcToLocal(application.created_at, 'YYYY-MM-DD HH:mm')}</span>
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
                            {t('myTasks.applicationMessage')}:
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
                          {t('myTasks.actions.viewDetails')}
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
                        <div key={task.id} className={styles.taskCard}>
                    {/* 任务等级装饰 */}
                    {task.task_level && task.task_level !== 'normal' && (
                      <div className={`${styles.taskCardLevelDecoration} ${task.task_level === 'vip' ? styles.taskCardLevelDecorationVip : styles.taskCardLevelDecorationSuper}`} />
                    )}

                    {/* 任务标题和状态 */}
                    <div className={styles.taskCardHeader}>
                      <div className={styles.taskCardHeaderLeft}>
                        <h3 className={styles.taskCardTitle}>
                          {task.title}
                        </h3>
                        {/* 任务等级标签 */}
                        {task.task_level && task.task_level !== 'normal' && (
                          <div className={`${styles.taskCardLevelBadge} ${task.task_level === 'vip' ? styles.taskCardLevelBadgeVip : styles.taskCardLevelBadgeSuper}`}>
                            {getTaskLevelText(task.task_level)}
                          </div>
                        )}
                        {/* 会员发布角标 */}
                        {task.poster_user_level && (task.poster_user_level === 'vip' || task.poster_user_level === 'super') && (
                          <div className={styles.taskCardLevelBadge} style={{ background: 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)', fontSize: '11px', padding: '4px 8px' }}>
                            {t('home.memberPublished') || '会员发布'}
                          </div>
                        )}
                      </div>
                      <span 
                        className={styles.taskCardStatusBadge}
                        style={{
                          background: getStatusColor(task)
                        }}
                      >
                        {getStatusText(task)}
                      </span>
                    </div>

                    {/* 任务信息 */}
                    <div className={styles.taskCardInfo}>
                            <div className={styles.taskCardInfoGrid}>
                        <div className={styles.taskCardInfoItem}>
                          <span className={styles.taskCardInfoIcon}>💰</span>
                          <span className={styles.taskCardInfoText}>£{((task.agreed_reward ?? task.base_reward ?? task.reward) || 0).toFixed(2)}</span>
                        </div>
                        <div className={styles.taskCardInfoItem}>
                          <span className={styles.taskCardInfoIcon}>
                            {task.location?.toLowerCase() === 'online' ? '🌐' : '📍'}
                          </span>
                          <span className={task.location?.toLowerCase() === 'online' ? styles.taskCardInfoTextOnline : styles.taskCardInfoTextNormal}>
                            {obfuscateLocation(task.location)}
                          </span>
                        </div>
                        <div className={styles.taskCardInfoItem}>
                          <span className={styles.taskCardInfoIcon}>🏷️</span>
                          <span className={styles.taskCardInfoTextNormal}>{task.task_type}</span>
                        </div>
                        <div className={styles.taskCardInfoItem}>
                          <span className={styles.taskCardInfoIcon}>👤</span>
                          <span className={styles.taskCardInfoTextNormal}>
                            {isPoster ? t('myTasks.userRole.poster') : isTaker ? t('myTasks.userRole.taker') : t('myTasks.userRole.unknown')}
                          </span>
                        </div>
                      </div>
                      
                      <div className={styles.taskCardDeadline}>
                        <span className={styles.taskCardInfoIcon}>⏰</span>
                        <span className={styles.taskCardInfoTextNormal}>
                          {task.deadline && TimeHandlerV2.formatUtcToLocal(task.deadline, 'MM/DD HH:mm', 'Europe/London')}
                        </span>
                      </div>
                    </div>

                          {/* 任务描述 */}
                          <div className={styles.taskCardDescription}>
                      {task.description.length > 120 
                        ? `${task.description.substring(0, 120)}...` 
                        : task.description
                      }
                    </div>

                          {/* 操作按钮 */}
                          <div className={styles.taskCardActions}>
                      <button
                        onClick={() => handleViewTask(task.id)}
                        className={`${styles.taskCardButton} ${styles.taskCardButtonView}`}
                      >
{t('myTasks.actions.viewDetails')}
                      </button>

                      {/* 可见性控制按钮 */}
                      {isPoster && task.status === 'completed' && (
                        <button
                          onClick={() => handleUpdateVisibility(task.id, task.is_public === 1 ? 0 : 1)}
                          disabled={actionLoading === task.id}
                          className={`${styles.taskCardButton} ${styles.taskCardButtonVisibility} ${task.is_public === 1 ? styles.taskCardButtonVisibilityPublic : styles.taskCardButtonVisibilityPrivate} ${actionLoading === task.id ? styles.taskCardButtonDisabled : ''}`}
                        >
                          {actionLoading === task.id ? t('myTasks.actions.processing') : (task.is_public === 1 ? t('myTasks.actions.setPrivate') : t('myTasks.actions.setPublic'))}
                        </button>
                      )}

                      {/* 根据任务状态和用户角色显示不同按钮 */}
                      {task.status === 'taken' && isTaker && (
                        <div className={styles.taskCardWaitingApproval}>
                          <span className={styles.taskCardWaitingApprovalIcon}>⏳</span>
                          <span>{t('myTasks.actions.waitingApproval')}</span>
                        </div>
                      )}

                      {task.status === 'in_progress' && isTaker && !completedTasks.has(task.id) && (
                        <button
                          onClick={() => handleCompleteTask(task.id)}
                          disabled={actionLoading === task.id}
                          className={`${styles.taskCardButton} ${styles.taskCardButtonComplete} ${actionLoading === task.id ? styles.taskCardButtonDisabled : ''}`}
                        >
                          {actionLoading === task.id ? t('myTasks.actions.processing') : t('myTasks.actions.markComplete')}
                        </button>
                      )}

                      {task.status === 'pending_confirmation' && isPoster && (
                        <button
                          onClick={() => handleConfirmCompletion(task.id)}
                          disabled={actionLoading === task.id}
                          className={`${styles.taskCardButton} ${styles.taskCardButtonComplete} ${actionLoading === task.id ? styles.taskCardButtonDisabled : ''}`}
                        >
                          {actionLoading === task.id ? t('myTasks.actions.processing') : t('myTasks.actions.confirmComplete')}
                        </button>
                      )}

                      {/* 多人任务参与者：申请退出按钮 */}
                      {task.is_multi_participant && taskParticipants[task.id] && 
                       (taskParticipants[task.id].status === 'accepted' || taskParticipants[task.id].status === 'in_progress') &&
                       taskParticipants[task.id].status !== 'exit_requested' && (() => {
                        // 检查时间段是否已开始
                        let canExit = true;
                        if ((task as any).time_slot_start_datetime) {
                          const now = dayjs.utc();
                          const slotStart = dayjs.utc((task as any).time_slot_start_datetime);
                          if (now.isAfter(slotStart) || now.isSame(slotStart)) {
                            canExit = false;
                          }
                        }
                        
                        return canExit ? (
                          <button
                            onClick={() => handleRequestExit(task.id)}
                            disabled={actionLoading === task.id}
                            className={`${styles.taskCardButton} ${styles.taskCardButtonCancel} ${actionLoading === task.id ? styles.taskCardButtonDisabled : ''}`}
                            style={{
                              background: '#ffc107',
                              color: '#000'
                            }}
                          >
                            {actionLoading === task.id ? t('myTasks.actions.processing') : '申请退出'}
                          </button>
                        ) : (
                          <div style={{
                            padding: '8px 12px',
                            background: '#f3f4f6',
                            color: '#6b7280',
                            borderRadius: '6px',
                            fontSize: '14px'
                          }}>
                            时间段已开始，无法申请退出
                          </div>
                        );
                      })()}

                      {/* 取消按钮：只有 open、taken 或 in_progress 状态的任务可以取消 */}
                      {/* pending_confirmation（待确认）和 completed（已完成）状态的任务不能取消 */}
                      {/* 多人任务的参与者不显示取消按钮，而是显示申请退出按钮 */}
                      {!task.is_multi_participant && (task.status === 'open' || task.status === 'taken' || task.status === 'in_progress') && (
                        <button
                          onClick={(e) => {
                            e.preventDefault();
                            e.stopPropagation();
                            if (!pendingCancelTasks.has(task.id) && actionLoading !== task.id) {
                              handleCancelTask(task.id);
                            }
                          }}
                          disabled={actionLoading === task.id || pendingCancelTasks.has(task.id)}
                          className={`${styles.taskCardButton} ${styles.taskCardButtonCancel} ${(actionLoading === task.id || pendingCancelTasks.has(task.id)) ? styles.taskCardButtonDisabled : ''}`}
                          style={{
                            background: pendingCancelTasks.has(task.id) ? '#9ca3af' : undefined
                          }}
                        >
                          {pendingCancelTasks.has(task.id) ? '待审核' : (actionLoading === task.id ? t('myTasks.actions.processing') : t('myTasks.actions.cancelTask'))}
                        </button>
                      )}

                      {/* 聊天按钮 - 只有在任务进行中且有接收者时才显示 */}
                      {(task.status === 'in_progress' && task.taker_id) && (
                        <button
                          onClick={() => handleChat(task.id)}
                          className={`${styles.taskCardButton} ${styles.taskCardButtonChat}`}
                        >
{t('myTasks.actions.contactTaker')}
                        </button>
                      )}

                      {/* 评价按钮 */}
                      {canReview(task) && !hasReviewed(task) && (
                        <button
                          onClick={() => handleReviewTask(task)}
                          className={`${styles.taskCardButton} ${styles.taskCardButtonReview}`}
                        >
{t('myTasks.actions.review')}
                        </button>
                      )}

                      {/* 查看评价按钮 */}
                      {task.status === 'completed' && (taskReviews[task.id] ?? []).length > 0 && (
                        <button
                          onClick={() => toggleTaskReviews(task.id)}
                          className={styles.taskCardButtonViewReviews}
                        >
{(showTaskReviews[task.id] ?? false) ? t('myTasks.actions.hideReviews') : `${t('myTasks.actions.viewReviews')} (${(taskReviews[task.id] ?? []).length})`}
                        </button>
                      )}

                      {/* 删除按钮 */}
                      {task.status === 'cancelled' && isPoster && (
                        <button
                          onClick={() => handleDeleteTask(task.id)}
                          disabled={actionLoading === task.id}
                          className={`${styles.taskCardButtonDelete} ${actionLoading === task.id ? styles.taskCardButtonDisabled : ''}`}
                        >
                          {actionLoading === task.id ? t('myTasks.actions.processing') : `🗑️ ${t('myTasks.actions.deleteTask')}`}
                        </button>
                      )}
                    </div>

                    {/* 评价列表 */}
                    {(showTaskReviews[task.id] ?? false) && (taskReviews[task.id] ?? []).length > 0 && (
                      <div className={styles.taskCardReviewsContainer}>
                        <h4 className={styles.taskCardReviewsTitle}>
{t('myTasks.actions.viewReviews')}
                        </h4>
                        {(taskReviews[task.id] ?? []).map((review: any, index: number) => (
                          <div key={index} className={styles.taskCardReviewItem}>
                            <div className={styles.taskCardReviewHeader}>
                              <div className={styles.taskCardReviewUser}>
                                {t('myTasks.user')} {review.user_id}
                              </div>
                              <div className={styles.taskCardReviewRating}>
                                {Array.from({length: Math.floor(review.rating)}, () => '⭐').join('')}
                                {review.rating % 1 !== 0 && '☆'}
                                {Array.from({length: 5 - Math.ceil(review.rating)}, () => '☆').join('')}
                              </div>
                            </div>
                            {review.comment && (
                              <div className={styles.taskCardReviewComment}>
                                {review.comment}
                              </div>
                            )}
                            <div className={styles.taskCardReviewTime}>
                              {TimeHandlerV2.formatUtcToLocal(review.created_at)}
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
                  <div className={styles.pagination}>
              <button
                onClick={() => setCurrentPage(prev => Math.max(1, prev - 1))}
                disabled={currentPage === 1}
                className={`${styles.paginationButton} ${styles.paginationButtonPrev}`}
              >
                ← {t('myTasks.previousPage')}
              </button>
              
                    <div className={styles.paginationNumbers}>
                {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                  const pageNum = i + 1;
                  const isActive = pageNum === currentPage;
                  return (
                    <button
                      key={pageNum}
                      onClick={() => setCurrentPage(pageNum)}
                      className={`${styles.paginationNumber} ${isActive ? styles.paginationNumberActive : ''}`}
                    >
                      {pageNum}
                    </button>
                  );
                })}
              </div>
              
              <button
                onClick={() => setCurrentPage(prev => prev + 1)}
                disabled={currentPage >= totalPages}
                className={`${styles.paginationButton} ${styles.paginationButtonNext}`}
              >
                {t('myTasks.nextPage')} →
              </button>
            </div>
          )}
        </div>
      </div>
      </div>

          {/* 评价弹窗 */}
          {showReviewModal && currentReviewTask && (
            <div 
              className={styles.reviewModalOverlay} 
              onClick={() => {
                setShowReviewModal(false);
                setReviewRating(5);
                setReviewComment('');
                setSelectedTags([]);
                setIsAnonymous(false);
                setCurrentReviewTask(null);
              }}
            >
              <div className={styles.reviewModal} onClick={(e) => e.stopPropagation()}>
                <div className={styles.reviewModalHeader}>
                  <LazyImage src="/static/logo.png" alt="Link²Ur Logo" className={styles.reviewModalLogo} width={40} height={40} />
                  <h2 className={styles.reviewModalTitle}>
                    {t('myTasks.actions.review')}
                  </h2>
                </div>
                
                {/* 星级评价 */}
                <div className={styles.reviewRatingSection}>
                  <div className={styles.reviewStars}>
                    {[1, 2, 3, 4, 5].map(star => (
                      <span
                        key={star}
                        onClick={() => setReviewRating(star)}
                        onMouseEnter={() => setHoverRating(star)}
                        onMouseLeave={() => setHoverRating(0)}
                        className={styles.reviewStar}
                        style={{
                          opacity: star <= (hoverRating || reviewRating) ? 1 : 0.3
                        }}
                      >
                        ⭐
                      </span>
                    ))}
                  </div>
                  <div className={styles.reviewRatingText}>
                    {getRatingText(reviewRating)}
                  </div>
                </div>

                {/* 标签选择 */}
                <div className={styles.reviewTagsSection}>
                  <div className={styles.reviewTagsGrid}>
                    {getReviewTags(currentReviewTask).map(tag => (
                      <div
                        key={tag}
                        onClick={() => toggleTag(tag)}
                        className={`${styles.reviewTag} ${selectedTags.includes(tag) ? styles.reviewTagSelected : ''}`}
                      >
                        {tag}
                      </div>
                    ))}
                  </div>
                </div>

                {/* 评论输入 */}
                <div className={styles.reviewCommentSection}>
                  <label className={styles.reviewCommentLabel}>
                    {t('myTasks.reviewPlaceholder')} ({t('myTasks.optional')})
                  </label>
                  <textarea
                    value={reviewComment}
                    onChange={(e) => setReviewComment(e.target.value)}
                    placeholder={t('myTasks.reviewPlaceholder')}
                    className={styles.reviewCommentInput}
                  />
                </div>

                {/* 提交按钮 */}
                <button
                  onClick={handleSubmitReview}
                  disabled={actionLoading === currentReviewTask.id}
                  className={styles.reviewSubmitButton}
                >
                  {actionLoading === currentReviewTask.id ? t('myTasks.actions.processing') : t('myTasks.actions.submitReview')}
                </button>
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
              grid-template-columns: repeat(2, 1fr) !important;
              gap: 12px !important;
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