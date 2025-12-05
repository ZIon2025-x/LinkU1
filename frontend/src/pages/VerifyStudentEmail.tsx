import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { message } from 'antd';
import { verifyStudentEmail } from '../api';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';

const VerifyStudentEmail: React.FC = () => {
  const { token } = useParams<{ token: string }>();
  const { navigate } = useLocalizedNavigation();
  const { t } = useLanguage();
  const [loading, setLoading] = useState(true);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (token) {
      handleVerify();
    } else {
      setError(t('settings.invalidToken'));
      setLoading(false);
    }
  }, [token]);

  const handleVerify = async () => {
    if (!token) return;

    try {
      setLoading(true);
      const response = await verifyStudentEmail(token);
      if (response.code === 200) {
        setSuccess(true);
        message.success(t('settings.verificationSuccess'));
        // 3秒后跳转到学生认证页面
        setTimeout(() => {
          navigate('/student-verification');
        }, 3000);
      }
    } catch (error: any) {
      let errorMsg = t('settings.verificationFailed');
      if (error?.response?.data?.detail) {
        if (typeof error.response.data.detail === 'string') {
          errorMsg = error.response.data.detail;
        } else if (error.response.data.detail.message) {
          errorMsg = error.response.data.detail.message;
        } else if (error.response.data.detail.error) {
          errorMsg = error.response.data.detail.error;
        }
      }
      setError(errorMsg);
      message.error(errorMsg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      background: 'linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%)',
      padding: '20px'
    }}>
      <div style={{
        background: '#fff',
        borderRadius: '16px',
        padding: '40px',
        maxWidth: '500px',
        width: '100%',
        boxShadow: '0 8px 32px rgba(0,0,0,0.1)',
        textAlign: 'center'
      }}>
        {loading && (
          <>
            <div style={{
              fontSize: '48px',
              marginBottom: '20px'
            }}>
              ⏳
            </div>
            <h2 style={{
              color: '#333',
              marginBottom: '12px',
              fontSize: '24px'
            }}>
              {t('settings.verificationStatus')}
            </h2>
            <p style={{
              color: '#666',
              fontSize: '16px'
            }}>
              {t('common.loading')}
            </p>
          </>
        )}

        {success && (
          <>
            <div style={{
              fontSize: '64px',
              marginBottom: '20px'
            }}>
              ✅
            </div>
            <h2 style={{
              color: '#10b981',
              marginBottom: '12px',
              fontSize: '24px',
              fontWeight: 'bold'
            }}>
              {t('settings.verificationSuccess')}
            </h2>
            <p style={{
              color: '#666',
              fontSize: '16px',
              marginBottom: '24px'
            }}>
              {t('settings.verificationEmailSent')}
            </p>
            <p style={{
              color: '#999',
              fontSize: '14px'
            }}>
              {t('common.loading')}...
            </p>
            <button
              onClick={() => navigate('/student-verification')}
              style={{
                marginTop: '20px',
                background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                color: '#fff',
                border: 'none',
                padding: '12px 24px',
                borderRadius: '25px',
                cursor: 'pointer',
                fontSize: '16px',
                fontWeight: 'bold'
              }}
            >
              {t('settings.studentVerification')}
            </button>
          </>
        )}

        {error && (
          <>
            <div style={{
              fontSize: '64px',
              marginBottom: '20px'
            }}>
              ❌
            </div>
            <h2 style={{
              color: '#ef4444',
              marginBottom: '12px',
              fontSize: '24px',
              fontWeight: 'bold'
            }}>
              {t('settings.verificationFailed')}
            </h2>
            <p style={{
              color: '#666',
              fontSize: '16px',
              marginBottom: '24px'
            }}>
              {error}
            </p>
            <button
              onClick={() => navigate('/student-verification')}
              style={{
                background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                color: '#fff',
                border: 'none',
                padding: '12px 24px',
                borderRadius: '25px',
                cursor: 'pointer',
                fontSize: '16px',
                fontWeight: 'bold'
              }}
            >
              {t('settings.studentVerification')}
            </button>
          </>
        )}
      </div>
    </div>
  );
};

export default VerifyStudentEmail;

