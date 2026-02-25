import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/tasks/bloc/task_list_bloc.dart';
import 'package:link2ur/features/tasks/bloc/task_list_event.dart';
import 'package:link2ur/features/tasks/bloc/task_list_state.dart';
import 'package:link2ur/data/models/task.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  late MockTaskRepository mockTaskRepository;
  late TaskListBloc taskListBloc;

  final testTask = Task(
    id: 1,
    title: 'Test Task',
    taskType: 'errand',
    reward: 10.0,
    status: 'open',
    posterId: 'user1',
  );

  final testResponse = TaskListResponse(
    tasks: [testTask],
    total: 1,
    page: 1,
    pageSize: 20,
  );

  setUp(() {
    mockTaskRepository = MockTaskRepository();
    taskListBloc = TaskListBloc(taskRepository: mockTaskRepository);
    registerFallbackValues();
  });

  tearDown(() {
    taskListBloc.close();
  });

  group('TaskListBloc', () {
    test('initial state is correct', () {
      expect(taskListBloc.state.status, TaskListStatus.initial);
      expect(taskListBloc.state.tasks, isEmpty);
      expect(taskListBloc.state.page, 1);
      expect(taskListBloc.state.hasMore, isTrue);
      expect(taskListBloc.state.selectedCategory, 'all');
      expect(taskListBloc.state.selectedCity, 'all');
      expect(taskListBloc.state.searchQuery, '');
      expect(taskListBloc.state.sortBy, 'latest');
    });

    // ==================== 加载任务列表 ====================

    group('TaskListLoadRequested', () {
      blocTest<TaskListBloc, TaskListState>(
        'emits [loading, loaded] when load succeeds',
        build: () {
          when(() => mockTaskRepository.getTasks(
                page: any(named: 'page'),
                taskType: any(named: 'taskType'),
                keyword: any(named: 'keyword'),
                sortBy: any(named: 'sortBy'),
                location: any(named: 'location'),
              )).thenAnswer((_) async => testResponse);
          return taskListBloc;
        },
        act: (bloc) => bloc.add(const TaskListLoadRequested()),
        expect: () => [
          const TaskListState(status: TaskListStatus.loading),
          TaskListState(
            status: TaskListStatus.loaded,
            tasks: [testTask],
            total: 1,
            page: 1,
            hasMore: false,
          ),
        ],
      );

      blocTest<TaskListBloc, TaskListState>(
        'emits [loading, error] when load fails',
        build: () {
          when(() => mockTaskRepository.getTasks(
                page: any(named: 'page'),
                taskType: any(named: 'taskType'),
                keyword: any(named: 'keyword'),
                sortBy: any(named: 'sortBy'),
                location: any(named: 'location'),
              )).thenThrow(Exception('Network error'));
          return taskListBloc;
        },
        act: (bloc) => bloc.add(const TaskListLoadRequested()),
        expect: () => [
          const TaskListState(status: TaskListStatus.loading),
          isA<TaskListState>()
              .having((s) => s.status, 'status', TaskListStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    // ==================== 加载更多 ====================

    group('TaskListLoadMore', () {
      blocTest<TaskListBloc, TaskListState>(
        'loads next page and appends tasks',
        build: () {
          final page2Task = Task(
            id: 2,
            title: 'Task Page 2',
            taskType: 'errand',
            reward: 20.0,
            status: 'open',
            posterId: 'user2',
          );
          when(() => mockTaskRepository.getTasks(
                page: 2,
                taskType: any(named: 'taskType'),
                keyword: any(named: 'keyword'),
                sortBy: any(named: 'sortBy'),
                location: any(named: 'location'),
              )).thenAnswer((_) async => TaskListResponse(
                tasks: [page2Task],
                total: 30,
                page: 2,
                pageSize: 20,
              ));
          return taskListBloc;
        },
        seed: () => TaskListState(
          status: TaskListStatus.loaded,
          tasks: [testTask],
          total: 30,
          page: 1,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const TaskListLoadMore()),
        expect: () => [
          isA<TaskListState>().having((s) => s.isLoadingMore, 'isLoadingMore', true),
          isA<TaskListState>()
              .having((s) => s.tasks.length, 'tasks.length', 2)
              .having((s) => s.page, 'page', 2)
              .having((s) => s.isLoadingMore, 'isLoadingMore', false),
        ],
      );

      blocTest<TaskListBloc, TaskListState>(
        'does nothing when hasMore is false',
        build: () => taskListBloc,
        seed: () => TaskListState(
          status: TaskListStatus.loaded,
          tasks: [testTask],
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const TaskListLoadMore()),
        expect: () => [],
      );

      blocTest<TaskListBloc, TaskListState>(
        'does nothing when already loading more',
        build: () => taskListBloc,
        seed: () => TaskListState(
          status: TaskListStatus.loaded,
          tasks: [testTask],
          hasMore: true,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const TaskListLoadMore()),
        expect: () => [],
      );

      blocTest<TaskListBloc, TaskListState>(
        'resets isLoadingMore on error without changing overall status',
        build: () {
          when(() => mockTaskRepository.getTasks(
                page: 2,
                taskType: any(named: 'taskType'),
                keyword: any(named: 'keyword'),
                sortBy: any(named: 'sortBy'),
                location: any(named: 'location'),
              )).thenThrow(Exception('Network error'));
          return taskListBloc;
        },
        seed: () => TaskListState(
          status: TaskListStatus.loaded,
          tasks: [testTask],
          total: 30,
          page: 1,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const TaskListLoadMore()),
        expect: () => [
          isA<TaskListState>().having((s) => s.isLoadingMore, 'isLoadingMore', true),
          isA<TaskListState>()
              .having((s) => s.status, 'status', TaskListStatus.loaded)
              .having((s) => s.isLoadingMore, 'isLoadingMore', false),
        ],
      );
    });

    // ==================== 分类切换 ====================

    group('TaskListCategoryChanged', () {
      blocTest<TaskListBloc, TaskListState>(
        'reloads tasks with new category',
        build: () {
          when(() => mockTaskRepository.getTasks(
                page: any(named: 'page'),
                taskType: 'errand',
                keyword: any(named: 'keyword'),
                sortBy: any(named: 'sortBy'),
                location: any(named: 'location'),
              )).thenAnswer((_) async => testResponse);
          return taskListBloc;
        },
        act: (bloc) => bloc.add(const TaskListCategoryChanged('errand')),
        expect: () => [
          isA<TaskListState>()
              .having((s) => s.selectedCategory, 'selectedCategory', 'errand')
              .having((s) => s.status, 'status', TaskListStatus.loading),
          isA<TaskListState>()
              .having((s) => s.status, 'status', TaskListStatus.loaded)
              .having((s) => s.selectedCategory, 'selectedCategory', 'errand'),
        ],
      );
    });

    // ==================== 排序切换 ====================

    group('TaskListSortChanged', () {
      blocTest<TaskListBloc, TaskListState>(
        'reloads tasks with new sort order',
        build: () {
          when(() => mockTaskRepository.getTasks(
                page: any(named: 'page'),
                taskType: any(named: 'taskType'),
                keyword: any(named: 'keyword'),
                sortBy: 'reward_high',
                location: any(named: 'location'),
              )).thenAnswer((_) async => testResponse);
          return taskListBloc;
        },
        act: (bloc) => bloc.add(const TaskListSortChanged('reward_high')),
        expect: () => [
          isA<TaskListState>()
              .having((s) => s.sortBy, 'sortBy', 'reward_high')
              .having((s) => s.status, 'status', TaskListStatus.loading),
          isA<TaskListState>()
              .having((s) => s.status, 'status', TaskListStatus.loaded),
        ],
      );
    });

    // ==================== 城市筛选 ====================

    group('TaskListCityChanged', () {
      blocTest<TaskListBloc, TaskListState>(
        'reloads tasks with city filter',
        build: () {
          when(() => mockTaskRepository.getTasks(
                page: any(named: 'page'),
                taskType: any(named: 'taskType'),
                keyword: any(named: 'keyword'),
                sortBy: any(named: 'sortBy'),
                location: 'London',
              )).thenAnswer((_) async => testResponse);
          return taskListBloc;
        },
        act: (bloc) => bloc.add(const TaskListCityChanged('London')),
        expect: () => [
          isA<TaskListState>()
              .having((s) => s.selectedCity, 'selectedCity', 'London')
              .having((s) => s.status, 'status', TaskListStatus.loading),
          isA<TaskListState>()
              .having((s) => s.status, 'status', TaskListStatus.loaded),
        ],
      );
    });

    // ==================== State helpers ====================

    group('TaskListState helpers', () {
      test('isEmpty returns true when loaded with no tasks', () {
        const state = TaskListState(
          status: TaskListStatus.loaded,
          tasks: [],
        );
        expect(state.isEmpty, isTrue);
      });

      test('isEmpty returns false when loaded with tasks', () {
        final state = TaskListState(
          status: TaskListStatus.loaded,
          tasks: [testTask],
        );
        expect(state.isEmpty, isFalse);
      });

      test('hasActiveFilters detects non-default sort', () {
        const state = TaskListState(sortBy: 'reward_high');
        expect(state.hasActiveFilters, isTrue);
      });

      test('hasActiveFilters detects city filter', () {
        const state = TaskListState(selectedCity: 'London');
        expect(state.hasActiveFilters, isTrue);
      });

      test('hasActiveFilters returns false for defaults', () {
        const state = TaskListState();
        expect(state.hasActiveFilters, isFalse);
      });
    });
  });
}
