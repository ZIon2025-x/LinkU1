import React, { useState, useEffect } from 'react';
import { useStripeConnect } from '../../hooks/useStripeConnect';
import {
  ConnectAccountOnboarding,
  ConnectComponentsProvider,
} from '@stripe/react-connect-js';
import { loadConnectAndInitialize } from '@stripe/connect-js';
import api from '../../api';
import StripeConnectAccountInfo from './StripeConnectAccountInfo';
import { useLanguage } from '../../contexts/LanguageContext';
import { logger } from '../../utils/logger';

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
  const { t, language } = useLanguage();
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
  
  // 对于 onboarding，启用 account_onboarding 组件
  // 如果使用 Custom 账户且平台负责收集信息，可以禁用 Stripe 用户认证
  const stripeConnectInstance = useStripeConnect(
    connectedAccountId,
    false, // enablePayouts
    false, // enableAccountManagement
    true,  // enableAccountOnboarding - 启用 onboarding 组件
    false  // disableStripeUserAuthentication - 默认不禁用（如果需要可以改为 true）
  ) || manualStripeConnectInstance;

  // 防止页面跳转到 Stripe 外部页面
  useEffect(() => {
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      // 如果正在 onboarding 过程中，阻止跳转
      if (stripeConnectInstance || manualStripeConnectInstance) {
        // 不阻止，让用户正常完成流程
      }
    };

    // 监听所有链接点击，防止跳转到 Stripe 外部页面
    const handleLinkClick = (e: MouseEvent) => {
      const target = e.target as HTMLElement;
      const link = target.closest('a');
      if (link && link.href) {
        // 阻止所有指向 Stripe Connect 外部页面的链接
        if (link.href.includes('connect.stripe.com') || 
            link.href.includes('stripe.com/app/express')) {
          e.preventDefault();
          e.stopPropagation();
          logger.log('Blocked navigation to Stripe external page:', link.href);
          // 显示提示信息
          if (onError) {
            onError(t('wallet.stripe.useEmbeddedComponent'));
          }
          return false;
        }
      }
    };
    
    // 监听 window.location 变化，防止程序化跳转
    const originalLocation = window.location;
    const checkLocation = () => {
      if (window.location.href.includes('connect.stripe.com') || 
          window.location.href.includes('stripe.com/app/express')) {
        logger.log('Detected navigation to Stripe external page, blocking...');
        // 阻止跳转并返回
        window.history.back();
        if (onError) {
          onError(t('wallet.stripe.blockedExternalNavigation'));
        }
      }
    };
    
    // 定期检查 location 变化
    const locationCheckInterval = setInterval(checkLocation, 100);

    window.addEventListener('beforeunload', handleBeforeUnload);
    document.addEventListener('click', handleLinkClick, true);
    
    // 监听 popstate 事件，防止通过浏览器历史记录跳转
    const handlePopState = (e: PopStateEvent) => {
      if (window.location.href.includes('connect.stripe.com') || 
          window.location.href.includes('stripe.com/app/express')) {
        e.preventDefault();
        window.history.pushState(null, '', window.location.pathname);
        logger.log('Blocked popstate navigation to Stripe external page');
      }
    };
    window.addEventListener('popstate', handlePopState);

    return () => {
      window.removeEventListener('beforeunload', handleBeforeUnload);
      document.removeEventListener('click', handleLinkClick, true);
      window.removeEventListener('popstate', handlePopState);
      if (locationCheckInterval) {
        clearInterval(locationCheckInterval);
      }
    };
  }, [stripeConnectInstance, manualStripeConnectInstance]);

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
      const errorMessage = err.response?.data?.detail || err.message || t('wallet.stripe.failedToCreateAccount');
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
        logger.log('Periodic account status check:', err.response?.status || err.message);
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
        logger.log('No Stripe Connect account found');
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
            ✓ {t('wallet.stripe.paymentAccountSetupComplete')}
          </div>
          <div style={{ fontSize: '14px', color: '#666', marginBottom: '10px' }}>
            {t('wallet.stripe.canStartReceivingRewards')}
          </div>
          {accountStatus.charges_enabled && (
            <div style={{ fontSize: '12px', color: '#28a745' }}>
              ✓ {t('wallet.stripe.paymentEnabled')}
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
          <h2 style={{ marginBottom: '10px', color: '#333' }}>{t('wallet.stripe.readyToReceive')}</h2>
          <p style={{ marginBottom: '20px', color: '#666', fontSize: '14px' }}>
            {t('wallet.stripe.setupStripeAccount')}
          </p>
        </>
      )}
      
      {connectedAccountId && !stripeConnectInstance && (
        <>
          <h2 style={{ marginBottom: '10px', color: '#333' }}>{t('wallet.stripe.addInfoToReceive')}</h2>
          <p style={{ marginBottom: '20px', color: '#666', fontSize: '14px' }}>
            {t('wallet.stripe.initializing')}
          </p>
          <div style={{ textAlign: 'center', marginTop: '20px' }}>
            <button
              onClick={async () => {
                // 手动创建 onboarding session 并使用嵌入式组件
                try {
                  setError(null);
                  setAccountCreatePending(true);
                  
                  // 先尝试通过 account_session 端点获取 client_secret
                  let clientSecret: string | null = null;
                  try {
                    const sessionResponse = await api.post('/api/stripe/connect/account_session', {
                      account: connectedAccountId,
                    });
                    if (sessionResponse.data?.client_secret) {
                      clientSecret = sessionResponse.data.client_secret;
                    }
                  } catch (sessionErr: any) {
                    logger.log('Account session endpoint failed, trying onboarding-session:', sessionErr);
                  }
                  
                  // 如果 account_session 失败，尝试 onboarding-session
                  if (!clientSecret) {
                    const response = await api.post('/api/stripe/connect/account/onboarding-session');
                    const data = response.data;
                    if (data.client_secret) {
                      clientSecret = data.client_secret;
                    }
                  }
                  
                  if (clientSecret) {
                    // 使用 client_secret 直接创建 Stripe Connect instance
                    const publishableKey = process.env.REACT_APP_STRIPE_PUBLISHABLE_KEY || 
                      (process.env as any).STRIPE_PUBLISHABLE_KEY;
                    
                    if (!publishableKey) {
                      setError(t('wallet.stripe.stripePublishableKeyNotConfigured'));
                      setAccountCreatePending(false);
                      return;
                    }
                    
                    // 创建一个持久的 fetchClientSecret 函数
                    const clientSecretValue = clientSecret;
                    // 将应用语言映射到 Stripe 支持的语言代码
                    const stripeLocale = language === 'zh' ? 'zh-CN' : 'en';
                    const instance = loadConnectAndInitialize({
                      publishableKey,
                      fetchClientSecret: async () => {
                        // 每次都重新获取最新的 client_secret
                        try {
                          const refreshResponse = await api.post('/api/stripe/connect/account_session', {
                            account: connectedAccountId,
                          });
                          if (refreshResponse.data?.client_secret) {
                            return refreshResponse.data.client_secret;
                          }
                        } catch (err) {
                          console.warn('Failed to refresh client_secret, using cached value');
                        }
                        // 如果刷新失败，返回缓存的 client_secret
                        return clientSecretValue;
                      },
                      locale: stripeLocale, // 设置 Stripe Connect 组件的语言
                      appearance: {
                        overlays: "dialog",
                        variables: {
                          colorPrimary: "#635BFF",
                        },
                      },
                    });
                    
                    setManualStripeConnectInstance(instance);
                    setAccountCreatePending(false);
                  } else {
                    setError(t('wallet.stripe.failedToGetClientSecret'));
                    setAccountCreatePending(false);
                  }
                } catch (err: any) {
                  console.error('Error creating onboarding session:', err);
                  setError(err.response?.data?.detail || err.message || t('wallet.stripe.failedToCreateOnboardingSession'));
                  setAccountCreatePending(false);
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
              {t('wallet.stripe.addInfo')}
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
            {t('wallet.stripe.register')}
          </button>
        </div>
      )}

      {accountCreatePending && (
        <div style={{ textAlign: 'center', padding: '20px' }}>
          <div>{t('wallet.stripe.creatingAccount')}</div>
        </div>
      )}

      {stripeConnectInstance && (
        <div 
          style={{ 
            width: '100%',
            minHeight: '600px',
            position: 'relative',
            overflow: 'hidden'
          }}
          // 防止组件内部链接导致页面跳转
          onClick={(e) => {
            // 阻止所有链接的默认行为
            const target = e.target as HTMLElement;
            if (target.tagName === 'A' || target.closest('a')) {
              e.preventDefault();
              e.stopPropagation();
            }
          }}
        >
          <ConnectComponentsProvider connectInstance={stripeConnectInstance}>
            <ConnectAccountOnboarding
              onExit={handleOnboardingExit}
              onStepChange={(stepChange) => {
                // 监听步骤变化，用于分析和调试
                // stepChange.step 包含当前步骤名称，如 'business_type', 'external_account' 等
                logger.log('Onboarding step changed:', stepChange.step);
              }}
              // 根据官方文档，这些是可选的配置
              // collectionOptions 可以控制收集哪些要求
              // collectionOptions={{
              //   fields: 'currently_due', // 默认值，只收集当前需要的要求
              //   // fields: 'eventually_due', // 也可以收集未来需要的要求
              //   // futureRequirements: 'include', // 包含未来要求
              //   // requirements: {
              //   //   only: ['business_details.*'], // 只收集特定要求
              //   //   // exclude: ['tos_acceptance.*'], // 排除特定要求
              //   // }
              // }}
              // 自定义策略链接（可选）
              // fullTermsOfServiceUrl="https://your-domain.com/terms"
              // recipientTermsOfServiceUrl="https://your-domain.com/recipient-terms"
              // privacyPolicyUrl="https://your-domain.com/privacy"
            />
          </ConnectComponentsProvider>
        </div>
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
          {t('wallet.stripe.error')}: {error}
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
              {t('wallet.stripe.connectAccountId')}: <code style={{ fontWeight: '700', fontSize: '14px' }}>{connectedAccountId}</code>
            </p>
          )}
          {accountCreatePending && <p>{t('wallet.stripe.creatingConnectAccount')}</p>}
          {onboardingExited && <p>{t('wallet.stripe.onboardingExited')}</p>}
        </div>
      )}
    </div>
  );
};

export default StripeConnectOnboarding;
