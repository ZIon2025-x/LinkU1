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
/// 设计原则: 任务聊天里看视频是"功能性"用途(快速看清现场/说明),不需要 chewie /
/// pod_player 自带的 speed/quality/PIP/captions 等冗余按钮. 自己实现完全可控的 UI.
///
/// 优化点:
/// - 拖动 thumb 不弹回(_isDragging + _dragValue 优先于 controller position)
/// - 拖动 seekTo 节流 100ms (避免 player 跟不上)
/// - 用 ValueListenableBuilder 只 rebuild 进度/按钮,AppBar 不参与重建
/// - 播放完毕自动暂停回到 0(重播交互)
/// - retry 并发互斥(_isInitializing flag)
/// - 错误路径 controller 一定 dispose 不泄漏
/// - duration=0 (initialize 完成前刹那)时 Slider max fallback 不抛 assert
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
  bool _isInitializing = false; // 防 retry 并发 (#5)
  bool _showControls = true;
  Timer? _hideTimer;

  // 拖动状态 (#1 防 thumb 弹回)
  bool _isDragging = false;
  double? _dragValue;
  // 节流 (#7) — 拖动期间 100ms 内不重复 seekTo
  DateTime _lastSeekTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const _seekThrottleMs = 100;

  // 播放完毕标记 (#4) — 触发显示重播按钮
  bool _hasFinished = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_isInitializing) return; // #5 互斥
    _isInitializing = true;
    try {
      // 清理上一轮(retry 时)
      await _disposeController();
      if (mounted) {
        setState(() {
          _initError = null;
          _hasFinished = false;
        });
      }

      final localPath = await MediaSaver.downloadToTemp(
        widget.videoUrl,
        widget.filename,
      );
      // 异步 await 间 widget 可能已 unmount,提前退出避免泄漏
      if (!mounted) return;

      _controller = VideoPlayerController.file(File(localPath));
      try {
        await _controller!.initialize();
      } catch (e) {
        // #3 initialize 失败时 dispose 已创建的 controller
        await _disposeController();
        rethrow;
      }
      if (!mounted) {
        await _disposeController();
        return;
      }

      _controller!.addListener(_onControllerTick);
      await _controller!.play();
      _retryCount = 0;
      _scheduleHideControls();
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.error(
        'Video init failed (retry=$_retryCount) url=${widget.videoUrl}',
        e,
      );
      if (mounted) setState(() => _initError = 'chat_video_play_failed');
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _disposeController() async {
    final c = _controller;
    _controller = null;
    if (c != null) {
      try {
        c.removeListener(_onControllerTick);
        await c.dispose();
      } catch (e) {
        AppLogger.error('VideoPlayer dispose failed', e);
      }
    }
  }

  /// 只用来检测"播完"事件 — 不调 setState 更新 UI(Slider/时间走 ValueListenableBuilder)
  /// (#2 避免每帧全 widget rebuild)
  void _onControllerTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    final pos = c.value.position;
    // #4 播完自动暂停(回到 0 用户感受为"重播"准备)
    if (!_hasFinished &&
        dur.inMilliseconds > 0 &&
        pos.inMilliseconds >= dur.inMilliseconds - 200 &&
        !c.value.isPlaying) {
      _hasFinished = true;
      // 不 seekTo(0),保留 thumb 在末尾,用户点中央按钮触发 replay
      if (mounted) setState(() {});
    }
  }

  Future<void> _onRetry() async {
    _retryCount++;
    await _init();
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      // 如果是从"播完"状态点开始,先回到 0 再 play
      if (_hasFinished) {
        c.seekTo(Duration.zero);
        _hasFinished = false;
      }
      c.play();
    }
    _scheduleHideControls();
    if (mounted) setState(() {}); // 立即反映按钮图标变化
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    final c = _controller;
    if (c != null && c.value.isPlaying && !_isDragging) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  // ---- Slider 拖动 (#1, #7) ----

  void _onDragStart(double v) {
    _hideTimer?.cancel();
    setState(() {
      _isDragging = true;
      _dragValue = v;
    });
  }

  void _onDragUpdate(double v) {
    // thumb 立即跟手 (本地 state)
    setState(() => _dragValue = v);
    // 节流 seekTo(画面跟着动但不卡)
    final now = DateTime.now();
    if (now.difference(_lastSeekTime).inMilliseconds < _seekThrottleMs) {
      return;
    }
    _lastSeekTime = now;
    _controller?.seekTo(Duration(milliseconds: v.toInt()));
  }

  void _onDragEnd(double v) {
    // 拖动结束,精确 seek 到最终位置
    _controller?.seekTo(Duration(milliseconds: v.toInt()));
    setState(() {
      _isDragging = false;
      _dragValue = null;
      _hasFinished = false; // 拖回视频中间不再算播完
    });
    _scheduleHideControls();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    // dispose 是 sync 但 _disposeController 是 async — fire and forget
    _disposeController();
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
              ? _buildPlayer(c)
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

  Widget _buildPlayer(VideoPlayerController c) {
    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          // 视频内容 — 静态 widget,只渲染 texture,不参与 controller 监听导致的 rebuild
          Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
          // 动态部分(中央按钮 + 底部进度条 + 时间)— 只这部分订阅 controller 变化 (#2)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (context, value, _) {
              final isPlaying = value.isPlaying;
              return Stack(
                children: [
                  // 中央播放/暂停 — 暂停 / 播完 / showControls 时显示
                  if (!isPlaying || _showControls || _hasFinished)
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
                            _hasFinished
                                ? Icons.replay
                                : (isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow),
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                      ),
                    ),
                  // 底部进度条 — _showControls 时显示
                  if (_showControls)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildBottomBar(c, value),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(VideoPlayerController c, VideoPlayerValue value) {
    final duration = value.duration;
    final controllerPos = value.position;
    // (#8) duration 可能为 0(initialize 完成前刹那或某些异常),fallback 1ms 避免 Slider max=0 assert
    final maxMs = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    // (#1) 拖动期间用 _dragValue,否则用 controller position
    final positionMs = _isDragging && _dragValue != null
        ? _dragValue!.clamp(0.0, maxMs)
        : controllerPos.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();
    final displayPosition = _isDragging && _dragValue != null
        ? Duration(milliseconds: _dragValue!.toInt())
        : controllerPos;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
            _formatDuration(displayPosition),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.5,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: positionMs.clamp(0.0, maxMs),
                max: maxMs,
                onChangeStart: _onDragStart,
                onChanged: _onDragUpdate,
                onChangeEnd: _onDragEnd,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(duration),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
