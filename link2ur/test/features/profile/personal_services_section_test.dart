import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:link2ur/data/models/user.dart';
import 'package:link2ur/features/profile/views/widgets/personal_services_section.dart';
import 'package:link2ur/l10n/app_localizations.dart';

void main() {
  UserProfilePersonalService _svc(int id, String name, {String? cat, String pricingType = 'fixed', double price = 15.0}) =>
      UserProfilePersonalService(
        id: id,
        serviceName: name,
        basePrice: price,
        category: cat ?? 'tutoring',
        pricingType: pricingType,
      );

  Widget _harness(List<UserProfilePersonalService> services) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: PersonalServicesSection(services: services),
        ),
      );

  testWidgets('renders title and each service when non-empty', (tester) async {
    await tester.pumpWidget(_harness([
      _svc(1, '家教 · 小学数学'),
      _svc(2, '伦敦市内代取', cat: 'errand'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('个人服务'), findsOneWidget);
    expect(find.text('家教 · 小学数学'), findsOneWidget);
    expect(find.text('伦敦市内代取'), findsOneWidget);
  });

  testWidgets('renders SizedBox.shrink (no UI) when empty', (tester) async {
    await tester.pumpWidget(_harness(const []));
    await tester.pumpAndSettle();

    expect(find.text('个人服务'), findsNothing);
    final renderBox = tester.renderObject<RenderBox>(
      find.byType(PersonalServicesSection),
    );
    expect(renderBox.size.height, 0);
  });

  testWidgets('shows "议价" label for negotiable pricing_type', (tester) async {
    await tester.pumpWidget(_harness([
      _svc(1, '私人教练', pricingType: 'negotiable', price: 0.0),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('议价'), findsOneWidget);
  });
}
