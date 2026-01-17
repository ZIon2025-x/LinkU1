/**
 * 模糊化位置信息，只显示城市名称，保护用户隐私
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
  
  // 邮编格式检测
  const postcodePattern = /^[A-Z]{1,2}[0-9][0-9A-Z]?\s*[0-9][A-Z]{2}$/i;
  const usPostcodePattern = /^[0-9]{5}(-[0-9]{4})?$/;
  const isPostcode = (component: string): boolean => {
    return postcodePattern.test(component) || usPostcodePattern.test(component);
  };
  
  // 检测是否包含门牌号（以数字开头）
  const hasStreetNumber = (component: string): boolean => {
    return /^[0-9]+\s/.test(component);
  };
  
  // 过滤掉邮编和街道地址
  let filteredComponents = [...components];
  
  if (hasStreetNumber(filteredComponents[0]) && filteredComponents.length > 1) {
    filteredComponents = filteredComponents.slice(1);
  }
  
  filteredComponents = filteredComponents.filter(component => !isPostcode(component));
  
  if (filteredComponents.length >= 2) {
    const lastTwo = filteredComponents.slice(-2);
    return lastTwo.join(', ');
  } else if (filteredComponents.length === 1) {
    return filteredComponents[0];
  }
  
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
  
  return trimmed;
}

/**
 * 计算两个坐标之间的距离（公里）
 */
export function calculateDistance(
  lat1: number, 
  lon1: number, 
  lat2: number, 
  lon2: number
): number {
  const R = 6371;
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
 * 格式化浏览量
 */
export function formatViewCount(count: number): string {
  if (count < 1000) {
    return String(count);
  } else if (count < 10000) {
    const kValue = count / 1000.0;
    const kValueFloor = Math.floor(kValue * 10) / 10.0;
    if (Math.abs(kValueFloor - Math.floor(kValueFloor)) < 0.01) {
      return `${Math.floor(kValueFloor)}k`;
    }
    const formatted = kValueFloor.toFixed(1) + 'k';
    return formatted.replace(/\.?0+$/, '');
  } else if (count < 100000) {
    const wanValue = count / 10000.0;
    const wanValueFloor = Math.floor(wanValue * 10) / 10.0;
    if (Math.abs(wanValueFloor - Math.floor(wanValueFloor)) < 0.01) {
      return `${Math.floor(wanValueFloor)}万`;
    }
    const formatted = wanValueFloor.toFixed(1) + '万';
    return formatted.replace(/\.?0+$/, '');
  } else {
    const wanValue = Math.floor(count / 10000);
    return `${wanValue}万+`;
  }
}

/**
 * 格式化文件大小
 */
export function formatFileSize(bytes: number): string {
  if (bytes < 1024) {
    return bytes + ' B';
  } else if (bytes < 1024 * 1024) {
    return (bytes / 1024).toFixed(1) + ' KB';
  } else if (bytes < 1024 * 1024 * 1024) {
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  } else {
    return (bytes / (1024 * 1024 * 1024)).toFixed(1) + ' GB';
  }
}

/**
 * 格式化日期时间
 */
export function formatDateTime(dateString: string | Date): string {
  const date = typeof dateString === 'string' ? new Date(dateString) : dateString;
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/**
 * 格式化相对时间
 */
export function formatRelativeTime(dateString: string | Date): string {
  const date = typeof dateString === 'string' ? new Date(dateString) : dateString;
  const now = new Date();
  const diff = now.getTime() - date.getTime();
  
  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  
  if (seconds < 60) {
    return '刚刚';
  } else if (minutes < 60) {
    return `${minutes}分钟前`;
  } else if (hours < 24) {
    return `${hours}小时前`;
  } else if (days < 30) {
    return `${days}天前`;
  } else {
    return formatDateTime(date);
  }
}
