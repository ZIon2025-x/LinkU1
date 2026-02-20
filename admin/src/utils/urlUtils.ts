/**
 * 图片 URL 解析工具
 * 解决管理员子域名下相对路径图片无法加载的问题
 */
import { API_BASE_URL, MAIN_SITE_URL } from '../config';

/**
 * 将相对或协议的图片 URL 解析为可访问的完整 URL
 * - 已包含 http(s):// 的 URL 原样返回
 * - 以 / 开头的相对路径：使用 MAIN_SITE_URL（主站通常代理 /uploads/）
 * - 其他情况：尝试使用 API_BASE_URL
 */
export function resolveImageUrl(url: string | null | undefined): string {
  if (!url || typeof url !== 'string' || url.trim() === '') {
    return '';
  }
  const trimmed = url.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  // 相对路径：主站或 API 都可能提供 /uploads/，优先用主站（与后端 FRONTEND_URL 存储一致）
  const base = trimmed.startsWith('/uploads') ? MAIN_SITE_URL : API_BASE_URL;
  const baseClean = base.replace(/\/$/, '');
  const pathClean = trimmed.startsWith('/') ? trimmed : `/${trimmed}`;
  return `${baseClean}${pathClean}`;
}
