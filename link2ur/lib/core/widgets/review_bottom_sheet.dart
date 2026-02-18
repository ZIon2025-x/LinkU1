import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../utils/l10n_extension.dart';
import 'animated_star_rating.dart';
import 'buttons.dart';

/// 评价任务底部弹窗（对齐 iOS ReviewModal）
///
/// 支持：星级评分（半星）、评论输入、匿名开关、异步提交加载态
class ReviewBottomSheet extends StatefulWidget {
  const ReviewBottomSheet({
    super.key,
    required this.onSubmit,
  });

  /// 异步提交，返回 (success, errorMessage?)
  final Future<({bool success, String? error})> Function(
    double rating,
    String? comment,
    bool isAnonymous,
  ) onSubmit;

  @override
  State<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<ReviewBottomSheet> {
  double _rating = 5.0;
  bool _isAnonymous = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.taskDetailReviewTitle,
              style: AppTypography.title3.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: AnimatedStarRating(
                rating: _rating,
                size: 36,
                spacing: 6,
                activeColor: const Color(0xFFFFB300),
                onRatingChanged: _isSubmitting
                    ? null
                    : (v) => setState(() {
                          _rating = v;
                          _errorMessage = null;
                        }),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _ratingLabel(context),
                style: AppTypography.bodyBold.copyWith(
                  color: const Color(0xFFFFB300),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.body.copyWith(
                          color: AppColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 500,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                hintText: context.l10n.taskDetailReviewCommentHint,
                hintStyle: TextStyle(
                  color: isDark
                      ? AppColors.textPlaceholderDark
                      : AppColors.textPlaceholderLight,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.separatorDark
                        : AppColors.separatorLight,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.separatorDark
                        : AppColors.separatorLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? AppColors.primaryDark
                        : AppColors.primaryLight,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: isDark
                    ? AppColors.secondaryBackgroundDark
                    : AppColors.backgroundLight,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  context.l10n.taskDetailReviewAnonymous,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: _isAnonymous,
                  onChanged: _isSubmitting
                      ? null
                      : (v) => setState(() => _isAnonymous = v),
                  activeThumbColor: isDark
                      ? AppColors.primaryDark
                      : AppColors.primaryLight,
                  activeTrackColor: (isDark
                      ? AppColors.primaryDark
                      : AppColors.primaryLight)
                      .withValues(alpha: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                text: context.l10n.taskDetailReviewSubmit,
                isLoading: _isSubmitting,
                onPressed: _rating >= 0.5 && !_isSubmitting
                    ? () => _handleSubmit()
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(BuildContext context) {
    final l10n = context.l10n;
    final fullStars = _rating.floor();
    final hasHalfStar = _rating - fullStars >= 0.5;

    if (hasHalfStar) {
      switch (fullStars) {
        case 0:
          return l10n.rating05Stars;
        case 1:
          return l10n.rating15Stars;
        case 2:
          return l10n.rating25Stars;
        case 3:
          return l10n.rating35Stars;
        case 4:
          return l10n.rating45Stars;
        default:
          return '';
      }
    }
    switch (fullStars) {
      case 1:
        return l10n.ratingVeryPoor;
      case 2:
        return l10n.ratingPoor;
      case 3:
        return l10n.ratingAverage;
      case 4:
        return l10n.ratingGood;
      case 5:
        return l10n.ratingExcellent;
      default:
        return '';
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final comment = _commentController.text.trim();
      final result = await widget.onSubmit(
        _rating,
        comment.isEmpty ? null : comment,
        _isAnonymous,
      );

      if (!mounted) return;
      if (result.success) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = result.error ??
              context.l10n.actionReviewFailed;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }
}
