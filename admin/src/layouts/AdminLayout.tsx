import React, { useState, useRef, ReactNode } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { adminLogout } from '../api';
import { message, Breadcrumb } from 'antd';
import styles from './AdminLayout.module.css';
import NotificationBell, { NotificationBellRef } from '../components/NotificationBell';
import NotificationModal from '../components/NotificationModal';

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
    key: 'tasks',
    label: '任务管理',
    icon: '📋',
    path: '/admin/tasks',
  },
  {
    key: 'cancel-requests',
    label: '取消申请',
    icon: '📝',
    path: '/admin/cancel-requests',
  },
  {
    key: 'customer-service',
    label: '客服管理',
    icon: '🎧',
    path: '/admin/customer-service',
  },
  {
    key: 'job-positions',
    label: '岗位管理',
    icon: '💼',
    path: '/admin/job-positions',
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
    key: 'promotion-codes',
    label: '推广码管理',
    icon: '🏷️',
    path: '/admin/promotion-codes',
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
    key: 'official-activities',
    label: '官方活动',
    icon: '🎉',
    path: '/admin/official-activities',
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
  {
    key: 'payments',
    label: '支付管理',
    icon: '💳',
    path: '/admin/payments',
  },
  {
    key: 'vip',
    label: 'VIP订阅',
    icon: '👑',
    path: '/admin/vip',
  },
  {
    key: 'recommendation',
    label: '推荐系统',
    icon: '📈',
    path: '/admin/recommendation',
  },
  {
    key: 'student-verification',
    label: '学生认证',
    icon: '🎓',
    path: '/admin/student-verification',
  },
  {
    key: 'oauth-clients',
    label: 'OAuth客户端',
    icon: '🔐',
    path: '/admin/oauth-clients',
  },
];

const PATH_LABELS: Record<string, string> = {
  '/admin': '仪表盘',
  '/admin/users': '用户管理',
  '/admin/experts': '专家管理',
  '/admin/tasks': '任务管理',
  '/admin/cancel-requests': '取消申请',
  '/admin/job-positions': '岗位管理',
  '/admin/customer-service': '客服管理',
  '/admin/coupons': '优惠券管理',
  '/admin/promotion-codes': '推广码管理',
  '/admin/disputes': '纠纷管理',
  '/admin/refunds': '退款管理',
  '/admin/notifications': '通知管理',
  '/admin/invitations': '邀请码管理',
  '/admin/forum': '论坛管理',
  '/admin/flea-market': '跳蚤市场',
  '/admin/leaderboard': '排行榜',
  '/admin/official-activities': '官方活动',
  '/admin/banners': 'Banner管理',
  '/admin/reports': '举报管理',
  '/admin/payments': '支付管理',
  '/admin/vip': 'VIP订阅',
  '/admin/recommendation': '推荐系统',
  '/admin/student-verification': '学生认证',
  '/admin/oauth-clients': 'OAuth客户端',
  '/admin/settings': '设置',
  '/admin/2fa': '双因素认证',
};

export const AdminLayout: React.FC<AdminLayoutProps> = ({
  children,
  menuItems = defaultMenuItems,
}) => {
  const navigate = useNavigate();
  const location = useLocation();
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [showUserMenu, setShowUserMenu] = useState(false);
  const [showNotificationModal, setShowNotificationModal] = useState(false);
  const notificationBellRef = useRef<NotificationBellRef>(null);

  const breadcrumbItems = React.useMemo(() => {
    const pathname = location.pathname;
    const items: { title: string }[] = [{ title: 'LinkU 管理后台' }];
    if (PATH_LABELS[pathname] && pathname !== '/admin') {
      items.push({ title: PATH_LABELS[pathname] });
    }
    return items;
  }, [location.pathname]);

  const handleLogout = async () => {
    try {
      await adminLogout();
      message.success('已登出');
      navigate('/login');
    } catch (error) {
      message.error('登出失败');
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
          <Breadcrumb items={breadcrumbItems} className={styles.breadcrumb} />

          <div className={styles.topBarActions}>
            <NotificationBell
              ref={notificationBellRef}
              userType="admin"
              onOpenModal={() => setShowNotificationModal(true)}
            />
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

      <NotificationModal
        isOpen={showNotificationModal}
        onClose={() => setShowNotificationModal(false)}
        userType="admin"
        onNotificationRead={() => notificationBellRef.current?.refreshUnreadCount()}
      />
    </div>
  );
};

export default AdminLayout;
