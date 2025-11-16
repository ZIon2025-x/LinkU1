/**
 * 全局WebSocket管理器
 * 确保整个应用只有一个WebSocket连接
 */

import { 
  WS_CLOSE_CODE_NORMAL,
  WS_CLOSE_CODE_HEARTBEAT_TIMEOUT,
  WS_CLOSE_REASON_NEW_CONNECTION,
  WS_CLOSE_REASON_HEARTBEAT_TIMEOUT
} from '../constants/websocket';

type MessageHandler = (message: any) => void;

class WebSocketManager {
  private static instance: WebSocketManager | null = null;
  private ws: WebSocket | null = null;
  private userId: string | null = null;
  private messageHandlers: Set<MessageHandler> = new Set();
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 5;
  private reconnectTimeout: ReturnType<typeof setTimeout> | null = null;
  private heartbeatInterval: ReturnType<typeof setInterval> | null = null;
  private wsBaseUrl: string = '';

  private constructor() {
    // 私有构造函数，确保单例
  }

  public static getInstance(): WebSocketManager {
    if (!WebSocketManager.instance) {
      WebSocketManager.instance = new WebSocketManager();
    }
    return WebSocketManager.instance;
  }

  /**
   * 初始化WebSocket管理器
   */
  public initialize(wsBaseUrl: string): void {
    this.wsBaseUrl = wsBaseUrl;
  }

  /**
   * 连接到WebSocket服务器
   */
  public connect(userId: string): void {
    // ⚠️ 先清理旧的定时器，防止多条计时器并发
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
      this.reconnectTimeout = null;
    }
    
    // 如果已经连接到同一个用户且连接正常，不需要重新连接
    if (this.ws && 
        this.userId === userId && 
        this.ws.readyState === WebSocket.OPEN) {
      console.debug('WebSocket already connected to user', userId);
      return;
    }

    // 如果正在连接中，等待完成
    if (this.ws && this.ws.readyState === WebSocket.CONNECTING) {
      console.debug('WebSocket connection in progress, waiting...');
      return;
    }

    // 如果连接到不同用户，先断开旧连接
    if (this.ws && this.userId !== userId) {
      this.disconnect();
    }

    // 如果已有连接但未打开，先清理
    if (this.ws) {
      this.cleanup();
    }

    this.userId = userId;
    this.reconnectAttempts = 0;

    this.doConnect();
  }

  /**
   * 执行连接
   */
  private doConnect(): void {
    if (!this.userId || !this.wsBaseUrl) {
      return;
    }

    try {
      const wsUrl = `${this.wsBaseUrl}/ws/chat/${this.userId}`;
      this.ws = new WebSocket(wsUrl);

      this.ws.onopen = () => {
        this.reconnectAttempts = 0;
        if (this.reconnectTimeout) {
          clearTimeout(this.reconnectTimeout);
          this.reconnectTimeout = null;
        }
        this.startHeartbeat();
      };

      this.ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data);
          
          // ⚠️ 处理心跳消息（ping/pong）
          if (msg.type === 'ping') {
            // 响应pong
            if (this.ws && this.ws.readyState === WebSocket.OPEN) {
              this.ws.send(JSON.stringify({ type: 'pong' }));
            }
            return;
          }
          
          if (msg.type === 'pong' || msg.type === 'heartbeat') {
            return;
          }

          // 通知所有订阅者
          this.messageHandlers.forEach(handler => {
            try {
              handler(msg);
            } catch (error) {
              console.error('WebSocket消息处理错误:', error);
            }
          });
        } catch (error) {
          console.error('WebSocket消息解析失败:', error);
        }
      };

      this.ws.onerror = (error) => {
        console.error('WebSocket错误:', error);
      };

      this.ws.onclose = (event) => {
        this.cleanup();

        // ⚠️ 先清理旧的定时器，防止多定时器并存
        if (this.reconnectTimeout) {
          clearTimeout(this.reconnectTimeout);
          this.reconnectTimeout = null;
        }
        
        // ⚠️ 检查是否是"新连接替换"场景（协议契约）
        // 统一：只在 code===1000 && reason===NEW_CONNECTION 时不重连
        const isNewConnectionReplacement = event.code === WS_CLOSE_CODE_NORMAL && 
          event.reason === WS_CLOSE_REASON_NEW_CONNECTION;
        
        // 如果是新连接替换，不触发重连
        if (isNewConnectionReplacement) {
          console.debug('WebSocket closed due to new connection replacement, no reconnect');
          return;
        }
        
        // 检查是否是心跳超时（需要重连）
        const isHeartbeatTimeout = event.code === WS_CLOSE_CODE_HEARTBEAT_TIMEOUT;
        
        // 只在异常关闭或心跳超时时重连（排除正常关闭且不是新连接替换的情况）
        if ((event.code !== WS_CLOSE_CODE_NORMAL || isHeartbeatTimeout) && 
            this.userId && 
            this.reconnectAttempts < this.maxReconnectAttempts) {
          this.reconnectAttempts++;
          
          // 指数回退 + 抖动（jitter），避免同步风暴
          const baseDelay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
          const jitter = Math.random() * 1000; // 0-1秒随机抖动
          const delay = baseDelay + jitter;
          
          // ⚠️ 检查窗口可见性和网络状态
          if (document.hidden || !navigator.onLine) {
            // 窗口隐藏或离线，延迟重连
            this.reconnectTimeout = setTimeout(() => {
              if (!document.hidden && navigator.onLine) {
                this.doConnect();
              }
            }, delay);
            return;
          }
          
          this.reconnectTimeout = setTimeout(() => {
            this.doConnect();
          }, delay);
        }
      };
    } catch (error) {
      console.error('WebSocket连接失败:', error);
    }
  }

  /**
   * 断开连接
   */
  public disconnect(): void {
    this.userId = null;
    this.cleanup();
  }

  /**
   * 清理资源
   */
  private cleanup(): void {
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
      this.reconnectTimeout = null;
    }

    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }

    if (this.ws) {
      try {
        this.ws.close(1000, '主动断开连接');
      } catch (error) {
        // 忽略关闭错误
      }
      this.ws = null;
    }
  }

  /**
   * 启动心跳（已由服务端统一处理，前端只需响应pong）
   * ⚠️ 注意：心跳已由服务端统一处理，前端只需在收到ping时响应pong
   */
  private startHeartbeat(): void {
    // 心跳已由服务端统一处理，前端只需响应pong（在onmessage中处理）
    // 不再需要前端主动发送心跳
  }

  /**
   * 订阅消息
   */
  public subscribe(handler: MessageHandler): () => void {
    this.messageHandlers.add(handler);
    
    // 返回取消订阅函数
    return () => {
      this.messageHandlers.delete(handler);
    };
  }

  /**
   * 发送消息
   */
  public send(message: any): boolean {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
      return true;
    }
    console.warn('WebSocket未连接，无法发送消息');
    return false;
  }

  /**
   * 获取连接状态
   */
  public isConnected(): boolean {
    return this.ws !== null && this.ws.readyState === WebSocket.OPEN;
  }

  /**
   * 获取当前用户ID
   */
  public getCurrentUserId(): string | null {
    return this.userId;
  }
}

export default WebSocketManager.getInstance();

