import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/flea_market_purchase_request.dart';

// ---------------------------------------------------------------------------
// Minimal JSON factory — only required fields
// ---------------------------------------------------------------------------
Map<String, dynamic> _base({
  int id = 1,
  int itemId = 10,
  String buyerId = 'u_1',
  String status = 'pending',
  int? taskId,
  int? consultationTaskId,
}) =>
    <String, dynamic>{
      'id': id,
      'item_id': itemId,
      'buyer_id': buyerId,
      'status': status,
      if (taskId != null) 'task_id': taskId,
      if (consultationTaskId != null)
        'consultation_task_id': consultationTaskId,
    };

void main() {
  // -------------------------------------------------------------------------
  // fromJson basics
  // -------------------------------------------------------------------------
  group('FleaMarketPurchaseRequest.fromJson', () {
    test('parses all basic fields from a realistic payload', () {
      final json = <String, dynamic>{
        'id': 5,
        'item_id': 20,
        'buyer_id': 'u_2',
        'buyer_name': 'Bob',
        'buyer_avatar': 'https://example.com/b.png',
        'proposed_price': 12.5,
        'seller_counter_price': 15.0,
        'message': 'interested',
        'status': 'negotiating',
        'final_price': null,
        'task_id': 101,
        'consultation_task_id': 55,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
      };
      final fmpr = FleaMarketPurchaseRequest.fromJson(json);
      expect(fmpr.id, 5);
      expect(fmpr.itemId, 20);
      expect(fmpr.buyerId, 'u_2');
      expect(fmpr.buyerName, 'Bob');
      expect(fmpr.buyerAvatar, 'https://example.com/b.png');
      expect(fmpr.proposedPrice, 12.5);
      expect(fmpr.sellerCounterPrice, 15.0);
      expect(fmpr.message, 'interested');
      expect(fmpr.status, 'negotiating');
      expect(fmpr.finalPrice, isNull);
      expect(fmpr.taskId, 101);
      expect(fmpr.consultationTaskId, 55);
      expect(fmpr.createdAt, DateTime.parse('2026-01-01T00:00:00Z'));
      expect(fmpr.updatedAt, DateTime.parse('2026-01-02T00:00:00Z'));
    });

    test('defaults status to pending when missing', () {
      final fmpr = FleaMarketPurchaseRequest.fromJson(<String, dynamic>{
        'id': 1,
        'item_id': 10,
        'buyer_id': 'u_1',
      });
      expect(fmpr.status, 'pending');
    });

    test('consultation_task_id is null when key is absent', () {
      final fmpr = FleaMarketPurchaseRequest.fromJson(_base());
      expect(fmpr.consultationTaskId, isNull);
    });

    test('consultation_task_id is null when explicitly null in JSON', () {
      final json = _base()..['consultation_task_id'] = null;
      final fmpr = FleaMarketPurchaseRequest.fromJson(json);
      expect(fmpr.consultationTaskId, isNull);
    });

    test('consultation_task_id parses integer correctly', () {
      final fmpr = FleaMarketPurchaseRequest.fromJson(
        _base(consultationTaskId: 77),
      );
      expect(fmpr.consultationTaskId, 77);
    });
  });

  // -------------------------------------------------------------------------
  // copyWith
  // -------------------------------------------------------------------------
  group('FleaMarketPurchaseRequest.copyWith', () {
    test('preserves consultationTaskId when not overridden', () {
      final fmpr = FleaMarketPurchaseRequest(
        id: 1,
        itemId: 10,
        buyerId: 'u_1',
        status: 'consulting',
        taskId: 200,
        consultationTaskId: 100,
      );
      final updated = fmpr.copyWith(taskId: 300);
      expect(updated.consultationTaskId, 100);
      expect(updated.taskId, 300);
    });

    test('can update consultationTaskId', () {
      final fmpr = FleaMarketPurchaseRequest(
        id: 1,
        itemId: 10,
        buyerId: 'u_1',
        status: 'consulting',
      );
      final updated = fmpr.copyWith(consultationTaskId: 50);
      expect(updated.consultationTaskId, 50);
    });
  });

  // -------------------------------------------------------------------------
  // Equatable props
  // -------------------------------------------------------------------------
  group('FleaMarketPurchaseRequest Equatable', () {
    test('includes consultationTaskId in equality check', () {
      final base = FleaMarketPurchaseRequest(
        id: 1,
        itemId: 10,
        buyerId: 'u_1',
        status: 'consulting',
        consultationTaskId: 50,
      );
      final different = base.copyWith(consultationTaskId: 99);
      expect(base, isNot(equals(different)));
    });

    test('equal when all props match', () {
      const a = FleaMarketPurchaseRequest(
        id: 1,
        itemId: 10,
        buyerId: 'u_1',
        status: 'consulting',
        consultationTaskId: 50,
      );
      const b = FleaMarketPurchaseRequest(
        id: 1,
        itemId: 10,
        buyerId: 'u_1',
        status: 'consulting',
        consultationTaskId: 50,
      );
      expect(a, equals(b));
    });
  });

  // -------------------------------------------------------------------------
  // FleaMarketPurchaseRequestConsultationRoute — FMPR 2 scenarios + special promotion assertion
  // -------------------------------------------------------------------------
  group('FleaMarketPurchaseRequestConsultationRoute.consultationMessageTaskId',
      () {
    test('FMPR 咨询中: fallback taskId=占位', () {
      final fmpr = FleaMarketPurchaseRequest.fromJson({
        'id': 1,
        'item_id': 10,
        'buyer_id': 'u_1',
        'status': 'consulting',
        'task_id': 102,
        'consultation_task_id': null,
      });
      expect(fmpr.consultationMessageTaskId, 102);
    });

    test(
        'FMPR 晋升后: consultationTaskId == taskId (special!), helper returns consultation_task_id',
        () {
      final fmpr = FleaMarketPurchaseRequest.fromJson({
        'id': 1,
        'item_id': 10,
        'buyer_id': 'u_1',
        'status': 'accepted',
        'task_id': 102,
        'consultation_task_id': 102,
      });
      expect(fmpr.consultationMessageTaskId, 102);
      // 断言 quirk itself 而非 bug:FMPR 晋升后两字段确实相等
      expect(
        fmpr.consultationTaskId,
        equals(fmpr.taskId),
        reason: 'FMPR promotion quirk: both fields point to same task row. '
            'Not a bug. Do NOT use == for 成单判断.',
      );
    });

    test('NULL boundary', () {
      final fmpr = FleaMarketPurchaseRequest.fromJson({
        'id': 1,
        'item_id': 10,
        'buyer_id': 'u_1',
        'status': 'pending',
        'task_id': null,
        'consultation_task_id': null,
      });
      expect(fmpr.consultationMessageTaskId, isNull);
    });

    test('returns taskId when consultationTaskId is null (no key in JSON)', () {
      final fmpr = FleaMarketPurchaseRequest.fromJson(_base(taskId: 77));
      expect(fmpr.consultationMessageTaskId, 77);
    });
  });
}
