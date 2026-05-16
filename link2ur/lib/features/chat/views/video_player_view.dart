import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/router/page_transitions.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/media_saver.dart';

/// 全屏视频播放器 - chewie 包装 video_player
/// 右上角三点菜单提供"保存到相册"功能
class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({
    super.key,
    required this.videoUrl,
    required this.filename,
  });

  final String videoUrl;
  final String filename;

  /// 便捷方法 - push 进入全屏视频播放页(iOS 支持右滑返回)
  static void show(
    BuildContext context, {
    required String videoUrl,
    required String filename,
  }) {
    pushWithSwipeBack(
      context,
      VideoPlayerView(videoUrl: videoUrl, filename: filename),
    );
  }

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        // 整页就是全屏,不需要 chewie 二次全屏
        allowFullScreen: false,
      );
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.error('Video init failed', e);
      if (mounted) {
        setState(() => _initError = 'chat_video_play_failed');
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _onSaveToAlbum() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final localPath = await MediaSaver.downloadToTemp(
        widget.videoUrl,
        widget.filename,
      );
      final result = await MediaSaver.saveVideo(localPath);
      if (!mounted) return;
      switch (result) {
        case SaveResult.success:
          messenger.showSnackBar(
            SnackBar(content: Text(context.l10n.chatSaveSuccess)),
          );
          break;
        case SaveResult.permissionDenied:
          messenger.showSnackBar(
            SnackBar(content: Text(context.l10n.chatSavePermissionDenied)),
          );
          break;
        case SaveResult.failed:
          messenger.showSnackBar(
            SnackBar(content: Text(context.l10n.chatSaveFailed)),
          );
          break;
      }
    } catch (e) {
      AppLogger.error('Save video failed', e);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatSaveFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'save') _onSaveToAlbum();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'save',
                child: Row(
                  children: [
                    const Icon(Icons.download, size: 20),
                    const SizedBox(width: 8),
                    Text(context.l10n.chatSaveToAlbum),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: _initError != null
            ? Text(
                context.localizeError(_initError),
                style: const TextStyle(color: Colors.white),
              )
            : (_chewieController != null
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator()),
      ),
    );
  }
}
