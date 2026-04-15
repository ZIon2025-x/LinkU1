import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/service_application.dart';

ServiceApplication _app(
  ServiceApplicationStatus s, {
  double? counter,
  int? taskId,
}) =>
    ServiceApplication(
      id: 1,
      status: s,
      serviceId: 1,
      currency: 'GBP',
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      expertCounterPrice: counter,
      taskId: taskId,
    );

void main() {
  group('ServiceApplicationStatus', () {
    test('fromApi maps all backend strings', () {
      expect(
        ServiceApplicationStatus.fromApi('pending'),
        ServiceApplicationStatus.pending,
      );
      expect(
        ServiceApplicationStatus.fromApi('negotiating'),
        ServiceApplicationStatus.negotiating,
      );
      expect(
        ServiceApplicationStatus.fromApi('price_agreed'),
        ServiceApplicationStatus.priceAgreed,
      );
      expect(
        ServiceApplicationStatus.fromApi('approved'),
        ServiceApplicationStatus.approved,
      );
      expect(
        ServiceApplicationStatus.fromApi('rejected'),
        ServiceApplicationStatus.rejected,
      );
      expect(
        ServiceApplicationStatus.fromApi('cancelled'),
        ServiceApplicationStatus.cancelled,
      );
    });

    test('fromApi falls back to pending for unknown / null', () {
      expect(
        ServiceApplicationStatus.fromApi(null),
        ServiceApplicationStatus.pending,
      );
      expect(
        ServiceApplicationStatus.fromApi('bogus'),
        ServiceApplicationStatus.pending,
      );
      expect(
        ServiceApplicationStatus.fromApi(''),
        ServiceApplicationStatus.pending,
      );
    });

    test('apiValue produces snake_case for priceAgreed', () {
      expect(ServiceApplicationStatus.priceAgreed.apiValue, 'price_agreed');
    });

    test('apiValue matches enum name for non-compound values', () {
      expect(ServiceApplicationStatus.pending.apiValue, 'pending');
      expect(ServiceApplicationStatus.negotiating.apiValue, 'negotiating');
      expect(ServiceApplicationStatus.approved.apiValue, 'approved');
      expect(ServiceApplicationStatus.rejected.apiValue, 'rejected');
      expect(ServiceApplicationStatus.cancelled.apiValue, 'cancelled');
    });

    test('isTerminal is true only for approved/rejected/cancelled', () {
      expect(ServiceApplicationStatus.approved.isTerminal, true);
      expect(ServiceApplicationStatus.rejected.isTerminal, true);
      expect(ServiceApplicationStatus.cancelled.isTerminal, true);
      expect(ServiceApplicationStatus.pending.isTerminal, false);
      expect(ServiceApplicationStatus.negotiating.isTerminal, false);
      expect(ServiceApplicationStatus.priceAgreed.isTerminal, false);
    });
  });

  group('ServiceApplication.fromJson', () {
    test('parses a full realistic payload', () {
      final json = <String, dynamic>{
        'id': 42,
        'status': 'negotiating',
        'service_id': 7,
        'service_name': 'Cleaning',
        'service_owner_id': 'u_owner_1',
        'owner_name': 'Alice',
        'expert_id': 'e_1',
        'expert_name': 'Bob Team',
        'applicant_id': 'u_applicant_9',
        'applicant_name': 'Carol',
        'applicant_avatar': 'https://example.com/a.png',
        'application_message': 'please',
        'negotiated_price': 40.0,
        'expert_counter_price': 50.0,
        'final_price': null,
        'currency': 'GBP',
        'task_id': null,
        'created_at': '2026-04-15T10:00:00Z',
        'approved_at': null,
        'price_agreed_at': null,
      };
      final app = ServiceApplication.fromJson(json);
      expect(app.id, 42);
      expect(app.status, ServiceApplicationStatus.negotiating);
      expect(app.serviceId, 7);
      expect(app.serviceName, 'Cleaning');
      expect(app.ownerId, 'u_owner_1');
      expect(app.ownerName, 'Alice');
      expect(app.expertId, 'e_1');
      expect(app.expertName, 'Bob Team');
      expect(app.applicantId, 'u_applicant_9');
      expect(app.applicantName, 'Carol');
      expect(app.applicantAvatar, 'https://example.com/a.png');
      expect(app.applicationMessage, 'please');
      expect(app.negotiatedPrice, 40.0);
      expect(app.expertCounterPrice, 50.0);
      expect(app.finalPrice, isNull);
      expect(app.currency, 'GBP');
      expect(app.taskId, isNull);
      expect(app.approvedAt, isNull);
      expect(app.priceAgreedAt, isNull);
    });

    test('defaults currency to GBP when missing', () {
      final json = <String, dynamic>{
        'id': 1,
        'status': 'pending',
        'service_id': 1,
        'created_at': '2026-04-15T10:00:00Z',
      };
      expect(ServiceApplication.fromJson(json).currency, 'GBP');
    });

    test('falls back to service_owner_name when owner_name is absent', () {
      final json = <String, dynamic>{
        'id': 1,
        'status': 'pending',
        'service_id': 1,
        'service_owner_name': 'Fallback Name',
        'created_at': '2026-04-15T10:00:00Z',
      };
      expect(ServiceApplication.fromJson(json).ownerName, 'Fallback Name');
    });

    test('parses price_agreed status + approved_at/price_agreed_at', () {
      final json = <String, dynamic>{
        'id': 3,
        'status': 'price_agreed',
        'service_id': 2,
        'final_price': 88.5,
        'task_id': 101,
        'created_at': '2026-04-15T10:00:00Z',
        'price_agreed_at': '2026-04-15T11:00:00Z',
      };
      final app = ServiceApplication.fromJson(json);
      expect(app.status, ServiceApplicationStatus.priceAgreed);
      expect(app.finalPrice, 88.5);
      expect(app.taskId, 101);
      expect(
        app.priceAgreedAt,
        DateTime.parse('2026-04-15T11:00:00Z'),
      );
    });

    test('roundtrip: fromJson -> toJson preserves status.apiValue', () {
      final json = <String, dynamic>{
        'id': 5,
        'status': 'price_agreed',
        'service_id': 2,
        'currency': 'GBP',
        'created_at': '2026-04-15T10:00:00Z',
      };
      final app = ServiceApplication.fromJson(json);
      expect(app.toJson()['status'], 'price_agreed');
    });

    test('tolerates string task_id from backend', () {
      final json = <String, dynamic>{
        'id': 9,
        'status': 'approved',
        'service_id': 2,
        'task_id': '77',
        'created_at': '2026-04-15T10:00:00Z',
      };
      expect(ServiceApplication.fromJson(json).taskId, 77);
    });
  });

  group('ServiceApplicationRules', () {
    test('canCancel allows pending/negotiating/price_agreed only', () {
      expect(_app(ServiceApplicationStatus.pending).canCancel, true);
      expect(_app(ServiceApplicationStatus.negotiating).canCancel, true);
      expect(_app(ServiceApplicationStatus.priceAgreed).canCancel, true);
      expect(_app(ServiceApplicationStatus.approved).canCancel, false);
      expect(_app(ServiceApplicationStatus.rejected).canCancel, false);
      expect(_app(ServiceApplicationStatus.cancelled).canCancel, false);
    });

    test('canRespondCounterOffer requires negotiating + expertCounterPrice',
        () {
      expect(
        _app(ServiceApplicationStatus.negotiating, counter: 50)
            .canRespondCounterOffer,
        true,
      );
      expect(
        _app(ServiceApplicationStatus.negotiating).canRespondCounterOffer,
        false,
      );
      expect(
        _app(ServiceApplicationStatus.pending, counter: 50)
            .canRespondCounterOffer,
        false,
      );
      expect(
        _app(ServiceApplicationStatus.priceAgreed, counter: 50)
            .canRespondCounterOffer,
        false,
      );
    });

    test('canViewTask requires approved + taskId', () {
      expect(
        _app(ServiceApplicationStatus.approved, taskId: 10).canViewTask,
        true,
      );
      expect(
        _app(ServiceApplicationStatus.approved).canViewTask,
        false,
      );
      expect(
        _app(ServiceApplicationStatus.pending, taskId: 10).canViewTask,
        false,
      );
    });

    test('canApprove allows pending + price_agreed only', () {
      expect(_app(ServiceApplicationStatus.pending).canApprove, true);
      expect(_app(ServiceApplicationStatus.priceAgreed).canApprove, true);
      expect(_app(ServiceApplicationStatus.negotiating).canApprove, false);
      expect(_app(ServiceApplicationStatus.approved).canApprove, false);
      expect(_app(ServiceApplicationStatus.rejected).canApprove, false);
      expect(_app(ServiceApplicationStatus.cancelled).canApprove, false);
    });

    test('canReject allows pending/negotiating/price_agreed only', () {
      expect(_app(ServiceApplicationStatus.pending).canReject, true);
      expect(_app(ServiceApplicationStatus.negotiating).canReject, true);
      expect(_app(ServiceApplicationStatus.priceAgreed).canReject, true);
      expect(_app(ServiceApplicationStatus.approved).canReject, false);
      expect(_app(ServiceApplicationStatus.rejected).canReject, false);
      expect(_app(ServiceApplicationStatus.cancelled).canReject, false);
    });

    test('canCounterOffer allows pending + negotiating only', () {
      expect(_app(ServiceApplicationStatus.pending).canCounterOffer, true);
      expect(_app(ServiceApplicationStatus.negotiating).canCounterOffer, true);
      expect(_app(ServiceApplicationStatus.priceAgreed).canCounterOffer, false);
      expect(_app(ServiceApplicationStatus.approved).canCounterOffer, false);
      expect(_app(ServiceApplicationStatus.rejected).canCounterOffer, false);
      expect(_app(ServiceApplicationStatus.cancelled).canCounterOffer, false);
    });
  });
}
