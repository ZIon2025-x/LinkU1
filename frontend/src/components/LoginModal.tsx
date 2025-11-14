import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { message } from 'antd';
import api from '../api';
import ForgotPasswordModal from './ForgotPasswordModal';
import VerificationModal from './VerificationModal';
import { useLanguage } from '../contexts/LanguageContext';

interface LoginModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
  onReopen?: () => void; // 用于重新打开登录弹窗
  showForgotPassword?: boolean; // 忘记密码弹窗状态
  onShowForgotPassword?: () => void; // 显示忘记密码弹窗
  onHideForgotPassword?: () => void; // 隐藏忘记密码弹窗
}

const LoginModal: React.FC<LoginModalProps> = ({ 
  isOpen, 
  onClose, 
  onSuccess, 
  onReopen,
  showForgotPassword = false, 
  onShowForgotPassword, 
  onHideForgotPassword 
}) => {
  const { t, language } = useLanguage();
  const [isLogin, setIsLogin] = useState(true);
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    confirmPassword: '',
    username: '',
    phone: '',
    invitationCode: ''
  });
  const [agreedToTerms, setAgreedToTerms] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [showVerificationModal, setShowVerificationModal] = useState(false);
  const [registeredEmail, setRegisteredEmail] = useState('');
  const [loginMethod, setLoginMethod] = useState<'password' | 'code' | 'phone'>('code');
  const [verificationCode, setVerificationCode] = useState('');
  const [codeSent, setCodeSent] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const [phoneForCode, setPhoneForCode] = useState('');
  const countdownTimerRef = React.useRef<NodeJS.Timeout | null>(null);
  
  // 清理倒计时
  React.useEffect(() => {
    return () => {
      if (countdownTimerRef.current) {
        clearInterval(countdownTimerRef.current);
      }
    };
  }, []);
  const [passwordValidation, setPasswordValidation] = useState({
    is_valid: false,
    score: 0,
    strength: 'weak',
    errors: [],
    suggestions: []
  });
  const navigate = useNavigate();

  // 翻译密码验证错误信息
  const translatePasswordError = (errorText: string): string => {
    // 匹配密码长度错误
    const tooShortMatch = errorText.match(/密码长度至少需要(\d+)个字符/);
    if (tooShortMatch) {
      const minLength = tooShortMatch[1];
      return t('auth.passwordTooShort').replace('{minLength}', minLength);
    }
    
    const tooShort12Match = errorText.match(/密码长度至少需要12个字符/);
    if (tooShort12Match) {
      return t('auth.passwordTooShort12');
    }
    
    const tooLongMatch = errorText.match(/密码长度不能超过(\d+)个字符/);
    if (tooLongMatch) {
      const maxLength = tooLongMatch[1];
      return t('auth.passwordTooLong').replace('{maxLength}', maxLength);
    }
    
    // 匹配字符类型错误
    if (errorText.includes('密码必须包含至少一个大写字母')) {
      return t('auth.passwordMissingUppercase');
    }
    if (errorText.includes('密码必须包含至少一个小写字母')) {
      return t('auth.passwordMissingLowercase');
    }
    if (errorText.includes('密码必须包含至少一个数字')) {
      return t('auth.passwordMissingDigit');
    }
    if (errorText.includes('密码必须包含至少一个特殊字符')) {
      return t('auth.passwordMissingSpecial');
    }
    
    // 匹配其他错误
    if (errorText.includes('密码过于常见')) {
      return t('auth.passwordTooCommon');
    }
    if (errorText.includes('密码不能包含用户名')) {
      return t('auth.passwordContainsUsername');
    }
    if (errorText.includes('密码不能包含邮箱前缀')) {
      return t('auth.passwordContainsEmail');
    }
    
    // 如果没有匹配，返回原文
    return errorText;
  };

  // 翻译密码验证建议信息
  const translatePasswordSuggestion = (suggestionText: string): string => {
    if (suggestionText.includes('避免使用重复的字符序列')) {
      return t('auth.passwordAvoidRepeating');
    }
    return suggestionText;
  };

  // 密码验证防抖定时器
  const passwordValidationTimeoutRef = React.useRef<NodeJS.Timeout | null>(null);

  // 密码验证函数
  const validatePassword = React.useCallback(async (password: string) => {
    if (!password || password.length === 0) {
      setPasswordValidation({
        is_valid: false,
        score: 0,
        strength: 'weak',
        errors: [],
        suggestions: []
      });
      return;
    }

    try {
      const response = await api.post('/api/users/password/validate', {
        password: password,
        username: formData.username || '',
        email: formData.email || ''
      });
      
      // 确保返回的数据格式正确
      if (response.data) {
        setPasswordValidation({
          is_valid: response.data.is_valid || false,
          score: response.data.score || 0,
          strength: response.data.strength || 'weak',
          errors: response.data.errors || [],
          suggestions: response.data.suggestions || []
        });
      }
    } catch (error: any) {
      console.error('密码验证失败:', error);
      // 验证失败时，至少显示错误信息
      if (error?.response?.data?.errors) {
        setPasswordValidation({
          is_valid: false,
          score: 0,
          strength: 'weak',
          errors: error.response.data.errors,
          suggestions: error.response.data.suggestions || []
        });
      }
    }
  }, [formData.username, formData.email]);

  // 触发密码验证（带防抖）
  const triggerPasswordValidation = React.useCallback((password: string) => {
    // 清除之前的定时器
    if (passwordValidationTimeoutRef.current) {
      clearTimeout(passwordValidationTimeoutRef.current);
    }
    
    // 立即清空密码为空时的验证结果
    if (!password || password.length === 0) {
      setPasswordValidation({
        is_valid: false,
        score: 0,
        strength: 'weak',
        errors: [],
        suggestions: []
      });
      return;
    }
    
    // 设置防抖，延迟300ms后验证（避免移动端输入法频繁触发）
    passwordValidationTimeoutRef.current = setTimeout(() => {
      validatePassword(password);
    }, 300);
  }, [validatePassword]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    const currentValue = e.target.value; // 确保获取最新值
    
    setFormData(prev => ({
      ...prev,
      [name]: currentValue
    }));
    setError('');
    
    // 如果是密码字段且是注册模式，使用最新的值进行防抖密码验证
    if (name === 'password' && !isLogin) {
      triggerPasswordValidation(currentValue);
    }
  };

  // 处理输入事件（移动端支持，用于处理输入法的实时输入）
  const handleInput = (e: React.FormEvent<HTMLInputElement>) => {
    const target = e.currentTarget;
    const name = target.name;
    const actualValue = target.value; // 直接从input元素获取最新值
    
    // 对于密码字段，确保状态同步（移动端输入法可能需要）
    if (name === 'password') {
      setFormData(prev => ({
        ...prev,
        [name]: actualValue
      }));
      
      // 如果是注册模式，进行防抖密码验证
      if (!isLogin && actualValue) {
        triggerPasswordValidation(actualValue);
      }
    }
  };

  // 组件卸载时清理定时器
  React.useEffect(() => {
    return () => {
      if (passwordValidationTimeoutRef.current) {
        clearTimeout(passwordValidationTimeoutRef.current);
      }
    };
  }, []);

  // 发送验证码
  const handleSendCode = async (email: string) => {
    setLoading(true);
    setError('');
    try {
      const res = await api.post('/api/secure-auth/send-verification-code', {
        email: email.trim().toLowerCase(),
      });
      
      setCodeSent(true);
      setCountdown(300); // 5分钟倒计时
      message.success(t('auth.codeSent') || '验证码已发送');
      
      // 开始倒计时
      if (countdownTimerRef.current) {
        clearInterval(countdownTimerRef.current);
      }
      countdownTimerRef.current = setInterval(() => {
        setCountdown((prev) => {
          if (prev <= 1) {
            if (countdownTimerRef.current) {
              clearInterval(countdownTimerRef.current);
              countdownTimerRef.current = null;
            }
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
      
    } catch (err: any) {
      let msg = t('auth.codeSent') || '发送验证码失败';
      if (err?.response?.data?.detail) {
        msg = err.response.data.detail;
      } else if (err?.message) {
        msg = err.message;
      }
      setError(msg);
      message.error(msg);
    } finally {
      setLoading(false);
    }
  };

  // 发送手机验证码
  const handleSendPhoneCode = async (phone: string) => {
    setLoading(true);
    setError('');
    try {
      const res = await api.post('/api/secure-auth/send-phone-verification-code', {
        phone: phone.trim(),
      });
      
      setPhoneForCode(phone.trim());
      setCodeSent(true);
      setCountdown(300); // 5分钟倒计时
      message.success(t('auth.codeSent') || '验证码已发送');
      
      // 开始倒计时
      if (countdownTimerRef.current) {
        clearInterval(countdownTimerRef.current);
      }
      countdownTimerRef.current = setInterval(() => {
        setCountdown((prev) => {
          if (prev <= 1) {
            if (countdownTimerRef.current) {
              clearInterval(countdownTimerRef.current);
              countdownTimerRef.current = null;
            }
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
      
    } catch (err: any) {
      let msg = t('auth.codeSent') || '发送验证码失败';
      if (err?.response?.data?.detail) {
        msg = err.response.data.detail;
      } else if (err?.message) {
        msg = err.message;
      }
      setError(msg);
      message.error(msg);
    } finally {
      setLoading(false);
    }
  };

  // 验证码登录（邮箱）
  const handleCodeLogin = async (email: string, code: string) => {
    setLoading(true);
    setError('');
    try {
      const res = await api.post('/api/secure-auth/login-with-code', {
        email: email.trim().toLowerCase(),
        verification_code: code.trim(),
      });
      
      // 所有设备都使用HttpOnly Cookie认证，无需localStorage存储
      
      // 登录成功后获取CSRF token
      try {
        await api.get('/api/csrf/token');
      } catch (error) {
        console.warn('获取CSRF token失败:', error);
      }
      
      // 登录成功后获取用户资料，更新语言偏好
      try {
        const userRes = await api.get('/api/users/profile/me');
        const userData = userRes.data;
        
        // 如果用户有语言偏好设置，且与当前语言不同，则更新语言
        if (userData.language_preference && userData.language_preference !== localStorage.getItem('language')) {
          localStorage.setItem('language', userData.language_preference);
        }
      } catch (error) {
        console.warn('获取用户资料失败:', error);
      }
      
      if (res.data.is_new_user) {
        message.success(t('auth.newUserCreated') || '新用户已自动创建');
      }
      message.success(t('auth.loginWithCodeSuccess') || t('auth.loginSuccess'));
      
      // 添加短暂延迟确保认证信息设置完成
      setTimeout(() => {
        onSuccess?.();
        onClose();
        window.location.reload();
      }, 100);
    } catch (err: any) {
      let msg = t('auth.loginError');
      if (err?.response?.data?.detail) {
        if (typeof err.response.data.detail === 'string') {
          msg = err.response.data.detail;
        } else if (Array.isArray(err.response.data.detail)) {
          msg = err.response.data.detail.map((item: any) => item.msg).join('；');
        } else if (typeof err.response.data.detail === 'object' && err.response.data.detail.msg) {
          msg = err.response.data.detail.msg;
        } else {
          msg = JSON.stringify(err.response.data.detail);
        }
      } else if (err?.message) {
        msg = err.message;
      }
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  // 手机号验证码登录
  const handlePhoneCodeLogin = async (phone: string, code: string) => {
    setLoading(true);
    setError('');
    try {
      const res = await api.post('/api/secure-auth/login-with-phone-code', {
        phone: phone.trim(),
        verification_code: code.trim(),
      });
      
      // 所有设备都使用HttpOnly Cookie认证，无需localStorage存储
      
      // 登录成功后获取CSRF token
      try {
        await api.get('/api/csrf/token');
      } catch (error) {
        console.warn('获取CSRF token失败:', error);
      }
      
      // 登录成功后获取用户资料，更新语言偏好
      try {
        const userRes = await api.get('/api/users/profile/me');
        const userData = userRes.data;
        
        // 如果用户有语言偏好设置，且与当前语言不同，则更新语言
        if (userData.language_preference && userData.language_preference !== localStorage.getItem('language')) {
          localStorage.setItem('language', userData.language_preference);
        }
      } catch (error) {
        console.warn('获取用户资料失败:', error);
      }
      
      if (res.data.is_new_user) {
        message.success(t('auth.newUserCreated') || '新用户已自动创建');
      }
      message.success(t('auth.loginWithCodeSuccess') || t('auth.loginSuccess'));
      
      // 添加短暂延迟确保认证信息设置完成
      setTimeout(() => {
        onSuccess?.();
        onClose();
        window.location.reload();
      }, 100);
    } catch (err: any) {
      let msg = t('auth.loginError');
      if (err?.response?.data?.detail) {
        if (typeof err.response.data.detail === 'string') {
          msg = err.response.data.detail;
        } else if (Array.isArray(err.response.data.detail)) {
          msg = err.response.data.detail.map((item: any) => item.msg).join('；');
        } else if (typeof err.response.data.detail === 'object' && err.response.data.detail.msg) {
          msg = err.response.data.detail.msg;
        } else {
          msg = JSON.stringify(err.response.data.detail);
        }
      } else if (err?.message) {
        msg = err.message;
      }
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      if (isLogin) {
        // 如果是邮箱验证码登录模式
        if (loginMethod === 'code') {
          if (!codeSent) {
            // 发送验证码
            await handleSendCode(formData.email);
            return;
          } else {
            // 使用验证码登录
            await handleCodeLogin(formData.email, verificationCode);
            return;
          }
        }
        
        // 如果是手机号验证码登录模式
        if (loginMethod === 'phone') {
          if (!codeSent) {
            // 发送手机验证码
            await handleSendPhoneCode(formData.phone);
            return;
          } else {
            // 使用手机验证码登录
            await handlePhoneCodeLogin(phoneForCode || formData.phone, verificationCode);
            return;
          }
        }
        
        // 密码登录逻辑 - 使用与Login.tsx相同的格式
        const res = await api.post('/api/secure-auth/login', {
          email: formData.email,
          password: formData.password,
        });
        
        // 所有设备都使用HttpOnly Cookie认证，无需localStorage存储
        
        // 登录成功后获取CSRF token
        try {
          await api.get('/api/csrf/token');
        } catch (error) {
          console.warn('获取CSRF token失败:', error);
        }
        
        // 登录成功后获取用户资料，更新语言偏好
        try {
          const userRes = await api.get('/api/users/profile/me');
          const userData = userRes.data;
          
          // 如果用户有语言偏好设置，且与当前语言不同，则更新语言
          if (userData.language_preference && userData.language_preference !== localStorage.getItem('language')) {
            localStorage.setItem('language', userData.language_preference);
          }
        } catch (error) {
          console.warn('获取用户资料失败:', error);
        }
        
        // 添加短暂延迟确保认证信息设置完成
        setTimeout(() => {
          onSuccess?.();
          onClose();
          window.location.reload(); // 刷新页面以更新用户状态和语言
        }, 100);
      } else {
        // 注册逻辑
        if (formData.password !== formData.confirmPassword) {
          setError(t('auth.passwordMismatch'));
          setLoading(false);
          return;
        }
        
        if (!agreedToTerms) {
          setError(t('auth.agreeToTermsFirst'));
          setLoading(false);
          return;
        }
        
        // 检查密码强度
        if (!passwordValidation.is_valid) {
          setError(t('auth.passwordNotSecure'));
          setLoading(false);
          return;
        }
        
        const res = await api.post('/api/users/register', {
          email: formData.email,
          password: formData.password,
          name: formData.username,  // 改为 name
          phone: formData.phone,
          invitation_code: formData.invitationCode || null,  // 邀请码
          agreed_to_terms: agreedToTerms,  // 记录用户同意状态
          terms_agreed_at: new Date().toISOString()  // 记录同意时间
        });
        
        // 处理注册成功后的逻辑
        if (res.data.verification_required) {
          message.success(`注册成功！我们已向 ${res.data.email} 发送了验证邮件，请检查您的邮箱并点击验证链接完成注册。`);
          // 显示验证弹窗而不是跳转页面
          setRegisteredEmail(res.data.email);
          setShowVerificationModal(true);
        } else {
          message.success(res.data.message || t('auth.registerSuccess'));
          // 开发环境：直接跳转到登录页面
          setTimeout(() => {
            navigate('/login');
            onClose(); // 关闭弹窗
          }, 1500);
        }
        
        // 清空表单数据
        setFormData({
          email: '',
          password: '',
          confirmPassword: '',
          username: '',
          phone: '',
          invitationCode: ''
        });
      }
    } catch (err: any) {
      console.error('注册/登录错误:', err);
      console.error('错误响应:', err?.response?.data);
      
      let msg = isLogin ? t('auth.loginFailed') : t('auth.registerFailed');
      
      // 优先处理HTTP响应错误
      if (err?.response?.data) {
        const responseData = err.response.data;
        
        // 处理detail字段
        if (responseData.detail) {
          if (typeof responseData.detail === 'string') {
            msg = responseData.detail;
          } else if (Array.isArray(responseData.detail)) {
            msg = responseData.detail.map((item: any) => item.msg || item).join('；');
          } else if (typeof responseData.detail === 'object' && responseData.detail.msg) {
            msg = responseData.detail.msg;
          } else {
            msg = JSON.stringify(responseData.detail);
          }
        }
        // 处理message字段
        else if (responseData.message) {
          msg = responseData.message;
        }
        // 处理其他错误信息
        else if (responseData.error) {
          msg = responseData.error;
        }
      }
      // 处理网络错误或其他错误
      else if (err?.message) {
        if (err.message.includes('Request failed with status code')) {
          msg = '网络请求失败，请检查网络连接';
        } else {
          msg = err.message;
        }
      }
      
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleLogin = () => {
    // Google登录逻辑（暂时显示提示）
    message.info(t('auth.googleLoginNotImplemented'));
  };

  if (!isOpen) return null;

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000,
      padding: '20px'
    }}>
      {/* 登录弹窗内容 */}
      {!showForgotPassword && (
        <div style={{
          backgroundColor: '#fff',
          borderRadius: '16px',
          padding: '32px',
          width: '100%',
          maxWidth: '400px',
          maxHeight: '90vh',
          overflow: 'auto',
          boxShadow: '0 20px 40px rgba(0, 0, 0, 0.1)',
          position: 'relative'
        }}>
        {/* 关闭按钮 */}
        <button
          onClick={onClose}
          style={{
            position: 'absolute',
            top: '16px',
            right: '16px',
            background: 'none',
            border: 'none',
            fontSize: '24px',
            cursor: 'pointer',
            color: '#666',
            width: '32px',
            height: '32px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            borderRadius: '50%',
            transition: 'background-color 0.2s'
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.backgroundColor = '#f5f5f5';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.backgroundColor = 'transparent';
          }}
        >
          ×
        </button>

        {/* 标题 */}
        <h2 style={{
          fontSize: '28px',
          fontWeight: 'bold',
          color: '#333',
          marginBottom: '8px',
          textAlign: 'center'
        }}>
          {isLogin ? t('auth.loginTitle') : t('register.title')}
        </h2>

        {/* 欢迎礼品横幅 */}
        <div style={{
          backgroundColor: '#e3f2fd',
          borderRadius: '8px',
          padding: '12px 16px',
          marginBottom: '24px',
          textAlign: 'center',
          border: '1px solid #bbdefb'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
            <span style={{ fontSize: '20px' }}>💎</span>
            <span style={{ fontSize: '14px', color: '#1976d2' }}>
              {t('home.welcomeGift')}
            </span>
          </div>
        </div>

        {/* 错误提示 */}
        {error && (
          <div style={{
            backgroundColor: '#ffebee',
            color: '#c62828',
            padding: '12px',
            borderRadius: '8px',
            marginBottom: '16px',
            fontSize: '14px',
            textAlign: 'center'
          }}>
            {error}
          </div>
        )}


        {/* 表单 */}
        <form onSubmit={handleSubmit}>
          {/* 邮箱输入（密码登录和邮箱验证码登录时显示） */}
          {isLogin && loginMethod !== 'phone' && (
            <div style={{ marginBottom: '16px' }}>
              <label style={{
                display: 'block',
                fontSize: '14px',
                fontWeight: '600',
                color: '#333',
                marginBottom: '8px'
              }}>
                {t('common.email')}
              </label>
              <input
                type="email"
                name="email"
                value={formData.email}
                onChange={handleInputChange}
                placeholder={t('common.email')}
                required
                disabled={isLogin && loginMethod === 'code' && codeSent}
                style={{
                  width: '100%',
                  padding: '12px 16px',
                  border: '1px solid #ddd',
                  borderRadius: '8px',
                  fontSize: '16px',
                  boxSizing: 'border-box',
                  transition: 'border-color 0.2s',
                  backgroundColor: isLogin && loginMethod === 'code' && codeSent ? '#f5f5f5' : '#fff'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#3b82f6';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#ddd';
                }}
              />
            </div>
          )}

          {/* 手机号输入（手机号验证码登录时显示） - 暂时隐藏 */}
          {false && isLogin && loginMethod === 'phone' && (
            <div style={{ marginBottom: '16px' }}>
              <label style={{
                display: 'block',
                fontSize: '14px',
                fontWeight: '600',
                color: '#333',
                marginBottom: '8px'
              }}>
                {t('common.phone')}
              </label>
              <input
                type="tel"
                name="phone"
                value={formData.phone}
                onChange={(e) => {
                  const value = e.target.value.replace(/\D/g, ''); // 只允许数字
                  setFormData(prev => ({ ...prev, phone: value }));
                  if (!codeSent) {
                    setPhoneForCode(value);
                  }
                }}
                placeholder={t('auth.phonePlaceholder')}
                required
                disabled={codeSent}
                maxLength={11}
                style={{
                  width: '100%',
                  padding: '12px 16px',
                  border: '1px solid #ddd',
                  borderRadius: '8px',
                  fontSize: '16px',
                  boxSizing: 'border-box',
                  transition: 'border-color 0.2s',
                  backgroundColor: codeSent ? '#f5f5f5' : '#fff'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#3b82f6';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#ddd';
                }}
              />
            </div>
          )}

          {/* 注册时显示邮箱输入 */}
          {!isLogin && (
            <div style={{ marginBottom: '16px' }}>
              <label style={{
                display: 'block',
                fontSize: '14px',
                fontWeight: '600',
                color: '#333',
                marginBottom: '8px'
              }}>
                {t('common.email')}
              </label>
              <input
                type="email"
                name="email"
                value={formData.email}
                onChange={handleInputChange}
                placeholder={t('common.email')}
                required
                style={{
                  width: '100%',
                  padding: '12px 16px',
                  border: '1px solid #ddd',
                  borderRadius: '8px',
                  fontSize: '16px',
                  boxSizing: 'border-box',
                  transition: 'border-color 0.2s'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#3b82f6';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#ddd';
                }}
              />
            </div>
          )}

          {/* 验证码输入（邮箱验证码登录模式下显示） */}
          {isLogin && loginMethod === 'code' && codeSent && (
            <>
              <div style={{ marginBottom: '16px' }}>
                <label style={{
                  display: 'block',
                  fontSize: '14px',
                  fontWeight: '600',
                  color: '#333',
                  marginBottom: '8px'
                }}>
                  {t('auth.verificationCode')}
                </label>
                <input
                  type="text"
                  value={verificationCode}
                  onChange={(e) => {
                    const value = e.target.value.replace(/\D/g, ''); // 只允许数字
                    setVerificationCode(value.slice(0, 6));
                  }}
                  placeholder={t('auth.enterVerificationCode')}
                  maxLength={6}
                  required
                  style={{
                    width: '100%',
                    padding: '12px 16px',
                    border: '1px solid #ddd',
                    borderRadius: '8px',
                    fontSize: '24px',
                    letterSpacing: '8px',
                    textAlign: 'center',
                    boxSizing: 'border-box',
                    transition: 'border-color 0.2s',
                    fontFamily: 'monospace'
                  }}
                  onFocus={(e) => {
                    e.target.style.borderColor = '#3b82f6';
                  }}
                  onBlur={(e) => {
                    e.target.style.borderColor = '#ddd';
                  }}
                />
              </div>
              <div style={{ textAlign: 'center', marginBottom: '16px', color: '#666', fontSize: '12px' }}>
                <div>{t('auth.codeSentToEmail').replace('{email}', formData.email)}</div>
                {countdown > 0 && (
                  <div style={{ marginTop: '4px' }}>
                    {t('auth.codeExpiresIn').replace('{seconds}', String(countdown))}
                  </div>
                )}
              </div>
              <div style={{ textAlign: 'center', marginBottom: '16px' }}>
                <button
                  type="button"
                  onClick={() => handleSendCode(formData.email)}
                  disabled={countdown > 0 || loading}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: countdown > 0 ? '#999' : '#3b82f6',
                    cursor: countdown > 0 ? 'not-allowed' : 'pointer',
                    fontSize: '14px',
                    textDecoration: 'underline',
                    padding: '4px 8px'
                  }}
                >
                  {countdown > 0 ? `${t('auth.resendCode')} (${Math.floor(countdown / 60)}:${String(countdown % 60).padStart(2, '0')})` : t('auth.resendCode')}
                </button>
              </div>
            </>
          )}

          {/* 验证码输入（手机号验证码登录模式下显示） - 暂时隐藏 */}
          {false && isLogin && loginMethod === 'phone' && codeSent && (
            <>
              <div style={{ marginBottom: '16px' }}>
                <label style={{
                  display: 'block',
                  fontSize: '14px',
                  fontWeight: '600',
                  color: '#333',
                  marginBottom: '8px'
                }}>
                  {t('auth.verificationCode')}
                </label>
                <input
                  type="text"
                  value={verificationCode}
                  onChange={(e) => {
                    const value = e.target.value.replace(/\D/g, ''); // 只允许数字
                    setVerificationCode(value.slice(0, 6));
                  }}
                  placeholder={t('auth.enterVerificationCode')}
                  maxLength={6}
                  required
                  style={{
                    width: '100%',
                    padding: '12px 16px',
                    border: '1px solid #ddd',
                    borderRadius: '8px',
                    fontSize: '24px',
                    letterSpacing: '8px',
                    textAlign: 'center',
                    boxSizing: 'border-box',
                    transition: 'border-color 0.2s',
                    fontFamily: 'monospace'
                  }}
                  onFocus={(e) => {
                    e.target.style.borderColor = '#3b82f6';
                  }}
                  onBlur={(e) => {
                    e.target.style.borderColor = '#ddd';
                  }}
                />
              </div>
              <div style={{ textAlign: 'center', marginBottom: '16px', color: '#666', fontSize: '12px' }}>
                <div>{t('auth.codeSentToPhone').replace('{phone}', phoneForCode)}</div>
                {countdown > 0 && (
                  <div style={{ marginTop: '4px' }}>
                    {t('auth.codeExpiresIn').replace('{seconds}', String(countdown))}
                  </div>
                )}
              </div>
              <div style={{ textAlign: 'center', marginBottom: '16px' }}>
                <button
                  type="button"
                  onClick={() => handleSendPhoneCode(phoneForCode)}
                  disabled={countdown > 0 || loading}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: countdown > 0 ? '#999' : '#3b82f6',
                    cursor: countdown > 0 ? 'not-allowed' : 'pointer',
                    fontSize: '14px',
                    textDecoration: 'underline',
                    padding: '4px 8px'
                  }}
                >
                  {countdown > 0 ? `${t('auth.resendCode')} (${Math.floor(countdown / 60)}:${String(countdown % 60).padStart(2, '0')})` : t('auth.resendCode')}
                </button>
              </div>
            </>
          )}

          {/* 密码输入（仅在密码登录模式下显示） */}
          {isLogin && loginMethod === 'password' && (
            <div style={{ marginBottom: '16px' }}>
              <label style={{
                display: 'block',
                fontSize: '14px',
                fontWeight: '600',
                color: '#333',
                marginBottom: '8px'
              }}>
                {t('common.password')}
              </label>
              <input
                type="password"
                name="password"
                value={formData.password}
                onChange={handleInputChange}
                placeholder={t('common.password')}
                required
                style={{
                  width: '100%',
                  padding: '12px 16px',
                  border: '1px solid #ddd',
                  borderRadius: '8px',
                  fontSize: '16px',
                  boxSizing: 'border-box',
                  transition: 'border-color 0.2s'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#3b82f6';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#ddd';
                }}
              />
              {/* 忘记密码链接 */}
              <div style={{ textAlign: 'right', marginTop: '4px' }}>
                <button
                  type="button"
                  onClick={() => {
                    if (onShowForgotPassword) {
                      onShowForgotPassword();
                    }
                  }}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: '#3b82f6',
                    fontSize: '12px',
                    cursor: 'pointer',
                    textDecoration: 'underline',
                    padding: '0'
                  }}
                >
                  {t('auth.forgotPassword')}
                </button>
              </div>
            </div>
          )}

          {/* 注册时显示用户名和手机号 */}
          {!isLogin && (
            <>
              <div style={{ marginBottom: '16px' }}>
                <label style={{
                  display: 'block',
                  fontSize: '14px',
                  fontWeight: '600',
                  color: '#333',
                  marginBottom: '8px'
                }}>
                  {t('common.username')}
                </label>
                <input
                  type="text"
                  name="username"
                  value={formData.username}
                  onChange={handleInputChange}
                  placeholder={t('common.username')}
                  required
                  style={{
                    width: '100%',
                    padding: '12px 16px',
                    border: '1px solid #ddd',
                    borderRadius: '8px',
                    fontSize: '16px',
                    boxSizing: 'border-box',
                    transition: 'border-color 0.2s'
                  }}
                  onFocus={(e) => {
                    e.target.style.borderColor = '#3b82f6';
                  }}
                  onBlur={(e) => {
                    e.target.style.borderColor = '#ddd';
                  }}
                />
              </div>

              <div style={{ marginBottom: '16px' }}>
                <label style={{
                  display: 'block',
                  fontSize: '14px',
                  fontWeight: '600',
                  color: '#333',
                  marginBottom: '8px'
                }}>
                  {t('auth.phone')}
                </label>
                <input
                  type="tel"
                  name="phone"
                  value={formData.phone}
                  onChange={handleInputChange}
                  placeholder={t('auth.phonePlaceholder')}
                  style={{
                    width: '100%',
                    padding: '12px 16px',
                    border: '1px solid #ddd',
                    borderRadius: '8px',
                    fontSize: '16px',
                    boxSizing: 'border-box',
                    transition: 'border-color 0.2s'
                  }}
                  onFocus={(e) => {
                    e.target.style.borderColor = '#3b82f6';
                  }}
                  onBlur={(e) => {
                    e.target.style.borderColor = '#ddd';
                  }}
                />
              </div>

              {/* 邀请码输入框 */}
              <div style={{ marginBottom: '16px' }}>
                <label style={{
                  display: 'block',
                  fontSize: '14px',
                  fontWeight: '600',
                  color: '#333',
                  marginBottom: '8px'
                }}>
                  {t('auth.inviterId')}
                </label>
                <input
                  type="text"
                  name="invitationCode"
                  value={formData.invitationCode}
                  onChange={handleInputChange}
                  placeholder={t('auth.inviterIdPlaceholder')}
                  style={{
                    width: '100%',
                    padding: '12px 16px',
                    border: '1px solid #ddd',
                    borderRadius: '8px',
                    fontSize: '16px',
                    boxSizing: 'border-box',
                    transition: 'border-color 0.2s'
                  }}
                  onFocus={(e) => {
                    e.target.style.borderColor = '#3b82f6';
                  }}
                  onBlur={(e) => {
                    e.target.style.borderColor = '#ddd';
                  }}
                />
              </div>
            </>
          )}

          {/* 密码输入（注册模式） */}
          {!isLogin && (
            <div style={{ marginBottom: '16px' }}>
              <label style={{
                display: 'block',
                fontSize: '14px',
                fontWeight: '600',
                color: '#333',
                marginBottom: '8px'
              }}>
                {t('common.password')}
              </label>
              <input
                type="password"
                name="password"
                value={formData.password}
                onChange={handleInputChange}
                onInput={handleInput}
                onKeyUp={(e) => {
                  // 移动端某些情况下需要keyup事件触发
                  const target = e.currentTarget;
                  if (target.name === 'password' && !isLogin) {
                    triggerPasswordValidation(target.value);
                  }
                }}
                placeholder={t('auth.passwordRequirements')}
                required
                autoComplete="new-password"
                style={{
                  width: '100%',
                  padding: '12px 16px',
                  border: '1px solid #ddd',
                borderRadius: '8px',
                fontSize: '16px',
                boxSizing: 'border-box',
                transition: 'border-color 0.2s'
              }}
              onFocus={(e) => {
                e.target.style.borderColor = '#3b82f6';
              }}
              onBlur={(e) => {
                e.target.style.borderColor = '#ddd';
                // 失焦时也触发一次验证，确保最后的值被验证
                if (!isLogin) {
                  const currentValue = e.target.value || formData.password;
                  if (currentValue) {
                    // 清除防抖定时器，立即验证
                    if (passwordValidationTimeoutRef.current) {
                      clearTimeout(passwordValidationTimeoutRef.current);
                    }
                    validatePassword(currentValue);
                  }
                }
              }}
            />
            
            {/* 密码强度显示 - 仅在注册模式且输入密码时显示 */}
            {!isLogin && formData.password && (
              <div style={{
                marginTop: '8px',
                padding: '8px 12px',
                backgroundColor: '#f8f9fa',
                borderRadius: '6px',
                border: '1px solid #e9ecef'
              }}>
                <div style={{ marginBottom: '6px' }}>
                  <span style={{ 
                    color: passwordValidation.score >= 80 ? '#52c41a' : 
                           passwordValidation.score >= 60 ? '#faad14' : '#ff4d4f',
                    fontWeight: 'bold',
                    fontSize: '13px'
                  }}>
                    {t('auth.passwordStrength')}: {passwordValidation.strength === 'weak' ? t('auth.weak') : 
                           passwordValidation.strength === 'medium' ? t('auth.medium') :
                           passwordValidation.strength === 'strong' ? t('auth.strong') : t('auth.veryStrong')} 
                    ({passwordValidation.score}/100)
                  </span>
                </div>
                
                {passwordValidation.errors.length > 0 && (
                  <div style={{ color: '#ff4d4f', marginBottom: '6px', fontSize: '12px' }}>
                    {passwordValidation.errors.map((error, index) => (
                      <div key={index}>• {translatePasswordError(error)}</div>
                    ))}
                  </div>
                )}
                
                {passwordValidation.suggestions.length > 0 && (
                  <div style={{ color: '#1890ff', fontSize: '12px' }}>
                    <div style={{ fontWeight: 'bold', marginBottom: '2px' }}>{t('auth.suggestions')}:</div>
                    {passwordValidation.suggestions.map((suggestion, index) => (
                      <div key={index}>• {translatePasswordSuggestion(suggestion)}</div>
                    ))}
                  </div>
                )}
              </div>
            )}
            
              {/* 注册时显示密码要求 */}
            </div>
          )}

          {/* 注册时显示确认密码 */}
          {!isLogin && (
            <div style={{ marginBottom: '16px' }}>
              <label style={{
                display: 'block',
                fontSize: '14px',
                fontWeight: '600',
                color: '#333',
                marginBottom: '8px'
              }}>
                {t('auth.confirmPassword')}
              </label>
              <input
                type="password"
                name="confirmPassword"
                value={formData.confirmPassword}
                onChange={handleInputChange}
                placeholder={t('auth.confirmPassword')}
                required
                style={{
                  width: '100%',
                  padding: '12px 16px',
                  border: '1px solid #ddd',
                  borderRadius: '8px',
                  fontSize: '16px',
                  boxSizing: 'border-box',
                  transition: 'border-color 0.2s'
                }}
                onFocus={(e) => {
                  e.target.style.borderColor = '#3b82f6';
                }}
                onBlur={(e) => {
                  e.target.style.borderColor = '#ddd';
                }}
              />
            </div>
          )}

          {/* 用户协议 - 只在注册时显示 */}
          {!isLogin && (
            <div style={{
              fontSize: '12px',
              color: '#666',
              marginBottom: '24px',
              lineHeight: '1.4',
              display: 'flex',
              alignItems: 'flex-start',
              gap: '8px'
            }}>
              <div style={{
                position: 'relative',
                marginTop: '2px'
              }}>
                <input
                  type="checkbox"
                  checked={agreedToTerms}
                  onChange={(e) => setAgreedToTerms(e.target.checked)}
                  style={{
                    width: '16px',
                    height: '16px',
                    accentColor: '#52c41a',
                    cursor: 'pointer'
                  }}
                />
              </div>
              <div style={{ flex: 1 }}>
                {t('auth.agreeToTerms')}{' '}
                <a 
                  href="/terms" 
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{ color: '#3b82f6', textDecoration: 'underline', cursor: 'pointer' }}
                  onClick={(e) => {
                    e.preventDefault();
                    navigate('/terms');
                  }}
                >
                  {t('auth.termsOfService')}
                </a>
                {language === 'zh' ? '、' : ', '}
                <a 
                  href="/privacy" 
                  target="_blank"
                  rel="noopener noreferrer"
                  style={{ color: '#3b82f6', textDecoration: 'underline', cursor: 'pointer' }}
                  onClick={(e) => {
                    e.preventDefault();
                    navigate('/privacy');
                  }}
                >
                  {t('common.privacyPolicy')}
                </a>
                {language === 'zh' ? '，' : ', '}{t('auth.smsNotification')}
              </div>
            </div>
          )}

          {/* 提交按钮 */}
          <button
            type="submit"
            disabled={loading || (!isLogin && !agreedToTerms) || (isLogin && loginMethod === 'code' && codeSent && verificationCode.length !== 6) || (isLogin && loginMethod === 'phone' && codeSent && verificationCode.length !== 6)}
            style={{
              width: '100%',
              padding: '14px',
              backgroundColor: (loading || (!isLogin && !agreedToTerms) || (isLogin && loginMethod === 'code' && codeSent && verificationCode.length !== 6) || (isLogin && loginMethod === 'phone' && codeSent && verificationCode.length !== 6)) ? '#ccc' : '#3b82f6',
              color: '#fff',
              border: 'none',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: '600',
              cursor: (loading || (!isLogin && !agreedToTerms) || (isLogin && loginMethod === 'code' && codeSent && verificationCode.length !== 6) || (isLogin && loginMethod === 'phone' && codeSent && verificationCode.length !== 6)) ? 'not-allowed' : 'pointer',
              marginBottom: '16px',
              transition: 'background-color 0.2s'
            }}
            onMouseEnter={(e) => {
              if (!loading && !((isLogin && loginMethod === 'code' && codeSent && verificationCode.length !== 6) || (isLogin && loginMethod === 'phone' && codeSent && verificationCode.length !== 6))) {
                e.currentTarget.style.backgroundColor = '#2563eb';
              }
            }}
            onMouseLeave={(e) => {
              if (!loading) {
                e.currentTarget.style.backgroundColor = '#3b82f6';
              }
            }}
          >
            {loading ? t('common.processing') : 
             (isLogin && loginMethod === 'code' && !codeSent) ? t('auth.sendVerificationCode') :
             (isLogin && loginMethod === 'phone' && !codeSent) ? t('auth.sendVerificationCode') :
             (isLogin ? t('auth.login') : t('auth.register'))}
          </button>

          {/* 切换登录/注册 */}
          <div style={{ textAlign: 'center', marginBottom: '16px' }}>
            <button
              type="button"
              onClick={() => {
                setIsLogin(!isLogin);
                setAgreedToTerms(false); // 切换时重置同意状态
                setError(''); // 清空错误信息
              }}
              style={{
                background: 'none',
                border: 'none',
                color: '#3b82f6',
                fontSize: '14px',
                cursor: 'pointer',
                textDecoration: 'underline'
              }}
            >
              {isLogin ? t('auth.noAccount') : t('auth.haveAccount')}
            </button>
          </div>

          {/* 分割线 */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            marginBottom: '16px'
          }}>
            <div style={{
              flex: 1,
              height: '1px',
              backgroundColor: '#e0e0e0'
            }}></div>
            <span style={{
              padding: '0 16px',
              fontSize: '14px',
              color: '#666'
            }}>或</span>
            <div style={{
              flex: 1,
              height: '1px',
              backgroundColor: '#e0e0e0'
            }}></div>
          </div>

          {/* Google登录按钮 - 暂时隐藏，功能未实现 */}
          {false && (
          <button
            type="button"
            onClick={handleGoogleLogin}
            style={{
              width: '100%',
              padding: '14px',
              backgroundColor: '#fff',
              color: '#333',
              border: '1px solid #ddd',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: '600',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '12px',
              transition: 'border-color 0.2s',
              marginBottom: '12px'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.borderColor = '#3b82f6';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.borderColor = '#ddd';
            }}
          >
            <div style={{
              width: '20px',
              height: '20px',
              backgroundColor: '#4285f4',
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#fff',
              fontSize: '12px',
              fontWeight: 'bold'
            }}>
              G
            </div>
            {t('auth.continueWithGoogle')}
          </button>
          )}

          {/* 登录方式切换（仅在登录模式下显示） */}
          {isLogin && (
            <>
              <button
                type="button"
                onClick={() => {
                  setLoginMethod('password');
                  setCodeSent(false);
                  setVerificationCode('');
                  setPhoneForCode('');
                  setError('');
                }}
                style={{
                  width: '100%',
                  padding: '14px',
                  backgroundColor: loginMethod === 'password' ? '#3b82f6' : '#fff',
                  color: loginMethod === 'password' ? '#fff' : '#333',
                  border: loginMethod === 'password' ? 'none' : '1px solid #ddd',
                  borderRadius: '8px',
                  fontSize: '16px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  transition: 'all 0.2s',
                  marginBottom: '12px'
                }}
                onMouseEnter={(e) => {
                  if (loginMethod !== 'password') {
                    e.currentTarget.style.borderColor = '#3b82f6';
                    e.currentTarget.style.backgroundColor = '#f8f9fa';
                  }
                }}
                onMouseLeave={(e) => {
                  if (loginMethod !== 'password') {
                    e.currentTarget.style.borderColor = '#ddd';
                    e.currentTarget.style.backgroundColor = '#fff';
                  }
                }}
              >
                {t('auth.passwordLogin')}
              </button>
              <button
                type="button"
                onClick={() => {
                  setLoginMethod('code');
                  setCodeSent(false);
                  setVerificationCode('');
                  setPhoneForCode('');
                  setError('');
                }}
                style={{
                  width: '100%',
                  padding: '14px',
                  backgroundColor: loginMethod === 'code' ? '#3b82f6' : '#fff',
                  color: loginMethod === 'code' ? '#fff' : '#333',
                  border: loginMethod === 'code' ? 'none' : '1px solid #ddd',
                  borderRadius: '8px',
                  fontSize: '16px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  transition: 'all 0.2s',
                  marginBottom: '12px'
                }}
                onMouseEnter={(e) => {
                  if (loginMethod !== 'code') {
                    e.currentTarget.style.borderColor = '#3b82f6';
                    e.currentTarget.style.backgroundColor = '#f8f9fa';
                  }
                }}
                onMouseLeave={(e) => {
                  if (loginMethod !== 'code') {
                    e.currentTarget.style.borderColor = '#ddd';
                    e.currentTarget.style.backgroundColor = '#fff';
                  }
                }}
              >
                {t('auth.loginWithCode')}
              </button>
              {/* 手机号登录按钮 - 暂时隐藏 */}
              {false && (
              <button
                type="button"
                onClick={() => {
                  setLoginMethod('phone');
                  setCodeSent(false);
                  setVerificationCode('');
                  setPhoneForCode('');
                  setError('');
                }}
                style={{
                  width: '100%',
                  padding: '14px',
                  backgroundColor: loginMethod === 'phone' ? '#3b82f6' : '#fff',
                  color: loginMethod === 'phone' ? '#fff' : '#333',
                  border: loginMethod === 'phone' ? 'none' : '1px solid #ddd',
                  borderRadius: '8px',
                  fontSize: '16px',
                  fontWeight: '600',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  transition: 'all 0.2s',
                  marginBottom: '12px'
                }}
                onMouseEnter={(e) => {
                  if (loginMethod !== 'phone') {
                    e.currentTarget.style.borderColor = '#3b82f6';
                    e.currentTarget.style.backgroundColor = '#f8f9fa';
                  }
                }}
                onMouseLeave={(e) => {
                  if (loginMethod !== 'phone') {
                    e.currentTarget.style.borderColor = '#ddd';
                    e.currentTarget.style.backgroundColor = '#fff';
                  }
                }}
              >
                {t('auth.phoneLogin')}
              </button>
              )}
              
              {/* 提示信息：新用户可以直接使用验证码登录创建新账号 */}
              {loginMethod === 'code' && (
                <div style={{
                  padding: '12px',
                  backgroundColor: '#e6f7ff',
                  border: '1px solid #91d5ff',
                  borderRadius: '8px',
                  marginBottom: '12px',
                  fontSize: '13px',
                  color: '#0050b3',
                  lineHeight: '1.5'
                }}>
                  💡 {t('auth.newUserCanLoginWithCode')}
                </div>
              )}
            </>
          )}
        </form>
        </div>
      )}
      
      {/* 忘记密码弹窗 */}
      <ForgotPasswordModal
        isOpen={showForgotPassword}
        onClose={() => {
          if (onHideForgotPassword) {
            onHideForgotPassword();
          }
        }}
        onBackToLogin={() => {
          if (onHideForgotPassword) {
            onHideForgotPassword();
          }
        }}
      />

      {/* 验证邮件弹窗 */}
      <VerificationModal
        isOpen={showVerificationModal}
        onClose={() => setShowVerificationModal(false)}
        email={registeredEmail}
        onLogin={() => {
          setShowVerificationModal(false);
          setIsLogin(true);
          if (onReopen) {
            onReopen();
          }
        }}
      />
    </div>
  );
};

export default LoginModal;
