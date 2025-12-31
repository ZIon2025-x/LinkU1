import React, { useEffect, useState, useRef } from 'react';
import api from '../../api';

// 从环境变量获取 Stripe Publishable Key
// 注意：React 应用需要 REACT_APP_ 前缀
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
    console.log('Component mounted, STRIPE_PUBLISHABLE_KEY:', STRIPE_PUBLISHABLE_KEY ? 'Set' : 'Not set');
    
    // 检查全局 Stripe 是否已加载（HTML 中已预加载）
    const checkStripeLoaded = () => {
      // @ts-ignore
      if (window.Stripe) {
        console.log('Global Stripe found, setting stripeLoaded to true');
        setStripeLoaded(true);
        return true;
      }
      return false;
    };

    // 如果 Stripe 还没加载，等待它加载
    if (!checkStripeLoaded()) {
      console.log('Waiting for global Stripe to load...');
      let attempts = 0;
      const maxAttempts = 50; // 最多等待5秒
      const checkInterval = setInterval(() => {
        attempts++;
        if (checkStripeLoaded()) {
          clearInterval(checkInterval);
        } else if (attempts >= maxAttempts) {
          clearInterval(checkInterval);
          console.error('Global Stripe failed to load after timeout');
          setError('Stripe 加载失败，请刷新页面重试');
          setLoading(false);
        }
      }, 100);
    }

    // 获取或创建 onboarding session
    loadOnboardingSession();
  }, []);

  const loadOnboardingSession = async () => {
    try {
      console.log('Loading onboarding session...');
      setLoading(true);
      setError(null);

      const response = await api.post('/api/stripe/connect/account/create-embedded');
      console.log('Onboarding session response:', { 
        status: response.status,
        hasData: !!response.data,
        data: response.data 
      });
      
      const data = response.data;

      if (data.client_secret) {
        console.log('Client secret received:', data.client_secret.substring(0, 20) + '...');
        setClientSecret(data.client_secret);
        setAccountStatus({
          account_id: data.account_id,
          account_status: data.account_status,
          charges_enabled: data.charges_enabled,
        });
      } else if (data.account_status && data.charges_enabled) {
        // 账户已完成设置
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
        console.error('No client_secret and account not set up:', data);
        setError('无法创建 onboarding session: ' + (data.message || '未知错误'));
        if (onError) {
          onError('无法创建 onboarding session');
        }
      }
    } catch (err: any) {
      console.error('Error loading onboarding session:', err);
      const errorMessage = err.response?.data?.detail || err.message || '加载失败';
      console.error('Error message:', errorMessage);
      setError(errorMessage);
      if (onError) {
        onError(errorMessage);
      }
    } finally {
      setLoading(false);
      console.log('loadOnboardingSession finished, loading set to false');
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

    // 检查并等待 Connect Embedded 脚本加载
    const loadConnectEmbedded = () => {
      // 首先检查全局对象
      // @ts-ignore
      if (window.Stripe && window.Stripe.ConnectEmbedded) {
        console.log('ConnectEmbedded already available on global Stripe');
        initializeConnectEmbedded();
        return;
      }
      
      // 尝试通过 Stripe 实例访问（Connect Embedded 可能附加在实例上）
      if (STRIPE_PUBLISHABLE_KEY) {
        try {
          // @ts-ignore
          const testInstance = window.Stripe(STRIPE_PUBLISHABLE_KEY);
          // @ts-ignore
          if (testInstance && testInstance.ConnectEmbedded) {
            console.log('ConnectEmbedded found on Stripe instance');
            // @ts-ignore
            window.Stripe.ConnectEmbedded = testInstance.ConnectEmbedded;
            initializeConnectEmbedded();
            return;
          }
        } catch (e) {
          console.log('Could not create test Stripe instance:', e);
        }
      }

      console.log('Waiting for Connect Embedded script to load...');
      // 检查脚本是否在 HTML 中
      const existingScript = document.querySelector('script[src*="connect-embedded"]');
      console.log('Existing Connect Embedded script in HTML:', !!existingScript);
      
      // 脚本已在 HTML 中预加载，等待它加载完成
      let attempts = 0;
      const maxAttempts = 150; // 最多等待15秒（因为脚本可能加载较慢）
      
      const checkInterval = setInterval(() => {
        attempts++;
        // @ts-ignore
        const hasStripe = !!window.Stripe;
        // @ts-ignore
        const hasConnectEmbedded = !!(window.Stripe && window.Stripe.ConnectEmbedded);
        
        if (attempts % 10 === 0) {
          console.log(`Checking ConnectEmbedded (attempt ${attempts}/${maxAttempts}):`, {
            hasStripe,
            hasConnectEmbedded,
            // @ts-ignore
            stripeKeys: window.Stripe ? Object.keys(window.Stripe) : []
          });
        }
        
        if (hasConnectEmbedded) {
          clearInterval(checkInterval);
          console.log('ConnectEmbedded is now available!');
          initializeConnectEmbedded();
        } else if (attempts >= maxAttempts) {
          clearInterval(checkInterval);
          console.error('ConnectEmbedded failed to load after timeout');
          // @ts-ignore
          console.error('window.Stripe:', window.Stripe);
          // @ts-ignore
          console.error('window.Stripe.ConnectEmbedded:', window.Stripe?.ConnectEmbedded);
          // @ts-ignore
          console.error('window.Stripe keys:', window.Stripe ? Object.keys(window.Stripe) : 'Stripe not found');
          
          // 检查脚本是否真的加载了
          const scripts = Array.from(document.querySelectorAll('script[src*="connect-embedded"]')) as HTMLScriptElement[];
          console.error('Connect Embedded scripts found:', scripts.length);
          scripts.forEach((s, i) => {
            // 使用类型断言访问 complete 属性（HTMLScriptElement 的标准属性）
            const scriptComplete = (s as any).complete;
            console.error(`Script ${i}:`, s.src, 'loaded:', s.getAttribute('data-loaded'), 'complete:', scriptComplete);
          });
          
          // 检查脚本的加载状态
          const connectScript = scripts[0];
          const scriptComplete = connectScript ? (connectScript as any).complete : false;
          
          // 如果脚本还在加载，等待 onload 事件
          if (connectScript && !scriptComplete) {
            console.log('Script is still loading, waiting for onload event...');
            // 如果脚本还在加载，再等待一下
            const existingOnload = connectScript.onload;
            connectScript.onload = (e) => {
              console.log('Connect Embedded script onload fired');
              if (existingOnload) existingOnload.call(connectScript, e);
              // 等待脚本初始化
              setTimeout(() => {
                // @ts-ignore
                if (window.Stripe && window.Stripe.ConnectEmbedded) {
                  console.log('ConnectEmbedded available after script onload');
                  initializeConnectEmbedded();
                } else {
                  console.error('ConnectEmbedded still not available after script onload');
                  // 尝试重新检查
                  checkConnectEmbeddedAfterDelay();
                }
              }, 1000);
            };
            return; // 继续等待
          }
          
          // 如果脚本已加载但 ConnectEmbedded 仍不可用，可能是初始化问题
          // 尝试强制重新加载脚本
          console.log('Script appears loaded but ConnectEmbedded not available, attempting to reload...');
          
          // 移除现有脚本
          if (connectScript && connectScript.parentNode) {
            connectScript.parentNode.removeChild(connectScript);
          }
          
          // 重新加载脚本，确保顺序正确
          const reloadScript = () => {
            // 确保 Stripe.js 已加载
            // @ts-ignore
            if (!window.Stripe) {
              console.error('Stripe.js not loaded, cannot load Connect Embedded');
              setError('Stripe.js 未加载，请刷新页面重试');
              setLoading(false);
              return;
            }
            
            console.log('Reloading Connect Embedded script...');
            const script = document.createElement('script');
            script.src = 'https://js.stripe.com/connect-embedded/v1/';
            script.async = false; // 同步加载以确保顺序
            
            script.onload = () => {
              console.log('Reloaded script onload fired');
              // 等待更长时间，因为脚本可能需要初始化
              setTimeout(() => {
                // @ts-ignore
                if (window.Stripe && window.Stripe.ConnectEmbedded) {
                  console.log('ConnectEmbedded available after reload');
                  initializeConnectEmbedded();
                } else {
                  console.error('ConnectEmbedded still not available after reload');
                  // @ts-ignore
                  console.error('window.Stripe:', window.Stripe);
                  // @ts-ignore
                  console.error('window.Stripe keys:', window.Stripe ? Object.keys(window.Stripe) : 'Stripe not found');
                  
                  // 最后尝试：检查是否需要使用不同的方式
                  // @ts-ignore
                  if (window.Stripe && typeof window.Stripe === 'function') {
                    console.log('Trying to access ConnectEmbedded via Stripe instance...');
                    // @ts-ignore
                    const stripeInstance = window.Stripe(STRIPE_PUBLISHABLE_KEY);
                    // @ts-ignore
                    if (stripeInstance && stripeInstance.ConnectEmbedded) {
                      console.log('Found ConnectEmbedded via Stripe instance');
                      // 更新全局对象以便后续使用
                      // @ts-ignore
                      window.Stripe.ConnectEmbedded = stripeInstance.ConnectEmbedded;
                      initializeConnectEmbedded();
                      return;
                    }
                  }
                  
                  setError('Stripe Connect Embedded 加载失败。请检查网络连接或刷新页面重试。如果问题持续，请联系技术支持。');
                  setLoading(false);
                }
              }, 2000);
            };
            
            script.onerror = (err) => {
              console.error('Reload script error:', err);
              setError('无法加载 Stripe Connect 脚本。请检查网络连接或刷新页面重试。');
              setLoading(false);
              if (onError) {
                onError('无法加载 Stripe Connect 脚本');
              }
            };
            
            document.head.appendChild(script);
          };
          
          // 延迟一点再重新加载，确保之前的脚本完全清理
          setTimeout(reloadScript, 100);
        }
      }, 100);
    };

    // 辅助函数：延迟检查 ConnectEmbedded
    const checkConnectEmbeddedAfterDelay = () => {
      let checkAttempts = 0;
      const maxCheckAttempts = 20; // 最多检查20次（2秒）
      const checkInterval = setInterval(() => {
        checkAttempts++;
        // @ts-ignore
        if (window.Stripe && window.Stripe.ConnectEmbedded) {
          clearInterval(checkInterval);
          console.log('ConnectEmbedded became available after delay');
          initializeConnectEmbedded();
        } else if (checkAttempts >= maxCheckAttempts) {
          clearInterval(checkInterval);
          console.error('ConnectEmbedded still not available after delay');
          setError('Stripe Connect Embedded 加载失败。请检查网络连接或刷新页面重试。');
          setLoading(false);
        }
      }, 100);
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

        // 使用 Stripe 函数初始化实例（需要 publishable key）
        if (!STRIPE_PUBLISHABLE_KEY) {
          console.error('STRIPE_PUBLISHABLE_KEY is not set');
          setError('Stripe 密钥未配置');
          setLoading(false);
          return;
        }

        console.log('Creating Stripe instance and ConnectEmbedded...', {
          // @ts-ignore
          hasConnectEmbedded: !!StripeGlobal.ConnectEmbedded,
          clientSecret: clientSecret.substring(0, 30) + '...',
          hasPublishableKey: !!STRIPE_PUBLISHABLE_KEY
        });

        // 初始化 Stripe 实例
        // @ts-ignore
        const stripeInstance = StripeGlobal(STRIPE_PUBLISHABLE_KEY);
        
        // 检查 ConnectEmbedded 是否在 Stripe 实例上
        // @ts-ignore
        const ConnectEmbeddedClass = stripeInstance.ConnectEmbedded || StripeGlobal.ConnectEmbedded;
        
        if (!ConnectEmbeddedClass) {
          console.error('ConnectEmbedded class not found', {
            // @ts-ignore
            hasStripeInstance: !!stripeInstance,
            // @ts-ignore
            hasStripeGlobalConnectEmbedded: !!StripeGlobal.ConnectEmbedded,
            // @ts-ignore
            stripeInstanceKeys: stripeInstance ? Object.keys(stripeInstance) : [],
            // @ts-ignore
            stripeGlobalKeys: Object.keys(StripeGlobal)
          });
          setError('Stripe Connect Embedded 未找到。请确保脚本已正确加载。');
          setLoading(false);
          return;
        }
        
        console.log('Creating ConnectEmbedded instance with class:', ConnectEmbeddedClass);
        
        // 创建 ConnectEmbedded 实例
        const connectEmbedded = new ConnectEmbeddedClass({
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

  if (loading && !stripeLoaded && !clientSecret) {
    return (
      <div style={{ padding: '20px', textAlign: 'center' }}>
        <div>加载中...</div>
        <div style={{ fontSize: '12px', color: '#999', marginTop: '10px' }}>
          正在初始化 Stripe 和获取 onboarding session...
        </div>
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

