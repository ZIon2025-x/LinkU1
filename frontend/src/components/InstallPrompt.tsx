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
    // 检测移动设备
    const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) || 
                     window.innerWidth <= 768;
    
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
      console.log('[PWA] 收到 beforeinstallprompt 事件');
      setDeferredPrompt(promptEvent);
      
      // 延迟显示提示，给用户一些时间浏览网站
      const delay = isMobile ? 5000 : 3000; // 移动端延迟更久
      setTimeout(() => {
        // 检查是否仍然可以显示（未安装）
        if (!window.matchMedia('(display-mode: standalone)').matches) {
          setIsVisible(true);
        }
      }, delay);
    };

    // 监听appinstalled事件（安装完成）
    const handleAppInstalled = () => {
      console.log('[PWA] 应用已安装');
      setIsInstalled(true);
      setIsVisible(false);
      setDeferredPrompt(null);
      localStorage.removeItem('pwa-install-dismissed');
    };

    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt);
    window.addEventListener('appinstalled', handleAppInstalled);

    // 对于移动端，即使没有beforeinstallprompt事件也显示提示
    let hasInteracted = false;
    let interactionTimer: NodeJS.Timeout | null = null;
    
    const handleInteraction = () => {
      if (hasInteracted) return;
      hasInteracted = true;
      
      // 移动端：用户交互后显示提示（即使没有beforeinstallprompt）
      if (isMobile) {
        const delay = isMobile ? 5000 : 3000;
        interactionTimer = setTimeout(() => {
          // 检查是否仍然可以显示（未安装且没有deferredPrompt）
          if (!window.matchMedia('(display-mode: standalone)').matches) {
            // 即使没有beforeinstallprompt事件，移动端也显示提示
            setIsVisible(true);
          }
        }, delay);
      }
    };

    // 移动端：监听用户交互
    if (isMobile) {
      window.addEventListener('scroll', handleInteraction, { once: true, passive: true });
      window.addEventListener('click', handleInteraction, { once: true });
      window.addEventListener('touchstart', handleInteraction, { once: true, passive: true });
    }

    // 移动端：如果没有收到beforeinstallprompt事件，延迟后也显示提示
    let fallbackTimer: NodeJS.Timeout | null = null;
    if (isMobile) {
      fallbackTimer = setTimeout(() => {
        // 使用函数形式检查状态
        setDeferredPrompt((currentPrompt) => {
          if (!currentPrompt && !window.matchMedia('(display-mode: standalone)').matches) {
            console.log('[PWA] 移动端：未收到beforeinstallprompt事件，显示手动安装提示');
            setIsVisible(true);
          }
          return currentPrompt;
        });
      }, 8000); // 8秒后如果还没有事件，显示提示
    }
    
    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt);
      window.removeEventListener('appinstalled', handleAppInstalled);
      if (isMobile) {
        window.removeEventListener('scroll', handleInteraction);
        window.removeEventListener('click', handleInteraction);
        window.removeEventListener('touchstart', handleInteraction);
        if (interactionTimer) clearTimeout(interactionTimer);
        if (fallbackTimer) clearTimeout(fallbackTimer);
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []); // 只在组件挂载时运行一次

  const handleInstall = async () => {
    // 检测设备和浏览器
    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent);
    const isAndroid = /Android/.test(navigator.userAgent);
    const isSafari = /Safari/.test(navigator.userAgent) && !/Chrome/.test(navigator.userAgent);
    const isChrome = /Chrome/.test(navigator.userAgent) && !/Edge/.test(navigator.userAgent);
    const isEdge = /Edge/.test(navigator.userAgent);
    const isFirefox = /Firefox/.test(navigator.userAgent);
    const isMobile = isIOS || isAndroid;
    
    // iOS Safari需要手动指导
    if (isIOS && isSafari) {
      alert(
        t('pwa.iosInstallInstructions') || 
        '要安装此应用，请点击浏览器底部的分享按钮（□↑图标），然后选择"添加到主屏幕"'
      );
      handleDismiss();
      return;
    }

    // 如果没有deferredPrompt，提供手动安装指导
    if (!deferredPrompt) {
      console.warn('[PWA] 没有可用的安装提示事件，提供手动安装指导');
      
      // 尝试检测是否已经安装
      if (window.matchMedia('(display-mode: standalone)').matches) {
        alert('应用已经安装！');
        handleDismiss();
        return;
      }
      
      // 根据设备和浏览器提供不同的指导
      let instructions = '';
      
      if (isMobile) {
        if (isAndroid && isChrome) {
          instructions = 'Android Chrome：\n1. 点击浏览器右上角菜单（三个点）\n2. 选择"安装应用"或"添加到主屏幕"';
        } else if (isAndroid && isFirefox) {
          instructions = 'Android Firefox：\n1. 点击浏览器右上角菜单（三个点）\n2. 选择"安装"或"添加到主屏幕"';
        } else if (isAndroid) {
          instructions = 'Android：\n1. 点击浏览器菜单\n2. 查找"安装"或"添加到主屏幕"选项';
        } else if (isIOS && isChrome) {
          instructions = 'iOS Chrome：\n1. 点击浏览器底部中间的分享按钮\n2. 选择"添加到主屏幕"';
        } else {
          instructions = '移动端：\n请通过浏览器菜单查找"安装"或"添加到主屏幕"选项';
        }
      } else {
        // 桌面端
        if (isChrome || isEdge) {
          instructions = '桌面端：\n请点击浏览器地址栏右侧的安装图标，或通过菜单选择"安装应用"';
        } else if (isFirefox) {
          instructions = '桌面端：\n请点击浏览器菜单，选择"安装"或"添加到主屏幕"';
        } else {
          instructions = '请通过浏览器菜单查找"安装"或"添加到主屏幕"选项';
        }
      }
      
      alert(instructions);
      handleDismiss();
      return;
    }

    try {
      // 显示安装提示
      console.log('[PWA] 显示安装提示...');
      await deferredPrompt.prompt();
      
      // 等待用户选择
      const { outcome } = await deferredPrompt.userChoice;
      
      console.log('[PWA] 用户选择:', outcome);
      
      if (outcome === 'accepted') {
        console.log('[PWA] 用户接受了安装提示');
        // 安装提示会由浏览器处理，appinstalled事件会触发并关闭提示
        // 但为了保险起见，也清除deferredPrompt
        setDeferredPrompt(null);
        // 不立即关闭提示，等待appinstalled事件
      } else {
        console.log('[PWA] 用户拒绝了安装提示');
        // 用户拒绝后，关闭提示
        setDeferredPrompt(null);
        handleDismiss();
      }
    } catch (error) {
      console.error('[PWA] 安装提示失败:', error);
      // 出错时也关闭提示
      handleDismiss();
      
      // 提供备用方案
      alert('安装提示无法显示。请尝试通过浏览器菜单手动安装应用。');
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

