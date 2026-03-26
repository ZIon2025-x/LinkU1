import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/search/bloc/search_bloc.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  late MockTaskRepository mockTaskRepo;
  late MockForumRepository mockForumRepo;
  late MockFleaMarketRepository mockFleaMarketRepo;
  late MockTaskExpertRepository mockTaskExpertRepo;
  late MockActivityRepository mockActivityRepo;
  late MockLeaderboardRepository mockLeaderboardRepo;
  late MockPersonalServiceRepository mockPersonalServiceRepo;
  late SearchBloc bloc;

  setUp(() {
    mockTaskRepo = MockTaskRepository();
    mockForumRepo = MockForumRepository();
    mockFleaMarketRepo = MockFleaMarketRepository();
    mockTaskExpertRepo = MockTaskExpertRepository();
    mockActivityRepo = MockActivityRepository();
    mockLeaderboardRepo = MockLeaderboardRepository();
    mockPersonalServiceRepo = MockPersonalServiceRepository();
    bloc = SearchBloc(
      taskRepository: mockTaskRepo,
      forumRepository: mockForumRepo,
      fleaMarketRepository: mockFleaMarketRepo,
      taskExpertRepository: mockTaskExpertRepo,
      activityRepository: mockActivityRepo,
      leaderboardRepository: mockLeaderboardRepo,
      personalServiceRepository: mockPersonalServiceRepo,
    );
  });

  tearDown(() {
    bloc.close();
  });

  group('SearchBloc', () {
    // ==================== Initial State ====================

    test('initial state is correct', () {
      expect(bloc.state.status, equals(SearchStatus.initial));
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.taskResults, isEmpty);
      expect(bloc.state.forumResults, isEmpty);
      expect(bloc.state.fleaMarketResults, isEmpty);
      expect(bloc.state.expertResults, isEmpty);
      expect(bloc.state.activityResults, isEmpty);
      expect(bloc.state.leaderboardResults, isEmpty);
      expect(bloc.state.leaderboardItemResults, isEmpty);
      expect(bloc.state.forumCategoryResults, isEmpty);
      expect(bloc.state.recentSearches, isEmpty);
      expect(bloc.state.errorMessage, isNull);
      expect(bloc.state.searchPage, equals(1));
      expect(bloc.state.searchHasMore, isTrue);
      expect(bloc.state.hasResults, isFalse);
      expect(bloc.state.totalResults, equals(0));
      expect(bloc.state.isLoading, isFalse);
    });

    // ==================== SearchState helpers ====================

    group('SearchState computed properties', () {
      test('isLoading returns true when status is loading', () {
        const state = SearchState(status: SearchStatus.loading);
        expect(state.isLoading, isTrue);
      });

      test('isLoading returns false when status is loaded', () {
        const state = SearchState(status: SearchStatus.loaded);
        expect(state.isLoading, isFalse);
      });

      test('hasResults returns true when any result list is non-empty', () {
        const state = SearchState(
          taskResults: [
            {'id': 1, 'title': 'test', 'type': 'task'}
          ],
        );
        expect(state.hasResults, isTrue);
      });

      test('hasResults returns false when all result lists are empty', () {
        const state = SearchState();
        expect(state.hasResults, isFalse);
      });

      test('totalResults sums all result list lengths', () {
        const state = SearchState(
          taskResults: [
            {'id': 1, 'title': 't', 'type': 'task'},
          ],
          forumResults: [
            {'id': 2, 'title': 'f', 'type': 'forum'},
            {'id': 3, 'title': 'f2', 'type': 'forum'},
          ],
          expertResults: [
            {'id': 4, 'title': 'e', 'type': 'expert'},
          ],
        );
        expect(state.totalResults, equals(4));
      });
    });

    // ==================== SearchCleared ====================

    group('SearchCleared', () {
      blocTest<SearchBloc, SearchState>(
        'resets all results and status to initial',
        build: () => bloc,
        seed: () => const SearchState(
          status: SearchStatus.loaded,
          query: 'flutter',
          taskResults: [
            {'id': 1, 'title': 'Task 1', 'type': 'task'}
          ],
          forumResults: [
            {'id': 2, 'title': 'Forum Post', 'type': 'forum'}
          ],
          fleaMarketResults: [
            {'id': 3, 'title': 'Item', 'type': 'flea_market'}
          ],
          expertResults: [
            {'id': 4, 'title': 'Expert', 'type': 'expert'}
          ],
          activityResults: [
            {'id': 5, 'title': 'Activity', 'type': 'activity'}
          ],
          leaderboardResults: [
            {'id': 6, 'title': 'Leaderboard', 'type': 'leaderboard'}
          ],
          leaderboardItemResults: [
            {'id': 7, 'title': 'LB Item', 'type': 'leaderboard_item'}
          ],
          forumCategoryResults: [
            {'id': 8, 'title': 'Category', 'type': 'forum_category'}
          ],
          recentSearches: ['flutter', 'dart'],
        ),
        act: (bloc) => bloc.add(const SearchCleared()),
        expect: () => [
          isA<SearchState>()
              .having((s) => s.status, 'status', SearchStatus.initial)
              .having((s) => s.query, 'query', '')
              .having((s) => s.taskResults, 'taskResults', isEmpty)
              .having((s) => s.forumResults, 'forumResults', isEmpty)
              .having(
                  (s) => s.fleaMarketResults, 'fleaMarketResults', isEmpty)
              .having((s) => s.expertResults, 'expertResults', isEmpty)
              .having(
                  (s) => s.activityResults, 'activityResults', isEmpty)
              .having((s) => s.leaderboardResults, 'leaderboardResults',
                  isEmpty)
              .having((s) => s.leaderboardItemResults,
                  'leaderboardItemResults', isEmpty)
              .having((s) => s.forumCategoryResults,
                  'forumCategoryResults', isEmpty),
        ],
      );

      blocTest<SearchBloc, SearchState>(
        'preserves recentSearches when clearing search results',
        build: () => bloc,
        seed: () => const SearchState(
          status: SearchStatus.loaded,
          query: 'test',
          taskResults: [
            {'id': 1, 'title': 'x', 'type': 'task'}
          ],
          recentSearches: ['previous_search'],
        ),
        act: (bloc) => bloc.add(const SearchCleared()),
        expect: () => [
          isA<SearchState>()
              .having((s) => s.status, 'status', SearchStatus.initial)
              .having((s) => s.recentSearches, 'recentSearches',
                  ['previous_search']),
        ],
      );

      blocTest<SearchBloc, SearchState>(
        'can be called from initial state without error',
        build: () => bloc,
        act: (bloc) => bloc.add(const SearchCleared()),
        // _onCleared always emits via copyWith; even though values match
        // initial defaults, the new list instances differ from const [],
        // so Equatable does NOT deduplicate.
        expect: () => [
          isA<SearchState>()
              .having((s) => s.status, 'status', SearchStatus.initial)
              .having((s) => s.query, 'query', ''),
        ],
      );
    });

    // ==================== SearchLoadMore ====================

    group('SearchLoadMore', () {
      blocTest<SearchBloc, SearchState>(
        'is a no-op and emits nothing when searchHasMore is true',
        build: () => bloc,
        seed: () => const SearchState(
          status: SearchStatus.loaded,
          query: 'flutter',
        ),
        act: (bloc) => bloc.add(const SearchLoadMore()),
        expect: () => [],
      );

      blocTest<SearchBloc, SearchState>(
        'is a no-op and emits nothing when searchHasMore is false',
        build: () => bloc,
        seed: () => const SearchState(
          status: SearchStatus.loaded,
          query: 'flutter',
          searchHasMore: false,
        ),
        act: (bloc) => bloc.add(const SearchLoadMore()),
        expect: () => [],
      );

      blocTest<SearchBloc, SearchState>(
        'is a no-op and emits nothing when already loading',
        build: () => bloc,
        seed: () => const SearchState(
          status: SearchStatus.loading,
          query: 'flutter',
        ),
        act: (bloc) => bloc.add(const SearchLoadMore()),
        expect: () => [],
      );
    });

    // ==================== SearchSubmitted ====================

    group('SearchSubmitted', () {
      blocTest<SearchBloc, SearchState>(
        'does nothing when query is empty',
        build: () => bloc,
        act: (bloc) => bloc.add(const SearchSubmitted('')),
        wait: const Duration(milliseconds: 600),
        expect: () => [],
      );

      blocTest<SearchBloc, SearchState>(
        'does nothing when query is only whitespace',
        build: () => bloc,
        act: (bloc) => bloc.add(const SearchSubmitted('   ')),
        wait: const Duration(milliseconds: 600),
        expect: () => [],
      );

      blocTest<SearchBloc, SearchState>(
        'emits loading then loaded then error (StorageService singleton throws)',
        build: () {
          // All repo search methods will throw, so each _search* returns []
          when(() => mockTaskRepo.getTasks(
                keyword: any(named: 'keyword'),
                pageSize: any(named: 'pageSize'),
                page: any(named: 'page'),
                taskType: any(named: 'taskType'),
                status: any(named: 'status'),
                sortBy: any(named: 'sortBy'),
                location: any(named: 'location'),
                cancelToken: any(named: 'cancelToken'),
              )).thenThrow(Exception('mock'));
          when(() => mockForumRepo.searchPosts(
                keyword: any(named: 'keyword'),
                pageSize: any(named: 'pageSize'),
                page: any(named: 'page'),
              )).thenThrow(Exception('mock'));
          when(() => mockFleaMarketRepo.getItems(
                keyword: any(named: 'keyword'),
                pageSize: any(named: 'pageSize'),
                page: any(named: 'page'),
                category: any(named: 'category'),
                sortBy: any(named: 'sortBy'),
                cancelToken: any(named: 'cancelToken'),
              )).thenThrow(Exception('mock'));
          when(() => mockTaskExpertRepo.searchExperts(
                keyword: any(named: 'keyword'),
                pageSize: any(named: 'pageSize'),
                page: any(named: 'page'),
              )).thenThrow(Exception('mock'));
          when(() => mockActivityRepo.getActivities(
                keyword: any(named: 'keyword'),
                pageSize: any(named: 'pageSize'),
                page: any(named: 'page'),
                status: any(named: 'status'),
                cancelToken: any(named: 'cancelToken'),
                hasTimeSlots: any(named: 'hasTimeSlots'),
                expertId: any(named: 'expertId'),
              )).thenThrow(Exception('mock'));
          when(() => mockLeaderboardRepo.getLeaderboards(
                keyword: any(named: 'keyword'),
                pageSize: any(named: 'pageSize'),
                page: any(named: 'page'),
                location: any(named: 'location'),
                sort: any(named: 'sort'),
              )).thenThrow(Exception('mock'));
          when(() => mockForumRepo.getVisibleCategories())
              .thenThrow(Exception('mock'));
          return SearchBloc(
            taskRepository: mockTaskRepo,
            forumRepository: mockForumRepo,
            fleaMarketRepository: mockFleaMarketRepo,
            taskExpertRepository: mockTaskExpertRepo,
            activityRepository: mockActivityRepo,
            leaderboardRepository: mockLeaderboardRepo,
            personalServiceRepository: mockPersonalServiceRepo,
          );
        },
        act: (bloc) => bloc.add(const SearchSubmitted('flutter')),
        wait: const Duration(milliseconds: 600),
        expect: () => [
          // 1. loading state with query
          isA<SearchState>()
              .having((s) => s.status, 'status', SearchStatus.loading)
              .having((s) => s.query, 'query', 'flutter'),
          // 2. loaded state with all empty results (each _search* catches its own exception)
          isA<SearchState>()
              .having((s) => s.status, 'status', SearchStatus.loaded)
              .having((s) => s.taskResults, 'taskResults', isEmpty)
              .having((s) => s.forumResults, 'forumResults', isEmpty)
              .having(
                  (s) => s.fleaMarketResults, 'fleaMarketResults', isEmpty)
              .having((s) => s.expertResults, 'expertResults', isEmpty)
              .having(
                  (s) => s.activityResults, 'activityResults', isEmpty)
              .having((s) => s.leaderboardResults, 'leaderboardResults',
                  isEmpty)
              .having((s) => s.leaderboardItemResults,
                  'leaderboardItemResults', isEmpty)
              .having((s) => s.forumCategoryResults,
                  'forumCategoryResults', isEmpty)
              .having((s) => s.searchPage, 'searchPage', 1)
              .having((s) => s.searchHasMore, 'searchHasMore', false),
          // 3. error state from StorageService.instance.addSearchHistory throw
          isA<SearchState>()
              .having((s) => s.status, 'status', SearchStatus.error)
              .having((s) => s.errorMessage, 'errorMessage',
                  'search_error_failed'),
        ],
      );

      blocTest<SearchBloc, SearchState>(
        'debounces rapid submissions and only processes the last one',
        build: () {
          // All repos throw so individual searches return []
          when(() => mockTaskRepo.getTasks(
                keyword: any(named: 'keyword'),
                pageSize: any(named: 'pageSize'),
                page: any(named: 'page'),
                taskType: any(named: 'taskType'),
                status: any(named: 'status'),
                sortBy: any(named: 'sortBy'),
                location: any(named: 'location'),
                cancelToken: any(named: 'cancelToken'),
              )).thenThrow(Exception('mock'));
          when(() => mockForumRepo.searchPosts(
                keyword: any(named: 'keyword'),
                pageSize: any(named: 'pageSize'),
                page: any(named: 'page'),
              )).thenThrow(Exception('mock'));
          when(() => mockFleaMarketRepo.getItems(
                keyword: any(named: 'keyword'),
                pageSize: any(named: 'pageSize'),
                page: any(named: 'page'),
                category: any(named: 'category'),
                sortBy: any(named: 'sortBy'),
                cancelToken: any(named: 'cancelToken'),
              )).thenThrow(Exception('mock'));
          when(() => mockTaskExpertRepo.searchExperts(
                keyword: any(named: 'keyword'),
                pageSize: any(named: 'pageSize'),
                page: any(named: 'page'),
              )).thenThrow(Exception('mock'));
          when(() => mockActivityRepo.getActivities(
                keyword: any(named: 'keyword'),
                pageSize: any(named: 'pageSize'),
                page: any(named: 'page'),
                status: any(named: 'status'),
                cancelToken: any(named: 'cancelToken'),
                hasTimeSlots: any(named: 'hasTimeSlots'),
                expertId: any(named: 'expertId'),
              )).thenThrow(Exception('mock'));
          when(() => mockLeaderboardRepo.getLeaderboards(
                keyword: any(named: 'keyword'),
                pageSize: any(named: 'pageSize'),
                page: any(named: 'page'),
                location: any(named: 'location'),
                sort: any(named: 'sort'),
              )).thenThrow(Exception('mock'));
          when(() => mockForumRepo.getVisibleCategories())
              .thenThrow(Exception('mock'));
          return SearchBloc(
            taskRepository: mockTaskRepo,
            forumRepository: mockForumRepo,
            fleaMarketRepository: mockFleaMarketRepo,
            taskExpertRepository: mockTaskExpertRepo,
            activityRepository: mockActivityRepo,
            leaderboardRepository: mockLeaderboardRepo,
            personalServiceRepository: mockPersonalServiceRepo,
          );
        },
        act: (bloc) {
          // Fire three events rapidly; debounce + switchMap should only
          // process the last one ('react')
          bloc.add(const SearchSubmitted('flu'));
          bloc.add(const SearchSubmitted('flutt'));
          bloc.add(const SearchSubmitted('react'));
        },
        wait: const Duration(milliseconds: 600),
        expect: () => [
          // Only 'react' search is processed
          isA<SearchState>()
              .having((s) => s.status, 'status', SearchStatus.loading)
              .having((s) => s.query, 'query', 'react'),
          isA<SearchState>()
              .having((s) => s.status, 'status', SearchStatus.loaded),
          isA<SearchState>()
              .having((s) => s.status, 'status', SearchStatus.error)
              .having((s) => s.errorMessage, 'errorMessage',
                  'search_error_failed'),
        ],
      );
    });

    // ==================== SearchState.copyWith ====================

    group('SearchState.copyWith', () {
      test('copies all fields correctly', () {
        const original = SearchState(
          status: SearchStatus.loaded,
          query: 'test',
          taskResults: [
            {'id': 1}
          ],
          searchPage: 2,
          searchHasMore: false,
          errorMessage: 'some_error',
        );

        final copied = original.copyWith(
          status: SearchStatus.error,
          query: 'new_query',
          searchPage: 3,
        );

        expect(copied.status, equals(SearchStatus.error));
        expect(copied.query, equals('new_query'));
        expect(copied.searchPage, equals(3));
        // Unchanged fields preserved
        expect(copied.taskResults, equals(original.taskResults));
        expect(copied.searchHasMore, equals(false));
      });

      test('errorMessage is replaced (not preserved) when omitted', () {
        const original = SearchState(
          errorMessage: 'some_error',
        );
        // copyWith without errorMessage sets it to null
        final copied = original.copyWith(status: SearchStatus.loading);
        expect(copied.errorMessage, isNull);
      });

      test('errorMessage can be explicitly set', () {
        const original = SearchState();
        final copied =
            original.copyWith(errorMessage: 'search_error_failed');
        expect(copied.errorMessage, equals('search_error_failed'));
      });
    });

    // ==================== SearchEvent equality ====================

    group('SearchEvent equality', () {
      test('SearchSubmitted events with same query are equal', () {
        const a = SearchSubmitted('flutter');
        const b = SearchSubmitted('flutter');
        expect(a, equals(b));
      });

      test('SearchSubmitted events with different queries are not equal', () {
        const a = SearchSubmitted('flutter');
        const b = SearchSubmitted('dart');
        expect(a, isNot(equals(b)));
      });

      test('SearchCleared events are equal', () {
        const a = SearchCleared();
        const b = SearchCleared();
        expect(a, equals(b));
      });

      test('SearchLoadMore events are equal', () {
        const a = SearchLoadMore();
        const b = SearchLoadMore();
        expect(a, equals(b));
      });

      test('LoadRecentSearches events are equal', () {
        const a = LoadRecentSearches();
        const b = LoadRecentSearches();
        expect(a, equals(b));
      });

      test('SearchHistoryCleared events are equal', () {
        const a = SearchHistoryCleared();
        const b = SearchHistoryCleared();
        expect(a, equals(b));
      });
    });

    // ==================== SearchState equality ====================

    group('SearchState equality', () {
      test('states with same values are equal', () {
        const a = SearchState(
          status: SearchStatus.loaded,
          query: 'test',
        );
        const b = SearchState(
          status: SearchStatus.loaded,
          query: 'test',
        );
        expect(a, equals(b));
      });

      test('states with different status are not equal', () {
        const a = SearchState(status: SearchStatus.loading);
        const b = SearchState(status: SearchStatus.loaded);
        expect(a, isNot(equals(b)));
      });

      test('states with different query are not equal', () {
        const a = SearchState(query: 'a');
        const b = SearchState(query: 'b');
        expect(a, isNot(equals(b)));
      });
    });
  });
}
