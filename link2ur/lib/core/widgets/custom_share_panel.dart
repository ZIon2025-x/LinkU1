import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../design/app_radius.dart';
import '../constants/app_assets.dart';
import '../utils/wechat_share_manager.dart';
import '../utils/qq_share_manager.dart';

/// 分享平台枚举
enum SharePlatform {
  wechat,
  wechatMoments,
  qq,
  qzone,
  weibo,
  facebook,
  instagram,
  twitter,
  sms,
  copyLink,
  generateImage,
  more,
}

/// 分享平台扩展
extension SharePlatformExtension on SharePlatform {
  String get displayName {
    switch (this) {
      case SharePlatform.wechat:
        return '微信';
      case SharePlatform.wechatMoments:
        return '朋友圈';
      case SharePlatform.qq:
        return 'QQ';
      case SharePlatform.qzone:
        return 'QQ空间';
      case SharePlatform.weibo:
        return '微博';
      case SharePlatform.facebook:
        return 'Facebook';
      case SharePlatform.instagram:
        return 'Instagram';
      case SharePlatform.twitter:
        return 'X';
      case SharePlatform.sms:
        return '短信';
      case SharePlatform.copyLink:
        return '复制链接';
      case SharePlatform.generateImage:
        return '生成图片';
      case SharePlatform.more:
        return '更多';
    }
  }

  Color get color {
    switch (this) {
      case SharePlatform.wechat:
      case SharePlatform.wechatMoments:
        return const Color(0xFF07C160);
      case SharePlatform.qq:
      case SharePlatform.qzone:
        return const Color(0xFF1296DB);
      case SharePlatform.weibo:
        return const Color(0xFFE6162D);
      case SharePlatform.facebook:
        return const Color(0xFF1877F2);
      case SharePlatform.instagram:
        return const Color(0xFFE4405F);
      case SharePlatform.twitter:
        return const Color(0xFF000000);
      case SharePlatform.sms:
        return const Color(0xFF34C759);
      case SharePlatform.copyLink:
        return AppColors.primary;
      case SharePlatform.generateImage:
        return AppColors.accent;
      case SharePlatform.more:
        return AppColors.textSecondaryLight;
    }
  }

  IconData get fallbackIcon {
    switch (this) {
      case SharePlatform.wechat:
      case SharePlatform.wechatMoments:
        return Icons.chat_bubble;
      case SharePlatform.qq:
      case SharePlatform.qzone:
        return Icons.chat;
      case SharePlatform.weibo:
        return Icons.public;
      case SharePlatform.facebook:
        return Icons.facebook;
      case SharePlatform.instagram:
        return Icons.camera_alt;
      case SharePlatform.twitter:
        return Icons.tag;
      case SharePlatform.sms:
        return Icons.sms;
      case SharePlatform.copyLink:
        return Icons.link;
      case SharePlatform.generateImage:
        return Icons.image;
      case SharePlatform.more:
        return Icons.more_horiz;
    }
  }

  String? get logoAsset {
    switch (this) {
      case SharePlatform.wechat:
        return AppAssets.wechat;
      case SharePlatform.wechatMoments:
        return AppAssets.wechatMoments;
      case SharePlatform.qq:
        return AppAssets.qq;
      case SharePlatform.qzone:
        return AppAssets.qzone;
      case SharePlatform.weibo:
        return AppAssets.weibo;
      case SharePlatform.facebook:
        return AppAssets.facebook;
      case SharePlatform.instagram:
        return AppAssets.instagram;
      case SharePlatform.twitter:
        return AppAssets.xTwitter;
      default:
        return null;
    }
  }
}

/// 自定义分享面板组件（类似小红书）
/// 参考iOS CustomSharePanel.swift
class CustomSharePanel extends StatelessWidget {
  const CustomSharePanel({
    super.key,
    required this.title,
    this.description = '',
    this.url,
    this.onDismiss,
  });

  final String title;
  final String description;
  final String? url;
  final VoidCallback? onDismiss;

