/**
 * CAPTCHA 组件
 * 支持 Google reCAPTCHA v2（交互式）和 hCaptcha
 */

import { useEffect, useRef, useState, useImperativeHandle, forwardRef } from 'react';
import { logger } from '../utils/logger';

interface CaptchaProps {
  onVerify: (token: string) => void;
  onError?: (error: string) => void;
  onExpire?: () => void;
  siteKey?: string;
  type?: 'recaptcha' | 'hcaptcha';
  theme?: 'light' | 'dark';
  size?: 'normal' | 'compact';
}

export interface CaptchaRef {
  reset: () => void;
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

const Captcha = forwardRef<CaptchaRef, CaptchaProps>(({ 
  onVerify, 
  onError,
  onExpire,
  siteKey, 
  type = 'recaptcha',
  theme = 'light',
  size = 'normal'
}, ref) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const [widgetId, setWidgetId] = useState<number | string | null>(null);
  const isRenderedRef = useRef<boolean>(false);

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
      isRenderedRef.current = false;
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
    
    // 防止重复渲染
    if (isRenderedRef.current) return;

    try {
      window.grecaptcha.ready(() => {
        // 再次检查，防止在 ready 回调期间重复渲染
        if (isRenderedRef.current || !containerRef.current) return;
        
        isRenderedRef.current = true;
        const id = window.grecaptcha!.render(containerRef.current!, {
          sitekey: siteKey,
          callback: (token: string) => {
            onVerify(token);
          },
          'expired-callback': () => {
            if (onExpire) {
              onExpire();
            }
          },
          'error-callback': () => {
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
    
    // 防止重复渲染
    if (isRenderedRef.current) return;

    try {
      isRenderedRef.current = true;
      const id = window.hcaptcha.render(containerRef.current, {
        sitekey: siteKey,
        callback: (token: string) => {
          onVerify(token);
        },
        'error-callback': (error: string) => {
          if (onError) {
            onError(error || 'hCaptcha verification failed');
          }
        },
        'expired-callback': () => {
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
      try {
        window.hcaptcha.reset(widgetId as string);
        logger.log('hCaptcha 已重置');
      } catch (e) {
        console.error('重置 hCaptcha 失败:', e);
      }
    } else if (type === 'recaptcha' && widgetId && window.grecaptcha) {
      try {
        window.grecaptcha.reset(widgetId as number);
        logger.log('reCAPTCHA 已重置');
      } catch (e) {
        console.error('重置 reCAPTCHA 失败:', e);
      }
    }
  };

  // 暴露 reset 方法给父组件
  useImperativeHandle(ref, () => ({
    reset
  }));

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
});

Captcha.displayName = 'Captcha';

export default Captcha;

