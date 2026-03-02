import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/page_transitions.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/external_web_view.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/utils/native_share.dart';
import '../../../core/utils/share_util.dart';
import '../../../data/models/leaderboard.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../bloc/leaderboard_bloc.dart';

/// 排行榜条目详情页 - 对标iOS LeaderboardItemDetailView.swift
class LeaderboardItemDetailView extends StatelessWidget {
  const LeaderboardItemDetailView({super.key, required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeaderboardBloc(
        leaderboardRepository: context.read<LeaderboardRepository>(),
      )
        ..add(LeaderboardLoadItemDetail(itemId))
        ..add(LeaderboardLoadItemVotes(itemId)),
      child: _ItemDetailContent(itemId: itemId),
    );
  }
}

class _ItemDetailContent extends StatelessWidget {
  const _ItemDetailContent({required this.itemId});
  final int itemId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeaderboardBloc, LeaderboardState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.itemDetail != curr.itemDetail ||
          prev.itemVotes != curr.itemVotes ||
          prev.errorMessage != curr.errorMessage,
      builder: (context, state) {
        final item = state.itemDetail;
        final hasImages =
            item != null && item.images != null && item.images!.isNotEmpty;

        return Scaffold(
          extendBodyBehindAppBar: hasImages,
          appBar: _buildAppBar(context, item, hasImages),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: ResponsiveUtils.detailMaxWidth(context)),
              child: _buildBody(context, state),
            ),
          ),
          bottomNavigationBar:
              item != null ? _buildVoteBar(context, state) : null,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, LeaderboardItem? item, bool hasImages) {
    void onShare() async {
      if (item == null) return;
      final shareFiles = await NativeShare.fileFromFirstImageUrl(item.firstImage);
      if (!context.mounted) return;
      await NativeShare.share(
        title: item.name,
        description: item.description ?? '',
        url: ShareUtil.leaderboardItemUrl(item.id),
        files: shareFiles,
        context: context,
      );
    }

    if (!hasImages) {
      return AppBar(
        title: Text(context.l10n.leaderboardItemDetail),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: onShare,
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      forceMaterialTransparency: true,
      leading: Padding(
        padding: const EdgeInsets.all(4),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: Colors.white),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: onShare,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share_outlined,
                  size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, LeaderboardState state) {
    if (state.isLoading && state.itemDetail == null) {
      return const SkeletonLeaderboardItemDetail();
    }

    if (state.status == LeaderboardStatus.error && state.itemDetail == null) {
      return ErrorStateView.loadFailed(
        message: state.errorMessage ?? '加载失败',
        onRetry: () => context
            .read<LeaderboardBloc>()
            .add(LeaderboardLoadItemDetail(itemId)),
      );
    }

    final item = state.itemDetail;
    if (item == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        children: [
          // 图片区域
          _ImageSection(images: item.images ?? []),

          // 主信息区域 — 负偏移叠加效果
          Transform.translate(
            offset: const Offset(0, -40),
            child: Column(
              children: [
                // 名称卡片
                _NameCard(item: item, isDark: isDark),
                const SizedBox(height: AppSpacing.md),

                // 统计行
                _StatsRow(item: item),
                const SizedBox(height: AppSpacing.lg),

                // 描述卡片
                if (item.description != null &&
                    item.description!.isNotEmpty)
                  _DescriptionCard(
                      description: item.description!, isDark: isDark),

                // 联系方式卡片
                if (item.address != null ||
                    item.phone != null ||
                    item.website != null)
                  _ContactCard(item: item, isDark: isDark),

                // 评论区
                _CommentsSection(
                  votes: state.itemVotes,
                  isDark: isDark,
                ),

                const SizedBox(height: 140),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 底部投票栏
  Widget _buildVoteBar(BuildContext context, LeaderboardState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = state.itemDetail!;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark
                    ? AppColors.cardBackgroundDark
                    : AppColors.cardBackgroundLight)
                .withValues(alpha: 0.85),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 12),
              child: Row(
                children: [
                  // 反对按钮
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showVoteSheet(context, 'downvote', item),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: item.hasDownvoted
                              ? AppColors.error
                              : AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.thumb_down,
                                size: 20,
                                color: item.hasDownvoted
                                    ? Colors.white
                                    : AppColors.error),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.leaderboardOppose,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: item.hasDownvoted
                                    ? Colors.white
                                    : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 支持按钮
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showVoteSheet(context, 'upvote', item),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: item.hasUpvoted
                              ? AppColors.success
                              : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.thumb_up,
                                size: 20,
                                color: item.hasUpvoted
                                    ? Colors.white
                                    : AppColors.success),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.leaderboardSupport,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: item.hasUpvoted
                                    ? Colors.white
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showVoteSheet(
      BuildContext context, String voteType, LeaderboardItem item) {
    AppHaptics.selection();
    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<LeaderboardBloc>(),
        child: _VoteCommentSheet(
          itemId: itemId,
          voteType: voteType,
          existingComment:
              item.userVote == voteType ? item.userVoteComment : null,
          existingAnonymous:
              item.userVote == voteType ? (item.userVoteIsAnonymous ?? false) : false,
        ),
      ),
    );
  }
}

// ==================== 投票评论弹窗 ====================

class _VoteCommentSheet extends StatefulWidget {
  const _VoteCommentSheet({
    required this.itemId,
    required this.voteType,
    this.existingComment,
    this.existingAnonymous = false,
  });

  final int itemId;
  final String voteType;
  final String? existingComment;
  final bool existingAnonymous;

  @override
  State<_VoteCommentSheet> createState() => _VoteCommentSheetState();
}

class _VoteCommentSheetState extends State<_VoteCommentSheet> {
  late final TextEditingController _controller;
  late bool _isAnonymous;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existingComment ?? '');
    _isAnonymous = widget.existingAnonymous;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUpvote = widget.voteType == 'upvote';
    final accentColor = isUpvote ? AppColors.success : AppColors.error;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomPadding),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 不画自定义拖拽条：主题 showDragHandle: true 已提供
            const SizedBox(height: 16),

            // 标题
            Text(
              isUpvote
                  ? context.l10n.leaderboardSupportReason
                  : context.l10n.leaderboardOpposeReason,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 评论输入框
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.skeletonBase,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: context.l10n.leaderboardWriteReason,
                  hintStyle: AppTypography.body
                      .copyWith(color: AppColors.textTertiaryLight),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 匿名开关
            Row(
              children: [
                const Icon(Icons.visibility_off_outlined,
                    size: 18, color: AppColors.textSecondaryLight),
                const SizedBox(width: 8),
                Text(
                  context.l10n.leaderboardAnonymousVote,
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondaryLight),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: _isAnonymous,
                  onChanged: (v) => setState(() => _isAnonymous = v),
                  activeTrackColor: accentColor,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 提交按钮
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  isUpvote
                      ? context.l10n.leaderboardConfirmSupport
                      : context.l10n.leaderboardConfirmOppose,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    AppHaptics.medium();
    final comment = _controller.text.trim();
    context.read<LeaderboardBloc>().add(
          LeaderboardVoteItem(
            widget.itemId,
            voteType: widget.voteType,
            comment: comment.isNotEmpty ? comment : null,
            isAnonymous: _isAnonymous,
          ),
        );
    Navigator.of(context).pop();
  }
}

// ==================== 名称卡片 ====================

class _NameCard extends StatelessWidget {
  const _NameCard({required this.item, required this.isDark});
  final LeaderboardItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            SelectableText(
              item.name,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color:
                    isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            if (item.submitterName != null) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  final uid = item.submitterId ?? item.submittedBy;
                  if (uid.isNotEmpty) context.goToUserProfile(uid);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.skeletonBase,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AvatarView(
                        imageUrl: item.submitterAvatar,
                        name: item.submitterName,
                        size: 24,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n
                            .leaderboardSubmittedBy(item.submitterName ?? ''),
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondaryLight),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          size: 14, color: AppColors.textTertiaryLight),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== 统计行 ====================

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.item});
  final LeaderboardItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 净得分
          Column(
            children: [
              Text(
                '${item.netVotes}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color:
                      item.netVotes >= 0 ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(height: 2),
              Text(context.l10n.leaderboardCurrentScore,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondaryLight)),
            ],
          ),
          _verticalDivider(),
          // 总票数
          Column(
            children: [
              Text(
                '${item.upvotes + item.downvotes}',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(context.l10n.leaderboardTotalVotesCount,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textSecondaryLight)),
            ],
          ),
          if (item.rank != null) ...[
            _verticalDivider(),
            Column(
              children: [
                Text(
                  '#${item.rank}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(context.l10n.leaderboardRank,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondaryLight)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: 1,
        height: 30,
        color: AppColors.separatorLight.withValues(alpha: 0.3),
      ),
    );
  }
}

// ==================== 描述卡片 ====================

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.description, required this.isDark});
  final String description;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.leaderboardDetails,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              description,
              style: TextStyle(
                fontSize: 15,
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

// ==================== 联系方式卡片 ====================

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.item, required this.isDark});
  final LeaderboardItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.leaderboardContactInfoDetail,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 地址
            if (item.address != null && item.address!.isNotEmpty)
              _ContactRow(
                icon: Icons.location_on_outlined,
                text: item.address!,
                onTap: () => _openMap(item.address!),
                onLongPress: () => _copy(context, item.address!),
              ),

            // 电话
            if (item.phone != null && item.phone!.isNotEmpty)
              _ContactRow(
                icon: Icons.phone_outlined,
                text: item.phone!,
                onTap: () => _callPhone(item.phone!),
                onLongPress: () => _copy(context, item.phone!),
              ),

            // 网站
            if (item.website != null && item.website!.isNotEmpty)
              _ContactRow(
                icon: Icons.language_outlined,
                text: item.website!,
                onTap: () => _openUrl(context, item.website!),
                onLongPress: () => _copy(context, item.website!),
              ),
          ],
        ),
      ),
    );
  }

  void _openMap(String address) {
    final encoded = Uri.encodeComponent(address);
    launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded'));
  }

  void _callPhone(String phone) {
    launchUrl(Uri.parse('tel:$phone'));
  }

  void _openUrl(BuildContext context, String url) {
    final uri = url.startsWith('http') ? url : 'https://$url';
    ExternalWebView.openInApp(context, url: uri);
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.leaderboardCopied),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.text,
    required this.onTap,
    required this.onLongPress,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        AppHaptics.medium();
        onLongPress();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: AppTypography.body.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 16, color: AppColors.textTertiaryLight),
          ],
        ),
      ),
    );
  }
}

