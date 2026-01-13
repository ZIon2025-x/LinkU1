import { useState, useEffect, useCallback, useRef } from 'react';
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
 * 自动翻译hook - 根据语言环境自动翻译文本（优化版：防抖、去重、缓存）
 * 只在文本语言和当前界面语言不同时才翻译
 * @param text 原始文本
 * @param language 当前语言环境
 * @param autoTranslate 是否自动翻译（默认true）
 * @param taskId 任务ID（可选，如果提供则优先使用任务翻译持久化）
 * @param fieldType 字段类型（可选，'title' 或 'description'，需要配合 taskId 使用）
 */
export const useAutoTranslate = (
  text: string,
  language: Language,
  autoTranslate: boolean = true,
  taskId?: number,
  fieldType?: 'title' | 'description'
): UseAutoTranslateReturn => {
  const { translate } = useTranslation();
  const [translatedText, setTranslatedText] = useState<string | null>(null);
  const [isTranslating, setIsTranslating] = useState(false);
  const [showOriginal, setShowOriginal] = useState(false);
  
  // 使用ref跟踪当前翻译请求，防止重复请求
  const currentRequestRef = useRef<Promise<string> | null>(null);
  const lastTextRef = useRef<string>('');
  const lastLanguageRef = useRef<Language>(language);

  // 执行翻译
  const performTranslation = useCallback(async () => {
    const trimmedText = text?.trim() || '';
    
    if (!trimmedText) {
      setTranslatedText(null);
      currentRequestRef.current = null;
      return;
    }

    // 检测文本语言
    const detectedLang = detectLanguage(trimmedText);
    
    // 如果文本语言和当前界面语言相同，不需要翻译
    if (detectedLang === language) {
      setTranslatedText(null);
      currentRequestRef.current = null;
      lastTextRef.current = trimmedText;
      lastLanguageRef.current = language;
      return;
    }

    // 如果文本和语言都没有变化，不需要重新翻译（避免重复请求）
    if (
      trimmedText === lastTextRef.current &&
      language === lastLanguageRef.current
    ) {
      return;
    }

    // 目标语言就是当前界面语言（这样用户就能看到自己语言版本的文本）
    const targetLang = language;

    // 如果提供了 taskId 和 fieldType，优先从数据库获取任务翻译
    if (taskId && fieldType) {
      try {
        const { getTaskTranslation } = await import('../api');
        const existing = await getTaskTranslation(taskId, fieldType, targetLang);
        if (existing.exists && existing.translated_text) {
          setTranslatedText(existing.translated_text);
          lastTextRef.current = trimmedText;
          lastLanguageRef.current = language;
          currentRequestRef.current = null;
          return;
        }
      } catch (error) {
        // 如果任务翻译API失败，降级到普通翻译（静默失败，不影响用户体验）
      }
    }
    
    // 检查持久化缓存（sessionStorage）
    const cached = getTranslationCache(trimmedText, targetLang, detectedLang);
    if (cached) {
      setTranslatedText(cached);
      lastTextRef.current = trimmedText;
      lastLanguageRef.current = language;
      currentRequestRef.current = null;
      return;
    }

    // 如果已有正在进行的相同请求，等待它完成
    if (currentRequestRef.current) {
      try {
        const result = await currentRequestRef.current;
        setTranslatedText(result);
        lastTextRef.current = trimmedText;
        lastLanguageRef.current = language;
      } catch (error) {
        // 请求失败，继续执行新的翻译
      }
      return;
    }

    // 创建新的翻译请求
    setIsTranslating(true);
    const translationPromise = (async () => {
      try {
        let translated: string;
        
        // 如果提供了 taskId 和 fieldType，使用任务翻译API（会保存到数据库）
        if (taskId && fieldType) {
          try {
            const { translateAndSaveTask } = await import('../api');
            const result = await translateAndSaveTask(taskId, fieldType, targetLang, detectedLang);
            translated = result.translated_text;
          } catch (error) {
            // 如果任务翻译API失败，降级到普通翻译
            translated = await translate(trimmedText, targetLang, detectedLang);
          }
        } else {
          // 普通翻译
          translated = await translate(trimmedText, targetLang, detectedLang);
        }
        
        setTranslatedText(translated);
        // 保存到持久化缓存（sessionStorage）
        setTranslationCache(trimmedText, translated, targetLang, detectedLang);
        lastTextRef.current = trimmedText;
        lastLanguageRef.current = language;
        return translated;
      } catch (error) {
        setTranslatedText(null);
        throw error;
      } finally {
        setIsTranslating(false);
        currentRequestRef.current = null;
      }
    })();

    currentRequestRef.current = translationPromise;
  }, [text, language, translate]);

  // 当文本或语言改变时自动翻译（优化防抖：300ms）
  useEffect(() => {
    if (autoTranslate && !showOriginal) {
      // 延迟执行翻译，避免在快速切换时频繁请求（从100ms增加到300ms）
      const timer = setTimeout(() => {
        performTranslation();
      }, 300);
      return () => {
        clearTimeout(timer);
        // 如果组件卸载或依赖变化，取消正在进行的请求
        if (currentRequestRef.current) {
          currentRequestRef.current = null;
        }
      };
    } else {
      setTranslatedText(null);
      currentRequestRef.current = null;
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
    currentRequestRef.current = null;
    lastTextRef.current = '';
  }, []);

  return {
    translatedText: showOriginal ? null : translatedText,
    isTranslating,
    showOriginal,
    toggleOriginal,
    clearTranslation
  };
};
