/**
 * 图片工具函数
 * 提供图片优化、格式转换等功能
 */

/**
 * 将后端返回的图片路径转换为可用的完整 URL
 * - 完整 http(s) URL：原样返回（后端会做 images/ -> public/images/ 的兼容）
 * - 以 / 开头的路径（如 /uploads/...、/static/...）：原样返回（相对当前站点）
 * - 存储相对路径 public/...、flea_market/...：补上 /uploads/ 前缀
 * - 旧格式 images/...（如 images/service_images/、images/leaderboard_covers/）：
 *   实际文件在 public/images/ 下，补为 /uploads/public/images/...
 * 用于达人头像、榜单图片、服务图片等从 API 取得的图片
 */
export function formatImageUrl(imagePath: string | null | undefined): string {
  if (imagePath == null || imagePath === '') return '';
  const s = String(imagePath).trim();
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  if (s.startsWith('/')) return s;
  if (s.startsWith('public/') || s.startsWith('flea_market/')) return `/uploads/${s}`;
  if (s.startsWith('images/')) return `/uploads/public/${s}`;
  return `/${s}`;
}

/**
 * 确保任务/活动等图片 URL 为可用的绝对地址。
 * 若为 CDN 域名型无协议 URL（如 cdn.link2ur.com/...），补上 https://，
 * 否则 img src 会被当作相对路径导致任务大厅等不显示图片。
 */
export function ensureAbsoluteImageUrl(url: string | null | undefined): string {
  if (url == null || url === '') return '';
  const s = String(url).trim();
  if (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('/')) return s;
  if (!s.includes('://') && s.includes('.') && !s.startsWith('.')) {
    const first = s.split('/')[0] || '';
    if (/^[a-zA-Z0-9][-a-zA-Z0-9.]*$/.test(first)) return `https://${s}`;
  }
  return s;
}

/**
 * 检测浏览器是否支持 WebP 格式
 */
export function supportsWebP(): boolean {
  if (typeof window === 'undefined') return false;
  
  const canvas = document.createElement('canvas');
  canvas.width = 1;
  canvas.height = 1;
  return canvas.toDataURL('image/webp').indexOf('data:image/webp') === 0;
}

/**
 * 检测浏览器是否支持 AVIF 格式
 */
export function supportsAVIF(): Promise<boolean> {
  return new Promise((resolve) => {
    if (typeof window === 'undefined') {
      resolve(false);
      return;
    }
    
    const img = new Image();
    img.onload = () => resolve(true);
    img.onerror = () => resolve(false);
    img.src = 'data:image/avif;base64,AAAAIGZ0eXBhdmlmAAAAAGF2aWZtaWYxbWlhZk1BMUIAAADybWV0YQAAAAAAAAAoaGRscgAAAAAAAAAAcGljdAAAAAAAAAAAAAAAAGxpYmF2aWYAAAAADnBpdG0AAAAAAAEAAAAeaWxvYwAAAABEAAABAAEAAAABAAABGgAAAB0AAAAoaWluZgAAAAAAAQAAABppbmZlAgAAAAABAABhdjAxQ29sb3IAAAAAamlwcnAAAABLaXBjbwAAABRpc3BlAAAAAAAAAAIAAAACAAAAEHBpeGkAAAAAAwgICAAAAAxhdjFDgQ0MAAAAABNjb2xybmNseAACAAIAAYAAAAAXaXBtYQAAAAAAAAABAAEEAQKDBAAAACVtZGF0EgAKCBgABogQEAwgMg8f8D///8WfhwB8+ErK42A=';
  });
}

/**
 * 优化图片 URL，尝试使用更高效的格式
 * @param src 原始图片 URL
 * @param preferFormat 优先使用的格式（webp, avif）
 * @returns 优化后的图片 URL
 */
export function optimizeImageUrl(src: string, preferFormat: 'webp' | 'avif' = 'webp'): string {
  if (!src) return src;
  
  // 如果已经是目标格式，直接返回
  if (src.toLowerCase().endsWith(`.${preferFormat}`)) {
    return src;
  }
  
  // 如果浏览器不支持 WebP，返回原图
  if (preferFormat === 'webp' && !supportsWebP()) {
    return src;
  }
  
  // 尝试将常见格式替换为目标格式
  const formatMap: Record<string, string> = {
    '.jpg': `.${preferFormat}`,
    '.jpeg': `.${preferFormat}`,
    '.png': `.${preferFormat}`,
  };
  
  for (const [ext, newExt] of Object.entries(formatMap)) {
    if (src.toLowerCase().endsWith(ext)) {
      return src.replace(new RegExp(`${ext}$`, 'i'), newExt);
    }
  }
  
  return src;
}

/**
 * 生成响应式图片 srcSet
 * @param baseUrl 基础图片 URL
 * @param widths 宽度数组，例如 [320, 640, 1280]
 * @returns srcSet 字符串
 */
export function generateSrcSet(baseUrl: string, widths: number[]): string {
  return widths
    .map(width => {
      // 假设服务器支持通过参数或路径指定宽度
      // 这里需要根据实际 API 调整
      const url = baseUrl.includes('?') 
        ? `${baseUrl}&w=${width}` 
        : `${baseUrl}?w=${width}`;
      return `${url} ${width}w`;
    })
    .join(', ');
}

/**
 * 生成 sizes 属性用于响应式图片
 * @param breakpoints 断点配置，例如 { mobile: '100vw', tablet: '50vw', desktop: '33vw' }
 * @returns sizes 字符串
 */
export function generateSizes(breakpoints: Record<string, string>): string {
  return Object.entries(breakpoints)
    .map(([breakpoint, size]) => {
      // 这里需要根据实际的媒体查询断点调整
      const mediaQuery = breakpoint === 'mobile' 
        ? '' 
        : `(min-width: ${breakpoint === 'tablet' ? '768px' : '1024px'}) `;
      return mediaQuery ? `${mediaQuery}${size}` : size;
    })
    .join(', ');
}

/**
 * 预加载图片
 * @param src 图片 URL
 * @returns Promise，图片加载完成后 resolve
 */
export function preloadImage(src: string): Promise<void> {
  return new Promise((resolve, reject) => {
    if (typeof window === 'undefined') {
      resolve();
      return;
    }
    
    const img = new Image();
    img.onload = () => resolve();
    img.onerror = reject;
    img.src = src;
  });
}

/**
 * 批量预加载图片
 * @param srcs 图片 URL 数组
 * @returns Promise，所有图片加载完成后 resolve
 */
export function preloadImages(srcs: string[]): Promise<void[]> {
  return Promise.all(srcs.map(src => preloadImage(src)));
}
