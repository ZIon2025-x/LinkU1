import React, { useState, useEffect } from 'react';

// 图片加载工具函数
const loadImageWithFallback = async (src: string, retryCount = 0): Promise<string> => {
  // 首先尝试使用fetch
  try {
    const response = await fetch(src, {
      method: 'GET',
      credentials: 'include',
      headers: {
        'Accept': 'image/*',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'Connection': 'keep-alive'
      },
      signal: AbortSignal.timeout(10000)
    });
    
    if (response.ok) {
      const blob = await response.blob();
      return URL.createObjectURL(blob);
    }
    
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  } catch (error) {
    console.warn('Fetch失败，尝试XMLHttpRequest:', error);
    
    // 如果fetch失败，使用XMLHttpRequest作为备用
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open('GET', src, true);
      xhr.withCredentials = true;
      xhr.responseType = 'blob';
      xhr.timeout = 10000;
      
      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          const blob = xhr.response;
          const blobUrl = URL.createObjectURL(blob);
          resolve(blobUrl);
        } else {
          reject(new Error(`XHR HTTP ${xhr.status}: ${xhr.statusText}`));
        }
      };
      
      xhr.onerror = () => {
        reject(new Error('XHR网络错误'));
      };
      
      xhr.ontimeout = () => {
        reject(new Error('XHR超时'));
      };
      
      xhr.send();
    });
  }
};

// 私有图片加载组件
interface PrivateImageLoaderProps {
  src: string;
  alt: string;
  style: React.CSSProperties;
  className?: string;
}

const PrivateImageLoader: React.FC<PrivateImageLoaderProps> = ({ 
  src, 
  alt, 
  style, 
  className 
}) => {
  const [imageSrc, setImageSrc] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  useEffect(() => {
    const loadImage = async (retryCount = 0) => {
      try {
        setLoading(true);
        setError(false);
        
        // 图片URL无过期时间，直接加载
        
        // 使用新的图片加载工具函数
        const blobUrl = await loadImageWithFallback(src);
        setImageSrc(blobUrl);
        console.log('图片加载成功:', src);
        
      } catch (err) {
        console.error('图片加载错误:', err, src);
        
        // 如果是网络错误，尝试重试
        if (retryCount < 2) {
          console.log(`图片加载失败，${1000 * (retryCount + 1)}ms后重试...`);
          setTimeout(() => {
            loadImage(retryCount + 1);
          }, 1000 * (retryCount + 1));
          return;
        }
        
        setError(true);
      } finally {
        setLoading(false);
      }
    };

    loadImage();
    
    // 清理blob URL
    return () => {
      if (imageSrc && imageSrc.startsWith('blob:')) {
        URL.revokeObjectURL(imageSrc);
      }
    };
  }, [src]);

  if (loading) {
    return (
      <div 
        className={className}
        style={{
          ...style,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: '#f3f4f6',
          color: '#6b7280'
        }}
      >
        <div style={{ fontSize: '14px' }}>加载中...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div 
        className={className}
        style={{
          ...style,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'linear-gradient(135deg, #f3f4f6, #e5e7eb)',
          color: '#6b7280',
          borderRadius: '8px',
          border: '2px dashed #d1d5db',
          padding: '20px'
        }}
      >
        <div style={{ fontSize: '24px', marginBottom: '8px' }}>📷</div>
        <div style={{ fontWeight: '600', marginBottom: '4px' }}>
          图片加载失败
        </div>
        <div style={{ fontSize: '12px', opacity: 0.7, textAlign: 'center', marginBottom: '8px' }}>
          网络错误或权限问题，请重试
        </div>
        <button onClick={() => window.location.reload()} style={{
          padding: '6px 12px',
          background: '#3b82f6',
          color: 'white',
          border: 'none',
          borderRadius: '6px',
          cursor: 'pointer',
          fontSize: '12px',
          fontWeight: '600'
        }}>刷新页面</button>
      </div>
    );
  }

  return <img src={imageSrc} alt={alt} style={style} className={className} />;
};

export default PrivateImageLoader;
