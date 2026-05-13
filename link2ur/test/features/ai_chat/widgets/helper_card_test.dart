import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:link2ur/features/ai_chat/widgets/task_result_cards.dart';
import 'package:link2ur/l10n/app_localizations.dart';

/// 构造带 GoRouter 的测试路由，捕获跳转路径
GoRouter _testRouter(List<String> capturedPushes) {
  return GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(
        path: '/test',
        builder: (_, __) => Scaffold(
          body: TaskResultCards(toolResult: {
            'helpers': [
              {
                'user_id': 'u_001',
                'name': 'Alice',
                'avatar_url': null,
                'source': 'service',
                'match_score': 0.92,
                'match_reason': '发布了陪逛服务,评分 4.8(伦敦)',
                'profile_url': '/profile/u_001',
              },
            ],
          }),
        ),
      ),
      GoRoute(
        path: '/profile/:id',
        redirect: (_, state) {
          capturedPushes.add(state.uri.path);
          return '/test';
        },
        builder: (_, __) => const SizedBox(),
      ),
    ],
  );
}

Widget _wrapWithRouter(GoRouter router) {
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  testWidgets('HelperCard renders name and match_reason', (tester) async {
    await tester.pumpWidget(_wrapWithRouter(_testRouter([])));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('发布了陪逛服务,评分 4.8(伦敦)'), findsOneWidget);
  });

  testWidgets('Tapping HelperCard navigates to profile_url', (tester) async {
    final captured = <String>[];
    await tester.pumpWidget(_wrapWithRouter(_testRouter(captured)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();

    expect(captured, contains('/profile/u_001'));
  });

  testWidgets('Empty helpers list renders nothing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TaskResultCards(toolResult: const {'helpers': []}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsNothing);
  });
}
