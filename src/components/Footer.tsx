import React from 'react';

const Footer: React.FC = () => {
  return (
    <footer style={{
      background: 'linear-gradient(135deg, #1e3a8a 0%, #1e40af 100%)',
      color: '#fff',
      padding: '60px 0 30px',
      marginTop: '80px'
    }}>
      <div style={{maxWidth: 1200, margin: '0 auto', padding: '0 24px'}}>
        {/* 上半部分 - 主要内容 */}
        <div style={{
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
              LinkU Review
            </h3>
            <p style={{
              fontSize: '16px',
              color: 'rgba(255,255,255,0.8)',
              lineHeight: '1.6',
              marginBottom: '20px'
            }}>
              英国留学生互助平台，连接你我，共创美好留学体验
            </p>
          </div>
          
          {/* 中列 - 链接导航 */}
          <div style={{
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
                帮助中心
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
                  隐私政策
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
                  服务条款
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
          <div>
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
              <a href="mailto:feedback@linku.com" style={{
                color: '#60a5fa',
                textDecoration: 'none',
                fontSize: '14px',
                fontWeight: '500'
              }}>
                feedback@linku.com
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
              <a href="mailto:business@linku.com" style={{
                color: '#60a5fa',
                textDecoration: 'none',
                fontSize: '14px',
                fontWeight: '500'
              }}>
                business@linku.com
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
              <a href="mailto:partnership@linku.com" style={{
                color: '#60a5fa',
                textDecoration: 'none',
                fontSize: '14px',
                fontWeight: '500'
              }}>
                partnership@linku.com
              </a>
            </div>
            
            {/* 应用下载按钮 */}
            <div style={{marginTop: '24px'}}>
              <p style={{
                fontSize: '14px',
                color: 'rgba(255,255,255,0.8)',
                marginBottom: '12px'
              }}>
                下载我们的应用
              </p>
              <div style={{display: 'flex', flexDirection: 'column', gap: '8px'}}>
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
        <div style={{
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
                LinkU
              </div>
              <div style={{
                fontSize: '12px',
                color: 'rgba(255,255,255,0.6)',
                lineHeight: '1'
              }}>
                Delivery
              </div>
            </div>
          </div>
          
          {/* 中间 - 版权信息 */}
          <div style={{
            fontSize: '14px',
            color: 'rgba(255,255,255,0.8)',
            textAlign: 'center'
          }}>
            Copyright © 2025 LinkU
          </div>
          
          {/* 右侧 - 社交媒体 */}
          <div style={{
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
    </footer>
  );
};

export default Footer;
