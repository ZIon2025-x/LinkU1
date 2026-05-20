import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/message.dart';

/// Minimal JSON map satisfying Message.fromJson required fields.
Map<String, dynamic> _minJson({Map<String, dynamic>? overrides}) {
  final base = <String, dynamic>{
    'id': 1,
    'sender_id': 'u1',
    'receiver_id': 'u2',
    'content': 'hi',
    'message_type': 'text',
  };
  if (overrides != null) base.addAll(overrides);
  return base;
}

void main() {
  group('Message.applicationId', () {
    test('returns top-level application_id when present', () {
      final m = Message.fromJson(_minJson(overrides: {'application_id': 42}));
      expect(m.applicationId, 42);
    });

    test('falls back to meta.application_id when top-level absent', () {
      final m = Message.fromJson(_minJson(overrides: {
        'message_type': 'system',
        'meta': jsonEncode({'application_id': 99}),
      }));
      expect(m.applicationId, 99);
    });

    test('returns null when neither present', () {
      final m = Message.fromJson(_minJson());
      expect(m.applicationId, isNull);
    });

    test('top-level takes priority over meta when both present', () {
      final m = Message.fromJson(_minJson(overrides: {
        'application_id': 7,
        'meta': jsonEncode({'application_id': 99}),
      }));
      expect(m.applicationId, 7);
    });

    test('two messages with different applicationId are not equal', () {
      final base = <String, dynamic>{
        'id': 1,
        'sender_id': 'u1',
        'receiver_id': 'u2',
        'content': 'hi',
        'message_type': 'text',
      };
      final a = Message.fromJson({...base, 'application_id': 42});
      final b = Message.fromJson({...base, 'application_id': 99});
      expect(a == b, isFalse,
          reason: 'applicationId must participate in equality');
    });
  });
}
