import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/models/badge.dart';
import '../constants/app_assets.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../utils/helpers.dart';

/// 异步图片视图
/// 参考iOS AsyncImageView.swift
/// 默认 [BoxFit.cover]：等比例缩放并裁剪填满，不拉伸变形；小图标等可用 [BoxFit.contain]。
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
    this.semanticLabel,
    this.fallbackUrl,
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

  /// Semantic label for accessibility.
  final String? semanticLabel;

  /// 备用图片 URL。当 [imageUrl] 加载失败时（如缩略图 404），自动尝试加载此 URL。
  /// 典型用法：imageUrl 传缩略图，fallbackUrl 传原图，兼容没有缩略图的旧图片。
  final String? fallbackUrl;

  @override
  Widget build(BuildContext context) {
    final url = Helpers.getImageUrl(imageUrl);
    
    if (url.isEmpty) {
      return _buildPlaceholder(context);
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);

    // 只约束宽度（不同时约束宽高），让图片解码器自动维持原始宽高比。
    // 同时指定 memCacheWidth + memCacheHeight 在部分设备/图片格式（含EXIF旋转）
    // 下可能导致解码比例错误，渲染时图片被拉伸或压扁。
    final knownCacheWidth = memCacheWidth ??
        (width != null && width!.isFinite ? (width! * dpr).round() : null);

    // 如果已经有有效的缓存宽度，直接构建图片（最常见路径）
    if (knownCacheWidth != null) {
      return _buildImage(url, knownCacheWidth, null);
    }

    // width 为 null 或 infinity 时，使用 LayoutBuilder 获取实际约束宽度
    // 避免全分辨率原图被解码到内存
    return LayoutBuilder(
      builder: (context, constraints) {
        final constraintWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth * dpr).round()
            : null;
        return _buildImage(url, constraintWidth, null);
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
      errorWidget: (context, failedUrl, error) {
        // 如果有 fallbackUrl 且与主 URL 不同，尝试加载 fallback
        final fb = fallbackUrl;
        if (fb != null && fb.isNotEmpty && fb != url) {
          return CachedNetworkImage(
            imageUrl: fb,
            width: width,
            height: height,
            fit: fit,
            fadeInDuration: fadeInDuration,
            memCacheWidth: effectiveMemCacheWidth,
            memCacheHeight: effectiveMemCacheHeight,
            placeholder: (context, url) => placeholder ?? _buildPlaceholder(context),
            errorWidget: (context, url, error) => errorWidget ?? _buildError(context),
          );
        }
        return errorWidget ?? _buildError(context);
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    if (semanticLabel != null) {
      image = Semantics(
        label: semanticLabel,
        image: true,
        child: image,
      );
    }

    return image;
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
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
      width: width ?? double.infinity,
      height: height ?? double.infinity,
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
/// - 匿名用户 → 使用 assets/images/any.png 统一匿名头像（不请求网络）
/// - 官方头像 (/static/logo.png, official, system) → 显示 logo
/// - 预设头像 (/static/avatarX.png) → 使用本地 asset（更快、离线可用）
/// - 网络URL (http/https) → CachedNetworkImage 加载
/// - 无头像 → 显示预设头像 avatar1（对标后端默认值）
class AvatarView extends StatelessWidget {
  const AvatarView({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40,
    this.backgroundColor,
    this.isOfficial = false,
    this.isAnonymous = false,
    this.displayedBadge,
    this.semanticLabel,
  });

  final String? imageUrl;
  final String? name;
  final double size;
  final Color? backgroundColor;
  /// 强制使用官方 logo 头像（用于客服、系统消息等）
  final bool isOfficial;
  /// 匿名用户：使用 assets/images/any.png，不请求网络头像
  final bool isAnonymous;
  /// Optional badge to display as a colored indicator around the avatar.
  /// When present, a small colored dot is shown at the top-right corner.
  final UserBadge? displayedBadge;

  /// Semantic label for accessibility. Falls back to [name] or 'Avatar'.
  final String? semanticLabel;

  /// Maps badge rank to a display color.
  static Color _badgeColor(String? rank) {
    return switch (rank) {
      'gold' => const Color(0xFFFFD700),
      'silver' => const Color(0xFFC0C0C0),
      'bronze' => const Color(0xFFCD7F32),
      _ => AppColors.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final rawAvatar = _buildAvatar(context);
    final avatar = Semantics(
      label: semanticLabel ?? name ?? 'Avatar',
      image: true,
      child: rawAvatar,
    );
    if (displayedBadge == null) return avatar;

    // Wrap with a small colored dot indicator at top-right
    final dotSize = (size * 0.22).clamp(8.0, 16.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: _badgeColor(displayedBadge!.rank),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    // 1. 匿名用户 → 统一匿名头像 any.png
    if (isAnonymous) {
      return _buildLocalAsset(AppAssets.any);
    }

    // 2. 官方头像 → 显示 logo
    if (isOfficial || AppAssets.isOfficialAvatar(imageUrl)) {
      return _buildLocalAsset(AppAssets.logo);
    }

    // 3. 预设头像 → 使用本地 asset
    final localAsset = AppAssets.getLocalAvatarAsset(imageUrl);
    if (localAsset != null) {
      return _buildLocalAsset(localAsset);
    }

    // 4. 网络 URL → CachedNetworkImage（按头像实际尺寸缓存，避免缓存全尺寸大图）
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
          placeholder: (context, url) => _buildPlaceholder(context),
          errorWidget: (context, url, error) => _buildPlaceholder(context),
        ),
      );
    }

    // 5. 无头像 → 显示预设头像 avatar1（对标后端默认值）
    return _buildLocalAsset(AppAssets.avatar1);
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
    this.semanticLabel,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? 'Image',
      child: GestureDetector(
        onTap: onTap,
        child: AsyncImageView(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: fit,
          borderRadius: borderRadius ?? AppRadius.allMedium,
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}
