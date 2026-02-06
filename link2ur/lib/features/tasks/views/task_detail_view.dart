import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/skeleton_view.dart';

/// 任务详情页
/// 参考iOS TaskDetailView.swift
class TaskDetailView extends StatefulWidget {
  const TaskDetailView({
    super.key,
    required this.taskId,
  });

  final int taskId;

  @override
  State<TaskDetailView> createState() => _TaskDetailViewState();
}

class _TaskDetailViewState extends State<TaskDetailView> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  Future<void> _loadTask() async {
    // TODO: 加载任务详情
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // TODO: 分享
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {
              // TODO: 更多操作
            },
          ),
        ],
      ),
      body: _isLoading ? const SkeletonDetail() : _buildContent(),
      bottomNavigationBar: _isLoading ? null : _buildBottomBar(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片轮播
          _buildImageCarousel(),

          Padding(
            padding: AppSpacing.allMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题和状态
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '示例任务标题 ${widget.taskId}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: AppRadius.allTiny,
                      ),
                      child: const Text(
                        '招募中',
                        style: TextStyle(color: AppColors.success),
                      ),
                    ),
                  ],
                ),
                AppSpacing.vMd,

                // 价格
                Text(
                  '\$${widget.taskId * 20}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                AppSpacing.vLg,

                // 任务信息卡片
                _buildInfoCard(),
                AppSpacing.vMd,

                // 任务描述
                _buildDescriptionCard(),
                AppSpacing.vMd,

                // 发布者信息
                _buildPosterCard(),
                AppSpacing.vXxl,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel() {
    return Container(
      height: 250,
      color: AppColors.skeletonBase,
      child: PageView.builder(
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            color: AppColors.skeletonBase,
            child: Center(
              child: Icon(
                Icons.image,
                size: 64,
                color: AppColors.textTertiaryLight,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard() {
    return AppCard(
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.category_outlined,
            label: '任务类型',
            value: '代取代送',
          ),
          const Divider(height: 24),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: '任务地点',
            value: '校园内',
          ),
          const Divider(height: 24),
          _InfoRow(
            icon: Icons.access_time,
            label: '截止时间',
            value: '3天后',
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '任务描述',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.vMd,
          Text(
            '这是一个示例任务的详细描述。任务发布者会在这里详细说明任务的具体要求、注意事项等信息。'
            '接单者需要仔细阅读这些信息，确保能够完成任务后再申请接单。',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterCard() {
    return AppCard(
      child: Row(
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
                const Text(
                  '发布者名称',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.star, size: 14, color: AppColors.gold),
                    const SizedBox(width: 4),
                    Text(
                      '4.8',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '发布12个任务',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
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
        child: Row(
          children: [
            // 收藏按钮
            IconActionButton(
              icon: Icons.favorite_border,
              onPressed: () {
                // TODO: 收藏
              },
              backgroundColor: AppColors.skeletonBase,
            ),
            AppSpacing.hMd,
            // 聊天按钮
            IconActionButton(
              icon: Icons.chat_bubble_outline,
              onPressed: () {
                // TODO: 聊天
              },
              backgroundColor: AppColors.skeletonBase,
            ),
            AppSpacing.hMd,
            // 申请按钮
            Expanded(
              child: PrimaryButton(
                text: '申请接单',
                onPressed: () {
                  // TODO: 申请接单
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondaryLight),
        AppSpacing.hMd,
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
