import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/skill_leaderboard/bloc/skill_leaderboard_bloc.dart';
import 'package:link2ur/data/models/skill_category.dart';
import 'package:link2ur/data/models/skill_leaderboard_entry.dart';
import 'package:link2ur/data/repositories/skill_leaderboard_repository.dart';

class MockSkillLeaderboardRepository extends Mock
    implements SkillLeaderboardRepository {}

void main() {
  late MockSkillLeaderboardRepository mockRepository;
  late SkillLeaderboardBloc bloc;

  // Mock data
  final categoriesData = <Map<String, dynamic>>[
    {
      'id': 1,
      'name_zh': '编程',
      'name_en': 'Programming',
      'icon': null,
      'display_order': 1,
      'is_active': true,
    },
    {
      'id': 2,
      'name_zh': '设计',
      'name_en': 'Design',
      'icon': null,
      'display_order': 2,
      'is_active': true,
    },
  ];

  final entriesData = <Map<String, dynamic>>[
    {
      'user_id': 'user1',
      'user_name': 'Alice',
      'user_avatar': null,
      'skill_category': 'Programming',
      'completed_tasks': 10,
      'total_amount': 5000,
      'avg_rating': 4.8,
      'score': 598.0,
      'rank': 1,
    },
  ];

  final myRankData = <String, dynamic>{
    'user_id': 'me',
    'user_name': 'Me',
    'user_avatar': null,
    'skill_category': 'Programming',
    'completed_tasks': 5,
    'total_amount': 2000,
    'avg_rating': 4.5,
    'score': 295.0,
    'rank': 8,
  };

  final expectedCategories =
      categoriesData.map((e) => SkillCategory.fromJson(e)).toList();
  final expectedEntries =
      entriesData.map((e) => SkillLeaderboardEntry.fromJson(e)).toList();
  final expectedMyRank = SkillLeaderboardEntry.fromJson(myRankData);

  setUp(() {
    mockRepository = MockSkillLeaderboardRepository();
    bloc = SkillLeaderboardBloc(skillLeaderboardRepository: mockRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('SkillLeaderboardBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, equals(LeaderboardStatus.initial));
      expect(bloc.state.categories, isEmpty);
      expect(bloc.state.entries, isEmpty);
      expect(bloc.state.selectedCategory, isNull);
      expect(bloc.state.myRank, isNull);
      expect(bloc.state.errorMessage, isNull);
    });

    // ==================== Load ====================

    group('LeaderboardLoadRequested', () {
      blocTest<SkillLeaderboardBloc, SkillLeaderboardState>(
        'emits [loading, loaded] with categories + entries + myRank on success',
        build: () {
          when(() => mockRepository.getCategories())
              .thenAnswer((_) async => categoriesData);
          when(() => mockRepository.getLeaderboard('Programming'))
              .thenAnswer((_) async => entriesData);
          when(() => mockRepository.getMyRank('Programming'))
              .thenAnswer((_) async => myRankData);
          return bloc;
        },
        act: (bloc) => bloc.add(const LeaderboardLoadRequested()),
        expect: () => [
          isA<SkillLeaderboardState>()
              .having((s) => s.status, 'status', LeaderboardStatus.loading),
          isA<SkillLeaderboardState>()
              .having((s) => s.status, 'status', LeaderboardStatus.loaded)
              .having((s) => s.categories, 'categories', expectedCategories)
              .having((s) => s.entries, 'entries', expectedEntries)
              .having(
                  (s) => s.selectedCategory, 'selectedCategory', 'Programming')
              .having((s) => s.myRank, 'myRank', expectedMyRank),
        ],
        verify: (_) {
          verify(() => mockRepository.getCategories()).called(1);
          verify(() => mockRepository.getLeaderboard('Programming')).called(1);
          verify(() => mockRepository.getMyRank('Programming')).called(1);
        },
      );

      blocTest<SkillLeaderboardBloc, SkillLeaderboardState>(
        'emits [loading, loaded] with empty categories (entries empty)',
        build: () {
          when(() => mockRepository.getCategories())
              .thenAnswer((_) async => <Map<String, dynamic>>[]);
          return bloc;
        },
        act: (bloc) => bloc.add(const LeaderboardLoadRequested()),
        expect: () => [
          isA<SkillLeaderboardState>()
              .having((s) => s.status, 'status', LeaderboardStatus.loading),
          isA<SkillLeaderboardState>()
              .having((s) => s.status, 'status', LeaderboardStatus.loaded)
              .having((s) => s.categories, 'categories', isEmpty)
              .having((s) => s.entries, 'entries', isEmpty)
              .having((s) => s.myRank, 'myRank', isNull),
        ],
        verify: (_) {
          verify(() => mockRepository.getCategories()).called(1);
          verifyNever(() => mockRepository.getLeaderboard(any()));
          verifyNever(() => mockRepository.getMyRank(any()));
        },
      );

      blocTest<SkillLeaderboardBloc, SkillLeaderboardState>(
        'emits [loading, error] on failure',
        build: () {
          when(() => mockRepository.getCategories())
              .thenThrow(Exception('network error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const LeaderboardLoadRequested()),
        expect: () => [
          isA<SkillLeaderboardState>()
              .having((s) => s.status, 'status', LeaderboardStatus.loading),
          isA<SkillLeaderboardState>()
              .having((s) => s.status, 'status', LeaderboardStatus.error)
              .having((s) => s.errorMessage, 'errorMessage',
                  'leaderboard_load_failed'),
        ],
      );
    });

    // ==================== Category Selected ====================

    group('LeaderboardCategorySelected', () {
      blocTest<SkillLeaderboardBloc, SkillLeaderboardState>(
        'emits [loading, loaded] with new entries for selected category',
        build: () {
          when(() => mockRepository.getLeaderboard('Design'))
              .thenAnswer((_) async => entriesData);
          when(() => mockRepository.getMyRank('Design'))
              .thenAnswer((_) async => myRankData);
          return bloc;
        },
        act: (bloc) => bloc.add(const LeaderboardCategorySelected('Design')),
        expect: () => [
          isA<SkillLeaderboardState>()
              .having((s) => s.status, 'status', LeaderboardStatus.loading)
              .having(
                  (s) => s.selectedCategory, 'selectedCategory', 'Design'),
          isA<SkillLeaderboardState>()
              .having((s) => s.status, 'status', LeaderboardStatus.loaded)
              .having((s) => s.entries, 'entries', expectedEntries)
              .having((s) => s.myRank, 'myRank', expectedMyRank),
        ],
        verify: (_) {
          verify(() => mockRepository.getLeaderboard('Design')).called(1);
          verify(() => mockRepository.getMyRank('Design')).called(1);
        },
      );

      blocTest<SkillLeaderboardBloc, SkillLeaderboardState>(
        'emits [loading, error] on failure',
        build: () {
          when(() => mockRepository.getLeaderboard('Design'))
              .thenThrow(Exception('load failed'));
          return bloc;
        },
        act: (bloc) => bloc.add(const LeaderboardCategorySelected('Design')),
        expect: () => [
          isA<SkillLeaderboardState>()
              .having((s) => s.status, 'status', LeaderboardStatus.loading),
          isA<SkillLeaderboardState>()
              .having((s) => s.status, 'status', LeaderboardStatus.error)
              .having((s) => s.errorMessage, 'errorMessage',
                  'leaderboard_category_load_failed'),
        ],
      );
    });

    // ==================== My Rank ====================

    group('LeaderboardMyRankRequested', () {
      blocTest<SkillLeaderboardBloc, SkillLeaderboardState>(
        'updates myRank on success',
        build: () {
          when(() => mockRepository.getMyRank('Programming'))
              .thenAnswer((_) async => myRankData);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const LeaderboardMyRankRequested('Programming')),
        expect: () => [
          isA<SkillLeaderboardState>()
              .having((s) => s.myRank, 'myRank', expectedMyRank),
        ],
        verify: (_) {
          verify(() => mockRepository.getMyRank('Programming')).called(1);
        },
      );

      blocTest<SkillLeaderboardBloc, SkillLeaderboardState>(
        'emits error and clears myRank on failure',
        build: () {
          when(() => mockRepository.getMyRank('Programming'))
              .thenThrow(Exception('rank fetch failed'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const LeaderboardMyRankRequested('Programming')),
        expect: () => [
          isA<SkillLeaderboardState>()
              .having((s) => s.errorMessage, 'errorMessage',
                  'leaderboard_my_rank_failed')
              .having((s) => s.myRank, 'myRank', isNull),
        ],
      );
    });
  });
}
