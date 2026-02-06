/**
 * i18n 国际化工具函数测试
 */

import {
  SUPPORTED_LANGUAGES,
  DEFAULT_LANGUAGE,
  getLanguageFromPath,
  removeLanguageFromPath,
  addLanguageToPath,
  detectBrowserLanguage,
  getLanguageSwitchUrl,
  hasLanguagePrefix
} from './i18n';

describe('i18n 工具函数', () => {
  describe('常量', () => {
    test('SUPPORTED_LANGUAGES 应该包含 en 和 zh', () => {
      expect(SUPPORTED_LANGUAGES).toContain('en');
      expect(SUPPORTED_LANGUAGES).toContain('zh');
      expect(SUPPORTED_LANGUAGES).toHaveLength(2);
    });

    test('DEFAULT_LANGUAGE 应该是 en', () => {
      expect(DEFAULT_LANGUAGE).toBe('en');
    });
  });

  describe('getLanguageFromPath', () => {
    test('从英文路径中提取语言', () => {
      expect(getLanguageFromPath('/en/tasks')).toBe('en');
      expect(getLanguageFromPath('/en')).toBe('en');
      expect(getLanguageFromPath('/en/forum/post/123')).toBe('en');
    });

    test('从中文路径中提取语言', () => {
      expect(getLanguageFromPath('/zh/tasks')).toBe('zh');
      expect(getLanguageFromPath('/zh')).toBe('zh');
      expect(getLanguageFromPath('/zh/forum/post/123')).toBe('zh');
    });

    test('没有语言前缀时返回默认语言', () => {
      expect(getLanguageFromPath('/tasks')).toBe(DEFAULT_LANGUAGE);
      expect(getLanguageFromPath('/')).toBe(DEFAULT_LANGUAGE);
      expect(getLanguageFromPath('/forum/post/123')).toBe(DEFAULT_LANGUAGE);
    });

    test('无效语言前缀返回默认语言', () => {
      expect(getLanguageFromPath('/fr/tasks')).toBe(DEFAULT_LANGUAGE);
      expect(getLanguageFromPath('/de')).toBe(DEFAULT_LANGUAGE);
    });
  });

  describe('removeLanguageFromPath', () => {
    test('移除英文语言前缀', () => {
      expect(removeLanguageFromPath('/en/tasks')).toBe('/tasks');
      expect(removeLanguageFromPath('/en/forum/post/123')).toBe('/forum/post/123');
    });

    test('移除中文语言前缀', () => {
      expect(removeLanguageFromPath('/zh/tasks')).toBe('/tasks');
      expect(removeLanguageFromPath('/zh/forum/post/123')).toBe('/forum/post/123');
    });

    test('只有语言前缀时返回根路径', () => {
      expect(removeLanguageFromPath('/en')).toBe('/');
      expect(removeLanguageFromPath('/zh')).toBe('/');
    });

    test('没有语言前缀时保持原样', () => {
      expect(removeLanguageFromPath('/tasks')).toBe('/tasks');
      expect(removeLanguageFromPath('/forum/post/123')).toBe('/forum/post/123');
    });
  });

  describe('addLanguageToPath', () => {
    test('为根路径添加语言前缀', () => {
      expect(addLanguageToPath('/', 'en')).toBe('/en');
      expect(addLanguageToPath('/', 'zh')).toBe('/zh');
      expect(addLanguageToPath('', 'en')).toBe('/en');
    });

    test('为普通路径添加语言前缀', () => {
      expect(addLanguageToPath('/tasks', 'en')).toBe('/en/tasks');
      expect(addLanguageToPath('/forum/post/123', 'zh')).toBe('/zh/forum/post/123');
    });

    test('替换已有的语言前缀', () => {
      expect(addLanguageToPath('/en/tasks', 'zh')).toBe('/zh/tasks');
      expect(addLanguageToPath('/zh/forum', 'en')).toBe('/en/forum');
    });
  });

  describe('detectBrowserLanguage', () => {
    const originalNavigator = global.navigator;

    afterEach(() => {
      // 恢复原始 navigator
      Object.defineProperty(global, 'navigator', {
        value: originalNavigator,
        writable: true
      });
    });

    test('中文浏览器返回 zh', () => {
      Object.defineProperty(global, 'navigator', {
        value: { language: 'zh-CN' },
        writable: true
      });
      expect(detectBrowserLanguage()).toBe('zh');
    });

    test('繁体中文浏览器返回 zh', () => {
      Object.defineProperty(global, 'navigator', {
        value: { language: 'zh-TW' },
        writable: true
      });
      expect(detectBrowserLanguage()).toBe('zh');
    });

    test('英文浏览器返回 en', () => {
      Object.defineProperty(global, 'navigator', {
        value: { language: 'en-US' },
        writable: true
      });
      expect(detectBrowserLanguage()).toBe('en');
    });

    test('其他语言返回默认语言 en', () => {
      Object.defineProperty(global, 'navigator', {
        value: { language: 'fr-FR' },
        writable: true
      });
      expect(detectBrowserLanguage()).toBe('en');
    });
  });

  describe('getLanguageSwitchUrl', () => {
    test('从英文切换到中文', () => {
      expect(getLanguageSwitchUrl('/en/tasks', 'zh')).toBe('/zh/tasks');
      expect(getLanguageSwitchUrl('/en/forum/post/123', 'zh')).toBe('/zh/forum/post/123');
    });

    test('从中文切换到英文', () => {
      expect(getLanguageSwitchUrl('/zh/tasks', 'en')).toBe('/en/tasks');
      expect(getLanguageSwitchUrl('/zh/forum/post/123', 'en')).toBe('/en/forum/post/123');
    });

    test('为没有语言前缀的路径添加语言', () => {
      expect(getLanguageSwitchUrl('/tasks', 'zh')).toBe('/zh/tasks');
      expect(getLanguageSwitchUrl('/tasks', 'en')).toBe('/en/tasks');
    });
  });

  describe('hasLanguagePrefix', () => {
    test('检测到语言前缀', () => {
      expect(hasLanguagePrefix('/en/tasks')).toBe(true);
      expect(hasLanguagePrefix('/zh/forum')).toBe(true);
      expect(hasLanguagePrefix('/en')).toBe(true);
      expect(hasLanguagePrefix('/zh')).toBe(true);
    });

    test('没有语言前缀', () => {
      expect(hasLanguagePrefix('/tasks')).toBe(false);
      expect(hasLanguagePrefix('/forum')).toBe(false);
      expect(hasLanguagePrefix('/')).toBe(false);
    });

    test('无效语言前缀', () => {
      expect(hasLanguagePrefix('/fr/tasks')).toBe(false);
      expect(hasLanguagePrefix('/de')).toBe(false);
    });
  });
});
