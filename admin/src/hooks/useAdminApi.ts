import { useState, useCallback } from 'react';
import { message } from 'antd';
import { getErrorMessage } from '../utils/errorHandler';

export interface UseAdminApiConfig<T, P extends any[] = any[]> {
  apiFunction: (...params: P) => Promise<T>;
  onSuccess?: (data: T, ...params: P) => void;
  onError?: (error: any, ...params: P) => void;
  successMessage?: string | ((data: T, ...params: P) => string);
  errorMessage?: string | ((error: any, ...params: P) => string);
  showSuccessMessage?: boolean;
  showErrorMessage?: boolean;
}

export interface UseAdminApiReturn<T, P extends any[]> {
  data: T | null;
  loading: boolean;
  error: any;
  execute: (...params: P) => Promise<T | null>;
  reset: () => void;
}

/**
 * 通用 API 调用管理 Hook
 * 统一处理 API 调用的 loading、错误处理、成功提示等逻辑
 */
export function useAdminApi<T = any, P extends any[] = any[]>(
  config: UseAdminApiConfig<T, P>
): UseAdminApiReturn<T, P> {
  const {
    apiFunction,
    onSuccess,
    onError,
    successMessage,
    errorMessage,
    showSuccessMessage = true,
    showErrorMessage = true,
  } = config;

  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<any>(null);

  const execute = useCallback(
    async (...params: P): Promise<T | null> => {
      setLoading(true);
      setError(null);

      try {
        const result = await apiFunction(...params);
        setData(result);

        if (onSuccess) {
          onSuccess(result, ...params);
        }

        if (showSuccessMessage && successMessage) {
          const msg =
            typeof successMessage === 'function'
              ? successMessage(result, ...params)
              : successMessage;
          message.success(msg);
        }

        return result;
      } catch (err) {
        console.error('API call failed:', err);
        setError(err);

        if (onError) {
          onError(err, ...params);
        }

        if (showErrorMessage) {
          const msg = errorMessage
            ? typeof errorMessage === 'function'
              ? errorMessage(err, ...params)
              : errorMessage
            : getErrorMessage(err);
          message.error(msg);
        }

        return null;
      } finally {
        setLoading(false);
      }
    },
    [
      apiFunction,
      onSuccess,
      onError,
      successMessage,
      errorMessage,
      showSuccessMessage,
      showErrorMessage,
    ]
  );

  const reset = useCallback(() => {
    setData(null);
    setError(null);
    setLoading(false);
  }, []);

  return {
    data,
    loading,
    error,
    execute,
    reset,
  };
}

/**
 * 批量操作 Hook
 * 用于处理多个 API 调用的批量操作
 */
export function useBatchApi<T = any, P extends any[] = any[]>(
  config: Omit<UseAdminApiConfig<T, P>, 'apiFunction'> & {
    apiFunction: (...params: P) => Promise<T>;
  }
) {
  const [loading, setLoading] = useState(false);
  const [results, setResults] = useState<Array<{ success: boolean; data?: T; error?: any }>>([]);

  const executeBatch = useCallback(
    async (paramsList: P[]): Promise<Array<{ success: boolean; data?: T; error?: any }>> => {
      setLoading(true);
      const batchResults: Array<{ success: boolean; data?: T; error?: any }> = [];

      for (const params of paramsList) {
        try {
          const result = await config.apiFunction(...params);
          batchResults.push({ success: true, data: result });

          if (config.onSuccess) {
            config.onSuccess(result, ...params);
          }
        } catch (err) {
          console.error('Batch API call failed:', err);
          batchResults.push({ success: false, error: err });

          if (config.onError) {
            config.onError(err, ...params);
          }
        }
      }

      setResults(batchResults);
      setLoading(false);

      const successCount = batchResults.filter((r) => r.success).length;
      const failCount = batchResults.length - successCount;

      if (config.showSuccessMessage && successCount > 0) {
        message.success(`成功完成 ${successCount} 项操作`);
      }

      if (config.showErrorMessage && failCount > 0) {
        message.error(`失败 ${failCount} 项操作`);
      }

      return batchResults;
    },
    [config]
  );

  return {
    loading,
    results,
    executeBatch,
  };
}
