import { useState, useCallback } from 'react';
import { translateText, translateBatch } from '../api';

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

export const useTranslation = (): UseTranslationReturn => {
  const [isTranslating, setIsTranslating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const translate = useCallback(async (
    text: string,
    targetLang: string,
    sourceLang?: string
  ): Promise<string> => {
    if (!text || !text.trim()) {
      return text;
    }

    setIsTranslating(true);
    setError(null);

    try {
      const result = await translateText(text, targetLang, sourceLang);
      return result.translated_text;
    } catch (err: any) {
      const errorMsg = err.response?.data?.detail || err.message || '翻译失败';
      setError(errorMsg);
            return text; // 翻译失败时返回原文
    } finally {
      setIsTranslating(false);
    }
  }, []);

  const translateBatchTexts = useCallback(async (
    texts: string[],
    targetLang: string,
    sourceLang?: string
  ): Promise<string[]> => {
    if (!texts || texts.length === 0) {
      return texts;
    }

    setIsTranslating(true);
    setError(null);

    try {
      const result = await translateBatch(texts, targetLang, sourceLang);
      return result.translations.map((t: any) => t.translated_text || t.original_text);
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

