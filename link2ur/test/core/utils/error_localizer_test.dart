import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:link2ur/core/utils/error_localizer.dart';
import 'package:link2ur/l10n/app_localizations.dart';

void main() {
  Widget buildContext(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  group('ErrorLocalizer.localize', () {
    testWidgets('returns localized message for known error codes',
        (tester) async {
      await tester.pumpWidget(
        buildContext(
          Builder(
            builder: (context) {
              expect(
                ErrorLocalizer.localize(context, 'error_network_timeout'),
                isNotEmpty,
              );
              expect(
                ErrorLocalizer.localize(context, 'auth_error_login_failed'),
                isNotEmpty,
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('returns localized message for AI chat error codes',
        (tester) async {
      await tester.pumpWidget(
        buildContext(
          Builder(
            builder: (context) {
              for (final code in [
                'ai_chat_load_conversations_failed',
                'ai_chat_create_conversation_failed',
                'ai_chat_load_history_failed',
                'ai_chat_create_conversation_retry',
                'unknown_error',
              ]) {
                final result = ErrorLocalizer.localize(context, code);
                expect(result, isNotEmpty, reason: 'code=$code should resolve');
                expect(result, isNot(equals(code)),
                    reason: 'code=$code should NOT be returned as-is');
              }
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('returns message as-is for unknown codes', (tester) async {
      await tester.pumpWidget(
        buildContext(
          Builder(
            builder: (context) {
              const customMsg = 'Custom server message';
              expect(
                ErrorLocalizer.localize(context, customMsg),
                customMsg,
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('ErrorLocalizerExtension', () {
    testWidgets('context.localizeError works as shorthand', (tester) async {
      await tester.pumpWidget(
        buildContext(
          Builder(
            builder: (context) {
              final direct = ErrorLocalizer.localize(context, 'error_unknown');
              final ext = context.localizeError('error_unknown');
              expect(ext, equals(direct));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('context.localizeError handles null', (tester) async {
      await tester.pumpWidget(
        buildContext(
          Builder(
            builder: (context) {
              final result = context.localizeError(null);
              expect(result, isNotEmpty);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('ErrorLocalizer.localizeErrorCode', () {
    testWidgets('maps known consultation error codes to localized text',
        (tester) async {
      await tester.pumpWidget(
        buildContext(
          Builder(
            builder: (context) {
              // Locale defaults to en on most test hosts; we only assert that
              // known codes resolve to non-empty, non-pass-through strings.
              for (final code in const [
                'CONSULTATION_ALREADY_EXISTS',
                'CONSULTATION_NOT_FOUND',
                'CONSULTATION_CLOSED',
                'SERVICE_NOT_FOUND',
                'SERVICE_INACTIVE',
                'EXPERT_TEAM_NOT_FOUND',
                'EXPERT_TEAM_INACTIVE',
                'CANNOT_CONSULT_SELF',
                'NOT_SERVICE_OWNER',
                'NOT_TEAM_MEMBER',
                'INSUFFICIENT_TEAM_ROLE',
                'INVALID_STATUS_TRANSITION',
                'PRICE_OUT_OF_RANGE',
                'TASK_NOT_FOUND',
              ]) {
                final result = ErrorLocalizer.localizeErrorCode(context, code);
                expect(result, isNotEmpty, reason: 'code=$code should resolve');
                expect(result, isNot(equals(code)),
                    reason: 'code=$code should NOT be returned as-is');
              }
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('unknown code falls back to generic consultation error',
        (tester) async {
      await tester.pumpWidget(
        buildContext(
          Builder(
            builder: (context) {
              final unknown = ErrorLocalizer.localizeErrorCode(
                context,
                'UNKNOWN_CODE_XYZ',
              );
              final generic = ErrorLocalizer.localizeErrorCode(
                context,
                'ANOTHER_UNKNOWN',
              );
              expect(unknown, isNotEmpty);
              // Both unknown codes collapse to the same generic fallback.
              expect(unknown, equals(generic));
              // And fallback is not the raw code itself.
              expect(unknown, isNot(equals('UNKNOWN_CODE_XYZ')));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('null / empty code returns errorUnknownGeneric',
        (tester) async {
      await tester.pumpWidget(
        buildContext(
          Builder(
            builder: (context) {
              expect(
                ErrorLocalizer.localizeErrorCode(context, null),
                isNotEmpty,
              );
              expect(
                ErrorLocalizer.localizeErrorCode(context, ''),
                isNotEmpty,
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('context.localizeErrorCode extension matches static call',
        (tester) async {
      await tester.pumpWidget(
        buildContext(
          Builder(
            builder: (context) {
              final direct = ErrorLocalizer.localizeErrorCode(
                context,
                'SERVICE_INACTIVE',
              );
              final ext = context.localizeErrorCode('SERVICE_INACTIVE');
              expect(ext, equals(direct));
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('ErrorLocalizer.localizeFromException', () {
    testWidgets('null returns errorUnknownGeneric', (tester) async {
      await tester.pumpWidget(
        buildContext(
          Builder(
            builder: (context) {
              final result = ErrorLocalizer.localizeFromException(context, null);
              expect(result, isNotEmpty);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('timeout exception returns network timeout message',
        (tester) async {
      await tester.pumpWidget(
        buildContext(
          Builder(
            builder: (context) {
              final result = ErrorLocalizer.localizeFromException(
                context,
                Exception('Connection timeout'),
              );
              expect(result, isNotEmpty);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
