import 'package:equatable/equatable.dart';

class TrendingSearchItem extends Equatable {
  final int rank;
  final String keyword;
  final String heatDisplay;
  final String? tag; // "hot", "new", "up", or null

  const TrendingSearchItem({
    required this.rank,
    required this.keyword,
    required this.heatDisplay,
    this.tag,
  });

  factory TrendingSearchItem.fromJson(Map<String, dynamic> json) {
    return TrendingSearchItem(
      rank: json['rank'] as int? ?? 0,
      keyword: json['keyword'] as String? ?? '',
      heatDisplay: json['heat_display'] as String? ?? '',
      tag: json['tag'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'keyword': keyword,
    'heat_display': heatDisplay,
    'tag': tag,
  };

  @override
  List<Object?> get props => [rank, keyword, heatDisplay, tag];
}

class TrendingSearchResponse extends Equatable {
  final List<TrendingSearchItem> items;
  final String? updatedAt;

  const TrendingSearchResponse({
    required this.items,
    this.updatedAt,
  });

  factory TrendingSearchResponse.fromJson(Map<String, dynamic> json) {
    return TrendingSearchResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => TrendingSearchItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      updatedAt: json['updated_at'] as String?,
    );
  }

  @override
  List<Object?> get props => [items, updatedAt];
}
