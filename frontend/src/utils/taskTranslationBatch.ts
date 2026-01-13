/**
 * 任务翻译批量加载工具
 * 用于优化任务列表加载时的翻译性能
 */

import { getTaskTranslationsBatch } from '../api';
import { Language } from '../contexts/LanguageContext';

interface TranslationCache {
  [taskId: number]: {
    title?: string;
    description?: string;
  };
}

// 模块级缓存（单例）
let translationCache: TranslationCache = {};
let cacheLanguage: Language | null = null;

/**
 * 批量加载任务翻译
 * @param taskIds 任务ID列表
 * @param language 目标语言
 * @param fieldType 字段类型（可选，默认同时加载title和description）
 */
export async function loadTaskTranslationsBatch(
  taskIds: number[],
  language: Language,
  fieldType?: 'title' | 'description'
): Promise<void> {
  if (!taskIds || taskIds.length === 0) {
    return;
  }

  // 如果语言改变，清空缓存
  if (cacheLanguage !== language) {
    translationCache = {};
    cacheLanguage = language;
  }

  // 过滤出需要加载的任务ID（还没有缓存的）
  const needLoadIds = taskIds.filter(id => {
    if (fieldType) {
      return !translationCache[id]?.[fieldType];
    }
    return !translationCache[id] || !translationCache[id].title || !translationCache[id].description;
  });

  if (needLoadIds.length === 0) {
    return; // 所有翻译都已缓存
  }

  try {
    // 批量加载翻译
    const loadPromises: Promise<void>[] = [];

    if (!fieldType || fieldType === 'title') {
      loadPromises.push(
        getTaskTranslationsBatch(needLoadIds, 'title', language)
          .then(result => {
            Object.entries(result.translations || {}).forEach(([taskIdStr, data]: [string, any]) => {
              const taskId = parseInt(taskIdStr);
              if (!translationCache[taskId]) {
                translationCache[taskId] = {};
              }
              translationCache[taskId].title = data.translated_text;
            });
          })
          .catch(error => {
            console.warn('批量加载任务标题翻译失败:', error);
          })
      );
    }

    if (!fieldType || fieldType === 'description') {
      loadPromises.push(
        getTaskTranslationsBatch(needLoadIds, 'description', language)
          .then(result => {
            Object.entries(result.translations || {}).forEach(([taskIdStr, data]: [string, any]) => {
              const taskId = parseInt(taskIdStr);
              if (!translationCache[taskId]) {
                translationCache[taskId] = {};
              }
              translationCache[taskId].description = data.translated_text;
            });
          })
          .catch(error => {
            console.warn('批量加载任务描述翻译失败:', error);
          })
      );
    }

    await Promise.all(loadPromises);
  } catch (error) {
    console.error('批量加载任务翻译失败:', error);
  }
}

/**
 * 获取任务翻译（从缓存）
 * @param taskId 任务ID
 * @param fieldType 字段类型
 */
export function getCachedTaskTranslation(
  taskId: number,
  fieldType: 'title' | 'description'
): string | null {
  return translationCache[taskId]?.[fieldType] || null;
}

/**
 * 设置任务翻译到缓存
 * @param taskId 任务ID
 * @param fieldType 字段类型
 * @param translatedText 翻译后的文本
 */
export function setCachedTaskTranslation(
  taskId: number,
  fieldType: 'title' | 'description',
  translatedText: string
): void {
  if (!translationCache[taskId]) {
    translationCache[taskId] = {};
  }
  translationCache[taskId][fieldType] = translatedText;
}

/**
 * 清空翻译缓存
 */
export function clearTaskTranslationCache(): void {
  translationCache = {};
  cacheLanguage = null;
}
