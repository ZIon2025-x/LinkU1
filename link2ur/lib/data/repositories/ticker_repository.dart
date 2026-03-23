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
