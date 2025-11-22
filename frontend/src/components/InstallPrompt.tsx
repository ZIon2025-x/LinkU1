import React, { useState, useEffect } from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import './InstallPrompt.css';

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
}

const InstallPrompt: React.FC = () => {
  const { t } = useLanguage();
  const [deferredPrompt, setDeferredPrompt] = useState<BeforeInstallPromptEvent | null>(null);
  const [isVisible, setIsVisible] = useState(false);
  const [isInstalled, setIsInstalled] = useState(false);

  useEffect(() => {
    // 检测是否已经安装
    const checkIfInstalled = () => {
      // 检查是否在standalone模式下运行（已安装）
      if (window.matchMedia('(display-mode: standalone)').matches) {
        setIsInstalled(true);
        return true;
      }
      
      // 检查是否在iOS上已添加到主屏幕
      if ((window.navigator as any).standalone === true) {
        setIsInstalled(true);
        return true;
      }
      
      return false;
    };

    if (checkIfInstalled()) {
      return;
    }

    // 检查用户是否已经关闭过提示
    const dismissedAt = localStorage.getItem('pwa-install-dismissed');
    if (dismissedAt) {
      const dismissedTime = parseInt(dismissedAt, 10);
      const daysSinceDismissed = (Date.now() - dismissedTime) / (1000 * 60 * 60 * 24);
      // 如果7天内关闭过，不再显示
      if (daysSinceDismissed < 7) {
        return;
      }
    }

    // 监听beforeinstallprompt事件（Chrome/Edge）
    const handleBeforeInstallPrompt = (e: Event) => {
      e.preventDefault();
      const promptEvent = e as BeforeInstallPromptEvent;
      setDeferredPrompt(promptEvent);
      
      // 延迟显示提示，给用户一些时间浏览网站
      setTimeout(() => {
        setIsVisible(true);
      }, 3000); // 3秒后显示
    };

    // 监听appinstalled事件（安装完成）
    const handleAppInstalled = () => {
      setIsInstalled(true);
      setIsVisible(false);
      setDeferredPrompt(null);
      localStorage.removeItem('pwa-install-dismissed');
    };

    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt);
    window.addEventListener('appinstalled', handleAppInstalled);

    // 对于iOS Safari，检测用户是否已经滚动或交互过
    let hasInteracted = false;
    const handleInteraction = () => {
      hasInteracted = true;
      // iOS Safari没有beforeinstallprompt事件，需要手动提示
      if (!isInstalled && !deferredPrompt && hasInteracted) {
        setTimeout(() => {
          // 检查是否是iOS设备
          const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
          const isSafari = /Safari/.test(navigator.userAgent) && !/Chrome/.test(navigator.userAgent);
          if (isIOS && isSafari) {
            setIsVisible(true);
          }
        }, 5000); // 5秒后显示iOS提示
      }
    };

    window.addEventListener('scroll', handleInteraction, { once: true });
    window.addEventListener('click', handleInteraction, { once: true });
    window.addEventListener('touchstart', handleInteraction, { once: true });

    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt);
      window.removeEventListener('appinstalled', handleAppInstalled);
      window.removeEventListener('scroll', handleInteraction);
      window.removeEventListener('click', handleInteraction);
      window.removeEventListener('touchstart', handleInteraction);
    };
  }, [deferredPrompt, isInstalled]);

  const handleInstall = async () => {
    if (!deferredPrompt) {
      // iOS Safari需要手动指导
      const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
      const isSafari = /Safari/.test(navigator.userAgent) && !/Chrome/.test(navigator.userAgent);
      
      if (isIOS && isSafari) {
        // 显示iOS安装指导
        alert(
          t('pwa.iosInstallInstructions') || 
          '要安装此应用，请点击浏览器底部的分享按钮，然后选择"添加到主屏幕"'
        );
      }
      handleDismiss();
      return;
    }

    try {
      // 显示安装提示
      await deferredPrompt.prompt();
      
      // 等待用户选择
      const { outcome } = await deferredPrompt.userChoice;
      
      if (outcome === 'accepted') {
        console.log('[PWA] 用户接受了安装提示');
      } else {
        console.log('[PWA] 用户拒绝了安装提示');
      }
      
      // 清除保存的提示事件
      setDeferredPrompt(null);
      setIsVisible(false);
    } catch (error) {
      console.error('[PWA] 安装提示失败:', error);
    }
  };

  const handleDismiss = () => {
    setIsVisible(false);
    // 记录关闭时间
    localStorage.setItem('pwa-install-dismissed', Date.now().toString());
  };

  // 如果已安装或不可见，不显示
  if (isInstalled || !isVisible) {
    return null;
  }

  return (
    <div className="install-prompt-overlay">
      <div className="install-prompt-container">
        <div className="install-prompt-content">
          <div className="install-prompt-icon">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M19 9H5C3.9 9 3 9.9 3 11V19C3 20.1 3.9 21 5 21H19C20.1 21 21 20.1 21 19V11C21 9.9 20.1 9 19 9Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
              <path d="M12 15V3M12 3L8 7M12 3L16 7" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </div>
          <div className="install-prompt-header">
            <h3>{t('pwa.installTitle') || '安装 Link²Ur'}</h3>
          </div>
          <div className="install-prompt-body">
            <p>
              {t('pwa.installDescription') || 
                '将 Link²Ur 添加到主屏幕，享受更快的访问速度和更好的体验！'}
            </p>
          </div>
          <div className="install-prompt-actions">
            <button 
              className="install-prompt-button install-prompt-button-secondary"
              onClick={handleDismiss}
            >
              {t('pwa.installLater') || '稍后'}
            </button>
            <button 
              className="install-prompt-button install-prompt-button-primary"
              onClick={handleInstall}
            >
              {t('pwa.installNow') || '立即安装'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default InstallPrompt;

