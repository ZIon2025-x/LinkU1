// 响应式样式工具函数
import React from 'react';

export const getResponsiveStyles = (isMobile: boolean) => ({
  modal: {
    maxWidth: isMobile ? '95%' : '900px',
    maxHeight: isMobile ? '95vh' : '90vh',
    borderRadius: isMobile ? '16px' : '24px',
    padding: isMobile ? '16px' : '40px'
  },
  title: {
    fontSize: isMobile ? '20px' : '32px',
    lineHeight: isMobile ? 1.2 : 1.3
  },
  grid: {
    gridTemplateColumns: isMobile ? '1fr' : 'repeat(auto-fit, minmax(200px, 1fr))',
    gap: isMobile ? '12px' : '20px'
  },
  button: {
    width: isMobile ? '100%' : 'auto',
    padding: isMobile ? '12px 24px' : '16px 32px',
    fontSize: isMobile ? '14px' : '16px'
  },
  card: {
    padding: isMobile ? '16px' : '20px',
    borderRadius: isMobile ? '12px' : '16px'
  }
});

// 检测移动设备的hook
export const useIsMobile = () => {
  const [isMobile, setIsMobile] = React.useState(false);

  React.useEffect(() => {
    const checkMobile = () => {
      setIsMobile(window.innerWidth < 768);
    };
    
    checkMobile();
    window.addEventListener('resize', checkMobile);
    return () => window.removeEventListener('resize', checkMobile);
  }, []);

  return isMobile;
};

