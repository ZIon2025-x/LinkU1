/**
 * 图片懒加载组件
 * 使用 Intersection Observer API 实现图片懒加载，提升页面性能
 */
import React, { useState, useRef, useEffect } from 'react';
import { Spin } from 'antd';

interface LazyImageProps {
  src: string;
  alt: string;
  className?: string;
  placeholder?: string;
  width?: number | string;
  height?: number | string;
  style?: React.CSSProperties;
  onLoad?: () => void;
  onError?: (e: React.SyntheticEvent<HTMLImageElement, Event>) => void;
  onClick?: () => void;
  title?: string;
  onMouseEnter?: (e: React.MouseEvent<HTMLElement>) => void;
  onMouseLeave?: (e: React.MouseEvent<HTMLElement>) => void;
  rootMargin?: string; // Intersection Observer 的 rootMargin
}

const LazyImage: React.FC<LazyImageProps> = ({ 
  src, 
  alt, 
  className,
  placeholder = '/placeholder.png',
  width,
  height,
  style,
  onLoad,
  onError,
  onClick,
  title,
  onMouseEnter,
  onMouseLeave,
  rootMargin = '50px'
}) => {
  const [isLoaded, setIsLoaded] = useState(false);
  const [isInView, setIsInView] = useState(false);
  const [hasError, setHasError] = useState(false);
  const imgRef = useRef<HTMLImageElement>(null);

  useEffect(() => {
    // 如果浏览器不支持 Intersection Observer，直接加载图片
    if (!('IntersectionObserver' in window)) {
      setIsInView(true);
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setIsInView(true);
            observer.disconnect();
          }
        });
      },
      { 
        rootMargin,
        threshold: 0.01 // 图片进入视口1%时开始加载
      }
    );

    if (imgRef.current) {
      observer.observe(imgRef.current);
    }

    return () => {
      if (imgRef.current) {
        observer.unobserve(imgRef.current);
      }
      observer.disconnect();
    };
  }, [rootMargin]);

  const handleLoad = () => {
    setIsLoaded(true);
    if (onLoad) {
      onLoad();
    }
  };

  const handleError = (e: React.SyntheticEvent<HTMLImageElement, Event>) => {
    setHasError(true);
    if (onError) {
      onError(e);
    }
  };

  // 如果图片加载失败，显示占位符
  if (hasError && placeholder) {
    return (
      <div
        ref={imgRef}
        style={{
          position: 'relative',
          width: width || '100%',
          height: height || 'auto',
          overflow: 'hidden',
          ...style
        }}
        className={className}
      >
        <img
          src={placeholder}
          alt={alt}
          width={width}
          height={height}
          loading="lazy"
          style={{
            width: '100%',
            height: '100%',
            maxWidth: '100%',
            maxHeight: '100%',
            objectFit: 'cover',
            display: 'block'
          }}
        />
      </div>
    );
  }

  // 判断是否使用固定尺寸（传入了 width 和 height）
  const hasFixedSize = width && height;
  
  return (
    <div 
      ref={imgRef}
      style={{ 
        position: 'relative',
        width: width || '100%',
        height: hasFixedSize ? height : (height || 'auto'),
        overflow: 'hidden',
        ...style
      }}
      className={className}
    >
      {!isInView && (
        <div style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: '#f0f0f0'
        }}>
          <Spin size="small" />
        </div>
      )}
      {isInView && (
        <img
          src={src}
          alt={alt}
          width={width}
          height={height}
          loading="lazy"
          onLoad={handleLoad}
          onError={handleError}
          style={{
            opacity: isLoaded ? 1 : 0,
            transition: 'opacity 0.3s ease-in-out',
            width: '100%',
            height: hasFixedSize ? '100%' : 'auto',
            maxWidth: '100%',
            maxHeight: hasFixedSize ? '100%' : 'none',
            objectFit: 'cover',
            display: 'block'
          }}
        />
      )}
    </div>
  );
};

export default LazyImage;
