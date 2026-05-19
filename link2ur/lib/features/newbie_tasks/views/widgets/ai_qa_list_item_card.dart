import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../data/models/ai_qa.dart';

/// AI 限时问答列表项卡片 (P0-T23, mockup M1 "官方活动" qa-item 样式)
///
/// 视觉要点（mockup `2026-05-13-ai-qa-bounty-mockup.html` 早期 M1 用金色,
/// 实际按品牌色规范 `mockups/blue-white-gradient-preview.html` 方案 B 统一蓝白）:
/// - 左侧 3px Apple System Blue 边框 (#007AFF) — 区分于其他类型卡片
/// - 顶部 badge 行: £X 现金 (橙) + +X 积分 (紫) + 进行中 (绿) — functional badge 跨 feature 一致
/// - 题面 2 行 ellipsis
/// - 底部 stats 行: 🤖 AI 出题 + 📝 X 人作答 + ⏱ 倒计时
class AiQaListItemCard extends StatelessWidget {
  const AiQaListItemCard({
    super.key,
    required this.question,
    this.onTap,
  });

  final AiQuestion question;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final pound = (question.rewardPoolPence / 100).toStringAsFixed(0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            // 蓝色左边框 (品牌色 Apple System Blue #007AFF,
            // mockups/blue-white-gradient-preview.html 方案 B)
            left: const BorderSide(color: Color(0xFF007AFF), width: 3),
            top: BorderSide(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              width: 0.5,
            ),
            right: BorderSide(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              width: 0.5,
            ),
            bottom: BorderSide(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部 badge 行
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Pill(
                  text: l10n.aiQaListCash(pound),
                  bg: const Color(0xFFFEF3C7),
                  fg: const Color(0xFFEA580C),
                ),
                _Pill(
                  text: l10n.aiQaListPoints(question.participationPoints),
                  bg: const Color(0xFFF3E8FF),
                  fg: const Color(0xFF6B21A8),
                ),
                _Pill(
                  text: l10n.aiQaStatusLive,
                  bg: const Color(0xFFD1FAE5),
                  fg: const Color(0xFF047857),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 题面
            Text(
              question.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // 底部 stats 行
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _StatChip(icon: '🤖', text: l10n.aiQaAiPosed),
                _StatChip(
                  icon: '📝',
                  text: l10n.aiQaListAnswerCount(question.answerCount ?? 0),
                ),
                if (question.deadline != null)
                  _StatChip(
                    icon: '⏱',
                    text: _formatCountdown(context, question.deadline!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 倒计时格式化 — 与 ai_qa_list_view.dart `_StatsRow` 同款逻辑。
  String _formatCountdown(BuildContext context, DateTime deadline) {
    final l10n = context.l10n;
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) {
      return l10n.aiQaDeadlinePassed;
    }
    if (diff.inDays > 0) {
      return l10n.aiQaCountdownDaysHours(diff.inDays, diff.inHours % 24);
    }
    return l10n.aiQaCountdownHours(diff.inHours);
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Pill({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String text;
  const _StatChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
