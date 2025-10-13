import React from 'react';
import { useCookie } from '../contexts/CookieContext';

const CookieTest: React.FC = () => {
  const { preferences, hasConsented, openSettings } = useCookie();

  return (
    <div style={{ padding: '20px', maxWidth: '800px', margin: '0 auto' }}>
      <h1>Cookie设置测试页面</h1>
      
      <div style={{ marginBottom: '20px' }}>
        <h2>当前状态</h2>
        <p>已同意Cookie: {hasConsented ? '是' : '否'}</p>
        <p>必要Cookie: {preferences.necessary ? '启用' : '禁用'}</p>
        <p>分析Cookie: {preferences.analytics ? '启用' : '禁用'}</p>
        <p>营销Cookie: {preferences.marketing ? '启用' : '禁用'}</p>
        <p>功能Cookie: {preferences.functional ? '启用' : '禁用'}</p>
      </div>

      <div style={{ marginBottom: '20px' }}>
        <button 
          onClick={openSettings}
          style={{
            padding: '10px 20px',
            backgroundColor: '#000',
            color: 'white',
            border: 'none',
            borderRadius: '6px',
            cursor: 'pointer'
          }}
        >
          打开Cookie设置
        </button>
      </div>

      <div style={{ marginBottom: '20px' }}>
        <h2>测试说明</h2>
        <ol>
          <li>刷新页面查看Cookie同意弹窗</li>
          <li>点击"接受"或"拒绝"按钮</li>
          <li>点击"Cookie设置"查看详细设置</li>
          <li>在设置页面中调整各种Cookie类型</li>
          <li>检查本地存储中的Cookie偏好设置</li>
        </ol>
      </div>

      <div>
        <h2>本地存储检查</h2>
        <p>打开浏览器开发者工具，查看Application > Local Storage中的以下键值：</p>
        <ul>
          <li>cookieConsent: 是否已同意</li>
          <li>cookiePreferences: 具体的Cookie偏好设置</li>
        </ul>
      </div>
    </div>
  );
};

export default CookieTest;
