import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/core/constants/app_constants.dart';
import 'package:link2ur/core/utils/task_status_helper.dart';
import 'package:link2ur/l10n/app_localizations.dart';

class MockAppLocalizations extends Mock implements AppLocalizations {}

void main() {
  late MockAppLocalizations l10n;

  setUp(() {
    l10n = MockAppLocalizations();
    when(() => l10n.taskStatusOpen).thenReturn('Open');
    when(() => l10n.taskStatusInProgress).thenReturn('In Progress');
    when(() => l10n.taskStatusPendingConfirmation).thenReturn('Pending Confirmation');
    when(() => l10n.taskStatusPendingPayment).thenReturn('Pending Payment');
    when(() => l10n.taskStatusCompleted).thenReturn('Completed');
    when(() => l10n.taskStatusCancelled).thenReturn('Cancelled');
    when(() => l10n.taskStatusDisputed).thenReturn('Disputed');
  });

  group('TaskStatusHelper.getLocalizedLabel', () {
    test('returns localized label for open', () {
      expect(
        TaskStatusHelper.getLocalizedLabel(AppConstants.taskStatusOpen, l10n),
        'Open',
      );
    });

    test('returns localized label for in_progress', () {
      expect(
        TaskStatusHelper.getLocalizedLabel(AppConstants.taskStatusInProgress, l10n),
        'In Progress',
      );
    });

    test('returns localized label for pending_confirmation', () {
      expect(
        TaskStatusHelper.getLocalizedLabel(
          AppConstants.taskStatusPendingConfirmation,
          l10n,
        ),
        'Pending Confirmation',
      );
    });

    test('returns localized label for pending_payment', () {
      expect(
        TaskStatusHelper.getLocalizedLabel(
          AppConstants.taskStatusPendingPayment,
          l10n,
        ),
        'Pending Payment',
      );
    });

    test('returns localized label for completed', () {
      expect(
        TaskStatusHelper.getLocalizedLabel(AppConstants.taskStatusCompleted, l10n),
        'Completed',
      );
    });

    test('returns localized label for cancelled', () {
      expect(
        TaskStatusHelper.getLocalizedLabel(AppConstants.taskStatusCancelled, l10n),
        'Cancelled',
      );
    });

    test('returns localized label for disputed', () {
      expect(
        TaskStatusHelper.getLocalizedLabel(AppConstants.taskStatusDisputed, l10n),
        'Disputed',
      );
    });

    test('returns raw status for unknown status', () {
      expect(
        TaskStatusHelper.getLocalizedLabel('unknown_status', l10n),
        'unknown_status',
      );
    });
  });
}
