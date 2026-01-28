/**
 * 图片懒加载组件
 * 使用 Intersection Observer API 实现图片懒加载，提升页面性能
 */
import React, { useState, useRef, useEffect, useMemo } from 'react';
import { Spin } from 'antd';
import { formatImageUrl } from '../utils/imageUtils';

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
  srcSet?: string; // 响应式图片源集合
  sizes?: string; // 响应式图片尺寸
  fetchPriority?: 'high' | 'low' | 'auto'; // 图片加载优先级
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
  rootMargin = '50px',
  srcSet,
  sizes,
  fetchPriority = 'auto'
}) => {
  const [isLoaded, setIsLoaded] = useState(false);
  const [isInView, setIsInView] = useState(false);
  const [hasError, setHasError] = useState(false);
  const imgRef = useRef<HTMLImageElement>(null);

  // 先将后端返回的相对路径（如 public/...、flea_market/...）转为可用的 /uploads/... 等
  const resolvedSrc = formatImageUrl(src);

  // 优化图片 URL：尝试使用 WebP 格式（如果浏览器支持）
  const optimizedSrc = useMemo(() => {
    if (!resolvedSrc) return resolvedSrc;
    
    // 如果已经指定了 srcSet，直接返回原 src
    if (srcSet) return resolvedSrc;
    
    // 检查浏览器是否支持 WebP
    const supportsWebP = () => {
      const canvas = document.createElement('canvas');
      canvas.width = 1;
      canvas.height = 1;
      return canvas.toDataURL('image/webp').indexOf('data:image/webp') === 0;
    };
    
    // 如果浏览器支持 WebP 且原图不是 WebP，尝试使用 WebP 版本
    if (supportsWebP() && !resolvedSrc.toLowerCase().endsWith('.webp')) {
      // 尝试将 .jpg/.jpeg/.png 替换为 .webp
      const webpSrc = resolvedSrc.replace(/\.(jpg|jpeg|png)$/i, '.webp');
      // 注意：这里假设服务器支持 WebP，实际使用时需要确保服务器确实提供 WebP 版本
      // 如果服务器不支持，图片加载会失败并回退到原图
      return webpSrc;
    }
    
    return resolvedSrc;
  }, [resolvedSrc, srcSet]);

  useEffect(() => {
    // 如果图片是绝对定位的，直接加载（因为绝对定位的图片通常需要立即显示）
    const isAbsolutePositioned = style?.position === 'absolute';
    if (isAbsolutePositioned) {
      setIsInView(true);
      return;
    }
    
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
  }, [rootMargin, style?.position]);

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
  
  // 构建容器样式，排除图片相关的样式属性
  // 当图片绝对定位时，容器应该填充父容器（100%宽高），并保持relative作为定位上下文
  // 如果 style 中有 width 和 height，优先使用它们来保持容器的宽高比（特别是对于圆形头像）
  const containerWidth = isAbsolutePositioned 
    ? '100%' 
    : (style?.width || width || '100%');
  const containerHeight = isAbsolutePositioned 
    ? '100%' 
    : (style?.height || (hasFixedSize ? height : (height || 'auto')));
  
  const containerStyle: React.CSSProperties = {
    position: 'relative',
    width: containerWidth,
    height: containerHeight,
    overflow: 'hidden',
    // 关键修复：确保容器不会超出父容器
    maxWidth: '100%',
    maxHeight: '100%',
    // 防止在 flex/grid 中被大图撑开（与 iOS Color.clear+overlay 同理）
    minWidth: 0,
    minHeight: 0,
    // 如果 style 中有 borderRadius，应用到容器以保持圆形
    borderRadius: style?.borderRadius || undefined,
  };
  
  // 将非图片相关的样式应用到容器（但排除已经在上面处理的属性）
  if (style) {
    const styleKeys = Object.keys(style) as Array<keyof React.CSSProperties>;
    styleKeys.forEach(key => {
      // 排除图片相关的样式属性，以及已经手动设置的属性
      if (!imageStyleProps.includes(key as string) && 
          key !== 'borderRadius' && 
          key !== 'width' && 
          key !== 'height') {
        const value = style[key];
        if (value !== undefined) {
          (containerStyle as any)[key] = value;
        }
      }
    });
  }
  
  // 图片样式：合并传入的图片相关样式和默认样式
  // 优先使用 style 中的 width/height，然后是 props 中的 width/height，最后是默认值
  // 对于圆形头像，图片应该填充整个容器
  const imgStyle: React.CSSProperties = {
    opacity: isLoaded ? (style?.opacity !== undefined ? style.opacity : 1) : 0,
    transition: 'opacity 0.3s ease-in-out',
    width: isAbsolutePositioned 
      ? (style?.width || '100%') 
      : '100%', // 图片填充容器宽度
    height: isAbsolutePositioned 
      ? (style?.height || '100%') 
      : '100%', // 图片填充容器高度
    maxWidth: '100%',
    maxHeight: '100%',
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
          src={optimizedSrc}
          alt={alt}
          width={width}
          height={height}
          srcSet={srcSet}
          sizes={sizes}
          loading="lazy"
          fetchPriority={fetchPriority}
          onLoad={handleLoad}
          onError={(e) => {
            // 如果 WebP 加载失败，回退到原图（使用 resolvedSrc，已处理相对路径）
            if (optimizedSrc !== resolvedSrc && (e.currentTarget.src === optimizedSrc)) {
              e.currentTarget.src = resolvedSrc;
              return;
            }
            handleError(e);
          }}
          style={imgStyle}
        />
      )}
    </div>
  );
};

export default LazyImage;
