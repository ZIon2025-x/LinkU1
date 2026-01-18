import { API_BASE_URL } from '../config';

/**
 * 格式化图片URL
 * 将相对路径转换为完整的API URL
 * @param imagePath 图片路径（可能是相对路径或完整URL）
 * @returns 完整的图片URL
 */
export function formatImageUrl(imagePath: string | null | undefined): string {
  if (!imagePath) {
    // 返回默认头像
    return `${API_BASE_URL}/static/avatar1.png`;
  }

  const imageStr = String(imagePath);

  // 如果已经是完整的URL（包含 http:// 或 https://），直接返回
  if (imageStr.startsWith('http://') || imageStr.startsWith('https://')) {
    return imageStr;
  }

  // 如果是相对路径（以 / 开头），添加API base URL
  if (imageStr.startsWith('/')) {
    return `${API_BASE_URL}${imageStr}`;
  }

  // 其他情况，也尝试添加API base URL
  return `${API_BASE_URL}/${imageStr}`;
}
