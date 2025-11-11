/**
 * 预加载和预取工具函数
 * P1 优化：使用 <link rel="preload"> 和 <link rel="prefetch"> 优化资源加载
 */

/**
 * 预加载关键资源（立即加载，高优先级）
 * @param href 资源 URL
 * @param as 资源类型（'script' | 'style' | 'image' | 'font' | 'fetch'）
 * @param crossorigin 是否跨域
 */
export function preloadResource(
  href: string,
  as: 'script' | 'style' | 'image' | 'font' | 'fetch',
  crossorigin?: boolean
): void {
  const link = document.createElement('link');
  link.rel = 'preload';
  link.href = href;
  link.as = as;
  if (crossorigin) {
    link.crossOrigin = 'anonymous';
  }
  document.head.appendChild(link);
}

/**
 * 预取非关键资源（低优先级，空闲时加载）
 * @param href 资源 URL
 * @param as 资源类型（可选，用于 fetch 类型）
 */
export function prefetchResource(href: string, as?: string): void {
  const link = document.createElement('link');
  link.rel = 'prefetch';
  link.href = href;
  if (as) {
    link.setAttribute('as', as);
  }
  document.head.appendChild(link);
}

/**
 * 预取任务详情数据（在用户可能访问前预取）
 * @param taskId 任务 ID
 * @param apiBaseUrl API 基础 URL
 */
export function prefetchTaskDetail(taskId: number, apiBaseUrl: string = '/api'): void {
  prefetchResource(`${apiBaseUrl}/tasks/${taskId}`, 'fetch');
}

/**
 * 预取用户信息（在需要前预取）
 * @param apiBaseUrl API 基础 URL
 */
export function prefetchUserInfo(apiBaseUrl: string = '/api'): void {
  prefetchResource(`${apiBaseUrl}/users/profile/me`, 'fetch');
}

/**
 * 预加载关键图片（首屏图片）
 * @param imageUrl 图片 URL
 */
export function preloadImage(imageUrl: string): void {
  preloadResource(imageUrl, 'image');
}

