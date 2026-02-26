import 'package:flutter/material.dart';

import '../../../data/models/activity.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';

/// 活动价格显示：有折扣时展示原价（删除线）+ 折后价，与 HTML mockup 一致
class ActivityPriceWidget extends StatelessWidget {
  const ActivityPriceWidget({
    super.key,
    required this.activity,
    this.fontSize = 18,
  });

  final Activity activity;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tertiaryColor = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;
    const symbol = '£';

    if (activity.hasDiscount &&
        activity.originalPricePerParticipant != null &&
        activity.discountedPricePerParticipant != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$symbol${Helpers.formatAmountNumber(activity.originalPricePerParticipant!)}',
            style: TextStyle(
              fontSize: fontSize * 0.65,
              color: tertiaryColor,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          SizedBox(width: fontSize * 0.35),
          Text(
            '$symbol${Helpers.formatAmountNumber(activity.discountedPricePerParticipant!)}',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      );
    }

    final isFree = activity.discountedPricePerParticipant == null &&
        activity.originalPricePerParticipant == null;
    return Text(
      isFree ? context.l10n.activityFree : activity.priceDisplay,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }
}
