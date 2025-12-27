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
  
  // 分离容器样式和图片样式
  // 如果style中包含position: absolute，说明图片需要绝对定位，应该应用到img而不是容器
  const isAbsolutePositioned = style?.position === 'absolute';
  
  // 图片相关的样式属性（当图片绝对定位时，这些属性应该应用到img而不是容器）
  const imageStyleProps = [
    'position', 'top', 'left', 'right', 'bottom',
    'objectFit', 'objectPosition', 'opacity', 'zIndex',
    'minWidth', 'minHeight', 'maxWidth', 'maxHeight',
    'width', 'height'
  ];
  
  const containerStyle: React.CSSProperties = {
    position: isAbsolutePositioned ? 'relative' : 'relative',
    width: width || '100%',
    height: hasFixedSize ? height : (height || 'auto'),
    overflow: 'hidden',
  };
  
  // 将非图片相关的样式应用到容器
  if (style) {
    Object.keys(style).forEach(key => {
      if (!imageStyleProps.includes(key)) {
        containerStyle[key as keyof React.CSSProperties] = style[key as keyof React.CSSProperties];
      }
    });
  }
  
  // 图片样式：合并传入的图片相关样式和默认样式
  const imgStyle: React.CSSProperties = {
    opacity: isLoaded ? (style?.opacity !== undefined ? style.opacity : 1) : 0,
    transition: 'opacity 0.3s ease-in-out',
    width: isAbsolutePositioned ? (style?.width || '100%') : (width || '100%'),
    height: isAbsolutePositioned ? (style?.height || '100%') : (hasFixedSize ? height : 'auto'),
    maxWidth: style?.maxWidth || '100%',
    maxHeight: style?.maxHeight || (hasFixedSize ? '100%' : 'none'),
    objectFit: (style?.objectFit as any) || 'cover',
    objectPosition: (style?.objectPosition as any) || 'center',
    display: 'block',
  };
  
  // 如果是绝对定位，应用定位相关样式
  if (isAbsolutePositioned) {
    imgStyle.position = 'absolute';
    if (style?.top !== undefined) imgStyle.top = style.top;
    if (style?.left !== undefined) imgStyle.left = style.left;
    if (style?.right !== undefined) imgStyle.right = style.right;
    if (style?.bottom !== undefined) imgStyle.bottom = style.bottom;
    if (style?.zIndex !== undefined) imgStyle.zIndex = style.zIndex;
    if (style?.minWidth !== undefined) imgStyle.minWidth = style.minWidth;
    if (style?.minHeight !== undefined) imgStyle.minHeight = style.minHeight;
  }
  
  return (
    <div 
      ref={imgRef}
      style={containerStyle}
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
          style={imgStyle}
        />
      )}
    </div>
  );
};

export default LazyImage;
