import React, { useState, ReactNode } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { adminLogout } from '../api';
import { message } from 'antd';
import styles from './AdminLayout.module.css';

export interface MenuItem {
  key: string;
  label: string;
  icon?: string;
  path: string;
  children?: MenuItem[];
}

export interface AdminLayoutProps {
  children: ReactNode;
  menuItems?: MenuItem[];
}

const defaultMenuItems: MenuItem[] = [
  {
    key: 'dashboard',
    label: '仪表盘',
    icon: '📊',
    path: '/admin',
  },
  {
    key: 'users',
    label: '用户管理',
    icon: '👥',
    path: '/admin/users',
  },
  {
    key: 'experts',
    label: '专家管理',
    icon: '⭐',
    path: '/admin/experts',
  },
  {
    key: 'coupons',
    label: '优惠券管理',
    icon: '🎟️',
    path: '/admin/coupons',
  },
  {
    key: 'disputes',
    label: '纠纷管理',
    icon: '⚖️',
    path: '/admin/disputes',
  },
  {
    key: 'refunds',
    label: '退款管理',
    icon: '💰',
    path: '/admin/refunds',
  },
  {
    key: 'notifications',
    label: '通知管理',
    icon: '🔔',
    path: '/admin/notifications',
  },
  {
    key: 'invitations',
    label: '邀请码管理',
    icon: '📧',
    path: '/admin/invitations',
  },
  {
    key: 'forum',
    label: '论坛管理',
    icon: '💬',
    path: '/admin/forum',
  },
  {
    key: 'flea-market',
    label: '跳蚤市场',
    icon: '🛒',
    path: '/admin/flea-market',
  },
  {
    key: 'leaderboard',
    label: '排行榜',
    icon: '🏆',
    path: '/admin/leaderboard',
  },
  {
    key: 'banners',
    label: 'Banner管理',
    icon: '🖼️',
    path: '/admin/banners',
  },
  {
    key: 'reports',
    label: '举报管理',
    icon: '🚨',
    path: '/admin/reports',
  },
];

export const AdminLayout: React.FC<AdminLayoutProps> = ({
  children,
  menuItems = defaultMenuItems,
}) => {
  const navigate = useNavigate();
  const location = useLocation();
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [showUserMenu, setShowUserMenu] = useState(false);

  const handleLogout = async () => {
    try {
      await adminLogout();
      message.success('已登出');
      navigate('/admin/login');
    } catch (error) {
      message.error('登出失败');
      console.error(error);
    }
  };

  const isActiveRoute = (path: string) => {
    if (path === '/admin') {
      return location.pathname === '/admin';
    }
    return location.pathname.startsWith(path);
  };

  const handleMenuClick = (item: MenuItem) => {
    navigate(item.path);
  };

  return (
    <div className={styles.layout}>
      {/* Sidebar */}
      <aside className={`${styles.sidebar} ${sidebarCollapsed ? styles.collapsed : ''}`}>
        <div className={styles.sidebarHeader}>
          <h1 className={styles.logo}>
            {sidebarCollapsed ? 'L' : 'LinkU 管理后台'}
          </h1>
          <button
            className={styles.toggleButton}
            onClick={() => setSidebarCollapsed(!sidebarCollapsed)}
            aria-label={sidebarCollapsed ? '展开侧边栏' : '收起侧边栏'}
          >
            {sidebarCollapsed ? '→' : '←'}
          </button>
        </div>

        <nav className={styles.nav}>
          {menuItems.map((item) => (
            <button
              key={item.key}
              className={`${styles.navItem} ${isActiveRoute(item.path) ? styles.active : ''}`}
              onClick={() => handleMenuClick(item)}
              title={sidebarCollapsed ? item.label : undefined}
            >
              {item.icon && <span className={styles.icon}>{item.icon}</span>}
              {!sidebarCollapsed && <span className={styles.label}>{item.label}</span>}
            </button>
          ))}
        </nav>
      </aside>

      {/* Main Content Area */}
      <div className={styles.mainContainer}>
        {/* Top Bar */}
        <header className={styles.topBar}>
          <div className={styles.breadcrumb}>
            {/* Breadcrumb can be added later */}
          </div>

          <div className={styles.topBarActions}>
            {/* User Menu */}
            <div className={styles.userMenuContainer}>
              <button
                className={styles.userButton}
                onClick={() => setShowUserMenu(!showUserMenu)}
              >
                <span className={styles.userAvatar}>👤</span>
                <span className={styles.userName}>管理员</span>
              </button>

              {showUserMenu && (
                <>
                  <div
                    className={styles.userMenuOverlay}
                    onClick={() => setShowUserMenu(false)}
                  />
                  <div className={styles.userMenu}>
                    <button
                      className={styles.userMenuItem}
                      onClick={() => {
                        navigate('/admin/settings');
                        setShowUserMenu(false);
                      }}
                    >
                      ⚙️ 设置
                    </button>
                    <button
                      className={styles.userMenuItem}
                      onClick={() => {
                        handleLogout();
                        setShowUserMenu(false);
                      }}
                    >
                      🚪 登出
                    </button>
                  </div>
                </>
              )}
            </div>
          </div>
        </header>

        {/* Page Content */}
        <main className={styles.content}>{children}</main>

        {/* Footer */}
        <footer className={styles.footer}>
          <p>© 2025 LinkU. All rights reserved.</p>
        </footer>
      </div>
    </div>
  );
};

export default AdminLayout;
