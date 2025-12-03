import React, { useState, useEffect } from 'react';
import api from '../../api';

interface PrivateImageDisplayProps {
  imageId: string;
  currentUserId: string;
  style?: React.CSSProperties;
  alt?: string;
}

const PrivateImageDisplay: React.FC<PrivateImageDisplayProps> = ({
  imageId,
  currentUserId,
  style = {},
  alt = "私密图片"
}) => {
  const [imageUrl, setImageUrl] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);
  const [retryCount, setRetryCount] = useState(0);

  const loadImage = async (retry = 0) => {
    try {
      setLoading(true);
      setError(false);
      
      // 生成图片访问URL
      const response = await api.post('/api/messages/generate-image-url', {
        image_id: imageId
      });
      
      if (response.data.success) {
        const { image_url } = response.data;
        
        // 使用fetch加载图片
        const imgResponse = await fetch(image_url, {
          method: 'GET',
          credentials: 'include',
          headers: {
            'Accept': 'image/*',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache'
          }
        });
        
        if (imgResponse.ok) {
          const blob = await imgResponse.blob();
          const blobUrl = URL.createObjectURL(blob);
          setImageUrl(blobUrl);
        } else {
          throw new Error(`HTTP ${imgResponse.status}: ${imgResponse.statusText}`);
        }
      } else {
        throw new Error('生成图片URL失败');
      }
      
    } catch (err) {
            // 如果是网络错误，尝试重试
      if (retry < 2) {
        setTimeout(() => {
          loadImage(retry + 1);
        }, 1000 * (retry + 1));
        return;
      }
      
      setError(true);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (imageId && currentUserId) {
      loadImage();
    }
    
    // 清理blob URL
    return () => {
      if (imageUrl && imageUrl.startsWith('blob:')) {
        URL.revokeObjectURL(imageUrl);
      }
    };
  }, [imageId, currentUserId]);

  if (loading) {
    return (
      <div style={{
        ...style,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: '#f3f4f6',
        color: '#6b7280',
        borderRadius: '8px'
      }}>
        <div style={{ fontSize: '14px' }}>加载中...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div style={{
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
      }}>
        <div style={{ fontSize: '24px', marginBottom: '8px' }}>🔒</div>
        <div style={{ fontWeight: '600', marginBottom: '4px' }}>
          私密图片加载失败
        </div>
        <div style={{ fontSize: '12px', opacity: 0.7, textAlign: 'center', marginBottom: '8px' }}>
          权限不足或网络错误
        </div>
        <button 
          onClick={() => {
            setRetryCount(prev => prev + 1);
            loadImage();
          }}
          style={{
            padding: '6px 12px',
            background: '#3b82f6',
            color: 'white',
            border: 'none',
            borderRadius: '6px',
            cursor: 'pointer',
            fontSize: '12px',
            fontWeight: '600'
          }}
        >
          重试
        </button>
      </div>
    );
  }

  return (
    <img 
      src={imageUrl} 
      alt={alt} 
      style={{
        ...style,
        borderRadius: '8px',
        maxWidth: '100%',
        height: 'auto'
      }}
      onError={() => {
                setError(true);
      }}
    />
  );
};

export default PrivateImageDisplay;
