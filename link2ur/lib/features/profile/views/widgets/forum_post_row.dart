import 'package:flutter/material.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/widgets/async_image_view.dart';
import '../../../../data/models/user.dart' show UserProfileForumPost;

/// 论坛动态行 (b-task-row): 彩色图标块 + 标题 + 赞/评论/时间。
///
/// 复用于他人主页 section 内联预览以及独立「全部论坛动态」页。
class ForumPostRow extends StatelessWidget {
  const ForumPostRow({
    super.key,
    required this.post,
    this.colorIndex = 0,
    this.showDivider = false,
  });

  final UserProfileForumPost post;
  final int colorIndex;
  final bool showDivider;

  static const _iconPalette = <List<Color>>[
    [Color(0xFFFEF3C7), Color(0xFFD97706)],
    [Color(0xFFDCFCE7), Color(0xFF059669)],
    [Color(0xFFEEF0FF), Color(0xFF4F46E5)],
    [Color(0xFFFCE7F3), Color(0xFFDB2777)],
    [Color(0xFFCFFAFE), Color(0xFF0891B2)],
  ];

  @override
  Widget build(BuildContext context) {
    final pair = _iconPalette[colorIndex % _iconPalette.length];
    final timeText = (post.createdAt != null && post.createdAt!.isNotEmpty)
        ? _formatTime(context, post.createdAt!)
        : null;

    return InkWell(
      onTap: () => context.goToForumPostDetail(post.id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  top: BorderSide(color: Color(0xFFF0F1F4)),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: pair[0],
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              child: post.images.isNotEmpty
                  ? AsyncImageView(
                      imageUrl: Helpers.getThumbnailUrl(post.images.first),
                      fallbackUrl: Helpers.getImageUrl(post.images.first),
                      width: 40,
                      height: 40,
                    )
                  : Icon(Icons.forum_outlined, color: pair[1], size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.displayTitle(Localizations.localeOf(context)),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.thumb_up_outlined,
                          size: 11, color: Color(0xFF9A9FA5)),
                      const SizedBox(width: 3),
                      Text(
                        '${post.likeCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9A9FA5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.mode_comment_outlined,
                          size: 11, color: Color(0xFF9A9FA5)),
                      const SizedBox(width: 3),
                      Text(
                        '${post.replyCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9A9FA5),
                        ),
                      ),
                      if (timeText != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '· $timeText',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9A9FA5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(BuildContext context, String createdAt) {
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return createdAt;
    return DateFormatter.formatRelative(dt, l10n: context.l10n);
  }
}
