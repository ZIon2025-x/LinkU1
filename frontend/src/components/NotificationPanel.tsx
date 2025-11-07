import React, { useState, useEffect } from 'react';
import { TimeHandlerV2 } from '../utils/timeUtils';
import { respondNegotiation } from '../api';

interface Notification {
  id: number;
  content: string;
  is_read: number;
  created_at: string;
  type?: string;
  related_id?: number;
}

interface NegotiationContent {
  type: string;
  task_title: string;
  task_id?: number;  // 任务ID（如果后端存储了）
  negotiated_price: number;
  currency: string;
  message?: string;
  token_accept: string;
  token_reject: string;
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
                      {TimeHandlerV2.formatUtcToLocal(notification.created_at, 'MMM DD HH:mm')}
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
                  
                  {/* 议价通知特殊处理 */}
                  {notification.type === 'negotiation_offer' ? (() => {
                    try {
                      const negotiationData: NegotiationContent = JSON.parse(notification.content);
                      return (
                        <div>
                          <p style={{
                            margin: '0 0 8px 0',
                            fontSize: '13px',
                            color: '#333',
                            lineHeight: '1.4'
                          }}>
                            <strong>{negotiationData.task_title}</strong>
                            <br />
                            {negotiationData.message && (
                              <>
                                {negotiationData.message}
                                <br />
                              </>
                            )}
                            议价金额: <strong style={{ color: '#059669' }}>
                              {negotiationData.negotiated_price.toFixed(2)} {negotiationData.currency}
                            </strong>
                          </p>
                          
                          {notification.is_read === 0 && (
                            <div style={{
                              display: 'flex',
                              gap: '8px',
                              marginTop: '8px'
                            }}>
                              <button
                                onClick={async () => {
                                  try {
                                    if (!notification.related_id) {
                                      alert('通知数据不完整');
                                      return;
                                    }
                                    // related_id是application_id，需要从content中获取task_id
                                    const taskId = negotiationData.task_id || (notification as any).task_id;
                                    if (!taskId) {
                                      // 如果content中没有task_id，尝试从API获取
                                      alert('通知数据不完整，缺少任务ID。请从任务详情页进行操作。');
                                      return;
                                    }
                                    await respondNegotiation(
                                      taskId,
                                      notification.related_id!,
                                      'accept',
                                      negotiationData.token_accept
                                    );
                                    alert('已同意议价');
                                    onMarkAsRead(notification.id);
                                  } catch (error: any) {
                                    console.error('同意议价失败:', error);
                                    alert(error.response?.data?.detail || '操作失败，请重试');
                                  }
                                }}
                                style={{
                                  flex: 1,
                                  padding: '8px 12px',
                                  border: 'none',
                                  background: '#10b981',
                                  color: 'white',
                                  borderRadius: '6px',
                                  cursor: 'pointer',
                                  fontSize: '12px',
                                  fontWeight: 600,
                                  transition: 'all 0.2s'
                                }}
                                onMouseEnter={(e) => {
                                  e.currentTarget.style.background = '#059669';
                                  e.currentTarget.style.transform = 'translateY(-1px)';
                                }}
                                onMouseLeave={(e) => {
                                  e.currentTarget.style.background = '#10b981';
                                  e.currentTarget.style.transform = 'translateY(0)';
                                }}
                              >
                                同意
                              </button>
                              <button
                                onClick={async () => {
                                  try {
                                    if (!notification.related_id) {
                                      alert('通知数据不完整');
                                      return;
                                    }
                                    const taskId = negotiationData.task_id || (notification as any).task_id;
                                    if (!taskId) {
                                      alert('通知数据不完整，缺少任务ID。请从任务详情页进行操作。');
                                      return;
                                    }
                                    await respondNegotiation(
                                      taskId,
                                      notification.related_id!,
                                      'reject',
                                      negotiationData.token_reject
                                    );
                                    alert('已拒绝议价');
                                    onMarkAsRead(notification.id);
                                  } catch (error: any) {
                                    console.error('拒绝议价失败:', error);
                                    alert(error.response?.data?.detail || '操作失败，请重试');
                                  }
                                }}
                                style={{
                                  flex: 1,
                                  padding: '8px 12px',
                                  border: 'none',
                                  background: '#ef4444',
                                  color: 'white',
                                  borderRadius: '6px',
                                  cursor: 'pointer',
                                  fontSize: '12px',
                                  fontWeight: 600,
                                  transition: 'all 0.2s'
                                }}
                                onMouseEnter={(e) => {
                                  e.currentTarget.style.background = '#dc2626';
                                  e.currentTarget.style.transform = 'translateY(-1px)';
                                }}
                                onMouseLeave={(e) => {
                                  e.currentTarget.style.background = '#ef4444';
                                  e.currentTarget.style.transform = 'translateY(0)';
                                }}
                              >
                                拒绝
                              </button>
                            </div>
                          )}
                        </div>
                      );
                    } catch (error) {
                      // 如果解析失败，显示原始内容
                      return (
                        <p style={{
                          margin: '0 0 8px 0',
                          fontSize: '13px',
                          color: '#333',
                          lineHeight: '1.4'
                        }}>
                          {notification.content}
                        </p>
                      );
                    }
                  })() : (
                    <>
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
                    </>
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
