/**
 * CAPTCHA 组件
 * 支持 Google reCAPTCHA v2（交互式）和 hCaptcha
 */

import React, { useEffect, useRef, useState } from 'react';

interface CaptchaProps {
  onVerify: (token: string) => void;
  onError?: (error: string) => void;
  onExpire?: () => void;
  siteKey?: string;
  type?: 'recaptcha' | 'hcaptcha';
  theme?: 'light' | 'dark';
  size?: 'normal' | 'compact';
}

declare global {
  interface Window {
    grecaptcha?: {
      ready: (callback: () => void) => void;
      render: (container: HTMLElement, options: {
        sitekey: string;
        callback: (token: string) => void;
        'expired-callback': () => void;
        'error-callback': () => void;
        theme?: 'light' | 'dark';
        size?: 'normal' | 'compact';
      }) => number;
      reset: (widgetId: number) => void;
      getResponse: (widgetId: number) => string;
    };
    hcaptcha?: {
      render: (container: HTMLElement, options: { 
        sitekey: string; 
        callback: (token: string) => void; 
        'error-callback': (error: string) => void;
        'expired-callback': () => void;
        theme?: 'light' | 'dark';
        size?: 'normal' | 'compact';
      }) => string;
      reset: (widgetId: string) => void;
      getResponse: (widgetId: string) => string;
    };
  }
}

const Captcha: React.FC<CaptchaProps> = ({ 
  onVerify, 
  onError,
  onExpire,
  siteKey, 
  type = 'recaptcha',
  theme = 'light',
  size = 'normal'
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const [widgetId, setWidgetId] = useState<number | string | null>(null);
  const [isLoaded, setIsLoaded] = useState(false);
  const [isVerified, setIsVerified] = useState(false);

  useEffect(() => {
    if (!siteKey) {
      // 如果没有 site key，跳过 CAPTCHA（开发环境）
      return;
    }

    if (type === 'recaptcha') {
      // 加载 Google reCAPTCHA v2（交互式）
      const scriptId = 'recaptcha-v2-script';
      if (document.getElementById(scriptId)) {
        // 脚本已加载
        if (window.grecaptcha && containerRef.current) {
          setIsLoaded(true);
          renderRecaptcha();
        }
        return;
      }

      const script = document.createElement('script');
      script.id = scriptId;
      script.src = 'https://www.google.com/recaptcha/api.js';
      script.async = true;
      script.defer = true;
      script.onload = () => {
        setIsLoaded(true);
        if (containerRef.current) {
          renderRecaptcha();
        }
      };
      script.onerror = () => {
        if (onError) {
          onError('Failed to load reCAPTCHA');
        }
      };
      document.head.appendChild(script);
    } else if (type === 'hcaptcha') {
      // 加载 hCaptcha
      const scriptId = 'hcaptcha-script';
      if (document.getElementById(scriptId)) {
        // 脚本已加载
        if (window.hcaptcha && containerRef.current) {
          setIsLoaded(true);
          renderHcaptcha();
        }
        return;
      }

      const script = document.createElement('script');
      script.id = scriptId;
      script.src = 'https://js.hcaptcha.com/1/api.js';
      script.async = true;
      script.defer = true;
      script.onload = () => {
        setIsLoaded(true);
        if (containerRef.current) {
          renderHcaptcha();
        }
      };
      script.onerror = () => {
        if (onError) {
          onError('Failed to load hCaptcha');
        }
      };
      document.head.appendChild(script);
    }

    return () => {
      // 清理
      if (type === 'hcaptcha' && widgetId && window.hcaptcha) {
        try {
          window.hcaptcha.reset(widgetId as string);
        } catch (e) {
          // 忽略错误
        }
      } else if (type === 'recaptcha' && widgetId && window.grecaptcha) {
        try {
          window.grecaptcha.reset(widgetId as number);
        } catch (e) {
          // 忽略错误
        }
      }
    };
  }, [siteKey, type, theme, size]);

  const renderRecaptcha = () => {
    if (!window.grecaptcha || !containerRef.current || !siteKey) return;

    try {
      window.grecaptcha.ready(() => {
        const id = window.grecaptcha!.render(containerRef.current!, {
          sitekey: siteKey,
          callback: (token: string) => {
            setIsVerified(true);
            onVerify(token);
          },
          'expired-callback': () => {
            setIsVerified(false);
            if (onExpire) {
              onExpire();
            }
          },
          'error-callback': () => {
            setIsVerified(false);
            if (onError) {
              onError('reCAPTCHA verification failed');
            }
          },
          theme: theme,
          size: size
        });
        setWidgetId(id);
      });
    } catch (error: any) {
      if (onError) {
        onError(error.message || 'Failed to render reCAPTCHA');
      }
    }
  };

  const renderHcaptcha = () => {
    if (!window.hcaptcha || !containerRef.current || !siteKey) return;

    try {
      const id = window.hcaptcha.render(containerRef.current, {
        sitekey: siteKey,
        callback: (token: string) => {
          setIsVerified(true);
          onVerify(token);
        },
        'error-callback': (error: string) => {
          setIsVerified(false);
          if (onError) {
            onError(error || 'hCaptcha verification failed');
          }
        },
        'expired-callback': () => {
          setIsVerified(false);
          if (onExpire) {
            onExpire();
          }
        },
        theme: theme,
        size: size
      });
      setWidgetId(id);
    } catch (error: any) {
      if (onError) {
        onError(error.message || 'Failed to render hCaptcha');
      }
    }
  };

  const reset = () => {
    if (type === 'hcaptcha' && widgetId && window.hcaptcha) {
      window.hcaptcha.reset(widgetId as string);
      setIsVerified(false);
    } else if (type === 'recaptcha' && widgetId && window.grecaptcha) {
      window.grecaptcha.reset(widgetId as number);
      setIsVerified(false);
    }
  };

  // reset 方法用于内部重置验证状态
  // 如果需要暴露给父组件，应该使用 forwardRef 和 useImperativeHandle
  // 目前不需要暴露，因为父组件通过 onVerify/onError/onExpire 回调处理状态

  return (
    <div 
      ref={containerRef} 
      style={{ 
        marginBottom: '16px',
        display: 'flex',
        justifyContent: 'center',
        minHeight: type === 'recaptcha' ? '78px' : '65px'
      }}
    />
  );
};

export default Captcha;

