import React from 'react';
import { TaskApplication, Task, User } from '../../types/task';
import { applicationStatusStyles } from '../../utils/taskModalStyles';
import { TimeHandlerV2 } from '../../utils/timeUtils';

interface ApplicationStatusDisplayProps {
  userApplication: TaskApplication | null;
  task: Task;
  user: User | null;
  canReview: () => boolean;
  hasUserReviewed: () => boolean;
  t: (key: string) => string;
}

const ApplicationStatusDisplay: React.FC<ApplicationStatusDisplayProps> = ({
  userApplication,
  task,
  user,
  canReview,
  hasUserReviewed,
  t
}) => {
  if (!userApplication) return null;

  const isTaskTaker = user && user.id === task.taker_id;
  const statusStyle = applicationStatusStyles[userApplication.status];

  return (
    <div style={{
      ...statusStyle,
      borderRadius: '16px',
      padding: '20px 24px',
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
  );
};

export default ApplicationStatusDisplay;


