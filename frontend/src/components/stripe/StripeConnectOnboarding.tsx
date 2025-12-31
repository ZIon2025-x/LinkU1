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
  const [stripeLoaded, setStripeLoaded] = useState<boolean>(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [accountStatus, setAccountStatus] = useState<{
    account_id: string;
    account_status: boolean;
    charges_enabled: boolean;
  } | null>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const connectEmbeddedRef = useRef<any>(null);

  useEffect(() => {
    // 初始化 Stripe
    if (STRIPE_PUBLISHABLE_KEY) {
      loadStripe(STRIPE_PUBLISHABLE_KEY).then((stripeInstance) => {
        if (stripeInstance) {
          setStripeLoaded(true);
          console.log('Stripe loaded successfully');
        } else {
          console.error('Failed to load Stripe');
          setError('无法加载 Stripe');
        }
      }).catch((err) => {
        console.error('Error loading Stripe:', err);
        setError('无法加载 Stripe');
      });
    } else {
      console.error('STRIPE_PUBLISHABLE_KEY is not set');
      setError('Stripe 密钥未配置');
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
    if (!stripeLoaded || !clientSecret || !containerRef.current) {
      console.log('Waiting for dependencies:', { 
        stripeLoaded, 
        hasClientSecret: !!clientSecret, 
        hasContainer: !!containerRef.current 
      });
      return;
    }

    console.log('Initializing Stripe Connect Embedded...', { 
      clientSecret: clientSecret.substring(0, 20) + '...' 
    });

    // 清理之前的实例
    if (connectEmbeddedRef.current) {
      try {
        connectEmbeddedRef.current.unmount();
      } catch (e) {
        console.warn('Error unmounting previous instance:', e);
      }
      connectEmbeddedRef.current = null;
    }

    // 加载 Connect Embedded 脚本
    const loadConnectEmbedded = () => {
      // @ts-ignore
      if (window.Stripe && window.Stripe.ConnectEmbedded) {
        initializeConnectEmbedded();
      } else {
        // 动态加载 Connect Embedded 脚本
        const script = document.createElement('script');
        script.src = 'https://js.stripe.com/connect-embedded/v1/';
        script.async = true;
        script.onload = () => {
          console.log('Stripe Connect Embedded script loaded');
          setTimeout(() => {
            initializeConnectEmbedded();
          }, 100);
        };
        script.onerror = (err) => {
          console.error('Failed to load Stripe Connect Embedded script:', err);
          setError('无法加载 Stripe Connect 脚本');
          setLoading(false);
          if (onError) {
            onError('无法加载 Stripe Connect 脚本');
          }
        };

        // 检查是否已存在
        const existingScript = document.querySelector('script[src="https://js.stripe.com/connect-embedded/v1/"]');
        if (!existingScript) {
          document.head.appendChild(script);
        } else {
          // 脚本已存在，直接初始化
          setTimeout(() => {
            initializeConnectEmbedded();
          }, 100);
        }
      }
    };

    const initializeConnectEmbedded = () => {
      try {
        // @ts-ignore
        const StripeGlobal = window.Stripe;
        // @ts-ignore
        if (!StripeGlobal || !StripeGlobal.ConnectEmbedded) {
          console.error('Stripe.ConnectEmbedded not available', {
            // @ts-ignore
            hasStripe: !!window.Stripe,
            // @ts-ignore
            hasConnectEmbedded: !!(window.Stripe && window.Stripe.ConnectEmbedded)
          });
          setError('Stripe Connect Embedded 未加载，请刷新页面重试');
          setLoading(false);
          return;
        }

        console.log('Creating ConnectEmbedded instance...', {
          // @ts-ignore
          hasConnectEmbedded: !!StripeGlobal.ConnectEmbedded,
          clientSecret: clientSecret.substring(0, 30) + '...'
        });

        // @ts-ignore
        const connectEmbedded = new StripeGlobal.ConnectEmbedded({
          clientSecret: clientSecret,
          onReady: () => {
            console.log('Stripe Connect onboarding ready');
            setLoading(false);
          },
          onComplete: async () => {
            console.log('Stripe Connect onboarding completed');
            await checkAccountStatus();
          },
          onExit: (event: any) => {
            console.log('User exited onboarding', event);
          },
          onError: (event: any) => {
            console.error('Onboarding error:', event);
            const errorMsg = event.error?.message || '设置过程中发生错误';
            setError(errorMsg);
            setLoading(false);
            if (onError) {
              onError(errorMsg);
            }
          },
        });

        connectEmbeddedRef.current = connectEmbedded;

        console.log('Mounting ConnectEmbedded to container...', {
          container: !!containerRef.current,
          containerId: containerRef.current?.id
        });

        if (containerRef.current) {
          connectEmbedded.mount(containerRef.current);
        } else {
          console.error('Container ref is null');
          setError('容器元素未找到');
          setLoading(false);
        }
      } catch (err: any) {
        console.error('Error initializing Connect Embedded:', err);
        setError(err.message || '初始化失败');
        setLoading(false);
        if (onError) {
          onError(err.message || '初始化失败');
        }
      }
    };

    loadConnectEmbedded();

    // 清理函数
    return () => {
      if (connectEmbeddedRef.current) {
        try {
          connectEmbeddedRef.current.unmount();
        } catch (e) {
          console.warn('Error unmounting on cleanup:', e);
        }
        connectEmbeddedRef.current = null;
      }
    };
  }, [stripeLoaded, clientSecret]);

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
          width: '100%',
          background: '#f8f9fa',
          border: '1px solid #e9ecef',
          borderRadius: '8px',
          padding: '20px'
        }}
      >
        {!stripeLoaded && (
          <div style={{ textAlign: 'center', padding: '40px', color: '#666' }}>
            正在加载 Stripe...
          </div>
        )}
        {stripeLoaded && !clientSecret && (
          <div style={{ textAlign: 'center', padding: '40px', color: '#666' }}>
            正在获取 onboarding session...
          </div>
        )}
        {stripeLoaded && clientSecret && loading && (
          <div style={{ textAlign: 'center', padding: '40px', color: '#666' }}>
            正在初始化表单...
          </div>
        )}
      </div>
    </div>
  );
};

export default StripeConnectOnboarding;

