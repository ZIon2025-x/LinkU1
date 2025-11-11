/**
 * 防抖 Hook
 * 延迟执行函数，在指定时间内如果再次调用则重新计时
 */
import { useCallback, useRef } from 'react';

/**
 * 防抖 Hook
 * @param func 要防抖的函数
 * @param delay 延迟时间（毫秒）
 * @returns 防抖后的函数
 */
export function useDebounce<T extends (...args: any[]) => any>(
  func: T,
  delay: number = 300
): T {
  // ⚠️ 使用 ReturnType<typeof setTimeout> 避免浏览器/Node 环境类型冲突
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  
  return useCallback((...args: Parameters<T>) => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }
    timeoutRef.current = setTimeout(() => {
      func(...args);
    }, delay);
  }, [func, delay]) as T;
}

