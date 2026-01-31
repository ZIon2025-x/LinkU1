import React from 'react';
import { useLanguage } from '../contexts/LanguageContext';

interface CategoryIconsProps {
  taskTypes: string[];
  getTaskTypeLabel: (taskType: string) => string;
  onTypeClick: (taskType: string) => void;
  selectedType?: string;
}

const CategoryIcons: React.FC<CategoryIconsProps> = React.memo(({
  taskTypes,
  getTaskTypeLabel,
  onTypeClick,
  selectedType
}) => {
  const { t } = useLanguage();
  const icons = ['🏠', '🎓', '🛍️', '🏃', '🔧', '🤝', '🚗', '🐕', '🛒', '📦'];
  const colors = [
    ['#ef4444', '#dc2626'],
    ['#f59e0b', '#d97706'],
    ['#10b981', '#059669'],
    ['#3b82f6', '#2563eb'],
    ['#8b5cf6', '#7c3aed'],
    ['#ec4899', '#db2777'],
    ['#06b6d4', '#0891b2'],
    ['#84cc16', '#65a30d'],
    ['#94a3b8', '#cbd5e1'],
    ['#78716c', '#57534e']
  ];

  return (
    <div style={{ position: 'relative' }}>
      <div className="category-icons" style={{
        display: 'flex',
        gap: '12px',
        justifyContent: 'space-between',
        paddingBottom: '4px',
        flexWrap: 'wrap',
        overflowX: 'auto',
        scrollbarWidth: 'none',
        msOverflowStyle: 'none'
      }}>
        {taskTypes.slice(0, 10).map((taskType, index) => (
        <div
          key={taskType}
          style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: '6px',
            flex: '1',
            minWidth: '90px',
            maxWidth: '140px',
            padding: '6px',
            borderRadius: '12px',
            position: 'relative'
          }}
        >
          <div 
            className={`category-icon-circle ${selectedType === taskType ? 'breathing' : ''}`}
            style={{
              width: '64px',
              height: '64px',
              background: `linear-gradient(135deg, ${colors[index]?.[0] ?? '#ef4444'}, ${colors[index]?.[1] ?? '#dc2626'})`,
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '28px',
              color: '#fff',
              boxShadow: '0 4px 12px rgba(0,0,0,0.15), 0 2px 6px rgba(0,0,0,0.1)',
              transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
              position: 'relative',
              overflow: 'hidden',
              cursor: 'pointer'
            }}
            onMouseEnter={(e) => {
              const isSelected = e.currentTarget.classList.contains('breathing');
              if (!isSelected) {
                e.currentTarget.style.transform = 'scale(1.1) rotate(5deg)';
                e.currentTarget.style.boxShadow = '0 6px 20px rgba(0,0,0,0.2), 0 4px 12px rgba(0,0,0,0.15)';
              }
              const glowEffect = e.currentTarget.querySelector('.icon-glow') as HTMLElement;
              if (glowEffect) {
                glowEffect.style.opacity = '1';
              }
            }}
            onMouseLeave={(e) => {
              const isSelected = e.currentTarget.classList.contains('breathing');
              if (!isSelected) {
                e.currentTarget.style.transform = 'scale(1) rotate(0deg)';
                e.currentTarget.style.boxShadow = '0 4px 12px rgba(0,0,0,0.15), 0 2px 6px rgba(0,0,0,0.1)';
              }
              const glowEffect = e.currentTarget.querySelector('.icon-glow') as HTMLElement;
              if (glowEffect) {
                glowEffect.style.opacity = '0';
              }
            }}
            onClick={(e) => {
              // 如果点击的是已选中的类型，则取消选择（回到全部）
              if (selectedType === taskType) {
                onTypeClick('all');
                // 重置按钮状态，确保没有残留的 transform
                const iconCircle = e.currentTarget;
                // 立即重置，避免依赖 setTimeout
                if (iconCircle && iconCircle.classList) {
                  const isSelected = iconCircle.classList.contains('breathing');
                  if (!isSelected) {
                    iconCircle.style.transform = 'scale(1) rotate(0deg)';
                    iconCircle.style.boxShadow = '0 4px 12px rgba(0,0,0,0.15), 0 2px 6px rgba(0,0,0,0.1)';
                  }
                }
              } else {
                onTypeClick(taskType);
              }
            }}
          >
            <div 
              className="icon-glow"
              style={{
                position: 'absolute',
                top: '-50%',
                left: '-50%',
                width: '200%',
                height: '200%',
                background: 'radial-gradient(circle, rgba(255,255,255,0.3) 0%, transparent 70%)',
                opacity: 0,
                transition: 'opacity 0.3s ease',
                pointerEvents: 'none'
              }}
            />
            <span className="category-emoji-icon" style={{ position: 'relative', zIndex: 1 }}>
              {icons[index]}
            </span>
          </div>
          <span style={{
            fontSize: '14px',
            color: '#374151',
            textAlign: 'center',
            fontWeight: '600',
            lineHeight: '1.4',
            userSelect: 'none',
            pointerEvents: 'none'
          }}>
            {getTaskTypeLabel(taskType)}
          </span>
        </div>
      ))}
      </div>
      {/* 移动端滑动提示 */}
      <div className="category-swipe-hint" style={{
        position: 'absolute',
        bottom: '-2px',
        left: '50%',
        transform: 'translateX(-50%)',
        fontSize: '11px',
        color: '#999',
        whiteSpace: 'nowrap',
        pointerEvents: 'none',
        zIndex: 10,
        display: 'none'
      }}>
        ← {t('tasks.swipeToSeeMore')} →
      </div>
      <style>{`
        /* 呼吸灯动画 */
        @keyframes breathing {
          0%, 100% {
            transform: scale(1) rotate(0deg);
            box-shadow: 0 4px 12px rgba(0,0,0,0.15), 0 2px 6px rgba(0,0,0,0.1);
          }
          50% {
            transform: scale(1.15) rotate(0deg);
            box-shadow: 0 8px 24px rgba(0,0,0,0.25), 0 4px 16px rgba(0,0,0,0.2);
          }
        }
        
        .category-icon-circle.breathing {
          animation: breathing 2s ease-in-out infinite;
        }
        
        /* 确保非选中状态时，hover 效果能正确覆盖动画 */
        .category-icon-circle:not(.breathing):hover {
          animation: none !important;
        }
        
        @media (max-width: 768px) {
          .category-swipe-hint {
            display: block !important;
          }
          /* 移动端增大 emoji 图标大小 */
          .category-icon-circle .category-emoji-icon {
            font-size: 32px !important;
            line-height: 1 !important;
            display: inline-block !important;
          }
        }
        @media (max-width: 480px) {
          .category-icon-circle .category-emoji-icon {
            font-size: 32px !important;
          }
        }
        @media (max-width: 360px) {
          .category-icon-circle .category-emoji-icon {
            font-size: 32px !important;
          }
        }
      `}</style>
    </div>
  );
});

CategoryIcons.displayName = 'CategoryIcons';

export default CategoryIcons;

