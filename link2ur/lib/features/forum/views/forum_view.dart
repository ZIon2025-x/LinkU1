import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';

/// 论坛页
/// 参考iOS ForumView.swift
class ForumView extends StatelessWidget {
  const ForumView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('社区'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '论坛'),
              Tab(text: '排行榜'),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondaryLight,
            indicatorColor: AppColors.primary,
          ),
        ),
        body: const TabBarView(
          children: [
            _ForumTab(),
            _LeaderboardTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            context.push('/forum/posts/create');
          },
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ),
    );
  }
}

class _ForumTab extends StatelessWidget {
  const _ForumTab();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: AppSpacing.allMd,
      itemCount: 10,
      separatorBuilder: (context, index) => AppSpacing.vMd,
      itemBuilder: (context, index) {
        return _PostCard(index: index);
      },
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: AppSpacing.allMd,
      itemCount: 5,
      separatorBuilder: (context, index) => AppSpacing.vMd,
      itemBuilder: (context, index) {
        return _LeaderboardCard(index: index);
      },
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/forum/posts/${index + 1}');
      },
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息
            Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                AppSpacing.hSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('用户 ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('2小时前', style: TextStyle(fontSize: 12, color: AppColors.textTertiaryLight)),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.vMd,
            
            // 标题
            Text(
              '帖子标题 ${index + 1}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            AppSpacing.vSm,
            
            // 内容
            Text(
              '帖子内容摘要...',
              style: TextStyle(color: AppColors.textSecondaryLight),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            AppSpacing.vMd,
            
            // 互动
            Row(
              children: [
                Icon(Icons.thumb_up_outlined, size: 16, color: AppColors.textTertiaryLight),
                const SizedBox(width: 4),
                Text('${(index + 1) * 12}', style: TextStyle(fontSize: 12, color: AppColors.textTertiaryLight)),
                const SizedBox(width: 16),
                Icon(Icons.comment_outlined, size: 16, color: AppColors.textTertiaryLight),
                const SizedBox(width: 4),
                Text('${(index + 1) * 5}', style: TextStyle(fontSize: 12, color: AppColors.textTertiaryLight)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/leaderboard/${index + 1}');
      },
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.allMedium,
              ),
              child: const Icon(Icons.leaderboard, color: AppColors.primary),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('排行榜 ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('${(index + 1) * 20} 个竞品', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiaryLight),
          ],
        ),
      ),
    );
  }
}
