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
    requirements?: {
      currently_due?: string[];
      eventually_due?: string[];
      past_due?: string[];
      disabled_reason?: string;
    };
  } | null>(null);
  const [manualStripeConnectInstance, setManualStripeConnectInstance] = useState<any>(null);
  const [showRequirements, setShowRequirements] = useState(false);
  
  // 对于 onboarding，启用 account_onboarding 组件
  // 如果使用 Custom 账户且平台负责收集信息，可以禁用 Stripe 用户认证
  const stripeConnectInstance = useStripeConnect(
    connectedAccountId,
    false, // enablePayouts
    false, // enableAccountManagement
    true,  // enableAccountOnboarding - 启用 onboarding 组件
    false  // disableStripeUserAuthentication - 默认不禁用（如果需要可以改为 true）
  ) || manualStripeConnectInstance;

  // 注意：不再阻止 Stripe 外部页面跳转，因为这会影响 Stripe 嵌入式组件的正常功能
  // 包括服务条款接受、身份验证等关键流程
  // Stripe 嵌入式组件会在 iframe 中处理大部分流程，不会导致页面跳转

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
            account_status: data.details_submitted ?? false,
            charges_enabled: data.charges_enabled ?? false,
            requirements: data.requirements,
          });

          // 如果有未完成的需求，显示需求列表
          if (data.requirements && (
            data.requirements.currently_due?.length > 0 ||
            data.requirements.past_due?.length > 0
          )) {
            setShowRequirements(true);
          }

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
            account_status: data.details_submitted ?? false,
            charges_enabled: data.charges_enabled ?? false,
            requirements: data.requirements,
          });

          // 如果有未完成的需求，显示需求列表
          if (data.requirements && (
            data.requirements.currently_due?.length > 0 ||
            data.requirements.past_due?.length > 0
          )) {
            setShowRequirements(true);
          } else {
            setShowRequirements(false);
          }

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
          account_status: data.details_submitted ?? false,
          charges_enabled: data.charges_enabled ?? false,
          requirements: data.requirements,
        });

        // 如果有未完成的需求，显示需求列表
        if (data.requirements && (
          data.requirements.currently_due?.length > 0 ||
          data.requirements.past_due?.length > 0
        )) {
          setShowRequirements(true);
        }

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

  // 将 Stripe 需求代码转换为用户友好的描述
  const getRequirementDescription = (requirement: string): string => {
    const requirementMap: Record<string, string> = {
      // 服务条款
      'tos_acceptance.date': language === 'zh' ? '接受服务条款' : 'Accept Terms of Service',
      'tos_acceptance.ip': language === 'zh' ? '接受服务条款' : 'Accept Terms of Service',
      'tos_acceptance': language === 'zh' ? '接受服务条款' : 'Accept Terms of Service',
      // 个人信息
      'individual.first_name': language === 'zh' ? '名字' : 'First Name',
      'individual.last_name': language === 'zh' ? '姓氏' : 'Last Name',
      'individual.dob.day': language === 'zh' ? '出生日期' : 'Date of Birth',
      'individual.dob.month': language === 'zh' ? '出生日期' : 'Date of Birth',
      'individual.dob.year': language === 'zh' ? '出生日期' : 'Date of Birth',
      'individual.email': language === 'zh' ? '电子邮箱' : 'Email Address',
      'individual.phone': language === 'zh' ? '电话号码' : 'Phone Number',
      // 地址
      'individual.address.line1': language === 'zh' ? '地址' : 'Address',
      'individual.address.city': language === 'zh' ? '城市' : 'City',
      'individual.address.postal_code': language === 'zh' ? '邮政编码' : 'Postal Code',
      'individual.address.country': language === 'zh' ? '国家' : 'Country',
      // 身份验证
      'individual.id_number': language === 'zh' ? '身份证号码' : 'ID Number',
      'individual.verification.document': language === 'zh' ? '身份证明文件（护照/驾照/身份证）' : 'Identity Document (Passport/Driver License/ID Card)',
      'individual.verification.additional_document': language === 'zh' ? '额外身份证明文件' : 'Additional Identity Document',
      // 银行账户
      'external_account': language === 'zh' ? '银行账户信息' : 'Bank Account Information',
      'bank_account': language === 'zh' ? '银行账户信息' : 'Bank Account Information',
      // 业务信息
      'business_profile.url': language === 'zh' ? '业务网址' : 'Business URL',
      'business_profile.mcc': language === 'zh' ? '业务类型' : 'Business Type',
      'business_profile.product_description': language === 'zh' ? '业务描述' : 'Business Description',
    };

    // 检查是否有匹配的描述
    for (const [key, value] of Object.entries(requirementMap)) {
      if (requirement.includes(key)) {
        return value;
      }
    }

    // 默认返回原始需求名称（格式化后）
    return requirement.replace(/_/g, ' ').replace(/\./g, ' > ');
  };

  // 获取去重后的需求列表
  const getUniqueRequirements = (requirements: string[]): string[] => {
    const seen = new Set<string>();
    const result: string[] = [];
    
    for (const req of requirements) {
      const desc = getRequirementDescription(req);
      if (!seen.has(desc)) {
        seen.add(desc);
        result.push(desc);
      }
    }
    
    return result;
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
          
          {/* 设置步骤说明 */}
          <div style={{ 
            marginBottom: '24px', 
            padding: '16px', 
            backgroundColor: '#f0f7ff', 
            borderRadius: '8px',
            border: '1px solid #d0e3f7'
          }}>
            <h3 style={{ fontSize: '15px', fontWeight: '600', color: '#1a56db', marginBottom: '12px' }}>
              {language === 'zh' ? '设置收款账户需要以下信息：' : 'To set up your payment account, you will need:'}
            </h3>
            <ul style={{ margin: 0, paddingLeft: '20px', color: '#4b5563', fontSize: '14px', lineHeight: '1.8' }}>
              <li>{language === 'zh' ? '个人信息（姓名、出生日期、地址）' : 'Personal information (name, date of birth, address)'}</li>
              <li>{language === 'zh' ? '身份证明文件（护照、驾照或身份证）' : 'Identity document (passport, driver license, or ID card)'}</li>
              <li>{language === 'zh' ? '银行账户信息（用于接收付款）' : 'Bank account information (for receiving payments)'}</li>
              <li>{language === 'zh' ? '同意 Stripe 服务条款' : 'Agreement to Stripe Terms of Service'}</li>
            </ul>
          </div>
        </>
      )}
      
      {/* 显示未完成的需求 */}
      {showRequirements && accountStatus?.requirements && (
        <div style={{ 
          marginBottom: '20px', 
          padding: '16px', 
          backgroundColor: '#fff8e6', 
          borderRadius: '8px',
          border: '1px solid #ffd666'
        }}>
          <h3 style={{ fontSize: '15px', fontWeight: '600', color: '#d48806', marginBottom: '12px', display: 'flex', alignItems: 'center' }}>
            <span style={{ marginRight: '8px' }}>⚠️</span>
            {language === 'zh' ? '需要完成以下步骤：' : 'Please complete the following:'}
          </h3>
          
          {/* 过期的需求（紧急） */}
          {accountStatus.requirements.past_due && accountStatus.requirements.past_due.length > 0 && (
            <div style={{ marginBottom: '12px' }}>
              <p style={{ fontSize: '13px', color: '#cf1322', fontWeight: '600', marginBottom: '6px' }}>
                {language === 'zh' ? '已过期（需立即处理）：' : 'Overdue (requires immediate action):'}
              </p>
              <ul style={{ margin: 0, paddingLeft: '20px', color: '#cf1322', fontSize: '13px' }}>
                {getUniqueRequirements(accountStatus.requirements.past_due).map((req, idx) => (
                  <li key={idx}>{req}</li>
                ))}
              </ul>
            </div>
          )}
          
          {/* 当前需要的 */}
          {accountStatus.requirements.currently_due && accountStatus.requirements.currently_due.length > 0 && (
            <div>
              <p style={{ fontSize: '13px', color: '#d48806', fontWeight: '600', marginBottom: '6px' }}>
                {language === 'zh' ? '当前需要：' : 'Currently needed:'}
              </p>
              <ul style={{ margin: 0, paddingLeft: '20px', color: '#614700', fontSize: '13px' }}>
                {getUniqueRequirements(accountStatus.requirements.currently_due).map((req, idx) => (
                  <li key={idx}>{req}</li>
                ))}
              </ul>
            </div>
          )}
          
          {/* 禁用原因 */}
          {accountStatus.requirements.disabled_reason && (
            <p style={{ marginTop: '12px', fontSize: '13px', color: '#cf1322', fontStyle: 'italic' }}>
              {language === 'zh' ? '账户状态：' : 'Account status: '}{accountStatus.requirements.disabled_reason}
            </p>
          )}
        </div>
      )}
      
      {connectedAccountId && !stripeConnectInstance && (
        <>
          <h2 style={{ marginBottom: '10px', color: '#333' }}>{t('wallet.stripe.addInfoToReceive')}</h2>
          <p style={{ marginBottom: '20px', color: '#666', fontSize: '14px' }}>
            {language === 'zh' 
              ? '您的收款账户需要补充一些信息才能完成设置。请点击下方按钮继续。' 
              : 'Your payment account needs additional information to complete setup. Please click the button below to continue.'}
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
            overflow: 'visible'  // 改为 visible 以确保 Stripe 组件能正常显示弹窗
          }}
          // 注意：不要阻止 Stripe 组件内部的链接点击，否则会影响服务条款接受等功能
        >
          <ConnectComponentsProvider connectInstance={stripeConnectInstance}>
            <ConnectAccountOnboarding
              onExit={handleOnboardingExit}
              onStepChange={(stepChange: { step?: string }) => {
                // 监听步骤变化，用于分析和调试
                logger.log('Onboarding step changed:', stepChange.step);
              }}
              // 收集「最终需要」的验证项（含身份证明文件），避免入驻完成后 Stripe 再要求补传
              collectionOptions={{
                fields: 'eventually_due',
                futureRequirements: 'include',
              }}
              // 服务条款配置：确保收集服务条款接受
              // skipTermsOfServiceCollection 默认为 false，Stripe 会自动显示服务条款接受界面
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
