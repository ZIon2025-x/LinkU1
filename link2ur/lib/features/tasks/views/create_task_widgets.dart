import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../l10n/app_localizations.dart';

// ==================== 1. SectionCard ====================

/// 白底圆角卡片容器
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.label,
    this.isRequired = false,
    required this.child,
  });

  final String label;
  final bool isRequired;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isRequired)
                const Text('* ',
                    style: TextStyle(
                        color: Color(0xFFFF4757),
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ==================== 2. CategoryDropdown ====================

/// 分类下拉选择框
class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({
    super.key,
    required this.selected,
    required this.onSelected,
    this.isStudentVerified = false,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final bool isStudentVerified;

  static List<(String key, String label)> getCategories(
    AppLocalizations l10n, {
    bool isStudentVerified = false,
  }) {
    return <(String key, String label)>[
      ('shopping', l10n.createTaskCategoryShopping),
      ('tutoring', l10n.createTaskCategoryTutoring),
      ('translation', l10n.createTaskCategoryTranslation),
      ('design', l10n.createTaskCategoryDesign),
      ('programming', l10n.createTaskCategoryProgramming),
      ('writing', l10n.createTaskCategoryWriting),
      ('photography', l10n.createTaskCategoryPhotography),
      ('moving', l10n.createTaskCategoryMoving),
      ('cleaning', l10n.createTaskCategoryCleaning),
      ('repair', l10n.createTaskCategoryRepair),
      ('pickup_dropoff', l10n.createTaskCategoryPickupDropoff),
      ('cooking', l10n.createTaskCategoryCooking),
      ('language_help', l10n.createTaskCategoryLanguageHelp),
      ('government', l10n.createTaskCategoryGovernment),
      ('pet_care', l10n.createTaskCategoryPetCare),
      ('errand', l10n.createTaskCategoryErrand),
      ('accompany', l10n.createTaskCategoryAccompany),
      ('digital', l10n.createTaskCategoryDigital),
      ('rental_housing', l10n.createTaskCategoryRentalHousing),
      if (isStudentVerified)
        ('campus_life', l10n.createTaskCategoryCampusLife),
      ('second_hand', l10n.createTaskCategorySecondHand),
      ('other', l10n.createTaskCategoryOther),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = getCategories(l10n, isStudentVerified: isStudentVerified);

    return DropdownButtonFormField<String>(
      initialValue: categories.any((c) => c.$1 == selected) ? selected : categories.first.$1,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEEEEEE),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEEEEEE),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      items: categories.map((cat) {
        return DropdownMenuItem<String>(
          value: cat.$1,
          child: Text(cat.$2),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
    );
  }
}

// ==================== 3. PriceRow ====================

/// 价格输入 + 定价类型三选一
class PriceRow extends StatelessWidget {
  const PriceRow({
    super.key,
    required this.controller,
    required this.pricingType,
    required this.onPricingTypeChanged,
    this.currency = 'GBP',
  });

  final TextEditingController controller;
  final String pricingType; // 'fixed', 'hourly', 'negotiable'
  final ValueChanged<String> onPricingTypeChanged;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Currency symbol
        Text(Helpers.currencySymbolFor(currency),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        // Price input
        SizedBox(
          width: 100,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            enabled: pricingType != 'negotiable',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: '0',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF3A3A3C)
                        : const Color(0xFFEEEEEE),
                    width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF3A3A3C)
                        : const Color(0xFFEEEEEE),
                    width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFAFAFA),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Pricing type buttons
        Expanded(
          child: Row(
            children: [
              _buildTypeBtn(context, 'fixed', l10n.createTaskPricingFixed),
              const SizedBox(width: 6),
              _buildTypeBtn(context, 'hourly', l10n.createTaskPricingHourly),
              const SizedBox(width: 6),
              _buildTypeBtn(
                  context, 'negotiable', l10n.createTaskPricingNegotiable),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeBtn(BuildContext context, String type, String label) {
    final isActive = pricingType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () => onPricingTypeChanged(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? Colors.white
                  : isDark
                      ? Colors.white70
                      : const Color(0xFF666666),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== 4. TaskModeSelector ====================

/// 任务方式三选卡片
class TaskModeSelector extends StatelessWidget {
  const TaskModeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected; // 'online', 'offline', 'both'
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final modes = <(String key, String icon, String label)>[
      ('online', '🌐', l10n.createTaskModeOnline),
      ('offline', '📍', l10n.createTaskModeOffline),
      ('both', '🤷', l10n.createTaskModeBoth),
    ];

    return Row(
      children: modes.map((mode) {
        final isSelected = selected == mode.$1;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                left: mode.$1 == 'online' ? 0 : 4,
                right: mode.$1 == 'both' ? 0 : 4),
            child: GestureDetector(
              onTap: () => onSelected(mode.$1),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : isDark
                            ? const Color(0xFF3A3A3C)
                            : const Color(0xFFEEEEEE),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(mode.$2, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(
                      mode.$3,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.primary
                            : isDark
                                ? Colors.white70
                                : const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ==================== 5. DeadlineChips ====================

/// 截止时间快捷选项 chips
class DeadlineChips extends StatelessWidget {
  const DeadlineChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String? selected; // '24h', '3d', '1w', '2w', 'no_rush', 'custom'
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = <(String key, String label)>[
      ('24h', l10n.createTaskDeadline24h),
      ('3d', l10n.createTaskDeadline3d),
      ('1w', l10n.createTaskDeadline1w),
      ('2w', l10n.createTaskDeadline2w),
      ('no_rush', l10n.createTaskDeadlineNoRush),
      ('custom', '📅 ${l10n.createTaskDeadlineCustom}'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected == opt.$1;
        return GestureDetector(
          onTap: () => onSelected(opt.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : isDark
                        ? const Color(0xFF3A3A3C)
                        : const Color(0xFFEEEEEE),
                width: 1.5,
              ),
            ),
            child: Text(
              opt.$2,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : isDark
                        ? Colors.white70
                        : const Color(0xFF666666),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ==================== 6. SkillTagSelector ====================

/// 技能标签选择 + 自定义输入
class SkillTagSelector extends StatelessWidget {
  const SkillTagSelector({
    super.key,
    required this.selected,
    required this.suggestions,
    required this.onToggle,
    required this.onAddCustom,
  });

  final List<String> selected;
  final List<String> suggestions;
  final ValueChanged<String> onToggle;
  final VoidCallback onAddCustom;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Merge: show suggestions first, then any selected that aren't in suggestions
    final allTags = <String>[
      ...suggestions,
      ...selected.where((s) => !suggestions.contains(s)),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...allTags.map((tag) {
          final isSelected = selected.contains(tag);
          return GestureDetector(
            onTap: () => onToggle(tag),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFFAFAFA),
                borderRadius: AppRadius.allPill,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : isDark
                          ? const Color(0xFF3A3A3C)
                          : const Color(0xFFEEEEEE),
                  width: 1.5,
                ),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : isDark
                          ? Colors.white70
                          : const Color(0xFF666666),
                ),
              ),
            ),
          );
        }),
        // + Custom button
        GestureDetector(
          onTap: onAddCustom,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: AppRadius.allPill,
              border: Border.all(
                color: isDark
                    ? const Color(0xFF3A3A3C)
                    : const Color(0xFFEEEEEE),
                width: 1.5,
              ),
            ),
            child: Text(
              l10n.createTaskAddCustomSkill,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : const Color(0xFF999999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== 7. AIOptimizeBar ====================

/// AI 优化渐变按钮
class AIOptimizeBar extends StatelessWidget {
  const AIOptimizeBar({
    super.key,
    required this.onTap,
    this.isLoading = false,
  });

  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('✨', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.createTaskAiOptimize,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(l10n.createTaskAiOptimizeDesc,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11)),
                ],
              ),
            ),
            // Arrow
            Text('${l10n.createTaskAiOptimizeBtn} ›',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ==================== 8. AITipCard ====================

/// 描述框下方的 AI 建议提示
class AITipCard extends StatelessWidget {
  const AITipCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2D4E) : const Color(0xFFEEECFF),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: l10n.createTaskAiTipPrefix,
                    style: const TextStyle(
                        color: Color(0xFF667EEA), fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: l10n.createTaskAiTipContent),
                ],
              ),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : const Color(0xFF666666),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
