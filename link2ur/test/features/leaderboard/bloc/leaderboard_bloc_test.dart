import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/leaderboard/bloc/leaderboard_bloc.dart';
import 'package:link2ur/data/models/leaderboard.dart';
import 'package:link2ur/data/repositories/leaderboard_repository.dart';

class MockLeaderboardRepository extends Mock
    implements LeaderboardRepository {}

void main() {
  late MockLeaderboardRepository mockRepo;
  late LeaderboardBloc bloc;

  const testLeaderboard = Leaderboard(
    id: 1,
    name: 'Best Coffee Shops',
    location: 'London',
    applicantId: 'user1',
    itemCount: 5,
    voteCount: 100,
  );

  const testLeaderboard2 = Leaderboard(
    id: 2,
    name: 'Top Restaurants',
    location: 'Manchester',
    applicantId: 'user2',
    itemCount: 3,
  );

  const testListResponse = LeaderboardListResponse(
    leaderboards: [testLeaderboard, testLeaderboard2],
    total: 2,
    page: 1,
    pageSize: 20,
  );

  const testItem = LeaderboardItem(
    id: 1,
    leaderboardId: 1,
    name: 'Coffee Lab',
    submittedBy: 'user1',
    upvotes: 10,
    downvotes: 2,
    netVotes: 8,
  );

  const testItemsResponse = LeaderboardItemsResponse(
    items: [testItem],
    total: 1,
    hasMore: false,
  );

  setUp(() {
    mockRepo = MockLeaderboardRepository();
    bloc = LeaderboardBloc(leaderboardRepository: mockRepo);
  });

  tearDown(() {
    bloc.close();
  });

  group('LeaderboardBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, equals(LeaderboardStatus.initial));
      expect(bloc.state.leaderboards, isEmpty);
      expect(bloc.state.selectedLeaderboard, isNull);
      expect(bloc.state.items, isEmpty);
    });

    group('LeaderboardLoadRequested', () {
      blocTest<LeaderboardBloc, LeaderboardState>(
        'emits [loading, loaded] with leaderboards on success',
        build: () {
          when(() => mockRepo.getLeaderboards(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                keyword: any(named: 'keyword'),
                location: any(named: 'location'),
                sort: any(named: 'sort'),
              )).thenAnswer((_) async => testListResponse);
          when(() => mockRepo.getFavoritesBatch(any()))
              .thenAnswer((_) async => {1: true, 2: false});
          return bloc;
        },
        act: (bloc) => bloc.add(const LeaderboardLoadRequested()),
        expect: () => [
          const LeaderboardState(status: LeaderboardStatus.loading),
          isA<LeaderboardState>()
              .having((s) => s.status, 'status',
                  LeaderboardStatus.loaded)
              .having((s) => s.leaderboards.length,
                  'leaderboards.length', 2),
          // Extra emission from _loadLeaderboardFavoritesBatch
          isA<LeaderboardState>()
              .having((s) => s.leaderboards.first.isFavorited,
                  'first.isFavorited', isTrue),
        ],
      );

      blocTest<LeaderboardBloc, LeaderboardState>(
        'emits [loading, error] when load fails',
        build: () {
          when(() => mockRepo.getLeaderboards(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                keyword: any(named: 'keyword'),
                location: any(named: 'location'),
                sort: any(named: 'sort'),
              )).thenThrow(Exception('Network error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const LeaderboardLoadRequested()),
        expect: () => [
          const LeaderboardState(status: LeaderboardStatus.loading),
          isA<LeaderboardState>()
              .having((s) => s.status, 'status',
                  LeaderboardStatus.error)
              .having(
                  (s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('LeaderboardSearchChanged', () {
      blocTest<LeaderboardBloc, LeaderboardState>(
        'reloads with search keyword',
        build: () {
          when(() => mockRepo.getLeaderboards(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                keyword: any(named: 'keyword'),
                location: any(named: 'location'),
                sort: any(named: 'sort'),
              )).thenAnswer((_) async => const LeaderboardListResponse(
                leaderboards: [testLeaderboard],
                total: 1,
                page: 1,
                pageSize: 20,
              ));
          when(() => mockRepo.getFavoritesBatch(any()))
              .thenAnswer((_) async => {});
          return bloc;
        },
        act: (bloc) => bloc.add(
            const LeaderboardSearchChanged('coffee')),
        expect: () => [
          isA<LeaderboardState>()
              .having((s) => s.status, 'status', LeaderboardStatus.loading)
              .having((s) => s.searchKeyword, 'searchKeyword', 'coffee'),
          isA<LeaderboardState>()
              .having((s) => s.status, 'status', LeaderboardStatus.loaded)
              .having((s) => s.leaderboards.length,
                  'leaderboards.length', 1),
        ],
      );
    });

    group('LeaderboardLoadMore', () {
      blocTest<LeaderboardBloc, LeaderboardState>(
        'appends more leaderboards',
        build: () {
          when(() => mockRepo.getLeaderboards(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                keyword: any(named: 'keyword'),
                location: any(named: 'location'),
                sort: any(named: 'sort'),
              )).thenAnswer((_) async => const LeaderboardListResponse(
                leaderboards: [testLeaderboard2],
                total: 3,
                page: 2,
                pageSize: 20,
              ));
          when(() => mockRepo.getFavoritesBatch(any()))
              .thenAnswer((_) async => {});
          return bloc;
        },
        seed: () => const LeaderboardState(
          status: LeaderboardStatus.loaded,
          leaderboards: [testLeaderboard],
        ),
        act: (bloc) => bloc.add(const LeaderboardLoadMore()),
        expect: () => [
          isA<LeaderboardState>()
              .having((s) => s.leaderboards.length,
                  'leaderboards.length', 2),
        ],
      );

      blocTest<LeaderboardBloc, LeaderboardState>(
        'does nothing when hasMore is false',
        build: () => bloc,
        seed: () => const LeaderboardState(
          status: LeaderboardStatus.loaded,
          leaderboards: [testLeaderboard],
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const LeaderboardLoadMore()),
        expect: () => [],
      );
    });

    group('LeaderboardLoadDetail', () {
      blocTest<LeaderboardBloc, LeaderboardState>(
        'loads leaderboard detail with items',
        build: () {
          when(() => mockRepo.getLeaderboardById(any()))
              .thenAnswer((_) async => testLeaderboard);
          when(() => mockRepo.getLeaderboardItems(
                any(),
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                sortBy: any(named: 'sortBy'),
                keyword: any(named: 'keyword'),
              )).thenAnswer((_) async => testItemsResponse);
          when(() => mockRepo.getFavoriteStatus(any()))
              .thenAnswer((_) async => true);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const LeaderboardLoadDetail(1)),
        expect: () => [
          isA<LeaderboardState>()
              .having((s) => s.status, 'status',
                  LeaderboardStatus.loading),
          isA<LeaderboardState>()
              .having((s) => s.status, 'status',
                  LeaderboardStatus.loaded)
              .having((s) => s.selectedLeaderboard?.isFavorited,
                  'selectedLeaderboard.isFavorited', isTrue)
              .having(
                  (s) => s.items.length, 'items.length', 1)
              .having((s) => s.isFavorited, 'isFavorited', isTrue),
        ],
      );

      blocTest<LeaderboardBloc, LeaderboardState>(
        'emits error when detail load fails',
        build: () {
          when(() => mockRepo.getLeaderboardById(any()))
              .thenThrow(Exception('Not found'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const LeaderboardLoadDetail(99)),
        expect: () => [
          isA<LeaderboardState>()
              .having((s) => s.status, 'status',
                  LeaderboardStatus.loading),
          isA<LeaderboardState>()
              .having((s) => s.status, 'status',
                  LeaderboardStatus.error),
        ],
      );
    });

    group('LeaderboardVoteItem', () {
      blocTest<LeaderboardBloc, LeaderboardState>(
        'performs optimistic vote update',
        build: () {
          when(() => mockRepo.voteItem(any(),
                  voteType: any(named: 'voteType'),
                  comment: any(named: 'comment'),
                  isAnonymous: any(named: 'isAnonymous')))
              .thenAnswer((_) async => {'success': true});
          when(() => mockRepo.getItemVotes(any()))
              .thenAnswer((_) async => []);
          return bloc;
        },
        seed: () => const LeaderboardState(
          status: LeaderboardStatus.loaded,
          items: [testItem],
        ),
        act: (bloc) => bloc.add(const LeaderboardVoteItem(
          1,
          voteType: 'up',
        )),
        expect: () => [
          // Optimistic update
          isA<LeaderboardState>()
              .having((s) => s.items.first.userVote, 'userVote', 'up'),
          // After API success + votes reload
          isA<LeaderboardState>(),
        ],
      );
    });

    group('LeaderboardSortChanged', () {
      blocTest<LeaderboardBloc, LeaderboardState>(
        'updates sort and reloads items',
        build: () {
          when(() => mockRepo.getLeaderboardItems(
                any(),
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                sortBy: any(named: 'sortBy'),
                keyword: any(named: 'keyword'),
              )).thenAnswer((_) async => testItemsResponse);
          return bloc;
        },
        seed: () => const LeaderboardState(
          status: LeaderboardStatus.loaded,
          selectedLeaderboard: testLeaderboard,
          items: [testItem],
        ),
        act: (bloc) => bloc.add(
            const LeaderboardSortChanged('newest', leaderboardId: 1)),
        expect: () => [
          isA<LeaderboardState>()
              .having((s) => s.sortBy, 'sortBy', 'newest')
              .having(
                  (s) => s.isLoadingItems, 'isLoadingItems', isTrue),
          isA<LeaderboardState>()
              .having(
                  (s) => s.isLoadingItems, 'isLoadingItems', isFalse)
              .having(
                  (s) => s.items.length, 'items.length', 1),
        ],
      );
    });

    group('LeaderboardToggleFavorite', () {
      blocTest<LeaderboardBloc, LeaderboardState>(
        'toggles favorite optimistically',
        build: () {
          when(() => mockRepo.toggleFavorite(any()))
              .thenAnswer((_) async {});
          return bloc;
        },
        seed: () => const LeaderboardState(
          status: LeaderboardStatus.loaded,
          selectedLeaderboard: testLeaderboard,
        ),
        act: (bloc) => bloc.add(
            const LeaderboardToggleFavorite(1)),
        expect: () => [
          isA<LeaderboardState>()
              .having((s) => s.isFavorited, 'isFavorited', isTrue),
        ],
      );
    });

    group('LeaderboardApplyRequested', () {
      blocTest<LeaderboardBloc, LeaderboardState>(
        'submits new leaderboard application on success',
        build: () {
          when(() => mockRepo.applyLeaderboard(
                name: any(named: 'name'),
                location: any(named: 'location'),
                description: any(named: 'description'),
                coverImage: any(named: 'coverImage'),
                applicationReason: any(named: 'applicationReason'),
              )).thenAnswer((_) async => testLeaderboard);
          return bloc;
        },
        act: (bloc) => bloc.add(const LeaderboardApplyRequested(
          name: 'Best Cafes',
          location: 'London',
        )),
        expect: () => [
          isA<LeaderboardState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<LeaderboardState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'leaderboard_applied'),
        ],
      );

      blocTest<LeaderboardBloc, LeaderboardState>(
        'emits error on application failure',
        build: () {
          when(() => mockRepo.applyLeaderboard(
                name: any(named: 'name'),
                location: any(named: 'location'),
                description: any(named: 'description'),
                coverImage: any(named: 'coverImage'),
                applicationReason: any(named: 'applicationReason'),
              )).thenThrow(Exception('Failed'));
          return bloc;
        },
        act: (bloc) => bloc.add(const LeaderboardApplyRequested(
          name: 'Bad',
          location: 'Nowhere',
        )),
        expect: () => [
          isA<LeaderboardState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<LeaderboardState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage', isNotNull),
        ],
      );
    });

    group('LeaderboardSubmitItem', () {
      blocTest<LeaderboardBloc, LeaderboardState>(
        'submits item to leaderboard on success',
        build: () {
          when(() => mockRepo.submitItem(
                leaderboardId: any(named: 'leaderboardId'),
                name: any(named: 'name'),
                description: any(named: 'description'),
                address: any(named: 'address'),
                phone: any(named: 'phone'),
                website: any(named: 'website'),
                images: any(named: 'images'),
              )).thenAnswer((_) async => testItem);
          when(() => mockRepo.getLeaderboardItems(
                any(),
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                sortBy: any(named: 'sortBy'),
                keyword: any(named: 'keyword'),
              )).thenAnswer((_) async => testItemsResponse);
          return bloc;
        },
        seed: () => const LeaderboardState(
          status: LeaderboardStatus.loaded,
          selectedLeaderboard: testLeaderboard,
        ),
        act: (bloc) => bloc.add(const LeaderboardSubmitItem(
          leaderboardId: 1,
          name: 'New Coffee Shop',
        )),
        expect: () => [
          isA<LeaderboardState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<LeaderboardState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'leaderboard_submitted'),
        ],
      );
    });

    group('LeaderboardClearActionMessage', () {
      blocTest<LeaderboardBloc, LeaderboardState>(
        'clears action message',
        build: () => bloc,
        seed: () => const LeaderboardState(
          status: LeaderboardStatus.loaded,
          actionMessage: 'some_action',
        ),
        act: (bloc) =>
            bloc.add(const LeaderboardClearActionMessage()),
        expect: () => [
          isA<LeaderboardState>()
              .having(
                  (s) => s.actionMessage, 'actionMessage', isNull),
        ],
      );
    });

    group('LeaderboardLoadItemDetail', () {
      blocTest<LeaderboardBloc, LeaderboardState>(
        'loads item detail',
        build: () {
          when(() => mockRepo.getItemDetail(any()))
              .thenAnswer((_) async => {
                    'id': 1,
                    'name': 'Coffee Lab',
                    'leaderboard_id': 1,
                    'submitted_by': 'user1',
                  });
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const LeaderboardLoadItemDetail(1)),
        expect: () => [
          isA<LeaderboardState>()
              .having((s) => s.status, 'status',
                  LeaderboardStatus.loading),
          isA<LeaderboardState>()
              .having((s) => s.status, 'status',
                  LeaderboardStatus.loaded)
              .having(
                  (s) => s.itemDetail, 'itemDetail', isNotNull),
        ],
      );
    });

    group('LeaderboardState helpers', () {
      test('props are correct', () {
        const state = LeaderboardState();
        expect(state.props.length, greaterThan(0));
      });
    });
  });
}
