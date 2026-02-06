import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    this.fadeInDuration = const Duration(milliseconds: 300),
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;

  @override
  Widget build(BuildContext context) {
    final url = Helpers.getImageUrl(imageUrl);
    
    if (url.isEmpty) {
      return _buildPlaceholder(context);
    }

    Widget image = CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: fadeInDuration,
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
class AvatarView extends StatelessWidget {
  const AvatarView({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40,
    this.backgroundColor,
  });

  final String? imageUrl;
  final String? name;
  final double size;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final url = Helpers.getImageUrl(imageUrl);

    if (url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholder(context),
          errorWidget: (context, url, error) => _buildPlaceholder(context),
        ),
      );
    }

    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
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
