import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../router/go_router_extensions.dart';
import '../utils/haptic_feedback.dart';
import '../utils/l10n_extension.dart';
import 'async_image_view.dart';

/// 发布者身份组件
///
/// 统一呈现内容发布者（用户或达人团队）：头像 + 名称 + 可选"达人团队"徽章。
///
/// 字段解析级联（对齐后端 display_name/display_avatar 兜底）：
///   displayName (后端)  →  fallbackName (调用方已有数据) → l10n.unknownUser
///   displayAvatar (后端) →  fallbackAvatar (调用方已有数据) → AvatarView 默认
///
/// 行为：
/// - ownerType == 'expert' 且 showBadge → 显示达人团队徽章
/// - 点击跳转：expert → /task-experts/{ownerId}; 其他 → /user/{ownerId}
/// - ownerId 为空/null → 渲染但不可点击
class PublisherIdentity extends StatelessWidget {
  const PublisherIdentity({
    super.key,
    required this.ownerType,
    required this.ownerId,
    this.displayName,
    this.displayAvatar,
    this.fallbackName,
    this.fallbackAvatar,
    this.showBadge = true,
    this.avatarSize = 32,
    this.nameStyle,
    this.isAnonymous = false,
    this.subtitle,
  });

  /// 'user' | 'expert' | null
  final String? ownerType;

  /// 用户 ID 或达人团队 ID
  final String? ownerId;

  /// 后端 display_name（owner 维度聚合后的名称）
  final String? displayName;

  /// 后端 display_avatar
  final String? displayAvatar;

  /// displayName 为空时的兜底（调用方已有名称，例如 author.name / ownerName）
  final String? fallbackName;

  /// displayAvatar 为空时的兜底
  final String? fallbackAvatar;

  /// 是否显示达人团队徽章（仅 expert 时生效）
  final bool showBadge;

  /// 头像尺寸
  final double avatarSize;

  /// 名称文本样式；默认 [AppTypography.subheadlineBold]
  final TextStyle? nameStyle;

  /// 是否为匿名发布者；true 时 AvatarView 渲染匿名头像 asset，覆盖 displayAvatar/fallbackAvatar
  final bool isAnonymous;

  /// 可选副标题（例如发布时间）；渲染在名称/徽章下方、同一 Column 内，自动与名称左对齐
  final Widget? subtitle;

  bool get _isExpert => ownerType == 'expert';
  bool get _isTappable => ownerId != null && ownerId!.isNotEmpty;

  String _resolveName(BuildContext context) {
    final primary = displayName?.trim();
    if (primary != null && primary.isNotEmpty) return primary;
    final fallback = fallbackName?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return context.l10n.unknownUser;
  }

  String? _resolveAvatar() {
    final primary = displayAvatar?.trim();
    if (primary != null && primary.isNotEmpty) return primary;
    final fallback = fallbackAvatar?.trim();
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }

  void _onTap(BuildContext context) {
    if (!_isTappable) return;
    AppHaptics.selection();
    if (_isExpert) {
      context.goToTaskExpertDetail(ownerId!);
    } else {
      context.goToUserProfile(ownerId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _resolveName(context);
    final avatar = _resolveAvatar();

    final effectiveNameStyle = nameStyle ?? AppTypography.subheadlineBold;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarView(
          imageUrl: avatar,
          name: name,
          size: avatarSize,
          isAnonymous: isAnonymous,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: effectiveNameStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (showBadge && _isExpert)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.l10n.expertTeamLabel,
                    style: AppTypography.caption2.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (subtitle != null) subtitle!,
            ],
          ),
        ),
      ],
    );

    if (!_isTappable) return content;
    return Semantics(
      button: true,
      label: _isExpert && showBadge
          ? '$name, ${context.l10n.expertTeamLabel}'
          : name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTap(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: content,
          ),
        ),
      ),
    );
  }
}
