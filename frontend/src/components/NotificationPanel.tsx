import React, { useState, useEffect } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { TimeHandlerV2 } from '../utils/timeUtils';
import { respondNegotiation, replyApplicationMessage, getNegotiationTokens, markForumNotificationRead } from '../api';
import { useLanguage } from '../contexts/LanguageContext';

interface Notification {
  id: number;
  content: string;
  is_read: number;
  created_at: string;
  type?: string;
  related_id?: number;
  // 论坛通知字段
  notification_type?: 'reply_post' | 'reply_reply' | 'like_post' | 'feature_post' | 'pin_post';
  target_type?: 'post' | 'reply';
  target_id?: number;
  from_user?: {
    id: string;
    name: string;
    avatar?: string;
  } | null;
  is_forum?: boolean; // 标识是否为论坛通知
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
  application_id?: number;
}

interface ApplicationMessageContent {
  type: string;
  task_title: string;
  task_id: number;
  message: string;
  application_id: number;
}

interface ApplicationMessageReplyContent {
  type: string;
  task_title: string;
  task_id: number;
  message: string;
  application_id: number;
  original_notification_id: number;
}

interface TaskApplicationContent {
  type: string;
  task_id: number;
  task_title: string;
  application_id: number;
  applicant_name: string;
  message?: string | null;
  negotiated_price?: number | null;
  currency?: string;
}

interface ServiceApplicationContent {
  type: string;
  service_id: number;
  service_name: string;
  applicant_id: string;
  applicant_name: string;
  negotiated_price?: number | null;
}

interface ServiceApplicationRejectedContent {
  type: string;
  service_id: number;
  expert_id: string;
  reject_reason?: string;
  message?: string;
}

interface NotificationPanelProps {
  isOpen: boolean;
  onClose: () => void;
  notifications: Notification[];
  unreadCount: number;
  onMarkAsRead: (id: number) => void;
  onMarkAllRead: () => void;
}

