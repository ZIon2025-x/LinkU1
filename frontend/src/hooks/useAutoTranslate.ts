import { useState, useEffect, useCallback } from 'react';
import { useTranslation } from './useTranslation';
import { Language } from '../contexts/LanguageContext';
import { getTranslationCache, setTranslationCache } from '../utils/translationCache';

// 简单的语言检测：检查是否包含中文字符
const detectLanguage = (text: string): 'zh' | 'en' => {
  if (!text || !text.trim()) return 'en';
  // 检查是否包含中文字符（Unicode范围：\u4e00-\u9fff）
  const hasChinese = /[\u4e00-\u9fff]/.test(text);
  return hasChinese ? 'zh' : 'en';
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
 * 只在文本语言和当前界面语言不同时才翻译
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

  // 执行翻译
  const performTranslation = useCallback(async () => {
    if (!text || !text.trim()) {
      setTranslatedText(null);
      return;
    }

    // 检测文本语言
    const detectedLang = detectLanguage(text);
    
    // 如果文本语言和当前界面语言相同，不需要翻译
    if (detectedLang === language) {
      setTranslatedText(null);
      return;
    }

    // 目标语言就是当前界面语言（这样用户就能看到自己语言版本的文本）
    const targetLang = language;

    // 检查持久化缓存（sessionStorage）
    const cached = getTranslationCache(text, targetLang, detectedLang);
    if (cached) {
      setTranslatedText(cached);
      return;
    }

    setIsTranslating(true);
    try {
      // 传递源语言，帮助后端更准确翻译
      const translated = await translate(text, targetLang, detectedLang);
      setTranslatedText(translated);
      // 保存到持久化缓存（sessionStorage）
      setTranslationCache(text, translated, targetLang, detectedLang);
    } catch (error) {
            setTranslatedText(null);
    } finally {
      setIsTranslating(false);
    }
  }, [text, language, translate]);

  // 当文本或语言改变时自动翻译
  useEffect(() => {
    if (autoTranslate && !showOriginal) {
      // 延迟执行翻译，避免在快速切换时频繁请求
      const timer = setTimeout(() => {
        performTranslation();
      }, 100);
      return () => clearTimeout(timer);
    } else {
      setTranslatedText(null);
    }
  }, [text, language, autoTranslate, showOriginal, performTranslation]);

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
