import React from 'react';
import { useAutoTranslate } from '../hooks/useAutoTranslate';
import { Language, useLanguage } from '../contexts/LanguageContext';
import { getTaskDisplayTitle } from '../utils/displayLocale';

interface TaskTitleProps {
  title: string;
  language: Language;
  className?: string;
  style?: React.CSSProperties;
  showOriginalButton?: boolean;
  autoTranslate?: boolean;
  taskId?: number;  // 任务ID（可选，如果提供则使用任务翻译持久化）
  /** 任务对象（可选）。若含 title_zh/title_en，则与 iOS 一致优先按语言显示双语字段，不再走自动翻译 */
  task?: { title: string; title_zh?: string | null; title_en?: string | null };
}

/**
 * 任务标题组件 - 优先双语字段（与 iOS 一致），否则支持自动翻译和查看原文
 */
const TaskTitle: React.FC<TaskTitleProps> = ({
  title,
  language,
  className,
  style,
  showOriginalButton = false,
  autoTranslate = true,
  taskId,
  task
}) => {
  const { t } = useLanguage();
  const hasBilingual =
    task &&
    ((task.title_zh != null && String(task.title_zh).trim() !== '') ||
     (task.title_en != null && String(task.title_en).trim() !== ''));
  const effectiveTitle = hasBilingual ? getTaskDisplayTitle(task!, language) : title;

  const { translatedText, isTranslating, showOriginal, toggleOriginal } = useAutoTranslate(
    effectiveTitle,
    language,
    !hasBilingual && autoTranslate,
    taskId,
    'title'
  );

  const displayText = hasBilingual ? effectiveTitle : (translatedText && !showOriginal ? translatedText : title);

  return (
    <div
      style={{
        position: 'relative',
        display: 'flex',
        alignItems: 'flex-start',
        gap: '8px',
        ...style
      }}
      className={className}
    >
      <div style={{ flex: 1, minWidth: 0 }}>
        {displayText}
        {isTranslating && (
          <span style={{ marginLeft: '6px', fontSize: '12px', opacity: 0.6 }}>⏳</span>
        )}
      </div>
      {showOriginalButton && translatedText && !isTranslating && (
        <button
          onClick={(e) => {
            e.stopPropagation();
            e.preventDefault();
            toggleOriginal();
          }}
          style={{
            background: 'transparent',
            border: 'none',
            color: '#6b7280',
            fontSize: '10px',
            padding: '2px 4px',
            cursor: 'pointer',
            whiteSpace: 'nowrap',
            flexShrink: 0,
            opacity: 0.6,
            transition: 'opacity 0.2s',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            minWidth: '18px',
            height: '18px',
            borderRadius: '4px',
            marginLeft: '4px'
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.opacity = '1';
            e.currentTarget.style.background = '#f3f4f6';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.opacity = '0.6';
            e.currentTarget.style.background = 'transparent';
          }}
          title={showOriginal ? t('taskDetail.showTranslation') : t('taskDetail.showOriginal')}
        >
          {showOriginal ? '🌐' : '📄'}
        </button>
      )}
    </div>
  );
};

export default TaskTitle;

