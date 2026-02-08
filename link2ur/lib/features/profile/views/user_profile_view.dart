import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/stat_item.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../bloc/profile_bloc.dart';

/// 公开用户资料页
/// 参考iOS UserProfileView.swift
class UserProfileView extends StatefulWidget {
  const UserProfileView({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: context.read<UserRepository>(),
        taskRepository: context.read<TaskRepository>(),
        forumRepository: context.read<ForumRepository>(),
      )..add(ProfileLoadPublicProfile(widget.userId)),
      child: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.profileUserProfile),
            ),
            body: state.isLoading
                ? const LoadingView()
                : state.errorMessage != null
                    ? ErrorStateView(
                        message: state.errorMessage!,
                        onRetry: () {
                          context.read<ProfileBloc>().add(
                                ProfileLoadPublicProfile(widget.userId),
                              );
                        },
                      )
                    : state.publicUser == null
                        ? const SizedBox.shrink()
                        : RefreshIndicator(
                            onRefresh: () async {
                              context.read<ProfileBloc>().add(
                                    ProfileLoadPublicProfile(widget.userId),
                                  );
                            },
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  // 用户信息卡片
                                  _buildUserInfoCard(context, state.publicUser!),
                                  // 统计数据
                                  _buildStatsRow(context, state.publicUser!),
                                  // 近期任务
                                  _buildRecentTasksSection(context),
                                  const SizedBox(height: AppSpacing.xl),
                                ],
                              ),
                            ),
                          ),
          );
        },
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context, User user) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 头像
          CircleAvatar(
            radius: 44,
            backgroundImage: user.avatar != null
                ? NetworkImage(user.avatar!)
                : null,
            child: user.avatar == null
                ? const Icon(Icons.person, size: 44)
                : null,
          ),
          const SizedBox(height: AppSpacing.md),

          // 名称 + 徽章
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                user.displayName,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, color: AppColors.primary, size: 20),
              ],
              if (user.isStudentVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.school, color: Colors.blue, size: 20),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // 简介
          if (user.bio != null && user.bio!.isNotEmpty)
            Text(
              user.bio!,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

          // 居住城市
          if (user.residenceCity != null &&
              user.residenceCity!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  user.residenceCity!,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textTertiary),
                ),
              ],
            ),
          ],

          // 评分
          if (user.avgRating != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  user.ratingDisplay,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, User user) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: StatItem(
              label: l10n.profileTaskCount,
              value: '${user.taskCount}',
              icon: Icons.assignment,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: StatItem(
              label: l10n.profileCompletedTasks,
              value: '${user.completedTaskCount}',
              icon: Icons.check_circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: StatItem(
              label: l10n.profileRating,
              value: user.ratingDisplay,
              icon: Icons.star,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTasksSection(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(l10n.profileRecentTasks,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 近期任务列表占位 - 实际应从API加载
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Center(
              child: Text(
                l10n.profileNoRecentTasks,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
