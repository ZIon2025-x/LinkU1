import { memo, type FC } from 'react';
import { useTaskSorting } from '../hooks/useTaskSorting';

interface SortControlsProps {
  loadTasks: (isLoadMore: boolean, targetPage?: number, overrideSortBy?: string) => void;
  taskLevel: string;
  showLevelDropdown: boolean;
  setShowLevelDropdown: (show: boolean) => void;
  handleLevelChange: (level: string) => string;
  t: (key: string) => string;
}

const SortControls: FC<SortControlsProps> = memo(({
  loadTasks,
  taskLevel,
  showLevelDropdown,
  setShowLevelDropdown,
  handleLevelChange,
  t
}) => {
  const sorting = useTaskSorting(loadTasks);

  return (
    <div className="sort-controls" style={{
      display: 'flex',
      gap: '12px',
      flex: '1',
      minWidth: '0',
      alignItems: 'center',
      flexWrap: 'wrap'
    }}>
      {/* 任务等级下拉菜单 */}
      <div className="level-dropdown-container" style={{ position: 'relative' }}>
        <div
          onClick={() => setShowLevelDropdown(!showLevelDropdown)}
          style={{
            background: taskLevel !== t('tasks.levels.all') 
              ? taskLevel === t('tasks.levels.vip') 
                ? 'linear-gradient(135deg, #f59e0b 0%, #d97706 100%)'
                : taskLevel === t('tasks.levels.super')
                ? 'linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%)'
                : 'linear-gradient(135deg, #6b7280 0%, #4b5563 100%)'
              : '#ffffff',
            color: taskLevel !== t('tasks.levels.all') ? '#ffffff' : '#374151',
            border: '1px solid #e5e7eb',
            borderRadius: '16px',
            padding: '12px 20px',
            cursor: 'pointer',
            transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            flexShrink: 0,
            boxShadow: taskLevel !== t('tasks.levels.all') 
              ? taskLevel === t('tasks.levels.vip')
                ? '0 8px 25px rgba(245, 158, 11, 0.3)'
                : taskLevel === t('tasks.levels.super')
                ? '0 8px 25px rgba(139, 92, 246, 0.3)'
                : '0 8px 25px rgba(107, 114, 128, 0.3)'
              : '0 2px 8px rgba(0, 0, 0, 0.08)',
            transform: taskLevel !== t('tasks.levels.all') ? 'translateY(-2px)' : 'translateY(0)',
            minWidth: '140px'
          }}
          onMouseEnter={(e) => {
            if (taskLevel === t('tasks.levels.all')) {
              e.currentTarget.style.transform = 'translateY(-1px)';
              e.currentTarget.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.15)';
            }
          }}
          onMouseLeave={(e) => {
            if (taskLevel === t('tasks.levels.all')) {
              e.currentTarget.style.transform = 'translateY(0)';
              e.currentTarget.style.boxShadow = '0 2px 8px rgba(0, 0, 0, 0.08)';
            }
          }}
        >
          <div style={{
            width: '32px',
            height: '32px',
            borderRadius: '50%',
            background: taskLevel !== t('tasks.levels.all') 
              ? 'rgba(255, 255, 255, 0.2)' 
              : '#f3f4f6',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '16px'
          }}>
            {taskLevel === t('tasks.levels.vip') ? '👑' : taskLevel === t('tasks.levels.super') ? '⭐' : '🎯'}
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: '14px', fontWeight: '600' }}>
              {taskLevel}
            </div>
          </div>
          <div style={{
            color: taskLevel !== t('tasks.levels.all') ? '#ffffff' : '#9ca3af',
            fontSize: '12px',
            transition: 'color 0.3s ease',
            transform: showLevelDropdown ? 'rotate(180deg)' : 'rotate(0deg)'
          }}>
            ▼
          </div>
        </div>
        
        {/* 任务等级下拉菜单 */}
        {showLevelDropdown && (
          <div className="custom-dropdown-content show" style={{
            position: 'absolute',
            top: '100%',
            left: 0,
            right: 0,
            background: '#ffffff',
            border: '1px solid #e5e7eb',
            borderRadius: '12px',
            boxShadow: '0 10px 25px rgba(0, 0, 0, 0.15)',
            zIndex: 1000,
            marginTop: '4px',
            overflow: 'hidden',
            width: 'auto',
            minWidth: '120px',
            maxWidth: '160px'
          }}>
            {[
              { key: 'all', icon: '🎯' },
              { key: 'normal', icon: '📋' },
              { key: 'vip', icon: '👑' },
              { key: 'super', icon: '⭐' }
            ].map(({ key, icon }) => (
              <div 
                key={key}
                className={`custom-dropdown-item ${taskLevel === t(`tasks.levels.${key}`) ? 'selected' : ''}`}
                onClick={() => handleLevelChange(t(`tasks.levels.${key}`))}
                style={{
                  padding: '12px 16px',
                  cursor: 'pointer',
                  transition: 'all 0.2s ease',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  fontSize: '14px',
                  fontWeight: '500',
                  color: taskLevel === t(`tasks.levels.${key}`) ? '#ffffff' : '#374151',
                  background: taskLevel === t(`tasks.levels.${key}`) ? '#3b82f6' : 'transparent',
                  borderBottom: key !== 'super' ? '1px solid #f3f4f6' : 'none'
                }}
              >
                <div className="icon" style={{
                  width: '20px',
                  height: '20px',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '16px'
                }}>
                  {icon}
                </div>
                <span>{t(`tasks.levels.${key}`)}</span>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* 最新发布按钮 */}
      <div
        onClick={sorting.handleLatestSort}
        style={{
          background: sorting.sortBy === 'latest' 
            ? 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)' 
            : '#ffffff',
          color: sorting.sortBy === 'latest' ? '#ffffff' : '#374151',
          border: '1px solid #e5e7eb',
          borderRadius: '16px',
          padding: '12px 20px',
          cursor: 'pointer',
          transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          flexShrink: 0,
          boxShadow: sorting.sortBy === 'latest' 
            ? '0 8px 25px rgba(102, 126, 234, 0.3)' 
            : '0 2px 8px rgba(0, 0, 0, 0.08)',
          transform: sorting.sortBy === 'latest' ? 'translateY(-2px)' : 'translateY(0)',
          position: 'relative',
          overflow: 'hidden'
        }}
        onMouseEnter={(e) => {
          if (sorting.sortBy !== 'latest') {
            e.currentTarget.style.transform = 'translateY(-1px)';
            e.currentTarget.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.15)';
          }
        }}
        onMouseLeave={(e) => {
          if (sorting.sortBy !== 'latest') {
            e.currentTarget.style.transform = 'translateY(0)';
            e.currentTarget.style.boxShadow = '0 2px 8px rgba(0, 0, 0, 0.08)';
          }
        }}
      >
        <div style={{
          width: '32px',
          height: '32px',
          borderRadius: '50%',
          background: sorting.sortBy === 'latest' 
            ? 'rgba(255, 255, 255, 0.2)' 
            : '#f3f4f6',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: '16px'
        }}>
          🕒
        </div>
        <div>
          <div style={{ fontSize: '14px', fontWeight: '600' }}>{t('tasks.sorting.latest')}</div>
        </div>
      </div>

      {/* 金额排序卡片 */}
      <div 
        className="reward-dropdown-container" 
        style={{ position: 'relative', zIndex: 10 }}
      >
        <div
          onClick={(e) => {
            e.stopPropagation();
            sorting.setShowRewardDropdown(!sorting.showRewardDropdown);
          }}
          onMouseDown={(e) => {
            e.stopPropagation();
          }}
          style={{
            background: sorting.rewardSort 
              ? 'linear-gradient(135deg, #f093fb 0%, #f5576c 100%)' 
              : '#ffffff',
            color: sorting.rewardSort ? '#ffffff' : '#374151',
            border: '1px solid #e5e7eb',
            borderRadius: '16px',
            padding: '12px 20px',
            cursor: 'pointer',
            transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            flexShrink: 0,
            boxShadow: sorting.rewardSort 
              ? '0 8px 25px rgba(240, 147, 251, 0.3)' 
              : '0 2px 8px rgba(0, 0, 0, 0.08)',
            transform: sorting.rewardSort ? 'translateY(-2px)' : 'translateY(0)',
            minWidth: '140px',
            position: 'relative',
            zIndex: 11,
            pointerEvents: 'auto',
            userSelect: 'none',
            WebkitUserSelect: 'none'
          }}
          onMouseEnter={(e) => {
            if (!sorting.rewardSort) {
              e.currentTarget.style.transform = 'translateY(-1px)';
              e.currentTarget.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.15)';
            }
          }}
          onMouseLeave={(e) => {
            if (!sorting.rewardSort) {
              e.currentTarget.style.transform = 'translateY(0)';
              e.currentTarget.style.boxShadow = '0 2px 8px rgba(0, 0, 0, 0.08)';
            }
          }}
        >
          <div 
            style={{
              width: '32px',
              height: '32px',
              borderRadius: '50%',
              background: sorting.rewardSort 
                ? 'rgba(255, 255, 255, 0.2)' 
                : '#fef3c7',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '16px',
              pointerEvents: 'none'
            }}
          >
            💰
          </div>
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: '6px', pointerEvents: 'none' }}>
            <div style={{ fontSize: '14px', fontWeight: '600' }}>
              {sorting.rewardSort === 'desc' ? t('tasks.sorting.rewardDesc') : 
               sorting.rewardSort === 'asc' ? t('tasks.sorting.rewardAsc') : t('tasks.sorting.rewardSort')}
            </div>
            <div style={{
              color: sorting.rewardSort ? '#ffffff' : '#9ca3af',
              fontSize: '12px',
              transition: 'color 0.3s ease',
              transform: sorting.showRewardDropdown ? 'rotate(180deg)' : 'rotate(0deg)',
              display: 'flex',
              alignItems: 'center'
            }}>
              ▼
            </div>
          </div>
        </div>
        
        {/* 金额排序下拉菜单 */}
        {sorting.showRewardDropdown && (
          <div 
            className="custom-dropdown-content show" 
            onClick={(e) => e.stopPropagation()}
            onMouseDown={(e) => e.stopPropagation()}
            style={{
              position: 'absolute',
              top: '100%',
              left: 0,
              right: 0,
              background: '#ffffff',
              border: '1px solid #e5e7eb',
              borderRadius: '12px',
              boxShadow: '0 10px 25px rgba(0, 0, 0, 0.15)',
              zIndex: 1000,
              marginTop: '4px',
              overflow: 'hidden',
              width: 'auto',
              minWidth: '120px',
              maxWidth: '160px'
            }}>
            <div 
              className={`custom-dropdown-item ${sorting.rewardSort === 'desc' ? 'selected' : ''}`}
              onMouseDown={(e) => e.stopPropagation()}
              onClick={(e) => {
                e.stopPropagation();
                e.preventDefault();
                sorting.handleRewardSortChange('desc');
              }}
              style={{
                padding: '12px 16px',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                fontSize: '14px',
                fontWeight: '500',
                color: sorting.rewardSort === 'desc' ? '#ffffff' : '#374151',
                background: sorting.rewardSort === 'desc' ? '#3b82f6' : 'transparent',
                borderBottom: '1px solid #f3f4f6'
              }}
            >
              <div className="icon" style={{
                width: '20px',
                height: '20px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '16px'
              }}>
                💰
              </div>
              <span>{t('tasks.sorting.rewardDesc')}</span>
            </div>
            <div 
              className={`custom-dropdown-item ${sorting.rewardSort === 'asc' ? 'selected' : ''}`}
              onMouseDown={(e) => e.stopPropagation()}
              onClick={(e) => {
                e.stopPropagation();
                e.preventDefault();
                sorting.handleRewardSortChange('asc');
              }}
              style={{
                padding: '12px 16px',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                fontSize: '14px',
                fontWeight: '500',
                color: sorting.rewardSort === 'asc' ? '#ffffff' : '#374151',
                background: sorting.rewardSort === 'asc' ? '#3b82f6' : 'transparent'
              }}
            >
              <div className="icon" style={{
                width: '20px',
                height: '20px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '16px'
              }}>
                💰
              </div>
              <span>{t('tasks.sorting.rewardAsc')}</span>
            </div>
          </div>
        )}
      </div>

      {/* 截止日期排序卡片 */}
      <div 
        className="deadline-dropdown-container" 
        style={{ position: 'relative', zIndex: 10 }}
      >
        <div
          onClick={(e) => {
            e.stopPropagation();
            sorting.setShowDeadlineDropdown(!sorting.showDeadlineDropdown);
          }}
          onMouseDown={(e) => {
            e.stopPropagation();
          }}
          style={{
            background: sorting.deadlineSort 
              ? 'linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)' 
              : '#ffffff',
            color: sorting.deadlineSort ? '#ffffff' : '#374151',
            border: '1px solid #e5e7eb',
            borderRadius: '16px',
            padding: '12px 20px',
            cursor: 'pointer',
            transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            flexShrink: 0,
            boxShadow: sorting.deadlineSort 
              ? '0 8px 25px rgba(79, 172, 254, 0.3)' 
              : '0 2px 8px rgba(0, 0, 0, 0.08)',
            transform: sorting.deadlineSort ? 'translateY(-2px)' : 'translateY(0)',
            minWidth: '160px',
            position: 'relative',
            zIndex: 11,
            pointerEvents: 'auto',
            userSelect: 'none',
            WebkitUserSelect: 'none'
          }}
          onMouseEnter={(e) => {
            if (!sorting.deadlineSort) {
              e.currentTarget.style.transform = 'translateY(-1px)';
              e.currentTarget.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.15)';
            }
          }}
          onMouseLeave={(e) => {
            if (!sorting.deadlineSort) {
              e.currentTarget.style.transform = 'translateY(0)';
              e.currentTarget.style.boxShadow = '0 2px 8px rgba(0, 0, 0, 0.08)';
            }
          }}
        >
          <div 
            style={{
              width: '32px',
              height: '32px',
              borderRadius: '50%',
              background: sorting.deadlineSort 
                ? 'rgba(255, 255, 255, 0.2)' 
                : '#fef3c7',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '16px',
              pointerEvents: 'none'
            }}
          >
            ⏰
          </div>
          <div style={{ flex: 1, display: 'flex', alignItems: 'center', gap: '6px', pointerEvents: 'none' }}>
            <div style={{ fontSize: '14px', fontWeight: '600' }}>
              {sorting.deadlineSort === 'asc' ? t('tasks.sorting.deadlineAsc') : 
               sorting.deadlineSort === 'desc' ? t('tasks.sorting.deadlineDesc') : t('tasks.sorting.deadlineSort')}
            </div>
            <div style={{
              color: sorting.deadlineSort ? '#ffffff' : '#9ca3af',
              fontSize: '12px',
              transition: 'color 0.3s ease',
              transform: sorting.showDeadlineDropdown ? 'rotate(180deg)' : 'rotate(0deg)',
              display: 'flex',
              alignItems: 'center'
            }}>
              ▼
            </div>
          </div>
        </div>
        
        {/* 截止日期排序下拉菜单 */}
        {sorting.showDeadlineDropdown && (
          <div 
            className="custom-dropdown-content show" 
            onClick={(e) => e.stopPropagation()}
            onMouseDown={(e) => e.stopPropagation()}
            style={{
              position: 'absolute',
              top: '100%',
              left: 0,
              right: 0,
              background: '#ffffff',
              border: '1px solid #e5e7eb',
              borderRadius: '12px',
              boxShadow: '0 10px 25px rgba(0, 0, 0, 0.15)',
              zIndex: 1000,
              marginTop: '4px',
              overflow: 'hidden',
              width: 'auto',
              minWidth: '120px',
              maxWidth: '160px'
            }}>
            <div 
              className={`custom-dropdown-item ${sorting.deadlineSort === 'asc' ? 'selected' : ''}`}
              onMouseDown={(e) => e.stopPropagation()}
              onClick={(e) => {
                e.stopPropagation();
                e.preventDefault();
                sorting.handleDeadlineSortChange('asc');
              }}
              style={{
                padding: '12px 16px',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                fontSize: '14px',
                fontWeight: '500',
                color: sorting.deadlineSort === 'asc' ? '#ffffff' : '#374151',
                background: sorting.deadlineSort === 'asc' ? '#3b82f6' : 'transparent',
                borderBottom: '1px solid #f3f4f6'
              }}
            >
              <div className="icon" style={{
                width: '20px',
                height: '20px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '16px'
              }}>
                ⏰
              </div>
              <span>{t('tasks.sorting.deadlineAsc')}</span>
            </div>
            <div 
              className={`custom-dropdown-item ${sorting.deadlineSort === 'desc' ? 'selected' : ''}`}
              onMouseDown={(e) => e.stopPropagation()}
              onClick={(e) => {
                e.stopPropagation();
                e.preventDefault();
                sorting.handleDeadlineSortChange('desc');
              }}
              style={{
                padding: '12px 16px',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                fontSize: '14px',
                fontWeight: '500',
                color: sorting.deadlineSort === 'desc' ? '#ffffff' : '#374151',
                background: sorting.deadlineSort === 'desc' ? '#3b82f6' : 'transparent'
              }}
            >
              <div className="icon" style={{
                width: '20px',
                height: '20px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '16px'
              }}>
                ⏰
              </div>
              <span>{t('tasks.sorting.deadlineDesc')}</span>
            </div>
          </div>
        )}
      </div>
    </div>
  );
});

SortControls.displayName = 'SortControls';

export default SortControls;

