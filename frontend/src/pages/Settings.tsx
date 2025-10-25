import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

const Settings: React.FC = () => {
  const navigate = useNavigate();
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('profile');
  const [sessions, setSessions] = useState<Array<any>>([]);
  const [sessionsLoading, setSessionsLoading] = useState(false);
  const [sessionsError, setSessionsError] = useState<string>('');
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    phone: '',
    timezone: 'UTC',
    notifications: {
      email: true,
      sms: false,
      push: true
    },
    privacy: {
      profile_public: true,
      show_contact: false,
      show_tasks: true
    }
  });

  useEffect(() => {
    // 加载用户数据
    loadUserData();
  }, []);

  // 切换到安全设置时加载会话列表
  useEffect(() => {
    if (activeTab === 'security') {
      void loadSessions();
    }
  }, [activeTab]);

  const loadUserData = async () => {
    try {
      setLoading(true);
      // TODO: 调用真实的用户设置API
      // const userData = await getUserSettings();
      // setUser(userData);
      // setFormData(userData.settings);
      
      // 暂时显示空数据，等待后端API实现
      setUser(null);
      setFormData({
        name: '',
        email: '',
        phone: '',
        timezone: 'UTC',
        notifications: {
          email: true,
          sms: false,
          push: true
        },
        privacy: {
          profile_public: true,
          show_contact: false,
          show_tasks: true
        }
      });
    } catch (error) {
      console.error('加载用户设置失败:', error);
      setUser(null);
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = (field: string, value: any) => {
    if (field.includes('.')) {
      const [parent, child] = field.split('.');
      setFormData(prev => ({
        ...prev,
        [parent]: {
          ...(prev[parent as keyof typeof prev] as any),
          [child]: value
        }
      }));
    } else {
      setFormData(prev => ({
        ...prev,
        [field]: value
      }));
    }
  };

  const handleSave = () => {
    alert('设置已保存！');
  };

  const handleChangePassword = () => {
    alert('修改密码功能开发中...');
  };

  const handleDeleteAccount = () => {
    if (window.confirm('确定要删除账户吗？此操作不可恢复！')) {
      alert('删除账户功能开发中...');
    }
  };

  const loadSessions = async () => {
    try {
      setSessionsLoading(true);
      setSessionsError('');
      const res = await fetch('/api/secure-auth/sessions', {
        method: 'GET',
        credentials: 'include'
      });
      if (!res.ok) {
        throw new Error(`加载会话失败: ${res.status}`);
      }
      const data = await res.json();
      setSessions(Array.isArray(data.sessions) ? data.sessions : []);
    } catch (e: any) {
      console.error(e);
      setSessionsError(e?.message || '加载会话失败');
      setSessions([]);
    } finally {
      setSessionsLoading(false);
    }
  };

  const logoutOthers = async () => {
    if (!window.confirm('确定要登出其它设备吗？这会使其它设备立即失效。')) {
      return;
    }
    try {
      setSessionsLoading(true);
      setSessionsError('');
      const res = await fetch('/api/secure-auth/logout-others', {
        method: 'POST',
        credentials: 'include'
      });
      if (!res.ok) {
        const text = await res.text();
        throw new Error(`登出其它设备失败: ${res.status} ${text}`);
      }
      await loadSessions();
      alert('已登出其它设备');
    } catch (e: any) {
      console.error(e);
      setSessionsError(e?.message || '登出其它设备失败');
    } finally {
      setSessionsLoading(false);
    }
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

  const tabs = [
    { id: 'profile', label: '个人资料', icon: '👤' },
    { id: 'notifications', label: '通知设置', icon: '🔔' },
    { id: 'privacy', label: '隐私设置', icon: '🔒' },
    { id: 'security', label: '安全设置', icon: '🛡️' }
  ];

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
      padding: '20px'
    }}>
      <div style={{ 
        maxWidth: '900px', 
        margin: '0 auto',
        background: '#fff',
        borderRadius: '16px',
        boxShadow: '0 8px 32px rgba(0,0,0,0.1)',
        overflow: 'hidden'
      }}>
        {/* 头部 */}
        <div style={{
          background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
          color: '#fff',
          padding: '30px',
          textAlign: 'center'
        }}>
          <button
            onClick={() => navigate('/')}
            style={{
              position: 'absolute',
              left: '20px',
              top: '20px',
              background: 'rgba(255,255,255,0.2)',
              border: 'none',
              color: '#fff',
              padding: '8px 16px',
              borderRadius: '20px',
              cursor: 'pointer',
              fontSize: '14px'
            }}
          >
            ← 返回首页
          </button>
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
          }}>⚙️ 设置</h1>
          <div style={{ fontSize: '16px', opacity: 0.9 }}>管理您的账户设置和偏好</div>
        </div>

        <div style={{ display: 'flex' }}>
          {/* 侧边栏 */}
          <div style={{
            width: '250px',
            background: '#f8f9fa',
            borderRight: '1px solid #e9ecef'
          }}>
            {tabs.map(tab => (
              <div
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                style={{
                  padding: '16px 20px',
                  cursor: 'pointer',
                  borderBottom: '1px solid #e9ecef',
                  background: activeTab === tab.id ? '#fff' : 'transparent',
                  color: activeTab === tab.id ? '#3b82f6' : '#666',
                  fontWeight: activeTab === tab.id ? 'bold' : 'normal',
                  transition: 'all 0.3s ease'
                }}
              >
                <span style={{ marginRight: '10px' }}>{tab.icon}</span>
                {tab.label}
              </div>
            ))}
          </div>

          {/* 内容区域 */}
          <div style={{ flex: 1, padding: '30px' }}>
            {activeTab === 'profile' && (
              <div>
                <h2 style={{ color: '#333', marginBottom: '20px', fontSize: '20px' }}>👤 个人资料</h2>
                
                <div style={{ display: 'flex', alignItems: 'center', marginBottom: '30px' }}>
                  <img
                    src={user?.avatar || '/static/avatar2.png'}
                    alt="头像"
                    style={{
                      width: '80px',
                      height: '80px',
                      borderRadius: '50%',
                      border: '3px solid #3b82f6',
                      marginRight: '20px'
                    }}
                  />
                  <div>
                    <button style={{
                      background: '#3b82f6',
                      color: '#fff',
                      border: 'none',
                      padding: '8px 16px',
                      borderRadius: '20px',
                      cursor: 'pointer',
                      fontSize: '14px'
                    }}>
                      更换头像
                    </button>
                  </div>
                </div>

                <div style={{ display: 'grid', gap: '20px' }}>
                  <div>
                    <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold', color: '#333' }}>
                      姓名
                    </label>
                    <input
                      type="text"
                      value={formData.name}
                      onChange={(e) => handleInputChange('name', e.target.value)}
                      style={{
                        width: '100%',
                        padding: '12px',
                        border: '1px solid #ddd',
                        borderRadius: '8px',
                        fontSize: '16px'
                      }}
                    />
                  </div>

                  <div>
                    <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold', color: '#333' }}>
                      邮箱
                    </label>
                    <input
                      type="email"
                      value={formData.email}
                      onChange={(e) => handleInputChange('email', e.target.value)}
                      style={{
                        width: '100%',
                        padding: '12px',
                        border: '1px solid #ddd',
                        borderRadius: '8px',
                        fontSize: '16px'
                      }}
                    />
                  </div>

                  <div>
                    <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold', color: '#333' }}>
                      手机号
                    </label>
                    <input
                      type="tel"
                      value={formData.phone}
                      onChange={(e) => handleInputChange('phone', e.target.value)}
                      style={{
                        width: '100%',
                        padding: '12px',
                        border: '1px solid #ddd',
                        borderRadius: '8px',
                        fontSize: '16px'
                      }}
                    />
                  </div>

                  <div>
                    <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold', color: '#333' }}>
                      时区
                    </label>
                    <select
                      value={formData.timezone}
                      onChange={(e) => handleInputChange('timezone', e.target.value)}
                      style={{
                        width: '100%',
                        padding: '12px',
                        border: '1px solid #ddd',
                        borderRadius: '8px',
                        fontSize: '16px'
                      }}
                    >
                      <option value="UTC">UTC</option>
                      <option value="Asia/Shanghai">北京时间</option>
                      <option value="America/New_York">纽约时间</option>
                      <option value="Europe/London">伦敦时间</option>
                    </select>
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'notifications' && (
              <div>
                <h2 style={{ color: '#333', marginBottom: '20px', fontSize: '20px' }}>🔔 通知设置</h2>
                
                <div style={{ display: 'grid', gap: '20px' }}>
                  <div style={{
                    padding: '20px',
                    background: '#f8f9fa',
                    borderRadius: '12px',
                    border: '1px solid #e9ecef'
                  }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div>
                        <div style={{ fontWeight: 'bold', color: '#333', marginBottom: '4px' }}>
                          📧 邮件通知
                        </div>
                        <div style={{ fontSize: '14px', color: '#666' }}>
                          接收任务更新和系统消息的邮件通知
                        </div>
                      </div>
                      <label style={{ position: 'relative', display: 'inline-block', width: '50px', height: '24px' }}>
                        <input
                          type="checkbox"
                          checked={formData.notifications.email}
                          onChange={(e) => handleInputChange('notifications.email', e.target.checked)}
                          style={{ opacity: 0, width: 0, height: 0 }}
                        />
                        <span style={{
                          position: 'absolute',
                          cursor: 'pointer',
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          background: formData.notifications.email ? '#3b82f6' : '#ccc',
                          borderRadius: '24px',
                          transition: '0.3s'
                        }}>
                          <span style={{
                            position: 'absolute',
                            content: '""',
                            height: '18px',
                            width: '18px',
                            left: formData.notifications.email ? '26px' : '3px',
                            bottom: '3px',
                            background: '#fff',
                            borderRadius: '50%',
                            transition: '0.3s'
                          }} />
                        </span>
                      </label>
                    </div>
                  </div>

                  <div style={{
                    padding: '20px',
                    background: '#f8f9fa',
                    borderRadius: '12px',
                    border: '1px solid #e9ecef'
                  }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div>
                        <div style={{ fontWeight: 'bold', color: '#333', marginBottom: '4px' }}>
                          📱 短信通知
                        </div>
                        <div style={{ fontSize: '14px', color: '#666' }}>
                          接收重要消息的短信通知
                        </div>
                      </div>
                      <label style={{ position: 'relative', display: 'inline-block', width: '50px', height: '24px' }}>
                        <input
                          type="checkbox"
                          checked={formData.notifications.sms}
                          onChange={(e) => handleInputChange('notifications.sms', e.target.checked)}
                          style={{ opacity: 0, width: 0, height: 0 }}
                        />
                        <span style={{
                          position: 'absolute',
                          cursor: 'pointer',
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          background: formData.notifications.sms ? '#3b82f6' : '#ccc',
                          borderRadius: '24px',
                          transition: '0.3s'
                        }}>
                          <span style={{
                            position: 'absolute',
                            content: '""',
                            height: '18px',
                            width: '18px',
                            left: formData.notifications.sms ? '26px' : '3px',
                            bottom: '3px',
                            background: '#fff',
                            borderRadius: '50%',
                            transition: '0.3s'
                          }} />
                        </span>
                      </label>
                    </div>
                  </div>

                  <div style={{
                    padding: '20px',
                    background: '#f8f9fa',
                    borderRadius: '12px',
                    border: '1px solid #e9ecef'
                  }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div>
                        <div style={{ fontWeight: 'bold', color: '#333', marginBottom: '4px' }}>
                          🔔 推送通知
                        </div>
                        <div style={{ fontSize: '14px', color: '#666' }}>
                          接收浏览器推送通知
                        </div>
                      </div>
                      <label style={{ position: 'relative', display: 'inline-block', width: '50px', height: '24px' }}>
                        <input
                          type="checkbox"
                          checked={formData.notifications.push}
                          onChange={(e) => handleInputChange('notifications.push', e.target.checked)}
                          style={{ opacity: 0, width: 0, height: 0 }}
                        />
                        <span style={{
                          position: 'absolute',
                          cursor: 'pointer',
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          background: formData.notifications.push ? '#3b82f6' : '#ccc',
                          borderRadius: '24px',
                          transition: '0.3s'
                        }}>
                          <span style={{
                            position: 'absolute',
                            content: '""',
                            height: '18px',
                            width: '18px',
                            left: formData.notifications.push ? '26px' : '3px',
                            bottom: '3px',
                            background: '#fff',
                            borderRadius: '50%',
                            transition: '0.3s'
                          }} />
                        </span>
                      </label>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'privacy' && (
              <div>
                <h2 style={{ color: '#333', marginBottom: '20px', fontSize: '20px' }}>🔒 隐私设置</h2>
                
                <div style={{ display: 'grid', gap: '20px' }}>
                  <div style={{
                    padding: '20px',
                    background: '#f8f9fa',
                    borderRadius: '12px',
                    border: '1px solid #e9ecef'
                  }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div>
                        <div style={{ fontWeight: 'bold', color: '#333', marginBottom: '4px' }}>
                          🌐 公开个人资料
                        </div>
                        <div style={{ fontSize: '14px', color: '#666' }}>
                          允许其他用户查看您的个人资料
                        </div>
                      </div>
                      <label style={{ position: 'relative', display: 'inline-block', width: '50px', height: '24px' }}>
                        <input
                          type="checkbox"
                          checked={formData.privacy.profile_public}
                          onChange={(e) => handleInputChange('privacy.profile_public', e.target.checked)}
                          style={{ opacity: 0, width: 0, height: 0 }}
                        />
                        <span style={{
                          position: 'absolute',
                          cursor: 'pointer',
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          background: formData.privacy.profile_public ? '#3b82f6' : '#ccc',
                          borderRadius: '24px',
                          transition: '0.3s'
                        }}>
                          <span style={{
                            position: 'absolute',
                            content: '""',
                            height: '18px',
                            width: '18px',
                            left: formData.privacy.profile_public ? '26px' : '3px',
                            bottom: '3px',
                            background: '#fff',
                            borderRadius: '50%',
                            transition: '0.3s'
                          }} />
                        </span>
                      </label>
                    </div>
                  </div>

                  <div style={{
                    padding: '20px',
                    background: '#f8f9fa',
                    borderRadius: '12px',
                    border: '1px solid #e9ecef'
                  }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div>
                        <div style={{ fontWeight: 'bold', color: '#333', marginBottom: '4px' }}>
                          📞 显示联系方式
                        </div>
                        <div style={{ fontSize: '14px', color: '#666' }}>
                          在个人资料中显示联系方式
                        </div>
                      </div>
                      <label style={{ position: 'relative', display: 'inline-block', width: '50px', height: '24px' }}>
                        <input
                          type="checkbox"
                          checked={formData.privacy.show_contact}
                          onChange={(e) => handleInputChange('privacy.show_contact', e.target.checked)}
                          style={{ opacity: 0, width: 0, height: 0 }}
                        />
                        <span style={{
                          position: 'absolute',
                          cursor: 'pointer',
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          background: formData.privacy.show_contact ? '#3b82f6' : '#ccc',
                          borderRadius: '24px',
                          transition: '0.3s'
                        }}>
                          <span style={{
                            position: 'absolute',
                            content: '""',
                            height: '18px',
                            width: '18px',
                            left: formData.privacy.show_contact ? '26px' : '3px',
                            bottom: '3px',
                            background: '#fff',
                            borderRadius: '50%',
                            transition: '0.3s'
                          }} />
                        </span>
                      </label>
                    </div>
                  </div>

                  <div style={{
                    padding: '20px',
                    background: '#f8f9fa',
                    borderRadius: '12px',
                    border: '1px solid #e9ecef'
                  }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <div>
                        <div style={{ fontWeight: 'bold', color: '#333', marginBottom: '4px' }}>
                          📋 显示任务历史
                        </div>
                        <div style={{ fontSize: '14px', color: '#666' }}>
                          在个人资料中显示任务历史
                        </div>
                      </div>
                      <label style={{ position: 'relative', display: 'inline-block', width: '50px', height: '24px' }}>
                        <input
                          type="checkbox"
                          checked={formData.privacy.show_tasks}
                          onChange={(e) => handleInputChange('privacy.show_tasks', e.target.checked)}
                          style={{ opacity: 0, width: 0, height: 0 }}
                        />
                        <span style={{
                          position: 'absolute',
                          cursor: 'pointer',
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          background: formData.privacy.show_tasks ? '#3b82f6' : '#ccc',
                          borderRadius: '24px',
                          transition: '0.3s'
                        }}>
                          <span style={{
                            position: 'absolute',
                            content: '""',
                            height: '18px',
                            width: '18px',
                            left: formData.privacy.show_tasks ? '26px' : '3px',
                            bottom: '3px',
                            background: '#fff',
                            borderRadius: '50%',
                            transition: '0.3s'
                          }} />
                        </span>
                      </label>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'security' && (
              <div>
                <h2 style={{ color: '#333', marginBottom: '20px', fontSize: '20px' }}>🛡️ 安全设置</h2>
                
                <div style={{ display: 'grid', gap: '20px' }}>
                  {/* 会话管理 */}
                  <div style={{
                    padding: '20px',
                    background: '#f8f9fa',
                    borderRadius: '12px',
                    border: '1px solid #e9ecef'
                  }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
                      <h3 style={{ color: '#333', margin: 0 }}>🖥️ 会话管理</h3>
                      <div>
                        <button
                          onClick={() => void loadSessions()}
                          style={{
                            background: '#e5e7eb',
                            color: '#111827',
                            border: 'none',
                            padding: '8px 14px',
                            borderRadius: '20px',
                            cursor: 'pointer',
                            fontSize: '13px',
                            marginRight: '8px'
                          }}
                        >
                          刷新
                        </button>
                        <button
                          onClick={() => void logoutOthers()}
                          style={{
                            background: '#f59e0b',
                            color: '#fff',
                            border: 'none',
                            padding: '8px 14px',
                            borderRadius: '20px',
                            cursor: 'pointer',
                            fontSize: '13px'
                          }}
                        >
                          登出其它设备
                        </button>
                      </div>
                    </div>

                    {sessionsLoading && (
                      <div style={{ color: '#666', fontSize: '14px' }}>加载会话中...</div>
                    )}
                    {sessionsError && (
                      <div style={{ color: '#ef4444', fontSize: '13px', marginBottom: '8px' }}>{sessionsError}</div>
                    )}
                    {!sessionsLoading && !sessionsError && (
                      <div style={{ display: 'grid', gap: '10px' }}>
                        {sessions.length === 0 && (
                          <div style={{ color: '#666', fontSize: '14px' }}>暂无会话</div>
                        )}
                        {sessions.map((s, idx) => (
                          <div key={idx} style={{
                            padding: '12px',
                            background: '#fff',
                            borderRadius: '10px',
                            border: '1px solid #e5e7eb',
                            display: 'flex',
                            justifyContent: 'space-between',
                            alignItems: 'center'
                          }}>
                            <div style={{ color: '#111827' }}>
                              <div style={{ fontWeight: 'bold' }}>{s.session_id}</div>
                              <div style={{ fontSize: '12px', color: '#6b7280' }}>
                                IP: {s.ip_address || '-'} | 设备: {s.device_fingerprint || '-'}
                              </div>
                              <div style={{ fontSize: '12px', color: '#6b7280' }}>
                                创建: {s.created_at} | 活动: {s.last_activity}
                              </div>
                            </div>
                            <div style={{ fontSize: '12px', color: s.is_current ? '#10b981' : '#6b7280' }}>
                              {s.is_current ? '当前设备' : '其它设备'}
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>

                  <div style={{
                    padding: '20px',
                    background: '#f8f9fa',
                    borderRadius: '12px',
                    border: '1px solid #e9ecef'
                  }}>
                    <h3 style={{ color: '#333', marginBottom: '10px' }}>🔑 密码</h3>
                    <p style={{ color: '#666', marginBottom: '15px', fontSize: '14px' }}>
                      定期更改密码以保护您的账户安全
                    </p>
                    <button
                      onClick={handleChangePassword}
                      style={{
                        background: '#3b82f6',
                        color: '#fff',
                        border: 'none',
                        padding: '10px 20px',
                        borderRadius: '20px',
                        cursor: 'pointer',
                        fontSize: '14px'
                      }}
                    >
                      修改密码
                    </button>
                  </div>

                  <div style={{
                    padding: '20px',
                    background: '#f8f9fa',
                    borderRadius: '12px',
                    border: '1px solid #e9ecef'
                  }}>
                    <h3 style={{ color: '#333', marginBottom: '10px' }}>📱 两步验证</h3>
                    <p style={{ color: '#666', marginBottom: '15px', fontSize: '14px' }}>
                      启用两步验证以增强账户安全性
                    </p>
                    <button
                      style={{
                        background: '#4CAF50',
                        color: '#fff',
                        border: 'none',
                        padding: '10px 20px',
                        borderRadius: '20px',
                        cursor: 'pointer',
                        fontSize: '14px'
                      }}
                    >
                      启用两步验证
                    </button>
                  </div>

                  <div style={{
                    padding: '20px',
                    background: '#f8f9fa',
                    borderRadius: '12px',
                    border: '1px solid #e9ecef'
                  }}>
                    <h3 style={{ color: '#333', marginBottom: '10px' }}>🗑️ 删除账户</h3>
                    <p style={{ color: '#666', marginBottom: '15px', fontSize: '14px' }}>
                      永久删除您的账户和所有相关数据
                    </p>
                    <button
                      onClick={handleDeleteAccount}
                      style={{
                        background: '#f44336',
                        color: '#fff',
                        border: 'none',
                        padding: '10px 20px',
                        borderRadius: '20px',
                        cursor: 'pointer',
                        fontSize: '14px'
                      }}
                    >
                      删除账户
                    </button>
                  </div>
                </div>
              </div>
            )}

            {/* 保存按钮 */}
            <div style={{ 
              marginTop: '30px', 
              paddingTop: '20px', 
              borderTop: '1px solid #e9ecef',
              textAlign: 'right'
            }}>
              <button
                onClick={handleSave}
                style={{
                  background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                  color: '#fff',
                  border: 'none',
                  padding: '12px 30px',
                  borderRadius: '25px',
                  cursor: 'pointer',
                  fontSize: '16px',
                  fontWeight: 'bold',
                  boxShadow: '0 4px 15px rgba(59, 130, 246, 0.3)',
                  transition: 'all 0.3s ease'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.transform = 'translateY(-2px)';
                  e.currentTarget.style.boxShadow = '0 6px 20px rgba(59, 130, 246, 0.4)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 4px 15px rgba(59, 130, 246, 0.3)';
                }}
              >
                保存设置
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Settings;
