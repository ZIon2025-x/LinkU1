import React from 'react';
import TaskTitle from './TaskTitle';
import { TASK_TYPES } from '../pages/Tasks';
import { Language } from '../contexts/LanguageContext';
import LazyImage from './LazyImage';
import styles from './TaskCard.module.css';
import { obfuscateLocation } from '../utils/formatUtils';

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
  // 根据任务等级确定卡片样式类名
  const getCardClassName = () => {
    const baseClass = styles.taskCard;
    if (task.task_level === 'vip') {
      return `${baseClass} ${styles.taskCardVip}`;
    } else if (task.task_level === 'super') {
      return `${baseClass} ${styles.taskCardSuper}`;
    }
    return baseClass;
  };

  // 根据任务等级确定标签样式类名
  const getLevelBadgeClassName = () => {
    const baseClass = isMobile ? styles.levelBadgeMobile : styles.levelBadge;
    if (task.task_level === 'vip') {
      return `${baseClass} ${styles.levelBadgeVip}`;
    } else if (task.task_level === 'super') {
      return `${baseClass} ${styles.levelBadgeSuper}`;
    }
    return baseClass;
  };

  return (
    <div
      className={getCardClassName()}
      onClick={() => onViewTask(task.id)}
    >
      {/* 任务图片区域 */}
      <div 
        className={`${styles.imageContainer} ${isMobile ? styles.imageContainerMobile : ''}`}
        style={{
          background: `linear-gradient(135deg, ${getTaskLevelColor(task.task_level)}20, ${getTaskLevelColor(task.task_level)}40)`
        }}
      >
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
          <LazyImage
            key={`task-img-${task.id}-${String(task.images[0])}`}
            src={String(task.images[0])}
            alt={task.title}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: '100%',
              maxWidth: '100%',
              maxHeight: '100%',
              objectFit: 'cover',
              zIndex: 1,
              backgroundColor: 'transparent',
              display: 'block'
            }}
            onLoad={() => {
              const placeholder = document.querySelector(`.task-icon-placeholder-${task.id}`) as HTMLElement;
              if (placeholder) {
                placeholder.style.display = 'none';
              }
            }}
            onError={() => {
              const placeholder = document.querySelector(`.task-icon-placeholder-${task.id}`) as HTMLElement;
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
                const parentElement = document.querySelector(`.task-card-${task.id}`) || document.querySelector(`[data-task-id="${task.id}"]`);
                if (parentElement) {
                  parentElement.appendChild(placeholderDiv);
                }
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
          <span>{task.location?.toLowerCase() === 'online' ? '🌐' : '📍'}</span>
          <span style={{
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis'
          }}>{obfuscateLocation(task.location)}</span>
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
                      top: '-2px',
                      right: '0px',
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
          <div 
            className={getLevelBadgeClassName()}
            style={{
              background: getTaskLevelColor(task.task_level)
            }}
          >
            {getTaskLevelLabel(task.task_level)}
          </div>
        )}
      </div>
      
      {/* 任务标题 */}
      <div className={`${styles.taskTitle} ${isMobile ? styles.taskTitleMobile : styles.taskTitleDesktop}`}>
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

