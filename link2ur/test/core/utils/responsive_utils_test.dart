import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:link2ur/core/utils/responsive.dart';

const _testBuilderKey = Key('test_builder');

void main() {
  Widget buildContext({required double width}) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: Builder(
        key: _testBuilderKey,
        builder: (context) => const SizedBox.shrink(),
      ),
    );
  }

  BuildContext getContext(WidgetTester tester) {
    return tester.element(find.byKey(_testBuilderKey));
  }

  group('Breakpoints', () {
    test('constants are defined', () {
      expect(Breakpoints.compact, 600);
      expect(Breakpoints.medium, 900);
      expect(Breakpoints.expanded, 1200);
      expect(Breakpoints.mobile, 768);
      expect(Breakpoints.maxDetailWidth, 900);
    });
  });

  group('ResponsiveUtils.gridColumnCount', () {
    testWidgets('task: phone (<600) returns 2', (tester) async {
      await tester.pumpWidget(buildContext(width: 400));
      final context = getContext(tester);
      expect(
        ResponsiveUtils.gridColumnCount(context, type: GridItemType.task),
        2,
      );
    });

    testWidgets('task: tablet portrait (600-900) returns 2', (tester) async {
      await tester.pumpWidget(buildContext(width: 700));
      final context = getContext(tester);
      expect(
        ResponsiveUtils.gridColumnCount(context, type: GridItemType.task),
        2,
      );
    });

    testWidgets('task: tablet landscape (900-1200) returns 3', (tester) async {
      await tester.pumpWidget(buildContext(width: 1000));
      final context = getContext(tester);
      expect(
        ResponsiveUtils.gridColumnCount(context, type: GridItemType.task),
        3,
      );
    });

    testWidgets('task: desktop (>1200) returns 4', (tester) async {
      await tester.pumpWidget(buildContext(width: 1400));
      final context = getContext(tester);
      expect(
        ResponsiveUtils.gridColumnCount(context, type: GridItemType.task),
        4,
      );
    });

    testWidgets('fleaMarket: phone returns 2, desktop returns 5', (tester) async {
      await tester.pumpWidget(buildContext(width: 400));
      final phoneContext = getContext(tester);
      expect(
        ResponsiveUtils.gridColumnCount(
          phoneContext,
          type: GridItemType.fleaMarket,
        ),
        2,
      );

      await tester.pumpWidget(buildContext(width: 1400));
      final desktopContext = getContext(tester);
      expect(
        ResponsiveUtils.gridColumnCount(
          desktopContext,
          type: GridItemType.fleaMarket,
        ),
        5,
      );
    });
  });

  group('ResponsiveUtils.detailMaxWidth', () {
    testWidgets('phone returns infinity', (tester) async {
      await tester.pumpWidget(buildContext(width: 400));
      final context = getContext(tester);
      expect(
        ResponsiveUtils.detailMaxWidth(context),
        double.infinity,
      );
    });

    testWidgets('tablet+ returns maxDetailWidth', (tester) async {
      await tester.pumpWidget(buildContext(width: 800));
      final context = getContext(tester);
      expect(
        ResponsiveUtils.detailMaxWidth(context),
        Breakpoints.maxDetailWidth,
      );
    });
  });
}
