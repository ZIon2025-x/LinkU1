import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/page_transitions.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/faq.dart';
import '../../../data/repositories/common_repository.dart';

// ==================== FAQ ====================

/// FAQ 视图：使用数据库/API 的 FAQ 库（与 backend GET /api/faq、data/models/faq.dart 一致）
class FAQView extends StatelessWidget {
  const FAQView({super.key});

  /// 使用 data/models/faq.dart 的 FaqSection/FaqItem 解析后端 sections 列表
  static List<_FAQSection> _parseSectionsFromApi(
    List<Map<String, dynamic>> sectionMaps,
    String fallbackTitle,
  ) {
    final sections = <_FAQSection>[];
    for (final map in sectionMaps) {
      try {
        final sec = FaqSection.fromJson(map);
        if (sec.title.isEmpty && sec.items.isEmpty) continue;
        sections.add(_FAQSection(
          title: sec.title.isEmpty ? fallbackTitle : sec.title,
          items: sec.items
              .map((e) => _FAQItem(question: e.question, answer: e.answer))
              .toList(),
        ));
      } catch (_) {
        // 单条解析失败时跳过该 section
        continue;
      }
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final faqLang = lang.startsWith('zh') ? 'zh' : 'en';
    final future = context.read<CommonRepository>().getFAQ(lang: faqLang);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.infoFAQTitle),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: AppSpacing.allMd,
                child: Text(
                  l10n.errorLoadFailedMessage,
                  style: AppTypography.body.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final list = snapshot.data ?? [];
          final sections = _parseSectionsFromApi(list, l10n.infoFAQTitle);
          if (sections.isEmpty) {
            return Center(
              child: Text(
                context.l10n.customerServiceNoChatHistory,
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: AppSpacing.allMd,
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) AppSpacing.vLg,
                  Text(
                    section.title,
                    style: AppTypography.title3.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  AppSpacing.vSm,
                  ...section.items.map((item) => _FAQItemWidget(item: item)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _FAQSection {
  _FAQSection({required this.title, required this.items});
  final String title;
  final List<_FAQItem> items;
}

class _FAQItem {
  _FAQItem({required this.question, required this.answer});
  final String question;
  final String answer;
}

class _FAQItemWidget extends StatefulWidget {
  const _FAQItemWidget({required this.item});
  final _FAQItem item;

  @override
  State<_FAQItemWidget> createState() => _FAQItemWidgetState();
}

class _FAQItemWidgetState extends State<_FAQItemWidget> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            widget.item.question,
            style: AppTypography.bodyBold.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          tilePadding: AppSpacing.horizontalMd,
          childrenPadding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
          ),
          children: [
            Text(
              widget.item.answer,
              style: AppTypography.body.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 法律文档通用视图 ====================

/// 法律文档内容视图
/// 参考iOS LegalDocumentContentView.swift
class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({
    super.key,
    required this.title,
    required this.content,
    this.url,
  });

  final String title;
  final String content;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: [
          if (url != null)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              onPressed: () async {
                final uri = Uri.tryParse(url!);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.allMd,
        child: Text(
          content,
          style: AppTypography.body.copyWith(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            height: 1.8,
          ),
        ),
      ),
    );
  }
}

/// 服务条款
class TermsView extends StatelessWidget {
  const TermsView({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentView(
      title: context.l10n.infoTermsTitle,
      content: context.l10n.infoTermsContent,
    );
  }
}

/// 隐私政策
class PrivacyView extends StatelessWidget {
  const PrivacyView({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentView(
      title: context.l10n.infoPrivacyTitle,
      content: context.l10n.infoPrivacyContent,
    );
  }
}

/// Cookie 政策
class CookiePolicyView extends StatelessWidget {
  const CookiePolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentView(
      title: context.l10n.infoCookieTitle,
      content: context.l10n.infoCookieContent,
    );
  }
}

// ==================== 关于 ====================

/// 关于视图
/// 参考iOS AboutView.swift
class AboutView extends StatefulWidget {
  const AboutView({super.key});

  @override
  State<AboutView> createState() => _AboutViewState();
}

class _AboutViewState extends State<AboutView> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (e) {
      AppLogger.warning('Failed to load package info: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.infoAboutTitle),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: AppSpacing.allLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  AppAssets.appIcon,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              AppSpacing.vLg,

              Text(
                'Link²Ur',
                style: AppTypography.title.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              AppSpacing.vXs,
              Text(
                context.l10n.infoConnectPlatform,
                style: AppTypography.subheadline.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              AppSpacing.vSm,
              Text(
                context.l10n.infoVersionFormat(_version, _buildNumber),
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),

              AppSpacing.vXl,

              // 功能列表
              _AboutListItem(
                title: context.l10n.infoTermsTitle,
                icon: Icons.description,
                onTap: () => pushWithSwipeBack(context, const TermsView()),
              ),
              _AboutListItem(
                title: context.l10n.infoPrivacyTitle,
                icon: Icons.privacy_tip,
                onTap: () => pushWithSwipeBack(context, const PrivacyView()),
              ),
              _AboutListItem(
                title: context.l10n.infoCookieTitle,
                icon: Icons.cookie,
                onTap: () => pushWithSwipeBack(context, const CookiePolicyView()),
              ),
              _AboutListItem(
                title: context.l10n.infoFAQTitle,
                icon: Icons.help_outline,
                onTap: () => pushWithSwipeBack(context, const FAQView()),
              ),

              const Spacer(),

              Text(
                context.l10n.infoCopyright,
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
              AppSpacing.vMd,
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutListItem extends StatelessWidget {
  const _AboutListItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: AppTypography.body.copyWith(
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark
            ? AppColors.textTertiaryDark
            : AppColors.textTertiaryLight,
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}

// ==================== VIP ====================

/// VIP 视图
/// 参考iOS VIPView.swift
class VIPView extends StatelessWidget {
  const VIPView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.infoVipCenter),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // VIP 卡片
            Container(
              width: double.infinity,
              margin: AppSpacing.allMd,
              padding: AppSpacing.allLg,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.secondaryBackgroundDark, AppColors.cardBackgroundDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: AppRadius.allLarge,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.workspace_premium,
                          color: AppColors.gold, size: 32),
                      AppSpacing.hSm,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Link²Ur VIP',
                            style: AppTypography.title2.copyWith(
                              color: AppColors.gold,
                            ),
                          ),
                          Text(
                            context.l10n.vipEnjoyBenefits,
                            style: AppTypography.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // VIP 特权列表
            Padding(
              padding: AppSpacing.horizontalMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.infoMemberBenefits,
                    style: AppTypography.title3.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  AppSpacing.vMd,
                  _VIPFeatureItem(
                    icon: Icons.bolt,
                    title: context.l10n.infoVipPriority,
                    description: context.l10n.vipPriorityRecommendationDesc,
                    color: AppColors.warning,
                  ),
                  _VIPFeatureItem(
                    icon: Icons.badge,
                    title: context.l10n.infoVipBadge,
                    description: context.l10n.vipExclusiveBadgeDesc,
                    color: AppColors.accent,
                  ),
                  _VIPFeatureItem(
                    icon: Icons.discount,
                    title: context.l10n.infoVipFeeReduction,
                    description: context.l10n.vipFeeDiscountDesc,
                    color: AppColors.success,
                  ),
                  _VIPFeatureItem(
                    icon: Icons.support_agent,
                    title: context.l10n.infoVipCustomerService,
                    description: context.l10n.vipExclusiveBadgeDesc,
                    color: AppColors.primary,
                  ),
                  _VIPFeatureItem(
                    icon: Icons.card_giftcard,
                    title: context.l10n.infoVipPointsBoost,
                    description: context.l10n.vipExclusiveActivityDesc,
                    color: AppColors.purple,
                  ),
                ],
              ),
            ),

            AppSpacing.vLg,

            // 购买按钮
            Padding(
              padding: AppSpacing.horizontalMd,
              child: PrimaryButton(
                text: context.l10n.infoVipSubscribe,
                onPressed: () {
                  context.goToVIPPurchase();
                },
                gradient: const LinearGradient(
                  colors: AppColors.gradientGold,
                ),
              ),
            ),

            AppSpacing.vXl,
          ],
        ),
      ),
    );
  }
}

class _VIPFeatureItem extends StatelessWidget {
  const _VIPFeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.allSmall,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyBold.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
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
