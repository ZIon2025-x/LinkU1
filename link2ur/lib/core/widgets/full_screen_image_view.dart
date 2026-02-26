import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../design/app_spacing.dart';
import '../router/page_transitions.dart';
import '../utils/helpers.dart';

/// 全屏图片查看器 - 类似小红书风格
/// 参考iOS FullScreenImageView.swift
class FullScreenImageView extends StatefulWidget {
  const FullScreenImageView({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.onPageChanged,
  });

  /// 图片URL列表
  final List<String> images;

  /// 初始显示的图片索引
  final int initialIndex;

  /// 页面切换回调
  final ValueChanged<int>? onPageChanged;

  /// 便捷方法 - 显示全屏图片查看器
  static void show(
    BuildContext context, {
    required List<String> images,
    int initialIndex = 0,
  }) {
    pushWithSwipeBack(
      context,
      FullScreenImageView(
        images: images,
        initialIndex: initialIndex,
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
        ],
      ),
    );
  }
}
