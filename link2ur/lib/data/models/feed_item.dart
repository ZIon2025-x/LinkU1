import 'package:equatable/equatable.dart';

import 'forum.dart';
import 'task.dart';
import 'task_expert.dart';

enum FeedItemType { post, task, service }

class FeedItem extends Equatable {
  const FeedItem({
    required this.itemType,
    required this.data,
    required this.sortScore,
    required this.createdAt,
  });

  final FeedItemType itemType;
  final dynamic data; // ForumPost | Task | TaskExpertService
  final double sortScore;
  final DateTime createdAt;

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final typeStr = json['item_type'] as String;
    final itemType = FeedItemType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => FeedItemType.post,
    );

    final rawData = json['data'] as Map<String, dynamic>;
    dynamic data;
    switch (itemType) {
      case FeedItemType.post:
        data = ForumPost.fromJson(rawData);
      case FeedItemType.task:
        data = Task.fromJson(rawData);
      case FeedItemType.service:
        data = TaskExpertService.fromJson(rawData);
    }

    return FeedItem(
      itemType: itemType,
      data: data,
      sortScore: (json['sort_score'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [itemType, sortScore, createdAt];
}

class SkillFeedResponse {
  const SkillFeedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  final List<FeedItem> items;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;

  factory SkillFeedResponse.fromJson(Map<String, dynamic> json) {
    return SkillFeedResponse(
      items: (json['items'] as List)
          .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      hasMore: json['has_more'] as bool,
    );
  }
}
