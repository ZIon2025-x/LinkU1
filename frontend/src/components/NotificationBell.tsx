import React, { useState, useEffect, useImperativeHandle, forwardRef } from 'react';
import { getUnreadStaffNotifications, getUnreadAdminNotifications } from '../api';

interface NotificationBellProps {
  userType: 'customer_service' | 'admin';
  onOpenModal: () => void;
}

export interface NotificationBellRef {
  refreshUnreadCount: () => void;
}

const NotificationBell = forwardRef<NotificationBellRef, NotificationBellProps>(({ userType, onOpenModal }, ref) => {
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(false);

  const loadUnreadCount = async () => {
    try {
      setLoading(true);
      let response;
      if (userType === 'admin') {
        // 管理员使用管理员专用通知API
        response = await getUnreadAdminNotifications();
        setUnreadCount(response.unread_count || 0);
      } else {
        // 客服使用客服专用API
        response = await getUnreadStaffNotifications();
        setUnreadCount(response.unread_count || 0);
      }
    } catch (error) {
      console.error('加载未读提醒数量失败:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadUnreadCount();
    
    // 每30秒检查一次未读提醒
    const interval = setInterval(loadUnreadCount, 30000);
    
    return () => clearInterval(interval);
  }, []);

  // 暴露刷新函数给父组件
  useImperativeHandle(ref, () => ({
    refreshUnreadCount: loadUnreadCount
  }));

  return (
    <div style={{ position: 'relative', display: 'inline-block' }}>
      <button
        onClick={onOpenModal}
        disabled={loading}
        style={{
          position: 'relative',
          padding: '8px',
          border: 'none',
          background: 'transparent',
          cursor: loading ? 'not-allowed' : 'pointer',
          fontSize: '18px',
          color: '#666',
          borderRadius: '4px',
          transition: 'all 0.2s ease'
        }}
        onMouseEnter={(e) => {
          if (!loading) {
            e.currentTarget.style.backgroundColor = '#f0f0f0';
            e.currentTarget.style.color = '#333';
          }
        }}
        onMouseLeave={(e) => {
          if (!loading) {
            e.currentTarget.style.backgroundColor = 'transparent';
            e.currentTarget.style.color = '#666';
          }
        }}
      >
        🔔
        {unreadCount > 0 && (
          <span style={{
            position: 'absolute',
            top: '-2px',
            right: '-2px',
            backgroundColor: '#dc3545',
            color: 'white',
            borderRadius: '50%',
            minWidth: '18px',
            height: '18px',
            fontSize: '11px',
            fontWeight: 'bold',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            lineHeight: 1,
            padding: '0 4px',
            boxSizing: 'border-box'
          }}>
            {unreadCount > 99 ? '99+' : unreadCount}
          </span>
        )}
      </button>
    </div>
  );
});

NotificationBell.displayName = 'NotificationBell';

export default NotificationBell;
