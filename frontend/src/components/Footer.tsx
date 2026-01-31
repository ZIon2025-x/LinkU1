import React, { useState } from 'react';
import { useLanguage } from '../contexts/LanguageContext';
import LocalizedLink from './LocalizedLink';
import LazyImage from './LazyImage';

const Footer: React.FC = () => {
  const { t } = useLanguage();
  const [showWechatModal, setShowWechatModal] = useState(false);
  
  return (
    <footer style={{
      background: 'linear-gradient(135deg, #1e3a8a 0%, #1e40af 100%)',
      color: '#fff',
      padding: '60px 0 30px',
      marginTop: '80px'
    }}>
      <div style={{maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
        {/* 上半部分 - 主要内容 */}
        <div className="footer-main-content" style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr 1fr',
          gap: '60px',
          marginBottom: '40px'
        }}>
          {/* 左列 - 品牌信息 */}
          <div className="footer-brand">
            <h3 style={{
              fontSize: '24px',
              fontWeight: '700',
              marginBottom: '20px',
              color: '#fff'
            }}>
              {t('footer.companyName')}
            </h3>
            <p style={{
              fontSize: '16px',
              color: 'rgba(255,255,255,0.8)',
              lineHeight: '1.6',
              marginBottom: '20px'
            }}>
              {t('footer.description')}
            </p>
          </div>
          
          {/* 中列 - 链接导航 */}
          <div className="footer-links" style={{
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: '40px'
          }}>
            <div className="footer-support">
              <h4 style={{
                fontSize: '16px',
                fontWeight: '600',
                marginBottom: '16px',
                color: '#fff'
              }}>
                {t('footer.support')}
              </h4>
              <div style={{display: 'flex', flexDirection: 'column', gap: '12px'}}>
                <LocalizedLink to="/support" style={{
                  color: 'rgba(255,255,255,0.8)',
                  textDecoration: 'none',
                  fontSize: '14px',
                  transition: 'color 0.2s ease'
                }}
                onMouseEnter={(e) => (e.target as HTMLElement).style.color = '#fff'}
                onMouseLeave={(e) => (e.target as HTMLElement).style.color = 'rgba(255,255,255,0.8)'}
                >
                  {t('footer.support')}
                </LocalizedLink>
                <LocalizedLink to="/faq" style={{
                  color: 'rgba(255,255,255,0.8)',
                  textDecoration: 'none',
                  fontSize: '14px',
                  transition: 'color 0.2s ease'
                }}
                onMouseEnter={(e) => (e.target as HTMLElement).style.color = '#fff'}
                onMouseLeave={(e) => (e.target as HTMLElement).style.color = 'rgba(255,255,255,0.8)'}
                >
                  {t('footer.faq')}
                </LocalizedLink>
                <LocalizedLink to="/privacy" style={{
                  color: 'rgba(255,255,255,0.8)',
                  textDecoration: 'none',
                  fontSize: '14px',
                  transition: 'color 0.2s ease'
                }}
                onMouseEnter={(e) => (e.target as HTMLElement).style.color = '#fff'}
                onMouseLeave={(e) => (e.target as HTMLElement).style.color = 'rgba(255,255,255,0.8)'}
                >
                  {t('footer.privacyPolicy')}
                </LocalizedLink>
                <LocalizedLink to="/terms" style={{
                  color: 'rgba(255,255,255,0.8)',
                  textDecoration: 'none',
                  fontSize: '14px',
                  transition: 'color 0.2s ease'
                }}
                onMouseEnter={(e) => (e.target as HTMLElement).style.color = '#fff'}
                onMouseLeave={(e) => (e.target as HTMLElement).style.color = 'rgba(255,255,255,0.8)'}
                >
                  {t('footer.termsOfService')}
                </LocalizedLink>
              </div>
            </div>
            
            <div className="footer-cooperation">
              <h4 style={{
                fontSize: '16px',
                fontWeight: '600',
                marginBottom: '16px',
                color: '#fff'
              }}>
                {t('footer.cooperation')}
              </h4>
              <div style={{display: 'flex', flexDirection: 'column', gap: '12px'}}>
                <LocalizedLink to="/partners" style={{
                  color: 'rgba(255,255,255,0.8)',
                  textDecoration: 'none',
                  fontSize: '14px',
                  transition: 'color 0.2s ease'
                }}
                onMouseEnter={(e) => (e.target as HTMLElement).style.color = '#fff'}
                onMouseLeave={(e) => (e.target as HTMLElement).style.color = 'rgba(255,255,255,0.8)'}
                >
                  {t('footer.partners')}
                </LocalizedLink>
                <LocalizedLink to="/task-experts/intro" style={{
                  color: 'rgba(255,255,255,0.8)',
                  textDecoration: 'none',
                  fontSize: '14px',
                  transition: 'color 0.2s ease'
                }}
                onMouseEnter={(e) => (e.target as HTMLElement).style.color = '#fff'}
                onMouseLeave={(e) => (e.target as HTMLElement).style.color = 'rgba(255,255,255,0.8)'}
                >
                  {t('footer.taskExperts')}
                </LocalizedLink>
                <LocalizedLink to="/merchant-cooperation" style={{
                  color: 'rgba(255,255,255,0.8)',
                  textDecoration: 'none',
                  fontSize: '14px',
                  transition: 'color 0.2s ease'
                }}
                onMouseEnter={(e) => (e.target as HTMLElement).style.color = '#fff'}
                onMouseLeave={(e) => (e.target as HTMLElement).style.color = 'rgba(255,255,255,0.8)'}
                >
                  {t('footer.merchantCooperation')}
                </LocalizedLink>
              </div>
            </div>
          </div>
          
          {/* 右列 - 联系信息和下载 */}
          <div className="footer-contact">
            <h4 style={{
              fontSize: '16px',
              fontWeight: '600',
              marginBottom: '20px',
              color: '#fff'
            }}>
              {t('footer.contactUs')}
            </h4>
            
            <div style={{marginBottom: '24px'}}>
              <p style={{
                fontSize: '14px',
                color: 'rgba(255,255,255,0.8)',
                marginBottom: '8px'
              }}>
                {t('footer.questionsOrSuggestions')}
              </p>
              <a href="mailto:support@link2ur.com" style={{
                color: '#60a5fa',
                textDecoration: 'none',
                fontSize: '14px',
                fontWeight: '500'
              }}>
                support@link2ur.com
              </a>
            </div>
            
            <div style={{marginBottom: '24px'}}>
              <p style={{
                fontSize: '14px',
                color: 'rgba(255,255,255,0.8)',
                marginBottom: '8px'
              }}>
                {t('footer.businessCooperation')}
              </p>
              <a href="mailto:info@link2ur.com" style={{
                color: '#60a5fa',
                textDecoration: 'none',
                fontSize: '14px',
                fontWeight: '500'
              }}>
                info@link2ur.com
              </a>
            </div>
            
            <div style={{marginBottom: '24px'}}>
              <p style={{
                fontSize: '14px',
                color: 'rgba(255,255,255,0.8)',
                marginBottom: '8px'
              }}>
                {t('footer.partnerCooperation')}
              </p>
              <a href="mailto:info@link2ur.com" style={{
                color: '#60a5fa',
                textDecoration: 'none',
                fontSize: '14px',
                fontWeight: '500'
              }}>
                info@link2ur.com
              </a>
            </div>
          </div>
        </div>
        
        {/* 分割线 */}
        <div style={{
          height: '1px',
          background: 'rgba(255,255,255,0.2)',
          margin: '40px 0 30px'
        }} />
        
        {/* 下半部分 - 版权和社交媒体 */}
        <div className="footer-bottom" style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '20px'
        }}>
          {/* 左侧 - Logo和版权 */}
          <div style={{display: 'flex', alignItems: 'center', gap: '12px'}}>
            <LazyImage 
              src="/static/logo.png"
              alt="Link²Ur Logo" 
              style={{
                width: '40px',
                height: '40px',
                objectFit: 'contain'
              }}
            />
            <div>
              <div style={{
                fontSize: '18px',
                fontWeight: '700',
                color: '#fff',
                lineHeight: '1'
              }}>
                Link²Ur
              </div>
              <div style={{
                fontSize: '12px',
                color: 'rgba(255,255,255,0.6)',
                lineHeight: '1'
              }}>
                Platform
              </div>
            </div>
          </div>
          
          {/* 中间 - 版权信息 */}
          <div style={{
            fontSize: '14px',
            color: 'rgba(255,255,255,0.8)',
            textAlign: 'center'
          }}>
            {t('footer.copyrightText')}
          </div>
          
          {/* 右侧 - 社交媒体 */}
          <div className="footer-social" style={{
            display: 'flex',
            gap: '16px',
            alignItems: 'center'
          }}>
            <a href="#" style={{
              width: '32px',
              height: '32px',
              background: 'rgba(255,255,255,0.1)',
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#fff',
              textDecoration: 'none',
              fontSize: '14px',
              fontWeight: 'bold',
              transition: 'all 0.2s ease'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
              e.currentTarget.style.transform = 'scale(1.1)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.1)';
              e.currentTarget.style.transform = 'scale(1)';
            }}
            >
              f
            </a>
            
            <a href="#" style={{
              width: '32px',
              height: '32px',
              background: 'rgba(255,255,255,0.1)',
              borderRadius: '50%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: '#fff',
              textDecoration: 'none',
              fontSize: '14px',
              fontWeight: 'bold',
              transition: 'all 0.2s ease'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
              e.currentTarget.style.transform = 'scale(1.1)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.background = 'rgba(255,255,255,0.1)';
              e.currentTarget.style.transform = 'scale(1)';
            }}
            >
              in
            </a>
            
            <button 
              onClick={() => setShowWechatModal(true)}
              style={{
                width: '32px',
                height: '32px',
                background: 'rgba(255,255,255,0.1)',
                borderRadius: '50%',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                color: '#fff',
                border: 'none',
                cursor: 'pointer',
                fontSize: '14px',
                fontWeight: 'bold',
                transition: 'all 0.2s ease',
                padding: '0'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
                e.currentTarget.style.transform = 'scale(1.1)';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = 'rgba(255,255,255,0.1)';
                e.currentTarget.style.transform = 'scale(1)';
              }}
              title="WeChat"
            >
              <LazyImage 
                src="/static/wechatlogo.png"
                alt="WeChat" 
                style={{
                  width: '20px',
                  height: '20px',
                  objectFit: 'contain'
                }}
                onError={(e: React.SyntheticEvent<HTMLImageElement, Event>) => {
                  // 如果 PNG 加载失败，回退到 WeChat 二维码图
                  const target = e.currentTarget;
                  if (!target.src.includes('wechat.jpg')) {
                    target.src = '/static/wechat.jpg';
                  }
                }}
              />
            </button>
          </div>
        </div>
      </div>
      
      {/* WeChat 二维码弹窗 */}
      {showWechatModal && (
        <div 
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            background: 'rgba(0, 0, 0, 0.7)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 10000,
            animation: 'fadeIn 0.2s ease-in'
          }}
          onClick={() => setShowWechatModal(false)}
        >
          <div 
            style={{
              background: '#fff',
              borderRadius: '12px',
              padding: '24px',
              maxWidth: '400px',
              width: '90%',
              textAlign: 'center',
              animation: 'slideUp 0.3s ease-out',
              position: 'relative',
              boxShadow: '0 20px 60px rgba(0, 0, 0, 0.3)'
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => setShowWechatModal(false)}
              style={{
                position: 'absolute',
                top: '12px',
                right: '12px',
                background: 'none',
                border: 'none',
                fontSize: '24px',
                cursor: 'pointer',
                color: '#666',
                width: '32px',
                height: '32px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                borderRadius: '50%',
                transition: 'all 0.2s ease'
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.background = '#f5f5f5';
                e.currentTarget.style.color = '#333';
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.background = 'none';
                e.currentTarget.style.color = '#666';
              }}
            >
              ×
            </button>
            <h3 style={{
              marginTop: '8px',
              marginBottom: '16px',
              color: '#333',
              fontSize: '20px',
              fontWeight: '600'
            }}>
              添加我们的 WeChat 客服
            </h3>
            <LazyImage 
              src="/static/wechat.jpg"
              alt="WeChat QR code" 
              style={{
                width: '100%',
                maxWidth: '300px',
                height: 'auto',
                borderRadius: '8px',
                border: '1px solid #e0e0e0'
              }}
            />
            <p style={{
              marginTop: '16px',
              color: '#666',
              fontSize: '14px'
            }}>
              Scan to add WeChat
            </p>
          </div>
        </div>
      )}
      
      {/* 移动端响应式样式 */}
      <style>
        {`
          @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
          }
          
          @keyframes slideUp {
            from { 
              opacity: 0;
              transform: translateY(20px);
            }
            to { 
              opacity: 1;
              transform: translateY(0);
            }
          }
          
          /* 移动端适配 */
          @media (max-width: 768px) {
            .footer-main-content {
              grid-template-columns: 1fr !important;
              gap: 40px !important;
              text-align: center;
            }
            
            .footer-links {
              grid-template-columns: 1fr 1fr !important;
              gap: 20px !important;
              text-align: center;
            }
            
            .footer-links > div {
              display: flex !important;
              flex-direction: column !important;
              gap: 8px !important;
            }
            
            .footer-contact {
              text-align: center;
            }
            
            .footer-download {
              text-align: center;
            }
            
            .download-buttons {
              flex-direction: row !important;
              justify-content: center;
              gap: 12px !important;
            }
            
            .download-buttons button {
              flex: 1;
              max-width: 150px;
              font-size: 11px !important;
              padding: 6px 8px !important;
            }
            
            .footer-bottom {
              flex-direction: column !important;
              text-align: center;
              gap: 30px !important;
            }
            
            .footer-social {
              justify-content: center;
              flex-wrap: wrap;
            }
            
            /* 调整内边距 */
            footer {
              padding: 40px 0 20px !important;
            }
            
            /* 调整字体大小 */
            .footer-main-content h3 {
              font-size: 20px !important;
            }
            
            .footer-main-content p {
              font-size: 14px !important;
            }
          }
          
          /* 超小屏幕优化 */
          @media (max-width: 480px) {
            .footer-main-content {
              gap: 30px !important;
            }
            
            .download-buttons {
              flex-direction: column !important;
              gap: 8px !important;
            }
            
            .download-buttons button {
              max-width: none !important;
              width: 100% !important;
            }
            
            .footer-social {
              gap: 12px !important;
            }
            
            .footer-social a {
              width: 28px !important;
              height: 28px !important;
              font-size: 12px !important;
            }
            
            /* 调整容器内边距 */
            footer > div {
              padding: 0 16px !important;
            }
            
            /* 调整分割线 */
            .footer-main-content + div {
              margin: 30px 0 20px !important;
            }
          }
          
          /* 中等屏幕优化 */
          @media (min-width: 769px) and (max-width: 1024px) {
            .footer-main-content {
              grid-template-columns: 1fr 1fr !important;
              gap: 40px !important;
            }
            
            .footer-contact {
              grid-column: 1 / -1;
              margin-top: 20px;
            }
            
            .footer-links {
              grid-template-columns: 1fr 1fr !important;
            }
          }
        `}
      </style>
    </footer>
  );
};

export default Footer;
