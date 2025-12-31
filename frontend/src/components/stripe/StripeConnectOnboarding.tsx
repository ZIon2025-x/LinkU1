import React, { useState, useEffect } from 'react';
import { useStripeConnect } from '../../hooks/useStripeConnect';
import {
  ConnectAccountOnboarding,
  ConnectComponentsProvider,
} from '@stripe/react-connect-js';
import api from '../../api';

// 从环境变量获取 Stripe Publishable Key
const STRIPE_PUBLISHABLE_KEY = process.env.REACT_APP_STRIPE_PUBLISHABLE_KEY || 
  (process.env as any).STRIPE_PUBLISHABLE_KEY || 
  '';

interface StripeConnectOnboardingProps {
  onComplete?: () => void;
  onError?: (error: string) => void;
}

/**
 * Stripe Connect Onboarding 组件
 * 参考 stripe-sample-code/src/Home.jsx
 */
const StripeConnectOnboarding: React.FC<StripeConnectOnboardingProps> = ({
  onComplete,
  onError,
}) => {
  const [accountCreatePending, setAccountCreatePending] = useState(false);
  const [onboardingExited, setOnboardingExited] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [connectedAccountId, setConnectedAccountId] = useState<string | null>(null);
  const [accountStatus, setAccountStatus] = useState<{
    account_id: string;
    account_status: boolean;
    charges_enabled: boolean;
  } | null>(null);
  
  const stripeConnectInstance = useStripeConnect(connectedAccountId);

  // 检查用户是否已有 Stripe Connect 账户
  useEffect(() => {
    const checkExistingAccount = async () => {
      try {
        const response = await api.get('/api/stripe/connect/account/status');
        const data = response.data;

        // 后端现在返回空状态而不是 404
        if (data.account_id) {
          setConnectedAccountId(data.account_id);
          setAccountStatus({
            account_id: data.account_id,
            account_status: data.details_submitted,
            charges_enabled: data.charges_enabled,
          });

          // 如果账户已完成设置，调用 onComplete
          if (data.charges_enabled && data.details_submitted) {
            if (onComplete) {
              onComplete();
            }
          }
        }
      } catch (err: any) {
        // 如果请求失败，可能是网络问题，但不影响流程
        if (err.response?.status !== 404) {
          console.error('Error checking account status:', err);
        }
      }
    };

    checkExistingAccount();
  }, [onComplete]);

  // 创建 Stripe Connect 账户
  const createAccount = async () => {
    setAccountCreatePending(true);
    setError(null);
    
    try {
      // 参考 stripe-sample-code/server.js 的 /account 端点
      // 我们的后端返回 account_id 而不是 account
      const response = await api.post('/api/stripe/connect/account/create-embedded');
      const data = response.data;

      if (data.account) {
        // 示例代码格式
        setConnectedAccountId(data.account);
      } else if (data.account_id) {
        // 我们的后端格式
        const accountId = data.account_id;
        setConnectedAccountId(accountId);
        if (data.account_status !== undefined) {
          setAccountStatus({
            account_id: accountId,
            account_status: data.account_status,
            charges_enabled: data.charges_enabled || false,
          });
        }
        
        // 如果账户已经完成设置，不需要继续 onboarding
        if (data.charges_enabled && data.account_status) {
          if (onComplete) {
            onComplete();
          }
        }
        // 注意：如果返回了 client_secret，useStripeConnect hook 会使用它
        // 否则，hook 会调用 account_session 端点获取
      } else if (data.error) {
        setError(data.error);
        if (onError) {
          onError(data.error);
        }
      } else {
        throw new Error('No account ID in response');
      }
    } catch (err: any) {
      console.error('Error creating account:', err);
      const errorMessage = err.response?.data?.detail || err.message || '创建账户失败';
      setError(errorMessage);
      if (onError) {
        onError(errorMessage);
      }
    } finally {
      setAccountCreatePending(false);
    }
  };

  // 处理 onboarding 退出
  const handleOnboardingExit = () => {
    setOnboardingExited(true);
    // 检查账户状态
    checkAccountStatus();
  };

  // 检查账户状态
  const checkAccountStatus = async () => {
    try {
      const response = await api.get('/api/stripe/connect/account/status');
      const data = response.data;

      if (data.charges_enabled && data.details_submitted) {
        setAccountStatus({
          account_id: data.account_id,
          account_status: data.details_submitted,
          charges_enabled: data.charges_enabled,
        });
        
        if (onComplete) {
          onComplete();
        }
      }
    } catch (err: any) {
      console.error('Error checking account status:', err);
    }
  };

  // 如果账户已完成设置
  if (accountStatus?.charges_enabled) {
    return (
      <div style={{ 
        maxWidth: '800px', 
        margin: '0 auto', 
        padding: '20px',
        background: '#fff',
        borderRadius: '12px',
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
        textAlign: 'center'
      }}>
        <div style={{ color: 'green', marginBottom: '10px', fontSize: '18px' }}>
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
      {!connectedAccountId && (
        <>
          <h2 style={{ marginBottom: '10px', color: '#333' }}>准备开始收款</h2>
          <p style={{ marginBottom: '20px', color: '#666', fontSize: '14px' }}>
            设置您的 Stripe 收款账户以接收任务奖励。所有信息将安全地存储在 Stripe 中。
          </p>
        </>
      )}
      
      {connectedAccountId && !stripeConnectInstance && (
        <>
          <h2 style={{ marginBottom: '10px', color: '#333' }}>添加信息以开始收款</h2>
          <p style={{ marginBottom: '20px', color: '#666', fontSize: '14px' }}>
            正在初始化...
          </p>
        </>
      )}

      {!accountCreatePending && !connectedAccountId && (
        <div style={{ textAlign: 'center', marginTop: '30px' }}>
          <button
            onClick={createAccount}
            style={{
              padding: '15px 40px',
              backgroundColor: '#635BFF',
              color: 'white',
              border: 'none',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: '600',
              cursor: 'pointer',
              boxShadow: '0 2px 4px rgba(99, 91, 255, 0.3)',
              transition: 'all 0.3s ease'
            }}
            onMouseOver={(e) => {
              e.currentTarget.style.backgroundColor = '#4f46e5';
              e.currentTarget.style.transform = 'translateY(-2px)';
              e.currentTarget.style.boxShadow = '0 4px 8px rgba(99, 91, 255, 0.4)';
            }}
            onMouseOut={(e) => {
              e.currentTarget.style.backgroundColor = '#635BFF';
              e.currentTarget.style.transform = 'translateY(0)';
              e.currentTarget.style.boxShadow = '0 2px 4px rgba(99, 91, 255, 0.3)';
            }}
          >
            注册
          </button>
        </div>
      )}

      {accountCreatePending && (
        <div style={{ textAlign: 'center', padding: '20px' }}>
          <div>正在创建账户...</div>
        </div>
      )}

      {stripeConnectInstance && (
        <ConnectComponentsProvider connectInstance={stripeConnectInstance}>
          <ConnectAccountOnboarding
            onExit={handleOnboardingExit}
          />
        </ConnectComponentsProvider>
      )}

      {error && (
        <div style={{ 
          marginTop: '20px', 
          padding: '15px', 
          backgroundColor: '#fee', 
          borderRadius: '8px',
          color: '#E61947',
          fontSize: '14px'
        }}>
          错误: {error}
        </div>
      )}

      {(connectedAccountId || accountCreatePending || onboardingExited) && (
        <div style={{ 
          marginTop: '20px', 
          padding: '15px', 
          backgroundColor: '#f8f9fa', 
          borderRadius: '8px',
          fontSize: '13px',
          color: '#666'
        }}>
          {connectedAccountId && (
            <p>
              您的连接账户 ID: <code style={{ fontWeight: '700', fontSize: '14px' }}>{connectedAccountId}</code>
            </p>
          )}
          {accountCreatePending && <p>正在创建连接账户...</p>}
          {onboardingExited && <p>账户入驻组件已退出</p>}
        </div>
      )}
    </div>
  );
};

export default StripeConnectOnboarding;
