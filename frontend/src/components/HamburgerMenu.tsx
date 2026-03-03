import React, { useState } from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';
import LazyImage from './LazyImage';

interface HamburgerMenuProps {
  user: any;
  onLogout: () => void;
  onLoginClick: () => void;
  systemSettings: any;
  unreadCount?: number; // 未读消息数量
}

const HamburgerMenu: React.FC<HamburgerMenuProps> = ({
  user,
  onLogout,
  onLoginClick,
  systemSettings: _systemSettings,
  unreadCount = 0
}) => {
  void _systemSettings;
  const [isOpen, setIsOpen] = useState(false);
  const { navigate } = useLocalizedNavigation();
  const { t } = useLanguage();
  

  const toggleMenu = () => {
    setIsOpen(!isOpen);
  };

  const handleNavigation = (path: string) => {
    navigate(path);
    setIsOpen(false);
  };

  return (
    <div className="hamburger-menu">
      <div className="menu-controls">
        {/* 汉堡菜单按钮 */}
        <button
          className={`hamburger-btn ${isOpen ? 'hidden' : ''}`}
          onClick={toggleMenu}
          style={{ position: 'relative' }}
        >
          <div className={`hamburger-line ${isOpen ? 'open' : ''}`} />
          <div className={`hamburger-line ${isOpen ? 'open' : ''}`} />
          <div className={`hamburger-line ${isOpen ? 'open' : ''}`} />
          {/* 未读消息红点指示器 */}
          {unreadCount > 0 && (
            <span 
              className="unread-dot hamburger-dot"
              style={{
                position: 'absolute',
                top: '2px',
                right: '2px',
                width: '12px',
                height: '12px',
                backgroundColor: '#ef4444',
                borderRadius: '50%',
                border: '2px solid #fff',
                animation: 'pulse 1.5s ease-in-out infinite',
                zIndex: 1001,
                boxShadow: '0 2px 4px rgba(0,0,0,0.2)'
              }}
              title={`${unreadCount} 条未读消息`}
            />
          )}
        </button>
      </div>

      {/* 展开的菜单 */}
      {isOpen && (
        <>
          {/* 背景遮罩 */}
          <div
            className="menu-overlay"
            onClick={() => setIsOpen(false)}
          />
          
          {/* 菜单内容 */}
          <div className="menu-content">
            {/* 顶部导航栏区域 */}
            <div className="menu-header">
              <div className="menu-logo">
                Link²Ur
              </div>
              <button
                className="menu-close-btn"
                onClick={() => setIsOpen(false)}
              >
                ✕
              </button>
            </div>

            {/* 可滚动内容区域 */}
            <div className="menu-scroll">
              {/* 导航链接 */}
              <div className="menu-nav">
                <button
                  className="menu-item"
                  onClick={() => handleNavigation('/tasks')}
                >
                  <span className="menu-icon">✨</span>
                  {t('hamburgerMenu.myTasks')}
                </button>

                <button
                  className="menu-item"
                  onClick={() => handleNavigation('/publish')}
                >
                  <span className="menu-icon">🚀</span>
                  {t('hamburgerMenu.publish')}
                </button>

                <button
                  className="menu-item"
                  onClick={() => handleNavigation('/task-experts')}
                >
                  <span className="menu-icon">👑</span>
                  {t('footer.taskExperts')}
                </button>

                <button
                  className="menu-item"
                  onClick={() => handleNavigation('/forum')}
                >
                  <span className="menu-icon">💬</span>
                  {t('hamburgerMenu.forum')}
                </button>

                <button
                  className="menu-item"
                  onClick={() => handleNavigation('/about')}
                >
                  <span className="menu-icon">ℹ️</span>
                  {t('hamburgerMenu.about')}
                </button>

                <button
                  className="menu-item"
                  onClick={() => handleNavigation('/milestones')}
                >
                  <span className="menu-icon">🏆</span>
                  {t('hamburgerMenu.milestones')}
                </button>
              </div>

              {/* 分割线 */}
              <div className="menu-divider" />

              {/* 用户相关功能 */}
              {user ? (
                <div className="menu-user-section">

                  {/* 用户头像和信息 */}
                  <div className="user-info">
                    <LazyImage
                      src={user.avatar || '/static/avatar1.png'}
                      alt={t('common.avatar')}
                      className="user-avatar"
                      width={40}
                      height={40}
                    />
                    <div className="user-details">
                      <div className="user-name">{user.name}</div>
                      <div className="user-email">{user.email}</div>
                    </div>
                  </div>

                  {/* 用户功能菜单 */}
                  <button
                    className="menu-item"
                    onClick={() => handleNavigation('/my-tasks')}
                  >
                    <span className="menu-icon">📋</span>
                    {t('hamburgerMenu.myPersonalTasks')}
                  </button>

                  <button
                    className="menu-item"
                    onClick={() => handleNavigation('/message')}
                    style={{ position: 'relative' }}
                  >
                    <span className="menu-icon">💬</span>
                    {t('hamburgerMenu.messages')}
                    {/* 未读消息红点指示器 */}
                    {unreadCount > 0 && (
                      <span 
                        className="unread-dot menu-dot"
                        style={{
                          position: 'absolute',
                          top: '50%',
                          right: '2rem',
                          transform: 'translateY(-50%)',
                          width: '12px',
                          height: '12px',
                          backgroundColor: '#ef4444',
                          borderRadius: '50%',
                          border: '2px solid #fff',
                          animation: 'pulse 1.5s ease-in-out infinite',
                          zIndex: 10,
                          boxShadow: '0 2px 4px rgba(0,0,0,0.2)'
                        }}
                        title={`${unreadCount} 条未读消息`}
                      />
                    )}
                  </button>

                  <button
                    className="menu-item"
                    onClick={() => handleNavigation('/profile')}
                  >
                    <span className="menu-icon">👤</span>
                    {t('hamburgerMenu.myProfile')}
                  </button>

                  <button
                    className="menu-item"
                    onClick={() => handleNavigation('/settings')}
                  >
                    <span className="menu-icon">⚙️</span>
                    {t('hamburgerMenu.mySettings')}
                  </button>

                  <button
                    className="menu-item"
                    onClick={() => handleNavigation('/student-verification')}
                  >
                    <span className="menu-icon">🎓</span>
                    {t('settings.studentVerification')}
                  </button>

                  <button
                    className="menu-item"
                    onClick={() => handleNavigation('/wallet')}
                  >
                    <span className="menu-icon">💰</span>
                    {t('hamburgerMenu.myWallet')}
                  </button>

                  {/* 登出按钮 */}
                  <button
                    className="menu-item logout-button"
                    onClick={() => {
                      onLogout();
                      setIsOpen(false);
                    }}
                  >
                    <span className="menu-icon">🚪</span>
                    {t('hamburgerMenu.logout')}
                  </button>
                </div>
              ) : (
                <div className="menu-auth-section">
                  <div className="auth-spacer"></div>
                  <button
                    className="menu-item login-button"
                    onClick={() => {
                      onLoginClick();
                      setIsOpen(false);
                    }}
                  >
                    <span className="menu-icon">🔑</span>
                    {t('hamburgerMenu.login')}/{t('hamburgerMenu.register')}
                  </button>
                </div>
              )}
            </div>
          </div>
        </>
      )}

      {/* 移动优先的CSS样式 */}
      <style>
        {`
          /* 重置和基础样式 */
          *, *::before, *::after {
            box-sizing: border-box;
          }

          /* 菜单控制区域 */
          .menu-controls {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-left: auto;
          }


          /* 汉堡菜单按钮 - 渐变流动效果 */
          .hamburger-btn {
            background: none;
            border: none;
            cursor: pointer;
            display: flex;
            flex-direction: column;
            justify-content: space-around;
            width: 24px;
            height: 18px;
            padding: 0;
            z-index: 1002;
            position: relative;
            overflow: visible;
            /* 确保在所有设备上保持统一大小 */
            min-width: 24px;
            min-height: 18px;
            max-width: 24px;
            max-height: 18px;
          }

          .hamburger-line {
            position: absolute;
            width: 100%;
            height: 2px;
            background: linear-gradient(90deg, #ff6b6b, #4ecdc4, #45b7d1);
            background-size: 200% 100%;
            border-radius: 2px;
            transition: all 0.4s ease;
            animation: gradient-shift 3s ease infinite;
          }

          @keyframes gradient-shift {
            0%, 100% { 
              background-position: 0% 50%; 
            }
            50% { 
              background-position: 100% 50%; 
            }
          }

          .hamburger-line:nth-child(1) {
            top: 0;
          }

          .hamburger-line:nth-child(2) {
            top: 50%;
            transform: translateY(-50%);
          }

          .hamburger-line:nth-child(3) {
            bottom: 0;
          }

          /* 激活状态 - 变成X，停止动画并变为红色渐变 */
          .hamburger-line.open {
            background: linear-gradient(90deg, #e74c3c, #c0392b);
            animation: none;
          }

          .hamburger-line.open:nth-child(1) {
            top: 50%;
            transform: translateY(-50%) rotate(45deg);
          }

          .hamburger-line.open:nth-child(2) {
            opacity: 0;
          }

          .hamburger-line.open:nth-child(3) {
            bottom: 50%;
            transform: translateY(50%) rotate(-45deg);
          }

          /* 菜单展开时隐藏汉堡按钮 */
          .hamburger-menu .hamburger-btn {
            transition: opacity 0.3s ease;
          }

          .hamburger-menu .hamburger-btn.hidden {
            opacity: 0;
            pointer-events: none;
          }

          /* 背景遮罩 */
          .menu-overlay {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.5);
            z-index: 999;
            animation: fadeIn 0.3s ease-out;
          }

          /* 菜单内容 - 移动优先 */
          .menu-content {
            position: fixed;
            right: 0;
            top: 0;
            bottom: 0;
            width: 100vw;
            max-width: 100vw;
            background: #fff;
            box-shadow: -4px 0 32px rgba(0,0,0,0.15);
            z-index: 1003; /* 高于汉堡按钮，覆盖它 */
            overflow: hidden;
            animation: slideInRight 0.3s ease-out;
            display: flex;
            flex-direction: column;
            /* 防止内容溢出导致水平滚动 */
            box-sizing: border-box;
          }

          /* 顶部导航栏 */
          .menu-header {
            height: 60px;
            background: #fff;
            border-bottom: 1px solid #e2e8f0;
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 1rem;
            position: sticky;
            top: 0;
            z-index: 10;
          }

          .menu-logo {
            font-weight: bold;
            font-size: 1.5rem;
            background: linear-gradient(135deg, #3b82f6, #8b5cf6);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
          }

          .menu-close-btn {
            background: none;
            border: none;
            cursor: pointer;
            padding: 0.5rem;
            border-radius: 4px;
            font-size: 1.5rem;
            color: #666;
            transition: background-color 0.2s ease;
            min-width: 44px;
            min-height: 44px;
            display: flex;
            align-items: center;
            justify-content: center;
          }

          .menu-close-btn:hover {
            background-color: #f5f5f5;
          }

          /* 可滚动内容区域 */
          .menu-scroll {
            flex: 1;
            overflow-y: auto;
            display: flex;
            flex-direction: column;
          }

          /* 导航区域 */
          .menu-nav {
            padding: 1.25rem 0;
          }

          /* 菜单项 */
          .menu-item {
            width: 100%;
            padding: 1.25rem 2rem;
            background: none;
            border: none;
            text-align: center;
            cursor: pointer;
            color: #A67C52;
            font-weight: 600;
            font-size: 1.125rem;
            transition: background-color 0.2s ease;
            display: flex;
            align-items: center;
            justify-content: center; /* 整体居中 */
            gap: 1rem; /* 固定距离 */
            min-height: 60px;
            position: relative;
            box-sizing: border-box;
            /* 防止内容溢出 */
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
          }

          .menu-item:hover {
            background-color: #f8f9fa;
          }

          .menu-icon {
            font-size: 1.5rem;
            flex-shrink: 0;
            width: 1.5rem; /* 固定宽度 */
            height: 1.5rem; /* 固定高度 */
            display: flex;
            align-items: center;
            justify-content: center;
          }

          /* 分割线 */
          .menu-divider {
            height: 1px;
            background-color: #e2e8f0;
            margin: 0 2rem;
          }

          /* 用户区域 */
          .menu-user-section {
            padding: 1.25rem 0;
          }

          /* 认证区域 */
          .menu-auth-section {
            display: flex;
            flex-direction: column;
            flex: 1;
            justify-content: flex-end;
            padding: 1.25rem 0;
          }

          .auth-spacer {
            flex: 1;
          }


          /* 用户信息 */
          .user-info {
            padding: 1.25rem 2rem;
            display: flex;
            align-items: center;
            justify-content: center; /* 水平居中 */
            gap: 1rem; /* 固定距离 */
            border-bottom: 1px solid #e2e8f0;
          }

          .user-avatar {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            border: 2px solid #8b5cf6;
            object-fit: cover;
            flex-shrink: 0;
          }

          .user-details {
            flex: 1;
            min-width: 0;
            text-align: center; /* 文字居中 */
          }

          .user-name {
            font-weight: 600;
            color: #2d3748;
            font-size: 0.875rem;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            text-align: center; /* 用户名居中 */
          }

          .user-email {
            color: #718096;
            font-size: 0.75rem;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            text-align: center; /* 邮箱居中 */
          }

          /* 特殊按钮样式 */

          .logout-button {
            color: #e53e3e;
            justify-content: center; /* 确保登出按钮内容居中 */
            gap: 1rem; /* 固定距离 */
          }

          .logout-button:hover {
            background-color: #fed7d7;
          }

          .login-button {
            background: linear-gradient(135deg, #3b82f6, #1d4ed8);
            color: #fff;
            margin: 1rem 2rem 2rem 2rem;
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
            width: calc(100% - 4rem);
            align-self: center;
            position: sticky;
            bottom: 0;
            z-index: 10;
            font-size: 1.125rem;
            font-weight: 700;
            padding: 1rem 2rem;
            min-height: 56px;
            justify-content: center; /* 确保登录按钮内容居中 */
            gap: 1rem; /* 固定距离 */
          }

          .login-button:hover {
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(59, 130, 246, 0.4);
          }

          /* 动画 */
          @keyframes slideInRight {
            from {
              opacity: 0;
              transform: translateX(100%);
            }
            to {
              opacity: 1;
              transform: translateX(0);
            }
          }
          
          @keyframes fadeIn {
            from {
              opacity: 0;
            }
            to {
              opacity: 1;
            }
          }
          
          /* 闪烁动画 */
          @keyframes pulse {
            0% {
              opacity: 1;
              transform: scale(1);
              box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.7);
            }
            50% {
              opacity: 0.7;
              transform: scale(1.1);
              box-shadow: 0 0 0 4px rgba(239, 68, 68, 0);
            }
            100% {
              opacity: 1;
              transform: scale(1);
              box-shadow: 0 0 0 0 rgba(239, 68, 68, 0);
            }
          }
          
          .unread-dot {
            animation: pulse 1.5s ease-in-out infinite;
          }

          /* 移动端确保使用标准大小（与首页一致） */
          @media (max-width: 767px) {
            .hamburger-btn {
              width: 24px !important;
              height: 18px !important;
              min-width: 24px !important;
              min-height: 18px !important;
              max-width: 24px !important;
              max-height: 18px !important;
            }
          }

          /* 平板和桌面端适配 */
          @media (min-width: 768px) {
            .menu-content {
              width: 400px;
              max-width: 400px;
            }
            
            .menu-item {
              padding: 1rem 1.5rem;
              font-size: 1rem;
            }
            
            .menu-icon {
              font-size: 1.25rem;
            }
            
            .user-info {
              padding: 1rem 1.5rem;
            }
            
            .login-button {
              margin: 0.75rem 1.5rem;
            }
          }

          /* 桌面端优化 */
          @media (min-width: 1024px) {
            .menu-content {
              width: 350px;
              max-width: 350px;
            }
          }

          /* 防止水平滚动 */
          body {
            overflow-x: hidden;
          }

          /* 确保根元素不产生水平滚动 */
          html, body {
            max-width: 100vw;
            overflow-x: hidden;
          }

          /* 确保菜单容器不超出视口 */
          .hamburger-menu {
            position: relative;
            max-width: 100vw;
            overflow: hidden;
          }

          /* 安全区域支持 */
          @supports (padding: max(0px)) {
            .menu-content {
              padding-bottom: max(0px, env(safe-area-inset-bottom));
            }
          }
        `}
      </style>
    </div>
  );
};

export default HamburgerMenu;