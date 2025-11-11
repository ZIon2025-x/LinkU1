import React from 'react';
import { useLanguage } from '../contexts/LanguageContext';

/**
 * 统一的错误提示组件
 * 显示刷新图标和错误提示信息
 */
const ErrorFallback: React.FC = () => {
  const { t } = useLanguage();
  
  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'center',
      alignItems: 'center',
      minHeight: '100vh',
      padding: '20px',
      textAlign: 'center',
      background: 'linear-gradient(135deg, #f3f4f6 0%, #e5e7eb 100%)'
    }}>
      <div style={{
        background: '#fff',
        padding: '40px',
        borderRadius: '20px',
        boxShadow: '0 20px 40px rgba(0,0,0,0.1)',
        maxWidth: '500px'
      }}>
        <div style={{
          fontSize: '48px',
          marginBottom: '20px',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center'
        }}>
          <span style={{
            fontSize: '48px',
            display: 'inline-block',
            animation: 'spin 2s linear infinite'
          }}>🔄</span>
        </div>
        <p style={{
          marginBottom: '0',
          color: '#6b7280',
          lineHeight: '1.6',
          fontSize: '16px'
        }}>
          {t('messages.errors.loadingProblem')}
        </p>
      </div>
      <style>{`
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
};

export default ErrorFallback;

