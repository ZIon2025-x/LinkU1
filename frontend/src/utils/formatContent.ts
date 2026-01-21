/**
 * 论坛内容格式化工具
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
 * @param content 用户输入的原始内容
 * @returns 转换后的标记格式内容
 */
export function encodeContent(content: string): string {
  if (!content) return content;
  
  // 检测是否已经编码过（如果包含 \\n 或 \\c，说明已经编码）
  // 避免重复编码
  if (content.includes('\\n') || content.includes('\\c')) {
    // 检查是否是编码格式：如果包含 \\n 或 \\c 但没有真正的换行符和空格，说明已编码
    // 简单检测：如果包含 \\n 或 \\c 且不包含真正的 \n（换行符），说明已编码
    if (!content.includes('\n') && !content.includes(' ')) {
      return content; // 已经编码，直接返回
    }
  }
  
  let result = content;
  
  // 1. 先处理换行符：将 \n 转换为 \\n（转义）
  // 注意：必须先处理换行符，避免后续处理影响
  result = result.replace(/\n/g, '\\n');
  
  // 2. 处理空格：将空格转换为 \\c
  result = result.replace(/ /g, '\\c');
  
  return result;
}

/**
 * 将标记格式的内容转换为显示格式（显示时使用）
 * 将 \n 和 \c 标记转换回实际的换行符和空格
 * 兼容旧数据：如果内容不包含编码标记，直接返回（向后兼容）
 * @param content 标记格式的内容
 * @returns 转换后的显示格式内容
 */
export function decodeContent(content: string): string {
  if (!content) return content;
  
  // 向后兼容：如果内容不包含编码标记，说明是旧数据，直接返回
  if (!content.includes('\\n') && !content.includes('\\c')) {
    return content;
  }
  
  let result = content;
  
  // 1. 处理换行标记：将 \\n 转换为实际的换行符
  // 连续的 \\n 表示多个换行
  result = result.replace(/\\n/g, '\n');
  
  // 2. 处理空格标记：将 \\c 转换为实际空格
  result = result.replace(/\\c/g, ' ');
  
  return result;
}