// 议价通知组件（单独组件以便使用 hooks）
const NegotiationOfferNotification: React.FC<{
  notification: Notification;
  onMarkAsRead: (id: number) => void;
  setSelectedNotification: (n: Notification) => void;
  setReplyContent: (s: string) => void;
  setShowReplyModal: (b: boolean) => void;
}> = ({ notification, onMarkAsRead, setSelectedNotification, setReplyContent, setShowReplyModal }) => {
  const [tokens, setTokens] = useState<{token_accept?: string, token_reject?: string, task_id?: number} | null>(null);
  const [loadingTokens, setLoadingTokens] = useState(false);
  
  useEffect(() => {
    // 尝试解析 JSON（旧数据）
    try {
      const negotiationData: NegotiationContent = JSON.parse(notification.content);
      // 如果是旧格式，直接使用 JSON 中的数据
      if (negotiationData.token_accept && negotiationData.token_reject) {
        setTokens({
          token_accept: negotiationData.token_accept,
          token_reject: negotiationData.token_reject,
          task_id: negotiationData.task_id
        });
        return;
      }
    } catch (e) {
      // 解析失败，说明是新格式的文本，需要通过 API 获取 token
    }
    
    // 新格式：通过 API 获取 token
    if (!tokens && !loadingTokens) {
      setLoadingTokens(true);
      getNegotiationTokens(notification.id)
        .then(data => {
          setTokens({
            token_accept: data.token_accept,
            token_reject: data.token_reject,
            task_id: data.task_id
          });
        })
        .catch(err => {
                    // 如果获取失败，可能是旧数据，尝试解析 JSON
          try {
            const negotiationData: NegotiationContent = JSON.parse(notification.content);
            if (negotiationData.token_accept && negotiationData.token_reject) {
              setTokens({
                token_accept: negotiationData.token_accept,
                token_reject: negotiationData.token_reject,
                task_id: negotiationData.task_id
              });
            }
          } catch (e) {
            // 忽略错误
          }
        })
        .finally(() => setLoadingTokens(false));
    }
  }, [notification.id, notification.content]);
  
  // 尝试解析 JSON 获取任务标题等信息（用于旧数据）
  let taskTitle = '';
  let message = '';
  let priceInfo = '';
  try {
    const negotiationData: NegotiationContent = JSON.parse(notification.content);
    taskTitle = negotiationData.task_title || '';
    message = negotiationData.message || '';
    if (negotiationData.negotiated_price) {
      priceInfo = `£${negotiationData.negotiated_price.toFixed(2)} ${negotiationData.currency || 'GBP'}`;
    }
  } catch (e) {
    // 新格式：直接显示文本内容
    const lines = notification.content.split('\n');
    taskTitle = lines[0] || notification.content;
    message = lines.find(l => l.includes('留言：'))?.replace('留言：', '') || '';
    priceInfo = lines.find(l => l.includes('议价金额：'))?.replace('议价金额：', '') || '';
  }
  
  return (
    <div>
      <p style={{
        margin: '0 0 8px 0',
        fontSize: '13px',
        color: '#333',
        lineHeight: '1.4'
      }}>
        {taskTitle || notification.content}
        {message && (
          <>
            <br />
            {message}
          </>
        )}
        {priceInfo && (
          <>
            <br />
            议价金额: <strong style={{ color: '#059669' }}>{priceInfo}</strong>
          </>
        )}
      </p>
      
      {notification.is_read === 0 && tokens && (
        <div style={{
          display: 'flex',
          gap: '8px',
          marginTop: '8px',
          flexWrap: 'wrap'
        }}>
          <button
            onClick={async () => {
              try {
                if (!notification.related_id || !tokens.token_accept || !tokens.task_id) {
                  alert('通知数据不完整');
                  return;
                }
                await respondNegotiation(
                  tokens.task_id,
                  notification.related_id!,
                  'accept',
                  tokens.token_accept
                );
                alert('已同意议价');
                onMarkAsRead(notification.id);
              } catch (error: any) {
                                alert(error.response?.data?.detail || '操作失败，请重试');
              }
            }}
            style={{
              flex: 1,
              minWidth: '60px',
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
                if (!notification.related_id || !tokens.token_reject || !tokens.task_id) {
                  alert('通知数据不完整');
                  return;
                }
                await respondNegotiation(
                  tokens.task_id,
                  notification.related_id!,
                  'reject',
                  tokens.token_reject
                );
                alert('已拒绝议价');
                onMarkAsRead(notification.id);
              } catch (error: any) {
                                alert(error.response?.data?.detail || '操作失败，请重试');
              }
            }}
            style={{
              flex: 1,
              minWidth: '60px',
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
          <button
            onClick={() => {
              setSelectedNotification(notification);
              setReplyContent('');
              setShowReplyModal(true);
            }}
            style={{
              flex: 1,
              minWidth: '60px',
              padding: '8px 12px',
              border: 'none',
              background: '#3b82f6',
              color: 'white',
              borderRadius: '6px',
              cursor: 'pointer',
              fontSize: '12px',
              fontWeight: 600,
              transition: 'all 0.2s'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = '#2563eb';
              e.currentTarget.style.transform = 'translateY(-1px)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = '#3b82f6';
              e.currentTarget.style.transform = 'translateY(0)';
            }}
          >
            留言
          </button>
        </div>
      )}
    </div>
  );
};

const NotificationPanel: React.FC<NotificationPanelProps> = ({
  isOpen,
  onClose,
  notifications,
  unreadCount,
  onMarkAsRead,
  onMarkAllRead
}) => {
  const { t, language } = useLanguage();
  const navigate = useNavigate();
  const { lang: langParam } = useParams<{ lang: string }>();
  const lang = langParam || language || 'zh';
  const [showReplyModal, setShowReplyModal] = useState(false);
  const [selectedNotification, setSelectedNotification] = useState<Notification | null>(null);
  const [replyContent, setReplyContent] = useState('');
  const [replying, setReplying] = useState(false);
  
  if (!isOpen) return null;

  const getNotificationIcon = (notification: Notification) => {
    // 论坛通知
    if (notification.is_forum && notification.notification_type) {
      switch (notification.notification_type) {
        case 'reply_post':
        case 'reply_reply':
          return '💬';
        case 'like_post':
          return '👍';
        case 'feature_post':
          return '⭐';
        case 'pin_post':
          return '📌';
        default:
          return '🔔';
      }
    }
    // 任务通知
    switch (notification.type) {
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

  const handleForumNotificationClick = async (notification: Notification) => {
    if (!notification.is_read && notification.is_forum) {
      try {
        await markForumNotificationRead(notification.id);
        onMarkAsRead(notification.id);
      } catch (error) {
        // 忽略错误，继续跳转
      }
    }
    if (notification.target_id) {
      navigate(`/${lang}/forum/post/${notification.target_id}`);
      onClose();
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
              key={`${notification.is_forum ? 'forum' : 'task'}-${notification.id}`}
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
                  {getNotificationIcon(notification)}
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
                  
                  {/* 论坛通知特殊处理 */}
                  {notification.is_forum ? (() => {
                    const forumType = notification.notification_type || '';
                    const fromUser = notification.from_user;
                    let text = '';
                    
                    switch (forumType) {
                      case 'reply_post':
                        text = fromUser ? `${fromUser.name} 回复了您的帖子` : '有人回复了您的帖子';
                        break;
                      case 'reply_reply':
                        text = fromUser ? `${fromUser.name} 回复了您的回复` : '有人回复了您的回复';
                        break;
                      case 'like_post':
                        text = fromUser ? `${fromUser.name} 点赞了您的帖子` : '有人点赞了您的帖子';
                        break;
                      case 'feature_post':
                        text = '您的帖子被设为精华';
                        break;
                      case 'pin_post':
                        text = '您的帖子被置顶';
                        break;
                      default:
                        text = '论坛通知';
                    }
                    
                    return (
                      <div
                        style={{
                          cursor: 'pointer',
                          padding: '8px',
                          borderRadius: '4px',
                          transition: 'background-color 0.2s'
                        }}
                        onMouseEnter={(e) => {
                          e.currentTarget.style.backgroundColor = '#f5f5f5';
                        }}
                        onMouseLeave={(e) => {
                          e.currentTarget.style.backgroundColor = 'transparent';
                        }}
                        onClick={() => handleForumNotificationClick(notification)}
                      >
                        <p style={{
                          margin: '0 0 8px 0',
                          fontSize: '13px',
                          color: '#333',
                          lineHeight: '1.4'
                        }}>
                          {text}
                        </p>
                        {notification.is_read === 0 && (
                          <button
                            onClick={(e) => {
                              e.stopPropagation();
                              handleForumNotificationClick(notification);
                            }}
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
                            查看
                          </button>
                        )}
                      </div>
                    );
                  })() : notification.type === 'negotiation_offer' ? (
                    <NegotiationOfferNotification
                      notification={notification}
                      onMarkAsRead={onMarkAsRead}
                      setSelectedNotification={setSelectedNotification}
                      setReplyContent={setReplyContent}
                      setShowReplyModal={setShowReplyModal}
                    />
                  ) : notification.type === 'application_accepted' ? (() => {
                    try {
                      const acceptedData = JSON.parse(notification.content);
                      const taskTitle = acceptedData.task_title || t('notifications.unknownTask');
                      const message = t('messages.systemMessages.applicationAccepted', { taskTitle });
                      return (
                        <div>
                          <p style={{
                            margin: '0 0 8px 0',
                            fontSize: '13px',
                            color: '#333',
                            lineHeight: '1.4'
                          }}>
                            {message}
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
                      );
                    } catch (error) {
                      // 如果解析失败，显示原始内容
                      return (
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
                      );
                    }
                  })() : notification.type === 'application_rejected' ? (() => {
                    try {
                      const rejectedData = JSON.parse(notification.content);
                      const taskTitle = rejectedData.task_title || t('notifications.unknownTask');
                      const message = t('notifications.applicationRejectedMessage').replace('{taskTitle}', taskTitle);
                      return (
                        <div>
                          <p style={{
                            margin: '0 0 8px 0',
                            fontSize: '13px',
                            color: '#333',
                            lineHeight: '1.4'
                          }}>
                            {message}
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
                      );
                    } catch (error) {
                      // 如果解析失败，显示原始内容
                      return (
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
                      );
                    }
                  })() : notification.type === 'application_message' ? (() => {
                    try {
                      const messageData: ApplicationMessageContent = JSON.parse(notification.content);
                      return (
                        <div>
                          <p style={{
                            margin: '0 0 8px 0',
                            fontSize: '13px',
                            color: '#333',
                            lineHeight: '1.4'
                          }}>
                            <strong>{messageData.task_title}</strong>
                            <br />
                            {messageData.message}
                          </p>
                          
                          {notification.is_read === 0 && (
                            <button
                              onClick={() => {
                                setSelectedNotification(notification);
                                setReplyContent('');
                                setShowReplyModal(true);
                              }}
                              style={{
                                padding: '8px 12px',
                                border: 'none',
                                background: '#3b82f6',
                                color: 'white',
                                borderRadius: '6px',
                                cursor: 'pointer',
                                fontSize: '12px',
                                fontWeight: 600,
                                transition: 'all 0.2s',
                                marginTop: '8px'
                              }}
                              onMouseEnter={(e) => {
                                e.currentTarget.style.background = '#2563eb';
                                e.currentTarget.style.transform = 'translateY(-1px)';
                              }}
                              onMouseLeave={(e) => {
                                e.currentTarget.style.background = '#3b82f6';
                                e.currentTarget.style.transform = 'translateY(0)';
                              }}
                            >
                              回复留言
                            </button>
                          )}
                        </div>
                      );
                    } catch (error) {
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
                  })() : notification.type === 'application_message_reply' ? (() => {
                    try {
                      const replyData: ApplicationMessageReplyContent = JSON.parse(notification.content);
                      return (
                        <div>
                          <p style={{
                            margin: '0 0 8px 0',
                            fontSize: '13px',
                            color: '#333',
                            lineHeight: '1.4'
                          }}>
                            <strong>{replyData.task_title}</strong>
                            <br />
                            申请者回复了您的留言：
                            <br />
                            {replyData.message}
                          </p>
                          {notification.is_read === 0 && (
                            <button
                              onClick={() => onMarkAsRead(notification.id)}
                              style={{
                                padding: '8px 12px',
                                border: 'none',
                                background: '#2196F3',
                                color: 'white',
                                borderRadius: '6px',
                                cursor: 'pointer',
                                fontSize: '12px',
                                fontWeight: 600,
                                transition: 'all 0.2s',
                                marginTop: '8px'
                              }}
                              onMouseEnter={(e) => {
                                e.currentTarget.style.background = '#1976D2';
                                e.currentTarget.style.transform = 'translateY(-1px)';
                              }}
                              onMouseLeave={(e) => {
                                e.currentTarget.style.background = '#2196F3';
                                e.currentTarget.style.transform = 'translateY(0)';
                              }}
                            >
                              标记已读
                            </button>
                          )}
                        </div>
                      );
                    } catch (error) {
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
                  })() : notification.type === 'task_application' ? (() => {
                    try {
                      const appData: TaskApplicationContent = JSON.parse(notification.content);
                      return (
                        <div>
                          <p style={{
                            margin: '0 0 8px 0',
                            fontSize: '13px',
                            color: '#333',
                            lineHeight: '1.4'
                          }}>
                            <strong>{appData.applicant_name}</strong> 申请了任务 <strong>{appData.task_title}</strong>
                            <br />
                            {appData.message ? (
                              <>
                                申请留言：{appData.message}
                                <br />
                              </>
                            ) : (
                              <>
                                申请留言：无
                                <br />
                              </>
                            )}
                            {appData.negotiated_price !== null && appData.negotiated_price !== undefined ? (
                              <>
                                议价金额：<strong style={{ color: '#059669' }}>
                                  £{appData.negotiated_price.toFixed(2)} {appData.currency || 'GBP'}
                                </strong>
                              </>
                            ) : (
                              <>议价金额：无议价（使用任务原定金额）</>
                            )}
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
                      );
                    } catch (error) {
                      // 如果解析失败，显示原始内容
                      return (
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
                      );
                    }
                  })() : notification.type === 'service_application' ? (() => {
                    // ⚠️ 兼容 JSON 格式（旧数据）和文本格式（新数据）
                    try {
                      const appData: ServiceApplicationContent = JSON.parse(notification.content);
                      return (
                        <div>
                          <p style={{
                            margin: '0 0 8px 0',
                            fontSize: '13px',
                            color: '#333',
                            lineHeight: '1.4'
                          }}>
                            <strong>{appData.applicant_name}</strong> 申请了服务 <strong>{appData.service_name}</strong>
                            {appData.negotiated_price !== null && appData.negotiated_price !== undefined ? (
                              <>
                                <br />
                                议价金额：<strong style={{ color: '#059669' }}>
                                  £{appData.negotiated_price.toFixed(2)}
                                </strong>
                              </>
                            ) : null}
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
                      );
                    } catch (error) {
                      // 如果解析失败，说明是新格式的文本，直接显示
                      return (
                        <>
                          <p style={{
                            margin: '0 0 8px 0',
                            fontSize: '13px',
                            color: '#333',
                            lineHeight: '1.6',
                            whiteSpace: 'pre-line'  // 保留换行符，自动换行
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
                      );
                    }
                  })() : notification.type === 'service_application_rejected' ? (() => {
                    // ⚠️ 兼容 JSON 格式（旧数据）和文本格式（新数据）
                    try {
                      const rejectedData: ServiceApplicationRejectedContent = JSON.parse(notification.content);
                      return (
                        <div>
                          <p style={{
                            margin: '0 0 8px 0',
                            fontSize: '13px',
                            color: '#333',
                            lineHeight: '1.4'
                          }}>
                            {rejectedData.message || '您的服务申请已被拒绝'}
                            {rejectedData.reject_reason && rejectedData.reject_reason.trim() ? (
                              <>
                                <br />
                                拒绝原因：{rejectedData.reject_reason}
                              </>
                            ) : null}
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
                      );
                    } catch (error) {
                      // 如果解析失败，说明是新格式的文本，直接显示
                      return (
                        <>
                          <p style={{
                            margin: '0 0 8px 0',
                            fontSize: '13px',
                            color: '#333',
                            lineHeight: '1.6',
                            whiteSpace: 'pre-line'  // 保留换行符，自动换行
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
      
      {/* 回复留言弹窗 */}
      {showReplyModal && selectedNotification && (() => {
        try {
          const notificationData = JSON.parse(selectedNotification.content);
          const taskId = notificationData.task_id;
          const applicationId = selectedNotification.related_id;
          
          if (!taskId || !applicationId) {
            return null;
          }
          
          return (
            <div style={{
              position: 'fixed',
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              background: 'rgba(0, 0, 0, 0.5)',
              zIndex: 10001,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '20px'
            }}
            onClick={() => {
              setShowReplyModal(false);
              setSelectedNotification(null);
              setReplyContent('');
            }}
            >
              <div style={{
                background: '#fff',
                borderRadius: '16px',
                padding: '24px',
                maxWidth: '500px',
                width: '100%',
                maxHeight: '90vh',
                overflowY: 'auto',
                boxShadow: '0 20px 60px rgba(0,0,0,0.3)'
              }}
              onClick={(e) => e.stopPropagation()}
              >
                <h3 style={{ margin: '0 0 20px 0', fontSize: '20px', fontWeight: 600 }}>回复留言</h3>
                
                <div style={{ marginBottom: '16px', padding: '12px', background: '#f3f4f6', borderRadius: '8px' }}>
                  <div style={{ fontSize: '12px', color: '#6b7280', marginBottom: '4px' }}>任务</div>
                  <div style={{ fontSize: '14px', fontWeight: 600 }}>{notificationData.task_title}</div>
                  {notificationData.message && (
                    <div style={{ fontSize: '12px', color: '#6b7280', marginTop: '8px', paddingTop: '8px', borderTop: '1px solid #e5e7eb' }}>
                      <div style={{ marginBottom: '4px' }}>发布者留言：</div>
                      <div>{notificationData.message}</div>
                    </div>
                  )}
                </div>
                
                <div style={{ marginBottom: '20px' }}>
                  <label style={{
                    display: 'block',
                    marginBottom: '8px',
                    fontSize: '14px',
                    fontWeight: 600,
                    color: '#374151'
                  }}>
                    回复内容
                  </label>
                  <textarea
                    value={replyContent}
                    onChange={(e) => setReplyContent(e.target.value)}
                    placeholder="请输入回复内容..."
                    style={{
                      width: '100%',
                      minHeight: '100px',
                      padding: '12px',
                      border: '2px solid #e5e7eb',
                      borderRadius: '8px',
                      fontSize: '14px',
                      fontFamily: 'inherit',
                      resize: 'vertical',
                      outline: 'none',
                      transition: 'border-color 0.2s ease'
                    }}
                    onFocus={(e) => {
                      e.currentTarget.style.borderColor = '#3b82f6';
                    }}
                    onBlur={(e) => {
                      e.currentTarget.style.borderColor = '#e5e7eb';
                    }}
                  />
                </div>

                <div style={{
                  display: 'flex',
                  gap: '12px',
                  justifyContent: 'flex-end'
                }}>
                  <button
                    onClick={() => {
                      setShowReplyModal(false);
                      setSelectedNotification(null);
                      setReplyContent('');
                    }}
                    disabled={replying}
                    style={{
                      padding: '12px 24px',
                      background: '#f3f4f6',
                      color: '#374151',
                      border: 'none',
                      borderRadius: '8px',
                      fontSize: '14px',
                      fontWeight: 600,
                      cursor: replying ? 'not-allowed' : 'pointer',
                      transition: 'all 0.2s ease',
                      opacity: replying ? 0.6 : 1
                    }}
                    onMouseEnter={(e) => {
                      if (!replying) {
                        e.currentTarget.style.background = '#e5e7eb';
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (!replying) {
                        e.currentTarget.style.background = '#f3f4f6';
                      }
                    }}
                  >
                    取消
                  </button>
                  <button
                    onClick={async () => {
                      if (!replyContent.trim()) {
                        alert('请输入回复内容');
                        return;
                      }
                      
                      setReplying(true);
                      try {
                        await replyApplicationMessage(
                          taskId,
                          applicationId,
                          replyContent,
                          selectedNotification.id
                        );
                        alert('回复已发送');
                        setShowReplyModal(false);
                        setSelectedNotification(null);
                        setReplyContent('');
                        onMarkAsRead(selectedNotification.id);
                      } catch (error: any) {
                                                alert(error.response?.data?.detail || '回复失败，请重试');
                      } finally {
                        setReplying(false);
                      }
                    }}
                    disabled={replying || !replyContent.trim()}
                    style={{
                      padding: '12px 24px',
                      background: replying || !replyContent.trim() ? '#cbd5e1' : 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
                      color: '#fff',
                      border: 'none',
                      borderRadius: '8px',
                      fontSize: '14px',
                      fontWeight: 600,
                      cursor: replying || !replyContent.trim() ? 'not-allowed' : 'pointer',
                      transition: 'all 0.2s ease'
                    }}
                    onMouseEnter={(e) => {
                      if (!replying && replyContent.trim()) {
                        e.currentTarget.style.transform = 'translateY(-1px)';
                        e.currentTarget.style.boxShadow = '0 4px 12px rgba(59, 130, 246, 0.3)';
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (!replying) {
                        e.currentTarget.style.transform = 'translateY(0)';
                        e.currentTarget.style.boxShadow = 'none';
                      }
                    }}
                  >
                    {replying ? '发送中...' : '发送'}
                  </button>
                </div>
              </div>
            </div>
          );
        } catch (error) {
          return null;
        }
      })()}
    </div>
  );
};

export default NotificationPanel;
