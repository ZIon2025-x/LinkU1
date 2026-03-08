import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/badges/bloc/badges_bloc.dart';
import 'package:link2ur/data/models/badge.dart';
import 'package:link2ur/data/repositories/badges_repository.dart';

class MockBadgesRepository extends Mock implements BadgesRepository {}

void main() {
  late MockBadgesRepository mockBadgesRepository;
  late BadgesBloc bloc;

  // Mock data
  final badgesData = <Map<String, dynamic>>[
    {
      'id': 1,
      'badge_type': 'skill_rank',
      'skill_category': 'Programming',
      'rank': '1',
      'is_displayed': true,
      'granted_at': '2026-01-01T00:00:00.000Z',
    },
    {
      'id': 2,
      'badge_type': 'skill_rank',
      'skill_category': 'Design',
      'rank': '5',
      'is_displayed': false,
      'granted_at': '2026-01-02T00:00:00.000Z',
    },
  ];

  final expectedBadges =
      badgesData.map((e) => UserBadge.fromJson(e)).toList();

  setUp(() {
    mockBadgesRepository = MockBadgesRepository();
    bloc = BadgesBloc(badgesRepository: mockBadgesRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('BadgesBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, equals(BadgesStatus.initial));
      expect(bloc.state.badges, isEmpty);
      expect(bloc.state.errorMessage, isNull);
    });

    // ==================== Load ====================

    group('BadgesLoadRequested', () {
      blocTest<BadgesBloc, BadgesState>(
        'emits [loading, loaded] with badges on success',
        build: () {
          when(() => mockBadgesRepository.getMyBadges())
              .thenAnswer((_) async => badgesData);
          return bloc;
        },
        act: (bloc) => bloc.add(const BadgesLoadRequested()),
        expect: () => [
          isA<BadgesState>()
              .having((s) => s.status, 'status', BadgesStatus.loading),
          isA<BadgesState>()
              .having((s) => s.status, 'status', BadgesStatus.loaded)
              .having((s) => s.badges, 'badges', expectedBadges),
        ],
        verify: (_) {
          verify(() => mockBadgesRepository.getMyBadges()).called(1);
        },
      );

      blocTest<BadgesBloc, BadgesState>(
        'emits [loading, error] on failure',
        build: () {
          when(() => mockBadgesRepository.getMyBadges())
              .thenThrow(Exception('network error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const BadgesLoadRequested()),
        expect: () => [
          isA<BadgesState>()
              .having((s) => s.status, 'status', BadgesStatus.loading),
          isA<BadgesState>()
              .having((s) => s.status, 'status', BadgesStatus.error)
              .having(
                  (s) => s.errorMessage, 'errorMessage', 'badges_load_failed'),
        ],
      );
    });

    // ==================== Toggle Display ====================

    group('BadgeDisplayToggled', () {
      blocTest<BadgesBloc, BadgesState>(
        'toggles display then triggers reload',
        build: () {
          when(() => mockBadgesRepository.toggleBadgeDisplay(1))
              .thenAnswer((_) async => <String, dynamic>{'success': true});
          // The bloc calls add(BadgesLoadRequested()) after toggle success
          when(() => mockBadgesRepository.getMyBadges())
              .thenAnswer((_) async => badgesData);
          return bloc;
        },
        act: (bloc) => bloc.add(const BadgeDisplayToggled(1)),
        expect: () => [
          // Reload sequence — loading
          isA<BadgesState>()
              .having((s) => s.status, 'status', BadgesStatus.loading),
          // Reload sequence — loaded
          isA<BadgesState>()
              .having((s) => s.status, 'status', BadgesStatus.loaded)
              .having((s) => s.badges, 'badges', expectedBadges),
        ],
        verify: (_) {
          verify(() => mockBadgesRepository.toggleBadgeDisplay(1)).called(1);
          verify(() => mockBadgesRepository.getMyBadges()).called(1);
        },
      );

      blocTest<BadgesBloc, BadgesState>(
        'emits error on failure',
        build: () {
          when(() => mockBadgesRepository.toggleBadgeDisplay(1))
              .thenThrow(Exception('toggle failed'));
          return bloc;
        },
        act: (bloc) => bloc.add(const BadgeDisplayToggled(1)),
        expect: () => [
          isA<BadgesState>()
              .having(
                  (s) => s.errorMessage, 'errorMessage', 'badge_toggle_failed'),
        ],
      );
    });

    // ==================== Getters ====================

    group('displayedBadges', () {
      test('returns only displayed badges', () {
        // Create a state with mixed displayed/not-displayed badges
        final state = BadgesState(
          status: BadgesStatus.loaded,
          badges: expectedBadges,
        );

        final displayed = state.displayedBadges;
        expect(displayed, hasLength(1));
        expect(displayed.first.id, equals(1));
        expect(displayed.first.isDisplayed, isTrue);
      });
    });
  });
}
