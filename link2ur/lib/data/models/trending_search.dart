import 'package:equatable/equatable.dart';

class TrendingSearchItem extends Equatable {
  final int rank;
  final String keyword;
  final String heatDisplay;
  final int viewCount;
  final String? tag; // "hot", "new", "up", or null

  const TrendingSearchItem({
    required this.rank,
    required this.keyword,
    required this.heatDisplay,
    this.viewCount = 0,
    this.tag,
  });

  /// 根据 locale 格式化浏览量展示
  String localizedHeatDisplay(String suffix) {
    if (viewCount >= 10000) {
      final val = viewCount / 10000;
      return '${_formatNum(val)}w$suffix';
    } else if (viewCount >= 1000) {
      final val = viewCount / 1000;
      return '${_formatNum(val)}k$suffix';
    }
    return '$viewCount$suffix';
  }

  /// 格式化数字：去除尾部多余的 0 和小数点（与后端 Python rstrip 逻辑一致）
  static String _formatNum(double val) {
    if (val == val.truncateToDouble()) return val.toInt().toString();
    var s = val.toStringAsFixed(1);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  factory TrendingSearchItem.fromJson(Map<String, dynamic> json) {
    return TrendingSearchItem(
      rank: json['rank'] as int? ?? 0,
      keyword: json['keyword'] as String? ?? '',
      heatDisplay: json['heat_display'] as String? ?? '',
      viewCount: json['view_count'] as int? ?? 0,
      tag: json['tag'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'rank': rank,
    'keyword': keyword,
    'heat_display': heatDisplay,
    'view_count': viewCount,
    'tag': tag,
  };

  @override
  List<Object?> get props => [rank, keyword, heatDisplay, viewCount, tag];
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
