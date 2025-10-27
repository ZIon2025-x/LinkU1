import { useEffect, useRef, useState, useCallback } from 'react';

interface WebSocketMessage {
  type: string;
  data: any;
}

interface UseWebSocketOptions {
  url: string;
  userId: string;
  onMessage?: (message: WebSocketMessage) => void;
  onConnect?: () => void;
  onDisconnect?: () => void;
  onError?: (error: Event) => void;
  reconnectInterval?: number;
  maxReconnectAttempts?: number;
}

export const useWebSocket = ({
  url,
  userId,
  onMessage,
  onConnect,
  onDisconnect,
  onError,
  reconnectInterval = 3000,
  maxReconnectAttempts = 5
}: UseWebSocketOptions) => {
  const [isConnected, setIsConnected] = useState(false);
  const [reconnectAttempts, setReconnectAttempts] = useState(0);
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const heartbeatIntervalRef = useRef<NodeJS.Timeout | null>(null);

  const connect = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      return;
    }

    try {
      const ws = new WebSocket(`${url}/ws/chat/${userId}`);
      wsRef.current = ws;

      ws.onopen = () => {
        setIsConnected(true);
        setReconnectAttempts(0);
        onConnect?.();
        
        // 启动心跳
        heartbeatIntervalRef.current = setInterval(() => {
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'ping' }));
          }
        }, 30000); // 每30秒发送一次心跳
      };

      ws.onmessage = (event) => {
        try {
          const message: WebSocketMessage = JSON.parse(event.data);
          
          // 忽略心跳响应
          if (message.type === 'pong') {
            return;
          }
          
          onMessage?.(message);
        } catch (error) {
          console.error('WebSocket消息解析失败:', error);
        }
      };

      ws.onclose = (event) => {
        setIsConnected(false);
        onDisconnect?.();
        
        // 清理心跳
        if (heartbeatIntervalRef.current) {
          clearInterval(heartbeatIntervalRef.current);
          heartbeatIntervalRef.current = null;
        }
        
        // 如果不是正常关闭，尝试重连
        if (event.code !== 1000 && reconnectAttempts < maxReconnectAttempts) {
          setReconnectAttempts(prev => prev + 1);
          
          reconnectTimeoutRef.current = setTimeout(() => {
            connect();
          }, reconnectInterval);
        }
      };

      ws.onerror = (error) => {
        console.error('WebSocket错误:', error);
        onError?.(error);
      };

    } catch (error) {
      console.error('WebSocket连接失败:', error);
    }
  }, [url, userId, onMessage, onConnect, onDisconnect, onError, reconnectInterval, maxReconnectAttempts, reconnectAttempts]);

  const disconnect = useCallback(() => {
    if (reconnectTimeoutRef.current) {
      clearTimeout(reconnectTimeoutRef.current);
      reconnectTimeoutRef.current = null;
    }
    
    if (heartbeatIntervalRef.current) {
      clearInterval(heartbeatIntervalRef.current);
      heartbeatIntervalRef.current = null;
    }
    
    if (wsRef.current) {
      wsRef.current.close(1000, '主动断开连接');
      wsRef.current = null;
    }
    
    setIsConnected(false);
  }, []);

  const sendMessage = useCallback((message: any) => {
    if (wsRef.current?.readyState === WebSocket.OPEN) {
      wsRef.current.send(JSON.stringify(message));
      return true;
    }
    console.warn('WebSocket未连接，无法发送消息');
    return false;
  }, []);

  // 初始化连接
  useEffect(() => {
    if (userId) {
      connect();
    }
    
    return () => {
      disconnect();
    };
  }, [userId, connect, disconnect]);

  // 清理函数
  useEffect(() => {
    return () => {
      disconnect();
    };
  }, [disconnect]);

  return {
    isConnected,
    reconnectAttempts,
    sendMessage,
    connect,
    disconnect
  };
};
