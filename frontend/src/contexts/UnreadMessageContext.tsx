import React, { createContext, useContext, useState, useEffect, useCallback, useRef } from 'react';
import api, { fetchCurrentUser } from '../api';

interface UnreadMessageContextType {
  unreadCount: number;
  refreshUnreadCount: () => Promise<void>;
  updateUnreadCount: (count: number) => void;
}

const UnreadMessageContext = createContext<UnreadMessageContextType>({
  unreadCount: 0,
  refreshUnreadCount: async () => {},
  updateUnreadCount: () => {}
});

export const useUnreadMessages = () => {
  return useContext(UnreadMessageContext);
};

interface UnreadMessageProviderProps {
  children: React.ReactNode;
}

export const UnreadMessageProvider: React.FC<UnreadMessageProviderProps> = ({ children }) => {
  const [unreadCount, setUnreadCount] = useState(0);
  const [user, setUser] = useState<any>(null);
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  // 获取用户信息
  useEffect(() => {
    const loadUser = async () => {
      try {
        const userData = await fetchCurrentUser();
        setUser(userData);
      } catch (error) {
        setUser(null);
      }
    };
    loadUser();
    
    // 定期检查用户登录状态
    const interval = setInterval(loadUser, 60000); // 每分钟检查一次
    return () => clearInterval(interval);
  }, []);

  const refreshUnreadCount = useCallback(async () => {
    if (!user) {
      setUnreadCount(0);
      return;
    }
    
    try {
      const response = await api.get('/api/users/messages/unread/count');
      const count = response.data.unread_count || 0;
      setUnreadCount(count);
    } catch (error) {
      // 静默处理错误
    }
  }, [user]);

  // 更新未读数量（允许外部直接设置）
  const updateUnreadCount = useCallback((count: number) => {
    setUnreadCount(count);
  }, []);

  // 初始加载
  useEffect(() => {
    if (user) {
      refreshUnreadCount();
    } else {
      setUnreadCount(0);
    }
  }, [user, refreshUnreadCount]);

  // WebSocket实时更新
  useEffect(() => {
    if (!user) {
      // 关闭WebSocket连接
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }
      return;
    }

    const connectWebSocket = () => {
      try {
        const { WS_BASE_URL } = require('../config');
        const wsUrl = `${WS_BASE_URL}/ws/chat/${user.id}`;
        const ws = new WebSocket(wsUrl);
        
        ws.onopen = () => {
          if (reconnectTimeoutRef.current) {
            clearTimeout(reconnectTimeoutRef.current);
            reconnectTimeoutRef.current = null;
          }
        };
        
        ws.onmessage = (event) => {
          try {
            const msg = JSON.parse(event.data);
            
            // 处理心跳消息
            if (msg.type === 'heartbeat') {
              return;
            }
            
            // 如果收到新消息，立即刷新未读数量
            if (msg.type === 'message_sent' || (msg.from && msg.content)) {
              // 延迟一点刷新，确保后端已更新
              setTimeout(() => {
                refreshUnreadCount();
              }, 500);
            }
          } catch (error) {
            // 静默处理解析错误
          }
        };
        
        ws.onerror = (error) => {
          // 静默处理错误
        };
        
        ws.onclose = (event) => {
          // 只在异常关闭时重连
          if (event.code !== 1000 && user) {
            reconnectTimeoutRef.current = setTimeout(() => {
              connectWebSocket();
            }, 5000);
          }
        };
        
        wsRef.current = ws;
      } catch (error) {
        // 静默处理错误
      }
    };

    connectWebSocket();

    return () => {
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
        reconnectTimeoutRef.current = null;
      }
    };
  }, [user, refreshUnreadCount]);

  // 定期更新（每10秒，作为WebSocket的备用）
  useEffect(() => {
    if (!user) return;

    const interval = setInterval(() => {
      if (!document.hidden) {
        refreshUnreadCount();
      }
    }, 10000); // 每10秒更新一次

    return () => clearInterval(interval);
  }, [user, refreshUnreadCount]);

  // 页面可见性变化时更新
  useEffect(() => {
    if (!user) return;

    const handleVisibilityChange = () => {
      if (!document.hidden) {
        refreshUnreadCount();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, [user, refreshUnreadCount]);

  return (
    <UnreadMessageContext.Provider value={{ unreadCount, refreshUnreadCount, updateUnreadCount }}>
      {children}
    </UnreadMessageContext.Provider>
  );
};

