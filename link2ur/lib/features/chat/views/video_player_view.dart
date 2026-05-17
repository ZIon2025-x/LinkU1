import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/router/page_transitions.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/media_saver.dart';

/// 全屏视频播放器 — video_player + 自定义简洁 controls.
///
/// 设计原则: 任务聊天里看视频是"功能性"用途(快速看清现场/说明),不需要 chewie
/// 或 pod_player 自带的 speed/quality/PIP/captions 等冗余按钮. 自己实现 ~80 行
/// 控件完全可控,只保留:
/// - 中央 play/pause 按钮(单击切换 + 单击空白处显示/隐藏 controls)
/// - 底部进度条(拖动**实时**seek 画面 — 跟 IG/抖音/微信一致)
/// - 底部时间显示 (current / duration)
/// - 右上角三点菜单 → 保存到相册 (AppBar 提供)
///
/// 播放策略: 先 MediaSaver.downloadToTemp 把签名 URL 下载到本地,再 file:// 播 —
/// 绕开 AVPlayer 对 HTTP Range 的挑剔 (backend 不返 206 Partial Content) +
/// 避免 15min 签名 URL 中途过期.
class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({
    super.key,
    required this.videoUrl,
    required this.filename,
  });

  final String videoUrl;
  final String filename;

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
  VideoPlayerController? _controller;
  String? _initError;
  int _retryCount = 0;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _controller?.dispose();
    _controller = null;
    if (mounted) setState(() => _initError = null);

    try {
      final localPath =
          await MediaSaver.downloadToTemp(widget.videoUrl, widget.filename);
      _controller = VideoPlayerController.file(File(localPath));
      await _controller!.initialize();
      _controller!.addListener(_onTick);
      await _controller!.play();
      _retryCount = 0;
      _scheduleHideControls();
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.error(
          'Video init failed (retry=$_retryCount) url=${widget.videoUrl}', e);
      if (mounted) {
        setState(() => _initError = 'chat_video_play_failed');
      }
    }
  }

  void _onTick() {
    // 触发 rebuild 让进度条更新
    if (mounted) setState(() {});
  }

  Future<void> _onRetry() async {
    _retryCount++;
    await _init();
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    _scheduleHideControls();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    // 播放中 3 秒后自动隐藏 controls,暂停时常显
    if (_controller != null && _controller!.value.isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onSaveToAlbum() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
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

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final initialized = c != null && c.value.isInitialized;
    final isPlaying = initialized && c.value.isPlaying;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
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
      body: _initError != null
          ? _buildError()
          : (initialized
              ? _buildPlayer(c, isPlaying)
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
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
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayer(VideoPlayerController c, bool isPlaying) {
    final value = c.value;
    final position = value.position;
    final duration = value.duration;
    final aspect = value.aspectRatio;

    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // 视频内容 — 居中,按视频实际 aspect ratio 显示,不变形
          Center(
            child: AspectRatio(
              aspectRatio: aspect,
              child: VideoPlayer(c),
            ),
          ),
          // 中央播放/暂停按钮 — 暂停时常显, 播放时跟随 _showControls
          if (!isPlaying || _showControls)
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
            ),
          // 底部 controls:进度条 + 时间
          if (_showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.5,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor:
                              Colors.white.withValues(alpha: 0.3),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withValues(alpha: 0.2),
                        ),
                        child: Slider(
                          value: position.inMilliseconds
                              .clamp(0, duration.inMilliseconds)
                              .toDouble(),
                          max: duration.inMilliseconds.toDouble(),
                          onChanged: (v) {
                            // 拖动时**实时** seek 画面 — 跟微信/IG/抖音一致
                            c.seekTo(Duration(milliseconds: v.toInt()));
                          },
                          onChangeStart: (_) {
                            // 拖动期间禁用自动隐藏
                            _hideTimer?.cancel();
                          },
                          onChangeEnd: (_) {
                            _scheduleHideControls();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
