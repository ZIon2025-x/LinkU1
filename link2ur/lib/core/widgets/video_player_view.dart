import 'package:flutter/material.dart';

/// 视频播放器组件
/// 参考iOS VideoPlayerView.swift
/// 轻量级视频占位组件，实际播放需集成 video_player 包
class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.autoPlay = false,
    this.loop = false,
    this.muted = false,
    this.borderRadius = 12.0,
    this.showControls = true,
    this.onTap,
  });

  /// 视频URL
  final String videoUrl;

  /// 缩略图URL
  final String? thumbnailUrl;

  /// 宽度
  final double? width;

  /// 高度
  final double? height;

  /// 是否自动播放
  final bool autoPlay;

  /// 是否循环
  final bool loop;

  /// 是否静音
  final bool muted;

  /// 圆角
  final double borderRadius;

  /// 是否显示控制器
  final bool showControls;

  /// 点击回调
  final VoidCallback? onTap;

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        } else {
          setState(() => _isPlaying = !_isPlaying);
        }
      },
      child: Container(
        width: widget.width,
        height: widget.height ?? 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          image: widget.thumbnailUrl != null
              ? DecorationImage(
                  image: NetworkImage(widget.thumbnailUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 无缩略图时的占位
            if (widget.thumbnailUrl == null)
              Icon(
                Icons.videocam,
                size: 48,
                color: Colors.white.withValues(alpha: 0.5),
              ),

            // 播放按钮
            if (widget.showControls && !_isPlaying)
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 36,
                ),
              ),

            // 静音标记
            if (widget.muted && _isPlaying)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volume_off,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

            // 时长指示
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '视频',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
