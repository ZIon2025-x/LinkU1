import React, { useState } from 'react';
import { useLanguage } from '../contexts/LanguageContext';

interface SEOTipsProps {
  taskTitle: string;
  taskDescription: string;
  taskType: string;
  location: string;
  onTitleChange: (title: string) => void;
  onDescriptionChange: (description: string) => void;
}

const SEOTips: React.FC<SEOTipsProps> = ({
  taskTitle,
  taskDescription,
  taskType,
  location,
  onTitleChange,
  onDescriptionChange
}) => {
  const { t } = useLanguage();
  const [showTips, setShowTips] = useState(false);

  // 生成SEO优化建议
  const generateSEOTips = () => {
    const tips = [];
    
    // 标题优化建议
    if (taskTitle.length < 20) {
      tips.push({
        type: 'warning',
        message: t('seo.tips.titleTooShort')
      });
    }
    
    if (!taskTitle.includes(location) && location !== 'Online') {
      tips.push({
        type: 'info',
        message: t('seo.tips.includeLocation').replace('{location}', location)
      });
    }
    
    if (!taskTitle.includes(taskType)) {
      tips.push({
        type: 'info',
        message: t('seo.tips.includeTaskType').replace('{taskType}', taskType)
      });
    }
    
    // 描述优化建议
    if (taskDescription.length < 100) {
      tips.push({
        type: 'warning',
        message: t('seo.tips.descriptionTooShort')
      });
    }
    
    if (!taskDescription.includes(taskType)) {
      tips.push({
        type: 'info',
        message: t('seo.tips.mentionTaskType').replace('{taskType}', taskType)
      });
    }
    
    if (!taskDescription.includes(location) && location !== 'Online') {
      tips.push({
        type: 'info',
        message: t('seo.tips.mentionLocation').replace('{location}', location)
      });
    }
    
    return tips;
  };

  const tips = generateSEOTips();
  const hasWarnings = tips.some(tip => tip.type === 'warning');

  // 生成优化后的标题建议
  const generateOptimizedTitle = () => {
    if (!taskTitle) return '';
    
    let optimized = taskTitle;
    
    // 如果标题不包含地点，添加地点
    if (!optimized.includes(location) && location !== 'Online') {
      optimized = `${optimized} - ${location}`;
    }
    
    // 如果标题不包含任务类型，添加任务类型
    if (!optimized.includes(taskType)) {
      optimized = `${taskType} - ${optimized}`;
    }
    
    return optimized;
  };

  // 生成优化后的描述建议
  const generateOptimizedDescription = () => {
    if (!taskDescription) return '';
    
    let optimized = taskDescription;
    
    // 在描述开头添加地点和类型信息
    if (location !== 'Online' && !optimized.includes(location)) {
      optimized = `在${location}寻找${taskType}服务。${optimized}`;
    }
    
    return optimized;
  };

  return (
    <div style={{ marginBottom: '20px' }}>
      <button
        onClick={() => setShowTips(!showTips)}
        style={{
          background: hasWarnings ? '#fef3c7' : '#e0f2fe',
          border: hasWarnings ? '1px solid #f59e0b' : '1px solid #0ea5e9',
          borderRadius: '8px',
          padding: '12px 16px',
          cursor: 'pointer',
          width: '100%',
          textAlign: 'left',
          fontSize: '14px',
          fontWeight: '600',
          color: hasWarnings ? '#92400e' : '#0c4a6e',
          display: 'flex',
          alignItems: 'center',
          gap: '8px'
        }}
      >
        <span>{hasWarnings ? '⚠️' : '💡'}</span>
        <span>
          {hasWarnings ? t('seo.tips.title') : t('seo.tips.viewTips')}
        </span>
        <span style={{ marginLeft: 'auto' }}>
          {showTips ? '▲' : '▼'}
        </span>
      </button>
      
      {showTips && (
        <div style={{
          background: '#f8fafc',
          border: '1px solid #e2e8f0',
          borderRadius: '8px',
          padding: '16px',
          marginTop: '8px'
        }}>
          <h4 style={{ margin: '0 0 12px 0', color: '#1e293b', fontSize: '16px' }}>
            SEO优化建议
          </h4>
          
          {tips.length > 0 ? (
            <div style={{ marginBottom: '16px' }}>
              {tips.map((tip, index) => (
                <div
                  key={index}
                  style={{
                    padding: '8px 12px',
                    marginBottom: '8px',
                    borderRadius: '6px',
                    fontSize: '14px',
                    background: tip.type === 'warning' ? '#fef3c7' : '#e0f2fe',
                    border: tip.type === 'warning' ? '1px solid #f59e0b' : '1px solid #0ea5e9',
                    color: tip.type === 'warning' ? '#92400e' : '#0c4a6e'
                  }}
                >
                  {tip.message}
                </div>
              ))}
            </div>
          ) : (
            <div style={{
              padding: '8px 12px',
              background: '#d1fae5',
              border: '1px solid #10b981',
              borderRadius: '6px',
              color: '#065f46',
              fontSize: '14px'
            }}>
              ✅ 您的任务描述已经很好了！
            </div>
          )}
          
          <div style={{ marginTop: '16px' }}>
            <h5 style={{ margin: '0 0 8px 0', color: '#374151', fontSize: '14px' }}>
              优化建议：
            </h5>
            
            <div style={{ marginBottom: '12px' }}>
              <label style={{ display: 'block', marginBottom: '4px', fontSize: '12px', color: '#6b7280' }}>
                优化后的标题：
              </label>
              <div style={{
                padding: '8px 12px',
                background: '#fff',
                border: '1px solid #d1d5db',
                borderRadius: '6px',
                fontSize: '14px',
                color: '#374151'
              }}>
                {generateOptimizedTitle() || '请输入任务标题'}
              </div>
              <button
                onClick={() => onTitleChange(generateOptimizedTitle())}
                style={{
                  background: '#3b82f6',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '4px',
                  padding: '4px 8px',
                  fontSize: '12px',
                  cursor: 'pointer',
                  marginTop: '4px'
                }}
              >
                应用建议
              </button>
            </div>
            
            <div>
              <label style={{ display: 'block', marginBottom: '4px', fontSize: '12px', color: '#6b7280' }}>
                优化后的描述：
              </label>
              <div style={{
                padding: '8px 12px',
                background: '#fff',
                border: '1px solid #d1d5db',
                borderRadius: '6px',
                fontSize: '14px',
                color: '#374151',
                maxHeight: '100px',
                overflow: 'auto'
              }}>
                {generateOptimizedDescription() || '请输入任务描述'}
              </div>
              <button
                onClick={() => onDescriptionChange(generateOptimizedDescription())}
                style={{
                  background: '#3b82f6',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '4px',
                  padding: '4px 8px',
                  fontSize: '12px',
                  cursor: 'pointer',
                  marginTop: '4px'
                }}
              >
                应用建议
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default SEOTips;
