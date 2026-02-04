import React, { useState, useEffect } from 'react';
import StripeConnectOnboarding from '../components/stripe/StripeConnectOnboarding';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { message, Modal } from 'antd';
import api, { fetchCurrentUser } from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import { getErrorMessage } from '../utils/errorHandler';
import { validateEmail, validateName } from '../utils/inputValidators';
import LazyImage from '../components/LazyImage';
import { useStripeConnect } from '../hooks/useStripeConnect';
import {
  ConnectComponentsProvider,
  ConnectAccountManagement,
  ConnectPayouts,
} from '@stripe/react-connect-js';

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

// 移动端检测函数
const isMobileDevice = () => {
  const isSmallScreen = window.innerWidth <= 768;
  const isMobileUA = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
  const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
  
  return isSmallScreen || (isMobileUA && isTouchDevice);
};

const TAB_IDS = ['payment', 'profile', 'preferences', 'notifications', 'privacy', 'security', 'studentVerification'] as const;

const Settings: React.FC = () => {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const { t } = useLanguage();
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'profile' | 'payment' | 'preferences' | 'notifications' | 'privacy' | 'security' | 'studentVerification'>('profile');
  const [isMobile, setIsMobile] = useState(false);
  const [stripeAccountId, setStripeAccountId] = useState<string | null>(null);
  const [, setStripeAccountStatus] = useState<any>(null);
  // 启用 payouts 和 account_management 组件（用于设置页面显示提现和账户管理）
  const stripeConnectInstance = useStripeConnect(stripeAccountId, true, true);
  const [sessions, setSessions] = useState<Array<any>>([]);
  const [sessionsLoading, setSessionsLoading] = useState(false);
  const [sessionsError, setSessionsError] = useState<string>('');
  const [newKeyword, setNewKeyword] = useState('');
  const [emailCodeSent, setEmailCodeSent] = useState(false);
  const [phoneCodeSent, setPhoneCodeSent] = useState(false);
  const [emailCodeCountdown, setEmailCodeCountdown] = useState(0);
  const [phoneCodeCountdown, setPhoneCodeCountdown] = useState(0);
  const [emailVerificationCode, setEmailVerificationCode] = useState('');
  const [phoneVerificationCode, setPhoneVerificationCode] = useState('');
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

  // 移动端检测
  useEffect(() => {
    const checkMobile = () => {
      const mobile = isMobileDevice();
      setIsMobile(mobile);
    };
    
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  useEffect(() => {
    // 加载用户数据
    loadUserData();
    // 检查 Stripe 账户状态
    checkStripeAccount();
  }, []);

  // 检查 Stripe 账户状态
  const checkStripeAccount = async () => {
    try {
      const response = await api.get('/api/stripe/connect/account/status');
      if (response.data && response.data.account_id) {
        setStripeAccountId(response.data.account_id);
        setStripeAccountStatus(response.data);
      } else {
        setStripeAccountId(null);
        setStripeAccountStatus(null);
      }
    } catch (error: any) {
      // 404 是正常的（没有账户）
      if (error.response?.status !== 404) {
        console.error('Error checking Stripe account:', error);
      }
      setStripeAccountId(null);
      setStripeAccountStatus(null);
    }
  };

  // 从 URL ?tab=payment 等同步到 activeTab（便于从其他页跳转到收款账户等）
  useEffect(() => {
    const tabFromUrl = searchParams.get('tab');
    if (tabFromUrl && TAB_IDS.includes(tabFromUrl as typeof TAB_IDS[number])) {
      setActiveTab(tabFromUrl as typeof activeTab);
    }
  }, [searchParams]);

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
              }
      
      // ⚠️ 使用fetchCurrentUser，利用缓存机制（不再使用时间戳参数绕过缓存）
      try {
        const userData = await fetchCurrentUser();
        // 格式化头像 URL
        if (userData.avatar) {
          userData.avatar = formatAvatarUrl(userData.avatar);
        }
        // 清理首尾空格（防止数据库中的空格问题）
        const residenceCity = userData.residence_city ? String(userData.residence_city).trim() : '';
        const languagePreference = userData.language_preference ? String(userData.language_preference).trim() : 'en';
        setUser(userData);
        setFormData(prev => ({
          ...prev,
          name: userData.name || '',
          email: userData.email || '',
          phone: userData.phone || '',
          residence_city: residenceCity,
          language_preference: languagePreference,
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
                if (error.response?.status === 401) {
          // 会话过期，重定向到登录页面
          navigate('/login');
          return;
        }
        setUser(null);
      }
    } catch (error) {
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
          const key = parts[i];
          if (key === undefined) break;
          current[key] = { ...(current[key] ?? {}) };
          current = current[key];
        }
        const lastKey = parts[parts.length - 1];
        if (lastKey !== undefined) current[lastKey] = value;
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
      // 验证输入
      if (formData.name) {
        const nameValidation = validateName(formData.name);
        if (!nameValidation.valid) {
          message.error(nameValidation.message);
          return;
        }
      }
      
      if (formData.email) {
        const emailValidation = validateEmail(formData.email);
        if (!emailValidation.valid) {
          message.error(emailValidation.message);
          return;
        }
      }
      
      // 保存个人资料（名字、常住城市、语言偏好）
      // 构建请求体，只包含需要更新的字段
      const updatePayload: any = {};
      
      // 名字：只在改变时更新
      if (formData.name !== user?.name && formData.name) {
        updatePayload.name = formData.name;
      }
      
      // 常住城市：只在改变时更新（允许更新为空）
      if (formData.residence_city !== user?.residence_city) {
        // 处理空字符串和null的情况
        const newCity = formData.residence_city?.trim() || null;
        const currentCity = user?.residence_city?.trim() || null;
        if (newCity !== currentCity) {
          updatePayload.residence_city = newCity;
        }
      }
      
      // 语言偏好：只在改变时更新
      if (formData.language_preference !== user?.language_preference) {
        updatePayload.language_preference = formData.language_preference || 'en';
      }
      
      // 邮箱：如果改变则更新（允许设置为空）
      if (formData.email !== user?.email) {
        updatePayload.email = formData.email || null;
        // 如果修改邮箱，需要验证码
        if (formData.email && formData.email !== user?.email) {
          if (!emailVerificationCode) {
            message.error(t('settings.emailVerificationRequired'));
            return;
          }
          updatePayload.email_verification_code = emailVerificationCode;
        }
      }
      
      // 手机号：如果改变则更新（允许设置为空）
      if (formData.phone !== user?.phone) {
        updatePayload.phone = formData.phone || null;
        // 如果修改手机号，需要验证码
        if (formData.phone && formData.phone !== user?.phone) {
          if (!phoneVerificationCode) {
            message.error(t('settings.phoneVerificationRequired'));
            return;
          }
          updatePayload.phone_verification_code = phoneVerificationCode;
        }
      }
      
      // 保存个人资料（如果有更新）
      if (Object.keys(updatePayload).length > 0) {
        // 使用 api.patch 而不是 fetch，这样能自动处理 Cookie 和 CSRF token
        await api.patch('/api/users/profile', updatePayload);
      }

      // 保存任务偏好设置（总是保存，即使个人资料没有更新）
      // 使用 api.put，自动处理 Cookie 和 CSRF token
      await api.put('/api/user-preferences', formData.preferences);
      
      // 如果既没有更新个人资料，也没有更新偏好，提示用户
      if (Object.keys(updatePayload).length === 0) {
        // 偏好已经保存，但为了用户体验，仍然显示成功消息
        message.success(t('settings.preferencesSaved'));
      }
      
      // ⚠️ 重新加载用户数据以获取最新的数据（使用fetchCurrentUser，利用缓存机制）
      try {
        const userData = await fetchCurrentUser();
        // 格式化头像 URL
        if (userData.avatar) {
          userData.avatar = formatAvatarUrl(userData.avatar);
        }
        setUser(userData);
        // 清理首尾空格（防止数据库中的空格问题）
        const residenceCity = userData.residence_city ? String(userData.residence_city).trim() : '';
        const languagePreference = userData.language_preference ? String(userData.language_preference).trim() : 'en';
        setFormData(prev => ({
          ...prev,
          name: userData.name || '',
          email: userData.email || '',
          phone: userData.phone || '',
          residence_city: residenceCity,
          language_preference: languagePreference,
        }));
      } catch (error) {
              }
      
      // 重置验证码状态
      setEmailCodeSent(false);
      setPhoneCodeSent(false);
      setEmailVerificationCode('');
      setPhoneVerificationCode('');
      setEmailCodeCountdown(0);
      setPhoneCodeCountdown(0);
      
      message.success(t('settings.saved'));
      // 如果语言偏好改变，刷新页面以应用新语言
      const currentLang = localStorage.getItem('language') || 'zh';
      if (formData.language_preference !== currentLang) {
        localStorage.setItem('language', formData.language_preference);
        window.location.reload();
      }
    } catch (error) {
            message.error(t('settings.saveFailed'));
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
    message.info(t('settings.changePasswordComingSoon'));
  };

  // 发送邮箱修改验证码
  const handleSendEmailCode = async () => {
    if (!formData.email) {
      message.error(t('settings.pleaseEnterNewEmail'));
      return;
    }
    
    if (formData.email === user?.email) {
      message.info(t('settings.emailSameAsCurrent'));
      return;
    }
    
    try {
      await api.post('/api/users/profile/send-email-update-code', {
        new_email: formData.email
      });
      message.success(t('settings.verificationCodeSentToEmail'));
      setEmailCodeSent(true);
      setEmailCodeCountdown(60);
      
      // 倒计时
      const timer = setInterval(() => {
        setEmailCodeCountdown((prev) => {
          if (prev <= 1) {
            clearInterval(timer);
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  // 发送手机号修改验证码
  const handleSendPhoneCode = async () => {
    if (!formData.phone) {
      message.error(t('settings.pleaseEnterNewPhone'));
      return;
    }
    
    if (formData.phone === user?.phone) {
      message.info(t('settings.phoneSameAsCurrent'));
      return;
    }
    
    try {
      await api.post('/api/users/profile/send-phone-update-code', {
        new_phone: formData.phone
      });
      message.success(t('settings.verificationCodeSentToPhone'));
      setPhoneCodeSent(true);
      setPhoneCodeCountdown(60);
      
      // 倒计时
      const timer = setInterval(() => {
        setPhoneCodeCountdown((prev) => {
          if (prev <= 1) {
            clearInterval(timer);
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
    } catch (error: any) {
      message.error(getErrorMessage(error));
    }
  };

  const handleDeleteAccount = () => {
    Modal.confirm({
      title: t('settings.confirmDeleteAccount'),
      content: t('settings.confirmDeleteAccountMessage'),
      okText: t('common.ok'),
      cancelText: t('common.cancel'),
      onOk: () => {
        message.info(t('settings.deleteAccountComingSoon'));
      }
    });
  };

  const loadSessions = async () => {
    try {
      setSessionsLoading(true);
      setSessionsError('');
      const res = await api.get('/api/secure-auth/sessions');
      setSessions(Array.isArray(res.data.sessions) ? res.data.sessions : []);
    } catch (e: any) {
            setSessionsError(e?.message || t('settings.loadSessionsFailed'));
      setSessions([]);
    } finally {
      setSessionsLoading(false);
    }
  };

  const logoutOthers = async () => {
    Modal.confirm({
      title: t('settings.confirmLogoutOthers'),
      content: t('settings.confirmLogoutOthersMessage'),
      okText: t('common.ok'),
      cancelText: t('common.cancel'),
      onOk: async () => {
        try {
          setSessionsLoading(true);
          setSessionsError('');
          
          // 使用 api.post，自动处理 Cookie 和 CSRF token
          await api.post('/api/secure-auth/logout-others');
          await loadSessions();
          message.success(t('settings.loggedOutOtherDevices'));
        } catch (e: any) {
                    setSessionsError(e?.response?.data?.detail || e?.message || t('settings.logoutOthersFailed'));
          message.error(e?.response?.data?.detail || e?.message || t('settings.logoutOthersFailed'));
        } finally {
          setSessionsLoading(false);
        }
      }
    });
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
        {t('common.loading')}
      </div>
    );
  }

  const tabs = [
    { id: 'payment', label: t('wallet.stripe.paymentAccount'), icon: '💳' },
    { id: 'profile', label: t('settings.profile'), icon: '👤' },
    { id: 'preferences', label: t('settings.preferences'), icon: '🎯' },
    { id: 'notifications', label: t('settings.notifications'), icon: '🔔' },
    { id: 'privacy', label: t('settings.privacy'), icon: '🔒' },
    { id: 'security', label: t('settings.security'), icon: '🛡️' },
    { id: 'studentVerification', label: t('settings.studentVerification'), icon: '🎓' }
  ];

  return (
    <div style={{ 
      minHeight: '100vh', 
      background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
      padding: isMobile ? '0' : '20px'
    }}>
      <div style={{ 
        maxWidth: isMobile ? '100%' : '900px', 
        margin: '0 auto',
        background: '#fff',
        borderRadius: isMobile ? '0' : '16px',
        boxShadow: isMobile ? 'none' : '0 8px 32px rgba(0,0,0,0.1)',
        overflow: 'hidden',
        minHeight: isMobile ? '100vh' : 'auto'
      }}>
        {/* 头部 */}
        <div style={{
          background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
          color: '#fff',
          padding: isMobile ? '16px' : '30px',
          textAlign: 'center',
          position: 'relative',
          zIndex: 10
        }}>
          <button
            onClick={() => navigate('/')}
            style={{
              position: isMobile ? 'relative' : 'absolute',
              left: isMobile ? 'auto' : '20px',
              top: isMobile ? 'auto' : '20px',
              background: 'rgba(255,255,255,0.2)',
              border: 'none',
              color: '#fff',
              padding: isMobile ? '6px 12px' : '8px 16px',
              borderRadius: '20px',
              cursor: 'pointer',
              fontSize: isMobile ? '12px' : '14px',
              marginBottom: isMobile ? '8px' : '0',
              display: 'inline-block',
              zIndex: 100,
              pointerEvents: 'auto',
              transition: 'all 0.2s ease'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.3)';
              e.currentTarget.style.transform = 'scale(1.05)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
              e.currentTarget.style.transform = 'scale(1)';
            }}
          >
            ← {isMobile ? t('common.back') : t('settings.backToHome')}
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
          <div style={{ fontSize: isMobile ? '14px' : '16px', opacity: 0.9, marginTop: isMobile ? '8px' : '0' }}>
            {isMobile ? t('settings.accountSettings') : t('settings.manageAccountSettings')}
          </div>
        </div>

        {/* 移动端：顶部标签导航 */}
        {isMobile && (
          <div style={{
            background: '#fff',
            borderBottom: '1px solid #e9ecef',
            overflowX: 'auto',
            scrollbarWidth: 'none',
            msOverflowStyle: 'none',
            WebkitOverflowScrolling: 'touch',
            position: 'relative',
            zIndex: 1
          }}>
            <div style={{
              display: 'flex',
              minWidth: 'max-content',
              padding: '0'
            }}>
              {tabs.map(tab => (
                <div
                  key={tab.id}
                  onClick={() => {
                    setActiveTab(tab.id);
                    setSearchParams({ tab: tab.id });
                  }}
                  style={{
                    padding: '12px 16px',
                    cursor: 'pointer',
                    borderBottom: activeTab === tab.id ? '3px solid #3b82f6' : '3px solid transparent',
                    background: activeTab === tab.id ? '#f0f7ff' : 'transparent',
                    color: activeTab === tab.id ? '#3b82f6' : '#666',
                    fontWeight: activeTab === tab.id ? 'bold' : 'normal',
                    transition: 'all 0.3s ease',
                    whiteSpace: 'nowrap',
                    fontSize: '14px',
                    flexShrink: 0
                  }}
                >
                  <span style={{ marginRight: '6px' }}>{tab.icon}</span>
                  {tab.label}
                </div>
              ))}
            </div>
          </div>
        )}

        <div style={{ display: isMobile ? 'block' : 'flex' }}>
          {/* 桌面端：侧边栏 */}
          {!isMobile && (
            <div style={{
              width: '250px',
              background: '#f8f9fa',
              borderRight: '1px solid #e9ecef'
            }}>
              {tabs.map(tab => (
                <div
                  key={tab.id}
                  onClick={() => {
                    setActiveTab(tab.id);
                    setSearchParams({ tab: tab.id });
                  }}
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
          )}

          {/* 内容区域 */}
          <div style={{ flex: 1, padding: isMobile ? '16px' : '30px' }}>
            {activeTab === 'payment' && (
              <div>
                {/* 如果已有账户，显示账户信息和银行卡管理 */}
                {stripeAccountId ? (
                  <div>
                    {/* 账户管理和提现（包括银行卡信息） */}
                    {stripeConnectInstance && (
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
                        {/* 账户管理 */}
                        <div style={{ 
                          padding: '24px',
                          background: '#fff',
                          borderRadius: '16px',
                          boxShadow: '0 1px 3px rgba(0,0,0,0.08)',
                          border: '1px solid #f0f0f0'
                        }}>
                          <ConnectComponentsProvider connectInstance={stripeConnectInstance}>
                            <ConnectAccountManagement />
                          </ConnectComponentsProvider>
                        </div>
                        
                        {/* 提现管理 */}
                        <div style={{ 
                          padding: '24px',
                          background: '#fff',
                          borderRadius: '16px',
                          boxShadow: '0 1px 3px rgba(0,0,0,0.08)',
                          border: '1px solid #f0f0f0'
                        }}>
                          <ConnectComponentsProvider connectInstance={stripeConnectInstance}>
                            <ConnectPayouts />
                          </ConnectComponentsProvider>
                        </div>
                      </div>
                    )}
                  </div>
                ) : (
                  /* 如果没有账户，显示注册界面 */
                  <div style={{
                    padding: '32px',
                    background: '#fff',
                    borderRadius: '16px',
                    boxShadow: '0 1px 3px rgba(0,0,0,0.08)',
                    border: '1px solid #f0f0f0'
                  }}>
                    <div style={{
                      marginBottom: '24px',
                      textAlign: 'center'
                    }}>
                      <h3 style={{
                        fontSize: '20px',
                        fontWeight: '600',
                        color: '#1a202c',
                        marginBottom: '8px'
                      }}>
                        {t('wallet.stripe.setupPaymentAccount')}
                      </h3>
                      <p style={{
                        fontSize: '14px',
                        color: '#64748b',
                        lineHeight: '1.6'
                      }}>
                        {t('wallet.stripe.setupCompleteDesc')}
                      </p>
                    </div>
                    <StripeConnectOnboarding
                      onComplete={() => {
                        message.success(t('wallet.stripe.paymentAccountSetupComplete'));
                        // 重新检查账户状态
                        checkStripeAccount();
                      }}
                      onError={(error) => {
                        message.error(`设置失败: ${error}`);
                      }}
                    />
                  </div>
                )}
              </div>
            )}

            {activeTab === 'profile' && (
              <div>
                <h2 style={{ color: '#333', marginBottom: isMobile ? '16px' : '20px', fontSize: isMobile ? '18px' : '20px' }}>
                  👤 {t('settings.profile')}
                </h2>
                
                <div style={{ 
                  display: 'flex', 
                  flexDirection: isMobile ? 'column' : 'row',
                  alignItems: isMobile ? 'center' : 'flex-start',
                  marginBottom: isMobile ? '20px' : '30px',
                  gap: isMobile ? '16px' : '0'
                }}>
                  <LazyImage
                    src={formatAvatarUrl(user?.avatar)}
                    alt="头像"
                    style={{
                      width: isMobile ? '60px' : '50px',
                      height: isMobile ? '60px' : '50px',
                      borderRadius: '50%',
                      border: '2px solid #3b82f6',
                      marginRight: isMobile ? '0' : '20px',
                      objectFit: 'cover'
                    }}
                    onError={(e) => {
                                            // 如果加载失败，使用默认头像
                      if (e.currentTarget.src !== '/static/avatar2.png') {
                        e.currentTarget.src = '/static/avatar2.png';
                      }
                    }}
                  />
                  <div style={{ textAlign: isMobile ? 'center' : 'left' }}>
                    <button style={{
                      background: '#3b82f6',
                      color: '#fff',
                      border: 'none',
                      padding: isMobile ? '10px 20px' : '8px 16px',
                      borderRadius: '20px',
                      cursor: 'pointer',
                      fontSize: isMobile ? '15px' : '14px',
                      width: isMobile ? 'auto' : 'auto'
                    }}>
                      {t('settings.changeAvatar')}
                    </button>
                  </div>
                </div>

                <div style={{ display: 'grid', gap: isMobile ? '16px' : '20px' }}>
                  <div>
                    <label style={{ 
                      display: 'block', 
                      marginBottom: isMobile ? '6px' : '8px', 
                      fontWeight: 'bold', 
                      color: '#333',
                      fontSize: isMobile ? '14px' : '16px'
                    }}>
                      用户名
                    </label>
                    <input
                      type="text"
                      value={formData.name}
                      onChange={(e) => handleInputChange('name', e.target.value)}
                      placeholder={t('settings.usernamePlaceholder')}
                      style={{
                        width: '100%',
                        padding: isMobile ? '14px' : '12px',
                        border: '1px solid #ddd',
                        borderRadius: '8px',
                        fontSize: isMobile ? '16px' : '16px', // 移动端16px避免自动缩放
                        boxSizing: 'border-box'
                      }}
                    />
                    <p style={{ marginTop: '4px', marginBottom: '0', fontSize: '12px', color: '#999' }}>
                      {(() => {
                        if (!user?.name_updated_at) {
                          return t('settings.usernameHint');
                        }
                        try {
                          const lastUpdate = new Date(user.name_updated_at);
                          const now = new Date();
                          const daysDiff = Math.floor((now.getTime() - lastUpdate.getTime()) / (1000 * 60 * 60 * 24));
                          const daysLeft = 30 - daysDiff;
                          if (daysLeft > 0) {
                            return t('settings.usernameHintDaysLeft', { days: daysLeft });
                          } else {
                            return t('settings.usernameHint');
                          }
                        } catch (e) {
                          return t('settings.usernameHint');
                        }
                      })()}
                    </p>
                    <p style={{ marginTop: '4px', marginBottom: '0', fontSize: '12px', color: '#666' }}>
                      {t('settings.usernameRules')}
                    </p>
                  </div>

                  <div>
                    <label style={{ 
                      display: 'block', 
                      marginBottom: isMobile ? '6px' : '8px', 
                      fontWeight: 'bold', 
                      color: '#333',
                      fontSize: isMobile ? '14px' : '16px'
                    }}>
                      {t('settings.email')} {!formData.email && <span style={{ color: '#999', fontSize: '12px', fontWeight: 'normal' }}>({t('settings.optional')})</span>}
                    </label>
                    <div style={{ display: 'flex', gap: '8px', marginBottom: '4px' }}>
                      <input
                        type="email"
                        value={formData.email || ''}
                        onChange={(e) => {
                          handleInputChange('email', e.target.value);
                          setEmailCodeSent(false);
                          setEmailVerificationCode('');
                        }}
                        placeholder={t('settings.emailPlaceholder')}
                        style={{
                          flex: 1,
                          padding: isMobile ? '14px' : '12px',
                          border: '1px solid #ddd',
                          borderRadius: '8px',
                          fontSize: '16px',
                          boxSizing: 'border-box'
                        }}
                      />
                      {formData.email && formData.email !== user?.email && (
                        <button
                          type="button"
                          onClick={handleSendEmailCode}
                          disabled={emailCodeCountdown > 0}
                          style={{
                            padding: isMobile ? '14px 20px' : '12px 20px',
                            backgroundColor: emailCodeCountdown > 0 ? '#ccc' : '#3b82f6',
                            color: 'white',
                            border: 'none',
                            borderRadius: '8px',
                            fontSize: isMobile ? '14px' : '16px',
                            cursor: emailCodeCountdown > 0 ? 'not-allowed' : 'pointer',
                            whiteSpace: 'nowrap'
                          }}
                        >
                          {emailCodeCountdown > 0 ? `${emailCodeCountdown}${t('settings.seconds')}` : t('settings.sendVerificationCode')}
                        </button>
                      )}
                    </div>
                    {formData.email && formData.email !== user?.email && emailCodeSent && (
                      <input
                        type="text"
                        value={emailVerificationCode}
                        onChange={(e) => {
                          const value = e.target.value.replace(/\D/g, '').slice(0, 6);
                          setEmailVerificationCode(value);
                        }}
                        placeholder={t('settings.verificationCodePlaceholder')}
                        maxLength={6}
                        style={{
                          width: '100%',
                          padding: isMobile ? '14px' : '12px',
                          border: '1px solid #ddd',
                          borderRadius: '8px',
                          fontSize: '16px',
                          marginTop: '8px',
                          boxSizing: 'border-box'
                        }}
                      />
                    )}
                    <p style={{ marginTop: '4px', marginBottom: '0', fontSize: isMobile ? '11px' : '12px', color: '#999' }}>
                      {formData.email && formData.email !== user?.email 
                        ? t('settings.emailModificationHint') 
                        : formData.email 
                          ? t('settings.emailCanModify') 
                          : t('settings.emailCanBind')}
                    </p>
                  </div>

                  {/* 手机号设置 - 暂时隐藏 */}
                  {false && (
                  <div>
                    <label style={{ 
                      display: 'block', 
                      marginBottom: isMobile ? '6px' : '8px', 
                      fontWeight: 'bold', 
                      color: '#333',
                      fontSize: isMobile ? '14px' : '16px'
                    }}>
                      手机号 {!formData.phone && <span style={{ color: '#999', fontSize: '12px', fontWeight: 'normal' }}>(可选)</span>}
                    </label>
                    <div style={{ display: 'flex', gap: '8px', marginBottom: '4px' }}>
                      <input
                        type="tel"
                        value={formData.phone || ''}
                        onChange={(e) => {
                          const value = e.target.value.replace(/\D/g, ''); // 只允许数字
                          handleInputChange('phone', value);
                          setPhoneCodeSent(false);
                          setPhoneVerificationCode('');
                        }}
                        placeholder="请输入手机号（可选）"
                        maxLength={15}
                        style={{
                          flex: 1,
                          padding: isMobile ? '14px' : '12px',
                          border: '1px solid #ddd',
                          borderRadius: '8px',
                          fontSize: '16px',
                          boxSizing: 'border-box'
                        }}
                      />
                      {formData.phone && formData.phone !== user?.phone && (
                        <button
                          type="button"
                          onClick={handleSendPhoneCode}
                          disabled={phoneCodeCountdown > 0}
                          style={{
                            padding: isMobile ? '14px 20px' : '12px 20px',
                            backgroundColor: phoneCodeCountdown > 0 ? '#ccc' : '#3b82f6',
                            color: 'white',
                            border: 'none',
                            borderRadius: '8px',
                            fontSize: isMobile ? '14px' : '16px',
                            cursor: phoneCodeCountdown > 0 ? 'not-allowed' : 'pointer',
                            whiteSpace: 'nowrap'
                          }}
                        >
                          {phoneCodeCountdown > 0 ? `${phoneCodeCountdown}秒` : '发送验证码'}
                        </button>
                      )}
                    </div>
                    {formData.phone && formData.phone !== user?.phone && phoneCodeSent && (
                      <input
                        type="text"
                        value={phoneVerificationCode}
                        onChange={(e) => {
                          const value = e.target.value.replace(/\D/g, '').slice(0, 6);
                          setPhoneVerificationCode(value);
                        }}
                        placeholder={t('settings.verificationCodePlaceholder')}
                        maxLength={6}
                        style={{
                          width: '100%',
                          padding: isMobile ? '14px' : '12px',
                          border: '1px solid #ddd',
                          borderRadius: '8px',
                          fontSize: '16px',
                          marginTop: '8px',
                          boxSizing: 'border-box'
                        }}
                      />
                    )}
                    <p style={{ marginTop: '4px', marginBottom: '0', fontSize: isMobile ? '11px' : '12px', color: '#999' }}>
                      {formData.phone && formData.phone !== user?.phone 
                        ? '修改手机号需要验证码验证，验证码将发送到新手机号' 
                        : formData.phone 
                          ? '可以修改手机号' 
                          : '如果使用邮箱登录，可以在此绑定手机号'}
                    </p>
                  </div>
                  )}

                  <div>
                    <label style={{ 
                      display: 'block', 
                      marginBottom: isMobile ? '6px' : '8px', 
                      fontWeight: 'bold', 
                      color: '#333',
                      fontSize: isMobile ? '14px' : '16px'
                    }}>
                      常住城市
                    </label>
                    <select
                      value={formData.residence_city}
                      onChange={(e) => handleInputChange('residence_city', e.target.value)}
                      style={{
                        width: '100%',
                        padding: isMobile ? '14px' : '12px',
                        border: '1px solid #ddd',
                        borderRadius: '8px',
                        fontSize: '16px',
                        boxSizing: 'border-box',
                        appearance: 'none',
                        backgroundImage: 'url("data:image/svg+xml;charset=UTF-8,%3csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 24 24\' fill=\'none\' stroke=\'currentColor\' stroke-width=\'2\' stroke-linecap=\'round\' stroke-linejoin=\'round\'%3e%3cpolyline points=\'6 9 12 15 18 9\'%3e%3c/polyline%3e%3c/svg%3e")',
                        backgroundRepeat: 'no-repeat',
                        backgroundPosition: 'right 12px center',
                        backgroundSize: '16px',
                        paddingRight: isMobile ? '40px' : '36px'
                      }}
                    >
                      <option value="">请选择常住城市</option>
                      {LOCATION_OPTIONS.map(location => (
                        <option key={location} value={location}>{location}</option>
                      ))}
                    </select>
                    <p style={{ marginTop: '4px', marginBottom: '0', fontSize: isMobile ? '11px' : '12px', color: '#999' }}>
                      选择您常居住的城市
                    </p>
                  </div>

                  <div>
                    <label style={{ 
                      display: 'block', 
                      marginBottom: isMobile ? '6px' : '8px', 
                      fontWeight: 'bold', 
                      color: '#333',
                      fontSize: isMobile ? '14px' : '16px'
                    }}>
                      语言偏好
                    </label>
                    <select
                      value={formData.language_preference}
                      onChange={(e) => handleInputChange('language_preference', e.target.value)}
                      style={{
                        width: '100%',
                        padding: isMobile ? '14px' : '12px',
                        border: '1px solid #ddd',
                        borderRadius: '8px',
                        fontSize: '16px',
                        boxSizing: 'border-box',
                        appearance: 'none',
                        backgroundImage: 'url("data:image/svg+xml;charset=UTF-8,%3csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 24 24\' fill=\'none\' stroke=\'currentColor\' stroke-width=\'2\' stroke-linecap=\'round\' stroke-linejoin=\'round\'%3e%3cpolyline points=\'6 9 12 15 18 9\'%3e%3c/polyline%3e%3c/svg%3e")',
                        backgroundRepeat: 'no-repeat',
                        backgroundPosition: 'right 12px center',
                        backgroundSize: '16px',
                        paddingRight: isMobile ? '40px' : '36px'
                      }}
                    >
                      <option value="zh">中文</option>
                      <option value="en">English</option>
                    </select>
                    <p style={{ marginTop: '4px', marginBottom: '0', fontSize: isMobile ? '11px' : '12px', color: '#999' }}>
                      选择您偏好的界面语言
                    </p>
                  </div>
                </div>
              </div>
            )}

            {activeTab === 'preferences' && (
              <div>
                <h2 style={{ 
                  color: '#333', 
                  marginBottom: isMobile ? '16px' : '20px', 
                  fontSize: isMobile ? '18px' : '20px' 
                }}>
                  🎯 任务偏好
                </h2>
                
                <div style={{ display: 'grid', gap: isMobile ? '20px' : '30px' }}>
                  {/* 偏好的任务类型 */}
                  <div>
                    <label style={{ 
                      display: 'block', 
                      marginBottom: isMobile ? '8px' : '12px', 
                      fontWeight: 'bold', 
                      color: '#333',
                      fontSize: isMobile ? '15px' : '16px'
                    }}>
                      📋 偏好的任务类型
                    </label>
                    <p style={{ 
                      fontSize: isMobile ? '13px' : '14px', 
                      color: '#666', 
                      marginBottom: isMobile ? '10px' : '12px' 
                    }}>
                      选择您感兴趣的任务类型，系统会优先为您推荐这些类型的任务
                    </p>
                    <div style={{ 
                      display: 'grid', 
                      gridTemplateColumns: isMobile ? '1fr' : 'repeat(auto-fill, minmax(150px, 1fr))',
                      gap: isMobile ? '8px' : '12px'
                    }}>
                      {TASK_TYPE_OPTIONS.map(type => (
                        <label key={type} style={{ 
                          display: 'flex', 
                          alignItems: 'center',
                          padding: isMobile ? '14px' : '12px',
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
                            style={{ 
                              marginRight: isMobile ? '10px' : '8px', 
                              width: isMobile ? '18px' : '16px', 
                              height: isMobile ? '18px' : '16px', 
                              cursor: 'pointer' 
                            }}
                          />
                          <span style={{ fontSize: isMobile ? '15px' : '14px' }}>{type}</span>
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
                      marginBottom: isMobile ? '8px' : '12px', 
                      fontWeight: 'bold', 
                      color: '#333',
                      fontSize: isMobile ? '15px' : '16px'
                    }}>
                      🌟 偏好的任务等级
                    </label>
                    <p style={{ 
                      fontSize: isMobile ? '13px' : '14px', 
                      color: '#666', 
                      marginBottom: isMobile ? '10px' : '12px' 
                    }}>
                      选择您感兴趣的任务等級
                    </p>
                    <div style={{ 
                      display: 'grid', 
                      gridTemplateColumns: isMobile ? '1fr' : 'repeat(auto-fill, minmax(120px, 1fr))',
                      gap: isMobile ? '8px' : '12px'
                    }}>
                      {['Normal', 'VIP', 'Super'].map(level => (
                        <label key={level} style={{ 
                          display: 'flex', 
                          alignItems: 'center',
                          padding: isMobile ? '14px' : '12px',
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
                            style={{ 
                              marginRight: isMobile ? '10px' : '8px', 
                              width: isMobile ? '18px' : '16px', 
                              height: isMobile ? '18px' : '16px', 
                              cursor: 'pointer' 
                            }}
                          />
                          <span style={{ fontSize: isMobile ? '15px' : '14px' }}>{level}</span>
                        </label>
                      ))}
                    </div>
                  </div>

                  {/* 最少截止时间 */}
                  <div>
                    <label style={{ 
                      display: 'block', 
                      marginBottom: isMobile ? '8px' : '12px', 
                      fontWeight: 'bold', 
                      color: '#333',
                      fontSize: isMobile ? '15px' : '16px'
                    }}>
                      ⏰ 最少截止时间
                    </label>
                    <p style={{ 
                      fontSize: isMobile ? '13px' : '14px', 
                      color: '#666', 
                      marginBottom: isMobile ? '10px' : '12px' 
                    }}>
                      设置任务截止时间至少需要多少天，系统将只推荐符合此条件的任务
                    </p>
                    <div style={{ 
                      display: 'flex', 
                      flexDirection: isMobile ? 'column' : 'row',
                      alignItems: isMobile ? 'flex-start' : 'center',
                      gap: isMobile ? '8px' : '12px'
                    }}>
                      <input
                        type="number"
                        value={formData.preferences.min_deadline_days}
                        onChange={(e) => handleInputChange('preferences.min_deadline_days', parseInt(e.target.value) || 1)}
                        min="1"
                        max="30"
                        style={{
                          width: isMobile ? '100%' : '120px',
                          padding: isMobile ? '14px' : '12px',
                          border: '1px solid #ddd',
                          borderRadius: '8px',
                          fontSize: '16px',
                          boxSizing: 'border-box'
                        }}
                      />
                      <span style={{ color: '#666', fontSize: isMobile ? '15px' : '16px' }}>天</span>
                      <span style={{ fontSize: isMobile ? '12px' : '14px', color: '#999' }}>
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
                <h2 style={{ 
                  color: '#333', 
                  marginBottom: isMobile ? '16px' : '20px', 
                  fontSize: isMobile ? '18px' : '20px' 
                }}>
                  🔔 通知设置
                </h2>
                
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
                <h2 style={{ 
                  color: '#333', 
                  marginBottom: isMobile ? '16px' : '20px', 
                  fontSize: isMobile ? '18px' : '20px' 
                }}>
                  🔒 隐私设置
                </h2>
                
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
                <h2 style={{ 
                  color: '#333', 
                  marginBottom: isMobile ? '16px' : '20px', 
                  fontSize: isMobile ? '18px' : '20px' 
                }}>
                  🛡️ 安全设置
                </h2>
                
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

            {activeTab === 'studentVerification' && (
              <div>
                <h2 style={{
                  color: '#333',
                  marginBottom: isMobile ? '16px' : '20px',
                  fontSize: isMobile ? '18px' : '20px'
                }}>
                  🎓 {t('settings.studentVerification')}
                </h2>

                <div style={{
                  background: '#f8f9fa',
                  borderRadius: '12px',
                  padding: isMobile ? '16px' : '20px',
                  border: '1px solid #e9ecef',
                  marginBottom: '20px'
                }}>
                  <p style={{
                    color: '#666',
                    fontSize: '14px',
                    marginBottom: '20px'
                  }}>
                    {t('settings.studentVerificationDesc')}
                  </p>
                  <button
                    onClick={() => {
                      const lang = localStorage.getItem('language') || 'en';
                      navigate(`/${lang}/student-verification`);
                    }}
                    style={{
                      background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                      color: '#fff',
                      border: 'none',
                      padding: '12px 24px',
                      borderRadius: '25px',
                      cursor: 'pointer',
                      fontSize: '16px',
                      fontWeight: 'bold',
                      boxShadow: '0 4px 15px rgba(59, 130, 246, 0.3)',
                      transition: 'all 0.3s ease',
                      width: isMobile ? '100%' : 'auto'
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
                    {t('settings.startVerification')}
                  </button>
                </div>
              </div>
            )}

            {/* 保存按钮 - 收款账户标签页不需要保存按钮（Stripe Connect 组件自动保存） */}
            {activeTab !== 'payment' && (
              <div style={{ 
                marginTop: isMobile ? '20px' : '30px', 
                paddingTop: isMobile ? '16px' : '20px', 
                borderTop: '1px solid #e9ecef',
                textAlign: isMobile ? 'center' : 'right'
              }}>
                <button
                  onClick={handleSave}
                  style={{
                    background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                    color: '#fff',
                    border: 'none',
                    padding: isMobile ? '14px 40px' : '12px 30px',
                    borderRadius: '25px',
                    cursor: 'pointer',
                    fontSize: isMobile ? '16px' : '16px',
                    fontWeight: 'bold',
                    boxShadow: '0 4px 15px rgba(59, 130, 246, 0.3)',
                    transition: 'all 0.3s ease',
                    width: isMobile ? '100%' : 'auto',
                    maxWidth: isMobile ? 'none' : 'none'
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
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default Settings;
