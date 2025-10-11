import React, { useState } from 'react';
import { Form, Input, Button, Card, message, Alert } from 'antd';
import styled from 'styled-components';
import { useNavigate } from 'react-router-dom';
import api from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import LoginModal from '../components/LoginModal';

const Wrapper = styled.div`
  min-height: 80vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f9f9f9;
`;

const StyledCard = styled(Card)`
  width: 400px;
  box-shadow: 0 2px 8px #f0f1f2;
`;

const ResendVerification: React.FC = () => {
  const navigate = useNavigate();
  const { t } = useLanguage();
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [email, setEmail] = useState('');
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);

  const onFinish = async (values: any) => {
    setLoading(true);
    try {
      await api.post('/api/users/resend-verification', values.email, {
        headers: {
          'Content-Type': 'text/plain'
        }
      });
      setEmail(values.email);
      setSuccess(true);
      message.success(t('auth.emailSent'));
    } catch (err: any) {
      const errorMsg = err.response?.data?.detail || t('auth.resendVerification');
      message.error(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  if (success) {
    return (
      <Wrapper>
        <StyledCard>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: 48, color: '#52c41a', marginBottom: 16 }}>📧</div>
            <h2 style={{ color: '#52c41a', marginBottom: 16 }}>{t('auth.emailSent')}</h2>
            <p style={{ fontSize: 16, marginBottom: 24, color: '#666' }}>
              {t('auth.checkEmail')} <strong>{email}</strong>
            </p>
            <Alert
              message={t('auth.resendEmail')}
              description={t('auth.checkEmail')}
              type="info"
              showIcon
              style={{ marginBottom: 24, textAlign: 'left' }}
            />
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
              <Button onClick={() => setSuccess(false)}>
                {t('auth.resendEmail')}
              </Button>
              <Button type="primary" onClick={() => setShowLoginModal(true)}>
                {t('common.login')}
              </Button>
            </div>
          </div>
        </StyledCard>
      </Wrapper>
    );
  }

  return (
    <Wrapper>
      <StyledCard title={t('auth.resendVerification')}>
        <p style={{ marginBottom: 24, color: '#666' }}>
          {t('auth.checkEmail')}
        </p>
        <Form layout="vertical" onFinish={onFinish}>
          <Form.Item 
            label={t('common.email')} 
            name="email" 
            rules={[
              { required: true, message: t('auth.emailRequired') },
              { type: 'email', message: t('auth.emailInvalid') }
            ]}
          > 
            <Input placeholder={t('common.email')} />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" block loading={loading}>
              {t('auth.resendEmail')}
            </Button>
          </Form.Item>
        </Form>
        <div style={{ textAlign: 'center', marginTop: 16 }}>
          <Button type="link" onClick={() => setShowLoginModal(true)}>
            {t('common.login')}
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

export default ResendVerification;
