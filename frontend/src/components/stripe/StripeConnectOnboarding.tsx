import React, { useState, useEffect } from 'react';
import { useStripeConnect } from '../../hooks/useStripeConnect';
import {
  ConnectAccountOnboarding,
  ConnectComponentsProvider,
} from '@stripe/react-connect-js';
import { loadConnectAndInitialize } from '@stripe/connect-js';
import api from '../../api';
import StripeConnectAccountInfo from './StripeConnectAccountInfo';

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
  const [manualStripeConnectInstance, setManualStripeConnectInstance] = useState<any>(null);
  
  const stripeConnectInstance = useStripeConnect(connectedAccountId) || manualStripeConnectInstance;

  // 检查用户是否已有 Stripe Connect 账户
  useEffect(() => {
    const checkExistingAccount = async () => {
      try {
        const response = await api.get('/api/stripe/connect/account/status');
        const data = response.data;

        // 后端现在返回空状态而不是 404
        if (data && data.account_id) {
          setConnectedAccountId(data.account_id);
          setAccountStatus({
            account_id: data.account_id,
            account_status: data.details_submitted || false,
            charges_enabled: data.charges_enabled || false,
          });

          // 如果账户已完成设置，调用 onComplete
          if (data.charges_enabled && data.details_submitted) {
            if (onComplete) {
              onComplete();
            }
          }
        } else {
          // 没有账户，重置状态
          setConnectedAccountId(null);
          setAccountStatus(null);
        }
      } catch (err: any) {
        // 如果请求失败，可能是网络问题，但不影响流程
        if (err.response?.status !== 404) {
          console.error('Error checking account status:', err);
        }
        // 404 是正常的（没有账户），重置状态
        setConnectedAccountId(null);
        setAccountStatus(null);
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
    // 延迟检查账户状态，给 Stripe 一些时间更新
    setTimeout(() => {
      checkAccountStatus();
    }, 1000);
  };

  // 当有账户 ID 时，定期检查账户状态（用于检测 onboarding 完成）
  useEffect(() => {
    if (!connectedAccountId || accountStatus?.charges_enabled) {
      return; // 没有账户或已完成，不需要检查
    }

    // 每 3 秒检查一次账户状态
    const intervalId = setInterval(async () => {
      try {
        const response = await api.get('/api/stripe/connect/account/status');
        const data = response.data;

        // 如果有账户 ID，更新状态
        if (data && data.account_id) {
          setAccountStatus({
            account_id: data.account_id,
            account_status: data.details_submitted || false,
            charges_enabled: data.charges_enabled || false,
          });

          // 如果账户已完成设置，调用 onComplete
          if (data.charges_enabled && data.details_submitted) {
            if (onComplete) {
              onComplete();
            }
          }
        }
      } catch (err: any) {
        // 忽略错误，继续检查
        console.log('Periodic account status check:', err.response?.status || err.message);
      }
    }, 3000);

    return () => {
      clearInterval(intervalId);
    };
  }, [connectedAccountId, accountStatus?.charges_enabled, onComplete]);

  // 检查账户状态
  const checkAccountStatus = async () => {
    try {
      const response = await api.get('/api/stripe/connect/account/status');
      const data = response.data;

      // 如果有账户 ID，更新状态
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
      console.error('Error checking account status:', err);
      // 如果是 404，说明没有账户，这是正常的
      if (err.response?.status === 404) {
        console.log('No Stripe Connect account found');
      }
    }
  };

  // 如果账户已完成设置（有账户ID且已提交详细信息），显示账户详细信息
  if (accountStatus?.account_id && accountStatus?.account_status) {
    return (
      <div>
        <div style={{ 
          maxWidth: '800px', 
          margin: '0 auto 20px', 
          padding: '20px',
          background: '#fff',
          borderRadius: '12px',
          boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
          textAlign: 'center'
        }}>
          <div style={{ color: 'green', marginBottom: '10px', fontSize: '18px' }}>
            ✓ 收款账户已设置完成
          </div>
          <div style={{ fontSize: '14px', color: '#666', marginBottom: '10px' }}>
            您可以开始接收任务奖励了
          </div>
          {accountStatus.charges_enabled && (
            <div style={{ fontSize: '12px', color: '#28a745' }}>
              ✓ 收款功能已启用
            </div>
          )}
        </div>
        <StripeConnectAccountInfo accountId={accountStatus.account_id} />
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
          <div style={{ textAlign: 'center', marginTop: '20px' }}>
            <button
              onClick={async () => {
                // 手动创建 onboarding session 并使用嵌入式组件
                try {
                  setError(null);
                  const response = await api.post('/api/stripe/connect/account/onboarding-session');
                  const data = response.data;
                  
                  if (data.client_secret) {
                    // 使用 client_secret 直接创建 Stripe Connect instance
                    const publishableKey = process.env.REACT_APP_STRIPE_PUBLISHABLE_KEY || 
                      (process.env as any).STRIPE_PUBLISHABLE_KEY;
                    
                    if (!publishableKey) {
                      setError('Stripe Publishable Key 未配置');
                      return;
                    }
                    
                    const instance = loadConnectAndInitialize({
                      publishableKey,
                      fetchClientSecret: async () => {
                        // 直接返回已获取的 client_secret
                        return data.client_secret;
                      },
                      appearance: {
                        overlays: "dialog",
                        variables: {
                          colorPrimary: "#635BFF",
                        },
                      },
                    });
                    
                    setManualStripeConnectInstance(instance);
                  } else {
                    setError('无法获取 client_secret');
                  }
                } catch (err: any) {
                  console.error('Error creating onboarding session:', err);
                  setError(err.response?.data?.detail || err.message || '创建 onboarding session 失败');
                }
              }}
              style={{
                padding: '12px 24px',
                backgroundColor: '#635BFF',
                color: 'white',
                border: 'none',
                borderRadius: '8px',
                fontSize: '14px',
                fontWeight: '600',
                cursor: 'pointer',
                boxShadow: '0 2px 4px rgba(99, 91, 255, 0.3)',
                transition: 'all 0.3s ease'
              }}
              onMouseOver={(e) => {
                e.currentTarget.style.backgroundColor = '#4f46e5';
                e.currentTarget.style.transform = 'translateY(-2px)';
              }}
              onMouseOut={(e) => {
                e.currentTarget.style.backgroundColor = '#635BFF';
                e.currentTarget.style.transform = 'translateY(0)';
              }}
            >
              添加信息
            </button>
          </div>
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
