import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/service_application.dart';
import 'package:link2ur/data/models/task_application.dart';
import 'package:link2ur/data/models/flea_market.dart';

void main() {
  group('consultationMessageTaskId NULL boundary (C.3 rule verification)', () {
    test('ServiceApplication: consultationTaskId null → consultationMessageTaskId is null', () {
      // Both taskId and consultationTaskId are null → extension returns null
      final sa = ServiceApplication(
        id: 1,
        status: ServiceApplicationStatus.pending,
        serviceId: 1,
        currency: 'GBP',
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      );
      expect(sa.consultationMessageTaskId, isNull);
    });

    test('TaskApplication: consultationTaskId null, taskId fallback → extension returns taskId', () {
      // consultationTaskId is null, taskId is fallback value
      // When both are semantically null (no consultation), extension returns the fallback
      final ta = TaskApplication.fromJson(<String, dynamic>{
        'id': 1,
        'task_id': 101,
        'status': 'pending',
        'consultation_task_id': null,
      });
      expect(ta.consultationMessageTaskId, 101);
    });

    test('PurchaseRequest (FMPR): 两字段都 null → consultationMessageTaskId is null', () {
      // Both taskId and consultationTaskId are null → extension returns null
      final fmpr = PurchaseRequest.fromJson(<String, dynamic>{
        'id': '1',
        'buyer_id': 'u_1',
        'status': 'pending',
        'task_id': null,
        'consultation_task_id': null,
      });
      expect(fmpr.consultationMessageTaskId, isNull);
    });
  });
}
