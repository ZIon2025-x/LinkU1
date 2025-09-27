import React, { useState, useEffect } from 'react';
import { getStaffNotifications, markStaffNotificationRead, markAllStaffNotificationsRead } from '../api';
import dayjs from 'dayjs';

interface StaffNotification {
  id: number;
  recipient_id: string;
  recipient_type: string;
  sender_id?: string;
  title: string;
  content: string;
  notification_type: string;
  is_read: number;
  created_at: string;
  read_at?: string;
}

interface NotificationModalProps {
  isOpen: boolean;
  onClose: () => void;
  userType: 'customer_service' | 'admin';
  onNotificationRead?: () => void; // 添加回调函数
}

const NotificationModal: React.FC<NotificationModalProps> = ({ isOpen, onClose, userType, onNotificationRead }) => {
  const [notifications, setNotifications] = useState<StaffNotification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(false);

  const loadNotifications = async () => {
    try {
      setLoading(true);
      const response = await getStaffNotifications();
      setNotifications(response.notifications || []);
      setUnreadCount(response.unread_count || 0);
    } catch (error) {
      console.error('加载提醒失败:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isOpen) {
      loadNotifications();
    }
  }, [isOpen]);

  const handleMarkAsRead = async (notificationId: number) => {
    try {
      await markStaffNotificationRead(notificationId);
      // 重新加载提醒列表（确保显示正确的已读/未读状态）
      await loadNotifications();
      // 通知父组件更新未读数量
      if (onNotificationRead) {
        onNotificationRead();
      }
    } catch (error) {
      console.error('标记已读失败:', error);
    }
  };

  const handleMarkAllAsRead = async () => {
    try {
      await markAllStaffNotificationsRead();
      // 重新加载提醒列表（现在会显示已读的提醒）
      await loadNotifications();
      // 通知父组件更新未读数量
      if (onNotificationRead) {
        onNotificationRead();
      }
    } catch (error) {
      console.error('标记全部已读失败:', error);
    }
  };

  const getNotificationIcon = (type: string) => {
    switch (type) {
      case 'success':
        return '✅';
      case 'warning':
        return '⚠️';
      case 'error':
        return '❌';
      default:
        return 'ℹ️';
    }
  };

  const getNotificationColor = (type: string) => {
    switch (type) {
      case 'success':
        return '#28a745';
      case 'warning':
        return '#ffc107';
      case 'error':
        return '#dc3545';
      default:
        return '#007bff';
    }
  };

  if (!isOpen) return null;

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.5)',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      zIndex: 1000
    }}>
      <div style={{
        backgroundColor: 'white',
        borderRadius: '8px',
        padding: '20px',
        maxWidth: '500px',
        width: '90%',
        maxHeight: '80vh',
        overflow: 'auto',
        boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
      }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '20px',
          paddingBottom: '10px',
          borderBottom: '1px solid #eee'
        }}>
          <h3 style={{ margin: 0, color: '#333' }}>
            系统提醒 ({unreadCount})
          </h3>
          <div>
            {unreadCount > 0 && (
              <button
                onClick={handleMarkAllAsRead}
                style={{
                  padding: '6px 12px',
                  border: 'none',
                  background: '#6c757d',
                  color: 'white',
                  borderRadius: '4px',
                  cursor: 'pointer',
                  fontSize: '12px',
                  marginRight: '10px'
                }}
              >
                全部已读
              </button>
            )}
            <button
              onClick={onClose}
              style={{
                padding: '6px 12px',
                border: 'none',
                background: '#dc3545',
                color: 'white',
                borderRadius: '4px',
                cursor: 'pointer',
                fontSize: '12px'
              }}
            >
              关闭
            </button>
          </div>
        </div>

        {loading ? (
          <div style={{ textAlign: 'center', padding: '20px' }}>
            加载中...
          </div>
        ) : notifications.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '20px', color: '#666' }}>
            暂无提醒
          </div>
        ) : (
          <div style={{ maxHeight: '400px', overflow: 'auto' }}>
            {notifications.map(notification => (
              <div
                key={notification.id}
                style={{
                  border: '1px solid #eee',
                  borderRadius: '6px',
                  padding: '15px',
                  marginBottom: '10px',
                  backgroundColor: notification.is_read ? '#f8f9fa' : '#fff',
                  borderLeft: `4px solid ${getNotificationColor(notification.notification_type)}`,
                  opacity: notification.is_read ? 0.7 : 1
                }}
              >
                <div style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'flex-start',
                  marginBottom: '8px'
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <span style={{ fontSize: '16px' }}>
                      {getNotificationIcon(notification.notification_type)}
                    </span>
                    <h4 style={{
                      margin: 0,
                      fontSize: '14px',
                      fontWeight: 'bold',
                      color: '#333'
                    }}>
                      {notification.title}
                    </h4>
                  </div>
                  <span style={{
                    fontSize: '12px',
                    color: '#666'
                  }}>
                    {dayjs(notification.created_at).format('MM-DD HH:mm')}
                  </span>
                </div>
                
                <p style={{
                  margin: '0 0 10px 0',
                  fontSize: '13px',
                  color: '#555',
                  lineHeight: '1.4'
                }}>
                  {notification.content}
                </p>

                {notification.is_read === 0 && (
                  <button
                    onClick={() => handleMarkAsRead(notification.id)}
                    style={{
                      padding: '4px 8px',
                      border: 'none',
                      background: '#007bff',
                      color: 'white',
                      borderRadius: '3px',
                      cursor: 'pointer',
                      fontSize: '11px'
                    }}
                  >
                    标记已读
                  </button>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default NotificationModal;
