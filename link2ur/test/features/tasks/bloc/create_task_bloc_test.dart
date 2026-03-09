import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/tasks/bloc/create_task_bloc.dart';
import 'package:link2ur/data/models/task.dart';
import 'package:link2ur/data/repositories/task_repository.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  late MockTaskRepository mockTaskRepo;
  late CreateTaskBloc bloc;

  const testTask = Task(
    id: 1,
    title: 'Test Task',
    taskType: 'delivery',
    reward: 10.0,
    status: 'open',
    posterId: 'user1',
  );

  const testRequest = CreateTaskRequest(
    title: 'Test Task',
    taskType: 'delivery',
    reward: 10.0,
  );

  setUpAll(() {
    registerFallbackValue(testRequest);
  });

  setUp(() {
    mockTaskRepo = MockTaskRepository();
    bloc = CreateTaskBloc(taskRepository: mockTaskRepo);
  });

  tearDown(() {
    bloc.close();
  });

  group('CreateTaskBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, equals(CreateTaskStatus.initial));
      expect(bloc.state.createdTask, isNull);
      expect(bloc.state.errorMessage, isNull);
    });

    group('CreateTaskSubmitted', () {
      blocTest<CreateTaskBloc, CreateTaskState>(
        'emits [submitting, success] when submission succeeds',
        build: () {
          when(() => mockTaskRepo.createTask(any()))
              .thenAnswer((_) async => testTask);
          return bloc;
        },
        act: (bloc) => bloc.add(const CreateTaskSubmitted(testRequest)),
        expect: () => [
          const CreateTaskState(status: CreateTaskStatus.submitting),
          const CreateTaskState(
            status: CreateTaskStatus.success,
            createdTask: testTask,
          ),
        ],
      );

      blocTest<CreateTaskBloc, CreateTaskState>(
        'emits [submitting, error] when submission fails',
        build: () {
          when(() => mockTaskRepo.createTask(any()))
              .thenThrow(Exception('Network error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const CreateTaskSubmitted(testRequest)),
        expect: () => [
          const CreateTaskState(status: CreateTaskStatus.submitting),
          isA<CreateTaskState>()
              .having((s) => s.status, 'status', CreateTaskStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );

      blocTest<CreateTaskBloc, CreateTaskState>(
        'uses droppable - ignores duplicate submissions while submitting',
        build: () {
          when(() => mockTaskRepo.createTask(any())).thenAnswer(
            (_) async {
              await Future.delayed(const Duration(milliseconds: 100));
              return testTask;
            },
          );
          return bloc;
        },
        act: (bloc) {
          bloc.add(const CreateTaskSubmitted(testRequest));
          bloc.add(const CreateTaskSubmitted(testRequest));
        },
        wait: const Duration(milliseconds: 200),
        expect: () => [
          const CreateTaskState(status: CreateTaskStatus.submitting),
          const CreateTaskState(
            status: CreateTaskStatus.success,
            createdTask: testTask,
          ),
        ],
        verify: (_) {
          verify(() => mockTaskRepo.createTask(any())).called(1);
        },
      );
    });

    group('CreateTaskReset', () {
      blocTest<CreateTaskBloc, CreateTaskState>(
        'resets state to initial',
        build: () => bloc,
        seed: () => const CreateTaskState(
          status: CreateTaskStatus.success,
          createdTask: testTask,
        ),
        act: (bloc) => bloc.add(const CreateTaskReset()),
        expect: () => [
          const CreateTaskState(),
        ],
      );

      blocTest<CreateTaskBloc, CreateTaskState>(
        'resets error state to initial',
        build: () => bloc,
        seed: () => const CreateTaskState(
          status: CreateTaskStatus.error,
          errorMessage: 'some error',
        ),
        act: (bloc) => bloc.add(const CreateTaskReset()),
        expect: () => [
          const CreateTaskState(),
        ],
      );
    });
  });
}
