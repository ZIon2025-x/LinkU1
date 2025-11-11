/**
 * TaskDetailSkeleton 组件
 * 任务详情页面的骨架屏加载状态
 */
import React from 'react';

const TaskDetailSkeleton: React.FC = () => {
  return (
    <div style={{ padding: '40px' }}>
      {/* 标题骨架 */}
      <div style={{
        height: '32px',
        width: '60%',
        background: '#e5e7eb',
        borderRadius: '4px',
        marginBottom: '20px',
        animation: 'pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite'
      }} />
      
      {/* 信息卡片骨架 */}
      <div style={{ 
        display: 'grid', 
        gridTemplateColumns: 'repeat(2, 1fr)', 
        gap: '20px', 
        marginBottom: '32px' 
      }}>
        {[1, 2, 3, 4].map(i => (
          <div
            key={i}
            style={{
              height: '100px',
              background: '#f3f4f6',
              borderRadius: '12px',
              animation: 'pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite'
            }}
          />
        ))}
      </div>
      
      {/* 描述骨架 */}
      <div style={{
        height: '200px',
        background: '#f3f4f6',
        borderRadius: '12px',
        marginBottom: '20px',
        animation: 'pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite'
      }} />
      
      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.5; }
        }
      `}</style>
    </div>
  );
};

export default TaskDetailSkeleton;

