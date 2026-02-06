import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/buttons.dart';

/// 任务达人详情页
/// 参考iOS TaskExpertDetailView.swift
class TaskExpertDetailView extends StatelessWidget {
  const TaskExpertDetailView({
    super.key,
    required this.expertId,
  });

  final int expertId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('达人详情'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 头部信息
            Container(
              padding: AppSpacing.allXl,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, color: AppColors.primary, size: 50),
                  ),
                  AppSpacing.vMd,
                  Text(
                    '达人 $expertId',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppSpacing.vSm,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, size: 16, color: AppColors.gold),
                      const SizedBox(width: 4),
                      const Text('4.9'),
                      const SizedBox(width: 16),
                      const Text('完成 50 单'),
                    ],
                  ),
                ],
              ),
            ),
            
            // 服务列表
            Padding(
              padding: AppSpacing.allMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '提供的服务',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.vMd,
                  ...List.generate(3, (index) => _ServiceItem(index: index)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceItem extends StatelessWidget {
  const _ServiceItem({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '服务项目 ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${(index + 1) * 30}/次',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SmallActionButton(
            text: '预约',
            onPressed: () {},
            filled: true,
          ),
        ],
      ),
    );
  }
}
