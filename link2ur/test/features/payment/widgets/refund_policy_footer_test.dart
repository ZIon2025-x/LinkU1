import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:link2ur/core/router/app_routes.dart';
import 'package:link2ur/features/payment/views/widgets/refund_policy_footer.dart';
import 'package:link2ur/l10n/app_localizations.dart';

void main() {
  group('RefundPolicyFooter', () {
    testWidgets('renders prefix + link text and navigates on tap',
        (tester) async {
      String? lastPushedLocation;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: RefundPolicyFooter()),
          ),
          GoRoute(
            path: AppRoutes.refundPolicy,
            builder: (_, __) {
              lastPushedLocation = AppRoutes.refundPolicy;
              return const Scaffold(body: Text('REFUND POLICY VIEW STUB'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      // Both spans should be present (en locale: "By tapping Pay, you agree to our  Refund Policy")
      expect(find.textContaining('By tapping Pay'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Refund Policy'), findsAtLeastNWidgets(1));

      // Find the RichText inside RefundPolicyFooter and grab the linked span
      final richText = tester.widget<RichText>(
        find.descendant(
          of: find.byType(RefundPolicyFooter),
          matching: find.byType(RichText),
        ),
      );
      TextSpan? linkSpan;
      richText.text.visitChildren((span) {
        if (span is TextSpan && span.recognizer != null) {
          linkSpan = span;
          return false;
        }
        return true;
      });
      expect(linkSpan, isNotNull,
          reason: 'Link span with tap recognizer must exist');

      // Trigger the recognizer's onTap handler directly (this is what
      // Flutter's hit testing eventually calls for a span tap).
      ((linkSpan!).recognizer as TapGestureRecognizer).onTap?.call();
      await tester.pumpAndSettle();

      expect(lastPushedLocation, AppRoutes.refundPolicy);
    });

    testWidgets('disposes the gesture recognizer cleanly', (tester) async {
      // If dispose() is missing, Flutter's framework reports a leak.
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: RefundPolicyFooter()),
        ),
      );
      await tester.pumpAndSettle();
      // Pump a different widget tree to trigger dispose on RefundPolicyFooter
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      // Test passes if no leak warnings raised by Flutter framework.
    });
  });
}
