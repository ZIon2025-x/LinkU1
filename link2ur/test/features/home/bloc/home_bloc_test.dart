import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/home/bloc/home_bloc.dart';
import 'package:link2ur/features/home/bloc/home_event.dart';
import 'package:link2ur/features/home/bloc/home_state.dart';
import 'package:link2ur/data/models/task.dart';
import 'package:link2ur/data/models/activity.dart';
import 'package:link2ur/data/models/user.dart';
import 'package:link2ur/data/repositories/task_repository.dart';
import 'package:link2ur/data/repositories/activity_repository.dart';
import 'package:link2ur/data/repositories/common_repository.dart';
import 'package:link2ur/data/repositories/discovery_repository.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

class MockActivityRepository extends Mock implements ActivityRepository {}

class MockCommonRepository extends Mock implements CommonRepository {}

class MockDiscoveryRepository extends Mock implements DiscoveryRepository {}

void main() {
  late MockTaskRepository mockTaskRepo;
  late MockActivityRepository mockActivityRepo;
  late MockCommonRepository mockCommonRepo;
  late MockDiscoveryRepository mockDiscoveryRepo;
  late HomeBloc bloc;

  const testTask = Task(
    id: 1,
    title: 'Test Task',
    taskType: 'delivery',
    reward: 10.0,
    status: 'open',
    posterId: 'user1',
  );

  const testTask2 = Task(
    id: 2,
    title: 'Another Task',
    taskType: 'tutoring',
    reward: 20.0,
    status: 'open',
    posterId: 'user2',
  );

  const testTaskListResponse = TaskListResponse(
    tasks: [testTask, testTask2],
    total: 2,
    page: 1,
    pageSize: 20,
  );

  const testActivity = Activity(
    id: 1,
    title: 'Test Activity',
    expertId: 'expert1',
    expertServiceId: 1,
    status: 'open',
  );

  const testActivityListResponse = ActivityListResponse(
    activities: [testActivity],
    total: 1,
    page: 1,
    pageSize: 20,
  );

  setUp(() {
    mockTaskRepo = MockTaskRepository();
    mockActivityRepo = MockActivityRepository();
    mockCommonRepo = MockCommonRepository();
    mockDiscoveryRepo = MockDiscoveryRepository();
    bloc = HomeBloc(
      taskRepository: mockTaskRepo,
      activityRepository: mockActivityRepo,
      commonRepository: mockCommonRepo,
      discoveryRepository: mockDiscoveryRepo,
    );
  });

  tearDown(() {
    bloc.close();
  });

  group('HomeBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, equals(HomeStatus.initial));
      expect(bloc.state.recommendedTasks, isEmpty);
      expect(bloc.state.openActivities, isEmpty);
      expect(bloc.state.banners, isEmpty);
      expect(bloc.state.currentTab, equals(0));
    });

    group('HomeLoadRequested', () {
      blocTest<HomeBloc, HomeState>(
        'emits [loading, loaded] with recommended tasks on success',
        build: () {
          when(() => mockTaskRepo.getRecommendedTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testTaskListResponse);
          when(() => mockActivityRepo.getActivities(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                status: any(named: 'status'),
                keyword: any(named: 'keyword'),
                hasTimeSlots: any(named: 'hasTimeSlots'),
                expertId: any(named: 'expertId'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testActivityListResponse);
          when(() => mockCommonRepo.getBanners())
              .thenAnswer((_) async => []);
          bloc.currentUser = const User(id: 'u1', name: 'Test');
          return bloc;
        },
        act: (bloc) => bloc.add(const HomeLoadRequested()),
        expect: () => [
          isA<HomeState>()
              .having(
                  (s) => s.status, 'status', HomeStatus.loading)
              .having(
                  (s) => s.isLoadingOpenActivities,
                  'isLoadingOpenActivities',
                  isTrue),
          isA<HomeState>()
              .having(
                  (s) => s.status, 'status', HomeStatus.loaded)
              .having((s) => s.recommendedTasks.length,
                  'recommendedTasks.length', 2)
              .having(
                  (s) => s.isLoadingOpenActivities,
                  'isLoadingOpenActivities',
                  isFalse),
        ],
      );

      blocTest<HomeBloc, HomeState>(
        'falls back to public tasks when recommended fails',
        build: () {
          when(() => mockTaskRepo.getRecommendedTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                cancelToken: any(named: 'cancelToken'),
              )).thenThrow(Exception('Not authenticated'));
          when(() => mockTaskRepo.getTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                taskType: any(named: 'taskType'),
                sortBy: any(named: 'sortBy'),
                location: any(named: 'location'),
                status: any(named: 'status'),
                keyword: any(named: 'keyword'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testTaskListResponse);
          when(() => mockActivityRepo.getActivities(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                status: any(named: 'status'),
                keyword: any(named: 'keyword'),
                hasTimeSlots: any(named: 'hasTimeSlots'),
                expertId: any(named: 'expertId'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testActivityListResponse);
          when(() => mockCommonRepo.getBanners())
              .thenAnswer((_) async => []);
          bloc.currentUser = const User(id: 'u1', name: 'Test');
          return bloc;
        },
        act: (bloc) => bloc.add(const HomeLoadRequested()),
        expect: () => [
          isA<HomeState>()
              .having(
                  (s) => s.status, 'status', HomeStatus.loading)
              .having(
                  (s) => s.isLoadingOpenActivities,
                  'isLoadingOpenActivities',
                  isTrue),
          isA<HomeState>()
              .having(
                  (s) => s.status, 'status', HomeStatus.loaded)
              .having((s) => s.recommendedTasks.length,
                  'recommendedTasks.length', 2)
              .having(
                  (s) => s.isLoadingOpenActivities,
                  'isLoadingOpenActivities',
                  isFalse),
        ],
      );

      blocTest<HomeBloc, HomeState>(
        'emits error when both recommended and public tasks fail',
        build: () {
          when(() => mockTaskRepo.getRecommendedTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                cancelToken: any(named: 'cancelToken'),
              )).thenThrow(Exception('Not authenticated'));
          when(() => mockTaskRepo.getTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                taskType: any(named: 'taskType'),
                sortBy: any(named: 'sortBy'),
                location: any(named: 'location'),
                status: any(named: 'status'),
                keyword: any(named: 'keyword'),
                cancelToken: any(named: 'cancelToken'),
              )).thenThrow(Exception('Network error'));
          bloc.currentUser = const User(id: 'u1', name: 'Test');
          return bloc;
        },
        act: (bloc) => bloc.add(const HomeLoadRequested()),
        expect: () => [
          // 1) loading + isLoadingOpenActivities = true
          isA<HomeState>()
              .having(
                  (s) => s.status, 'status', HomeStatus.loading)
              .having(
                  (s) => s.isLoadingOpenActivities,
                  'isLoadingOpenActivities',
                  isTrue),
          // 2) isLoadingOpenActivities reset to false (status still loading)
          isA<HomeState>()
              .having(
                  (s) => s.status, 'status', HomeStatus.loading)
              .having(
                  (s) => s.isLoadingOpenActivities,
                  'isLoadingOpenActivities',
                  isFalse),
          // 3) error state
          isA<HomeState>()
              .having(
                  (s) => s.status, 'status', HomeStatus.error),
        ],
      );
    });

    group('HomeTabChanged', () {
      blocTest<HomeBloc, HomeState>(
        'updates current tab',
        build: () => bloc,
        act: (bloc) => bloc.add(const HomeTabChanged(2)),
        expect: () => [
          isA<HomeState>()
              .having((s) => s.currentTab, 'currentTab', 2),
        ],
      );
    });

    group('HomeLoadRecommended', () {
      blocTest<HomeBloc, HomeState>(
        'loads more recommended tasks',
        build: () {
          when(() => mockTaskRepo.getRecommendedTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testTaskListResponse);
          when(() => mockTaskRepo.getTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                taskType: any(named: 'taskType'),
                sortBy: any(named: 'sortBy'),
                location: any(named: 'location'),
                status: any(named: 'status'),
                keyword: any(named: 'keyword'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testTaskListResponse);
          return bloc;
        },
        seed: () => const HomeState(
          status: HomeStatus.loaded,
          recommendedTasks: [testTask],
          hasMoreRecommended: true,
        ),
        act: (bloc) =>
            bloc.add(const HomeLoadRecommended(loadMore: true)),
        expect: () => [
          isA<HomeState>()
              .having((s) => s.recommendedTasks.length,
                  'recommendedTasks.length', greaterThan(1)),
        ],
      );

      blocTest<HomeBloc, HomeState>(
        'replaces tasks on initial load',
        build: () {
          when(() => mockTaskRepo.getRecommendedTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testTaskListResponse);
          when(() => mockTaskRepo.getTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                taskType: any(named: 'taskType'),
                sortBy: any(named: 'sortBy'),
                location: any(named: 'location'),
                status: any(named: 'status'),
                keyword: any(named: 'keyword'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testTaskListResponse);
          return bloc;
        },
        seed: () => const HomeState(
          status: HomeStatus.loaded,
          recommendedTasks: [testTask],
        ),
        act: (bloc) =>
            bloc.add(const HomeLoadRecommended()),
        expect: () => [
          isA<HomeState>()
              .having((s) => s.recommendedTasks.length,
                  'recommendedTasks.length', 2),
        ],
      );
    });

    group('HomeRefreshRequested', () {
      blocTest<HomeBloc, HomeState>(
        'refreshes all data',
        build: () {
          when(() => mockTaskRepo.getRecommendedTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testTaskListResponse);
          when(() => mockActivityRepo.getActivities(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                status: any(named: 'status'),
                keyword: any(named: 'keyword'),
                hasTimeSlots: any(named: 'hasTimeSlots'),
                expertId: any(named: 'expertId'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testActivityListResponse);
          when(() => mockCommonRepo.getBanners())
              .thenAnswer((_) async => []);
          bloc.currentUser = const User(id: 'u1', name: 'Test');
          return bloc;
        },
        seed: () => const HomeState(
          status: HomeStatus.loaded,
          recommendedTasks: [testTask],
        ),
        act: (bloc) => bloc.add(const HomeRefreshRequested()),
        expect: () => [
          isA<HomeState>()
              .having(
                  (s) => s.isRefreshing, 'isRefreshing', isTrue),
          isA<HomeState>()
              .having(
                  (s) => s.isRefreshing, 'isRefreshing', isFalse)
              .having((s) => s.recommendedTasks.length,
                  'recommendedTasks.length', 2),
        ],
      );
    });

    group('HomeRecommendedFilterChanged', () {
      blocTest<HomeBloc, HomeState>(
        'updates filter and triggers reload',
        build: () {
          when(() => mockTaskRepo.getRecommendedTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testTaskListResponse);
          when(() => mockTaskRepo.getTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                taskType: any(named: 'taskType'),
                sortBy: any(named: 'sortBy'),
                location: any(named: 'location'),
                status: any(named: 'status'),
                keyword: any(named: 'keyword'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testTaskListResponse);
          return bloc;
        },
        seed: () => const HomeState(status: HomeStatus.loaded),
        act: (bloc) => bloc.add(
            const HomeRecommendedFilterChanged(
                category: 'delivery')),
        expect: () => [
          // 1) Filter changed (status stays loaded, recommendedTasks still empty)
          isA<HomeState>()
              .having((s) => s.recommendedFilterCategory,
                  'recommendedFilterCategory', 'delivery'),
          // 2) HomeLoadRecommended: hasExistingData=false, so loading emitted
          isA<HomeState>()
              .having(
                  (s) => s.status, 'status', HomeStatus.loading)
              .having((s) => s.recommendedFilterCategory,
                  'recommendedFilterCategory', 'delivery'),
          // 3) Loaded with tasks
          isA<HomeState>()
              .having(
                  (s) => s.status, 'status', HomeStatus.loaded)
              .having((s) => s.recommendedTasks.length,
                  'recommendedTasks.length', 2),
        ],
      );
    });

    group('HomeState helpers', () {
      test('isLoading returns true for loading status', () {
        const state = HomeState(status: HomeStatus.loading);
        expect(state.isLoading, isTrue);
      });

      test('isLoading returns false for loaded status', () {
        const state = HomeState(status: HomeStatus.loaded);
        expect(state.isLoading, isFalse);
      });

      test('isLoaded returns true for loaded status', () {
        const state = HomeState(status: HomeStatus.loaded);
        expect(state.isLoaded, isTrue);
      });

      test('hasError returns true for error status', () {
        const state = HomeState(status: HomeStatus.error);
        expect(state.hasError, isTrue);
      });
    });
  });
}
