/**
 * 论坛内容格式化工具（与用户端 frontend 一致）
 * 统一处理换行和空格的标记方案
 *
 * 标记规则：
 * - \n = 换一行
 * - \n\n = 换两行（空一行）
 * - \c = 空一格
 * - \c\c = 空两格
 */

/**
 * 将用户输入的内容转换为标记格式（保存时使用）
 * 将实际的换行符和空格转换为 \n 和 \c 标记
 */
export function encodeContent(content: string): string {
  if (!content) return content;

  if (content.includes('\\n') || content.includes('\\c')) {
    if (!content.includes('\n') && !content.includes(' ')) {
      return content;
    }
  }

  let result = content;
  result = result.replace(/\n/g, '\\n');
  result = result.replace(/ /g, '\\c');
  return result;
}

/**
 * 将标记格式的内容转换为显示格式（显示/编辑时使用）
 * 将 \n 和 \c 标记转换回实际的换行符和空格
 */
export function decodeContent(content: string): string {
  if (!content) return content;

  if (!content.includes('\\n') && !content.includes('\\c')) {
    return content;
  }

  let result = content;
  result = result.replace(/\\n/g, '\n');
  result = result.replace(/\\c/g, ' ');
  return result;
}
