import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api';
import { getPublicSystemSettings } from '../api';
import { useLanguage } from '../contexts/LanguageContext';

const VIP: React.FC = () => {
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [systemSettings, setSystemSettings] = useState({
    vip_button_visible: true,
    vip_price_threshold: 10.0,
    super_vip_price_threshold: 50.0,
    vip_enabled: true,
    super_vip_enabled: true
  });
  const navigate = useNavigate();
  const { t } = useLanguage();

  useEffect(() => {
    const loadUser = async () => {
      try {
        const response = await api.get('/api/users/profile/me');
        setUser(response.data);
      } catch (error) {
        console.error('获取用户信息失败:', error);
      } finally {
        setLoading(false);
      }
    };

    const loadSystemSettings = async () => {
      try {
        const settings = await getPublicSystemSettings();
        setSystemSettings(settings);
      } catch (error) {
        console.error('加载系统设置失败:', error);
        setSystemSettings({ 
          vip_button_visible: true,
          vip_price_threshold: 10.0,
          super_vip_price_threshold: 50.0,
          vip_enabled: true,
          super_vip_enabled: true
        }); // 默认显示
      }
    };

    loadUser();
    loadSystemSettings();
  }, []);

  const getLevelColor = (level: string) => {
    switch (level) {
      case 'normal': return '#6c757d';
      case 'vip': return '#ffc107';
      case 'super': return '#dc3545';
      default: return '#6c757d';
    }
  };

  const getLevelText = (level: string) => {
    switch (level) {
      case 'normal': return '普通用户';
      case 'vip': return 'VIP会员';
      case 'super': return '超级会员';
      default: return '普通用户';
    }
  };

  const handleUpgrade = (level: string) => {
    // 这里可以添加支付逻辑
    alert(`升级到${getLevelText(level)}功能正在开发中，请联系管理员手动升级！`);
  };

  if (loading) {
    return (
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100vh',
        fontSize: '18px',
        color: '#666'
      }}>
        加载中...
      </div>
    );
  }

  // 如果VIP按钮被禁用，显示提示并重定向
  if (!systemSettings.vip_button_visible) {
    return (
      <div style={{
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100vh',
        padding: '20px',
        textAlign: 'center'
      }}>
        <div style={{
          fontSize: '48px',
          marginBottom: '20px'
        }}>
          🚫
        </div>
        <h1 style={{ 
          position: 'absolute',
          top: '-100px',
          left: '-100px',
          width: '1px',
          height: '1px',
          padding: '0',
          margin: '0',
          overflow: 'hidden',
          clip: 'rect(0, 0, 0, 0)',
          whiteSpace: 'nowrap',
          border: '0',
          fontSize: '1px',
          color: 'transparent',
          background: 'transparent'
        }}>
          VIP功能暂时不可用
        </h1>
        <p style={{
          fontSize: '16px',
          color: '#666',
          marginBottom: '24px',
          maxWidth: '400px'
        }}>
          管理员已暂时禁用VIP功能，请稍后再试或联系客服了解详情。
        </p>
        <button
          onClick={() => navigate('/')}
          style={{
            background: 'linear-gradient(135deg, #3b82f6, #8b5cf6)',
            color: '#fff',
            border: 'none',
            padding: '12px 24px',
            borderRadius: '8px',
            fontSize: '16px',
            fontWeight: '600',
            cursor: 'pointer',
            transition: 'all 0.3s ease'
          }}
        >
          返回首页
        </button>
      </div>
    );
  }

  return (
    <div style={{ minHeight: '100vh', background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)', paddingTop: '80px' }}>
      <div style={{ maxWidth: '1200px', margin: '0 auto', padding: '40px 20px' }}>
        {/* 页面标题 */}
        <div style={{ textAlign: 'center', marginBottom: '60px' }}>
          <h1 style={{ 
            position: 'absolute',
            top: '-100px',
            left: '-100px',
            width: '1px',
            height: '1px',
            padding: '0',
            margin: '0',
            overflow: 'hidden',
            clip: 'rect(0, 0, 0, 0)',
            whiteSpace: 'nowrap',
            border: '0',
            fontSize: '1px',
            color: 'transparent',
            background: 'transparent'
          }}>
            ✨ VIP会员中心
          </h1>
          <p style={{ 
            fontSize: '20px', 
            color: 'rgba(255,255,255,0.9)', 
            marginBottom: '30px' 
          }}>
            解锁更多特权，享受专属服务
          </p>
          
          {/* 当前用户状态 */}
          {user && (
            <div style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '15px',
              background: 'rgba(255,255,255,0.1)',
              padding: '15px 30px',
              borderRadius: '25px',
              backdropFilter: 'blur(10px)',
              border: '1px solid rgba(255,255,255,0.2)'
            }}>
              <span style={{ color: '#fff', fontSize: '16px' }}>当前状态：</span>
              <span style={{
                padding: '8px 16px',
                borderRadius: '20px',
                fontSize: '16px',
                fontWeight: 'bold',
                color: '#fff',
                background: getLevelColor(user.user_level),
                boxShadow: '0 2px 8px rgba(0,0,0,0.2)'
              }}>
                {getLevelText(user.user_level)}
              </span>
            </div>
          )}
        </div>

        {/* 会员套餐 */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(350px, 1fr))',
          gap: '30px',
          marginBottom: '60px'
        }}>
          {/* 普通用户 */}
          <div style={{
            background: 'rgba(255,255,255,0.95)',
            borderRadius: '20px',
            padding: '40px 30px',
            textAlign: 'center',
            boxShadow: '0 10px 30px rgba(0,0,0,0.1)',
            border: user?.user_level === 'normal' ? '3px solid #6c757d' : '1px solid #e0e0e0',
            position: 'relative',
            transform: user?.user_level === 'normal' ? 'scale(1.05)' : 'scale(1)',
            transition: 'all 0.3s ease'
          }}>
            {user?.user_level === 'normal' && (
              <div style={{
                position: 'absolute',
                top: '-15px',
                left: '50%',
                transform: 'translateX(-50%)',
                background: '#6c757d',
                color: '#fff',
                padding: '8px 20px',
                borderRadius: '20px',
                fontSize: '14px',
                fontWeight: 'bold'
              }}>
                当前套餐
              </div>
            )}
            <div style={{ fontSize: '32px', marginBottom: '20px' }}>👤</div>
            <h3 style={{ fontSize: '24px', fontWeight: 'bold', color: '#333', marginBottom: '15px' }}>普通用户</h3>
            <div style={{ fontSize: '36px', fontWeight: 'bold', color: '#6c757d', marginBottom: '30px' }}>免费</div>
            <ul style={{ textAlign: 'left', marginBottom: '30px', padding: '0 20px' }}>
              <li style={{ marginBottom: '10px', color: '#666' }}>✓ 基础任务发布</li>
              <li style={{ marginBottom: '10px', color: '#666' }}>✓ 基础任务接取</li>
              <li style={{ marginBottom: '10px', color: '#666' }}>✓ 基础客服支持</li>
              <li style={{ marginBottom: '10px', color: '#999' }}>✗ 优先任务推荐</li>
              <li style={{ marginBottom: '10px', color: '#999' }}>✗ 专属客服服务</li>
              <li style={{ marginBottom: '10px', color: '#999', fontSize: '14px' }}>✗ 发布VIP任务 (≥{systemSettings.vip_price_threshold}元)</li>
            </ul>
            <button
              onClick={() => handleUpgrade('normal')}
              disabled={user?.user_level === 'normal'}
              style={{
                width: '100%',
                padding: '15px',
                border: 'none',
                borderRadius: '10px',
                fontSize: '16px',
                fontWeight: 'bold',
                cursor: user?.user_level === 'normal' ? 'default' : 'pointer',
                background: user?.user_level === 'normal' ? '#e0e0e0' : '#6c757d',
                color: user?.user_level === 'normal' ? '#999' : '#fff',
                transition: 'all 0.3s ease'
              }}
            >
              {user?.user_level === 'normal' ? '当前套餐' : '选择此套餐'}
            </button>
          </div>

          {/* VIP会员 */}
          <div style={{
            background: 'rgba(255,255,255,0.95)',
            borderRadius: '20px',
            padding: '40px 30px',
            textAlign: 'center',
            boxShadow: '0 10px 30px rgba(0,0,0,0.1)',
            border: user?.user_level === 'vip' ? '3px solid #ffc107' : '1px solid #e0e0e0',
            position: 'relative',
            transform: user?.user_level === 'vip' ? 'scale(1.05)' : 'scale(1)',
            transition: 'all 0.3s ease'
          }}>
            {user?.user_level === 'vip' && (
              <div style={{
                position: 'absolute',
                top: '-15px',
                left: '50%',
                transform: 'translateX(-50%)',
                background: '#ffc107',
                color: '#fff',
                padding: '8px 20px',
                borderRadius: '20px',
                fontSize: '14px',
                fontWeight: 'bold'
              }}>
                当前套餐
              </div>
            )}
            <div style={{ fontSize: '32px', marginBottom: '20px' }}>⭐</div>
            <h3 style={{ fontSize: '24px', fontWeight: 'bold', color: '#333', marginBottom: '15px' }}>VIP会员</h3>
            <div style={{ fontSize: '36px', fontWeight: 'bold', color: '#ffc107', marginBottom: '30px' }}>¥29/月</div>
            <ul style={{ textAlign: 'left', marginBottom: '30px', padding: '0 20px' }}>
              <li style={{ marginBottom: '10px', color: '#666' }}>✓ 所有普通用户功能</li>
              <li style={{ marginBottom: '10px', color: '#666' }}>✓ 优先任务推荐</li>
              <li style={{ marginBottom: '10px', color: '#666' }}>✓ 专属客服服务</li>
              <li style={{ marginBottom: '10px', color: '#666' }}>✓ 任务发布数量翻倍</li>
              <li style={{ marginBottom: '10px', color: '#666', fontSize: '14px' }}>✓ 发布VIP任务 (≥{systemSettings.vip_price_threshold}元)</li>
              <li style={{ marginBottom: '10px', color: '#999', fontSize: '14px' }}>✗ 发布超级任务 (≥{systemSettings.super_vip_price_threshold}元)</li>
            </ul>
            <button
              onClick={() => handleUpgrade('vip')}
              disabled={user?.user_level === 'vip'}
              style={{
                width: '100%',
                padding: '15px',
                border: 'none',
                borderRadius: '10px',
                fontSize: '16px',
                fontWeight: 'bold',
                cursor: user?.user_level === 'vip' ? 'default' : 'pointer',
                background: user?.user_level === 'vip' ? '#e0e0e0' : '#ffc107',
                color: user?.user_level === 'vip' ? '#999' : '#fff',
                transition: 'all 0.3s ease'
              }}
            >
              {user?.user_level === 'vip' ? '当前套餐' : '升级到VIP'}
            </button>
          </div>

          {/* 超级会员 */}
          <div style={{
            background: 'rgba(255,255,255,0.95)',
            borderRadius: '20px',
            padding: '40px 30px',
            textAlign: 'center',
            boxShadow: '0 10px 30px rgba(0,0,0,0.1)',
            border: user?.user_level === 'super' ? '3px solid #dc3545' : '1px solid #e0e0e0',
            position: 'relative',
            transform: user?.user_level === 'super' ? 'scale(1.05)' : 'scale(1)',
            transition: 'all 0.3s ease'
          }}>
            {user?.user_level === 'super' && (
              <div style={{
                position: 'absolute',
                top: '-15px',
                left: '50%',
                transform: 'translateX(-50%)',
                background: '#dc3545',
                color: '#fff',
                padding: '8px 20px',
                borderRadius: '20px',
                fontSize: '14px',
                fontWeight: 'bold'
              }}>
                当前套餐
              </div>
            )}
            <div style={{ fontSize: '32px', marginBottom: '20px' }}>👑</div>
            <h3 style={{ fontSize: '24px', fontWeight: 'bold', color: '#333', marginBottom: '15px' }}>超级会员</h3>
            <div style={{ fontSize: '36px', fontWeight: 'bold', color: '#dc3545', marginBottom: '30px' }}>¥99/月</div>
            <ul style={{ textAlign: 'left', marginBottom: '30px', padding: '0 20px' }}>
              <li style={{ marginBottom: '10px', color: '#666' }}>✓ 所有VIP会员功能</li>
              <li style={{ marginBottom: '10px', color: '#666' }}>✓ 无限任务发布</li>
              <li style={{ marginBottom: '10px', color: '#666' }}>✓ 专属高级客服</li>
              <li style={{ marginBottom: '10px', color: '#666' }}>✓ 任务优先展示</li>
              <li style={{ marginBottom: '10px', color: '#666' }}>✓ 专属会员标识</li>
              <li style={{ marginBottom: '10px', color: '#666', fontSize: '14px' }}>✓ 发布VIP任务 (≥{systemSettings.vip_price_threshold}元)</li>
              <li style={{ marginBottom: '10px', color: '#666', fontSize: '14px' }}>✓ 发布超级任务 (≥{systemSettings.super_vip_price_threshold}元)</li>
            </ul>
            <button
              onClick={() => handleUpgrade('super')}
              disabled={user?.user_level === 'super'}
              style={{
                width: '100%',
                padding: '15px',
                border: 'none',
                borderRadius: '10px',
                fontSize: '16px',
                fontWeight: 'bold',
                cursor: user?.user_level === 'super' ? 'default' : 'pointer',
                background: user?.user_level === 'super' ? '#e0e0e0' : '#dc3545',
                color: user?.user_level === 'super' ? '#999' : '#fff',
                transition: 'all 0.3s ease'
              }}
            >
              {user?.user_level === 'super' ? '当前套餐' : '升级到超级会员'}
            </button>
          </div>
        </div>

        {/* 常见问题 */}
        <div style={{
          background: 'rgba(255,255,255,0.95)',
          borderRadius: '20px',
          padding: '40px',
          marginBottom: '40px'
        }}>
          <h2 style={{ fontSize: '28px', fontWeight: 'bold', color: '#333', marginBottom: '30px', textAlign: 'center' }}>
            💡 常见问题
          </h2>
          <div style={{ display: 'grid', gap: '20px' }}>
            <div style={{ padding: '20px', background: '#f8f9fa', borderRadius: '10px' }}>
              <h4 style={{ fontSize: '18px', fontWeight: 'bold', color: '#333', marginBottom: '10px' }}>
                Q: 如何升级会员？
              </h4>
              <p style={{ color: '#666', lineHeight: '1.6' }}>
                A: 目前会员升级功能正在开发中，您可以联系管理员手动升级，或等待自动升级功能上线。
              </p>
            </div>
            <div style={{ padding: '20px', background: '#f8f9fa', borderRadius: '10px' }}>
              <h4 style={{ fontSize: '18px', fontWeight: 'bold', color: '#333', marginBottom: '10px' }}>
                Q: 会员权益何时生效？
              </h4>
              <p style={{ color: '#666', lineHeight: '1.6' }}>
                A: 会员权益在升级后立即生效，您可以立即享受相应的特权服务。
              </p>
            </div>
            <div style={{ padding: '20px', background: '#f8f9fa', borderRadius: '10px' }}>
              <h4 style={{ fontSize: '18px', fontWeight: 'bold', color: '#333', marginBottom: '10px' }}>
                Q: 可以随时取消会员吗？
              </h4>
              <p style={{ color: '#666', lineHeight: '1.6' }}>
                A: 是的，您可以随时联系管理员取消会员服务，取消后将在下个计费周期生效。
              </p>
            </div>
          </div>
        </div>

        {/* 联系管理员 */}
        <div style={{
          background: 'rgba(255,255,255,0.1)',
          borderRadius: '20px',
          padding: '40px',
          textAlign: 'center',
          backdropFilter: 'blur(10px)',
          border: '1px solid rgba(255,255,255,0.2)'
        }}>
          <h3 style={{ fontSize: '24px', fontWeight: 'bold', color: '#fff', marginBottom: '20px' }}>
            📞 需要帮助？
          </h3>
          <p style={{ fontSize: '16px', color: 'rgba(255,255,255,0.9)', marginBottom: '30px' }}>
            如果您对会员服务有任何疑问，请联系我们的客服团队
          </p>
          <button
            onClick={() => navigate('/message')}
            style={{
              padding: '15px 30px',
              border: 'none',
              borderRadius: '25px',
              fontSize: '16px',
              fontWeight: 'bold',
              background: '#fff',
              color: '#667eea',
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              boxShadow: '0 4px 15px rgba(0,0,0,0.2)'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'translateY(-2px)';
              e.currentTarget.style.boxShadow = '0 6px 20px rgba(0,0,0,0.3)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'translateY(0)';
              e.currentTarget.style.boxShadow = '0 4px 15px rgba(0,0,0,0.2)';
            }}
          >
            联系客服
          </button>
        </div>
      </div>
    </div>
  );
};

export default VIP;
