import React from 'react';
import TaskTitle from './TaskTitle';
import { TASK_TYPES } from '../pages/Tasks';
import { Language } from '../contexts/LanguageContext';
import LazyImage from './LazyImage';
import styles from './TaskCard.module.css';
import { obfuscateLocation } from '../utils/formatUtils';
import { ensureAbsoluteImageUrl } from '../utils/imageUtils';

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
  // 增强：根据推荐理由返回对应的图标
  const getRecommendationReasonIcon = (reason?: string): string => {
    if (!reason) return '⭐';
    if (reason.includes('同校') || reason.includes('学校')) return '🎓';
    if (reason.includes('距离') || reason.includes('km')) return '📍';
    if (reason.includes('活跃时间') || reason.includes('时间段') || reason.includes('当前活跃')) return '⏰';
    if (reason.includes('高评分') || reason.includes('评分')) return '⭐';
    if (reason.includes('新发布') || reason.includes('新任务')) return '✨';
    if (reason.includes('即将截止') || reason.includes('截止')) return '⏳';
    return '⭐';
  };

  // 增强：根据推荐理由返回对应的样式
  const getRecommendationReasonStyle = (reason?: string): { background: string; shadowColor: string } => {
    if (!reason) {
      return {
        background: 'linear-gradient(135deg, #ff6b6b, #ee5a6f)',
        shadowColor: 'rgba(255, 107, 107, 0.4)'
      };
    }
    if (reason.includes('同校') || reason.includes('学校')) {
      return {
        background: 'linear-gradient(135deg, #4a90e2, #357abd)',
        shadowColor: 'rgba(74, 144, 226, 0.4)'
      };
    }
    if (reason.includes('距离') || reason.includes('km')) {
      return {
        background: 'linear-gradient(135deg, #52c41a, #389e0d)',
        shadowColor: 'rgba(82, 196, 26, 0.4)'
      };
    }
    if (reason.includes('活跃时间') || reason.includes('时间段') || reason.includes('当前活跃')) {
      return {
        background: 'linear-gradient(135deg, #fa8c16, #d46b08)',
        shadowColor: 'rgba(250, 140, 22, 0.4)'
      };
    }
    if (reason.includes('高评分') || reason.includes('评分')) {
      return {
        background: 'linear-gradient(135deg, #fadb14, #d4b106)',
        shadowColor: 'rgba(250, 219, 20, 0.4)'
      };
    }
    if (reason.includes('新发布') || reason.includes('新任务')) {
      return {
        background: 'linear-gradient(135deg, #9254de, #722ed1)',
        shadowColor: 'rgba(146, 84, 222, 0.4)'
      };
    }
    if (reason.includes('即将截止') || reason.includes('截止')) {
      return {
        background: 'linear-gradient(135deg, #ff4d4f, #cf1322)',
        shadowColor: 'rgba(255, 77, 79, 0.4)'
      };
    }
    return {
      background: 'linear-gradient(135deg, #ff6b6b, #ee5a6f)',
      shadowColor: 'rgba(255, 107, 107, 0.4)'
    };
  };

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
            src={ensureAbsoluteImageUrl(String(task.images[0]))}
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

        {/* 增强：推荐标记 - 左上角（优化推荐理由显示） */}
        {task.is_recommended && (
          <div 
            style={{
              position: 'absolute',
              top: isMobile ? '8px' : '12px',
              left: isMobile ? '8px' : '12px',
              background: getRecommendationReasonStyle(task.recommendation_reason).background,
              backdropFilter: 'blur(4px)',
              color: '#fff',
              padding: isMobile ? '4px 8px' : '6px 12px',
              borderRadius: '20px',
              fontSize: isMobile ? '10px' : '12px',
              fontWeight: '700',
              display: 'flex',
              alignItems: 'center',
              gap: '4px',
              zIndex: 4,
              boxShadow: `0 2px 8px ${getRecommendationReasonStyle(task.recommendation_reason).shadowColor}`,
              animation: 'pulse 2s ease-in-out infinite',
              cursor: 'pointer',
              maxWidth: isMobile ? 'calc(100% - 16px)' : 'calc(100% - 24px)'
            }}
            onClick={(e) => {
              e.stopPropagation();
              // 可以在这里添加反馈功能
            }}
            title={task.recommendation_reason || (language === 'zh' ? '推荐任务' : 'Recommended task')}
          >
            <span>{getRecommendationReasonIcon(task.recommendation_reason)}</span>
            {task.recommendation_reason ? (
              <span style={{ 
                overflow: 'hidden', 
                textOverflow: 'ellipsis', 
                whiteSpace: 'nowrap',
                maxWidth: isMobile ? '80px' : '120px'
              }}>
                {task.recommendation_reason}
              </span>
            ) : (
              <span>{language === 'zh' ? '推荐' : 'Recommended'}</span>
            )}
            {task.match_score && (
              <span style={{ opacity: 0.9, fontSize: isMobile ? '9px' : '11px' }}>
                {Math.round(task.match_score * 100)}%
              </span>
            )}
          </div>
        )}

        {/* 地点 - 左上角（如果没有推荐标记）或右上角 */}
        <div style={{
          position: 'absolute',
          top: isMobile ? '8px' : '12px',
          left: task.is_recommended ? 'auto' : (isMobile ? '8px' : '12px'),
          right: task.is_recommended ? (isMobile ? '8px' : '12px') : 'auto',
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
          // 显示最终任务金额：如果有议价且已批准，显示议价金额，否则显示原始金额
          const moneyReward = (task.agreed_reward ?? task.base_reward ?? task.reward) || 0;
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
          taskId={task.id}
          task={task}
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

