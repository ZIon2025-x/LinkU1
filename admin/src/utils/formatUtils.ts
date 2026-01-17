/**
 * 模糊化位置信息，只显示城市名称，保护用户隐私
 * 与 iOS 的 obfuscatedLocation 实现保持一致
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
  
  // 邮编格式检测（英国邮编格式：字母数字混合，如 B16 9NS, SW1A 1AA, B15 3EN）
  const postcodePattern = /^[A-Z]{1,2}[0-9][0-9A-Z]?\s*[0-9][A-Z]{2}$/i;
  const usPostcodePattern = /^[0-9]{5}(-[0-9]{4})?$/;
  const isPostcode = (component: string): boolean => {
    return postcodePattern.test(component) || usPostcodePattern.test(component);
  };
  
  // 检测是否包含门牌号（以数字开头）
  const hasStreetNumber = (component: string): boolean => {
    return /^[0-9]+\s/.test(component);
  };
  
  // 过滤掉邮编和街道地址，只保留城市相关的部分
  let filteredComponents = [...components];
  
  // 移除第一个部分（如果是街道地址）
  if (hasStreetNumber(filteredComponents[0]) && filteredComponents.length > 1) {
    filteredComponents = filteredComponents.slice(1);
  }
  
  // 移除所有邮编
  filteredComponents = filteredComponents.filter(component => !isPostcode(component));
  
  // 返回最后两个部分（通常是城市和国家，或区域和城市）
  if (filteredComponents.length >= 2) {
    const lastTwo = filteredComponents.slice(-2);
    return lastTwo.join(', ');
  } else if (filteredComponents.length === 1) {
    // 只有一个部分，直接返回
    return filteredComponents[0];
  }
  
  // 如果过滤后没有内容，返回原始内容的最后两个非邮编部分
  const validComponents: string[] = [];
  for (let i = components.length - 1; i >= 0; i--) {
    const component = components[i];
    if (!isPostcode(component) && !hasStreetNumber(component)) {
      validComponents.unshift(component);
      if (validComponents.length >= 2) {
        break;
      }
    }
  }
  
  if (validComponents.length > 0) {
    return validComponents.join(', ');
  }
  
  // 如果所有部分都被过滤掉了，返回原始内容
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

