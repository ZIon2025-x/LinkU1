import React from 'react';

interface LazyImageProps extends React.ImgHTMLAttributes<HTMLImageElement> {
  src: string; // 基础图片 URL（必须，组件内部会处理格式和响应式）
  alt: string; // 必须
}

/**
 * 懒加载图片组件（优化版）
 * 使用原生 loading="lazy" 和 <picture> 标签实现现代图片格式支持
 * 支持 AVIF/WebP 格式降级，响应式图片，自动懒加载
 */
const LazyImage: React.FC<LazyImageProps> = ({
  src,
  alt,
  className,
  sizes: propSizes,
  ...imgProps
}) => {
  // 提取基础路径（去除扩展名）
  const srcBase = src.replace(/\.(jpg|jpeg|png|webp|avif)$/i, '');
  
  // 使用传入的 sizes 或默认值，避免重复 props
  const sizes = propSizes || "(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw";
  
  return (
    <picture>
      {/* AVIF 格式（最佳压缩） */}
      <source
        srcSet={`
          ${srcBase}.avif?w=400 400w,
          ${srcBase}.avif?w=800 800w,
          ${srcBase}.avif?w=1200 1200w
        `}
        type="image/avif"
        sizes={sizes}
      />
      {/* WebP 格式（次优） */}
      <source
        srcSet={`
          ${srcBase}.webp?w=400 400w,
          ${srcBase}.webp?w=800 800w,
          ${srcBase}.webp?w=1200 1200w
        `}
        type="image/webp"
        sizes={sizes}
      />
      {/* 降级方案：原始格式 */}
      <img
        src={`${srcBase}.jpg`}
        srcSet={`
          ${srcBase}.jpg?w=400 400w,
          ${srcBase}.jpg?w=800 800w,
          ${srcBase}.jpg?w=1200 1200w
        `}
        sizes={sizes}
        loading="lazy"
        decoding="async"
        alt={alt}
        className={className}
        {...imgProps}
      />
    </picture>
  );
};

export default LazyImage;
