import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { message } from 'antd';
import { clearCache } from '../../../api';
import { getErrorMessage } from '../../../utils/errorHandler';
import { API_BASE_URL } from '../../../config';
import SystemSettings from '../../../components/SystemSettings';

/**
 * 系统设置组件
 */
const Settings: React.FC = () => {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [clearingCache, setClearingCache] = useState(false);
  const [showSystemSettings, setShowSystemSettings] = useState(false);

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
        {/* 系统配置：VIP / 积分 / 签到 */}
        <div style={{ background: 'white', padding: '24px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)' }}>
          <h3 style={{ margin: '0 0 16px 0', fontSize: '16px' }}>系统配置</h3>
          <p style={{ color: '#666', marginBottom: '16px', fontSize: '14px' }}>
            配置 VIP 等级、积分规则、签到奖励等业务参数。
          </p>
          <button
            onClick={() => setShowSystemSettings(true)}
            style={{
              padding: '10px 20px', border: '1px solid #d9d9d9', background: 'white',
              borderRadius: '4px', cursor: 'pointer', fontSize: '14px'
            }}
          >
            ⚙️ 打开系统配置
          </button>
        </div>

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
              <div style={{ fontWeight: '500' }}>
                {process.env.NODE_ENV === 'production' ? '生产环境' : '开发环境'}
              </div>
            </div>
            <div>
              <div style={{ color: '#666', fontSize: '12px', marginBottom: '4px' }}>后端地址</div>
              <div style={{ fontWeight: '500', fontSize: '12px', wordBreak: 'break-all' }}>{API_BASE_URL}</div>
            </div>
          </div>
        </div>

        {/* 安全设置 */}
        <div style={{ background: 'white', padding: '24px', borderRadius: '8px', boxShadow: '0 2px 4px rgba(0,0,0,0.1)' }}>
          <h3 style={{ margin: '0 0 16px 0', fontSize: '16px' }}>安全设置</h3>
          <p style={{ color: '#666', marginBottom: '16px', fontSize: '14px' }}>
            管理双因素认证 (2FA) 和账号安全。
          </p>
          <button
            onClick={() => navigate('/admin/2fa')}
            style={{
              padding: '10px 20px', border: '1px solid #d9d9d9', background: 'white',
              borderRadius: '4px', cursor: 'pointer', fontSize: '14px'
            }}
          >
            🔐 管理双因素认证 (2FA)
          </button>
        </div>
      </div>

      {showSystemSettings && (
        <SystemSettings onClose={() => setShowSystemSettings(false)} />
      )}
    </div>
  );
};

export default Settings;
