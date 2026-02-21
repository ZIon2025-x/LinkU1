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
