import React from 'react';
import { useLanguage } from '../contexts/LanguageContext';

const Footer: React.FC = () => {
  const { t } = useLanguage();
  
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
          <div>
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
            <div>
              <h4 style={{
                fontSize: '16px',
                fontWeight: '600',
                marginBottom: '16px',
                color: '#fff'
              }}>
                {t('footer.support')}
              </h4>
              <div style={{display: 'flex', flexDirection: 'column', gap: '12px'}}>
                <a href="#" style={{
                  color: 'rgba(255,255,255,0.8)',
                  textDecoration: 'none',
                  fontSize: '14px',
                  transition: 'color 0.2s ease'
                }}
                onMouseEnter={(e) => (e.target as HTMLElement).style.color = '#fff'}
                onMouseLeave={(e) => (e.target as HTMLElement).style.color = 'rgba(255,255,255,0.8)'}
                >
                  FAQ
                </a>
                <a href="#" style={{
                  color: 'rgba(255,255,255,0.8)',
                  textDecoration: 'none',
                  fontSize: '14px',
                  transition: 'color 0.2s ease'
                }}
                onMouseEnter={(e) => (e.target as HTMLElement).style.color = '#fff'}
                onMouseLeave={(e) => (e.target as HTMLElement).style.color = 'rgba(255,255,255,0.8)'}
                >
                  {t('footer.privacyPolicy')}
                </a>
                <a href="#" style={{
                  color: 'rgba(255,255,255,0.8)',
                  textDecoration: 'none',
                  fontSize: '14px',
                  transition: 'color 0.2s ease'
                }}
                onMouseEnter={(e) => (e.target as HTMLElement).style.color = '#fff'}
                onMouseLeave={(e) => (e.target as HTMLElement).style.color = 'rgba(255,255,255,0.8)'}
                >
                  {t('footer.termsOfService')}
                </a>
              </div>
            </div>
            
            <div>
              <h4 style={{
                fontSize: '16px',
                fontWeight: '600',
                marginBottom: '16px',
                color: '#fff'
              }}>
                合作伙伴
              </h4>
              <div style={{display: 'flex', flexDirection: 'column', gap: '12px'}}>
                <a href="#" style={{
                  color: 'rgba(255,255,255,0.8)',
                  textDecoration: 'none',
                  fontSize: '14px',
                  transition: 'color 0.2s ease'
                }}
                onMouseEnter={(e) => (e.target as HTMLElement).style.color = '#fff'}
                onMouseLeave={(e) => (e.target as HTMLElement).style.color = 'rgba(255,255,255,0.8)'}
                >
                  合作伙伴
                </a>
                <a href="#" style={{
                  color: 'rgba(255,255,255,0.8)',
                  textDecoration: 'none',
                  fontSize: '14px',
                  transition: 'color 0.2s ease'
                }}
                onMouseEnter={(e) => (e.target as HTMLElement).style.color = '#fff'}
                onMouseLeave={(e) => (e.target as HTMLElement).style.color = 'rgba(255,255,255,0.8)'}
                >
                  任务发布者
                </a>
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
              联系我们
            </h4>
            
            <div style={{marginBottom: '24px'}}>
              <p style={{
                fontSize: '14px',
                color: 'rgba(255,255,255,0.8)',
                marginBottom: '8px'
              }}>
                问题或建议？发送邮件至
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
                商务合作，发送邮件至
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
                合作伙伴，发送邮件至
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
            
            {/* 应用下载按钮 */}
            <div className="footer-download" style={{marginTop: '24px'}}>
              <p style={{
                fontSize: '14px',
                color: 'rgba(255,255,255,0.8)',
                marginBottom: '12px'
              }}>
                下载我们的应用
              </p>
              <div className="download-buttons" style={{display: 'flex', flexDirection: 'column', gap: '8px'}}>
                <button style={{
                  background: 'rgba(255,255,255,0.1)',
                  border: '1px solid rgba(255,255,255,0.2)',
                  borderRadius: '8px',
                  padding: '8px 12px',
                  color: '#fff',
                  fontSize: '12px',
                  fontWeight: '500',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  transition: 'all 0.2s ease'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = 'rgba(255,255,255,0.1)';
                }}
                >
                  <span style={{fontSize: '16px'}}>📱</span>
                  GET IT ON Google Play
                </button>
                
                <button style={{
                  background: 'rgba(255,255,255,0.1)',
                  border: '1px solid rgba(255,255,255,0.2)',
                  borderRadius: '8px',
                  padding: '8px 12px',
                  color: '#fff',
                  fontSize: '12px',
                  fontWeight: '500',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  transition: 'all 0.2s ease'
                }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.background = 'rgba(255,255,255,0.2)';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.background = 'rgba(255,255,255,0.1)';
                }}
                >
                  <span style={{fontSize: '16px'}}>🍎</span>
                  Download on the App Store
                </button>
              </div>
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
            <div style={{
              width: '40px',
              height: '40px',
              background: 'linear-gradient(135deg, #3b82f6, #1d4ed8)',
              borderRadius: '8px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: '20px',
              fontWeight: 'bold',
              color: '#fff'
            }}>
              L
            </div>
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
            Copyright © 2025 Link²Ur
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
              ▶
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
              📷
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
              微
            </a>
          </div>
        </div>
      </div>
      
      {/* 移动端响应式样式 */}
      <style>
        {`
          /* 移动端适配 */
          @media (max-width: 768px) {
            .footer-main-content {
              grid-template-columns: 1fr !important;
              gap: 40px !important;
              text-align: center;
            }
            
            .footer-links {
              grid-template-columns: 1fr !important;
              gap: 30px !important;
              text-align: center;
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
            
            .footer-main-content h4 {
              font-size: 14px !important;
            }
            
            .footer-main-content a {
              font-size: 13px !important;
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
