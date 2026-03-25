import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/router/go_router_extensions.dart';
import '../../../core/utils/l10n_extension.dart';

/// AI 工具结果的水平滚动卡片列表（支持任务、服务、达人、跳蚤商品、帖子等）
class TaskResultCards extends StatelessWidget {
  const TaskResultCards({
    super.key,
    required this.toolResult,
  });

  final Map<String, dynamic> toolResult;

  @override
  Widget build(BuildContext context) {
    // 尝试从不同字段提取列表数据
    final List<dynamic>? items = _extractItems();
    if (items == null || items.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardType = _detectCardType();

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md + 40, // align with AI bubble (avatar + gap)
        right: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: SizedBox(
        height: 128,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) {
            final item = items[index] as Map<String, dynamic>;
            return _ResultCard(data: item, isDark: isDark, cardType: cardType);
          },
        ),
      ),
    );
  }

  List<dynamic>? _extractItems() {
    for (final key in ['tasks', 'services', 'experts', 'items', 'posts', 'candidates']) {
      final val = toolResult[key];
      if (val is List && val.isNotEmpty) return val;
    }
    return null;
  }

  _CardType _detectCardType() {
    if (toolResult.containsKey('tasks')) return _CardType.task;
    if (toolResult.containsKey('services')) return _CardType.service;
    if (toolResult.containsKey('experts')) return _CardType.expert;
    if (toolResult.containsKey('items')) return _CardType.fleaMarket;
    if (toolResult.containsKey('posts')) return _CardType.forumPost;
    if (toolResult.containsKey('candidates')) return _CardType.candidate;
    return _CardType.task;
  }
}

