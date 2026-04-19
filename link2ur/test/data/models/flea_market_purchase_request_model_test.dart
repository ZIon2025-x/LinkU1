import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/flea_market.dart';

// ---------------------------------------------------------------------------
// Minimal JSON factory — only required fields
// ---------------------------------------------------------------------------
Map<String, dynamic> _base({
  String id = '1',
  String buyerId = 'u_1',
  String status = 'pending',
  int? taskId,
  int? consultationTaskId,
}) =>
    <String, dynamic>{
      'id': id,
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
  group('PurchaseRequest.fromJson', () {
    test('parses all basic fields from a realistic payload', () {
      final json = <String, dynamic>{
        'id': '5',
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
      final pr = PurchaseRequest.fromJson(json);
      expect(pr.id, '5');
      expect(pr.buyerId, 'u_2');
      expect(pr.buyerName, 'Bob');
      expect(pr.buyerAvatar, 'https://example.com/b.png');
      expect(pr.proposedPrice, 12.5);
      expect(pr.sellerCounterPrice, 15.0);
      expect(pr.message, 'interested');
      expect(pr.status, 'negotiating');
      expect(pr.finalPrice, isNull);
      expect(pr.taskId, 101);
      expect(pr.consultationTaskId, 55);
      expect(pr.createdAt, DateTime.parse('2026-01-01T00:00:00Z'));
      expect(pr.updatedAt, DateTime.parse('2026-01-02T00:00:00Z'));
    });

    test('defaults status to pending when missing', () {
      final pr = PurchaseRequest.fromJson(<String, dynamic>{
        'id': '1',
        'buyer_id': 'u_1',
      });
      expect(pr.status, 'pending');
    });

    test('consultation_task_id is null when key is absent', () {
      final pr = PurchaseRequest.fromJson(_base());
      expect(pr.consultationTaskId, isNull);
    });

    test('consultation_task_id is null when explicitly null in JSON', () {
      final json = _base()..['consultation_task_id'] = null;
      final pr = PurchaseRequest.fromJson(json);
      expect(pr.consultationTaskId, isNull);
    });

    test('consultation_task_id parses integer correctly', () {
      final pr = PurchaseRequest.fromJson(
        _base(consultationTaskId: 77),
      );
      expect(pr.consultationTaskId, 77);
    });
  });

  // -------------------------------------------------------------------------
  // copyWith
  // -------------------------------------------------------------------------
  group('PurchaseRequest.copyWith', () {
    test('preserves consultationTaskId when not overridden', () {
      const pr = PurchaseRequest(
        id: '1',
        buyerId: 'u_1',
        status: 'consulting',
        taskId: 200,
        consultationTaskId: 100,
      );
      final updated = pr.copyWith(taskId: 300);
      expect(updated.consultationTaskId, 100);
      expect(updated.taskId, 300);
    });

    test('can update consultationTaskId', () {
      const pr = PurchaseRequest(
        id: '1',
        buyerId: 'u_1',
        status: 'consulting',
      );
      final updated = pr.copyWith(consultationTaskId: 50);
      expect(updated.consultationTaskId, 50);
    });
  });

  // -------------------------------------------------------------------------
  // Equatable props
  // -------------------------------------------------------------------------
  group('PurchaseRequest Equatable', () {
    test('includes consultationTaskId in equality check', () {
      const base = PurchaseRequest(
        id: '1',
        buyerId: 'u_1',
        status: 'consulting',
        consultationTaskId: 50,
      );
      final different = base.copyWith(consultationTaskId: 99);
      expect(base, isNot(equals(different)));
    });

    test('equal when all props match', () {
      const a = PurchaseRequest(
        id: '1',
        buyerId: 'u_1',
        status: 'consulting',
        consultationTaskId: 50,
      );
      const b = PurchaseRequest(
        id: '1',
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
      final pr = PurchaseRequest.fromJson({
        'id': '1',
        'buyer_id': 'u_1',
        'status': 'consulting',
        'task_id': 102,
        'consultation_task_id': null,
      });
      expect(pr.consultationMessageTaskId, 102);
    });

    test(
        'FMPR 晋升后: consultationTaskId == taskId (special!), helper returns consultation_task_id',
        () {
      final pr = PurchaseRequest.fromJson({
        'id': '1',
        'buyer_id': 'u_1',
        'status': 'accepted',
        'task_id': 102,
        'consultation_task_id': 102,
      });
      expect(pr.consultationMessageTaskId, 102);
      // 断言 quirk itself 而非 bug:FMPR 晋升后两字段确实相等
      expect(
        pr.consultationTaskId,
        equals(pr.taskId),
        reason: 'FMPR promotion quirk: both fields point to same task row. '
            'Not a bug. Do NOT use == for 成单判断.',
      );
    });

    test('NULL boundary', () {
      final pr = PurchaseRequest.fromJson({
        'id': '1',
        'buyer_id': 'u_1',
        'status': 'pending',
        'task_id': null,
        'consultation_task_id': null,
      });
      expect(pr.consultationMessageTaskId, isNull);
    });

    test('returns taskId when consultationTaskId is null (no key in JSON)', () {
      final pr = PurchaseRequest.fromJson(_base(taskId: 77));
      expect(pr.consultationMessageTaskId, 77);
    });
  });
}
