import { useState, useCallback, useRef } from 'react';
import { translateText, translateBatch } from '../api';
import { getTranslationCache, setTranslationCache } from '../utils/translationCache';

interface TranslationResult {
  translatedText: string;
  sourceLanguage: string;
  targetLanguage: string;
  originalText: string;
}

interface UseTranslationReturn {
  translate: (text: string, targetLang: string, sourceLang?: string) => Promise<string>;
  translateBatch: (texts: string[], targetLang: string, sourceLang?: string) => Promise<string[]>;
  isTranslating: boolean;
  error: string | null;
}

// 全局请求去重Map（模块级，跨组件实例共享）
const pendingRequests = new Map<string, Promise<string>>();

/**
 * 生成请求键（用于去重）
 */
function getRequestKey(text: string, targetLang: string, sourceLang?: string): string {
  return `${text}::${sourceLang || 'auto'}::${targetLang}`;
}

export const useTranslation = (): UseTranslationReturn => {
  const [isTranslating, setIsTranslating] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const activeRequestsRef = useRef<Set<string>>(new Set());

  const translate = useCallback(async (
    text: string,
    targetLang: string,
    sourceLang?: string
  ): Promise<string> => {
    // 空文本直接返回
    if (!text || !text.trim()) {
      return text;
    }

    const trimmedText = text.trim();
    
    // 1. 先检查本地缓存
    const cached = getTranslationCache(trimmedText, targetLang, sourceLang);
    if (cached) {
      return cached;
    }

    // 2. 检查是否有正在进行的相同请求（去重）
    const requestKey = getRequestKey(trimmedText, targetLang, sourceLang);
    const pendingRequest = pendingRequests.get(requestKey);
    if (pendingRequest) {
      // 等待正在进行的请求完成
      return pendingRequest;
    }

    // 3. 创建新的翻译请求
    const translationPromise = (async () => {
      setIsTranslating(true);
      setError(null);
      activeRequestsRef.current.add(requestKey);

      try {
        const result = await translateText(trimmedText, targetLang, sourceLang);
        const translated = result.translated_text || trimmedText;
        
        // 保存到本地缓存
        setTranslationCache(trimmedText, translated, targetLang, sourceLang);
        
        return translated;
      } catch (err: any) {
        const errorMsg = err.response?.data?.detail || err.message || '翻译失败';
        setError(errorMsg);
        return trimmedText; // 翻译失败时返回原文
      } finally {
        activeRequestsRef.current.delete(requestKey);
        // 只有当没有其他活跃请求时才设置为false
        if (activeRequestsRef.current.size === 0) {
          setIsTranslating(false);
        }
        // 从pendingRequests中移除
        pendingRequests.delete(requestKey);
      }
    })();

    // 将请求添加到pendingRequests中
    pendingRequests.set(requestKey, translationPromise);

    return translationPromise;
  }, []);

  const translateBatchTexts = useCallback(async (
    texts: string[],
    targetLang: string,
    sourceLang?: string
  ): Promise<string[]> => {
    if (!texts || texts.length === 0) {
      return texts;
    }

    // 预处理：去除空白、去重
    const processedTexts: string[] = [];
    const textToIndex: number[] = []; // 原始索引映射
    const seenTexts = new Set<string>();
    
    for (let i = 0; i < texts.length; i++) {
      const text = texts[i];
      const trimmed = typeof text === 'string' ? text.trim() : String(text).trim();
      
      if (trimmed) {
        if (!seenTexts.has(trimmed)) {
          seenTexts.add(trimmed);
          processedTexts.push(trimmed);
        }
        textToIndex.push(processedTexts.indexOf(trimmed));
      } else {
        textToIndex.push(-1); // 空文本标记
      }
    }

    if (processedTexts.length === 0) {
      return texts;
    }

    setIsTranslating(true);
    setError(null);

    try {
      // 1. 先检查本地缓存
      const cachedResults: Map<string, string> = new Map();
      const textsToTranslate: string[] = [];
      const translateIndices: number[] = [];
      
      for (let i = 0; i < processedTexts.length; i++) {
        const text = processedTexts[i];
        const cached = getTranslationCache(text, targetLang, sourceLang);
        if (cached) {
          cachedResults.set(text, cached);
        } else {
          textsToTranslate.push(text);
          translateIndices.push(i);
        }
      }

      // 2. 批量翻译未缓存的文本
      let translatedResults: string[] = [];
      if (textsToTranslate.length > 0) {
        const result = await translateBatch(textsToTranslate, targetLang, sourceLang);
        translatedResults = result.translations.map((t: any) => t.translated_text || t.original_text);
        
        // 保存到本地缓存
        textsToTranslate.forEach((text, idx) => {
          const translated = translatedResults[idx];
          if (translated && translated !== text) {
            setTranslationCache(text, translated, targetLang, sourceLang);
          }
        });
      }

      // 3. 合并缓存和翻译结果
      const allResults: string[] = [];
      let translateIdx = 0;
      
      for (let i = 0; i < processedTexts.length; i++) {
        const text = processedTexts[i];
        if (cachedResults.has(text)) {
          allResults.push(cachedResults.get(text)!);
        } else {
          allResults.push(translatedResults[translateIdx] || text);
          translateIdx++;
        }
      }

      // 4. 根据原始索引映射返回结果（处理重复文本）
      return textToIndex.map(idx => {
        if (idx === -1) return ''; // 空文本
        return allResults[idx];
      });
    } catch (err: any) {
      const errorMsg = err.response?.data?.detail || err.message || '批量翻译失败';
      setError(errorMsg);
      return texts; // 翻译失败时返回原文
    } finally {
      setIsTranslating(false);
    }
  }, []);

  return {
    translate,
    translateBatch: translateBatchTexts,
    isTranslating,
    error
  };
};

