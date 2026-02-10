import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_assets.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../utils/helpers.dart';

/// 异步图片视图
/// 参考iOS AsyncImageView.swift
class AsyncImageView extends StatelessWidget {
  const AsyncImageView({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 150),
    this.memCacheWidth,
    this.memCacheHeight,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  /// 图片淡入时长，缓存命中时应尽量短以减少感知延迟
  final Duration fadeInDuration;

  /// 内存缓存宽度（像素），设置后解码图片会按此尺寸缩小，显著降低内存占用。
  /// 建议设置为 width * devicePixelRatio 的值。
  final int? memCacheWidth;

  /// 内存缓存高度（像素），设置后解码图片会按此尺寸缩小，显著降低内存占用。
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    final url = Helpers.getImageUrl(imageUrl);
    
    if (url.isEmpty) {
      return _buildPlaceholder(context);
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);

    // 优先使用显式 memCacheWidth/Height；如果 width/height 有限，按 DPR 计算
    final knownCacheWidth = memCacheWidth ??
        (width != null && width!.isFinite ? (width! * dpr).round() : null);
    final knownCacheHeight = memCacheHeight ??
        (height != null && height!.isFinite ? (height! * dpr).round() : null);

    // 如果已经有有效的缓存尺寸，直接构建图片（最常见路径）
    if (knownCacheWidth != null || knownCacheHeight != null) {
      return _buildImage(url, knownCacheWidth, knownCacheHeight);
    }

    // width/height 为 null 或 infinity 时，使用 LayoutBuilder 获取实际约束尺寸
    // 避免全分辨率原图被解码到内存
    return LayoutBuilder(
      builder: (context, constraints) {
        final constraintWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * dpr).round()
            : null;
        final constraintHeight = constraints.maxHeight.isFinite
            ? (constraints.maxHeight * dpr).round()
            : null;
        return _buildImage(url, constraintWidth, constraintHeight);
      },
    );
  }

  Widget _buildImage(String url, int? effectiveMemCacheWidth, int? effectiveMemCacheHeight) {
    Widget image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: fadeInDuration,
      memCacheWidth: effectiveMemCacheWidth,
      memCacheHeight: effectiveMemCacheHeight,
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(context),
      errorWidget: (context, url, error) => errorWidget ?? _buildError(context),
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.skeletonBase,
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: AppColors.textTertiaryLight,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.skeletonBase,
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.textTertiaryLight,
          size: 32,
        ),
      ),
    );
  }
}

/// 头像视图
///
/// 统一头像显示逻辑:
/// - 预设头像 (/static/avatarX.png) → 使用本地 asset（更快、离线可用）
/// - 官方头像 (/static/logo.png, official, system) → 显示 logo
/// - 网络URL (http/https) → CachedNetworkImage 加载
/// - 无头像 → 显示首字母占位符
class AvatarView extends StatelessWidget {
  const AvatarView({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40,
    this.backgroundColor,
    this.isOfficial = false,
  });

  final String? imageUrl;
  final String? name;
  final double size;
  final Color? backgroundColor;
  /// 强制使用官方 logo 头像（用于客服、系统消息等）
  final bool isOfficial;

  @override
  Widget build(BuildContext context) {
    // 1. 官方头像 → 显示 logo
    if (isOfficial || AppAssets.isOfficialAvatar(imageUrl)) {
      return _buildLocalAsset(AppAssets.logo);
    }

    // 2. 预设头像 → 使用本地 asset
    final localAsset = AppAssets.getLocalAvatarAsset(imageUrl);
    if (localAsset != null) {
      return _buildLocalAsset(localAsset);
    }

    // 3. 网络 URL → CachedNetworkImage（按头像实际尺寸缓存，避免缓存全尺寸大图）
    final url = Helpers.getImageUrl(imageUrl);
    if (url.isNotEmpty) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final cacheSize = (size * dpr).round();
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: cacheSize,
          memCacheHeight: cacheSize,
          placeholder: (context, url) => _buildPlaceholder(context),
          errorWidget: (context, url, error) => _buildPlaceholder(context),
        ),
      );
    }

    // 4. 无头像 → 首字母占位符
    return _buildPlaceholder(context);
  }

  Widget _buildLocalAsset(String assetPath) {
    return ClipOval(
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(null),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext? context) {
    final initial = name?.isNotEmpty == true ? name![0].toUpperCase() : '?';
    final bgColor = backgroundColor ?? _getColorFromName(name ?? '');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Color _getColorFromName(String name) {
    if (name.isEmpty) return AppColors.primary;
    final colors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.success,
      AppColors.teal,
      AppColors.purple,
      AppColors.accentPink,
    ];
    final index = name.codeUnitAt(0) % colors.length;
    return colors[index];
  }
}

/// 可点击的图片
class TappableImage extends StatelessWidget {
  const TappableImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.onTap,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AsyncImageView(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        borderRadius: borderRadius ?? AppRadius.allMedium,
      ),
    );
  }
}
