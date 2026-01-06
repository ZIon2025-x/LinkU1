import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { message } from 'antd';
import api from '../api';
import ForgotPasswordModal from './ForgotPasswordModal';
import VerificationModal from './VerificationModal';
import { useLanguage } from '../contexts/LanguageContext';
import Captcha, { CaptchaRef } from './Captcha';

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
  const [phoneCountryCode, setPhoneCountryCode] = useState('+44'); // 仅支持英国
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
  const [captchaToken, setCaptchaToken] = useState<string>('');
  const [captchaSiteKey, setCaptchaSiteKey] = useState<string | null>(null);
  const [captchaType, setCaptchaType] = useState<'recaptcha' | 'hcaptcha' | null>(null);
  const [captchaEnabled, setCaptchaEnabled] = useState(false);
  const captchaRef = React.useRef<CaptchaRef>(null);
  
  // 获取 CAPTCHA 配置（弹窗打开时获取）
  React.useEffect(() => {
    if (!isOpen) return;
    
    const fetchCaptchaConfig = async () => {
      try {
        console.log('正在获取 CAPTCHA 配置...');
        const res = await api.get('/api/secure-auth/captcha-site-key');
        console.log('CAPTCHA 配置获取结果:', res.data);
        if (res.data.enabled && res.data.site_key) {
          setCaptchaSiteKey(res.data.site_key);
          setCaptchaType(res.data.type || 'recaptcha');
          setCaptchaEnabled(true);
          console.log('CAPTCHA 已启用:', { 
            siteKey: res.data.site_key, 
            type: res.data.type,
            enabled: true
          });
        } else {
          console.log('CAPTCHA 未启用或未配置:', res.data);
          setCaptchaEnabled(false);
          setCaptchaSiteKey(null);
        }
      } catch (error) {
        // CAPTCHA 未配置或获取失败，继续使用（开发环境）
        console.error('CAPTCHA 配置获取失败:', error);
        setCaptchaEnabled(false);
        setCaptchaSiteKey(null);
      }
    };
    fetchCaptchaConfig();
  }, [isOpen]);

  // 清理倒计时
  React.useEffect(() => {
    return () => {
      if (countdownTimerRef.current) {
        clearInterval(countdownTimerRef.current);
      }
    };
  }, []);
  const [passwordValidation, setPasswordValidation] = useState<{
    is_valid: boolean;
    score: number;
    strength: string;
    bars: number;
    errors: string[];
    suggestions: string[];
    missing_requirements: string[];
  }>({
    is_valid: false,
    score: 0,
    strength: 'weak',
    bars: 1,
    errors: [],
    suggestions: [],
    missing_requirements: []
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

  // 前端密码强度验证函数（当后端不可用时使用）
  const validatePasswordFrontend = React.useCallback((password: string, username?: string, email?: string) => {
    const errors: string[] = [];
    const missing_requirements: string[] = [];
    let score = 0;

    // 基本长度检查
    const min_length = 12;
    if (password.length < min_length) {
      errors.push(`密码长度至少需要${min_length}个字符`);
      missing_requirements.push(`至少${min_length}个字符`);
      score -= 20;
    } else if (password.length >= 16) {
      score += 10;
    }

    // 字符类型检查
    const has_upper = /[A-Z]/.test(password);
    const has_lower = /[a-z]/.test(password);
    const has_digit = /\d/.test(password);
    // 检查特殊字符（包括Unicode特殊字符，排除中文字符范围）
    const has_special = /[^\w\s\u4e00-\u9fff]/.test(password);

    // 收集缺少的要求
    if (!has_upper) {
      errors.push("密码必须包含至少一个大写字母");
      missing_requirements.push("大写字母 (例如: A, B, C)");
      score -= 15;
    }

    if (!has_lower) {
      errors.push("密码必须包含至少一个小写字母");
      missing_requirements.push("小写字母 (例如: a, b, c)");
      score -= 15;
    }

    if (!has_digit) {
      errors.push("密码必须包含至少一个数字");
      missing_requirements.push("数字 (例如: 0, 1, 2, 3)");
      score -= 15;
    }

    if (!has_special) {
      errors.push("密码必须包含至少一个特殊字符");
      missing_requirements.push("特殊字符 (例如: !@#$%^&*()_+-=...)");
      score -= 15;
    }

    // 字符类型奖励
    const char_types = [has_upper, has_lower, has_digit, has_special].filter(Boolean).length;
    score += char_types * 5;

    // 计算最终分数
    score = Math.max(0, Math.min(100, score));

    // 计算bars和strength（基于新的三条横线规则）
    const has_letter = has_upper || has_lower;

    let strength: string;
    let bars: number;

    // 三条横线：强（有大小写字母、数字和特殊字符）
    if (has_upper && has_lower && has_digit && has_special) {
      strength = "strong";
      bars = 3;
    }
    // 两条横线：中（有数字和字母，或者有数字和特殊字符）
    else if ((has_digit && has_letter) || (has_digit && has_special)) {
      strength = "medium";
      bars = 2;
    }
    // 一条横线：弱（只有数字）
    else if (has_digit && !has_letter && !has_special) {
      strength = "weak";
      bars = 1;
    }
    // 其他情况归为弱
    else {
      strength = "weak";
      bars = 1;
    }

    return {
      is_valid: errors.length === 0,
      score,
      strength,
      bars,
      errors,
      suggestions: [],
      missing_requirements
    };
  }, []);

  // 密码验证函数
  const validatePassword = React.useCallback(async (password: string) => {
    if (!password || password.length === 0) {
      setPasswordValidation({
        is_valid: false,
        score: 0,
        strength: 'weak',
        bars: 1,
        errors: [],
        suggestions: [],
        missing_requirements: []
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
        const validationData = {
          is_valid: response.data.is_valid || false,
          score: response.data.score || 0,
          strength: response.data.strength || 'weak',
          bars: response.data.bars !== undefined ? response.data.bars : 1,  // 确保bars字段存在
          errors: response.data.errors || [],
          suggestions: response.data.suggestions || [],
          missing_requirements: response.data.missing_requirements || []
        };
                setPasswordValidation(validationData);
      }
    } catch (error: any) {
            // 如果是网络错误（后端不可用），使用前端验证作为后备
      if (error?.code === 'ERR_NETWORK' || error?.message === 'Network Error') {
                const frontendValidation = validatePasswordFrontend(
          password,
          formData.username,
          formData.email
        );
                setPasswordValidation(frontendValidation);
        return;
      }
      
      // 验证失败时，至少显示错误信息
      if (error?.response?.data?.errors) {
        setPasswordValidation({
          is_valid: false,
          score: 0,
          strength: 'weak',
          bars: 1,
          errors: error.response.data.errors,
          suggestions: error.response.data.suggestions || [],
          missing_requirements: error.response.data.missing_requirements || []
        });
      } else {
        // 如果没有任何错误信息，使用前端验证
        const frontendValidation = validatePasswordFrontend(
          password,
          formData.username,
          formData.email
        );
        setPasswordValidation(frontendValidation);
      }
    }
  }, [formData.username, formData.email, validatePasswordFrontend]);

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
        bars: 1,
        errors: [],
        suggestions: [],
        missing_requirements: []
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
    let currentValue = e.target.value; // 确保获取最新值
    
    // 邀请码自动转换为大写（不区分大小写，但统一显示为大写）
    if (name === 'invitationCode') {
      currentValue = currentValue.toUpperCase();
    }
    
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
  const handleSendCode = async (email: string, captchaToken?: string) => {
    setLoading(true);
    setError('');
    try {
      const res = await api.post('/api/secure-auth/send-verification-code', {
        email: email.trim().toLowerCase(),
        captcha_token: captchaToken || null,
      });
      
      setCodeSent(true);
      setCountdown(600); // 10分钟倒计时
      // 发送成功后清除 CAPTCHA token，下次发送需要重新验证
      if (captchaEnabled) {
        setCaptchaToken('');
      }
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
  const handleSendPhoneCode = async (phone: string, captchaToken?: string) => {
    setLoading(true);
    setError('');
    try {
      console.log('发送手机验证码请求:', { phone: phone.trim(), captchaToken: captchaToken ? `${captchaToken.substring(0, 20)}...` : 'null' });
      const res = await api.post('/api/secure-auth/send-phone-verification-code', {
        phone: phone.trim(),
        captcha_token: captchaToken || null,
      });
      
      setPhoneForCode(phone.trim());
      setCodeSent(true);
      setCountdown(600); // 10分钟倒计时
      // 发送成功后清除 CAPTCHA token，下次发送需要重新验证
      if (captchaEnabled) {
        setCaptchaToken('');
      }
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
  const handleCodeLogin = async (email: string, code: string, captchaToken?: string) => {
    setLoading(true);
    setError('');
    try {
      const res = await api.post('/api/secure-auth/login-with-code', {
        email: email.trim().toLowerCase(),
        verification_code: code.trim(),
        captcha_token: captchaToken || null,
      });
      
      // 所有设备都使用HttpOnly Cookie认证，无需localStorage存储
      
      // 登录成功后获取CSRF token
      try {
        await api.get('/api/csrf/token');
      } catch (error) {
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
        // 静默处理错误
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
          const detail = err.response.data.detail;
          // 检查是否是验证码错误
          if (detail.includes('验证码错误') || (detail.includes('验证码') && (detail.includes('错误') || detail.includes('过期')))) {
            msg = t('auth.verificationCodeError') || '验证码验证错误';
          } else {
            msg = detail;
          }
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
  const handlePhoneCodeLogin = async (phone: string, code: string, captchaToken?: string) => {
    setLoading(true);
    setError('');
    try {
      const res = await api.post('/api/secure-auth/login-with-phone-code', {
        phone: phone.trim(),
        verification_code: code.trim(),
        captcha_token: captchaToken || null,
      });
      
      // 所有设备都使用HttpOnly Cookie认证，无需localStorage存储
      
      // 登录成功后获取CSRF token
      try {
        await api.get('/api/csrf/token');
      } catch (error) {
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
        // 静默处理错误
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
          const detail = err.response.data.detail;
          // 检查是否是验证码错误
          if (detail.includes('验证码错误') || (detail.includes('验证码') && (detail.includes('错误') || detail.includes('过期')))) {
            msg = t('auth.verificationCodeError') || '验证码验证错误';
          } else {
            msg = detail;
          }
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
      // 检查 CAPTCHA 验证（仅验证码登录需要，密码登录不需要）
      // 只有在验证码登录模式下，且未发送验证码时，才需要 CAPTCHA
      if (isLogin && (loginMethod === 'code' || loginMethod === 'phone') && captchaEnabled && captchaSiteKey && !codeSent) {
        if (!captchaToken) {
          setError('请先完成人机验证');
          setLoading(false);
          return;
        }
      }
      const currentCaptchaToken = captchaToken;

      if (isLogin) {
        // 如果是邮箱验证码登录模式
        if (loginMethod === 'code') {
          if (!codeSent) {
            // 发送验证码
            await handleSendCode(formData.email, currentCaptchaToken);
            return;
          } else {
            // 使用验证码登录
            await handleCodeLogin(formData.email, verificationCode, currentCaptchaToken);
            return;
          }
        }
        
        // 如果是手机号验证码登录模式
        if (loginMethod === 'phone') {
          if (!codeSent) {
            // 发送手机验证码（使用完整号码：国家代码+手机号）
            const fullPhone = phoneForCode || (phoneCountryCode + formData.phone);
            await handleSendPhoneCode(fullPhone, currentCaptchaToken);
            return;
          } else {
            // 使用手机验证码登录（使用完整号码）
            const fullPhone = phoneForCode || (phoneCountryCode + formData.phone);
            await handlePhoneCodeLogin(fullPhone, verificationCode, currentCaptchaToken);
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
          // 静默处理错误
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
        
        // 组合完整的手机号（国家代码 + 手机号）
        const fullPhone = formData.phone ? (phoneCountryCode + formData.phone) : null;
        
        const res = await api.post('/api/users/register', {
          email: formData.email,
          password: formData.password,
          name: formData.username,  // 改为 name
          phone: fullPhone,  // 发送完整的手机号（包含国家代码）
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
        setPhoneCountryCode('+44'); // 重置国家代码
      }
    } catch (err: any) {
      let msg = isLogin ? t('auth.loginFailed') : t('auth.registerFailed');
      
      // 优先处理HTTP响应错误
      if (err?.response?.data) {
        const responseData = err.response.data;
        
        // 处理detail字段
        if (responseData.detail) {
          if (typeof responseData.detail === 'string') {
            const detail = responseData.detail;
            // 检查是否是密码错误（仅密码登录时）
            if (isLogin && loginMethod === 'password' && (detail.includes('密码错误') || detail.includes('用户名或密码错误'))) {
              msg = t('auth.passwordError') || '账户密码错误';
            } else {
              msg = detail;
            }
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

          {/* CAPTCHA 组件（hCaptcha 需要显示，reCAPTCHA v3 是无感知的） */}
          {captchaEnabled && captchaSiteKey && captchaType === 'hcaptcha' && !codeSent && (
            <div style={{ marginBottom: '16px' }}>
              <Captcha
                siteKey={captchaSiteKey}
                type="hcaptcha"
                onVerify={(token) => {
                  setCaptchaToken(token);
                }}
                onError={(error) => {
                  setError('人机验证失败，请重试');
                }}
              />
            </div>
          )}

          {/* 手机号输入（手机号验证码登录时显示） */}
          {isLogin && loginMethod === 'phone' && (
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
              <div style={{ display: 'flex', gap: '8px' }}>
                {/* 国家代码选择（仅支持英国） */}
                <div
                  style={{
                    padding: '12px 16px',
                    border: '1px solid #ddd',
                    borderRadius: '8px',
                    fontSize: '16px',
                    backgroundColor: codeSent ? '#f5f5f5' : '#fff',
                    minWidth: '100px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: '#666'
                  }}
                >
                  🇬🇧 +44
                </div>
                {/* 手机号输入 */}
                <input
                  type="tel"
                  name="phone"
                  value={formData.phone}
                  onChange={(e) => {
                    let value = e.target.value.replace(/\D/g, ''); // 只允许数字
                    // 如果是英国号码（+44），且以07开头，去掉开头的0
                    if (phoneCountryCode === '+44' && value.startsWith('07') && value.length === 11) {
                      value = value.substring(1); // 去掉开头的0，变成 7700123456
                    }
                    setFormData(prev => ({ ...prev, phone: value }));
                    if (!codeSent && value) {
                      // 存储完整号码（包含国家代码）
                      setPhoneForCode(phoneCountryCode + value);
                    }
                  }}
                  placeholder="7700123456"
                  required
                  disabled={codeSent}
                  maxLength={15}
                  style={{
                    flex: 1,
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
                    // 更新完整号码
                    if (!codeSent && formData.phone) {
                      let phoneValue = formData.phone;
                      // 如果是英国号码（+44），且以07开头，去掉开头的0
                      if (phoneCountryCode === '+44' && phoneValue.startsWith('07') && phoneValue.length === 11) {
                        phoneValue = phoneValue.substring(1);
                        setFormData(prev => ({ ...prev, phone: phoneValue }));
                      }
                      setPhoneForCode(phoneCountryCode + phoneValue);
                    }
                  }}
                />
              </div>
            </div>
          )}

          {/* CAPTCHA 组件（交互式验证，发送验证码前必须完成） */}
          {/* 只在验证码登录模式下显示，且未发送验证码时 */}
          {(() => {
            // 调试：记录显示条件
            if (isLogin && (loginMethod === 'code' || loginMethod === 'phone') && !codeSent) {
              console.log('CAPTCHA 显示条件检查:', {
                isLogin,
                loginMethod,
                codeSent,
                captchaEnabled,
                captchaSiteKey: captchaSiteKey ? '已设置' : '未设置',
                shouldShow: captchaEnabled && captchaSiteKey
              });
            }
            return isLogin && (loginMethod === 'code' || loginMethod === 'phone') && !codeSent && captchaEnabled && captchaSiteKey;
          })() && (
            <div style={{ marginBottom: '16px' }}>
              <div style={{ 
                fontSize: '14px', 
                color: '#666', 
                marginBottom: '8px',
                textAlign: 'center',
                fontWeight: '500'
              }}>
                ⚠ 请完成人机验证（防止恶意刷验证码）
              </div>
              <Captcha
                ref={captchaRef}
                siteKey={captchaSiteKey || undefined}
                type={captchaType || 'recaptcha'}
                onVerify={(token) => {
                  setCaptchaToken(token);
                  setError(''); // 清除错误
                  console.log('CAPTCHA 验证成功，token 已设置:', token ? `${token.substring(0, 20)}...` : 'null');
                }}
                onError={(error) => {
                  setError('人机验证失败，请重试');
                  setCaptchaToken('');
                  console.error('CAPTCHA 验证失败:', error);
                  // 重置 CAPTCHA，让用户重新验证
                  if (captchaRef.current) {
                    setTimeout(() => {
                      captchaRef.current?.reset();
                    }, 500);
                  }
                }}
                onExpire={() => {
                  setError('验证已过期，请重新验证');
                  setCaptchaToken('');
                  console.warn('CAPTCHA 验证已过期');
                  // 重置 CAPTCHA
                  if (captchaRef.current) {
                    captchaRef.current.reset();
                  }
                }}
                theme="light"
                size="normal"
              />
              {captchaToken && (
                <div style={{
                  marginTop: '8px',
                  padding: '8px',
                  backgroundColor: '#f0f9ff',
                  border: '1px solid #3b82f6',
                  borderRadius: '4px',
                  textAlign: 'center',
                  color: '#3b82f6',
                  fontSize: '12px'
                }}>
                  ✓ 验证已完成
                </div>
              )}
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
                    // 当用户输入验证码时，清除错误信息
                    if (error) {
                      setError('');
                    }
                  }}
                  placeholder={t('auth.enterVerificationCode')}
                  maxLength={6}
                  required
                  style={{
                    width: '100%',
                    padding: '12px 16px',
                    border: error && (error.includes('验证码') || error.includes('verification') || error.includes('code')) ? '1px solid #ff4d4f' : '1px solid #ddd',
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
                    e.target.style.borderColor = error && (error.includes('验证码') || error.includes('verification') || error.includes('code')) ? '#ff4d4f' : '#ddd';
                  }}
                />
                {/* 验证码错误提示（在输入框下方显示） */}
                {error && (error.includes('验证码') || error.includes('verification') || error.includes('code')) && (
                  <div style={{
                    color: '#ff4d4f',
                    fontSize: '12px',
                    marginTop: '8px',
                    textAlign: 'center'
                  }}>
                    {error}
                  </div>
                )}
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
                  onClick={async () => {
                    // 重新发送验证码时，需要重新完成验证
                    if (captchaEnabled && captchaSiteKey) {
                      if (!captchaToken) {
                        message.error('请先完成人机验证');
                        return;
                      }
                      // 重置验证状态，要求用户重新验证
                      setCaptchaToken('');
                      message.info('请重新完成人机验证后发送');
                      return;
                    }
                    await handleSendCode(formData.email, captchaToken);
                  }}
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

          {/* 验证码输入（手机号验证码登录模式下显示） */}
          {isLogin && loginMethod === 'phone' && codeSent && (
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
                <div>{t('auth.codeSentToPhone').replace('{phone}', phoneForCode || (phoneCountryCode + formData.phone))}</div>
                {countdown > 0 && (
                  <div style={{ marginTop: '4px' }}>
                    {t('auth.codeExpiresIn').replace('{seconds}', String(countdown))}
                  </div>
                )}
              </div>
              <div style={{ textAlign: 'center', marginBottom: '16px' }}>
                <button
                  type="button"
                  onClick={async () => {
                    // 重新发送验证码时，必须重新完成验证（防止重复使用同一个 token）
                    if (captchaEnabled && captchaSiteKey) {
                      // 重置验证状态，要求用户重新验证
                      setCaptchaToken('');
                      setCodeSent(false); // 允许重新显示验证框
                      message.warning('请重新完成人机验证后发送');
                      return;
                    }
                    await handleSendPhoneCode(phoneForCode, captchaToken);
                  }}
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
                  onClick={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    if (onShowForgotPassword) {
                      onShowForgotPassword();
                    }
                  }}
                  onTouchStart={(e) => {
                    // 移动端触摸反馈
                    e.currentTarget.style.opacity = '0.7';
                  }}
                  onTouchEnd={(e) => {
                    e.currentTarget.style.opacity = '1';
                  }}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: '#3b82f6',
                    fontSize: '12px',
                    cursor: 'pointer',
                    textDecoration: 'underline',
                    padding: '8px 12px',
                    margin: '-8px -12px',
                    minHeight: '44px',
                    minWidth: '44px',
                    display: 'inline-flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    WebkitTapHighlightColor: 'transparent',
                    touchAction: 'manipulation',
                    userSelect: 'none'
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
                <div style={{ display: 'flex', gap: '8px' }}>
                  {/* 国家代码显示（仅支持英国） */}
                  <div
                    style={{
                      padding: '12px 16px',
                      border: '1px solid #ddd',
                      borderRadius: '8px',
                      fontSize: '16px',
                      backgroundColor: '#fff',
                      minWidth: '100px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      color: '#666'
                    }}
                  >
                    🇬🇧 +44
                  </div>
                  {/* 手机号输入 */}
                  <input
                    type="tel"
                    name="phone"
                    value={formData.phone}
                    onChange={(e) => {
                      let value = e.target.value.replace(/\D/g, ''); // 只允许数字
                      // 如果是英国号码（+44），且以07开头，去掉开头的0
                      if (phoneCountryCode === '+44' && value.startsWith('07') && value.length === 11) {
                        value = value.substring(1); // 去掉开头的0，变成 7700123456
                      }
                      setFormData(prev => ({ ...prev, phone: value }));
                    }}
                    placeholder="7700123456"
                    style={{
                      flex: 1,
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
                <div style={{ marginBottom: '6px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <span style={{ 
                    fontSize: '13px',
                    fontWeight: '500',
                    color: '#666'
                  }}>
                    {t('auth.passwordStrength')}:
                  </span>
                  <div style={{ display: 'flex', gap: '4px', alignItems: 'center' }}>
                    {/* 密码强度横线显示 */}
                    {[1, 2, 3].map((bar) => {
                      const bars = passwordValidation.bars !== undefined ? passwordValidation.bars : 1;
                      const isActive = bar <= bars;
                      let barColor = '#d9d9d9'; // 默认灰色
                      
                      if (bars === 1) {
                        barColor = isActive ? '#ff4d4f' : '#d9d9d9'; // 弱：红色
                      } else if (bars === 2) {
                        barColor = isActive ? '#faad14' : '#d9d9d9'; // 中：橙色
                      } else if (bars === 3) {
                        barColor = isActive ? '#52c41a' : '#d9d9d9'; // 强：绿色
                      }
                      
                      return (
                        <div
                          key={bar}
                          style={{
                            width: '24px',
                            height: '4px',
                            backgroundColor: barColor,
                            borderRadius: '2px',
                            transition: 'background-color 0.3s'
                          }}
                        />
                      );
                    })}
                  </div>
                </div>
                
                {/* 实时提示：缺少什么 */}
                {passwordValidation.missing_requirements && passwordValidation.missing_requirements.length > 0 && (
                  <div style={{ color: '#ff9800', marginBottom: '6px', fontSize: '12px' }}>
                    <div style={{ fontWeight: 'bold', marginBottom: '4px' }}>缺少：</div>
                    {passwordValidation.missing_requirements.map((req, index) => (
                      <div key={index} style={{ marginBottom: '2px' }}>• {req}</div>
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
            disabled={Boolean(
              loading || 
              (!isLogin && !agreedToTerms) || 
              (isLogin && loginMethod === 'code' && codeSent && verificationCode.length !== 6) || 
              (isLogin && loginMethod === 'phone' && codeSent && verificationCode.length !== 6) ||
              // 只有验证码登录模式在发送验证码前需要 CAPTCHA，密码登录不需要
              (isLogin && (loginMethod === 'code' || loginMethod === 'phone') && captchaEnabled && !!captchaSiteKey && !codeSent && !captchaToken)
            )}
            style={{
              width: '100%',
              padding: '14px',
              backgroundColor: Boolean(
                loading || 
                (!isLogin && !agreedToTerms) || 
                (isLogin && loginMethod === 'code' && codeSent && verificationCode.length !== 6) || 
                (isLogin && loginMethod === 'phone' && codeSent && verificationCode.length !== 6) ||
                // 只有验证码登录模式在发送验证码前需要 CAPTCHA，密码登录不需要
                (isLogin && (loginMethod === 'code' || loginMethod === 'phone') && captchaEnabled && !!captchaSiteKey && !codeSent && !captchaToken)
              ) ? '#ccc' : '#3b82f6',
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
                setCodeSent(false);
                setVerificationCode('');
                setPhoneForCode('');
                setPhoneCountryCode('+44'); // 重置国家代码
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
              {/* 手机号登录按钮 */}
              <button
                type="button"
                onClick={() => {
                  setLoginMethod('phone');
                  setCodeSent(false);
                  setVerificationCode('');
                  setPhoneForCode('');
                  setPhoneCountryCode('+44'); // 重置为默认英国
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
              
              {/* 提示信息：新用户可以直接使用验证码登录创建新账号 */}
              {(loginMethod === 'code' || loginMethod === 'phone') && (
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
