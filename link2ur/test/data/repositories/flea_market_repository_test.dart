import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/core/constants/api_endpoints.dart';
import 'package:link2ur/core/utils/cache_manager.dart';
import 'package:link2ur/data/repositories/flea_market_repository.dart';
import 'package:link2ur/data/services/api_service.dart';

import '../../helpers/test_helpers.dart';

/// 验证 `FleaMarketRepository.getMyRelatedFleaItems` 按 `type` 参数
/// 正确组装 queryParameters。
///
/// 对应后端 `GET /api/flea-market/my-related-items?type=rental|sale`
/// 合并「我发布的 + 我的租赁」后的前端筛选。
void main() {
  late MockApiService mockApiService;
  late FleaMarketRepository repo;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockApiService = MockApiService();
    repo = FleaMarketRepository(apiService: mockApiService);

    // 清掉可能残留的内存缓存，避免同一测试进程中污染下一次调用
    CacheManager.shared.invalidateMyFleaMarketCache();

    // 默认返回一个空 items 响应，让 repo 正常走完流程
    when(() => mockApiService.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => ApiResponse.success(
          data: <String, dynamic>{'items': <dynamic>[]},
          statusCode: 200,
        ));
  });

  group('FleaMarketRepository.getMyRelatedFleaItems - type query param', () {
    test('without type passes null queryParameters', () async {
      await repo.getMyRelatedFleaItems(forceRefresh: true);

      final captured = verify(() => mockApiService.get<Map<String, dynamic>>(
            ApiEndpoints.fleaMarketMyRelatedItems,
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;

      expect(captured, isNotEmpty);
      expect(captured.single, isNull,
          reason: '省略 type 时应传 null，保持向后兼容的行为');
    });

    test("with type='rental' passes {'type':'rental'} queryParameters",
        () async {
      await repo.getMyRelatedFleaItems(forceRefresh: true, type: 'rental');

      final captured = verify(() => mockApiService.get<Map<String, dynamic>>(
            ApiEndpoints.fleaMarketMyRelatedItems,
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;

      expect(captured, isNotEmpty);
      expect(captured.single, isA<Map<String, dynamic>>());
      expect(captured.single, {'type': 'rental'});
    });

    test("with type='sale' passes {'type':'sale'} queryParameters", () async {
      await repo.getMyRelatedFleaItems(forceRefresh: true, type: 'sale');

      final captured = verify(() => mockApiService.get<Map<String, dynamic>>(
            ApiEndpoints.fleaMarketMyRelatedItems,
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured;

      expect(captured.single, {'type': 'sale'});
    });
  });
}
