import React from 'react';
import TaskTitle from './TaskTitle';
import { TASK_TYPES } from '../pages/Tasks';
import { Language } from '../contexts/LanguageContext';

interface TaskCardProps {
  task: any;
  isMobile: boolean;
  language: Language;
  onViewTask: (taskId: number) => void;
  getTaskTypeLabel: (taskType: string) => string;
  getRemainTime: (deadline: string, t: (key: string) => string) => string;
  isExpired: (deadline: string) => boolean;
  isExpiringSoon: (deadline: string) => boolean;
  getTaskLevelColor: (taskLevel: string) => string;
  getTaskLevelLabel: (taskLevel: string) => string;
  t: (key: string) => string;
}

const TaskCard: React.FC<TaskCardProps> = React.memo(({
  task,
  isMobile,
  language,
  onViewTask,
  getTaskTypeLabel,
  getRemainTime,
  isExpired,
  isExpiringSoon,
  getTaskLevelColor,
  getTaskLevelLabel,
  t
}) => {
  return (
    <div
      className="task-card"
      style={{
        background: '#fff',
        borderRadius: '12px',
        overflow: 'hidden',
        transition: 'all 0.2s ease',
        cursor: 'pointer',
        boxShadow: task.task_level === 'vip' ? '0 4px 15px rgba(245, 158, 11, 0.2)' : 
                   task.task_level === 'super' ? '0 4px 20px rgba(139, 92, 246, 0.3)' : 
                   '0 2px 8px rgba(0,0,0,0.05)',
        border: task.task_level === 'vip' ? '2px solid #f59e0b' : 
                task.task_level === 'super' ? '2px solid #8b5cf6' : 
                '1px solid #e5e7eb',
        animation: task.task_level === 'vip' ? 'vipGlow 4s infinite' : 
                   task.task_level === 'super' ? 'superPulse 3s infinite' : 'none'
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.transform = 'translateY(-2px)';
        if (task.task_level === 'vip') {
          e.currentTarget.style.boxShadow = '0 6px 20px rgba(245, 158, 11, 0.4)';
        } else if (task.task_level === 'super') {
          e.currentTarget.style.boxShadow = '0 8px 25px rgba(139, 92, 246, 0.5)';
        } else {
          e.currentTarget.style.boxShadow = '0 4px 16px rgba(0,0,0,0.1)';
        }
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.transform = 'translateY(0)';
        if (task.task_level === 'vip') {
          e.currentTarget.style.boxShadow = '0 4px 15px rgba(245, 158, 11, 0.2)';
        } else if (task.task_level === 'super') {
          e.currentTarget.style.boxShadow = '0 4px 20px rgba(139, 92, 246, 0.3)';
        } else {
          e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,0,0,0.05)';
        }
      }}
      onClick={() => onViewTask(task.id)}
    >
      {/* 任务图片区域 */}
      <div style={{
        aspectRatio: isMobile ? '9 / 16' : '16 / 9',
        width: '100%',
        position: 'relative',
        overflow: 'hidden',
        background: `linear-gradient(135deg, ${getTaskLevelColor(task.task_level)}20, ${getTaskLevelColor(task.task_level)}40)`,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}>
        {/* 任务类型图标占位符 */}
        {(!task.images || !Array.isArray(task.images) || task.images.length === 0 || !task.images[0]) && (
          <div 
            className={`task-icon-placeholder-${task.id}`}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: '100%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              zIndex: 0,
              pointerEvents: 'none'
            }}>
            <div style={{
              fontSize: isMobile ? '48px' : '64px',
              opacity: 0.6,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center'
            }}>
              {['🏠', '🎓', '🛍️', '🏃', '🔧', '🤝', '🚗', '🐕', '🛒', '📦'][TASK_TYPES.indexOf(task.task_type) % 10]}
            </div>
          </div>
        )}
        
        {/* 任务图片 */}
        {task.images && Array.isArray(task.images) && task.images.length > 0 && task.images[0] && (
          <img
            key={`task-img-${task.id}-${String(task.images[0])}`}
            src={String(task.images[0])}
            alt={task.title}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: '100%',
              objectFit: 'cover',
              zIndex: 1,
              backgroundColor: 'transparent',
              display: 'block'
            }}
            loading="lazy"
            onLoad={(e) => {
              const placeholder = e.currentTarget.parentElement?.querySelector(`.task-icon-placeholder-${task.id}`) as HTMLElement;
              if (placeholder) {
                placeholder.style.display = 'none';
              }
            }}
            onError={(e) => {
              e.currentTarget.style.display = 'none';
              const placeholder = e.currentTarget.parentElement?.querySelector(`.task-icon-placeholder-${task.id}`) as HTMLElement;
              if (!placeholder) {
                const placeholderDiv = document.createElement('div');
                placeholderDiv.className = `task-icon-placeholder-${task.id}`;
                placeholderDiv.style.cssText = `
                  position: absolute;
                  top: 0;
                  left: 0;
                  width: 100%;
                  height: 100%;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  z-index: 0;
                  pointer-events: none;
                `;
                placeholderDiv.innerHTML = `
                  <div style="font-size: ${isMobile ? '48px' : '64px'}; opacity: 0.6; display: flex; align-items: center; justify-content: center;">
                    ${['🏠', '🎓', '🛍️', '🏃', '🔧', '🤝', '🚗', '🐕', '🛒', '📦'][TASK_TYPES.indexOf(task.task_type) % 10]}
                  </div>
                `;
                e.currentTarget.parentElement?.appendChild(placeholderDiv);
              } else {
                placeholder.style.display = 'flex';
              }
            }}
          />
        )}
        
        {/* 图片遮罩层 */}
        <div style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: task.images && Array.isArray(task.images) && task.images.length > 0 && task.images[0]
            ? 'linear-gradient(to bottom, rgba(0,0,0,0.3) 0%, rgba(0,0,0,0.1) 50%, rgba(0,0,0,0.5) 100%)'
            : 'transparent',
          zIndex: 2,
          pointerEvents: 'none'
        }} />

        {/* 地点 - 左上角 */}
        <div style={{
          position: 'absolute',
          top: isMobile ? '8px' : '12px',
          left: isMobile ? '8px' : '12px',
          background: 'rgba(0, 0, 0, 0.6)',
          backdropFilter: 'blur(4px)',
          color: '#fff',
          padding: isMobile ? '4px 8px' : '6px 12px',
          borderRadius: '20px',
          fontSize: isMobile ? '10px' : '12px',
          fontWeight: '600',
          display: 'flex',
          alignItems: 'center',
          gap: '4px',
          zIndex: 3,
          boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
          maxWidth: isMobile ? 'calc(50% - 16px)' : 'auto'
        }}>
          <span>{task.location === 'Online' ? '🌐' : '📍'}</span>
          <span style={{
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis'
          }}>{task.location}</span>
        </div>

        {/* 任务类型 - 右上角 */}
        <div style={{
          position: 'absolute',
          top: isMobile ? '8px' : '12px',
          right: isMobile ? '8px' : '12px',
          background: 'rgba(0, 0, 0, 0.6)',
          backdropFilter: 'blur(4px)',
          color: '#fff',
          padding: isMobile ? '4px 8px' : '6px 12px',
          borderRadius: '20px',
          fontSize: isMobile ? '10px' : '12px',
          fontWeight: '600',
          display: 'flex',
          alignItems: 'center',
          gap: '4px',
          zIndex: 3,
          boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
          maxWidth: isMobile ? 'calc(50% - 16px)' : 'auto'
        }}>
          <span>🏷️</span>
          <span style={{
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis'
          }}>{getTaskTypeLabel(task.task_type)}</span>
        </div>

        {/* 金额/积分 - 右下角 */}
        {(() => {
          const moneyReward = (task.base_reward ?? task.reward) || 0;
          const pointsReward = task.points_reward && task.points_reward > 0 ? task.points_reward : 0;
          const hasMoney = moneyReward > 0;
          const hasPoints = pointsReward > 0;
          
          // 如果只有积分奖励（没有金额或金额为0）
          if (!hasMoney && hasPoints) {
            return (
              <div style={{
                position: 'absolute',
                bottom: isMobile ? '8px' : '12px',
                right: isMobile ? '8px' : '12px',
                background: 'rgba(139, 92, 246, 0.9)',
                backdropFilter: 'blur(4px)',
                color: '#fff',
                padding: isMobile ? '6px 10px' : '8px 14px',
                borderRadius: '20px',
                fontSize: isMobile ? '14px' : '18px',
                fontWeight: '700',
                zIndex: 3,
                boxShadow: '0 2px 12px rgba(139, 92, 246, 0.4)',
                display: 'flex',
                alignItems: 'center',
                gap: '4px'
              }}>
                <span>⭐</span>
                <span>{pointsReward.toLocaleString()} 积分</span>
              </div>
            );
          }
          
          // 如果有金额奖励
          if (hasMoney) {
            return (
              <div style={{
                position: 'absolute',
                bottom: isMobile ? '8px' : '12px',
                right: isMobile ? '8px' : '12px',
                zIndex: 3,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'flex-end',
                gap: '4px'
              }}>
                {/* 金额显示 */}
                <div style={{
                  background: 'rgba(5, 150, 105, 0.9)',
                  backdropFilter: 'blur(4px)',
                  color: '#fff',
                  padding: isMobile ? '6px 10px' : '8px 14px',
                  borderRadius: '20px',
                  fontSize: isMobile ? '14px' : '18px',
                  fontWeight: '700',
                  boxShadow: '0 2px 12px rgba(5, 150, 105, 0.4)',
                  position: 'relative'
                }}>
                  £{moneyReward.toFixed(2)}
                  {/* 积分奖励文本 - 右上角 */}
                  {hasPoints && (
                    <span style={{
                      position: 'absolute',
                      top: '-4px',
                      right: '2px',
                      color: '#fff',
                      fontSize: isMobile ? '9px' : '11px',
                      fontWeight: '600',
                      whiteSpace: 'nowrap',
                      textShadow: '0 1px 3px rgba(0,0,0,0.5)',
                      lineHeight: '1'
                    }}>
                      +{pointsReward.toLocaleString()}积分
                    </span>
                  )}
                </div>
              </div>
            );
          }
          
          // 如果都没有，不显示
          return null;
        })()}

        {/* 截止时间 - 左下角 */}
        <div style={{
          position: 'absolute',
          bottom: isMobile ? '8px' : '12px',
          left: isMobile ? '8px' : '12px',
          background: 'rgba(0, 0, 0, 0.6)',
          backdropFilter: 'blur(4px)',
          color: isExpired(task.deadline) ? '#fca5a5' : 
                 isExpiringSoon(task.deadline) ? '#fde68a' : '#fff',
          padding: isMobile ? '4px 8px' : '6px 12px',
          borderRadius: '20px',
          fontSize: isMobile ? '9px' : '11px',
          fontWeight: '600',
          display: 'flex',
          alignItems: 'center',
          gap: '4px',
          zIndex: 3,
          boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
          maxWidth: isMobile ? 'calc(50% - 16px)' : 'auto'
        }}>
          <span>⏰</span>
          <span style={{
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis'
          }}>
            {isExpired(task.deadline) ? t('home.taskExpired') : 
             isExpiringSoon(task.deadline) ? t('home.taskExpiringSoon') : getRemainTime(task.deadline, t)}
          </span>
        </div>

        {/* 任务等级标签 */}
        {task.task_level && task.task_level !== 'normal' && (
          <div style={{
            position: 'absolute',
            top: isMobile ? '42px' : '48px',
            right: isMobile ? '8px' : '12px',
            background: getTaskLevelColor(task.task_level),
            color: '#fff',
            padding: isMobile ? '3px 8px' : '4px 10px',
            borderRadius: '16px',
            fontSize: isMobile ? '9px' : '11px',
            fontWeight: '700',
            zIndex: 3,
            boxShadow: task.task_level === 'vip' ? '0 2px 8px rgba(245, 158, 11, 0.4)' : 
                      task.task_level === 'super' ? '0 2px 10px rgba(139, 92, 246, 0.5)' : 
                      '0 2px 6px rgba(0,0,0,0.2)'
          }}>
            {getTaskLevelLabel(task.task_level)}
          </div>
        )}
      </div>
      
      {/* 任务标题 */}
      <div style={{
        padding: '12px',
        fontSize: '15px',
        fontWeight: '600',
        color: '#1f2937',
        whiteSpace: isMobile ? 'nowrap' : 'normal',
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        lineHeight: '1.4',
        background: 'transparent',
        display: isMobile ? 'block' : '-webkit-box',
        WebkitLineClamp: isMobile ? 1 : 2,
        WebkitBoxOrient: isMobile ? 'unset' : 'vertical'
      }}>
        <TaskTitle
          title={task.title}
          language={language}
          style={{
            fontSize: 'inherit',
            fontWeight: 'inherit',
            color: 'inherit',
            whiteSpace: isMobile ? 'nowrap' : 'normal',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            display: isMobile ? 'block' : '-webkit-box',
            WebkitLineClamp: isMobile ? 1 : 2,
            WebkitBoxOrient: isMobile ? 'unset' : 'vertical'
          }}
        />
      </div>
    </div>
  );
});

TaskCard.displayName = 'TaskCard';

export default TaskCard;

