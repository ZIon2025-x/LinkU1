import React, { useState, useRef, useEffect } from 'react';

interface LazyImageProps {
  src: string;
  alt?: string;
  className?: string;
  style?: React.CSSProperties;
  placeholder?: string;
  onError?: () => void;
  onLoad?: () => void;
}

/**
 * 懒加载图片组件
 * 使用 Intersection Observer API 实现图片懒加载
 * 只有当图片进入视口时才加载，大幅提升页面性能
 */
const LazyImage: React.FC<LazyImageProps> = ({
  src,
  alt = '',
  className = '',
  style = {},
  placeholder = 'data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 400 300\'%3E%3Crect fill=\'%23f0f0f0\' width=\'400\' height=\'300\'/%3E%3C/svg%3E',
  onError,
  onLoad
}) => {
  const [imageSrc, setImageSrc] = useState(placeholder);
  const [isLoaded, setIsLoaded] = useState(false);
  const [hasError, setHasError] = useState(false);
  const imgRef = useRef<HTMLImageElement>(null);

  useEffect(() => {
    const img = imgRef.current;
    if (!img) return;

    // 如果图片已经加载过，直接使用
    if (isLoaded && imageSrc === src) {
      return;
    }

    // 使用 Intersection Observer 实现懒加载
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            // 图片进入视口，开始加载
            const imgElement = new Image();
            
            imgElement.onload = () => {
              setImageSrc(src);
              setIsLoaded(true);
              if (onLoad) onLoad();
            };
            
            imgElement.onerror = () => {
              setHasError(true);
              if (onError) onError();
            };
            
            imgElement.src = src;
            
            // 停止观察
            observer.unobserve(img);
          }
        });
      },
      {
        // 提前100px开始加载
        rootMargin: '100px'
      }
    );

    observer.observe(img);

    return () => {
      observer.disconnect();
    };
  }, [src, isLoaded, imageSrc, onLoad, onError]);

  return (
    <img
      ref={imgRef}
      src={imageSrc}
      alt={alt}
      className={className}
      style={{
        ...style,
        transition: 'opacity 0.3s ease-in-out',
        opacity: isLoaded && !hasError ? 1 : 0.7,
        ...(hasError && {
          backgroundColor: '#f0f0f0',
          objectFit: 'cover'
        })
      }}
      loading="lazy"
      decoding="async"
    />
  );
};

export default LazyImage;

