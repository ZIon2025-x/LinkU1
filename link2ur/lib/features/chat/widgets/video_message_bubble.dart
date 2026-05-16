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

  @override
  Widget build(BuildContext context) {
    final thumbUrl = _thumbAtt?.url;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allMedium,
      child: ClipRRect(
        borderRadius: AppRadius.allMedium,
        child: SizedBox(
          width: 200,
          height: 280,
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
