import React, { useEffect, useState, useRef } from 'react';
import { loadStripe } from '@stripe/stripe-js';
import api from '../../api';

const STRIPE_PUBLISHABLE_KEY = process.env.REACT_APP_STRIPE_PUBLISHABLE_KEY || '';

interface StripeConnectOnboardingProps {
  onComplete?: () => void;
  onError?: (error: string) => void;
}

const StripeConnectOnboarding: React.FC<StripeConnectOnboardingProps> = ({
  onComplete,
  onError,
}) => {
  const [clientSecret, setClientSecret] = useState<string | null>(null);
  const [stripe, setStripe] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [accountStatus, setAccountStatus] = useState<{
    account_id: string;
    account_status: boolean;
    charges_enabled: boolean;
  } | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    // 初始化 Stripe
    if (STRIPE_PUBLISHABLE_KEY) {
      loadStripe(STRIPE_PUBLISHABLE_KEY).then((stripeInstance) => {
        if (stripeInstance) {
          setStripe(stripeInstance);
        }
      });
    }

    // 获取或创建 onboarding session
    loadOnboardingSession();
  }, []);

  const loadOnboardingSession = async () => {
    try {
      setLoading(true);
      setError(null);

      const response = await api.post('/api/stripe/connect/account/create-embedded');
      const data = response.data;

      if (data.client_secret) {
        setClientSecret(data.client_secret);
        setAccountStatus({
          account_id: data.account_id,
          account_status: data.account_status,
          charges_enabled: data.charges_enabled,
        });
      } else if (data.account_status && data.charges_enabled) {
        // 账户已完成设置
        setAccountStatus({
          account_id: data.account_id,
          account_status: data.account_status,
          charges_enabled: data.charges_enabled,
        });
        if (onComplete) {
          onComplete();
        }
      } else {
        setError('无法创建 onboarding session');
        if (onError) {
          onError('无法创建 onboarding session');
        }
      }
    } catch (err: any) {
      const errorMessage = err.response?.data?.detail || err.message || '加载失败';
      setError(errorMessage);
      if (onError) {
        onError(errorMessage);
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!stripe || !clientSecret || !containerRef.current) {
      return;
    }

    // 动态加载 Stripe Connect Embedded
    const script = document.createElement('script');
    script.src = 'https://js.stripe.com/connect-embedded/v1/';
    script.async = true;
    script.onload = () => {
      // @ts-ignore
      if (window.Stripe && window.Stripe.ConnectEmbedded) {
        try {
          // @ts-ignore
          const connectEmbedded = new window.Stripe.ConnectEmbedded({
            clientSecret: clientSecret,
            onReady: () => {
              console.log('Stripe Connect onboarding ready');
            },
            onComplete: async () => {
              console.log('Stripe Connect onboarding completed');
              // 验证账户状态
              await checkAccountStatus();
            },
            onExit: (event: any) => {
              console.log('User exited onboarding', event);
            },
            onError: (event: any) => {
              console.error('Onboarding error:', event);
              const errorMsg = event.error?.message || '设置过程中发生错误';
              setError(errorMsg);
              if (onError) {
                onError(errorMsg);
              }
            },
          });

          connectEmbedded.mount(containerRef.current!);
        } catch (err: any) {
          console.error('Error initializing Connect Embedded:', err);
          setError(err.message || '初始化失败');
          if (onError) {
            onError(err.message || '初始化失败');
          }
        }
      }
    };

    document.body.appendChild(script);

    return () => {
      if (script.parentNode) {
        script.parentNode.removeChild(script);
      }
    };
  }, [stripe, clientSecret]);

  const checkAccountStatus = async () => {
    try {
      const response = await api.get('/api/stripe/connect/account/status');
      const data = response.data;

      if (data.charges_enabled) {
        setAccountStatus({
          account_id: data.account_id,
          account_status: data.details_submitted,
          charges_enabled: data.charges_enabled,
        });
        if (onComplete) {
          onComplete();
        }
      } else {
        setError('账户设置中，请稍候...');
      }
    } catch (err: any) {
      console.error('Error checking account status:', err);
    }
  };

  if (loading) {
    return (
      <div style={{ padding: '20px', textAlign: 'center' }}>
        <div>加载中...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div style={{ padding: '20px' }}>
        <div style={{ color: 'red', marginBottom: '10px' }}>错误: {error}</div>
        <button
          onClick={loadOnboardingSession}
          style={{
            padding: '10px 20px',
            backgroundColor: '#007bff',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
          }}
        >
          重试
        </button>
      </div>
    );
  }

  if (accountStatus?.charges_enabled) {
    return (
      <div style={{ padding: '20px', textAlign: 'center' }}>
        <div style={{ color: 'green', marginBottom: '10px' }}>
          ✓ 收款账户已设置完成
        </div>
        <div style={{ fontSize: '14px', color: '#666' }}>
          您可以开始接收任务奖励了
        </div>
      </div>
    );
  }

  return (
    <div style={{ 
      maxWidth: '800px', 
      margin: '0 auto', 
      padding: '20px',
      background: '#fff',
      borderRadius: '12px',
      boxShadow: '0 2px 8px rgba(0,0,0,0.1)'
    }}>
      <h2 style={{ marginBottom: '10px', color: '#333' }}>设置收款账户</h2>
      <p style={{ marginBottom: '20px', color: '#666', fontSize: '14px' }}>
        请完成以下信息以接收任务奖励。所有信息将安全地存储在 Stripe 中。
      </p>
      <div 
        ref={containerRef} 
        id="stripe-connect-embedded"
        style={{
          minHeight: '600px',
          width: '100%'
        }}
      />
    </div>
  );
};

export default StripeConnectOnboarding;

