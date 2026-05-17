import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pod_player/pod_player.dart';

import '../../../core/router/page_transitions.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/media_saver.dart';

/// 全屏视频播放器 — pod_player (Instagram Reels 风格,实时 scrub).
///
/// 右上角三点菜单提供"保存到相册"功能.
///
/// 实现策略: 先 MediaSaver.downloadToTemp 把签名 URL 下载到本地,然后用
/// PlayVideoFrom.file 播本地文件 — 绕开 AVPlayer 对 HTTP Range 的挑剔
/// (linktest backend FileResponse 不返 206 Partial Content),同时也避免
/// 15min 签名 URL 在播放中途过期.
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
  PodPlayerController? _controller;
  String? _initError;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 清理上一轮 controller (retry 时不可漏)
    try {
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
    if (mounted) setState(() => _initError = null);

    try {
      // 先下载到 app 临时目录,再用 file:// 播本地 —
      // 绕开 AVPlayer 对 HTTP Range 的挑剔,同时避免 15min 签名 URL 中途过期.
      final localPath =
          await MediaSaver.downloadToTemp(widget.videoUrl, widget.filename);

      _controller = PodPlayerController(
        playVideoFrom: PlayVideoFrom.file(File(localPath)),
        // autoPlay 默认 true, isLooping 默认 false — 用默认配置即可
      );
      await _controller!.initialise();
      _retryCount = 0; // 成功后清零,允许后续无限重试
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.error(
          'Video init failed (retry=$_retryCount) url=${widget.videoUrl}', e);
      if (mounted) {
        setState(() => _initError = 'chat_video_play_failed');
      }
    }
  }

  Future<void> _onRetry() async {
    _retryCount++;
    await _init();
  }

  @override
  void dispose() {
    try {
      _controller?.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _onSaveToAlbum() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 视频已经下载到本地 (在 _init 阶段),直接复用本地路径保存到相册.
      // 但 pod_player 没暴露内部 path,所以重新下载一次 (Dio 缓存可能命中).
      final localPath =
          await MediaSaver.downloadToTemp(widget.videoUrl, widget.filename);
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
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.localizeError(_initError),
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _onRetry,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: Text(
                      context.l10n.commonRetry,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (_retryCount >= 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        context.l10n.chatMediaUrlExpiredHint,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              )
            : (_controller != null
                ? PodVideoPlayer(
                    controller: _controller!,
                    podProgressBarConfig: const PodProgressBarConfig(
                      // 拖动时实时更新画面 (pod_player 默认行为,与 Instagram/IG Reels 一致)
                      circleHandlerColor: Colors.white,
                      playingBarColor: Colors.white,
                      bufferedBarColor: Color(0x55FFFFFF),
                      backgroundColor: Color(0x33FFFFFF),
                    ),
                  )
                : const CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }
}
