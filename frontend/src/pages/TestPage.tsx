import React from 'react';

const TestPage: React.FC = () => {
  return (
    <div style={{ 
      padding: '40px', 
      textAlign: 'center',
      minHeight: '100vh',
      background: '#f0f0f0'
    }}>
      <h1>测试页面</h1>
      <p>如果你能看到这个页面，说明React应用正在正常工作。</p>
      <p>当前时间: {new Date().toLocaleString()}</p>
    </div>
  );
};

export default TestPage;
