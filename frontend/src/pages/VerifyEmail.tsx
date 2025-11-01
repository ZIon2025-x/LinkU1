import React, { useEffect, useState } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import { Card, Spin, Alert, Button } from 'antd';
import styled from 'styled-components';
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
  width: 500px;
  text-align: center;
  box-shadow: 0 2px 8px #f0f1f2;
`;

const SuccessIcon = styled.div`
  font-size: 64px;
  color: #52c41a;
  margin-bottom: 16px;
`;

const ErrorIcon = styled.div`
  font-size: 64px;
  color: #ff4d4f;
  margin-bottom: 16px;
`;

const VerifyEmail: React.FC = () => {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const { t } = useLanguage();
  const [loading, setLoading] = useState(true);
  const [status, setStatus] = useState<'success' | 'error' | 'loading'>('loading');
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [showLoginModal, setShowLoginModal] = useState(false);
  const [showForgotPasswordModal, setShowForgotPasswordModal] = useState(false);

  useEffect(() => {
    const verifyEmail = async () => {
      const token = searchParams.get('token');
      const success = searchParams.get('success');
      const error = searchParams.get('error');
      
      // 如果已经有success参数，说明后端已经验证成功并重定向回来
      if (success === 'true' || success === '1') {
        console.log('邮箱验证成功，显示成功页面');
        setStatus('success');
        setMessage(t('auth.verificationSuccess') || '邮箱验证成功！您现在可以正常使用平台了。');
        setLoading(false);
        return;
      }
      
      // 如果有error参数，说明后端验证失败并重定向回来
      if (error) {
        console.log('邮箱验证失败:', error);
        setStatus('error');
        setError(decodeURIComponent(error));
        setLoading(false);
        return;
      }
      
      // 如果有token，调用API验证（兼容旧的方式）
      if (token) {
        try {
          const response = await api.get(`/api/users/verify-email?token=${token}`);
          setStatus('success');
          setMessage(response.data.message);
        } catch (err: any) {
          setStatus('error');
          setError(err.response?.data?.detail || t('auth.verificationFailed'));
        } finally {
          setLoading(false);
        }
      } else {
        // 没有token也没有其他参数，显示错误
        setStatus('error');
        setError(t('auth.verificationFailed') || '缺少验证令牌');
        setLoading(false);
      }
    };

    verifyEmail();
  }, [searchParams, t]);

  const handleGoToLogin = () => {
    setShowLoginModal(true);
  };

  const handleGoToRegister = () => {
    setShowLoginModal(true);
  };

  if (loading) {
    return (
      <Wrapper>
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
          邮箱验证 - Link²Ur
        </h1>
        <StyledCard>
          <Spin size="large" />
          <div style={{ marginTop: 16, fontSize: 16 }}>{t('common.loading')}</div>
        </StyledCard>
      </Wrapper>
    );
  }

  return (
    <Wrapper>
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
        邮箱验证 - Link²Ur
      </h1>
      <StyledCard>
        {status === 'success' ? (
          <>
            <SuccessIcon>✅</SuccessIcon>
            <h2 style={{ color: '#52c41a', marginBottom: 16 }}>{t('auth.verificationSuccess')}</h2>
            <p style={{ fontSize: 16, marginBottom: 24, color: '#666' }}>
              {message}
            </p>
            <Button type="primary" size="large" onClick={handleGoToLogin}>
              {t('common.login')}
            </Button>
          </>
        ) : (
          <>
            <ErrorIcon>❌</ErrorIcon>
            <h2 style={{ color: '#ff4d4f', marginBottom: 16 }}>{t('auth.verificationFailed')}</h2>
            <Alert
              message={error}
              type="error"
              showIcon
              style={{ marginBottom: 24, textAlign: 'left' }}
            />
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'center' }}>
              <Button onClick={handleGoToRegister}>
                {t('common.register')}
              </Button>
              <Button type="primary" onClick={handleGoToLogin}>
                {t('common.login')}
              </Button>
            </div>
          </>
        )}
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

export default VerifyEmail;
