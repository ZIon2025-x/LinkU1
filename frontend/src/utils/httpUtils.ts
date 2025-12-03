/**
 * HTTP/1.1强制工具函数
 * 用于解决HTTP/2协议错误问题
 */

// 创建强制使用HTTP/1.1的fetch配置
export const createHttp1FetchConfig = (url: string, options: RequestInit = {}) => {
  return {
    ...options,
    headers: {
      ...options.headers,
      'Connection': 'keep-alive',
      'Upgrade': 'http/1.1',
      'HTTP2-Settings': 'AAMAAABkAARAAAAAAAIAAAAA',
      'TE': 'trailers',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache'
    }
  };
};

// 强制HTTP/1.1的fetch包装器
export const fetchHttp1 = async (url: string, options: RequestInit = {}) => {
  const config = createHttp1FetchConfig(url, options);
  
  try {
    return await fetch(url, config);
  } catch (error) {
    // 只在开发环境输出详细日志
    if (process.env.NODE_ENV === 'development') {
          }
    throw error;
  }
};

// 强制HTTP/1.1的XMLHttpRequest实现
export const xhrHttp1 = (url: string, options: RequestInit = {}): Promise<Response> => {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    
    // 设置请求头
    xhr.open(options.method || 'GET', url, true);
    xhr.withCredentials = true;
    
    // 强制HTTP/1.1
    xhr.setRequestHeader('Connection', 'keep-alive');
    xhr.setRequestHeader('Upgrade', 'http/1.1');
    xhr.setRequestHeader('Cache-Control', 'no-cache');
    xhr.setRequestHeader('Pragma', 'no-cache');
    
    // 设置其他请求头
    if (options.headers) {
      Object.entries(options.headers).forEach(([key, value]) => {
        if (typeof value === 'string') {
          xhr.setRequestHeader(key, value);
        }
      });
    }
    
    // 设置响应类型
    xhr.responseType = 'blob';
    xhr.timeout = 10000;
    
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        // 创建Response对象
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
    
    xhr.onerror = () => {
      reject(new Error('XHR网络错误'));
    };
    
    xhr.ontimeout = () => {
      reject(new Error('XHR超时'));
    };
    
    xhr.send();
  });
};

// 双重备用加载函数
export const loadWithHttp1Fallback = async (url: string, options: RequestInit = {}) => {
  try {
    // 首先尝试fetch
    const response = await fetchHttp1(url, options);
    return response;
  } catch (error) {
    // 只在开发环境输出详细日志
    if (process.env.NODE_ENV === 'development') {
          }
    
    // 如果fetch失败，使用XMLHttpRequest
    try {
      return await xhrHttp1(url, options);
    } catch (xhrError) {
            const errorMessage = error instanceof Error ? error.message : String(error);
      throw new Error(`加载失败: ${errorMessage}`);
    }
  }
};

// 图片加载专用函数
export const loadImageWithHttp1 = async (src: string): Promise<string> => {
  const response = await loadWithHttp1Fallback(src, {
    method: 'GET',
    credentials: 'include',
    headers: {
      'Accept': 'image/*'
    }
  });
  
  if (response.ok) {
    const blob = await response.blob();
    return URL.createObjectURL(blob);
  }
  
  throw new Error(`HTTP ${response.status}: ${response.statusText}`);
};
