import React, { useState } from 'react';
import { message } from 'antd';
import { updateSystemSettings, clearCache } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';

/**
 * 系统设置组件
 */
const Settings: React.FC = () => {
  const [loading, setLoading] = useState(false);
  const [clearingCache, setClearingCache] = useState(false);

  const handleClearCache = async () => {
    setClearingCache(true);
    try {
      await clearCache();
      message.success('缓存清理成功');
    } catch (error: any) {
      message.error(getErrorMessage(error));
    } finally {
      setClearingCache(false);
    }
  };

  return (
    <div>
      <h2 style={{ marginBottom: '20px' }}>系统设置</h2>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
        {/* 缓存管理 */}
        <div style={{ background: 'white', padding: '24px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)' }}>
          <h3 style={{ margin: '0 0 16px 0', fontSize: '16px' }}>缓存管理</h3>
          <p style={{ color: '#666', marginBottom: '16px' }}>
            清理系统缓存可以解决某些数据不同步的问题。建议在更新配置后执行此操作。
          </p>
          <button
            onClick={handleClearCache}
            disabled={clearingCache}
            style={{
              padding: '10px 20px',
              border: 'none',
              background: '#dc3545',
              color: 'white',
              borderRadius: '4px',
              cursor: clearingCache ? 'not-allowed' : 'pointer',
              fontSize: '14px',
              fontWeight: '500',
              opacity: clearingCache ? 0.6 : 1
            }}
          >
            {clearingCache ? '清理中...' : '清理缓存'}
          </button>
        </div>

        {/* 系统信息 */}
        <div style={{ background: 'white', padding: '24px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)' }}>
          <h3 style={{ margin: '0 0 16px 0', fontSize: '16px' }}>系统信息</h3>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px' }}>
            <div>
              <div style={{ color: '#666', fontSize: '12px', marginBottom: '4px' }}>版本</div>
              <div style={{ fontWeight: '500' }}>v1.0.0</div>
            </div>
            <div>
              <div style={{ color: '#666', fontSize: '12px', marginBottom: '4px' }}>环境</div>
              <div style={{ fontWeight: '500' }}>{process.env.NODE_ENV || 'development'}</div>
            </div>
            <div>
              <div style={{ color: '#666', fontSize: '12px', marginBottom: '4px' }}>构建时间</div>
              <div style={{ fontWeight: '500' }}>{new Date().toLocaleDateString('zh-CN')}</div>
            </div>
          </div>
        </div>

        {/* 帮助信息 */}
        <div style={{ background: '#e7f3ff', padding: '16px 20px', borderRadius: '8px', border: '1px solid #b3d7ff' }}>
          <h4 style={{ margin: '0 0 12px 0', color: '#0056b3' }}>帮助信息</h4>
          <ul style={{ margin: 0, paddingLeft: '20px', color: '#333' }}>
            <li>如遇到问题，请先尝试清理缓存</li>
            <li>管理员操作将被记录在系统日志中</li>
            <li>如需技术支持，请联系开发团队</li>
          </ul>
        </div>
      </div>
    </div>
  );
};

export default Settings;
