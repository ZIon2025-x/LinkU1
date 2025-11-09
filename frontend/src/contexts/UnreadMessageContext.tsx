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
        console.log('[UnreadMessageContext] 加载用户信息:', userData?.id);
        setUser(userData);
      } catch (error) {
        console.log('[UnreadMessageContext] 用户未登录');
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
      console.log('[UnreadMessageContext] 刷新未读消息数量:', count, '用户ID:', user.id);
      setUnreadCount(count);
    } catch (error) {
      console.error('[UnreadMessageContext] 获取未读消息数量失败:', error);
    }
  }, [user]);

  // 更新未读数量（允许外部直接设置）
  const updateUnreadCount = useCallback((count: number) => {
    setUnreadCount(count);
  }, []);

  // 初始加载
  useEffect(() => {
    if (user) {
      console.log('[UnreadMessageContext] 用户已登录，开始加载未读消息数量');
      refreshUnreadCount();
    } else {
      console.log('[UnreadMessageContext] 用户未登录，重置未读数量为0');
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
          console.log('未读消息WebSocket连接成功');
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
          console.error('未读消息WebSocket错误:', error);
        };
        
        ws.onclose = (event) => {
          // 只在异常关闭时重连
          if (event.code !== 1000 && user) {
            console.log('未读消息WebSocket断开，5秒后重连...');
            reconnectTimeoutRef.current = setTimeout(() => {
              connectWebSocket();
            }, 5000);
          }
        };
        
        wsRef.current = ws;
      } catch (error) {
        console.error('创建未读消息WebSocket连接失败:', error);
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

