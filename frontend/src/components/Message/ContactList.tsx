import React from 'react';
import { TimeHandlerV2 } from '../../utils/timeUtils';
import { useLanguage } from '../../contexts/LanguageContext';

interface Contact {
  id: string;
  name: string;
  avatar: string;
  email: string;
  user_level: number;
  task_count: number;
  avg_rating: number;
  last_message_time: string | null;
  is_verified: boolean;
  unread_count?: number;
}

interface ContactListProps {
  contacts: Contact[];
  activeContact: Contact | null;
  onContactSelect: (contact: Contact) => void;
  unreadCounts: Record<string, number>;
  loading: boolean;
}

const ContactList: React.FC<ContactListProps> = ({
  contacts,
  activeContact,
  onContactSelect,
  unreadCounts,
  loading
}) => {
  const { t } = useLanguage();
  
  const getLevelBadge = (level: number) => {
    switch (level) {
      case 2:
        return <span style={{ 
          background: '#fbbf24', 
          color: 'white', 
          padding: '2px 6px', 
          borderRadius: '4px', 
          fontSize: '10px',
          fontWeight: 'bold'
        }}>VIP</span>;
      case 3:
        return <span style={{ 
          background: '#8b5cf6', 
          color: 'white', 
          padding: '2px 6px', 
          borderRadius: '4px', 
          fontSize: '10px',
          fontWeight: 'bold'
        }}>超级VIP</span>;
      default:
        return null;
    }
  };

  const formatLastMessageTime = (timestamp: string | null) => {
    // 使用新的统一时间处理系统，确保正确处理UTC时间
    if (!timestamp) return '';
    
    try {
      return TimeHandlerV2.formatLastMessageTime(timestamp, undefined, t);
    } catch (error) {
      console.error('最后消息时间格式化错误:', error);
      return '';
    }
  };

  if (loading) {
    return (
      <div style={{ 
        width: '300px', 
        background: '#f9fafb', 
        borderRight: '1px solid #e5e7eb',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '20px'
      }}>
        <div style={{ 
          width: '20px', 
          height: '20px', 
          border: '2px solid #e5e7eb',
          borderTop: '2px solid #3b82f6',
          borderRadius: '50%',
          animation: 'spin 1s linear infinite'
        }} />
        <div style={{ marginTop: '8px', color: '#6b7280' }}>加载中...</div>
      </div>
    );
  }

  return (
    <div style={{ 
      width: '300px', 
      background: '#f9fafb', 
      borderRight: '1px solid #e5e7eb',
      display: 'flex',
      flexDirection: 'column'
    }}>
      <div style={{ 
        padding: '16px', 
        borderBottom: '1px solid #e5e7eb',
        background: 'white'
      }}>
        <h2 style={{ 
          margin: 0, 
          fontSize: '18px', 
          fontWeight: '600',
          color: '#1f2937'
        }}>
          消息
        </h2>
      </div>
      
      <div style={{ flex: 1, overflowY: 'auto' }}>
        {contacts.length === 0 ? (
          <div style={{ 
            padding: '20px', 
            textAlign: 'center', 
            color: '#6b7280' 
          }}>
            暂无联系人
          </div>
        ) : (
          contacts.map((contact) => {
            const unreadCount = unreadCounts[contact.id] || 0;
            const isActive = activeContact?.id === contact.id;
            
            return (
              <div
                key={contact.id}
                onClick={() => onContactSelect(contact)}
                style={{
                  padding: '12px 16px',
                  cursor: 'pointer',
                  borderBottom: '1px solid #f3f4f6',
                  background: isActive ? '#eff6ff' : 'transparent',
                  borderLeft: isActive ? '3px solid #3b82f6' : '3px solid transparent',
                  transition: 'all 0.2s ease',
                  position: 'relative'
                }}
                onMouseEnter={(e) => {
                  if (!isActive) {
                    e.currentTarget.style.background = '#f9fafb';
                  }
                }}
                onMouseLeave={(e) => {
                  if (!isActive) {
                    e.currentTarget.style.background = 'transparent';
                  }
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <div style={{ position: 'relative' }}>
                    <img
                      src={contact.avatar}
                      alt={contact.name}
                      style={{
                        width: '40px',
                        height: '40px',
                        borderRadius: '50%',
                        objectFit: 'cover'
                      }}
                    />
                    {contact.is_verified && (
                      <div style={{
                        position: 'absolute',
                        bottom: '-2px',
                        right: '-2px',
                        width: '16px',
                        height: '16px',
                        background: '#10b981',
                        borderRadius: '50%',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '10px',
                        color: 'white'
                      }}>
                        ✓
                      </div>
                    )}
                  </div>
                  
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ 
                      display: 'flex', 
                      alignItems: 'center', 
                      gap: '8px',
                      marginBottom: '2px'
                    }}>
                      <span style={{ 
                        fontWeight: '500', 
                        color: '#1f2937',
                        fontSize: '14px',
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        whiteSpace: 'nowrap'
                      }}>
                        {contact.name}
                      </span>
                      {getLevelBadge(contact.user_level)}
                    </div>
                    
                    <div style={{ 
                      display: 'flex', 
                      alignItems: 'center', 
                      justifyContent: 'space-between',
                      fontSize: '12px',
                      color: '#6b7280'
                    }}>
                      <span style={{ 
                        overflow: 'hidden',
                        textOverflow: 'ellipsis',
                        whiteSpace: 'nowrap',
                        flex: 1
                      }}>
                        {contact.task_count} 个任务 • {contact.avg_rating.toFixed(1)}⭐
                      </span>
                      <span>
                        {formatLastMessageTime(contact.last_message_time)}
                      </span>
                    </div>
                  </div>
                  
                  {unreadCount > 0 && (
                    <div style={{
                      background: '#ef4444',
                      color: 'white',
                      borderRadius: '50%',
                      width: '20px',
                      height: '20px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '10px',
                      fontWeight: 'bold',
                      minWidth: '20px'
                    }}>
                      {unreadCount > 99 ? '99+' : unreadCount}
                    </div>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};

export default ContactList;
