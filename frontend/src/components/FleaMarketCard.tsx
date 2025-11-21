import React from 'react';
import { useNavigate } from 'react-router-dom';
import { useLanguage } from '../contexts/LanguageContext';
import styles from './FleaMarketCard.module.css';

interface FleaMarketCardProps {
  isMobile: boolean;
}

const FleaMarketCard: React.FC<FleaMarketCardProps> = ({ isMobile }) => {
  const { t, language } = useLanguage();
  const navigate = useNavigate();

  const handleClick = () => {
    navigate(`/${language}/flea-market`);
  };

  return (
    <div
      className={`${styles.fleaMarketCard} ${isMobile ? styles.fleaMarketCardMobile : ''}`}
      onClick={handleClick}
    >
      {/* 图片区域 */}
      <div 
        className={`${styles.imageContainer} ${isMobile ? styles.imageContainerMobile : ''}`}
        style={{
          background: 'linear-gradient(135deg, #10b98120, #10b98140)'
        }}
      >
        {/* 视频背景 - 显示中下部分 */}
        <video
          autoPlay
          loop
          muted
          playsInline
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            width: '100%',
            height: '100%',
            objectFit: 'cover',  // 覆盖模式
            objectPosition: '50% 70%',  // 显示中下部分，稍微上移
            zIndex: 1,
            pointerEvents: 'none'
          }}
          onError={() => {
            // 如果视频加载失败，显示占位符
            const placeholder = document.querySelector('.flea-market-placeholder') as HTMLElement;
            if (placeholder) {
              placeholder.style.display = 'flex';
            }
          }}
        >
          <source src="/static/flea.mp4" type="video/mp4" />
        </video>
        
        {/* 图标占位符（作为后备，仅在视频加载失败时显示） */}
        <div 
          className="flea-market-placeholder"
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            width: '100%',
            height: '100%',
            display: 'none',  // 默认隐藏
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 0,
            pointerEvents: 'none',
            opacity: 0.3
          }}>
          <div style={{
            fontSize: isMobile ? '48px' : '64px',
            opacity: 0.6,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}>
            🛍️
          </div>
        </div>

        {/* 图片遮罩层 */}
        <div style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'linear-gradient(to bottom, rgba(0,0,0,0.3) 0%, rgba(0,0,0,0.1) 50%, rgba(0,0,0,0.5) 100%)',
          zIndex: 2,
          pointerEvents: 'none'
        }} />

        {/* 任务类型 - 右上角 */}
        <div style={{
          position: 'absolute',
          top: isMobile ? '8px' : '12px',
          right: isMobile ? '8px' : '12px',
          background: 'rgba(16, 185, 129, 0.9)',
          backdropFilter: 'blur(4px)',
          color: '#fff',
          padding: isMobile ? '4px 8px' : '6px 12px',
          borderRadius: '20px',
          fontSize: isMobile ? '10px' : '12px',
          fontWeight: '600',
          display: 'flex',
          alignItems: 'center',
          gap: '4px',
          zIndex: 3,
          boxShadow: '0 2px 8px rgba(16, 185, 129, 0.4)'
        }}>
          <span>🏷️</span>
          <span>{t('fleaMarket.cardTitle')}</span>
        </div>

        {/* 特殊标识 - 左下角 */}
        <div style={{
          position: 'absolute',
          bottom: isMobile ? '8px' : '12px',
          left: isMobile ? '8px' : '12px',
          background: 'rgba(16, 185, 129, 0.9)',
          backdropFilter: 'blur(4px)',
          color: '#fff',
          padding: isMobile ? '4px 8px' : '6px 12px',
          borderRadius: '20px',
          fontSize: isMobile ? '9px' : '11px',
          fontWeight: '600',
          display: 'flex',
          alignItems: 'center',
          gap: '4px',
          zIndex: 3,
          boxShadow: '0 2px 8px rgba(16, 185, 129, 0.4)'
        }}>
          <span>✨</span>
          <span>{t('fleaMarket.specialBadge')}</span>
        </div>
      </div>
      
      {/* 标题 */}
      <div className={`${styles.cardTitle} ${isMobile ? styles.cardTitleMobile : styles.cardTitleDesktop}`}>
        {t('fleaMarket.cardTitle')}
      </div>
      
      {/* 描述 */}
      <div className={`${styles.cardDescription} ${isMobile ? styles.cardDescriptionMobile : styles.cardDescriptionDesktop}`}>
        {t('fleaMarket.cardDescription')}
      </div>
    </div>
  );
};

export default FleaMarketCard;

