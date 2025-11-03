import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api';

// 地点列表常量
const LOCATION_OPTIONS = [
  'Online', 'London', 'Edinburgh', 'Manchester', 'Birmingham', 'Glasgow', 
  'Bristol', 'Sheffield', 'Leeds', 'Nottingham', 'Newcastle', 'Southampton', 
  'Liverpool', 'Cardiff', 'Coventry', 'Exeter', 'Leicester', 'York', 
  'Aberdeen', 'Bath', 'Dundee', 'Reading', 'St Andrews', 'Belfast', 
  'Brighton', 'Durham', 'Norwich', 'Swansea', 'Loughborough', 'Lancaster', 
  'Warwick', 'Cambridge', 'Oxford', 'Other'
];

// 任务类型列表常量
const TASK_TYPE_OPTIONS = [
  'Housekeeping', 'Campus Life', 'Second-hand & Rental', 'Errand Running', 
  'Skill Service', 'Social Help', 'Transportation', 'Pet Care', 'Life Convenience', 'Other'
];

const Settings: React.FC = () => {
  const navigate = useNavigate();
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('profile');
  const [sessions, setSessions] = useState<Array<any>>([]);
  const [sessionsLoading, setSessionsLoading] = useState(false);
  const [sessionsError, setSessionsError] = useState<string>('');
  const [newKeyword, setNewKeyword] = useState('');
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    phone: '',
    residence_city: '',
    language_preference: 'en',
    notifications: {
      email: true,
      sms: false,
      push: true
    },
    privacy: {
      profile_public: true,
      show_contact: false,
      show_tasks: true
    },
    preferences: {
      task_types: [] as string[],
      locations: [] as string[],
      task_levels: [] as string[],
      min_deadline_days: 1,
      keywords: [] as string[]
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

  // 格式化头像 URL
  const formatAvatarUrl = (avatar: string | null | undefined): string => {
    if (!avatar) {
      return '/static/avatar2.png';
    }
    // 如果已经是完整 URL，直接返回
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return avatar;
    }
    // 如果是相对路径（以 / 开头），直接返回
    if (avatar.startsWith('/')) {
      return avatar;
    }
    // 否则，假设是相对路径，添加 /
    return `/${avatar}`;
  };

  const loadUserData = async () => {
    try {
      setLoading(true);
      
      // 加载用户偏好设置（使用 api.get 而不是 fetch）
      try {
        const preferencesResponse = await api.get('/api/user-preferences');
        const preferences = preferencesResponse.data;
        setFormData(prev => ({
          ...prev,
          preferences: {
            task_types: preferences.task_types || [],
            locations: preferences.locations || [],
            task_levels: preferences.task_levels || [],
            min_deadline_days: preferences.min_deadline_days || 1,
            keywords: preferences.keywords || []
          }
        }));
      } catch (error) {
        console.error('加载用户偏好失败:', error);
      }
      
      // 加载用户资料（使用 api.get 而不是 fetch，确保 Cookie 正确发送）
      try {
        const userResponse = await api.get('/api/users/profile/me');
        const userData = userResponse.data;
        // 格式化头像 URL
        if (userData.avatar) {
          userData.avatar = formatAvatarUrl(userData.avatar);
        }
        setUser(userData);
        setFormData(prev => ({
          ...prev,
          name: userData.name || '',
          email: userData.email || '',
          phone: userData.phone || '',
          residence_city: userData.residence_city || '',
          language_preference: userData.language_preference || 'en',
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
        }));
      } catch (error: any) {
        console.error('加载用户资料失败:', error);
        if (error.response?.status === 401) {
          // 会话过期，重定向到登录页面
          navigate('/login');
          return;
        }
        setUser(null);
      }
    } catch (error) {
      console.error('加载用户设置失败:', error);
      setUser(null);
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = (field: string, value: any) => {
    if (field.includes('.')) {
      const parts = field.split('.');
      setFormData(prev => {
        const newData = { ...prev };
        let current: any = newData;
        for (let i = 0; i < parts.length - 1; i++) {
          current[parts[i]] = { ...current[parts[i]] };
          current = current[parts[i]];
        }
        current[parts[parts.length - 1]] = value;
        return newData;
      });
    } else {
      setFormData(prev => ({
        ...prev,
        [field]: value
      }));
    }
  };

  const handleSave = async () => {
    try {
      // 保存个人资料（名字、常住城市、语言偏好）
      // 构建请求体，只包含需要更新的字段
      const updatePayload: any = {};
      
      // 名字：只在改变时更新
      if (formData.name !== user?.name && formData.name) {
        updatePayload.name = formData.name;
      }
      
      // 常住城市：总是发送（允许更新为空）
      if (formData.residence_city !== user?.residence_city) {
        updatePayload.residence_city = formData.residence_city || null;
      }
      
      // 语言偏好：总是发送（允许更新）
      if (formData.language_preference !== user?.language_preference) {
        updatePayload.language_preference = formData.language_preference || 'en';
      }
      
      // 如果没有要更新的字段，提示用户
      if (Object.keys(updatePayload).length === 0) {
        alert('没有需要更新的信息');
        return;
      }
      
      console.log('[DEBUG] 发送更新请求:', updatePayload);
      
      // 使用 api.patch 而不是 fetch，这样能自动处理 Cookie 和 CSRF token
      await api.patch('/api/users/profile', updatePayload);

      // 如果名字更新成功，重新加载用户数据以获取最新的name_updated_at
      if (formData.name !== user?.name) {
        try {
          const userResponse = await api.get('/api/users/profile/me');
          setUser(userResponse.data);
          alert('用户名更新成功！');
        } catch (error) {
          console.error('重新加载用户数据失败:', error);
        }
      }

      // 保存任务偏好设置（使用 api.put，自动处理 Cookie 和 CSRF token）
      await api.put('/api/user-preferences', formData.preferences);
      
      alert('设置已保存！');
      // 如果语言偏好改变，刷新页面以应用新语言
      const currentLang = localStorage.getItem('language') || 'zh';
      if (formData.language_preference !== currentLang) {
        localStorage.setItem('language', formData.language_preference);
        window.location.reload();
      }
    } catch (error) {
      console.error('保存设置失败:', error);
      alert('保存失败，请稍后重试');
    }
  };

  const addKeyword = () => {
    if (newKeyword.trim() && 
        !formData.preferences.keywords.includes(newKeyword.trim()) &&
        formData.preferences.keywords.length < 20) {
      const newKeywords = [...formData.preferences.keywords, newKeyword.trim()];
      handleInputChange('preferences.keywords', newKeywords);
      setNewKeyword('');
    }
  };

  const removeKeyword = (keyword: string) => {
    const newKeywords = formData.preferences.keywords.filter(k => k !== keyword);
    handleInputChange('preferences.keywords', newKeywords);
  };

  const handleKeywordKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      addKeyword();
    }
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
      const res = await api.get('/api/secure-auth/sessions');
      setSessions(Array.isArray(res.data.sessions) ? res.data.sessions : []);
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
      
      // 使用 api.post，自动处理 Cookie 和 CSRF token
      await api.post('/api/secure-auth/logout-others');
      await loadSessions();
      alert('已登出其它设备');
    } catch (e: any) {
      console.error(e);
      setSessionsError(e?.response?.data?.detail || e?.message || '登出其它设备失败');
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
    { id: 'preferences', label: '任务偏好', icon: '🎯' },
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
                    src={formatAvatarUrl(user?.avatar)}
                    alt="头像"
                    style={{
                      width: '80px',
                      height: '80px',
                      borderRadius: '50%',
                      border: '3px solid #3b82f6',
                      marginRight: '20px',
                      objectFit: 'cover'
                    }}
                    onError={(e) => {
                      console.error('头像加载失败:', user?.avatar);
                      // 如果加载失败，使用默认头像
                      if (e.currentTarget.src !== '/static/avatar2.png') {
                        e.currentTarget.src = '/static/avatar2.png';
                      }
                    }}
                    onLoad={() => {
                      console.log('头像加载成功:', user?.avatar);
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
                      用户名
                    </label>
                    <input
                      type="text"
                      value={formData.name}
                      onChange={(e) => handleInputChange('name', e.target.value)}
                      placeholder="请输入用户名（3-50个字符）"
                      style={{
                        width: '100%',
                        padding: '12px',
                        border: '1px solid #ddd',
                        borderRadius: '8px',
                        fontSize: '16px'
                      }}
                    />
                    <p style={{ marginTop: '4px', marginBottom: '0', fontSize: '12px', color: '#999' }}>
                      {(() => {
                        if (!user?.name_updated_at) {
                          return '可以修改用户名（用户名唯一，且一个月内只能修改一次）';
                        }
                        try {
                          const lastUpdate = new Date(user.name_updated_at);
                          const now = new Date();
                          const daysDiff = Math.floor((now.getTime() - lastUpdate.getTime()) / (1000 * 60 * 60 * 24));
                          const daysLeft = 30 - daysDiff;
                          if (daysLeft > 0) {
                            return `用户名一个月内只能修改一次，距离下次可修改还有 ${daysLeft} 天`;
                          } else {
                            return '可以修改用户名（用户名唯一，且一个月内只能修改一次）';
                          }
                        } catch (e) {
                          return '可以修改用户名（用户名唯一，且一个月内只能修改一次）';
                        }
                      })()}
                    </p>
                    <p style={{ marginTop: '4px', marginBottom: '0', fontSize: '12px', color: '#666' }}>
                      用户名只能包含字母、数字、下划线和连字符，且不能以数字开头
                    </p>
                  </div>

                  <div>
                    <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold', color: '#333' }}>
                      邮箱
                    </label>
                    <input
                      type="email"
                      value={formData.email}
                      disabled
                      style={{
                        width: '100%',
                        padding: '12px',
                        border: '1px solid #ddd',
                        borderRadius: '8px',
                        fontSize: '16px',
                        background: '#f8f9fa',
                        color: '#666',
                        cursor: 'not-allowed'
                      }}
                    />
                    <p style={{ marginTop: '4px', marginBottom: '0', fontSize: '12px', color: '#999' }}>
                      暂不支持修改
                    </p>
                  </div>

                  <div>
                    <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold', color: '#333' }}>
                      手机号
                    </label>
                    <input
                      type="tel"
                      value={formData.phone}
                      onChange={(e) => handleInputChange('phone', e.target.value)}
                      placeholder="请输入手机号"
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
                      常住城市
                    </label>
                    <select
                      value={formData.residence_city}
                      onChange={(e) => handleInputChange('residence_city', e.target.value)}
                      style={{
                        width: '100%',
                        padding: '12px',
                        border: '1px solid #ddd',
                        borderRadius: '8px',
                        fontSize: '16px'
                      }}
                    >
                      <option value="">请选择常住城市</option>
                      {LOCATION_OPTIONS.map(location => (
                        <option key={location} value={location}>{location}</option>
                      ))}
                    </select>
                    <p style={{ marginTop: '4px', marginBottom: '0', fontSize: '12px', color: '#999' }}>
                      选择您常居住的城市
                    </p>
                  </div>

                  <div>
                    <label style={{ display: 'block', marginBottom: '8px', fontWeight: 'bold', color: '#333' }}>
                      语言偏好
                    </label>
                    <select
                      value={formData.language_preference}
                      onChange={(e) => handleInputChange('language_preference', e.target.value)}
                      style={{
                        width: '100%',
                        padding: '12px',
                        border: '1px solid #ddd',
                        borderRadius: '8px',
                        fontSize: '16px'
                      }}
                    >
                      <option value="zh">中文</option>
                      <option value="en">English</option>
                    </select>
                    <p style={{ marginTop: '4px', marginBottom: '0', fontSize: '12px', color: '#999' }}>
                      选择您偏好的界面语言
                    </p>
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'preferences' && (
              <div>
                <h2 style={{ color: '#333', marginBottom: '20px', fontSize: '20px' }}>🎯 任务偏好</h2>
                
                <div style={{ display: 'grid', gap: '30px' }}>
                  {/* 偏好的任务类型 */}
                  <div>
                    <label style={{ 
                      display: 'block', 
                      marginBottom: '12px', 
                      fontWeight: 'bold', 
                      color: '#333',
                      fontSize: '16px'
                    }}>
                      📋 偏好的任务类型
                    </label>
                    <p style={{ fontSize: '14px', color: '#666', marginBottom: '12px' }}>
                      选择您感兴趣的任务类型，系统会优先为您推荐这些类型的任务
                    </p>
                    <div style={{ 
                      display: 'grid', 
                      gridTemplateColumns: 'repeat(auto-fill, minmax(150px, 1fr))',
                      gap: '12px'
                    }}>
                      {TASK_TYPE_OPTIONS.map(type => (
                        <label key={type} style={{ 
                          display: 'flex', 
                          alignItems: 'center',
                          padding: '12px',
                          border: formData.preferences.task_types.includes(type) ? '2px solid #3b82f6' : '1px solid #ddd',
                          borderRadius: '8px',
                          cursor: 'pointer',
                          background: formData.preferences.task_types.includes(type) ? '#eff6ff' : '#fff',
                          transition: 'all 0.3s ease'
                        }}>
                          <input
                            type="checkbox"
                            checked={formData.preferences.task_types.includes(type)}
                            onChange={(e) => {
                              const newTypes = e.target.checked
                                ? [...formData.preferences.task_types, type]
                                : formData.preferences.task_types.filter(t => t !== type);
                              handleInputChange('preferences.task_types', newTypes);
                            }}
                            style={{ marginRight: '8px', width: '16px', height: '16px', cursor: 'pointer' }}
                          />
                          <span style={{ fontSize: '14px' }}>{type}</span>
                        </label>
                      ))}
                    </div>
                  </div>

                  {/* 偏好的地点 */}
                  <div>
                    <label style={{ 
                      display: 'block', 
                      marginBottom: '12px', 
                      fontWeight: 'bold', 
                      color: '#333',
                      fontSize: '16px'
                    }}>
                      📍 偏好的地点
                    </label>
                    <p style={{ fontSize: '14px', color: '#666', marginBottom: '12px' }}>
                      选择您希望接收任务的地理位置
                    </p>
                    <div style={{ 
                      display: 'grid', 
                      gridTemplateColumns: 'repeat(auto-fill, minmax(120px, 1fr))',
                      gap: '12px'
                    }}>
                      {LOCATION_OPTIONS.map(location => (
                        <label key={location} style={{ 
                          display: 'flex', 
                          alignItems: 'center',
                          padding: '12px',
                          border: formData.preferences.locations.includes(location) ? '2px solid #3b82f6' : '1px solid #ddd',
                          borderRadius: '8px',
                          cursor: 'pointer',
                          background: formData.preferences.locations.includes(location) ? '#eff6ff' : '#fff',
                          transition: 'all 0.3s ease'
                        }}>
                          <input
                            type="checkbox"
                            checked={formData.preferences.locations.includes(location)}
                            onChange={(e) => {
                              const newLocations = e.target.checked
                                ? [...formData.preferences.locations, location]
                                : formData.preferences.locations.filter(l => l !== location);
                              handleInputChange('preferences.locations', newLocations);
                            }}
                            style={{ marginRight: '8px', width: '16px', height: '16px', cursor: 'pointer' }}
                          />
                          <span style={{ fontSize: '14px' }}>{location}</span>
                        </label>
                      ))}
                    </div>
                  </div>

                  {/* 偏好的任务等级 */}
                  <div>
                    <label style={{ 
                      display: 'block', 
                      marginBottom: '12px', 
                      fontWeight: 'bold', 
                      color: '#333',
                      fontSize: '16px'
                    }}>
                      🌟 偏好的任务等级
                    </label>
                    <p style={{ fontSize: '14px', color: '#666', marginBottom: '12px' }}>
                      选择您感兴趣的任務等級
                    </p>
                    <div style={{ 
                      display: 'grid', 
                      gridTemplateColumns: 'repeat(auto-fill, minmax(120px, 1fr))',
                      gap: '12px'
                    }}>
                      {['Normal', 'VIP', 'Super'].map(level => (
                        <label key={level} style={{ 
                          display: 'flex', 
                          alignItems: 'center',
                          padding: '12px',
                          border: formData.preferences.task_levels.includes(level) ? '2px solid #3b82f6' : '1px solid #ddd',
                          borderRadius: '8px',
                          cursor: 'pointer',
                          background: formData.preferences.task_levels.includes(level) ? '#eff6ff' : '#fff',
                          transition: 'all 0.3s ease'
                        }}>
                          <input
                            type="checkbox"
                            checked={formData.preferences.task_levels.includes(level)}
                            onChange={(e) => {
                              const newLevels = e.target.checked
                                ? [...formData.preferences.task_levels, level]
                                : formData.preferences.task_levels.filter(l => l !== level);
                              handleInputChange('preferences.task_levels', newLevels);
                            }}
                            style={{ marginRight: '8px', width: '16px', height: '16px', cursor: 'pointer' }}
                          />
                          <span style={{ fontSize: '14px' }}>{level}</span>
                        </label>
                      ))}
                    </div>
                  </div>

                  {/* 最少截止时间 */}
                  <div>
                    <label style={{ 
                      display: 'block', 
                      marginBottom: '12px', 
                      fontWeight: 'bold', 
                      color: '#333',
                      fontSize: '16px'
                    }}>
                      ⏰ 最少截止时间
                    </label>
                    <p style={{ fontSize: '14px', color: '#666', marginBottom: '12px' }}>
                      设置任务截止时间至少需要多少天，系统将只推荐符合此条件的任务
                    </p>
                    <div style={{ 
                      display: 'flex', 
                      alignItems: 'center',
                      gap: '12px'
                    }}>
                      <input
                        type="number"
                        value={formData.preferences.min_deadline_days}
                        onChange={(e) => handleInputChange('preferences.min_deadline_days', parseInt(e.target.value) || 1)}
                        min="1"
                        max="30"
                        style={{
                          width: '120px',
                          padding: '12px',
                          border: '1px solid #ddd',
                          borderRadius: '8px',
                          fontSize: '16px'
                        }}
                      />
                      <span style={{ color: '#666' }}>天</span>
                      <span style={{ fontSize: '14px', color: '#999' }}>
                        （至少 1 天，最多 30 天）
                      </span>
                    </div>
                  </div>

                  {/* 偏好关键词 */}
                  <div>
                    <label style={{ 
                      display: 'block', 
                      marginBottom: '12px', 
                      fontWeight: 'bold', 
                      color: '#333',
                      fontSize: '16px'
                    }}>
                      🔍 偏好关键词
                    </label>
                    <p style={{ fontSize: '14px', color: '#666', marginBottom: '12px' }}>
                      添加您感兴趣的关键词，系统会优先推荐包含这些关键词的任务
                    </p>
                    
                    {/* 添加关键词输入框 */}
                    <div style={{ 
                      display: 'flex', 
                      gap: '8px',
                      marginBottom: '16px'
                    }}>
                      <input
                        type="text"
                        value={newKeyword}
                        onChange={(e) => setNewKeyword(e.target.value)}
                        onKeyPress={handleKeywordKeyPress}
                        placeholder="输入关键词，如：编程、设计、翻译..."
                        style={{
                          flex: 1,
                          padding: '12px',
                          border: '1px solid #ddd',
                          borderRadius: '8px',
                          fontSize: '16px'
                        }}
                      />
                      <button
                        onClick={addKeyword}
                        disabled={!newKeyword.trim() || 
                                 formData.preferences.keywords.includes(newKeyword.trim()) ||
                                 formData.preferences.keywords.length >= 20}
                        style={{
                          padding: '12px 20px',
                          background: '#3b82f6',
                          color: '#fff',
                          border: 'none',
                          borderRadius: '8px',
                          cursor: 'pointer',
                          fontSize: '14px',
                          fontWeight: '600',
                          opacity: (!newKeyword.trim() || 
                                   formData.preferences.keywords.includes(newKeyword.trim()) ||
                                   formData.preferences.keywords.length >= 20) ? 0.5 : 1,
                          transition: 'all 0.3s ease'
                        }}
                      >
                        添加
                      </button>
                    </div>

                    {/* 已添加的关键词标签 */}
                    {formData.preferences.keywords.length > 0 && (
                      <div style={{ 
                        display: 'flex', 
                        flexWrap: 'wrap',
                        gap: '8px'
                      }}>
                        {formData.preferences.keywords.map((keyword, index) => (
                          <div
                            key={index}
                            style={{
                              display: 'flex',
                              alignItems: 'center',
                              gap: '6px',
                              padding: '8px 12px',
                              background: '#eff6ff',
                              border: '1px solid #3b82f6',
                              borderRadius: '20px',
                              fontSize: '14px',
                              color: '#1e40af'
                            }}
                          >
                            <span>{keyword}</span>
                            <button
                              onClick={() => removeKeyword(keyword)}
                              style={{
                                background: 'none',
                                border: 'none',
                                color: '#1e40af',
                                cursor: 'pointer',
                                fontSize: '16px',
                                padding: '0',
                                width: '20px',
                                height: '20px',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                borderRadius: '50%',
                                transition: 'all 0.2s ease'
                              }}
                              onMouseEnter={(e) => {
                                e.currentTarget.style.background = '#dc2626';
                                e.currentTarget.style.color = '#fff';
                              }}
                              onMouseLeave={(e) => {
                                e.currentTarget.style.background = 'none';
                                e.currentTarget.style.color = '#1e40af';
                              }}
                            >
                              ×
                            </button>
                          </div>
                        ))}
                      </div>
                    )}

                    {/* 提示信息 */}
                    <p style={{ 
                      fontSize: '12px', 
                      color: '#999', 
                      marginTop: '8px',
                      marginBottom: '0'
                    }}>
                      最多可添加 20 个关键词，按回车键快速添加
                    </p>
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
