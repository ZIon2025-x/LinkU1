import React from 'react';
import { Task, TaskLevel } from '../../types/task';
import { cardStyles, statusStyles, levelStyles } from '../../utils/taskModalStyles';
import { TimeHandlerV2 } from '../../utils/timeUtils';

interface TaskInfoCardProps {
  task: Task;
  getTaskLevelText: (level: TaskLevel) => string;
  getStatusText: (status: string) => string;
  shouldHideStatus: () => boolean;
  t: (key: string) => string;
}

const TaskInfoCard: React.FC<TaskInfoCardProps> = ({
  task,
  getTaskLevelText,
  getStatusText,
  shouldHideStatus,
  t
}) => {
  return (
    <div style={{
      display: 'grid',
      gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
      gap: '20px',
      marginBottom: '32px',
      position: 'relative',
      zIndex: 1
    }}>
      <div style={cardStyles.infoCard}>
        <div style={{ fontSize: '24px', marginBottom: '8px' }}>📋</div>
        <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>
          {t('taskDetail.taskTypeLabel')}
        </div>
        <div style={{ fontSize: '16px', fontWeight: '600', color: '#1e293b' }}>
          {task.task_type}
        </div>
      </div>
      
      <div style={task.location === 'Online' ? cardStyles.onlineCard : cardStyles.infoCard}>
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
      
      <div style={cardStyles.infoCard}>
        <div style={{ fontSize: '24px', marginBottom: '8px' }}>💰</div>
        <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>
          {t('taskDetail.rewardLabel')}
        </div>
        <div style={{ fontSize: '20px', fontWeight: '700', color: '#059669' }}>
          £{task.reward.toFixed(2)}
        </div>
      </div>
      
      <div style={cardStyles.infoCard}>
        <div style={{ fontSize: '24px', marginBottom: '8px' }}>⏰</div>
        <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>
          {t('taskDetail.deadlineLabel')}
        </div>
        <div style={{ fontSize: '16px', fontWeight: '600', color: '#1e293b' }}>
          {TimeHandlerV2.formatUtcToLocal(task.deadline, 'MM/DD HH:mm', 'Europe/London')} {t('taskDetail.ukTime')}
        </div>
      </div>
    </div>
  );
};

export default TaskInfoCard;


