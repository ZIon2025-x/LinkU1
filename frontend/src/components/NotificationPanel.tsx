import React, { useState, useEffect } from 'react';

interface Notification {
  id: number;
  content: string;
  is_read: number;
  created_at: string;
  type?: string;
}

interface NotificationPanelProps {
  isOpen: boolean;
  onClose: () => void;
  notifications: Notification[];
  unreadCount: number;
  onMarkAsRead: (id: number) => void;
  onMarkAllRead: () => void;
}

const NotificationPanel: React.FC<NotificationPanelProps> = ({
  isOpen,
  onClose,
  notifications,
  unreadCount,
  onMarkAsRead,
  onMarkAllRead
}) => {
  if (!isOpen) return <></>;

  const getNotificationIcon = (type?: string) => {
    switch (type) {
      case 'success':
        return '✅';
      case 'warning':
        return '⚠️';
      case 'error':
        return '❌';
      default:
        return '🔔';
    }
  };

  const getNotificationColor = (type?: string) => {
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

  return (
    <div 
      className="notification-panel"
      style={{
        position: 'fixed',
        right: '20px',
        top: '50px',
        width: '350px',
        maxHeight: '450px',
        backgroundColor: '#ffffff',
        borderRadius: '8px',
        boxShadow: '0 4px 20px rgba(0, 0, 0, 0.15)',
        border: '1px solid #e0e0e0',
        zIndex: 1000,
        overflow: 'hidden',
        animation: 'slideIn 0.3s ease-out'
      }}
    >
      {/* 头部 */}
      <div style={{
        padding: '12px 16px',
        borderBottom: '1px solid #f0f0f0',
        backgroundColor: '#fafafa',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center'
      }}>
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          fontWeight: '600',
          color: '#333',
          fontSize: '14px'
        }}>
          <span>🔔</span>
          <span>通知</span>
        </div>
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
          {unreadCount > 0 && (
            <button
              onClick={onMarkAllRead}
              style={{
                background: '#4CAF50',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                padding: '4px 8px',
                fontSize: '11px',
                cursor: 'pointer',
                transition: 'background-color 0.2s'
              }}
              onMouseEnter={(e) => e.currentTarget.style.background = '#45a049'}
              onMouseLeave={(e) => e.currentTarget.style.background = '#4CAF50'}
            >
              全部已读
            </button>
          )}
          <button
            onClick={onClose}
            style={{
              background: 'none',
              border: 'none',
              fontSize: '16px',
              cursor: 'pointer',
              color: '#999',
              padding: '4px',
              borderRadius: '4px',
              transition: 'background-color 0.2s'
            }}
            onMouseEnter={(e) => e.currentTarget.style.backgroundColor = '#f0f0f0'}
            onMouseLeave={(e) => e.currentTarget.style.backgroundColor = 'transparent'}
          >
            ×
          </button>
        </div>
      </div>

      {/* 通知列表 */}
      <div style={{
        maxHeight: '350px',
        overflowY: 'auto'
      }}>
        {notifications.length === 0 ? (
          <div style={{
            padding: '40px 20px',
            textAlign: 'center',
            color: '#666',
            fontSize: '14px'
          }}>
            <div style={{ fontSize: '32px', marginBottom: '8px' }}>📭</div>
            暂无通知
          </div>
        ) : (
          notifications.map((notification, index) => (
            <div
              key={notification.id}
              style={{
                padding: '12px 16px',
                borderBottom: index < notifications.length - 1 ? '1px solid #f5f5f5' : 'none',
                backgroundColor: notification.is_read === 0 ? '#f0f8ff' : '#ffffff',
                position: 'relative'
              }}
            >
              {/* 未读指示器 */}
              {notification.is_read === 0 && (
                <div style={{
                  position: 'absolute',
                  left: '0',
                  top: '0',
                  bottom: '0',
                  width: '3px',
                  backgroundColor: '#2196F3'
                }} />
              )}
              
              <div style={{
                display: 'flex',
                alignItems: 'flex-start',
                gap: '10px'
              }}>
                <div style={{
                  fontSize: '16px',
                  marginTop: '2px',
                  flexShrink: 0
                }}>
                  {getNotificationIcon(notification.type)}
                </div>
                
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center',
                    marginBottom: '4px'
                  }}>
                    <span style={{
                      fontSize: '11px',
                      color: '#999'
                    }}>
                      {new Date(notification.created_at).toLocaleString('zh-CN', {
                        month: 'short',
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                      })}
                    </span>
                    {notification.is_read === 0 && (
                      <span style={{
                        background: '#ff4757',
                        color: 'white',
                        fontSize: '9px',
                        fontWeight: 'bold',
                        padding: '2px 6px',
                        borderRadius: '10px'
                      }}>
                        新
                      </span>
                    )}
                  </div>
                  
                  <p style={{
                    margin: '0 0 8px 0',
                    fontSize: '13px',
                    color: '#333',
                    lineHeight: '1.4'
                  }}>
                    {notification.content}
                  </p>

                  {notification.is_read === 0 && (
                    <button
                      onClick={() => onMarkAsRead(notification.id)}
                      style={{
                        padding: '4px 8px',
                        border: 'none',
                        background: '#2196F3',
                        color: 'white',
                        borderRadius: '4px',
                        cursor: 'pointer',
                        fontSize: '11px',
                        transition: 'background-color 0.2s'
                      }}
                      onMouseEnter={(e) => e.currentTarget.style.background = '#1976D2'}
                      onMouseLeave={(e) => e.currentTarget.style.background = '#2196F3'}
                    >
                      标记已读
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default NotificationPanel;
