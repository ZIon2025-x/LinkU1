import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:link2ur/data/models/user.dart';
import 'package:link2ur/data/models/badge.dart';
import 'package:link2ur/features/profile/views/widgets/user_profile_hero_card.dart';
import 'package:link2ur/l10n/app_localizations.dart';

void main() {
  User _user({
    String name = '周哲',
    String? userLevel,
    bool isExpert = false,
    bool isStudentVerified = true,
    double? avgRating = 4.9,
    int completedTaskCount = 18,
    String? bio = 'UCL 经济系大三在读',
    String? residenceCity = '伦敦',
    DateTime? createdAt,
    UserBadge? displayedBadge,
  }) =>
      User(
        id: '00000099',
        name: name,
        userLevel: userLevel,
        isExpert: isExpert,
        isStudentVerified: isStudentVerified,
        avgRating: avgRating,
        completedTaskCount: completedTaskCount,
        taskCount: 0,
        bio: bio,
        residenceCity: residenceCity,
        createdAt: createdAt ?? DateTime.now().subtract(const Duration(days: 540)),
        displayedBadge: displayedBadge,
      );

  Widget _harness({
    required User user,
    int followers = 236,
    int following = 88,
    int totalReviews = 12,
    bool isSelf = false,
    bool isFollowing = false,
    bool isFollowLoading = false,
    VoidCallback? onFollow,
  }) =>
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: UserProfileHeroCard(
              user: user,
              followersCount: followers,
              followingCount: following,
              totalReviews: totalReviews,
              isSelf: isSelf,
              isFollowing: isFollowing,
              isFollowLoading: isFollowLoading,
              onFollow: onFollow ?? () {},
            ),
          ),
        ),
      );

  testWidgets('renders name + bio + trust strip with three numbers', (tester) async {
    await tester.pumpWidget(_harness(user: _user()));
    await tester.pumpAndSettle();

    expect(find.text('周哲'), findsOneWidget);
    expect(find.text('UCL 经济系大三在读'), findsOneWidget);
    expect(find.text('4.9'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('236'), findsOneWidget);
  });

  testWidgets('shows DisplayedBadge pill only when badge != null', (tester) async {
    await tester.pumpWidget(_harness(user: _user(displayedBadge: null)));
    await tester.pumpAndSettle();
    expect(find.textContaining('排名'), findsNothing);
    expect(find.textContaining('Top'), findsNothing);

    const badge = UserBadge(
      id: 1,
      badgeType: 'skill_rank',
      skillCategory: 'tutoring',
      city: '伦敦',
      rank: '8',
    );
    await tester.pumpWidget(_harness(user: _user(displayedBadge: badge)));
    await tester.pumpAndSettle();
    expect(find.textContaining('伦敦'), findsAtLeast(1));
    expect(find.textContaining('8'), findsAtLeast(1));
  });

  testWidgets('renders cleanly when user_level == vip', (tester) async {
    await tester.pumpWidget(_harness(user: _user(userLevel: 'vip')));
    await tester.pumpAndSettle();
    expect(find.byType(UserProfileHeroCard), findsOneWidget);
  });

  testWidgets('hides follow button when isSelf == true', (tester) async {
    await tester.pumpWidget(_harness(user: _user(), isSelf: true));
    await tester.pumpAndSettle();
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('shows ElevatedButton when isSelf == false and not following', (tester) async {
    await tester.pumpWidget(_harness(user: _user(), isSelf: false, isFollowing: false));
    await tester.pumpAndSettle();
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('shows OutlinedButton when already following', (tester) async {
    await tester.pumpWidget(_harness(user: _user(), isSelf: false, isFollowing: true));
    await tester.pumpAndSettle();
    expect(find.byType(OutlinedButton), findsOneWidget);
  });
}
