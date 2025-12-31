import React, { useEffect, useState } from 'react';
import { ConnectComponentsProvider, ConnectAccountOnboarding } from '@stripe/react-connect-js';
import { loadConnect } from '@stripe/connect-js';
import api from '../../api';

// 从环境变量获取 Stripe Publishable Key
const STRIPE_PUBLISHABLE_KEY = process.env.REACT_APP_STRIPE_PUBLISHABLE_KEY || 
  (process.env as any).STRIPE_PUBLISHABLE_KEY || 
  '';

interface StripeConnectOnboardingProps {
  onComplete?: () => void;
  onError?: (error: string) => void;
}

const StripeConnectOnboarding: React.FC<StripeConnectOnboardingProps> = ({
  onComplete,
  onError,
}) => {
  const [clientSecret, setClientSecret] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [accountStatus, setAccountStatus] = useState<{
    account_id: string;
    account_status: boolean;
    charges_enabled: boolean;
  } | null>(null);
  const [onboardingUrl, setOnboardingUrl] = useState<string | null>(null);
  const [useAccountLink, setUseAccountLink] = useState<boolean>(false);
  const [connectInstance, setConnectInstance] = useState<any>(null);

  // 初始化 ConnectJS
  useEffect(() => {
    if (!STRIPE_PUBLISHABLE_KEY) {
      console.error('STRIPE_PUBLISHABLE_KEY is not set');
      return;
    }

    const initConnect = async () => {
      try {
        // loadConnect 不接受参数，返回 ConnectJS 构造函数
        const ConnectJS = await loadConnect();
        // 使用 publishableKey 创建实例
        const connect = ConnectJS(STRIPE_PUBLISHABLE_KEY);
        setConnectInstance(connect);
        console.log('✅ ConnectJS initialized');
      } catch (err: any) {
        console.error('Error initializing ConnectJS:', err);
        // 如果初始化失败，切换到 AccountLink
        setError('ConnectJS 初始化失败，将使用跳转方式...');
        setTimeout(() => {
          loadOnboardingSession(true);
        }, 1000);
      }
    };

    initConnect();
  }, []);

  useEffect(() => {
    console.log('Component mounted, STRIPE_PUBLISHABLE_KEY:', STRIPE_PUBLISHABLE_KEY ? 'Set' : 'Not set');
    
    // 检查 URL 参数，看是否从 Stripe 页面返回
    const urlParams = new URLSearchParams(window.location.search);
    const fromStripe = urlParams.get('from_stripe') === 'true' || 
                       window.location.pathname.includes('/stripe/connect/success');
    
    if (fromStripe) {
      console.log('Returned from Stripe onboarding, checking account status...');
      checkAccountStatus().then(() => {
        window.history.replaceState({}, document.title, window.location.pathname);
      });
      return;
    }

    // 加载 onboarding session
    loadOnboardingSession();
  }, []);

  const loadOnboardingSession = async (useLink: boolean = false) => {
    try {
      console.log('Loading onboarding session...', { useLink });
      setLoading(true);
      setError(null);

      const endpoint = useLink 
        ? '/api/stripe/connect/account/create' 
        : '/api/stripe/connect/account/create-embedded';
      
      const response = await api.post(endpoint);
      console.log('Onboarding session response:', { 
        status: response.status,
        hasData: !!response.data,
        data: response.data 
      });
      
      const data = response.data;

      if (useLink && data.onboarding_url) {
        console.log('Onboarding URL received:', data.onboarding_url);
        setOnboardingUrl(data.onboarding_url);
        setUseAccountLink(true);
        setAccountStatus({
          account_id: data.account_id,
          account_status: data.account_status,
          charges_enabled: data.charges_enabled,
        });
        setLoading(false);
      } else if (data.client_secret) {
        console.log('Client secret received:', data.client_secret.substring(0, 20) + '...');
        setClientSecret(data.client_secret);
        setAccountStatus({
          account_id: data.account_id,
          account_status: data.account_status,
          charges_enabled: data.charges_enabled,
        });
        setLoading(false);
      } else if (data.account_status && data.charges_enabled) {
        console.log('Account already set up');
        setAccountStatus({
          account_id: data.account_id,
          account_status: data.account_status,
          charges_enabled: data.charges_enabled,
        });
        setLoading(false);
        if (onComplete) {
          onComplete();
        }
      } else {
        console.error('No client_secret/onboarding_url and account not set up:', data);
        setError('无法创建 onboarding session: ' + (data.message || '未知错误'));
        if (onError) {
          onError('无法创建 onboarding session');
        }
        setLoading(false);
      }
    } catch (err: any) {
      console.error('Error loading onboarding session:', err);
      const errorMessage = err.response?.data?.detail || err.message || '加载失败';
      console.error('Error message:', errorMessage);
      setError(errorMessage);
      if (onError) {
        onError(errorMessage);
      }
      setLoading(false);
    }
  };

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
        setLoading(false);
        if (onComplete) {
          onComplete();
        }
      } else {
        setError('账户设置中，请稍候...');
        setLoading(false);
      }
    } catch (err: any) {
      console.error('Error checking account status:', err);
      setLoading(false);
    }
  };

  // 当 clientSecret 更新时，更新 ConnectJS 实例
  useEffect(() => {
    if (!connectInstance || !clientSecret) return;

    try {
      // 更新 ConnectJS 实例的 clientSecret
      if (typeof connectInstance.update === 'function') {
        connectInstance.update({ clientSecret });
        console.log('✅ ConnectJS clientSecret updated');
      }
    } catch (err: any) {
      console.error('Error updating ConnectJS clientSecret:', err);
    }
  }, [connectInstance, clientSecret]);

  if (loading && !clientSecret && !onboardingUrl) {
    return (
      <div style={{ padding: '20px', textAlign: 'center' }}>
        <div>加载中...</div>
        <div style={{ fontSize: '12px', color: '#999', marginTop: '10px' }}>
          正在初始化 Stripe 和获取 onboarding session...
        </div>
      </div>
    );
  }

  if (error && !useAccountLink) {
    return (
      <div style={{ padding: '20px' }}>
        <div style={{ color: 'red', marginBottom: '10px' }}>错误: {error}</div>
        <button
          onClick={() => loadOnboardingSession(false)}
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
        <button
          onClick={() => loadOnboardingSession(true)}
          style={{
            padding: '10px 20px',
            backgroundColor: '#28a745',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
            marginLeft: '10px',
          }}
        >
          使用跳转方式
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

  // 如果使用 AccountLink 方式，显示跳转按钮
  if (useAccountLink && onboardingUrl) {
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
          请点击下方按钮跳转到 Stripe 页面完成账户设置。所有信息将安全地存储在 Stripe 中。
        </p>
        <div style={{ textAlign: 'center', marginTop: '30px' }}>
          <button
            onClick={() => {
              window.location.href = onboardingUrl;
            }}
            style={{
              padding: '15px 40px',
              backgroundColor: '#007bff',
              color: 'white',
              border: 'none',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: '600',
              cursor: 'pointer',
              boxShadow: '0 2px 4px rgba(0,123,255,0.3)',
              transition: 'all 0.3s ease'
            }}
            onMouseOver={(e) => {
              e.currentTarget.style.backgroundColor = '#0056b3';
              e.currentTarget.style.transform = 'translateY(-2px)';
              e.currentTarget.style.boxShadow = '0 4px 8px rgba(0,123,255,0.4)';
            }}
            onMouseOut={(e) => {
              e.currentTarget.style.backgroundColor = '#007bff';
              e.currentTarget.style.transform = 'translateY(0)';
              e.currentTarget.style.boxShadow = '0 2px 4px rgba(0,123,255,0.3)';
            }}
          >
            前往 Stripe 完成设置
          </button>
        </div>
        <div style={{ 
          marginTop: '20px', 
          padding: '15px', 
          backgroundColor: '#f8f9fa', 
          borderRadius: '8px',
          fontSize: '13px',
          color: '#666'
        }}>
          <strong>提示：</strong>完成设置后，您将被重定向回本页面。如果页面没有自动刷新，请手动刷新查看状态。
        </div>
      </div>
    );
  }

  // 使用官方 React 组件
  if (!clientSecret || !connectInstance) {
    return (
      <div style={{ padding: '20px', textAlign: 'center' }}>
        <div>正在初始化...</div>
        {!connectInstance && <div style={{ fontSize: '12px', color: '#999', marginTop: '10px' }}>正在加载 ConnectJS...</div>}
        {!clientSecret && connectInstance && <div style={{ fontSize: '12px', color: '#999', marginTop: '10px' }}>正在获取 onboarding session...</div>}
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
      
      <ConnectComponentsProvider connectInstance={connectInstance}>
        <ConnectAccountOnboarding
          onExit={() => {
            console.log('User exited onboarding');
          }}
          onStepChange={(stepChange) => {
            console.log('Step changed:', stepChange.step);
          }}
          onComplete={async () => {
            console.log('✅ Onboarding completed');
            await checkAccountStatus();
          }}
        />
      </ConnectComponentsProvider>
    </div>
  );
};

export default StripeConnectOnboarding;
