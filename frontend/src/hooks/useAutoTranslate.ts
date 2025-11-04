import { useState, useEffect, useCallback } from 'react';
import { useTranslation } from './useTranslation';
import { Language } from '../contexts/LanguageContext';

// 翻译缓存
const translationCache = new Map<string, string>();

// 生成缓存键
const getCacheKey = (text: string, targetLang: string): string => {
  return `${text}::${targetLang}`;
};

interface UseAutoTranslateReturn {
  translatedText: string | null;
  isTranslating: boolean;
  showOriginal: boolean;
  toggleOriginal: () => void;
  clearTranslation: () => void;
}

/**
 * 自动翻译hook - 根据语言环境自动翻译文本
 * @param text 原始文本
 * @param language 当前语言环境
 * @param autoTranslate 是否自动翻译（默认true）
 */
export const useAutoTranslate = (
  text: string,
  language: Language,
  autoTranslate: boolean = true
): UseAutoTranslateReturn => {
  const { translate } = useTranslation();
  const [translatedText, setTranslatedText] = useState<string | null>(null);
  const [isTranslating, setIsTranslating] = useState(false);
  const [showOriginal, setShowOriginal] = useState(false);

  // 获取目标语言
  const getTargetLanguage = useCallback(() => {
    return language === 'zh' ? 'en' : 'zh';
  }, [language]);

  // 执行翻译
  const performTranslation = useCallback(async () => {
    if (!text || !text.trim()) {
      setTranslatedText(null);
      return;
    }

    const targetLang = getTargetLanguage();
    const cacheKey = getCacheKey(text, targetLang);

    // 检查缓存
    if (translationCache.has(cacheKey)) {
      setTranslatedText(translationCache.get(cacheKey)!);
      return;
    }

    setIsTranslating(true);
    try {
      const translated = await translate(text, targetLang);
      setTranslatedText(translated);
      // 缓存翻译结果
      translationCache.set(cacheKey, translated);
    } catch (error) {
      console.error('自动翻译失败:', error);
      setTranslatedText(null);
    } finally {
      setIsTranslating(false);
    }
  }, [text, getTargetLanguage, translate]);

  // 当文本或语言改变时自动翻译
  // 注意：由于无法准确检测文本语言，暂时禁用自动翻译
  // 用户可以通过点击按钮手动翻译
  useEffect(() => {
    // 暂时禁用自动翻译，避免翻译错误
    setTranslatedText(null);
  }, [text, language, autoTranslate, showOriginal]);

  // 切换显示原文
  const toggleOriginal = useCallback(() => {
    setShowOriginal(prev => !prev);
  }, []);

  // 清除翻译
  const clearTranslation = useCallback(() => {
    setTranslatedText(null);
    setShowOriginal(false);
  }, []);

  return {
    translatedText: showOriginal ? null : translatedText,
    isTranslating,
    showOriginal,
    toggleOriginal,
    clearTranslation
  };
};

