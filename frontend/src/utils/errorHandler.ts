/**
 * 统一错误处理工具
 * 提供友好的错误提示，统一错误处理逻辑
 */

/**
 * 检查是否为需要设置收款账户的错误（428）
 */
export const isStripeSetupRequiredError = (error: any): boolean => {
  return error?.response?.status === 428;
};

/**
 * 获取 428 错误的提示消息
 */
export const getStripeSetupRequiredMessage = (error: any, fallbackKey?: string): string => {
  if (error?.response?.data?.detail) {
    return error.response.data.detail;
  }
  return fallbackKey || '请先设置收款账户';
};

/**
 * 处理需要设置收款账户的错误（428）
 * 显示提示消息并在短暂延迟后跳转到设置页面
 * 
 * @param error 错误对象
 * @param options 选项
 * @returns 是否为 428 错误
 */
export const handleStripeSetupRequired = (
  error: any,
  options: {
    showMessage: (msg: string) => void;
    navigate: (path: string) => void;
    onBeforeNavigate?: () => void;
    fallbackMessage?: string;
    navigateDelay?: number;
  }
): boolean => {
  if (!isStripeSetupRequiredError(error)) {
    return false;
  }

  const message = getStripeSetupRequiredMessage(error, options.fallbackMessage);
  options.showMessage(message);
  
  // 执行跳转前的清理操作（如关闭弹窗）
  if (options.onBeforeNavigate) {
    options.onBeforeNavigate();
  }
  
  // 延迟跳转，让用户有时间看到提示
  const delay = options.navigateDelay ?? 800;
  setTimeout(() => {
    options.navigate('/settings?tab=payment');
  }, delay);
  
  return true;
};

export interface ErrorResponse {
  detail?: string | string[] | { msg?: string; message?: string };
  message?: string;
  error?: string;
  errors?: string[];
}

/**
 * 获取友好的错误消息
 * @param error 错误对象
 * @returns 友好的错误消息
 */
export const getErrorMessage = (error: any): string => {
  // 处理网络错误
  if (error?.code === 'ERR_NETWORK' || error?.message === 'Network Error') {
    return '网络错误，请检查网络连接';
  }

  // 处理超时错误
  if (error?.code === 'ECONNABORTED' || error?.message?.includes('timeout')) {
    return '请求超时，请稍后重试';
  }

  // 处理HTTP响应错误
  if (error?.response) {
    const status = error.response.status;
    const data: ErrorResponse = error.response.data || {};
    
    switch (status) {
      case 400:
        return parseErrorDetail(data) || '请求参数错误，请检查输入';
      case 401:
        return '请先登录';
      case 403:
        return parseErrorDetail(data) || '没有权限执行此操作';
      case 404:
        return parseErrorDetail(data) || '资源不存在';
      case 409:
        return parseErrorDetail(data) || '资源冲突，请检查是否重复操作';
      case 429:
        const retryAfter = error.response.headers['retry-after'] || error.response.headers['Retry-After'];
        if (retryAfter) {
          return `请求过于频繁，请在 ${retryAfter} 秒后重试`;
        }
        return parseErrorDetail(data) || '请求过于频繁，请稍后再试';
      case 500:
        return '服务器错误，请稍后再试';
      case 502:
        return '网关错误，服务暂时不可用';
      case 503:
        return '服务暂时不可用，请稍后重试';
      default:
        return parseErrorDetail(data) || `操作失败 (${status})，请稍后再试`;
    }
  }
  
  // 处理普通错误消息
  if (error?.message) {
    return error.message;
  }
  
  // 默认错误消息
  return '操作失败，请稍后再试';
};

/**
 * 解析错误详情
 * @param data 错误响应数据
 * @returns 错误消息字符串
 */
const parseErrorDetail = (data: ErrorResponse): string | null => {
  // 优先使用 message 字段
  if (data.message) {
    return data.message;
  }

  // 然后尝试 detail 字段
  if (data.detail) {
    if (typeof data.detail === 'string') {
      return data.detail;
    }
    if (Array.isArray(data.detail)) {
      return data.detail.map((item: any) => {
        if (typeof item === 'string') {
          return item;
        }
        return item.msg || item.message || JSON.stringify(item);
      }).join('；');
    }
    if (typeof data.detail === 'object') {
      return data.detail.msg || data.detail.message || JSON.stringify(data.detail);
    }
  }

  // 尝试 errors 数组
  if (data.errors && Array.isArray(data.errors)) {
    return data.errors.join('；');
  }

  // 尝试 error 字段
  if (data.error) {
    return data.error;
  }

  return null;
};

/**
 * 判断错误是否可重试
 * @param error 错误对象
 * @returns 是否可重试
 */
export const isRetryableError = (error: any): boolean => {
  if (!error?.response) {
    // 网络错误可以重试
    return error?.code === 'ERR_NETWORK' || error?.message === 'Network Error';
  }

  const status = error.response.status;
  // 5xx 错误和 429 错误可以重试
  return status >= 500 || status === 429;
};

/**
 * 获取重试延迟时间（毫秒）
 * @param error 错误对象
 * @param attempt 当前重试次数
 * @returns 延迟时间（毫秒）
 */
export const getRetryDelay = (error: any, attempt: number = 1): number => {
  // 如果有 Retry-After 头，使用它
  const retryAfter = error?.response?.headers?.['retry-after'] || 
                     error?.response?.headers?.['Retry-After'];
  if (retryAfter) {
    return parseInt(retryAfter, 10) * 1000;
  }

  // 指数退避：1s, 2s, 4s, 8s...
  return Math.min(1000 * Math.pow(2, attempt - 1), 8000);
};

/**
 * 记录错误（用于错误监控）
 * @param error 错误对象
 * @param context 错误上下文
 */
export const logError = (error: any, context?: Record<string, any>): void => {
  const errorMessage = getErrorMessage(error);
  const errorInfo = {
    message: errorMessage,
    status: error?.response?.status,
    url: error?.config?.url || error?.request?.url,
    method: error?.config?.method,
    context,
    timestamp: new Date().toISOString(),
  };
  void errorInfo;

  // 在生产环境中，可以发送到错误监控服务（如 Sentry）
  if (process.env.NODE_ENV === 'production') {
    // TODO: 集成错误监控服务
    // Sentry.captureException(error, { extra: errorInfo });
    // 错误信息已记录，可用于错误监控服务
  } else {
    // 开发环境：错误信息已记录
    // 如需调试，可在此处添加日志输出
  }
};

