import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/design/app_radius.dart';
import '../../../data/models/message.dart';

/// 视频消息气泡 — 缩略图 + 时长徽章 + 中央播放按钮。
/// 点击行为由 caller 决定(本任务不实现,Task 15 接入 VideoPlayerView)。
class VideoMessageBubble extends StatelessWidget {
  const VideoMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onTap,
  });

  final Message message;
  final bool isMine;
  final VoidCallback? onTap;

  MessageAttachment? get _videoAtt {
    for (final a in message.attachments) {
      if (a.attachmentType == 'video') return a;
    }
    return null;
  }

  MessageAttachment? get _thumbAtt {
    for (final a in message.attachments) {
      if (a.attachmentType == 'image' && (a.meta?['role'] == 'thumbnail')) {
        return a;
      }
    }
    return null;
  }

  String get _durationLabel {
    final s = _videoAtt?.meta?['duration'];
    if (s is num && s > 0) {
      final secs = s.toInt();
      final mm = (secs ~/ 60).toString().padLeft(1, '0');
      final ss = (secs % 60).toString().padLeft(2, '0');
      return '$mm:$ss';
    }
    return '';
  }

  /// 视频实际宽高比(video.meta.width/height),fallback 9:16 竖屏(手机录像)。
  double get _aspectRatio {
    final w = _videoAtt?.meta?['width'];
    final h = _videoAtt?.meta?['height'];
    if (w is num && h is num && w > 0 && h > 0) {
      return w / h;
    }
    return 9 / 16; // 默认竖屏
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = _thumbAtt?.url;

    // 自适应:气泡宽度 = min(屏宽 * 0.55, 240) 让 iPhone SE / iPad 都合理;
    // 高度按视频实际比例算,横屏视频不会被强拉成竖屏(避免黑边或变形)。
    // 比例上下限:0.5(高瘦) ~ 1.78(16:9 横屏),超出按 1.0 (方形) 退避。
    final screenW = MediaQuery.of(context).size.width;
    final width = (screenW * 0.55).clamp(160.0, 240.0);
    final aspect = _aspectRatio.clamp(0.5, 1.78);
    final height = width / aspect;
    // 高度上限避免横屏视频在窄屏被算得超长 / 竖屏视频太高
    final clampedHeight = height.clamp(140.0, 320.0);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allMedium,
      child: ClipRRect(
        borderRadius: AppRadius.allMedium,
        child: SizedBox(
          width: width,
          height: clampedHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black),
              if (thumbUrl != null && thumbUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: thumbUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const ColoredBox(color: Colors.black12),
                  errorWidget: (_, __, ___) => const ColoredBox(color: Colors.black),
                ),
              // 半透明深色覆盖,让播放按钮更显眼
              Container(color: Colors.black.withValues(alpha: 0.15)),
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 64,
                ),
              ),
              if (_durationLabel.isNotEmpty)
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _durationLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
