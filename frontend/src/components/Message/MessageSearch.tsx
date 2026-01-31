import React, { useState, useEffect, useMemo } from 'react';

interface Message {
  id: number;
  sender_id: string;
  receiver_id: string;
  content: string;
  created_at: string;
  is_read: number;
}

interface MessageSearchProps {
  messages: Message[];
  currentUserId: string;
  onMessageSelect?: (message: Message) => void;
  placeholder?: string;
}

const MessageSearch: React.FC<MessageSearchProps> = ({
  messages,
  currentUserId,
  onMessageSelect,
  placeholder = "搜索消息..."
}) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [showResults, setShowResults] = useState(false);

  // 过滤消息
  const filteredMessages = useMemo(() => {
    if (!searchTerm.trim()) return [];
    
    const term = searchTerm.toLowerCase();
    return messages.filter(message => 
      message.content.toLowerCase().includes(term)
    );
  }, [messages, searchTerm]);

  // 格式化时间
  const formatMessageTime = (timestamp: string) => {
    const date = new Date(timestamp);
    const now = new Date();
    const diffInHours = (now.getTime() - date.getTime()) / (1000 * 60 * 60);
    
    if (diffInHours < 24) {
      return date.toLocaleTimeString('zh-CN', { 
        hour: '2-digit', 
        minute: '2-digit' 
      });
    } else if (diffInHours < 168) { // 7 days
      return date.toLocaleDateString('zh-CN', { 
        month: '2-digit', 
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
      });
    } else {
      return date.toLocaleDateString('zh-CN', { 
        year: '2-digit',
        month: '2-digit', 
        day: '2-digit'
      });
    }
  };

  // 高亮搜索词
  const highlightText = (text: string, searchTerm: string) => {
    if (!searchTerm.trim()) return text;
    
    const regex = new RegExp(`(${searchTerm})`, 'gi');
    const parts = text.split(regex);
    
    return parts.map((part, index) => 
      regex.test(part) ? (
        <mark key={index} style={{ 
          background: '#fef3c7', 
          color: '#92400e',
          padding: '0 2px',
          borderRadius: '2px'
        }}>
          {part}
        </mark>
      ) : part
    );
  };

  // 处理输入变化
  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setSearchTerm(value);
    setShowResults(value.trim().length > 0);
  };

  // 处理消息选择
  const handleMessageSelect = (message: Message) => {
    onMessageSelect?.(message);
    setSearchTerm('');
    setShowResults(false);
  };

  // 处理键盘事件
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      setSearchTerm('');
      setShowResults(false);
    }
  };

  // 点击外部关闭结果
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      const target = event.target as HTMLElement;
      if (!target.closest('[data-message-search]')) {
        setShowResults(false);
      }
    };

    if (showResults) {
      document.addEventListener('mousedown', handleClickOutside);
      return () => document.removeEventListener('mousedown', handleClickOutside);
    }
    return;
  }, [showResults]);

  return (
    <div 
      data-message-search
      style={{ 
        position: 'relative',
        width: '100%'
      }}
    >
      {/* 搜索输入框 */}
      <div style={{
        position: 'relative',
        display: 'flex',
        alignItems: 'center'
      }}>
        <input
          type="text"
          value={searchTerm}
          onChange={handleInputChange}
          onKeyDown={handleKeyDown}
          placeholder={placeholder}
          style={{
            width: '100%',
            padding: '8px 12px 8px 36px',
            border: '1px solid #d1d5db',
            borderRadius: '20px',
            outline: 'none',
            fontSize: '14px',
            background: '#f9fafb'
          }}
        />
        <div style={{
          position: 'absolute',
          left: '12px',
          color: '#6b7280',
          fontSize: '16px'
        }}>
          🔍
        </div>
        {searchTerm && (
          <button
            onClick={() => {
              setSearchTerm('');
              setShowResults(false);
            }}
            style={{
              position: 'absolute',
              right: '8px',
              padding: '4px',
              border: 'none',
              background: 'transparent',
              cursor: 'pointer',
              color: '#6b7280',
              fontSize: '16px'
            }}
          >
            ✕
          </button>
        )}
      </div>

      {/* 搜索结果 */}
      {showResults && (
        <div style={{
          position: 'absolute',
          top: '100%',
          left: 0,
          right: 0,
          background: 'white',
          border: '1px solid #e5e7eb',
          borderRadius: '8px',
          boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)',
          zIndex: 1000,
          maxHeight: '300px',
          overflowY: 'auto',
          marginTop: '4px'
        }}>
          {filteredMessages.length === 0 ? (
            <div style={{
              padding: '16px',
              textAlign: 'center',
              color: '#6b7280',
              fontSize: '14px'
            }}>
              没有找到匹配的消息
            </div>
          ) : (
            <div>
              <div style={{
                padding: '8px 12px',
                background: '#f9fafb',
                borderBottom: '1px solid #e5e7eb',
                fontSize: '12px',
                color: '#6b7280',
                fontWeight: '500'
              }}>
                找到 {filteredMessages.length} 条消息
              </div>
              
              {filteredMessages.map((message) => {
                const isOwn = message.sender_id === currentUserId;
                
                return (
                  <div
                    key={message.id}
                    onClick={() => handleMessageSelect(message)}
                    style={{
                      padding: '12px',
                      borderBottom: '1px solid #f3f4f6',
                      cursor: 'pointer',
                      transition: 'background-color 0.2s ease'
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.background = '#f9fafb';
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.background = 'white';
                    }}
                  >
                    <div style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'flex-start',
                      marginBottom: '4px'
                    }}>
                      <div style={{
                        fontSize: '12px',
                        color: '#6b7280',
                        fontWeight: '500'
                      }}>
                        {isOwn ? '我' : '对方'}
                      </div>
                      <div style={{
                        fontSize: '11px',
                        color: '#9ca3af'
                      }}>
                        {formatMessageTime(message.created_at)}
                      </div>
                    </div>
                    
                    <div style={{
                      fontSize: '14px',
                      color: '#1f2937',
                      lineHeight: '1.4',
                      wordBreak: 'break-word'
                    }}>
                      {highlightText(message.content, searchTerm)}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default MessageSearch;
