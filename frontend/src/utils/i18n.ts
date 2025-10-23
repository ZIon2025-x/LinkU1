// 国际化工具函数
export type Language = 'en' | 'zh';

export const SUPPORTED_LANGUAGES: Language[] = ['en', 'zh'];
export const DEFAULT_LANGUAGE: Language = 'en';

// 从URL路径中提取语言代码
export function getLanguageFromPath(pathname: string): Language {
  const segments = pathname.split('/').filter(Boolean);
  const firstSegment = segments[0];
  
  if (SUPPORTED_LANGUAGES.includes(firstSegment as Language)) {
    return firstSegment as Language;
  }
  
  return DEFAULT_LANGUAGE;
}

// 从URL路径中移除语言前缀
export function removeLanguageFromPath(pathname: string): string {
  const segments = pathname.split('/').filter(Boolean);
  const firstSegment = segments[0];
  
  if (SUPPORTED_LANGUAGES.includes(firstSegment as Language)) {
    return '/' + segments.slice(1).join('/');
  }
  
  return pathname;
}

// 为路径添加语言前缀
export function addLanguageToPath(path: string, language: Language): string {
  // 如果路径已经是根路径，直接添加语言
  if (path === '/' || path === '') {
    return `/${language}`;
  }
  
  // 如果路径已经包含语言前缀，替换它
  const segments = path.split('/').filter(Boolean);
  if (SUPPORTED_LANGUAGES.includes(segments[0] as Language)) {
    segments[0] = language;
    return '/' + segments.join('/');
  }
  
  // 否则添加语言前缀
  return `/${language}${path}`;
}

// 检测浏览器语言偏好
export function detectBrowserLanguage(): Language {
  if (typeof window === 'undefined') {
    return DEFAULT_LANGUAGE;
  }
  
  // 检测浏览器语言设置
  const browserLang = navigator.language || (navigator as any).userLanguage;
  
  // 如果浏览器语言是中文，返回中文
  if (browserLang.startsWith('zh')) {
    return 'zh';
  }
  
  // 否则返回英文
  return DEFAULT_LANGUAGE;
}

// 生成语言切换URL
export function getLanguageSwitchUrl(currentPath: string, targetLanguage: Language): string {
  return addLanguageToPath(removeLanguageFromPath(currentPath), targetLanguage);
}

// 检查路径是否包含语言前缀
export function hasLanguagePrefix(pathname: string): boolean {
  const segments = pathname.split('/').filter(Boolean);
  return segments.length > 0 && SUPPORTED_LANGUAGES.includes(segments[0] as Language);
}
