// Widget / smoke tests for Link2Ur app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:link2ur/core/utils/responsive.dart';
import 'package:link2ur/core/utils/sheet_adaptation.dart';

void main() {
  test('Breakpoints values are consistent', () {
    expect(Breakpoints.mobile, Breakpoints.tablet);
    expect(Breakpoints.maxDetailWidth, 900);
    expect(Breakpoints.compact, lessThan(Breakpoints.medium));
    expect(Breakpoints.medium, lessThan(Breakpoints.expanded));
  });

  test('SheetAdaptation constants are defined', () {
    expect(SheetAdaptation.tabletSheetMaxWidth, 600);
    expect(SheetAdaptation.tabletSheetMaxWidthLarge, 900);
  });

  testWidgets('ResponsiveLayout builds without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsiveLayout(
            mobile: Text('Mobile'),
            desktop: Text('Desktop'),
          ),
        ),
      ),
    );
    expect(find.byType(ResponsiveLayout), findsOneWidget);
  });
}
