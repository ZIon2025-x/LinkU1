import { useCallback, useRef, useEffect } from 'react';

/**
 * 节流回调 Hook
 * 用于优化高频事件（如滚动、resize）的处理
 * 
 * @param callback - 要节流的回调函数
 * @param delay - 节流延迟时间（毫秒）
 * @returns 节流后的回调函数
 */
export function useThrottledCallback<T extends (...args: any[]) => any>(
  callback: T,
  delay: number
): T {
  // 初始化为 0，确保第一次调用立即执行
  const lastRun = useRef(0);
  // 使用浏览器原生类型，避免与 Node.js 类型冲突
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  // 用 ref 保存最新 callback，避免每次 callback 变化都重新生成节流函数
  const callbackRef = useRef(callback);
  
  // 始终保存最新的 callback
  useEffect(() => {
    callbackRef.current = callback;
  }, [callback]);
  
  // 组件卸载时清理定时器，避免在卸载组件上 setState
  useEffect(() => {
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    };
  }, []);
  
  return useCallback(
    ((...args: Parameters<T>) => {
      const now = Date.now();
      const timeSinceLastRun = now - lastRun.current;
      
      const run = () => {
        lastRun.current = Date.now();
        callbackRef.current(...args);
      };
      
      if (timeSinceLastRun >= delay) {
        run();
      } else {
        if (timeoutRef.current) {
          clearTimeout(timeoutRef.current);
        }
        timeoutRef.current = setTimeout(run, delay - timeSinceLastRun);
      }
    }) as T,
    [delay] // 只依赖 delay，callback 通过 ref 访问最新值
  );
}

