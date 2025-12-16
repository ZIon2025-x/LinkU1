import React, { useState, useEffect } from 'react';
import { Form, Input, Button, Card, message } from 'antd';
import styled from 'styled-components';
import axios from 'axios';
import { useNavigate, useLocation } from 'react-router-dom';
import api from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import LanguageSwitcher from '../components/LanguageSwitcher';
import LoginModal from '../components/LoginModal';
import SEOHead from '../components/SEOHead';
import HreflangManager from '../components/HreflangManager';

const Wrapper = styled.div`
  min-height: 80vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f9f9f9;
`;

const StyledCard = styled(Card)`
  width: 350px;
  box-shadow: 0 2px 8px #f0f1f2;
`;

const ErrorMsg = styled.div`
  color: #ff4d4f;
  margin-bottom: 12px;
  text-align: center;
`;

const Login: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { t } = useLanguage();
  const [errorMsg, setErrorMsg] = useState('');
  const [loading, setLoading] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);
  const [loginMethod, setLoginMethod] = useState<'password' | 'code' | 'phone'>('password');
  const [verificationCode, setVerificationCode] = useState('');
  const [codeSent, setCodeSent] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const [emailForCode, setEmailForCode] = useState('');
  const [phoneForCode, setPhoneForCode] = useState('');
  const [phoneCountryCode, setPhoneCountryCode] = useState('+44'); // 仅支持英国
  const countdownTimerRef = React.useRef<NodeJS.Timeout | null>(null);
  
  // 生成canonical URL
  const canonicalUrl = `https://www.link2ur.com${location.pathname}`;
  
  // 清理倒计时
  useEffect(() => {
    return () => {
      if (countdownTimerRef.current) {
        clearInterval(countdownTimerRef.current);
      }
    };
  }, []);

  // 检查用户是否已登录
  useEffect(() => {
    // 直接检查用户是否已登录，HttpOnly Cookie会自动发送
    api.get('/api/users/profile/me')
      .then(() => {
        // 用户已登录，重定向到首页
        message.info(t('auth.alreadyLoggedIn'));
        navigate('/');
      })
      .catch(() => {
        // 用户未登录，继续显示登录页面
      });
  }, [navigate]);

  // 发送验证码
  const handleSendCode = async (email: string) => {
    setLoading(true);
    setErrorMsg('');
    try {
      const res = await api.post('/api/secure-auth/send-verification-code', {
        email: email.trim().toLowerCase(),
      });
      
      setEmailForCode(email.trim().toLowerCase());
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
      setErrorMsg(msg);
      message.error(msg);
    } finally {
      setLoading(false);
    }
  };

  // 发送手机验证码
  const handleSendPhoneCode = async (phone: string) => {
    setLoading(true);
    setErrorMsg('');
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
      setErrorMsg(msg);
      message.error(msg);
    } finally {
      setLoading(false);
    }
  };

  // 验证码登录（邮箱）
  const handleCodeLogin = async (email: string, code: string) => {
    setLoading(true);
    setErrorMsg('');
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
              }
      
      setErrorMsg('');
      if (res.data.is_new_user) {
        message.success(t('auth.newUserCreated') || '新用户已自动创建');
      }
      message.success(t('auth.loginWithCodeSuccess') || t('auth.loginSuccess'));
      
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
        navigate('/');
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
      setErrorMsg(msg);
    } finally {
      setLoading(false);
    }
  };

  // 手机号验证码登录
  const handlePhoneCodeLogin = async (phone: string, code: string) => {
    setLoading(true);
    setErrorMsg('');
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
              }
      
      setErrorMsg('');
      if (res.data.is_new_user) {
        message.success(t('auth.newUserCreated') || '新用户已自动创建');
      }
      message.success(t('auth.loginWithCodeSuccess') || t('auth.loginSuccess'));
      
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
        navigate('/');
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
      setErrorMsg(msg);
    } finally {
      setLoading(false);
    }
  };

  // 密码登录
  const onFinish = async (values: any) => {
    setLoading(true);
    try {
      const res = await api.post('/api/secure-auth/login', {
        email: values.email,
        password: values.password,
      });
      
      // 所有设备都使用HttpOnly Cookie认证，无需localStorage存储
      
      // 登录成功后获取CSRF token
      try {
        await api.get('/api/csrf/token');
      } catch (error) {
              }
      
      setErrorMsg(''); // 登录成功清空错误
      message.success(t('auth.loginSuccess'));
      
      // 登录成功后获取用户资料，更新语言偏好
      try {
        const userRes = await api.get('/api/users/profile/me');
        const userData = userRes.data;
        
        // 如果用户有语言偏好设置，且与当前语言不同，则更新语言
        if (userData.language_preference && userData.language_preference !== localStorage.getItem('language')) {
          localStorage.setItem('language', userData.language_preference);
          // 语言会在页面刷新后通过LanguageContext自动应用
        }
      } catch (error) {
        // 静默处理错误
      }
      
      // 添加短暂延迟确保认证信息设置完成
      setTimeout(() => {
        navigate('/');
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
      setErrorMsg(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Wrapper>
      <SEOHead 
        title="登录 - Link²Ur"
        description="登录Link²Ur，探索本地生活服务机会"
        noindex={true}
      />
      <HreflangManager type="page" path="/login" />
      {/* SEO优化：可见的H1标签 */}
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
        用户登录 - Link²Ur
      </h1>
      <div style={{ position: 'absolute', top: '20px', right: '20px' }}>
        <LanguageSwitcher />
      </div>
      <StyledCard title={t('auth.loginTitle')}>
        {errorMsg && <ErrorMsg>{errorMsg}</ErrorMsg>}
        
        {/* 登录方式切换 */}
        <div style={{ display: 'flex', gap: '8px', marginBottom: '16px' }}>
          <Button 
            type={loginMethod === 'password' ? 'primary' : 'default'}
            onClick={() => {
              setLoginMethod('password');
              setCodeSent(false);
              setVerificationCode('');
              setErrorMsg('');
            }}
            style={{ flex: 1 }}
          >
            {t('auth.passwordLogin')}
          </Button>
          <Button 
            type={loginMethod === 'code' ? 'primary' : 'default'}
            onClick={() => {
              setLoginMethod('code');
              setCodeSent(false);
              setVerificationCode('');
              setErrorMsg('');
            }}
            style={{ flex: 1 }}
          >
            {t('auth.loginWithCode')}
          </Button>
          <Button 
            type={loginMethod === 'phone' ? 'primary' : 'default'}
            onClick={() => {
              setLoginMethod('phone');
              setCodeSent(false);
              setVerificationCode('');
              setPhoneCountryCode('+44'); // 重置为英国
              setErrorMsg('');
            }}
            style={{ flex: 1 }}
          >
            {t('auth.phoneLogin')}
          </Button>
        </div>

        {loginMethod === 'password' ? (
          <Form layout="vertical" onFinish={onFinish}>
            <Form.Item label={t('common.email')} name="email" rules={[{ required: true, type: 'email' }]}> 
              <Input placeholder={t('common.email')} />
            </Form.Item>
            <Form.Item label={t('common.password')} name="password" rules={[{ required: true }]}> 
              <Input.Password placeholder={t('common.password')} />
            </Form.Item>
            <Form.Item>
              <Button type="primary" htmlType="submit" block loading={loading}>{t('common.login')}</Button>
            </Form.Item>
          </Form>
        ) : loginMethod === 'code' ? (
          <Form layout="vertical" onFinish={(values) => {
            if (!codeSent) {
              handleSendCode(values.email);
            } else {
              handleCodeLogin(emailForCode || values.email, verificationCode);
            }
          }}>
            <Form.Item label={t('common.email')} name="email" rules={[{ required: true, type: 'email' }]}> 
              <Input 
                placeholder={t('common.email')} 
                disabled={codeSent}
                onChange={(e) => !codeSent && setEmailForCode(e.target.value)}
              />
            </Form.Item>
            {codeSent && (
              <>
                <Form.Item label={t('auth.verificationCode')}>
                  <Input
                    placeholder={t('auth.enterVerificationCode')}
                    maxLength={6}
                    value={verificationCode}
                    onChange={(e) => {
                      const value = e.target.value.replace(/\D/g, ''); // 只允许数字
                      setVerificationCode(value);
                    }}
                    style={{ fontSize: '20px', letterSpacing: '8px', textAlign: 'center' }}
                  />
                </Form.Item>
                <div style={{ textAlign: 'center', marginBottom: '16px', color: '#666', fontSize: '12px' }}>
                  {t('auth.codeSentToEmail').replace('{email}', emailForCode)}
                  {countdown > 0 && (
                    <div style={{ marginTop: '4px' }}>
                      {t('auth.codeExpiresIn').replace('{seconds}', String(countdown))}
                    </div>
                  )}
                </div>
                <div style={{ textAlign: 'center', marginBottom: '16px' }}>
                  <Button 
                    type="link" 
                    onClick={() => handleSendCode(emailForCode)}
                    disabled={countdown > 0 || loading}
                  >
                    {countdown > 0 ? `${t('auth.resendCode')} (${Math.floor(countdown / 60)}:${String(countdown % 60).padStart(2, '0')})` : t('auth.resendCode')}
                  </Button>
                </div>
              </>
            )}
            <Form.Item>
              <Button 
                type="primary" 
                htmlType="submit" 
                block 
                loading={loading}
                disabled={codeSent && verificationCode.length !== 6}
              >
                {codeSent ? t('common.login') : t('auth.sendVerificationCode')}
              </Button>
            </Form.Item>
          </Form>
        ) : (
          <Form layout="vertical" onFinish={(values) => {
            if (!codeSent) {
              handleSendPhoneCode(values.phone);
            } else {
              handlePhoneCodeLogin(phoneForCode || values.phone, verificationCode);
            }
          }}>
            <Form.Item 
              label={t('common.phone')} 
              name="phone" 
              rules={[
                { required: true, message: t('auth.enterPhone') },
                { pattern: /^07\d{9}$/, message: '请输入11位英国手机号（以07开头）' }
              ]}
            > 
              <Input.Group compact>
                <div style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  padding: '0 12px',
                  border: '1px solid #d9d9d9',
                  borderRight: 'none',
                  borderRadius: '4px 0 0 4px',
                  backgroundColor: codeSent ? '#f5f5f5' : '#fff',
                  fontSize: '16px',
                  minWidth: '90px',
                  justifyContent: 'center',
                  color: '#666'
                }}>
                  🇬🇧 +44
                </div>
                <Input 
                  placeholder="7700123456"
                  disabled={codeSent}
                  onChange={(e) => {
                    const value = e.target.value.replace(/\D/g, ''); // 只允许数字
                    if (!codeSent) {
                      setPhoneForCode(phoneCountryCode + value);
                    }
                  }}
                  maxLength={11}
                  style={{
                    width: 'calc(100% - 90px)',
                    borderRadius: '0 4px 4px 0'
                  }}
                />
              </Input.Group>
            </Form.Item>
            {codeSent && (
              <>
                <Form.Item label={t('auth.verificationCode')}>
                  <Input
                    placeholder={t('auth.enterVerificationCode')}
                    maxLength={6}
                    value={verificationCode}
                    onChange={(e) => {
                      const value = e.target.value.replace(/\D/g, ''); // 只允许数字
                      setVerificationCode(value);
                    }}
                    style={{ fontSize: '20px', letterSpacing: '8px', textAlign: 'center' }}
                  />
                </Form.Item>
                <div style={{ textAlign: 'center', marginBottom: '16px', color: '#666', fontSize: '12px' }}>
                  {t('auth.codeSentToPhone').replace('{phone}', phoneForCode)}
                  {countdown > 0 && (
                    <div style={{ marginTop: '4px' }}>
                      {t('auth.codeExpiresIn').replace('{seconds}', String(countdown))}
                    </div>
                  )}
                </div>
                <div style={{ textAlign: 'center', marginBottom: '16px' }}>
                  <Button 
                    type="link" 
                    onClick={() => handleSendPhoneCode(phoneForCode)}
                    disabled={countdown > 0 || loading}
                  >
                    {countdown > 0 ? `${t('auth.resendCode')} (${Math.floor(countdown / 60)}:${String(countdown % 60).padStart(2, '0')})` : t('auth.resendCode')}
                  </Button>
                </div>
              </>
            )}
            <Form.Item>
              <Button 
                type="primary" 
                htmlType="submit" 
                block 
                loading={loading}
                disabled={codeSent && verificationCode.length !== 6}
              >
                {codeSent ? t('common.login') : t('auth.sendVerificationCode')}
              </Button>
            </Form.Item>
          </Form>
        )}
        
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
          {loginMethod === 'password' && (
            <Button type="link" onClick={() => setShowForgotPasswordModal(true)}>{t('auth.forgotPassword')}</Button>
          )}
          <Button type="link" onClick={() => setShowLoginModal(true)}>{t('common.register')}</Button>
        </div>
      </StyledCard>

      {/* 登录弹窗 */}
      <LoginModal
        isOpen={showLoginModal}
        onClose={() => setShowLoginModal(false)}
        onSuccess={() => {
          setShowLoginModal(false);
          window.location.reload();
        }}
        showForgotPassword={showForgotPasswordModal}
        onShowForgotPassword={() => setShowForgotPasswordModal(true)}
        onHideForgotPassword={() => setShowForgotPasswordModal(false)}
      />
    </Wrapper>
  );
};

export default Login; 