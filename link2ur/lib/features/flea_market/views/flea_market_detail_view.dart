import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/buttons.dart';

/// 跳蚤市场商品详情页
/// 参考iOS FleaMarketDetailView.swift
class FleaMarketDetailView extends StatelessWidget {
  const FleaMarketDetailView({
    super.key,
    required this.itemId,
  });

  final int itemId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('商品详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片
            Container(
              height: 300,
              color: AppColors.skeletonBase,
              child: const Center(
                child: Icon(Icons.image, size: 64, color: AppColors.textTertiaryLight),
              ),
            ),
            
            Padding(
              padding: AppSpacing.allMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 价格
                  Text(
                    '\$${itemId * 25}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  AppSpacing.vMd,
                  
                  // 标题
                  Text(
                    '商品标题 $itemId',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppSpacing.vLg,
                  
                  // 描述
                  Text(
                    '商品描述信息...',
                    style: TextStyle(
                      color: AppColors.textSecondaryLight,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
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
          child: Row(
            children: [
              IconActionButton(
                icon: Icons.chat_bubble_outline,
                onPressed: () {},
                backgroundColor: AppColors.skeletonBase,
              ),
              AppSpacing.hMd,
              Expanded(
                child: PrimaryButton(
                  text: '立即购买',
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
