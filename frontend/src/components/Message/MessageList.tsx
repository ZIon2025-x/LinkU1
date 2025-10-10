import React, { useRef, useEffect } from 'react';
import PrivateImageDisplay from './PrivateImageDisplay';
import PrivateImageLoader from './PrivateImageLoader';
import dayjs from 'dayjs';

interface Message {
  id: number;
  sender_id: string;
  receiver_id: string;
  content: string;
  created_at: string;
  is_read: number;
  image_id?: string;
}

interface MessageListProps {
  messages: Message[];
  currentUserId: string;
  userTimezone: string;
  timezoneInfo: any;
  isServiceMode: boolean;
  currentChat: any;
}

const MessageList: React.FC<MessageListProps> = ({
  messages,
  currentUserId,
  userTimezone,
  timezoneInfo,
  isServiceMode,
  currentChat
}) => {
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const formatMessageTime = (timestamp: string) => {
    try {
      let messageTime;
      
      if (isServiceMode && currentChat) {
        // 客服模式：使用英国时间
        messageTime = dayjs.utc(timestamp).tz('Europe/London');
      } else if (userTimezone && timezoneInfo) {
        // 普通聊天：使用用户时区
        messageTime = dayjs.utc(timestamp).tz(userTimezone);
      } else {
        // 默认使用英国时间
        messageTime = dayjs.utc(timestamp).tz('Europe/London');
      }
      
      return messageTime.format('HH:mm');
    } catch (error) {
      console.error('时间格式化错误:', error);
      return dayjs(timestamp).format('HH:mm');
    }
  };

  const renderMessageContent = (message: Message) => {
    // 检查是否是图片消息
    if (message.content.startsWith('[图片] ') || message.image_id) {
      const imageId = message.image_id || message.content.replace('[图片] ', '');
      return (
        <div style={{ maxWidth: '300px', maxHeight: '300px' }}>
          <PrivateImageDisplay
            imageId={imageId}
            currentUserId={currentUserId}
            style={{
              width: '100%',
              height: '100%',
              objectFit: 'cover',
              borderRadius: '8px',
              cursor: 'pointer'
            }}
            alt="私密图片"
          />
        </div>
      );
    }
    
    // 普通文本消息
    return (
      <div style={{ 
        wordBreak: 'break-word',
        whiteSpace: 'pre-wrap',
        lineHeight: '1.4'
      }}>
        {message.content}
      </div>
    );
  };

  return (
    <div style={{ 
      flex: 1, 
      overflowY: 'auto', 
      padding: '16px',
      display: 'flex',
      flexDirection: 'column',
      gap: '8px'
    }}>
      {messages.map((message) => {
        const isOwn = message.sender_id === currentUserId;
        const isSystem = !message.sender_id;
        
        if (isSystem) {
          return (
            <div key={message.id} style={{
              textAlign: 'center',
              margin: '8px 0',
              fontSize: '12px',
              color: '#6b7280',
              fontStyle: 'italic'
            }}>
              {message.content}
            </div>
          );
        }

        return (
          <div
            key={message.id}
            style={{
              display: 'flex',
              justifyContent: isOwn ? 'flex-end' : 'flex-start',
              marginBottom: '8px'
            }}
          >
            <div
              style={{
                maxWidth: '70%',
                padding: '8px 12px',
                borderRadius: '18px',
                backgroundColor: isOwn ? '#3b82f6' : '#f3f4f6',
                color: isOwn ? 'white' : '#1f2937',
                position: 'relative',
                wordBreak: 'break-word'
              }}
            >
                    {renderMessageContent(message)}
              <div
                style={{
                  fontSize: '10px',
                  opacity: 0.7,
                  marginTop: '4px',
                  textAlign: 'right'
                }}
              >
                {formatMessageTime(message.created_at)}
                {isOwn && (
                  <span style={{ marginLeft: '4px' }}>
                    {message.is_read ? '✓✓' : '✓'}
                  </span>
                )}
              </div>
            </div>
          </div>
        );
      })}
      <div ref={messagesEndRef} />
    </div>
  );
};

export default MessageList;
