import React, { useState, useEffect } from 'react';

interface NotificationButtonProps {
  user: any;
  unreadCount: number;
  onNotificationClick: () => void;
}

const NotificationButton: React.FC<NotificationButtonProps> = ({
  user,
  unreadCount,
  onNotificationClick
}) => {
  if (!user) return <></>;

  return (
    <button
      className="notification-btn"
      onClick={onNotificationClick}
      aria-label="通知"
      style={{
        background: 'none',
        border: 'none',
        cursor: 'pointer',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        width: '44px',
        height: '44px',
        padding: 0,
        position: 'relative',
        borderRadius: '50%',
        transition: 'background-color 0.2s ease'
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.backgroundColor = '#f5f5f5';
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.backgroundColor = 'transparent';
      }}
    >
      <span style={{
        fontSize: '20px',
        color: '#666'
      }}>
        🔔
      </span>
      {unreadCount > 0 && (
        <span style={{
          position: 'absolute',
          top: '8px',
          right: '8px',
          background: 'linear-gradient(135deg, #FF6B6B, #FF4757)',
          color: 'white',
          borderRadius: '50%',
          minWidth: '18px',
          height: '18px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: '0.75rem',
          fontWeight: 'bold',
          lineHeight: 1
        }}>
          {unreadCount}
        </span>
      )}
    </button>
  );
};

export default NotificationButton;
