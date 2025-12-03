import React, { useRef, useEffect, useState } from 'react';

interface LazyVideoProps {
  src: string;
  poster?: string;
  loop?: boolean;
  muted?: boolean;
  autoplay?: boolean;
  controls?: boolean;
  className?: string;
  style?: React.CSSProperties;
  onLoadStart?: () => void;
  onLoadedData?: () => void;
}

const LazyVideo: React.FC<LazyVideoProps> = ({
  src,
  poster,
  loop = true,
  muted = true,
  autoplay = false,
  controls = true,
  className,
  style,
  onLoadStart,
  onLoadedData
}) => {
  const videoRef = useRef<HTMLVideoElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [isInView, setIsInView] = useState(false);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setIsInView(true);
            // 一旦进入视口，可以开始加载视频
            if (videoRef.current && !isLoaded) {
              videoRef.current.load();
              setIsLoaded(true);
            }
          }
        });
      },
      {
        rootMargin: '50px', // 提前50px开始加载
        threshold: 0.1
      }
    );

    if (containerRef.current) {
      observer.observe(containerRef.current);
    }

    return () => {
      if (containerRef.current) {
        observer.unobserve(containerRef.current);
      }
    };
  }, [isLoaded]);

  useEffect(() => {
    if (isInView && videoRef.current && autoplay) {
      // 延迟播放，确保视频已加载
      const timer = setTimeout(() => {
        videoRef.current?.play().catch((error) => {
                  });
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [isInView, autoplay]);

  return (
    <div
      ref={containerRef}
      className={className}
      style={{
        position: 'relative',
        width: '100%',
        borderRadius: '12px',
        overflow: 'hidden',
        background: '#000',
        ...style
      }}
    >
      <video
        ref={videoRef}
        loop={loop}
        muted={muted}
        controls={controls}
        playsInline
        preload="metadata"
        poster={poster}
        style={{
          width: '100%',
          height: 'auto',
          display: 'block'
        }}
        onLoadStart={onLoadStart}
        onLoadedData={onLoadedData}
      >
        {isInView && <source src={src} type="video/mp4" />}
        您的浏览器不支持视频播放。
      </video>
    </div>
  );
};

export default LazyVideo;

