import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../design/app_spacing.dart';
import '../router/page_transitions.dart';
import '../utils/helpers.dart';
import '../utils/media_saver.dart';

/// 全屏图片查看器 - 类似小红书风格
/// 参考iOS FullScreenImageView.swift
class FullScreenImageView extends StatefulWidget {
  const FullScreenImageView({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.onPageChanged,
    this.allowSaveToAlbum = false,
  });

  /// 图片URL列表
  final List<String> images;

  /// 初始显示的图片索引
  final int initialIndex;

  /// 页面切换回调
  final ValueChanged<int>? onPageChanged;

  /// 是否在右上角显示三点菜单的"保存到相册"项。任务聊天调用方传 true。
  /// 其他调用方默认 false,行为不变(向后兼容)。
  final bool allowSaveToAlbum;

  /// 便捷方法 - 显示全屏图片查看器
  static void show(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
    bool allowSaveToAlbum = false,
  }) {
    pushWithSwipeBack(
      context,
      FullScreenImageView(
        images: images,
        initialIndex: initialIndex,
        allowSaveToAlbum: allowSaveToAlbum,
      ),
    );
  }

  @override
  State<FullScreenImageView> createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  late int _currentIndex;
  late PageController _pageController;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    // 隐藏状态栏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // 恢复状态栏
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  Future<void> _onSaveCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= widget.images.length) return;
    final url = Helpers.getImageUrl(widget.images[_currentIndex]);
    final messenger = ScaffoldMessenger.of(context);
    final result = await MediaSaver.saveImage(url);
    if (!mounted) return;
    switch (result) {
      case SaveResult.success:
        messenger.showSnackBar(const SnackBar(
          content: Text('Saved to album'), // TODO(Task 17): context.l10n.chatSaveSuccess
        ));
        break;
      case SaveResult.permissionDenied:
        messenger.showSnackBar(const SnackBar(
          content: Text('Permission denied'), // TODO(Task 17): context.l10n.chatSavePermissionDenied
        ));
        break;
      case SaveResult.failed:
        messenger.showSnackBar(const SnackBar(
          content: Text('Save failed'), // TODO(Task 17): context.l10n.chatSaveFailed
        ));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 图片轮播
          GestureDetector(
            onTap: _toggleControls,
            // 下滑关闭手势
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! > 300) {
                Navigator.of(context).pop();
              }
            },
            child: PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (context, index) {
                final url = Helpers.getImageUrl(widget.images[index]);
                return PhotoViewGalleryPageOptions(
                  imageProvider: url.isNotEmpty
                      ? CachedNetworkImageProvider(url)
                      : const AssetImage('assets/images/any.png')
                          as ImageProvider,
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  heroAttributes:
                      PhotoViewHeroAttributes(tag: 'image_$index'),
                );
              },
              itemCount: widget.images.length,
              loadingBuilder: (context, event) => Center(
                child: CircularProgressIndicator(
                  value: event == null
                      ? null
                      : event.cumulativeBytesLoaded /
                          (event.expectedTotalBytes ?? 1),
                  color: Colors.white70,
                  strokeWidth: 2,
                ),
              ),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              pageController: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                widget.onPageChanged?.call(index);
              },
            ),
          ),

          // 顶部关闭按钮（始终可见）
          Positioned(
            top: MediaQuery.paddingOf(context).top + AppSpacing.md,
            right: AppSpacing.md,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),

          // 底部图片指示器（多张图片时显示）
          if (widget.images.length > 1 && _showControls)
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 右上角"保存到相册"三点菜单（仅 allowSaveToAlbum=true 且控件可见时显示）
          // 放在关闭按钮左侧避免重叠（关闭按钮 right: 16 + 36 宽 = 占 16~52）
          if (widget.allowSaveToAlbum && _showControls)
            Positioned(
              top: MediaQuery.of(context).padding.top + 4,
              right: 56,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (v) {
                  if (v == 'save') _onSaveCurrent();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'save',
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 20),
                        SizedBox(width: 8),
                        Text('Save to album'), // TODO(Task 17): context.l10n.chatSaveToAlbum
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
