import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/features/tasks/views/consultation/flea_market_consultation_actions.dart';

void main() {
  group('FleaMarketConsultationActions.onFormalApply contract', () {
    test('asserts price/message are null in debug builds', () {
      // FleaMarket 的 formal-apply 是纯确认购买(无价格/消息)。
      // 基类签名为兼容 Service/Task 而保留 price/message,但 FleaMarket
      // 的实现在 debug 构建下会 assert 强制这两个参数为 null,
      // 防止未来误用导致数据静默丢失。
      final actions = FleaMarketConsultationActions(
        applicationId: 1,
        taskId: 10,
      );
      final ctx = _NullContext();

      expect(
        () => actions.onFormalApply(ctx, price: 100.0),
        throwsA(isA<AssertionError>()),
        reason: 'FleaMarket onFormalApply must reject non-null price',
      );

      expect(
        () => actions.onFormalApply(ctx, message: 'hello'),
        throwsA(isA<AssertionError>()),
        reason: 'FleaMarket onFormalApply must reject non-null message',
      );

      expect(
        () => actions.onFormalApply(ctx, price: 50.0, message: 'both'),
        throwsA(isA<AssertionError>()),
        reason: 'FleaMarket onFormalApply must reject both',
      );
    });
  });
}

/// BuildContext 的 minimal stub。assert 在读取 context.read 之前抛出,
/// 所以 stub 只需要满足类型即可。
class _NullContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