// ==================== 评论区 ====================

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({required this.votes, required this.isDark});
  final List<Map<String, dynamic>> votes;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // 只显示有评论的投票
    final withComments =
        votes.where((v) => v['comment'] != null && (v['comment'] as String).isNotEmpty).toList();

    if (withComments.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.leaderboardComments,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${withComments.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...withComments.map((vote) => _CommentCard(vote: vote, isDark: isDark)),
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.vote, required this.isDark});
  final Map<String, dynamic> vote;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isAnonymous =
        vote['is_anonymous'] == true || vote['is_anonymous'] == 1;
    final author = vote['author'] as Map<String, dynamic>?;
    final authorId = author?['id'] ?? vote['voter_id'];
    final authorNameRaw =
        author?['name'] as String? ?? vote['voter_name'] as String?;
    final authorAvatar =
        author?['avatar'] as String? ?? vote['voter_avatar'] as String?;
    final displayName = isAnonymous
        ? context.l10n.leaderboardAnonymousUser
        : (authorNameRaw ?? '');
    final voteType = vote['vote_type'] as String? ?? '';
    final comment = vote['comment'] as String? ?? '';
    final likeCount = (vote['like_count'] as int?) ?? 0;
    final isLiked = vote['is_liked'] == true || vote['user_liked'] == true;
    final voteId = vote['id'] as int?;
    final createdAt = vote['created_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : AppColors.skeletonBase.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作者行：匿名用 any 头像 + 显示「匿名用户」
          Row(
            children: [
              AvatarView(
                imageUrl: isAnonymous ? null : authorAvatar,
                name: isAnonymous ? null : authorNameRaw,
                size: 28,
                isAnonymous: isAnonymous,
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (!isAnonymous && authorId != null) {
                    context.goToUserProfile(authorId.toString());
                  }
                },
                child: Text(
                  displayName,
                  style: AppTypography.bodyBold.copyWith(fontSize: 13),
                ),
              ),
              const SizedBox(width: 6),
              // 投票类型标签
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: voteType == 'upvote'
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  voteType == 'upvote'
                      ? context.l10n.leaderboardSupport
                      : context.l10n.leaderboardOppose,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: voteType == 'upvote'
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ),
              const Spacer(),
              // 时间
              if (createdAt != null)
                Text(
                  _formatTime(context, createdAt),
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiaryLight, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 评论内容
          SelectableText(
            comment,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textPrimaryLight,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          // 点赞
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                if (voteId != null) {
                  AppHaptics.selection();
                  context
                      .read<LeaderboardBloc>()
                      .add(LeaderboardLikeVote(voteId));
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 14,
                    color: isLiked
                        ? AppColors.error
                        : AppColors.textTertiaryLight,
                  ),
                  if (likeCount > 0) ...[
                    const SizedBox(width: 3),
                    Text(
                      '$likeCount',
                      style: AppTypography.caption.copyWith(
                        color: isLiked
                            ? AppColors.error
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(BuildContext context, String dateStr) {
    try {
      final l10n = context.l10n;
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return l10n.timeJustNow;
      if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
      if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
      if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
      return DateFormat('MM/dd').format(date);
    } catch (_) {
      return '';
    }
  }
}

// ==================== 图片区域 ====================

class _ImageSection extends StatefulWidget {
  const _ImageSection({required this.images});
  final List<String> images;

  @override
  State<_ImageSection> createState() => _ImageSectionState();
}

class _ImageSectionState extends State<_ImageSection> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryLight,
              AppColors.primaryLight.withValues(alpha: 0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library,
                size: 48,
                color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(context.l10n.leaderboardNoImages,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textTertiaryLight)),
          ],
        ),
      );
    }

    final aspectHeight = MediaQuery.of(context).size.width * 17 / 20;

    return SizedBox(
      height: aspectHeight.clamp(200, 400).toDouble(),
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  pushWithSwipeBack(
                    context,
                    FullScreenImageView(
                      images: widget.images,
                      initialIndex: index,
                    ),
                  );
                },
                child: AsyncImageView(
                  imageUrl: widget.images[index],
                  width: double.infinity,
                  height: double.infinity,
                ),
              );
            },
          ),
          if (widget.images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 50,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        List.generate(widget.images.length, (index) {
                      final isSelected = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: isSelected ? 8 : 6,
                        height: isSelected ? 8 : 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
