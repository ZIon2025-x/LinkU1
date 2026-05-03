import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/legal_document.dart';
import '../../../data/repositories/common_repository.dart';

/// 退款政策页面
///
/// 通过 GET /api/legal/refund_policy?lang= 获取后端 seeded JSON 文档,
/// 渲染为可滚动的章节卡片列表。
///
/// 入口:
/// - 支付页底部的 RefundPolicyFooter (PaymentView, ApprovalPaymentPage)
/// - 设置页"法律条款"分组的导航行
class RefundPolicyView extends StatelessWidget {
  const RefundPolicyView({super.key});

  /// content_json 中的 metadata key —— 这些值已内嵌标签 (如 "版本：v1.0"),
  /// 单独渲染在顶部,不进入正文卡片列表。
  static const _metadataKeys = {'lastUpdated', 'version', 'effectiveDate'};

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    // 后端只 seeded zh/en;zh-Hant locale 复用 zh 内容,沿用 FAQView 同款 fallback。
    final apiLang = lang.startsWith('zh') ? 'zh' : 'en';

    final future =
        context.read<CommonRepository>().getLegalDocument(
              type: 'refund_policy',
              lang: apiLang,
            );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.refundPolicyTitle),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: AppSpacing.allLg,
                child: Text(
                  context.l10n.errorLoadFailedMessage,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final doc = LegalDocument.fromJson(snapshot.data!);
          final allSections = doc.sections;
          final metaSections = allSections
              .where((s) => _metadataKeys.contains(s.title))
              .toList();
          final contentSections = allSections
              .where((s) => !_metadataKeys.contains(s.title))
              .toList();

          return ListView.builder(
            padding: AppSpacing.allMd,
            itemCount: contentSections.length + 1, // +1 for metadata strip header
            itemBuilder: (context, i) {
              if (i == 0) return _MetadataStrip(sections: metaSections);
              return _SectionCard(section: contentSections[i - 1]);
            },
          );
        },
      ),
    );
  }
}

/// 顶部 metadata 小字行(最后更新、版本、生效日期),
/// 值本身已含标签前缀 (如 "版本：v1.0"),用 · 间隔拼接。
class _MetadataStrip extends StatelessWidget {
  const _MetadataStrip({required this.sections});

  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;

    final values = <String>[
      for (final s in sections)
        if (s.paragraphs.isNotEmpty) s.paragraphs.first,
    ];
    if (values.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Text(
        values.join(' · '),
        style: TextStyle(fontSize: 12, color: color),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final bodyColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.allMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                section.title,
                style: AppTypography.title3.copyWith(color: titleColor),
              ),
            ),
          for (final p in section.paragraphs)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                p,
                style: AppTypography.body
                    .copyWith(color: bodyColor, height: 1.7),
              ),
            ),
        ],
      ),
    );
  }
}
