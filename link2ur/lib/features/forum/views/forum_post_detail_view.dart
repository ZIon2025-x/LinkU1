import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';

/// 帖子详情页
/// 参考iOS ForumPostDetailView.swift
class ForumPostDetailView extends StatelessWidget {
  const ForumPostDetailView({
    super.key,
    required this.postId,
  });

  final int postId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('帖子详情'),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.allMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('用户 $postId', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('2小时前', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.vLg,
            
            // 标题
            Text(
              '帖子标题 $postId',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            AppSpacing.vMd,
            
            // 内容
            Text(
              '这是帖子的详细内容。用户可以在这里分享他们的想法、经验或者提问。'
              '社区成员可以通过回复和点赞来参与讨论。',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondaryLight,
                height: 1.6,
              ),
            ),
            AppSpacing.vXl,
            
            // 互动栏
            Row(
              children: [
                _ActionButton(icon: Icons.thumb_up_outlined, label: '点赞', count: postId * 15),
                AppSpacing.hLg,
                _ActionButton(icon: Icons.favorite_outline, label: '收藏', count: postId * 5),
                AppSpacing.hLg,
                _ActionButton(icon: Icons.comment_outlined, label: '评论', count: postId * 8),
              ],
            ),
            AppSpacing.vXl,
            
            // 评论列表
            const Divider(),
            AppSpacing.vMd,
            const Text('评论', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            AppSpacing.vMd,
            ...List.generate(5, (index) => _CommentItem(index: index)),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: TextField(
            decoration: InputDecoration(
              hintText: '写评论...',
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: AppColors.primary),
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondaryLight),
        const SizedBox(width: 4),
        Text('$count', style: TextStyle(color: AppColors.textSecondaryLight)),
      ],
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.skeletonBase,
            child: Icon(Icons.person, size: 18, color: AppColors.textTertiaryLight),
          ),
          AppSpacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('评论者 ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                    const SizedBox(width: 8),
                    Text('1小时前', style: TextStyle(fontSize: 12, color: AppColors.textTertiaryLight)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('这是一条评论内容...', style: TextStyle(color: AppColors.textSecondaryLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
