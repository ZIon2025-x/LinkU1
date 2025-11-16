/**
 * 全局WebSocket管理器
 * 确保整个应用只有一个WebSocket连接
 */

type MessageHandler = (message: any) => void;

class WebSocketManager {
  private static instance: WebSocketManager | null = null;
  private ws: WebSocket | null = null;
  private userId: string | null = null;
  private messageHandlers: Set<MessageHandler> = new Set();
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 5;
  private reconnectTimeout: NodeJS.Timeout | null = null;
  private heartbeatInterval: NodeJS.Timeout | null = null;
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
    // 如果已经连接到同一个用户，不需要重新连接
    if (this.ws && this.userId === userId && this.ws.readyState === WebSocket.OPEN) {
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
          
          // 处理心跳消息
          if (msg.type === 'heartbeat') {
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

        // 只在异常关闭时重连
        if (event.code !== 1000 && this.userId && this.reconnectAttempts < this.maxReconnectAttempts) {
          this.reconnectAttempts++;
          this.reconnectTimeout = setTimeout(() => {
            this.doConnect();
          }, 5000);
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
   * 启动心跳
   */
  private startHeartbeat(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
    }

    this.heartbeatInterval = setInterval(() => {
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify({ type: 'ping' }));
      }
    }, 30000); // 每30秒发送一次心跳
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

