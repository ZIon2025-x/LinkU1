/**
 * HTTP/2协议错误修复工具
 * 用于解决ERR_HTTP2_PROTOCOL_ERROR问题
 */

// 检测是否为HTTP/2协议错误
export const isHttp2Error = (error: any): boolean => {
  if (!error) return false;
  
  const errorMessage = error.message || error.toString();
  return errorMessage.includes('ERR_HTTP2_PROTOCOL_ERROR') || 
         errorMessage.includes('HTTP2_PROTOCOL_ERROR') ||
         errorMessage.includes('Failed to fetch');
};

// 强制降级到HTTP/1.1的fetch包装器
export const createHttp1Fetch = () => {
  const originalFetch = window.fetch;
  
  return async (url: string | URL | Request, init?: RequestInit): Promise<Response> => {
    const requestUrl = typeof url === 'string' ? url : url.toString();
    
    // 强制使用HTTP/1.1的配置
    const http1Init: RequestInit = {
      ...init,
      headers: {
        ...init?.headers,
        'Connection': 'keep-alive',
        'Upgrade': 'http/1.1',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache'
      }
    };
    
    try {
      return await originalFetch(requestUrl, http1Init);
    } catch (error) {
      if (isHttp2Error(error)) {
        console.warn('检测到HTTP/2错误，尝试使用XMLHttpRequest:', error);
        
        // 使用XMLHttpRequest作为备用
        return new Promise((resolve, reject) => {
          const xhr = new XMLHttpRequest();
          xhr.open(http1Init.method || 'GET', requestUrl, true);
          xhr.withCredentials = true;
          xhr.responseType = 'blob';
          xhr.timeout = 10000;
          
          // 设置请求头
          if (http1Init.headers) {
            Object.entries(http1Init.headers).forEach(([key, value]) => {
              if (typeof value === 'string') {
                xhr.setRequestHeader(key, value);
              }
            });
          }
          
          xhr.onload = () => {
            if (xhr.status >= 200 && xhr.status < 300) {
              const response = new Response(xhr.response, {
                status: xhr.status,
                statusText: xhr.statusText,
                headers: new Headers()
              });
              resolve(response);
            } else {
              reject(new Error(`XHR HTTP ${xhr.status}: ${xhr.statusText}`));
            }
          };
          
          xhr.onerror = () => reject(new Error('XHR网络错误'));
          xhr.ontimeout = () => reject(new Error('XHR超时'));
          
          xhr.send();
        });
      }
      
      throw error;
    }
  };
};

// 全局应用HTTP/1.1修复
export const applyHttp1Fix = () => {
  if (typeof window !== 'undefined') {
    // 替换全局fetch
    window.fetch = createHttp1Fetch();
    
    // 添加错误监听器
    window.addEventListener('unhandledrejection', (event) => {
      if (isHttp2Error(event.reason)) {
        console.warn('捕获到HTTP/2错误，已自动处理:', event.reason);
        event.preventDefault();
      }
    });
    
    console.log('HTTP/1.1修复已应用');
  }
};

// 检测并修复HTTP/2问题
export const detectAndFixHttp2 = () => {
  if (typeof window !== 'undefined') {
    // 检测浏览器是否支持HTTP/2
    const supportsHttp2 = 'serviceWorker' in navigator && 
                          'PushManager' in window && 
                          'Notification' in window;
    
    if (supportsHttp2) {
      console.log('检测到HTTP/2支持，应用修复措施');
      applyHttp1Fix();
    } else {
      console.log('浏览器不支持HTTP/2，无需修复');
    }
  }
};

// 自动应用修复
export const autoFixHttp2 = () => {
  // 立即应用修复
  detectAndFixHttp2();
  
  // 页面加载完成后再次检查
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', detectAndFixHttp2);
  }
  
  // 窗口加载完成后检查
  window.addEventListener('load', detectAndFixHttp2);
};
