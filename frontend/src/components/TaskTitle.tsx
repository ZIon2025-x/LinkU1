import React from 'react';
import { useAutoTranslate } from '../hooks/useAutoTranslate';
import { Language, useLanguage } from '../contexts/LanguageContext';

interface TaskTitleProps {
  title: string;
  language: Language;
  className?: string;
  style?: React.CSSProperties;
  showOriginalButton?: boolean;
  autoTranslate?: boolean;
  taskId?: number;  // 任务ID（可选，如果提供则使用任务翻译持久化）
}

/**
 * 任务标题组件 - 支持自动翻译和查看原文
 */
const TaskTitle: React.FC<TaskTitleProps> = ({
  title,
  language,
  className,
  style,
  showOriginalButton = false,  // 默认不显示按钮，任务卡片上不需要
  autoTranslate = true,  // 自动翻译，但会检测文本语言，只在需要时翻译
  taskId  // 任务ID（可选，如果提供则使用任务翻译持久化）
}) => {
  const { t } = useLanguage();
  const { translatedText, isTranslating, showOriginal, toggleOriginal } = useAutoTranslate(
    title,
    language,
    autoTranslate,
    taskId,  // 传递 taskId
    'title'  // 字段类型为 title
  );

  // 显示的文字：如果有翻译且不显示原文，则显示翻译；否则显示原文
  const displayText = translatedText && !showOriginal ? translatedText : title;

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

