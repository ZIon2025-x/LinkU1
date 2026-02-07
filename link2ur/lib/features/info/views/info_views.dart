import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/constants/app_assets.dart';

// ==================== FAQ ====================

/// FAQ 视图
/// 参考iOS FAQView.swift
class FAQView extends StatelessWidget {
  const FAQView({super.key});

  static const List<_FAQSection> _sections = [
    _FAQSection(
      title: '账号相关',
      items: [
        _FAQItem(
          question: '如何注册 Link²Ur 账号？',
          answer: '您可以使用邮箱注册，填写基本信息即可完成注册。如果是在校学生，推荐完成学生认证以享受更多功能。',
        ),
        _FAQItem(
          question: '忘记密码怎么办？',
          answer: '在登录页面点击"忘记密码"，通过注册邮箱接收重置链接即可修改密码。',
        ),
        _FAQItem(
          question: '如何完成学生认证？',
          answer: '进入"个人中心"→"学生认证"，上传有效的学生证或教育邮箱即可申请认证。',
        ),
      ],
    ),
    _FAQSection(
      title: '任务相关',
      items: [
        _FAQItem(
          question: '如何发布任务？',
          answer: '点击底部导航栏中间的"+"按钮，选择"发布任务"，填写任务描述、酬劳、截止时间等信息即可发布。',
        ),
        _FAQItem(
          question: '如何接受任务？',
          answer: '浏览首页或任务列表，找到感兴趣的任务，点击"申请接单"即可。任务发布者确认后，您即可开始执行。',
        ),
        _FAQItem(
          question: '任务酬劳如何结算？',
          answer: '任务完成后，发布者确认完成，平台将自动将酬劳转入您的钱包。您可以在钱包中提现到银行卡。',
        ),
      ],
    ),
    _FAQSection(
      title: '支付与安全',
      items: [
        _FAQItem(
          question: '支付方式有哪些？',
          answer: '目前支持银行卡（Visa/Mastercard）、Apple Pay、微信支付等方式。',
        ),
        _FAQItem(
          question: '支付安全吗？',
          answer: '所有支付均通过 Stripe 安全通道处理，您的支付信息经过加密保护，平台不会存储您的银行卡信息。',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('常见问题'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: AppSpacing.allMd,
        itemCount: _sections.length,
        itemBuilder: (context, index) {
          final section = _sections[index];
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
      ),
    );
  }
}

class _FAQSection {
  const _FAQSection({required this.title, required this.items});
  final String title;
  final List<_FAQItem> items;
}

class _FAQItem {
  const _FAQItem({required this.question, required this.answer});
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
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
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
          childrenPadding: EdgeInsets.only(
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
    return const LegalDocumentView(
      title: '服务条款',
      content: '''
Link²Ur 服务条款

最后更新日期：2024年1月1日

1. 服务概述
Link²Ur 是一个校园互助平台，旨在帮助用户发布和接受各类生活服务任务。

2. 用户责任
- 用户应提供真实、准确的个人信息
- 用户应遵守平台规则和相关法律法规
- 用户对其发布的内容承担责任

3. 平台责任
- 平台提供信息中介服务
- 平台对交易资金实行托管保障
- 平台有权对违规行为进行处理

4. 支付与结算
- 所有支付通过第三方支付平台处理
- 任务完成后平台自动结算
- 平台收取合理的服务费用

5. 隐私保护
请参阅我们的隐私政策了解详细信息。

6. 免责声明
平台作为信息中介，不对用户之间的交易承担直接责任。

如有任何疑问，请联系我们的客服团队。
''',
    );
  }
}

/// 隐私政策
class PrivacyView extends StatelessWidget {
  const PrivacyView({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentView(
      title: '隐私政策',
      content: '''
Link²Ur 隐私政策

最后更新日期：2024年1月1日

1. 信息收集
我们收集以下类型的信息：
- 注册信息（姓名、邮箱等）
- 位置信息（用于附近任务推荐）
- 设备信息（用于推送通知）

2. 信息使用
我们使用您的信息来：
- 提供和改善服务
- 个性化推荐
- 保障交易安全

3. 信息存储与保护
- 数据存储在安全的服务器上
- 采用加密技术保护数据传输
- 定期进行安全审计

4. 信息共享
我们不会出售您的个人信息。仅在以下情况下共享：
- 经您同意
- 法律要求
- 服务提供所必需

5. Cookie 政策
我们使用 Cookie 来改善用户体验。

6. 您的权利
- 访问和修改个人信息
- 删除账户
- 退订通知

如有隐私相关问题，请联系 privacy@link2ur.com
''',
    );
  }
}

/// Cookie 政策
class CookiePolicyView extends StatelessWidget {
  const CookiePolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentView(
      title: 'Cookie 政策',
      content: '''
Link²Ur Cookie 政策

我们使用 Cookie 和类似技术来改善您的使用体验。

1. 什么是 Cookie
Cookie 是存储在您设备上的小型文本文件。

2. 我们如何使用 Cookie
- 必要 Cookie：保持登录状态
- 功能 Cookie：记住偏好设置
- 分析 Cookie：改善服务质量

3. 管理 Cookie
您可以在设备设置中管理 Cookie 偏好。
''',
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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
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
                '校园任务互助平台',
                style: AppTypography.subheadline.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              AppSpacing.vSm,
              Text(
                '版本 $_version ($_buildNumber)',
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),

              AppSpacing.vXl,

              // 功能列表
              _AboutListItem(
                title: '服务条款',
                icon: Icons.description,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TermsView()),
                ),
              ),
              _AboutListItem(
                title: '隐私政策',
                icon: Icons.privacy_tip,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrivacyView()),
                ),
              ),
              _AboutListItem(
                title: 'Cookie 政策',
                icon: Icons.cookie,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CookiePolicyView()),
                ),
              ),
              _AboutListItem(
                title: '常见问题',
                icon: Icons.help_outline,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FAQView()),
                ),
              ),

              const Spacer(),

              Text(
                '© 2024 Link²Ur. All rights reserved.',
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
        title: const Text('会员中心'),
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
                  colors: [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
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
                          color: Color(0xFFFFD700), size: 32),
                      AppSpacing.hSm,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Link²Ur VIP',
                            style: AppTypography.title2.copyWith(
                              color: const Color(0xFFFFD700),
                            ),
                          ),
                          Text(
                            '尊享会员特权',
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
                    '会员特权',
                    style: AppTypography.title3.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  AppSpacing.vMd,
                  _VIPFeatureItem(
                    icon: Icons.bolt,
                    title: '优先接单',
                    description: '任务推送优先，抢单更快一步',
                    color: AppColors.warning,
                  ),
                  _VIPFeatureItem(
                    icon: Icons.badge,
                    title: '专属标识',
                    description: '头像显示VIP标识，提升可信度',
                    color: AppColors.accent,
                  ),
                  _VIPFeatureItem(
                    icon: Icons.discount,
                    title: '手续费减免',
                    description: '平台服务费享受折扣优惠',
                    color: AppColors.success,
                  ),
                  _VIPFeatureItem(
                    icon: Icons.support_agent,
                    title: '专属客服',
                    description: 'VIP专属客服通道，问题优先处理',
                    color: AppColors.primary,
                  ),
                  _VIPFeatureItem(
                    icon: Icons.card_giftcard,
                    title: '积分加倍',
                    description: '每日签到积分翻倍',
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
                text: '开通 VIP 会员',
                onPressed: () {
                  // TODO: 跳转到支付页面
                },
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF9500)],
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
      padding: EdgeInsets.only(bottom: AppSpacing.md),
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
