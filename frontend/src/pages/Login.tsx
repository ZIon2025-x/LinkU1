import React, { useState, useEffect } from 'react';
import { Form, Input, Button, Card, message } from 'antd';
import styled from 'styled-components';
import axios from 'axios';
import { useNavigate } from 'react-router-dom';
import api from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import LanguageSwitcher from '../components/LanguageSwitcher';
import LoginModal from '../components/LoginModal';

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
  const { t } = useLanguage();
  const [errorMsg, setErrorMsg] = useState('');
  const [loading, setLoading] = useState(false);
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);

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
        console.log(t('auth.notLoggedIn'));
      });
  }, [navigate]);

  const onFinish = async (values: any) => {
    setLoading(true);
    try {
      const res = await api.post('/api/secure-auth/login', {
        email: values.email,
        password: values.password,
      });
      
      // 所有设备都使用HttpOnly Cookie认证，无需localStorage存储
      console.log('使用HttpOnly Cookie认证，无需localStorage存储');
      
      // 登录成功后获取CSRF token
      try {
        await api.get('/api/csrf/token');
        console.log('登录成功后获取CSRF token');
      } catch (error) {
        console.warn('获取CSRF token失败:', error);
      }
      
      setErrorMsg(''); // 登录成功清空错误
      message.success(t('auth.loginSuccess'));
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
      <div style={{ position: 'absolute', top: '20px', right: '20px' }}>
        <LanguageSwitcher />
      </div>
      <StyledCard title={t('auth.loginTitle')}>
        {errorMsg && <ErrorMsg>{errorMsg}</ErrorMsg>}
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
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
          <Button type="link" onClick={() => setShowForgotPasswordModal(true)}>{t('auth.forgotPassword')}</Button>
          <Button type="link" onClick={() => setShowLoginModal(true)}>{t('common.register')}</Button>
        </div>
        <div style={{ textAlign: 'center', marginTop: 8 }}>
          <Button type="link" onClick={() => setShowLoginModal(true)}>
            重发验证邮件
          </Button>
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