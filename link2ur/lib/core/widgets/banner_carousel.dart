import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../router/app_router.dart';

import '../design/app_colors.dart';
import '../utils/helpers.dart';
import 'async_image_view.dart';

/// 横幅轮播组件
/// 参考iOS BannerCarouselView.swift
/// 支持自动轮播、指示器、内部/外部链接跳转
///
/// 字段约定（与后端 & iOS 一致）：
/// - `link_type`: "internal"（应用内路由）或 "external"（外部URL）
/// - `link_url`:  internal 时为路由路径（如 /flea-market、/tasks/123）；
///               external 时为完整 URL（如 https://example.com）
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    required this.banners,
    this.height = 180,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.autoPlay = true,
    this.borderRadius = 12.0,
    this.onBannerTap,
  });

  /// 横幅数据列表
  /// 每个 Map 应包含 'image_url', 'link_type', 'link_url' 等字段
  final List<Map<String, dynamic>> banners;

  /// 轮播高度
  final double height;

  /// 自动播放间隔
  final Duration autoPlayInterval;

  /// 是否自动播放
  final bool autoPlay;

  /// 圆角
  final double borderRadius;

  /// 点击回调
  final void Function(Map<String, dynamic> banner)? onBannerTap;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.autoPlay && widget.banners.length > 1) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (_pageController.hasClients) {
        final nextIndex = (_currentIndex + 1) % widget.banners.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _handleBannerTap(Map<String, dynamic> banner) {
    if (widget.onBannerTap != null) {
      widget.onBannerTap!(banner);
      return;
    }

    final linkType = banner['link_type'] as String?;
    final linkUrl = banner['link_url'] as String?;

    if (linkUrl == null || linkUrl.isEmpty) return;

    if (linkType == 'external') {
      _openExternalUrl(linkUrl);
    } else {
      // internal — linkUrl 是应用内路由路径，对齐 iOS InternalLinkView
      context.safePush(linkUrl);
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          // 轮播图
          ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: PageView.builder(
              controller: _pageController,
              allowImplicitScrolling: true,
              itemCount: widget.banners.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final banner = widget.banners[index];
                final imageUrl = Helpers.getImageUrl(
                  banner['image_url'] as String? ?? '',
                );

                return GestureDetector(
                  onTap: () => _handleBannerTap(banner),
                  child: AsyncImageView(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    placeholder: Container(
                      color: AppColors.skeletonBase,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: Container(
                      color: AppColors.skeletonBase,
                      child: const Icon(Icons.image, size: 40),
                    ),
                  ),
                );
              },
            ),
          ),

          // 页面指示器
          if (widget.banners.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.banners.length, (index) {
                  final isActive = index == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
