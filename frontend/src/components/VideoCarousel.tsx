import React, { useState, useRef, useEffect } from 'react';

interface VideoItem {
  src: string;
  poster?: string;
  title: string;
  description: string;
  specialties: string[];
  achievements: string[];
}

interface VideoCarouselProps {
  videos: VideoItem[];
  autoplay?: boolean;
  loop?: boolean;
}

const VideoCarousel: React.FC<VideoCarouselProps> = ({
  videos,
  autoplay = false,
  loop = true
}) => {
  const [currentIndex, setCurrentIndex] = useState(0);
  const videoRefs = useRef<(HTMLVideoElement | null)[]>([]);
  const [isPlaying, setIsPlaying] = useState(false);
  const [videoDimensions, setVideoDimensions] = useState<{ width: number; height: number } | null>(null);

  // 初始化时加载并播放第一个视频
  useEffect(() => {
    const firstVideo = videoRefs.current[0];
    if (firstVideo) {
      firstVideo.load();
      // 延迟播放，确保视频已加载
      const timer = setTimeout(() => {
        firstVideo.play().catch((error) => {
          console.log('Autoplay prevented:', error);
        });
      }, 100);
      return () => clearTimeout(timer);
    }
  }, []);

  // 切换视频时加载并播放新视频（懒加载）
  useEffect(() => {
    const currentVideo = videoRefs.current[currentIndex];
    if (currentVideo) {
      // 如果视频还没有src，设置src（懒加载）
      if (!currentVideo.src) {
        currentVideo.src = videos[currentIndex].src;
      }
      currentVideo.load();
      // 延迟播放，确保视频已加载
      const timer = setTimeout(() => {
        currentVideo.play().catch((error) => {
          console.log('Autoplay prevented:', error);
        });
        // 更新视频尺寸
        if (currentVideo.videoWidth && currentVideo.videoHeight) {
          setVideoDimensions({
            width: currentVideo.videoWidth,
            height: currentVideo.videoHeight
          });
        }
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [currentIndex, videos]);

  const handlePrevious = () => {
    const newIndex = currentIndex === 0 ? videos.length - 1 : currentIndex - 1;
    // 暂停当前视频
    if (videoRefs.current[currentIndex]) {
      videoRefs.current[currentIndex]?.pause();
    }
    setCurrentIndex(newIndex);
    // 播放新视频
    setTimeout(() => {
      if (videoRefs.current[newIndex]) {
        videoRefs.current[newIndex]?.play().catch((error) => {
          console.log('Autoplay prevented:', error);
        });
      }
    }, 50);
  };

  const handleNext = () => {
    const newIndex = currentIndex === videos.length - 1 ? 0 : currentIndex + 1;
    // 暂停当前视频
    if (videoRefs.current[currentIndex]) {
      videoRefs.current[currentIndex]?.pause();
    }
    setCurrentIndex(newIndex);
    // 播放新视频
    setTimeout(() => {
      if (videoRefs.current[newIndex]) {
        videoRefs.current[newIndex]?.play().catch((error) => {
          console.log('Autoplay prevented:', error);
        });
      }
    }, 50);
  };

  const handleVideoPlay = () => {
    setIsPlaying(true);
    // 暂停其他视频
    videoRefs.current.forEach((video, index) => {
      if (video && index !== currentIndex) {
        video.pause();
      }
    });
  };

  const handleVideoPause = () => {
    setIsPlaying(false);
  };

  // 计算容器宽度，根据视频比例自适应
  const containerStyle = videoDimensions 
    ? {
        width: '100%',
        maxWidth: '800px',
        margin: '0 auto',
        aspectRatio: `${videoDimensions.width} / ${videoDimensions.height}`,
        background: '#fff',
        borderRadius: '20px',
        boxShadow: '0 8px 32px rgba(0,0,0,0.12)',
        overflow: 'hidden'
      }
    : {
        width: '100%',
        maxWidth: '800px',
        margin: '0 auto',
        minHeight: '450px',
        background: '#fff',
        borderRadius: '20px',
        boxShadow: '0 8px 32px rgba(0,0,0,0.12)',
        overflow: 'hidden'
      };

  return (
    <div style={containerStyle}>
      {/* 视频容器 */}
      <div style={{
        position: 'relative',
        width: '100%',
        height: '100%',
        background: '#000',
        overflow: 'hidden',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }}>
        {videos.map((video, index) => (
          <div
            key={index}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: '100%',
              display: index === currentIndex ? 'block' : 'none'
            }}
          >
            <video
              ref={(el) => {
                videoRefs.current[index] = el;
              }}
              src={index === currentIndex || index === 0 ? video.src : undefined}
              poster={video.poster}
              loop={false}
              muted={true}
              controls={false}
              playsInline
              autoPlay={true}
              preload={index === 0 ? 'auto' : 'none'}
              style={{
                width: '100%',
                height: '100%',
                objectFit: 'contain',
                pointerEvents: 'none'
              }}
              onPlay={handleVideoPlay}
              onPause={handleVideoPause}
              onEnded={() => {
                // 视频播放完成后自动切换到下一个
                if (index === currentIndex) {
                  const nextIndex = currentIndex === videos.length - 1 ? 0 : currentIndex + 1;
                  setCurrentIndex(nextIndex);
                }
              }}
              onLoadedData={(e) => {
                // 视频加载完成后自动播放并获取尺寸
                const video = e.currentTarget;
                if (index === currentIndex) {
                  setVideoDimensions({
                    width: video.videoWidth,
                    height: video.videoHeight
                  });
                  video.play().catch((error) => {
                    console.log('Autoplay prevented:', error);
                  });
                }
              }}
            />
            
            {/* 文字介绍叠加层 */}
            <div style={{
              position: 'absolute',
              bottom: 0,
              left: 0,
              right: 0,
              background: 'linear-gradient(to top, rgba(0,0,0,0.9) 0%, rgba(0,0,0,0.7) 60%, rgba(0,0,0,0.3) 80%, transparent 100%)',
              padding: '20px 24px',
              color: '#fff',
              zIndex: 5
            }}>
              <h3 style={{
                fontSize: '22px',
                fontWeight: '700',
                marginBottom: '10px',
                display: 'flex',
                alignItems: 'center',
                gap: '10px',
                textShadow: '0 2px 8px rgba(0,0,0,0.8)'
              }}>
                <span style={{ fontSize: '26px' }}>
                  {index === 0 ? '💻' : index === 1 ? '🎨' : index === 2 ? '🍽️' : '🐾'}
                </span>
                {video.title}
              </h3>
              
              <p style={{
                fontSize: '13px',
                lineHeight: '1.6',
                marginBottom: '14px',
                opacity: 0.95,
                textShadow: '0 1px 4px rgba(0,0,0,0.8)'
              }}>
                {video.description}
              </p>

              <div style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))',
                gap: '12px',
                fontSize: '11px'
              }}>
                {/* 特长 */}
                <div>
                  <h4 style={{
                    fontSize: '13px',
                    fontWeight: '600',
                    marginBottom: '6px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '5px',
                    opacity: 0.95,
                    textShadow: '0 1px 3px rgba(0,0,0,0.8)'
                  }}>
                    <span>⭐</span>
                    专业特长
                  </h4>
                  <ul style={{
                    listStyle: 'none',
                    padding: 0,
                    margin: 0,
                    opacity: 0.9
                  }}>
                    {video.specialties.slice(0, 3).map((specialty, i) => (
                      <li key={i} style={{
                        marginBottom: '3px',
                        paddingLeft: '14px',
                        position: 'relative',
                        textShadow: '0 1px 2px rgba(0,0,0,0.8)'
                      }}>
                        <span style={{
                          position: 'absolute',
                          left: 0,
                          color: '#60a5fa'
                        }}>•</span>
                        {specialty}
                      </li>
                    ))}
                  </ul>
                </div>

                {/* 达人要求 */}
                <div>
                  <h4 style={{
                    fontSize: '13px',
                    fontWeight: '600',
                    marginBottom: '6px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '5px',
                    opacity: 0.95,
                    textShadow: '0 1px 3px rgba(0,0,0,0.8)'
                  }}>
                    <span>📋</span>
                    达人要求
                  </h4>
                  <ul style={{
                    listStyle: 'none',
                    padding: 0,
                    margin: 0,
                    opacity: 0.9
                  }}>
                    {video.achievements.slice(0, 3).map((achievement, i) => (
                      <li key={i} style={{
                        marginBottom: '3px',
                        paddingLeft: '14px',
                        position: 'relative',
                        textShadow: '0 1px 2px rgba(0,0,0,0.8)'
                      }}>
                        <span style={{
                          position: 'absolute',
                          left: 0,
                          color: '#34d399'
                        }}>•</span>
                        {achievement}
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            </div>
          </div>
        ))}
        
        {/* 左右切换按钮 */}
        <button
          onClick={handlePrevious}
          style={{
            position: 'absolute',
            left: '16px',
            top: '50%',
            transform: 'translateY(-50%)',
            background: 'rgba(255, 255, 255, 0.9)',
            border: 'none',
            borderRadius: '50%',
            width: '48px',
            height: '48px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            fontSize: '24px',
            color: '#1f2937',
            boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
            transition: 'all 0.3s ease',
            zIndex: 10
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = 'rgba(255, 255, 255, 1)';
            e.currentTarget.style.transform = 'translateY(-50%) scale(1.1)';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.9)';
            e.currentTarget.style.transform = 'translateY(-50%) scale(1)';
          }}
        >
          ‹
        </button>
        
        <button
          onClick={handleNext}
          style={{
            position: 'absolute',
            right: '16px',
            top: '50%',
            transform: 'translateY(-50%)',
            background: 'rgba(255, 255, 255, 0.9)',
            border: 'none',
            borderRadius: '50%',
            width: '48px',
            height: '48px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            fontSize: '24px',
            color: '#1f2937',
            boxShadow: '0 4px 12px rgba(0,0,0,0.15)',
            transition: 'all 0.3s ease',
            zIndex: 10
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = 'rgba(255, 255, 255, 1)';
            e.currentTarget.style.transform = 'translateY(-50%) scale(1.1)';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = 'rgba(255, 255, 255, 0.9)';
            e.currentTarget.style.transform = 'translateY(-50%) scale(1)';
          }}
        >
          ›
        </button>

        {/* 指示器 - 放在文字上方 */}
        <div style={{
          position: 'absolute',
          bottom: '200px',
          left: '50%',
          transform: 'translateX(-50%)',
          display: 'flex',
          gap: '8px',
          zIndex: 15
        }}>
          {videos.map((_, index) => (
            <button
              key={index}
              onClick={() => {
                if (videoRefs.current[currentIndex]) {
                  videoRefs.current[currentIndex]?.pause();
                }
                setCurrentIndex(index);
                // 播放新视频
                setTimeout(() => {
                  if (videoRefs.current[index]) {
                    videoRefs.current[index]?.play().catch((error) => {
                      console.log('Autoplay prevented:', error);
                    });
                  }
                }, 50);
              }}
              style={{
                width: index === currentIndex ? '24px' : '8px',
                height: '8px',
                borderRadius: '4px',
                border: 'none',
                background: index === currentIndex ? '#fff' : 'rgba(255, 255, 255, 0.5)',
                cursor: 'pointer',
                transition: 'all 0.3s ease',
                padding: 0
              }}
            />
          ))}
        </div>
      </div>
    </div>
  );
};

export default VideoCarousel;

