import React, { useState, useEffect } from 'react';
import { Spin } from 'antd';
import { CloseOutlined } from '@ant-design/icons';
import { useLanguage } from '../contexts/LanguageContext';
import { getTaskExpert } from '../api';
import LazyImage from './LazyImage';

interface ExpertDetailModalProps {
  isOpen: boolean;
  onClose: () => void;
  expertId: string;
  onViewServices?: () => void;
}

const ExpertDetailModal: React.FC<ExpertDetailModalProps> = ({
  isOpen,
  onClose,
  expertId,
  onViewServices
}) => {
  const { t } = useLanguage();
  const [expert, setExpert] = useState<any>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (isOpen && expertId) {
      loadExpertDetail();
    } else {
      setExpert(null);
    }
  }, [isOpen, expertId]);

  const loadExpertDetail = async () => {
    setLoading(true);
    try {
      const data = await getTaskExpert(expertId);
      // 确保所有字段都有默认值
      setExpert({
        ...data,
        expert_name: data.expert_name || data.name,
        name: data.name || data.expert_name,
        bio: data.bio || data.bio_en || '',
        bio_en: data.bio_en || data.bio || '',
        location: data.location || null,
        category: data.category || null,
        expertise_areas: data.expertise_areas || [],
        featured_skills: data.featured_skills || [],
        achievements: data.achievements || [],
        avg_rating: data.avg_rating || 0,
        completed_tasks: data.completed_tasks || 0,
        completion_rate: data.completion_rate || 0,
        response_time: data.response_time || null,
        success_rate: data.success_rate !== undefined ? data.success_rate : null,
        is_verified: data.is_verified || false,
        user_level: data.user_level || null
      });
    } catch (err: any) {
          } finally {
      setLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        background: 'rgba(0, 0, 0, 0.6)',
        backdropFilter: 'blur(4px)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 10000,
        padding: '20px'
      }}
      onClick={onClose}
    >
      <div
        style={{
          background: 'rgba(255, 255, 255, 0.1)',
          backdropFilter: 'blur(20px)',
          borderRadius: '24px',
          border: '1px solid rgba(255, 255, 255, 0.2)',
          boxShadow: '0 8px 32px rgba(0, 0, 0, 0.2)',
          maxWidth: '600px',
          width: '100%',
          maxHeight: '90vh',
          overflow: 'auto',
          position: 'relative',
          color: 'white'
        }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* 关闭按钮 */}
        <button
          onClick={onClose}
          style={{
            position: 'absolute',
            top: '16px',
            right: '16px',
            background: 'rgba(255, 255, 255, 0.2)',
            border: 'none',
            borderRadius: '50%',
            width: '32px',
            height: '32px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            color: 'white',
            fontSize: '20px',
            zIndex: 10,
            transition: 'background 0.2s'
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.3)';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.2)';
          }}
        >
          <CloseOutlined />
        </button>

        {loading ? (
          <div style={{ padding: '60px', textAlign: 'center' }}>
            <Spin size="large" />
          </div>
        ) : expert ? (
          <>
            {/* 头部 */}
            <div
              style={{
                padding: '32px 32px 24px',
                borderBottom: '1px solid rgba(255, 255, 255, 0.2)'
              }}
            >
              <h2 style={{ margin: 0, color: 'white', fontSize: '24px', fontWeight: 600 }}>
                {t('taskExperts.expertDetail') || '任务达人详情'}
              </h2>
            </div>

            {/* 内容 */}
            <div style={{ padding: '24px 32px' }}>
              {/* 专家信息 */}
              <div
                style={{
                  display: 'flex',
                  gap: '20px',
                  marginBottom: '32px',
                  paddingBottom: '24px',
                  borderBottom: '1px solid rgba(255, 255, 255, 0.2)'
                }}
              >
                <LazyImage
                  src={expert.avatar || 'https://via.placeholder.com/80'}
                  alt={expert.expert_name || expert.name}
                  width={80}
                  height={80}
                  style={{
                    borderRadius: '50%',
                    objectFit: 'cover',
                    border: '2px solid rgba(255, 255, 255, 0.3)'
                  }}
                />
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '8px', flexWrap: 'wrap' }}>
                    <h3 style={{ margin: 0, color: 'white', fontSize: '20px', fontWeight: 600 }}>
                      {expert.expert_name || expert.name}
                    </h3>
                    {expert.is_verified && (
                      <span style={{
                        background: '#10b981',
                        color: 'white',
                        borderRadius: '50%',
                        width: '20px',
                        height: '20px',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '12px',
                        fontWeight: 'bold'
                      }}>
                        ✓
                      </span>
                    )}
                    {expert.user_level && (
                      <span style={{
                        padding: '4px 10px',
                        background: 'rgba(255, 255, 255, 0.2)',
                        borderRadius: '12px',
                        fontSize: '12px',
                        fontWeight: 600,
                        color: 'white'
                      }}>
                        {expert.user_level === 'super' ? (t('taskExperts.superExpert') || '超级达人') :
                         expert.user_level === 'vip' ? (t('taskExperts.vipExpert') || 'VIP达人') :
                         (t('taskExperts.normalExpert') || '普通达人')}
                      </span>
                    )}
                  </div>
                  <p style={{ margin: '0 0 12px 0', color: 'rgba(255, 255, 255, 0.9)', fontSize: '14px', lineHeight: 1.6 }}>
                    {expert.bio || expert.bio_en || ''}
                  </p>
                  <div style={{ display: 'flex', gap: '16px', fontSize: '14px', color: 'rgba(255,255,255,0.9)', flexWrap: 'wrap', marginBottom: '12px' }}>
                    {expert.avg_rating > 0 && (
                      <span>⭐ {expert.avg_rating.toFixed(1)}</span>
                    )}
                    {expert.completed_tasks !== undefined && (
                      <span>✅ {expert.completed_tasks} {t('taskExperts.tasks') || '任务'}</span>
                    )}
                    {expert.completion_rate !== undefined && (
                      <span>📊 {expert.completion_rate}% {t('taskExperts.completionRate') || '完成率'}</span>
                    )}
                  </div>
                  {/* 城市和分类信息 */}
                  {(expert.location || expert.category) && (
                    <div style={{ display: 'flex', gap: '12px', fontSize: '13px', color: 'rgba(255,255,255,0.8)', flexWrap: 'wrap', marginTop: '8px' }}>
                      {expert.location && (
                        <span>📍 {expert.location}</span>
                      )}
                      {expert.category && (() => {
                        const categoryKey = expert.category.replace(/_([a-z])/g, (_: string, letter: string) => letter.toUpperCase());
                        const categoryLabel = t(`taskExperts.${categoryKey}`) || expert.category;
                        return (
                          <span>💼 {categoryLabel}</span>
                        );
                      })()}
                    </div>
                  )}
                </div>
              </div>

              {/* 专业领域 */}
              {expert.expertise_areas && expert.expertise_areas.length > 0 && (
                <div style={{ marginBottom: '24px' }}>
                  <h4 style={{ margin: '0 0 12px 0', color: 'white', fontSize: '16px', fontWeight: 600 }}>
                    {t('taskExperts.expertiseAreas') || '专业领域'}
                  </h4>
                  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                    {expert.expertise_areas.map((area: string, index: number) => (
                      <span
                        key={index}
                        style={{
                          padding: '6px 12px',
                          background: 'rgba(255, 255, 255, 0.15)',
                          backdropFilter: 'blur(10px)',
                          borderRadius: '8px',
                          fontSize: '13px',
                          color: 'white',
                          border: '1px solid rgba(255, 255, 255, 0.2)'
                        }}
                      >
                        {area}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* 特色技能 */}
              {expert.featured_skills && Array.isArray(expert.featured_skills) && expert.featured_skills.length > 0 && (
                <div style={{ marginBottom: '24px' }}>
                  <h4 style={{ margin: '0 0 12px 0', color: 'white', fontSize: '16px', fontWeight: 600 }}>
                    {t('taskExperts.featuredSkills') || '特色技能'}
                  </h4>
                  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                    {expert.featured_skills.map((skill: string, index: number) => (
                      <span
                        key={index}
                        style={{
                          padding: '6px 12px',
                          background: 'rgba(255, 255, 255, 0.15)',
                          backdropFilter: 'blur(10px)',
                          borderRadius: '8px',
                          fontSize: '13px',
                          color: 'white',
                          border: '1px solid rgba(255, 255, 255, 0.2)'
                        }}
                      >
                        {skill}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* 成就徽章 */}
              {expert.achievements && Array.isArray(expert.achievements) && expert.achievements.length > 0 && (
                <div style={{ marginBottom: '24px' }}>
                  <h4 style={{ margin: '0 0 12px 0', color: 'white', fontSize: '16px', fontWeight: 600 }}>
                    {t('taskExperts.achievements') || '成就徽章'}
                  </h4>
                  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                    {expert.achievements.map((achievement: string, index: number) => (
                      <span
                        key={index}
                        style={{
                          padding: '6px 12px',
                          background: 'rgba(255, 255, 255, 0.15)',
                          backdropFilter: 'blur(10px)',
                          borderRadius: '8px',
                          fontSize: '13px',
                          color: 'white',
                          border: '1px solid rgba(255, 255, 255, 0.2)'
                        }}
                      >
                        {achievement}
                      </span>
                    ))}
                  </div>
                </div>
              )}

              {/* 服务信息 */}
              {(expert.response_time || expert.success_rate !== undefined) && (
                <div>
                  <h4 style={{ margin: '0 0 12px 0', color: 'white', fontSize: '16px', fontWeight: 600 }}>
                    {t('taskExperts.serviceInfo') || '服务信息'}
                  </h4>
                  <div style={{ color: 'rgba(255,255,255,0.9)', fontSize: '14px', lineHeight: 1.8 }}>
                    {expert.response_time && (
                      <div>{t('taskExperts.responseTime') || '响应时间'}：{expert.response_time}</div>
                    )}
                    {expert.success_rate !== undefined && (
                      <div>{t('taskExperts.successRate') || '成功率'}：{expert.success_rate}%</div>
                    )}
                  </div>
                </div>
              )}
            </div>

            {/* 底部按钮 */}
            <div
              style={{
                padding: '20px 32px',
                borderTop: '1px solid rgba(255, 255, 255, 0.2)',
                display: 'flex',
                gap: '12px',
                justifyContent: 'flex-end'
              }}
            >
              <button
                onClick={onClose}
                style={{
                  padding: '10px 24px',
                  background: 'rgba(255, 255, 255, 0.1)',
                  backdropFilter: 'blur(10px)',
                  border: '1px solid rgba(255, 255, 255, 0.2)',
                  borderRadius: '8px',
                  color: 'white',
                  fontSize: '14px',
                  fontWeight: 600,
                  cursor: 'pointer',
                  transition: 'all 0.2s'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = 'rgba(255, 255, 255, 0.2)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = 'rgba(255, 255, 255, 0.1)';
                }}
              >
                {t('common.cancel') || '取消'}
              </button>
              {onViewServices && (
                <button
                  onClick={() => {
                    onClose();
                    onViewServices();
                  }}
                  style={{
                    padding: '10px 24px',
                    background: 'rgba(255, 255, 255, 0.2)',
                    backdropFilter: 'blur(10px)',
                    border: '1px solid rgba(255, 255, 255, 0.3)',
                    borderRadius: '8px',
                    color: 'white',
                    fontSize: '14px',
                    fontWeight: 600,
                    cursor: 'pointer',
                    transition: 'all 0.2s'
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.background = 'rgba(255, 255, 255, 0.3)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.background = 'rgba(255, 255, 255, 0.2)';
                  }}
                >
                  {t('taskExperts.viewServices') || '查看服务列表'}
                </button>
              )}
            </div>
          </>
        ) : (
          <div style={{ padding: '60px', textAlign: 'center', color: 'white' }}>
            {t('taskExperts.expertNotFound') || '达人信息未找到'}
          </div>
        )}
      </div>
    </div>
  );
};

export default ExpertDetailModal;

