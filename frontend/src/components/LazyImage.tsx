import React, { useState, useRef, useEffect } from 'react';

interface LazyImageProps {
  src: string;
  alt?: string;
  className?: string;
  style?: React.CSSProperties;
  placeholder?: string;
  onError?: () => void;
  onLoad?: () => void;
  // P2 优化：响应式图片支持
  srcSet?: string; // 自定义 srcset（如果不提供，将自动生成）
  sizes?: string; // sizes 属性
  // P2 优化：优先级设置
  fetchPriority?: 'high' | 'low' | 'auto'; // 首图使用 'high'
  // P2 优化：是否为首图
  isFirstImage?: boolean;
}

/**
 * 懒加载图片组件（P2 优化版）
 * 使用 Intersection Observer API 实现图片懒加载
 * 支持 srcset/sizes、WebP/AVIF 格式、fetchpriority
 * 只有当图片进入视口时才加载，大幅提升页面性能
 */
const LazyImage: React.FC<LazyImageProps> = ({
  src,
  alt = '',
  className = '',
  style = {},
  placeholder = 'data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' viewBox=\'0 0 400 300\'%3E%3Crect fill=\'%23f0f0f0\' width=\'400\' height=\'300\'/%3E%3C/svg%3E',
  onError,
  onLoad,
  srcSet,
  sizes,
  fetchPriority,
  isFirstImage = false
}) => {
  const [imageSrc, setImageSrc] = useState(placeholder);
  const [isLoaded, setIsLoaded] = useState(false);
  const [hasError, setHasError] = useState(false);
  const imgRef = useRef<HTMLImageElement>(null);

  // P2 优化：生成响应式 srcset（如果未提供）
  const generateSrcSet = (baseSrc: string): string | undefined => {
    if (srcSet) return srcSet; // 如果提供了自定义 srcset，直接使用
    
    // 自动生成 srcset（假设后端支持不同尺寸）
    // 格式：src?w=400 400w, src?w=800 800w, src?w=1200 1200w
    // 注意：这需要后端支持图片尺寸参数，如果不需要可以返回 undefined
    // 这里提供一个示例实现
    try {
      const url = new URL(baseSrc, window.location.origin);
      const baseUrl = url.origin + url.pathname;
      const params = new URLSearchParams(url.search);
      
      // 生成不同尺寸的 srcset
      const widths = [400, 800, 1200, 1600];
      return widths.map(w => {
        params.set('w', w.toString());
        return `${baseUrl}?${params.toString()} ${w}w`;
      }).join(', ');
    } catch {
      // 如果 URL 解析失败，返回 undefined（使用原始 src）
      return undefined;
    }
  };

  // P2 优化：生成 sizes 属性（如果未提供）
  const generateSizes = (): string => {
    if (sizes) return sizes;
    
    // 默认响应式 sizes
    // 假设图片在不同屏幕尺寸下的显示宽度
    return '(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw';
  };

  // P2 优化：检测浏览器支持的图片格式
  const getBestFormat = (baseSrc: string): string => {
    // 如果后端支持格式协商（通过 Accept 头），浏览器会自动选择
    // 这里我们只处理前端逻辑，格式协商由后端/CDN 处理
    
    // 可以尝试添加 .webp 或 .avif 后缀（如果后端支持）
    // 但更推荐的方式是通过后端/CDN 自动转换
    return baseSrc;
  };

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

  // P2 优化：生成 srcset 和 sizes
  const finalSrcSet = generateSrcSet(src);
  const finalSizes = generateSizes();
  
  // P2 优化：确定 fetchpriority（首图使用 high，其他使用 auto 或 lazy）
  const finalFetchPriority = fetchPriority || (isFirstImage ? 'high' : 'auto');
  
  // P2 优化：首图不使用 lazy loading（立即加载）
  const loadingAttr = isFirstImage ? 'eager' : 'lazy';

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
      // P2 优化：响应式图片支持
      srcSet={finalSrcSet}
      sizes={finalSizes}
      // P2 优化：优先级设置
      fetchPriority={finalFetchPriority}
      // P2 优化：首图立即加载，其他懒加载
      loading={loadingAttr}
      decoding="async"
    />
  );
};

export default LazyImage;

