import React from 'react';

/**
 * Dashboard Component
 * TODO: Extract dashboard content from AdminDashboard.tsx
 */
const Dashboard: React.FC = () => {
  return (
    <div style={{ padding: '24px' }}>
      <h1>仪表盘</h1>
      <p>TODO: 从 AdminDashboard.tsx 中提取仪表盘内容</p>
      <div style={{
        padding: '20px',
        background: '#fff3cd',
        border: '1px solid #ffeaa7',
        borderRadius: '8px',
        marginTop: '16px'
      }}>
        <p style={{ margin: 0, color: '#856404' }}>
          ⚠️ 此组件是占位符，需要从原 AdminDashboard.tsx 中提取完整的仪表盘功能。
        </p>
      </div>
    </div>
  );
};

export default Dashboard;
