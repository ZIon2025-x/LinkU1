/**
 * 格式化浏览量，超过1000、10000、100000时使用模糊显示
 * 
 * 规则：
 * - 超过1000：显示为 "1.2k" 格式
 * - 超过10000：显示为 "1.2万" 格式
 * - 超过100000：显示为 "10万+" 格式
 */
export function formatViewCount(count: number): string {
  if (count < 1000) {
    return String(count);
  } else if (count < 10000) {
    // 超过1000，显示为 k 格式（保留一位小数，向下取整）
    const kValue = count / 1000.0;
    // 向下取整到一位小数
    const kValueFloor = Math.floor(kValue * 10) / 10.0;
    if (Math.abs(kValueFloor - Math.floor(kValueFloor)) < 0.01) {
      return `${Math.floor(kValueFloor)}k`;
    }
    const formatted = kValueFloor.toFixed(1) + 'k';
    // 移除末尾的0和小数点
    return formatted.replace(/\.?0+$/, '');
  } else if (count < 100000) {
    // 超过10000，显示为万格式（保留一位小数，向下取整）
    const wanValue = count / 10000.0;
    // 向下取整到一位小数
    const wanValueFloor = Math.floor(wanValue * 10) / 10.0;
    if (Math.abs(wanValueFloor - Math.floor(wanValueFloor)) < 0.01) {
      return `${Math.floor(wanValueFloor)}万`;
    }
    const formatted = wanValueFloor.toFixed(1) + '万';
    // 移除末尾的0和小数点
    return formatted.replace(/\.?0+$/, '');
  } else {
    // 超过100000，显示为 "10万+" 格式
    const wanValue = Math.floor(count / 10000);
    return `${wanValue}万+`;
  }
}

