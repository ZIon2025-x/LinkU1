/**
 * 模糊化位置信息，只显示城市名称，保护用户隐私
 * 
 * 规则：
 * - "Online" 保持不变
 * - "B16 9NS, Birmingham, UK" -> "Birmingham, UK"
 * - "123 High Street, London, UK" -> "London, UK"
 * - "Birmingham, UK" -> "Birmingham, UK"（已是城市级别）
 */
export function obfuscateLocation(location: string | null | undefined): string {
  if (!location || location.trim() === '') {
    return '';
  }
  
  const trimmed = location.trim();
  
  // Online 保持不变
  if (trimmed.toLowerCase() === 'online') {
    return trimmed;
  }
  
  // 按逗号分隔
  const components = trimmed.split(',').map(s => s.trim());
  
  // 如果只有一个部分，直接返回
  if (components.length <= 1) {
    return trimmed;
  }
  
  // 检测第一个部分是否是邮编（英国邮编格式）
  const firstComponent = components[0];
  const isPostcode = /^[A-Z]{1,2}[0-9][0-9A-Z]?\s*[0-9][A-Z]{2}$/i.test(firstComponent) ||
                     /^[0-9]{5}(-[0-9]{4})?$/.test(firstComponent);  // 美国邮编
  
  // 检测第一个部分是否包含门牌号（以数字开头）
  const hasStreetNumber = /^[0-9]+\s/.test(firstComponent);
  
  if (isPostcode || hasStreetNumber) {
    // 移除第一个部分（邮编或街道地址），返回剩余部分
    if (components.length >= 2) {
      return components.slice(1).join(', ');
    }
  }
  
  // 如果有3个或更多部分，取最后两个（通常是城市和国家）
  if (components.length >= 3) {
    return components.slice(-2).join(', ');
  }
  
  // 否则返回原始内容（只有两个部分，可能就是城市和国家）
  return trimmed;
}

/**
 * 计算两个坐标之间的距离（公里）
 * 使用 Haversine 公式
 */
export function calculateDistance(
  lat1: number, 
  lon1: number, 
  lat2: number, 
  lon2: number
): number {
  const R = 6371; // 地球平均半径（公里）
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = 
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * 格式化距离显示
 * - 小于 1km：显示米
 * - 1-10km：保留一位小数
 * - 10km 以上：整数
 */
export function formatDistance(distanceKm: number): string {
  if (distanceKm < 1) {
    return `${Math.round(distanceKm * 1000)}m`;
  } else if (distanceKm < 10) {
    return `${distanceKm.toFixed(1)}km`;
  } else {
    return `${Math.round(distanceKm)}km`;
  }
}

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