enum _CardType { task, service, expert, fleaMarket, forumPost, candidate }

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.data,
    required this.isDark,
    required this.cardType,
  });

  final Map<String, dynamic> data;
  final bool isDark;
  final _CardType cardType;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2332) : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              _title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Subtitle (price, rating, etc.)
            if (_subtitle != null)
              Text(
                _subtitle!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),

            const Spacer(),

            // Bottom info row
            _buildBottomRow(context),

            const SizedBox(height: 4),

            // View detail hint
            Text(
              l10n.aiTaskCardViewDetail,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _title {
    switch (cardType) {
      case _CardType.task:
        return data['title'] as String? ?? '';
      case _CardType.service:
        return data['service_name'] as String? ?? '';
      case _CardType.expert:
        return data['name'] as String? ?? '';
      case _CardType.fleaMarket:
        return data['title'] as String? ?? data['name'] as String? ?? '';
      case _CardType.forumPost:
        return data['title'] as String? ?? '';
      case _CardType.candidate:
        return data['name'] as String? ?? '';
    }
  }

  String? get _subtitle {
    switch (cardType) {
      case _CardType.task:
        final reward = data['reward'];
        if (reward == null) return null;
        final currency = data['currency'] as String? ?? 'GBP';
        final symbol = currency == 'GBP' ? '£' : currency;
        return '$symbol${reward is num ? reward.toStringAsFixed(2) : reward}';
      case _CardType.service:
        final price = data['base_price'];
        if (price == null) return null;
        final currency = data['currency'] as String? ?? 'GBP';
        final symbol = currency == 'GBP' ? '£' : currency;
        return '$symbol${price is num ? price.toStringAsFixed(2) : price}';
      case _CardType.expert:
        final rating = data['rating'];
        if (rating == null || rating == 0) return null;
        return '★ $rating';
      case _CardType.fleaMarket:
        final price = data['price'] ?? data['base_price'];
        if (price == null) return null;
        final currency = data['currency'] as String? ?? 'GBP';
        final symbol = currency == 'GBP' ? '£' : currency;
        return '$symbol${price is num ? price.toStringAsFixed(2) : price}';
      case _CardType.forumPost:
        return null;
      case _CardType.candidate:
        final rating = data['avg_rating'];
        if (rating == null || rating == 0) return null;
        return '★ ${rating is num ? rating.toStringAsFixed(1) : rating}';
    }
  }

  Widget _buildBottomRow(BuildContext context) {
    final subtextColor = isDark ? Colors.white54 : Colors.black45;
    final List<Widget> chips = [];

    switch (cardType) {
      case _CardType.task:
        final taskType = data['task_type'] as String? ?? '';
        final location = data['location'] as String? ?? '';
        if (taskType.isNotEmpty) {
          chips.addAll([
            Icon(Icons.category_outlined, size: 12, color: subtextColor),
            const SizedBox(width: 2),
            Flexible(child: Text(taskType, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: subtextColor))),
          ]);
        }
        if (location.isNotEmpty) {
          if (chips.isNotEmpty) chips.add(const SizedBox(width: AppSpacing.xs));
          chips.addAll([
            Icon(Icons.location_on_outlined, size: 12, color: subtextColor),
            const SizedBox(width: 2),
            Flexible(child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: subtextColor))),
          ]);
        }
      case _CardType.service:
        final type = data['service_type'] as String? ?? '';
        final category = data['category'] as String? ?? '';
        final label = type == 'personal' ? '个人' : (type == 'expert' ? '达人' : '');
        if (label.isNotEmpty) {
          chips.addAll([
            Icon(Icons.badge_outlined, size: 12, color: subtextColor),
            const SizedBox(width: 2),
            Text(label, style: TextStyle(fontSize: 11, color: subtextColor)),
          ]);
        }
        if (category.isNotEmpty) {
          if (chips.isNotEmpty) chips.add(const SizedBox(width: AppSpacing.xs));
          chips.addAll([
            Flexible(child: Text(category, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: subtextColor))),
          ]);
        }
      case _CardType.expert:
        final tasks = data['completed_tasks'];
        if (tasks != null && tasks > 0) {
          chips.addAll([
            Icon(Icons.task_alt, size: 12, color: subtextColor),
            const SizedBox(width: 2),
            Text('$tasks', style: TextStyle(fontSize: 11, color: subtextColor)),
          ]);
        }
      case _CardType.fleaMarket:
        final category = data['category'] as String? ?? '';
        if (category.isNotEmpty) {
          chips.addAll([
            Icon(Icons.category_outlined, size: 12, color: subtextColor),
            const SizedBox(width: 2),
            Flexible(child: Text(category, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: subtextColor))),
          ]);
        }
      case _CardType.forumPost:
        final category = data['category_name'] as String? ?? '';
        final likes = data['likes'] ?? data['like_count'];
        if (category.isNotEmpty) {
          chips.addAll([
            Icon(Icons.forum_outlined, size: 12, color: subtextColor),
            const SizedBox(width: 2),
            Flexible(child: Text(category, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: subtextColor))),
          ]);
        }
        if (likes != null && likes > 0) {
          if (chips.isNotEmpty) chips.add(const SizedBox(width: AppSpacing.xs));
          chips.addAll([
            Icon(Icons.thumb_up_outlined, size: 12, color: subtextColor),
            const SizedBox(width: 2),
            Text('$likes', style: TextStyle(fontSize: 11, color: subtextColor)),
          ]);
        }
      case _CardType.candidate:
        final similarCount = data['similar_task_count'];
        final reasons = data['reasons'] as List<dynamic>?;
        if (similarCount != null && similarCount > 0) {
          chips.addAll([
            Icon(Icons.task_alt, size: 12, color: subtextColor),
            const SizedBox(width: 2),
            Text('$similarCount', style: TextStyle(fontSize: 11, color: subtextColor)),
          ]);
        }
        if (reasons != null && reasons.isNotEmpty) {
          if (chips.isNotEmpty) chips.add(const SizedBox(width: AppSpacing.xs));
          chips.add(Flexible(child: Text(
            reasons.first.toString(),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: subtextColor),
          )));
        }
    }

    return Row(children: chips);
  }

  void _onTap(BuildContext context) {
    final id = data['id'];
    switch (cardType) {
      case _CardType.task:
        if (id is int) context.goToTaskDetail(id);
      case _CardType.service:
        // Service detail not directly navigable; go to expert detail if available
        final expertId = data['expert_id'] as String?;
        if (expertId != null) context.goToTaskExpertDetail(expertId);
      case _CardType.expert:
        if (id is String) context.goToTaskExpertDetail(id);
      case _CardType.fleaMarket:
        if (id != null) context.goToFleaMarketDetail(id.toString());
      case _CardType.forumPost:
        if (id is int) context.goToForumPostDetail(id);
      case _CardType.candidate:
        final userId = data['user_id'] as String?;
        if (userId != null) context.goToUserProfile(userId);
    }
  }
}
