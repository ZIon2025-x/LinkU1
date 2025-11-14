import React from 'react';
import { TASK_TYPES } from '../pages/Tasks';

interface CategoryIconsProps {
  taskTypes: string[];
  getTaskTypeLabel: (taskType: string) => string;
  onTypeClick: (taskType: string) => void;
}

const CategoryIcons: React.FC<CategoryIconsProps> = React.memo(({
  taskTypes,
  getTaskTypeLabel,
  onTypeClick
}) => {
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
    <div className="category-icons" style={{
      display: 'flex',
      gap: '16px',
      justifyContent: 'space-between',
      paddingBottom: '8px',
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
            gap: '10px',
            flex: '1',
            minWidth: '90px',
            maxWidth: '140px',
            cursor: 'pointer',
            padding: '12px',
            borderRadius: '12px',
            transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
            position: 'relative'
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = 'linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%)';
            e.currentTarget.style.transform = 'translateY(-4px)';
            e.currentTarget.style.boxShadow = '0 8px 24px rgba(0,0,0,0.12)';
            const iconCircle = e.currentTarget.querySelector('.category-icon-circle') as HTMLElement;
            if (iconCircle) {
              iconCircle.style.transform = 'scale(1.1) rotate(5deg)';
              iconCircle.style.boxShadow = '0 6px 20px rgba(0,0,0,0.2), 0 4px 12px rgba(0,0,0,0.15)';
            }
            const glowEffect = e.currentTarget.querySelector('.icon-glow') as HTMLElement;
            if (glowEffect) {
              glowEffect.style.opacity = '1';
            }
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = 'transparent';
            e.currentTarget.style.transform = 'translateY(0)';
            e.currentTarget.style.boxShadow = 'none';
            const iconCircle = e.currentTarget.querySelector('.category-icon-circle') as HTMLElement;
            if (iconCircle) {
              iconCircle.style.transform = 'scale(1) rotate(0deg)';
              iconCircle.style.boxShadow = '0 4px 12px rgba(0,0,0,0.15), 0 2px 6px rgba(0,0,0,0.1)';
            }
            const glowEffect = e.currentTarget.querySelector('.icon-glow') as HTMLElement;
            if (glowEffect) {
              glowEffect.style.opacity = '0';
            }
          }}
          onClick={() => onTypeClick(taskType)}
        >
          <div 
            className="category-icon-circle"
            style={{
              width: '64px',
              height: '64px',
              background: `linear-gradient(135deg, ${colors[index][0]}, ${colors[index][1]})`,
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '28px',
              color: '#fff',
              boxShadow: '0 4px 12px rgba(0,0,0,0.15), 0 2px 6px rgba(0,0,0,0.1)',
              transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
              position: 'relative',
              overflow: 'hidden'
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
            <span style={{ position: 'relative', zIndex: 1 }}>
              {icons[index]}
            </span>
          </div>
          <span style={{
            fontSize: '14px',
            color: '#374151',
            textAlign: 'center',
            fontWeight: '600',
            lineHeight: '1.4',
            transition: 'color 0.2s ease'
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.color = '#1f2937';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.color = '#374151';
          }}
          >
            {getTaskTypeLabel(taskType)}
          </span>
        </div>
      ))}
    </div>
  );
});

CategoryIcons.displayName = 'CategoryIcons';

export default CategoryIcons;

