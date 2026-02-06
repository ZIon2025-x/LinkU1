import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';

/// 排行榜详情页
/// 参考iOS LeaderboardDetailView.swift
class LeaderboardDetailView extends StatelessWidget {
  const LeaderboardDetailView({
    super.key,
    required this.leaderboardId,
  });

  final int leaderboardId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('排行榜 $leaderboardId'),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: ListView.separated(
        padding: AppSpacing.allMd,
        itemCount: 10,
        separatorBuilder: (context, index) => AppSpacing.vSm,
        itemBuilder: (context, index) {
          return _RankItem(rank: index + 1);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('提交竞品', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _RankItem extends StatelessWidget {
  const _RankItem({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.allMedium,
        border: isTop3 ? Border.all(color: _getRankColor(rank).withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        children: [
          // 排名
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isTop3 ? _getRankColor(rank) : AppColors.skeletonBase,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: isTop3 ? Colors.white : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          AppSpacing.hMd,
          
          // 图片
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.skeletonBase,
              borderRadius: AppRadius.allSmall,
            ),
            child: const Icon(Icons.image, color: AppColors.textTertiaryLight),
          ),
          AppSpacing.hMd,
          
          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('竞品 $rank', style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('${rank * 50} 票', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
              ],
            ),
          ),
          
          // 投票按钮
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.thumb_up_outlined),
                onPressed: () {},
                iconSize: 20,
                color: AppColors.success,
              ),
              IconButton(
                icon: const Icon(Icons.thumb_down_outlined),
                onPressed: () {},
                iconSize: 20,
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return AppColors.gold;
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return AppColors.textSecondaryLight;
    }
  }
}
