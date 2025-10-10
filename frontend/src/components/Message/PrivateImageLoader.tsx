import React, { useState, useEffect } from 'react';
import { loadImageWithHttp1 } from '../../utils/httpUtils';

// 图片加载工具函数
const loadImageWithFallback = async (src: string, retryCount = 0): Promise<string> => {
  try {
    return await loadImageWithHttp1(src);
  } catch (error) {
    console.warn('图片加载失败，尝试重试:', error);
    
    // 如果是网络错误，尝试重试
    if (retryCount < 2) {
      console.log(`图片加载失败，${1000 * (retryCount + 1)}ms后重试...`);
      await new Promise(resolve => setTimeout(resolve, 1000 * (retryCount + 1)));
      return loadImageWithFallback(src, retryCount + 1);
    }
    
    throw error;
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
