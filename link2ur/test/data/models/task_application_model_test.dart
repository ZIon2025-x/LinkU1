import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/task_application.dart';

// ---------------------------------------------------------------------------
// Minimal JSON factory — only required fields
// ---------------------------------------------------------------------------
Map<String, dynamic> _base({
  int id = 1,
  int taskId = 101,
  String status = 'pending',
  int? consultationTaskId,
}) =>
    <String, dynamic>{
      'id': id,
      'task_id': taskId,
      'status': status,
      if (consultationTaskId != null)
        'consultation_task_id': consultationTaskId,
    };

void main() {
  // -------------------------------------------------------------------------
  // fromJson basics
  // -------------------------------------------------------------------------
  group('TaskApplication.fromJson', () {
    test('parses all basic fields from a realistic payload', () {
      final json = <String, dynamic>{
        'id': 42,
        'task_id': 7,
        'applicant_id': 'u_1',
        'applicant_name': 'Alice',
        'applicant_avatar': 'https://example.com/a.png',
        'applicant_user_level': 'gold',
        'status': 'chatting',
        'message': 'hi',
        'negotiated_price': 25.5,
        'currency': 'GBP',
        'created_at': '2026-01-01T00:00:00Z',
        'unread_count': 3,
        'poster_reply': 'sure',
        'poster_reply_at': '2026-01-02T00:00:00Z',
        'task_status': 'in_progress',
        'task_title': 'Do my taxes',
        'consultation_task_id': 99,
      };
      final ta = TaskApplication.fromJson(json);
      expect(ta.id, 42);
      expect(ta.taskId, 7);
      expect(ta.applicantId, 'u_1');
      expect(ta.applicantName, 'Alice');
      expect(ta.applicantAvatar, 'https://example.com/a.png');
      expect(ta.applicantUserLevel, 'gold');
      expect(ta.status, 'chatting');
      expect(ta.message, 'hi');
      expect(ta.proposedPrice, 25.5);
      expect(ta.currency, 'GBP');
      expect(ta.createdAt, '2026-01-01T00:00:00Z');
      expect(ta.unreadCount, 3);
      expect(ta.posterReply, 'sure');
      expect(ta.posterReplyAt, '2026-01-02T00:00:00Z');
      expect(ta.taskStatus, 'in_progress');
      expect(ta.taskTitle, 'Do my taxes');
      expect(ta.consultationTaskId, 99);
    });

    test('defaults status to pending when missing', () {
      final ta = TaskApplication.fromJson(<String, dynamic>{
        'id': 1,
        'task_id': 1,
      });
      expect(ta.status, 'pending');
    });

    test('defaults taskId to 0 when missing', () {
      final ta = TaskApplication.fromJson(<String, dynamic>{
        'id': 1,
        'status': 'pending',
      });
      expect(ta.taskId, 0);
    });

    test('defaults unreadCount to 0 when missing', () {
      final ta = TaskApplication.fromJson(_base());
      expect(ta.unreadCount, 0);
    });

    test('consultation_task_id is null when key is absent', () {
      final ta = TaskApplication.fromJson(_base());
      expect(ta.consultationTaskId, isNull);
    });

    test('consultation_task_id is null when explicitly null in JSON', () {
      final json = _base()..['consultation_task_id'] = null;
      final ta = TaskApplication.fromJson(json);
      expect(ta.consultationTaskId, isNull);
    });

    test('consultation_task_id parses integer correctly', () {
      final ta = TaskApplication.fromJson(_base(consultationTaskId: 55));
      expect(ta.consultationTaskId, 55);
    });
  });

  // -------------------------------------------------------------------------
  // copyWith
  // -------------------------------------------------------------------------
  group('TaskApplication.copyWith', () {
    test('preserves consultationTaskId when not overridden', () {
      final ta = TaskApplication(
        id: 1,
        taskId: 200,
        status: 'approved',
        consultationTaskId: 100,
      );
      final updated = ta.copyWith(taskId: 300);
      expect(updated.consultationTaskId, 100);
      expect(updated.taskId, 300);
    });

    test('can update consultationTaskId', () {
      final ta = TaskApplication(
        id: 1,
        taskId: 100,
        status: 'consulting',
      );
      final updated = ta.copyWith(consultationTaskId: 100);
      expect(updated.consultationTaskId, 100);
    });
  });

  // -------------------------------------------------------------------------
  // Equatable props
  // -------------------------------------------------------------------------
  group('TaskApplication Equatable', () {
    test('includes consultationTaskId in equality check', () {
      final base = TaskApplication(
        id: 1,
        taskId: 100,
        status: 'consulting',
        consultationTaskId: 50,
      );
      final different = base.copyWith(consultationTaskId: 99);
      expect(base, isNot(equals(different)));
    });

    test('equal when consultationTaskId matches', () {
      const a = TaskApplication(
        id: 1,
        taskId: 100,
        status: 'consulting',
        consultationTaskId: 50,
      );
      const b = TaskApplication(
        id: 1,
        taskId: 100,
        status: 'consulting',
        consultationTaskId: 50,
      );
      expect(a, equals(b));
    });
  });

  // -------------------------------------------------------------------------
  // TaskApplicationConsultationRoute extension — TA 3 scenarios + NULL
  // -------------------------------------------------------------------------
  group('TaskApplicationConsultationRoute.consultationMessageTaskId', () {
    test('TA 占位记录咨询中: fallback to taskId (占位)', () {
      // consultation_task_id=null, task_id=占位
      final ta = TaskApplication.fromJson(
        <String, dynamic>{
          'id': 1,
          'task_id': 101,
          'status': 'consulting',
          'consultation_task_id': null,
        },
      );
      expect(ta.consultationMessageTaskId, 101);
    });

    test('TA 占位记录 cancelled: fallback taskId=占位 仍有效', () {
      // After formal apply, placeholder TA.status='cancelled', task_id still=占位
      final ta = TaskApplication.fromJson(
        <String, dynamic>{
          'id': 1,
          'task_id': 101,
          'status': 'cancelled',
          'consultation_task_id': null,
        },
      );
      expect(ta.consultationMessageTaskId, 101);
    });

    test('TA orig_application: consultationTaskId takes precedence over taskId',
        () {
      // orig_application: task_id=原任务, consultation_task_id=占位
      final ta = TaskApplication.fromJson(
        <String, dynamic>{
          'id': 1,
          'task_id': 999,
          'status': 'approved',
          'consultation_task_id': 101,
        },
      );
      expect(ta.consultationMessageTaskId, 101);
    });

    test('returns taskId when consultationTaskId is null (no key in JSON)', () {
      final ta = TaskApplication.fromJson(_base(taskId: 77));
      expect(ta.consultationMessageTaskId, 77);
    });
  });
}