  /// 便捷方法 - 显示分享面板
  static void show(
    BuildContext context, {
    required String title,
    String description = '',
    String? url,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CustomSharePanel(
        title: title,
        description: description,
        url: url,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  /// 所有分享平台
  static const List<SharePlatform> _allPlatforms = [
    SharePlatform.wechat,
    SharePlatform.wechatMoments,
    SharePlatform.qq,
    SharePlatform.weibo,
    SharePlatform.facebook,
    SharePlatform.instagram,
    SharePlatform.twitter,
    SharePlatform.sms,
    SharePlatform.copyLink,
    SharePlatform.more,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.topXlarge,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示器
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 标题栏
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    '分享到',
                    style: AppTypography.title3.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onDismiss,
                    child: Icon(
                      Icons.close,                 // xmark.circle.fill
                      size: 24,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),

            // 分享平台网格
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.lg,
                ),
                itemCount: _allPlatforms.length,
                itemBuilder: (context, index) {
                  final platform = _allPlatforms[index];
                  return _SharePlatformButton(
                    platform: platform,
                    onTap: () => _shareToPlatform(context, platform),
                  );
                },
              ),
            ),

            AppSpacing.vMd,
          ],
        ),
      ),
    );
  }

  Future<void> _shareToPlatform(
      BuildContext context, SharePlatform platform) async {
    HapticFeedback.selectionClick();

    switch (platform) {
      case SharePlatform.copyLink:
        if (url != null) {
          await Clipboard.setData(ClipboardData(text: url!));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('链接已复制'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        onDismiss?.call();
        break;

      case SharePlatform.sms:
        final smsUrl = Uri.parse('sms:?body=${Uri.encodeComponent('$title\n${url ?? ''}')}'
        );
        if (await canLaunchUrl(smsUrl)) {
          await launchUrl(smsUrl);
        }
        onDismiss?.call();
        break;

      case SharePlatform.wechat:
        onDismiss?.call();
        await _shareToWeChat(context, toMoments: false);
        break;

      case SharePlatform.wechatMoments:
        onDismiss?.call();
        await _shareToWeChat(context, toMoments: true);
        break;

      case SharePlatform.qq:
        onDismiss?.call();
        await _shareToQQ(context, toQZone: false);
        break;

      case SharePlatform.qzone:
        onDismiss?.call();
        await _shareToQQ(context, toQZone: true);
        break;

      case SharePlatform.more:
        onDismiss?.call();
        // 延迟显示系统分享面板，确保底部Sheet完全关闭
        await Future.delayed(const Duration(milliseconds: 300));
        final shareText = '$title\n$description\n${url ?? ''}';
        await Share.share(shareText);
        break;

      default:
        // 其他平台尝试通过系统分享
        onDismiss?.call();
        await Future.delayed(const Duration(milliseconds: 300));
        final defaultShareText = '$title\n$description\n${url ?? ''}';
        await Share.share(defaultShareText);
        break;
    }
  }

  /// 分享到微信
  Future<void> _shareToWeChat(BuildContext context, {required bool toMoments}) async {
    try {
      final wechatManager = WeChatShareManager.instance;
      final installed = await wechatManager.isWeChatInstalled();

      if (!installed) {
        // 微信未安装，使用系统分享
        await Future.delayed(const Duration(milliseconds: 300));
        await Share.share('$title\n$description\n${url ?? ''}');
        return;
      }

      bool success;
      if (toMoments) {
        success = await wechatManager.shareToMoments(
          title: title,
          description: description,
          url: url ?? '',
        );
      } else {
        success = await wechatManager.shareToFriend(
          title: title,
          description: description,
          url: url ?? '',
        );
      }

      if (!success && context.mounted) {
        // 分享失败，回退到系统分享
        await Future.delayed(const Duration(milliseconds: 300));
        await Share.share('$title\n$description\n${url ?? ''}');
      }
    } catch (_) {
      // 出错时回退到系统分享
      await Future.delayed(const Duration(milliseconds: 300));
      await Share.share('$title\n$description\n${url ?? ''}');
    }
  }

  /// 分享到 QQ
  Future<void> _shareToQQ(BuildContext context, {required bool toQZone}) async {
    try {
      final qqManager = QQShareManager.instance;
      final installed = await qqManager.isQQInstalled();

      if (!installed) {
        // QQ 未安装，使用系统分享
        await Future.delayed(const Duration(milliseconds: 300));
        await Share.share('$title\n$description\n${url ?? ''}');
        return;
      }

      bool success;
      if (toQZone) {
        success = await qqManager.shareToQZone(
          title: title,
          description: description,
          url: url ?? '',
        );
      } else {
        success = await qqManager.shareToFriend(
          title: title,
          description: description,
          url: url ?? '',
        );
      }

      if (!success && context.mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        await Share.share('$title\n$description\n${url ?? ''}');
      }
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 300));
      await Share.share('$title\n$description\n${url ?? ''}');
    }
  }
}

/// 分享平台按钮
class _SharePlatformButton extends StatelessWidget {
  const _SharePlatformButton({
    required this.platform,
    required this.onTap,
  });

  final SharePlatform platform;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图标
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: platform.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: platform.logoAsset != null
                  ? ClipOval(
                      child: Image.asset(
                        platform.logoAsset!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          platform.fallbackIcon,
                          size: 28,
                          color: platform.color,
                        ),
                      ),
                    )
                  : Icon(
                      platform.fallbackIcon,
                      size: 28,
                      color: platform.color,
                    ),
            ),
          ),
          const SizedBox(height: 6),
          // 平台名称
          Text(
            platform.displayName,
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
