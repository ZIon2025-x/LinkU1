import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/cards.dart';
import '../../auth/bloc/auth_bloc.dart';

/// 个人中心页
/// 参考iOS ProfileView.swift
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (!state.isAuthenticated) {
          return _buildNotLoggedIn(context);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('我的'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: AppSpacing.allMd,
            child: Column(
              children: [
                // 用户信息卡片
                _buildUserCard(context, state),
                AppSpacing.vLg,

                // 统计数据
                _buildStatsRow(context),
                AppSpacing.vLg,

                // 功能列表
                _buildMenuSection(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotLoggedIn(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_circle_outlined,
              size: 80,
              color: AppColors.textTertiaryLight,
            ),
            AppSpacing.vMd,
            const Text(
              '登录后查看个人信息',
              style: TextStyle(color: AppColors.textSecondaryLight),
            ),
            AppSpacing.vLg,
            ElevatedButton(
              onPressed: () => context.push('/login'),
              child: const Text('立即登录'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, AuthState state) {
    final user = state.user!;

    return GestureDetector(
      onTap: () => context.push('/profile/edit'),
      child: AppCard(
        child: Row(
          children: [
            // 头像
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: const Icon(Icons.person, color: AppColors.primary, size: 36),
            ),
            AppSpacing.hMd,
            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (user.isVerified) ...[
                        AppSpacing.hSm,
                        Icon(Icons.verified, color: AppColors.primary, size: 18),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? 'ID: ${user.id}',
                    style: TextStyle(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiaryLight),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatItem(
            value: '12',
            label: '发布任务',
            onTap: () => context.push('/profile/my-tasks'),
          ),
        ),
        Expanded(
          child: _StatItem(
            value: '8',
            label: '完成任务',
            onTap: () => context.push('/profile/my-tasks'),
          ),
        ),
        Expanded(
          child: _StatItem(
            value: '4.9',
            label: '评分',
            onTap: () {},
          ),
        ),
        Expanded(
          child: _StatItem(
            value: '\$120',
            label: '余额',
            onTap: () => context.push('/wallet'),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    return Column(
      children: [
        GroupedCard(
          children: [
            _MenuItem(
              icon: Icons.task_alt,
              title: '我的任务',
              onTap: () => context.push('/profile/my-tasks'),
            ),
            _MenuItem(
              icon: Icons.article_outlined,
              title: '我的帖子',
              onTap: () => context.push('/profile/my-posts'),
            ),
            _MenuItem(
              icon: Icons.storefront_outlined,
              title: '我的闲置',
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.favorite_outline,
              title: '我的收藏',
              onTap: () {},
            ),
          ],
        ),
        AppSpacing.vMd,
        GroupedCard(
          children: [
            _MenuItem(
              icon: Icons.account_balance_wallet_outlined,
              title: '我的钱包',
              onTap: () => context.push('/wallet'),
            ),
            _MenuItem(
              icon: Icons.school_outlined,
              title: '学生认证',
              onTap: () => context.push('/student-verification'),
            ),
            _MenuItem(
              icon: Icons.card_giftcard_outlined,
              title: '优惠券',
              onTap: () {},
            ),
          ],
        ),
        AppSpacing.vMd,
        GroupedCard(
          children: [
            _MenuItem(
              icon: Icons.help_outline,
              title: '帮助中心',
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.info_outline,
              title: '关于我们',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: AppRadius.allMedium,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textSecondaryLight),
            AppSpacing.hMd,
            Expanded(
              child: Text(title, style: const TextStyle(fontSize: 16)),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiaryLight),
          ],
        ),
      ),
    );
  }
}
