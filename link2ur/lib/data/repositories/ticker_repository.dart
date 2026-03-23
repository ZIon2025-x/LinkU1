import '../services/api_service.dart';

class TickerItem {
  TickerItem({required this.textZh, required this.textEn, this.linkType, this.linkId});

  final String textZh;
  final String textEn;
  final String? linkType;
  final String? linkId;

  factory TickerItem.fromJson(Map<String, dynamic> json) => TickerItem(
    textZh: json['text_zh'] as String? ?? '',
    textEn: json['text_en'] as String? ?? '',
    linkType: json['link_type'] as String?,
    linkId: json['link_id'] as String?,
  );

  String displayText(String locale) => locale.startsWith('en') ? textEn : textZh;

  /// Default ticker items when backend has no data
  static List<TickerItem> get defaults => [
    TickerItem(
      textZh: '👋 欢迎来到 Link²Ur，发布任务或提供技能，开始互助之旅',
      textEn: '👋 Welcome to Link²Ur — post tasks or offer skills to get started',
    ),
    TickerItem(
      textZh: '🎯 发现身边的技能达人，找到最适合你的帮手',
      textEn: '🎯 Discover skilled helpers nearby — find the perfect match',
    ),
    TickerItem(
      textZh: '💡 新用户首次发布任务享专属优惠，快来体验',
      textEn: '💡 New users get exclusive deals on first task — try it now',
    ),
  ];
}

class TickerRepository {
  TickerRepository({required ApiService apiService}) : _apiService = apiService;
  final ApiService _apiService;

  Future<List<TickerItem>> getTicker() async {
    final response = await _apiService.get<Map<String, dynamic>>('/api/feed/ticker');
    if (!response.isSuccess || response.data == null) return [];
    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => TickerItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
