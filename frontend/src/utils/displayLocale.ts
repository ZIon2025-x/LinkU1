/**
 * 双语显示工具（与 iOS 实现一致）
 * 根据当前语言优先使用 title_zh/title_en、description_zh/description_en 等，
 * 无对应双语字段时回退到 title、description。
 */

export type DisplayLanguage = 'en' | 'zh';

function isZh(lang: DisplayLanguage | string): boolean {
  return String(lang).toLowerCase().startsWith('zh');
}

/** 任务：根据语言取显示标题 */
export function getTaskDisplayTitle(
  task: { title: string; title_zh?: string | null; title_en?: string | null },
  language: DisplayLanguage | string
): string {
  if (isZh(language)) {
    return (task.title_zh && task.title_zh.trim() !== '') ? task.title_zh : task.title;
  }
  return (task.title_en && task.title_en.trim() !== '') ? task.title_en : task.title;
}

/** 任务：根据语言取显示描述 */
export function getTaskDisplayDescription(
  task: { description: string; description_zh?: string | null; description_en?: string | null },
  language: DisplayLanguage | string
): string {
  if (isZh(language)) {
    return (task.description_zh && task.description_zh.trim() !== '') ? task.description_zh : task.description;
  }
  return (task.description_en && task.description_en.trim() !== '') ? task.description_en : task.description;
}

/** 论坛帖子：根据语言取显示标题 */
export function getForumPostDisplayTitle(
  post: { title: string; title_zh?: string | null; title_en?: string | null },
  language: DisplayLanguage | string
): string {
  if (isZh(language)) {
    return (post.title_zh && post.title_zh.trim() !== '') ? post.title_zh : post.title;
  }
  return (post.title_en && post.title_en.trim() !== '') ? post.title_en : post.title;
}

/** 论坛帖子：根据语言取显示内容 */
export function getForumPostDisplayContent(
  post: { content?: string | null; content_zh?: string | null; content_en?: string | null },
  language: DisplayLanguage | string
): string | undefined {
  const base = post.content ?? undefined;
  if (isZh(language)) {
    return (post.content_zh && post.content_zh.trim() !== '') ? post.content_zh : (base ?? undefined);
  }
  return (post.content_en && post.content_en.trim() !== '') ? post.content_en : (base ?? undefined);
}

/** 论坛帖子：根据语言取显示内容预览 */
export function getForumPostDisplayContentPreview(
  post: {
    content_preview?: string | null;
    content_preview_zh?: string | null;
    content_preview_en?: string | null;
  },
  language: DisplayLanguage | string
): string | undefined {
  const base = post.content_preview ?? undefined;
  if (isZh(language)) {
    return (post.content_preview_zh && post.content_preview_zh.trim() !== '')
      ? post.content_preview_zh
      : (base ?? undefined);
  }
  return (post.content_preview_en && post.content_preview_en.trim() !== '')
    ? post.content_preview_en
    : (base ?? undefined);
}

/** 论坛板块：根据语言取显示名称 */
export function getForumCategoryDisplayName(
  category: { name: string; name_zh?: string | null; name_en?: string | null },
  language: DisplayLanguage | string
): string {
  if (isZh(language)) {
    return (category.name_zh && category.name_zh.trim() !== '') ? category.name_zh : category.name;
  }
  return (category.name_en && category.name_en.trim() !== '') ? category.name_en : category.name;
}

/** 论坛板块：根据语言取显示描述 */
export function getForumCategoryDisplayDescription(
  category: {
    description?: string | null;
    description_zh?: string | null;
    description_en?: string | null;
  },
  language: DisplayLanguage | string
): string | undefined {
  const base = category.description ?? undefined;
  if (isZh(language)) {
    return (category.description_zh && category.description_zh.trim() !== '')
      ? category.description_zh
      : (base ?? undefined);
  }
  return (category.description_en && category.description_en.trim() !== '')
    ? category.description_en
    : (base ?? undefined);
}
