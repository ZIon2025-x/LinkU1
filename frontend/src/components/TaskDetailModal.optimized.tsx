// 这是优化后的TaskDetailModal示例代码
// 展示了如何使用新的子组件和样式系统
// 
// 主要优化：
// 1. 使用类型定义替代any
// 2. 拆分大组件为子组件
// 3. 提取样式常量
// 4. 使用React.memo优化性能
// 5. 使用useMemo和useCallback减少不必要的渲染

import React, { useEffect, useState, useMemo, useCallback } from 'react';
import api, { fetchCurrentUser } from '../api';
import LoginModal from './LoginModal';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import { Task, User } from '../types/task';
import { modalStyles } from '../utils/taskModalStyles';
import TaskInfoCard from './taskDetailModal/TaskInfoCard';
import ApplicationStatusDisplay from './taskDetailModal/ApplicationStatusDisplay';
import ApplicantList from './taskDetailModal/ApplicantList';
import ReviewModal from './taskDetailModal/ReviewModal';

interface TaskDetailModalProps {
  isOpen: boolean;
  onClose: () => void;
  taskId: number | null;
}

// 使用memo避免不必要的重新渲染
const TaskDetailModal: React.FC<TaskDetailModalProps> = React.memo(({ isOpen, onClose, taskId }) => {
  const { t } = useLanguage();
  useLocalizedNavigation(); // navigate 未使用，admin/service 在独立子域
  const [task, setTask] = useState<Task | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [user, setUser] = useState<User | null>(null);
  const [, setNewPrice] = useState('');
  const [actionLoading] = useState(false);
  const [showReviewModal, setShowReviewModal] = useState(false);
  const [reviewRating, setReviewRating] = useState(5);
  const [hoverRating, setHoverRating] = useState(0);
  const [reviewComment, setReviewComment] = useState('');
  const [isAnonymous, setIsAnonymous] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [applications] = useState<any[]>([]);
  const [loadingApplications] = useState(false);
  const [userApplication] = useState<any>(null);
  const [hasApplied] = useState(false);

  // 使用useCallback缓存函数
  const loadTaskData = useCallback(async () => {
    if (!taskId) return;
    
    setLoading(true);
    setError('');
    
    try {
      const res = await api.get(`/api/tasks/${taskId}`);
      setTask(res.data);
      setNewPrice(res.data.reward.toString());
    } catch (error: any) {
      setError(t('taskDetail.taskNotFound'));
    } finally {
      setLoading(false);
    }
    
    try {
      const userData = await fetchCurrentUser();
      setUser(userData);
    } catch (error) {
      setUser(null);
    }
  }, [taskId, t]);

  useEffect(() => {
    if (isOpen && taskId) {
      loadTaskData();
    }
  }, [isOpen, taskId, loadTaskData]);

  // 使用useMemo缓存计算结果
  const isTaskPoster = useMemo(() => user && task && user.id === task.poster_id, [user, task]);
  const _isTaskTaker = useMemo(() => user && task && user.id === task.taker_id, [user, task]);
  void _isTaskTaker;

  const getTaskLevelText = useCallback((level: string) => {
    switch (level) {
      case 'vip': return '⭐ VIP';
      case 'super': return t('myTasks.taskLevel.super');
      default: return t('myTasks.taskLevel.normal');
    }
  }, [t]);

  const getStatusText = useCallback((status: string) => {
    switch (status) {
      case 'open': return t('myTasks.taskStatus.open');
      case 'taken': return t('myTasks.taskStatus.taken');
      case 'in_progress': return t('myTasks.taskStatus.in_progress');
      case 'pending_confirmation': return t('myTasks.taskStatus.pending_confirmation');
      case 'completed': return t('myTasks.taskStatus.completed');
      case 'cancelled': return t('myTasks.taskStatus.cancelled');
      default: return status;
    }
  }, [t]);

  const shouldHideStatus = useCallback(() => {
    if (!task || !user) return false;
    const isPoster = task.poster_id === user.id;
    const isTaker = task.taker_id === user.id;
    const isApplicant = hasApplied || userApplication;
    
    if (!isPoster && !isTaker && !isApplicant && task.status === 'taken') {
      return true;
    }
    return false;
  }, [task, user, hasApplied, userApplication]);

  const canReview = useCallback(() => {
    if (!user || !task) return false;
    return (task.poster_id === user.id || task.taker_id === user.id) && task.status === 'completed';
  }, [user, task]);

  const hasUserReviewed = useCallback(() => {
    if (!user || !task) return false;
    // 实现评价检查逻辑
    return false;
  }, [user, task]);

  if (!isOpen) return null;

  if (loading) {
    return (
      <div style={modalStyles.overlay}>
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
      <div style={modalStyles.overlay}>
        <div style={{
          backgroundColor: '#fff',
          borderRadius: '16px',
          padding: '40px',
          textAlign: 'center',
          maxWidth: '400px',
          width: '100%'
        }}>
          <div style={{ fontSize: 48, marginBottom: 20, color: 'red' }}>❌</div>
          <div style={{ fontSize: 18, color: 'red', marginBottom: 20 }}>
            {error || t('taskDetail.taskNotFound')}
          </div>
          <button onClick={onClose} style={{
            background: '#3b82f6',
            color: '#fff',
            border: 'none',
            borderRadius: '8px',
            padding: '12px 24px',
            fontSize: '16px',
            cursor: 'pointer'
          }}>
            {t('taskDetail.close')}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div style={modalStyles.overlay}>
      <div style={modalStyles.modal}>
        {/* 关闭按钮 */}
        <button
          onClick={onClose}
          style={modalStyles.closeButton}
          onMouseEnter={(e) => {
            e.currentTarget.style.backgroundColor = '#f0f0f0';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.backgroundColor = 'transparent';
          }}
        >
          ×
        </button>
        
        <div style={modalStyles.content}>
          {/* 任务标题 */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '20px',
            marginBottom: '32px'
          }}>
            <h2 style={{
              fontSize: '32px',
              fontWeight: '800',
              background: 'linear-gradient(135deg, #667eea, #764ba2)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              margin: '0 0 8px 0'
            }}>{task.title}</h2>
          </div>

          {/* 使用新的子组件 */}
          <TaskInfoCard
            task={task}
            getTaskLevelText={getTaskLevelText}
            getStatusText={getStatusText}
            shouldHideStatus={shouldHideStatus}
            t={t}
          />

          {/* 任务描述 */}
          <div style={{
            background: '#f8fafc',
            padding: '24px',
            borderRadius: '16px',
            border: '2px solid #e2e8f0',
            marginBottom: '32px'
          }}>
            <h3 style={{
              fontSize: '18px',
              fontWeight: '600',
              color: '#1e293b',
              margin: '0 0 16px 0'
            }}>
              📝 {t('taskDetail.descriptionLabel')}
            </h3>
            <div style={{
              fontSize: '16px',
              lineHeight: 1.6,
              color: '#374151',
              whiteSpace: 'pre-wrap'
            }}>{task.description}</div>
          </div>

          {/* 申请状态显示 */}
          <ApplicationStatusDisplay
            userApplication={userApplication}
            task={task}
            user={user}
            canReview={canReview}
            hasUserReviewed={hasUserReviewed}
            t={t}
          />

          {/* 申请者列表 - 仅任务发布者可见 */}
          {isTaskPoster && (task.status === 'taken' || task.status === 'open') && (
            <ApplicantList
              applications={applications}
              loadingApplications={loadingApplications}
              actionLoading={actionLoading}
              onApproveApplication={async (_applicationId) => {
                // 实现批准申请逻辑
              }}
              onRejectApplication={async (_applicationId) => {
                // 实现拒绝申请逻辑
              }}
              t={t}
            />
          )}

          {/* 评价弹窗 */}
          <ReviewModal
            isOpen={showReviewModal}
            onClose={() => setShowReviewModal(false)}
            onSubmit={async () => {
              // 实现提交评价逻辑
            }}
            reviewRating={reviewRating}
            setReviewRating={setReviewRating}
            hoverRating={hoverRating}
            setHoverRating={setHoverRating}
            reviewComment={reviewComment}
            setReviewComment={setReviewComment}
            isAnonymous={isAnonymous}
            setIsAnonymous={setIsAnonymous}
            actionLoading={actionLoading}
            t={t}
          />

          {/* 登录弹窗 */}
          <LoginModal 
            isOpen={showLoginModal}
            onClose={() => setShowLoginModal(false)}
            onSuccess={() => {
              window.location.reload();
            }}
            onReopen={() => setShowLoginModal(true)}
            showForgotPassword={false}
          />
        </div>
      </div>
    </div>
  );
});

TaskDetailModal.displayName = 'TaskDetailModal';

export default TaskDetailModal;


