/**
 * 设备检测工具
 * 用于准确识别用户设备类型和详细信息
 */

export interface DeviceInfo {
  type: 'mobile' | 'tablet' | 'desktop';
  os: string;
  osVersion: string;
  browser: string;
  browserVersion: string;
  screenWidth: number;
  screenHeight: number;
  isTouchDevice: boolean;
  userAgent: string;
}

/**
 * 检测设备类型
 */
export function detectDeviceType(): 'mobile' | 'tablet' | 'desktop' {
  const userAgent = navigator.userAgent || navigator.vendor || (window as any).opera;
  const width = window.innerWidth;
  
  // 检测平板设备
  const isTablet = /iPad|Android|Tablet|PlayBook|Silk/i.test(userAgent) || 
                   (width >= 768 && width <= 1024 && 'ontouchstart' in window);
  
  // 检测移动设备
  const isMobile = /Android|webOS|iPhone|iPod|BlackBerry|IEMobile|Opera Mini|Mobile|mobile|CriOS/i.test(userAgent) ||
                   (width < 768 && 'ontouchstart' in window);
  
  if (isTablet && !isMobile) {
    return 'tablet';
  }
  
  if (isMobile) {
    return 'mobile';
  }
  
  return 'desktop';
}

/**
 * 检测操作系统
 */
export function detectOS(): { name: string; version: string } {
  const userAgent = navigator.userAgent || navigator.vendor || (window as any).opera;
  
  if (/Windows NT 10.0/i.test(userAgent)) {
    return { name: 'Windows', version: '10' };
  }
  if (/Windows NT 6.3/i.test(userAgent)) {
    return { name: 'Windows', version: '8.1' };
  }
  if (/Windows NT 6.2/i.test(userAgent)) {
    return { name: 'Windows', version: '8' };
  }
  if (/Windows NT 6.1/i.test(userAgent)) {
    return { name: 'Windows', version: '7' };
  }
  // 必须先于 Mac OS X 检测：iPhone/iPad 的 UA 含 "like Mac OS X"，否则会误判为 macOS
  if (/iPhone|iPad|iPod/i.test(userAgent)) {
    const match = userAgent.match(/OS (\d+[._]\d+)/);
    return { name: 'iOS', version: match ? match[1].replace('_', '.') : 'Unknown' };
  }
  if (/Mac OS X/i.test(userAgent)) {
    const match = userAgent.match(/Mac OS X (\d+[._]\d+)/);
    return { name: 'macOS', version: match ? match[1].replace('_', '.') : 'Unknown' };
  }
  if (/Android/i.test(userAgent)) {
    const match = userAgent.match(/Android (\d+\.\d+)/);
    return { name: 'Android', version: match ? match[1] : 'Unknown' };
  }
  if (/Linux/i.test(userAgent)) {
    return { name: 'Linux', version: 'Unknown' };
  }
  
  return { name: 'Unknown', version: 'Unknown' };
}

/**
 * 检测浏览器
 */
export function detectBrowser(): { name: string; version: string } {
  const userAgent = navigator.userAgent || navigator.vendor || (window as any).opera;
  
  if (/Edg/i.test(userAgent)) {
    const match = userAgent.match(/Edg\/(\d+\.\d+)/);
    return { name: 'Edge', version: match ? match[1] : 'Unknown' };
  }
  if (/Chrome/i.test(userAgent) && !/Edg/i.test(userAgent)) {
    const match = userAgent.match(/Chrome\/(\d+\.\d+)/);
    return { name: 'Chrome', version: match ? match[1] : 'Unknown' };
  }
  if (/Safari/i.test(userAgent) && !/Chrome/i.test(userAgent)) {
    const match = userAgent.match(/Version\/(\d+\.\d+)/);
    return { name: 'Safari', version: match ? match[1] : 'Unknown' };
  }
  if (/Firefox/i.test(userAgent)) {
    const match = userAgent.match(/Firefox\/(\d+\.\d+)/);
    return { name: 'Firefox', version: match ? match[1] : 'Unknown' };
  }
  if (/Opera|OPR/i.test(userAgent)) {
    const match = userAgent.match(/(?:Opera|OPR)\/(\d+\.\d+)/);
    return { name: 'Opera', version: match ? match[1] : 'Unknown' };
  }
  
  return { name: 'Unknown', version: 'Unknown' };
}

/**
 * 获取完整的设备信息
 */
export function getDeviceInfo(): DeviceInfo {
  const deviceType = detectDeviceType();
  const os = detectOS();
  const browser = detectBrowser();
  
  return {
    type: deviceType,
    os: os.name,
    osVersion: os.version,
    browser: browser.name,
    browserVersion: browser.version,
    screenWidth: window.screen.width,
    screenHeight: window.screen.height,
    isTouchDevice: 'ontouchstart' in window || navigator.maxTouchPoints > 0,
    userAgent: navigator.userAgent
  };
}

/**
 * 获取简化的设备类型（用于API调用）
 */
export function getDeviceType(): string {
  return detectDeviceType();
}
