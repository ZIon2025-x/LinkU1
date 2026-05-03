import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/widgets/animated_star_rating.dart';
import '../../../../data/models/user.dart' show UserProfileReview;

/// 单条评价 (b-review-mini): 32 圆头像 + 姓名 + 星级 + 时间 + 评论。
///
/// 复用于他人主页 section 内联预览以及独立「全部评价」页面。
class ReviewMini extends StatelessWidget {
  const ReviewMini({
    super.key,
    required this.review,
    this.showDivider = false,
  });

  final UserProfileReview review;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final reviewerName = (review.reviewerName?.isNotEmpty ?? false)
        ? review.reviewerName!
        : (review.isAnonymous
            ? context.l10n.profileAnonymousUser
            : context.l10n.commonUser);
    final initial = reviewerName.characters.isNotEmpty
        ? reviewerName.characters.first
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(
                top: BorderSide(color: Color(0xFFF0F1F4)),
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _avatarGradient(reviewerName),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        reviewerName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedStarRating(
                      rating: review.rating,
                      size: 11,
                      spacing: 1,
                    ),
                    const Spacer(),
                    if (review.createdAt.isNotEmpty)
                      Text(
                        _formatReviewTime(context, review.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9A9FA5),
                        ),
                      ),
                  ],
                ),
                if ((review.comment ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    review.comment!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.55,
                      color: Color(0xFF4D5560),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatReviewTime(BuildContext context, String createdAt) {
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return createdAt;
    return DateFormatter.formatRelative(dt, l10n: context.l10n);
  }

  static const _palette = <List<Color>>[
    [Color(0xFFFFD6A5), Color(0xFFFF9A3C)],
    [Color(0xFFA8EDEA), Color(0xFF67D4FF)],
    [Color(0xFFC8B6FF), Color(0xFF9484FF)],
    [Color(0xFFFFC1CC), Color(0xFFFF6A88)],
    [Color(0xFFB8E994), Color(0xFF26A65B)],
  ];

  LinearGradient _avatarGradient(String name) {
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final pair = _palette[hash % _palette.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: pair,
    );
  }
}
