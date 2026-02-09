import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/full_screen_image_view.dart';
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
      )..add(LeaderboardLoadItemDetail(itemId)),
      child: _ItemDetailContent(itemId: itemId),
    );
  }
}

class _ItemDetailContent extends StatelessWidget {
  const _ItemDetailContent({required this.itemId});
  final int itemId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<LeaderboardBloc, LeaderboardState>(
      builder: (context, state) {
        final item = state.itemDetail;
        final hasImages = item != null &&
            item['images'] is List &&
            (item['images'] as List).isNotEmpty;

        return Scaffold(
          extendBodyBehindAppBar: hasImages,
          appBar: _buildAppBar(context, l10n, hasImages),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ResponsiveUtils.detailMaxWidth(context)),
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
      BuildContext context, dynamic l10n, bool hasImages) {
    if (!hasImages) {
      return AppBar(
        title: Text(l10n.leaderboardItemDetail),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              HapticFeedback.selectionClick();
            },
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
            onTap: () {
              HapticFeedback.selectionClick();
            },
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
    if (state.isLoading) return const SkeletonDetail();

    if (state.errorMessage != null) {
      return ErrorStateView(
        message: state.errorMessage!,
        onRetry: () => context
            .read<LeaderboardBloc>()
            .add(LeaderboardLoadItemDetail(itemId)),
      );
    }

    final item = state.itemDetail;
    if (item == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final images =
        item['images'] is List ? (item['images'] as List).cast<String>() : <String>[];
    final name = item['name'] as String? ?? '';
    final description = item['description'] as String?;
    final rank = item['rank'];
    final upvotes = item['upvotes'] ?? 0;
    final downvotes = item['downvotes'] ?? 0;
    final netVotes = (upvotes as int) - (downvotes as int);

    return SingleChildScrollView(
      child: Column(
        children: [
          // 图片区域 - 对标iOS image TabView
          _ImageSection(images: images),

          // 主信息卡片 - 对标iOS overlapping card with radius 24
          Transform.translate(
            offset: const Offset(0, -40),
            child: Column(
              children: [
                // 名称卡片
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.cardBackgroundDark
                          : AppColors.cardBackgroundLight,
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
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // 提交者行
                        if (item['submitter_name'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.skeletonBase,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundImage:
                                      item['submitter_avatar'] != null
                                          ? NetworkImage(
                                              item['submitter_avatar']
                                                  as String)
                                          : null,
                                  child: item['submitter_avatar'] == null
                                      ? const Icon(Icons.person, size: 12)
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  context.l10n.leaderboardSubmittedBy(item['submitter_name'] ?? ''),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right,
                                    size: 14,
                                    color: AppColors.textTertiaryLight),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // 统计行 - 对标iOS stats section
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 净得分
                      Column(
                        children: [
                          Text(
                            '$netVotes',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: netVotes >= 0
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(context.l10n.leaderboardCurrentScore,
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondaryLight)),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24),
                        child: Container(
                          width: 1,
                          height: 30,
                          color: AppColors.separatorLight
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      // 总票数
                      Column(
                        children: [
                          Text(
                            '${upvotes + downvotes}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(context.l10n.leaderboardTotalVotesCount,
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondaryLight)),
                        ],
                      ),
                      if (rank != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24),
                          child: Container(
                            width: 1,
                            height: 30,
                            color: AppColors.separatorLight
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '#$rank',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(context.l10n.leaderboardRank,
                                style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondaryLight)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 描述卡片 - 对标iOS description card with left bar
                if (description != null && description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md),
                    child: Container(
                      width: double.infinity,
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
                                  borderRadius:
                                      BorderRadius.circular(2),
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
                          Text(
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
                  ),

                const SizedBox(height: 140),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 底部投票栏 - 对标iOS two pills (oppose/support) with material
  Widget _buildVoteBar(BuildContext context, LeaderboardState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = state.itemDetail;
    final userVote = item?['user_vote'] as String?;
    final hasUpvoted = userVote == 'up';
    final hasDownvoted = userVote == 'down';

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
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context
                            .read<LeaderboardBloc>()
                            .add(LeaderboardVoteItem(itemId));
                      },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: hasDownvoted
                              ? AppColors.error
                              : AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.thumb_down,
                              size: 20,
                              color: hasDownvoted
                                  ? Colors.white
                                  : AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.leaderboardOppose,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: hasDownvoted
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
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context
                            .read<LeaderboardBloc>()
                            .add(LeaderboardVoteItem(itemId));
                      },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: hasUpvoted
                              ? AppColors.success
                              : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.thumb_up,
                              size: 20,
                              color: hasUpvoted
                                  ? Colors.white
                                  : AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.leaderboardSupport,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: hasUpvoted
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
            Icon(Icons.photo_library, size: 48,
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
            onPageChanged: (index) =>
                setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FullScreenImageView(
                      images: widget.images,
                      initialIndex: index,
                    ),
                  ));
                },
                child: AsyncImageView(
                  imageUrl: widget.images[index],
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),

          // 页面指示器
          if (widget.images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 50,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(widget.images.length, (index) {
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
