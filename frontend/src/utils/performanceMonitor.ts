/**
 * 性能监控工具函数
 * 注意：仅用于本地/预发布环境的性能调试，生产环境慎用（会产生额外开销）
 */

/**
 * 测量函数执行性能
 * @param name - 性能测量名称
 * @param fn - 要测量的函数
 */
export function measurePerformance(name: string, fn: () => void) {
  performance.mark(`${name}-start`);
  fn();
  performance.mark(`${name}-end`);
  performance.measure(name, `${name}-start`, `${name}-end`);
  
  // 取最新一次测量结果（而不是第一次）
  const entries = performance.getEntriesByName(name);
  const measure = entries[entries.length - 1];
  
  console.log(`${name}: ${measure.duration}ms`);
  
  // 清理 marks 和 measures，避免内存占用和下次统计干扰
  performance.clearMarks(`${name}-start`);
  performance.clearMarks(`${name}-end`);
  performance.clearMeasures(name);
}

/**
 * 异步性能测量
 * @param name - 性能测量名称
 * @param fn - 要测量的异步函数
 */
export async function measureAsyncPerformance<T>(
  name: string,
  fn: () => Promise<T>
): Promise<T> {
  performance.mark(`${name}-start`);
  const result = await fn();
  performance.mark(`${name}-end`);
  performance.measure(name, `${name}-start`, `${name}-end`);
  
  // 取最新一次测量结果
  const entries = performance.getEntriesByName(name);
  const measure = entries[entries.length - 1];
  
  console.log(`${name}: ${measure.duration}ms`);
  
  // 清理 marks 和 measures
  performance.clearMarks(`${name}-start`);
  performance.clearMarks(`${name}-end`);
  performance.clearMeasures(name);
  
  return result;
}

