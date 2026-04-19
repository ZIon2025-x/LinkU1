import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/task.dart';

/// Minimal JSON map that satisfies Task.fromJson required fields.
Map<String, dynamic> _minJson({Map<String, dynamic>? overrides}) {
  final base = <String, dynamic>{
    'id': 1,
    'title': 'Test Task',
    'task_type': 'Skill Service',
    'reward': 10.0,
    'status': 'open',
    'poster_id': '42',
  };
  if (overrides != null) base.addAll(overrides);
  return base;
}

void main() {
  group('Task.isConsultationPlaceholder', () {
    test('fromJson parses is_consultation_placeholder=true', () {
      final task = Task.fromJson(
        _minJson(overrides: {'is_consultation_placeholder': true}),
      );
      expect(task.isConsultationPlaceholder, isTrue);
    });

    test('fromJson parses is_consultation_placeholder=false', () {
      final task = Task.fromJson(
        _minJson(overrides: {'is_consultation_placeholder': false}),
      );
      expect(task.isConsultationPlaceholder, isFalse);
    });

    test('fromJson defaults to false when key is absent', () {
      final task = Task.fromJson(_minJson());
      expect(task.isConsultationPlaceholder, isFalse);
    });

    test('fromJson defaults to false when value is null', () {
      final task = Task.fromJson(
        _minJson(overrides: {'is_consultation_placeholder': null}),
      );
      expect(task.isConsultationPlaceholder, isFalse);
    });

    test('toJson round-trips isConsultationPlaceholder=true', () {
      final task = Task.fromJson(
        _minJson(overrides: {'is_consultation_placeholder': true}),
      );
      expect(task.toJson()['is_consultation_placeholder'], isTrue);
    });

    test('toJson round-trips isConsultationPlaceholder=false', () {
      final task = Task.fromJson(_minJson());
      expect(task.toJson()['is_consultation_placeholder'], isFalse);
    });

    test('copyWith preserves isConsultationPlaceholder when not overridden', () {
      final task = Task.fromJson(
        _minJson(overrides: {'is_consultation_placeholder': true}),
      );
      final copied = task.copyWith(title: 'New Title');
      expect(copied.isConsultationPlaceholder, isTrue);
    });

    test('copyWith overrides isConsultationPlaceholder', () {
      final task = Task.fromJson(
        _minJson(overrides: {'is_consultation_placeholder': true}),
      );
      final copied = task.copyWith(isConsultationPlaceholder: false);
      expect(copied.isConsultationPlaceholder, isFalse);
    });

    test('Equatable props: tasks differ when isConsultationPlaceholder differs', () {
      final taskA = Task.fromJson(_minJson());
      final taskB = Task.fromJson(
        _minJson(overrides: {'is_consultation_placeholder': true}),
      );
      expect(taskA, isNot(equals(taskB)));
    });
  });
}
