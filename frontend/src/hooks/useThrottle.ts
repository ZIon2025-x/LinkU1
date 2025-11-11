/**
 * 节流 Hook
 * 限制函数执行频率，在指定时间内最多执行一次
 */
import { useCallback, useRef } from 'react';

/**
 * 节流 Hook
 * @param func 要节流的函数
 * @param delay 节流间隔（毫秒）
 * @returns 节流后的函数
 */
export function useThrottle<T extends (...args: any[]) => any>(
  func: T,
  delay: number = 300
): T {
  const lastRunRef = useRef<number>(0);
  
  return useCallback((...args: Parameters<T>) => {
    const now = Date.now();
    if (now - lastRunRef.current >= delay) {
      lastRunRef.current = now;
      func(...args);
    }
  }, [func, delay]) as T;
}

