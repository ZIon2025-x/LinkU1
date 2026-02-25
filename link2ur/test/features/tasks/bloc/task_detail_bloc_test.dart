import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/tasks/bloc/task_detail_bloc.dart';
import 'package:link2ur/data/models/task.dart';
import 'package:link2ur/data/models/review.dart';

import '../../../helpers/test_helpers.dart';

class FakeCreateReviewRequest extends Fake implements CreateReviewRequest {}

void main() {
  late MockTaskRepository mockTaskRepository;
  late TaskDetailBloc taskDetailBloc;

  final testTask = Task(
    id: 42,
    title: 'Test Task',
    taskType: 'errand',
    reward: 25.0,
    status: 'open',
    posterId: 'poster1',
  );

  final inProgressTask = Task(
    id: 42,
    title: 'Test Task',
    taskType: 'errand',
    reward: 25.0,
    status: 'in_progress',
    posterId: 'poster1',
    takerId: 'taker1',
  );

  final completedTask = Task(
    id: 42,
    title: 'Test Task',
    taskType: 'errand',
    reward: 25.0,
    status: 'completed',
    posterId: 'poster1',
    takerId: 'taker1',
  );

  setUp(() {
    mockTaskRepository = MockTaskRepository();
    taskDetailBloc = TaskDetailBloc(taskRepository: mockTaskRepository);
    registerFallbackValues();
    registerFallbackValue(FakeCreateReviewRequest());
  });

  tearDown(() {
    taskDetailBloc.close();
  });

  group('TaskDetailBloc', () {
    test('initial state is correct', () {
      expect(taskDetailBloc.state.status, TaskDetailStatus.initial);
      expect(taskDetailBloc.state.task, isNull);
      expect(taskDetailBloc.state.isSubmitting, isFalse);
      expect(taskDetailBloc.state.applications, isEmpty);
      expect(taskDetailBloc.state.reviews, isEmpty);
    });

    // ==================== 加载任务详情 ====================

    group('TaskDetailLoadRequested', () {
      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits [loading, loaded] when load succeeds',
        build: () {
          when(() => mockTaskRepository.getTaskDetail(42))
              .thenAnswer((_) async => testTask);
          return taskDetailBloc;
        },
        act: (bloc) => bloc.add(const TaskDetailLoadRequested(42)),
        expect: () => [
          const TaskDetailState(status: TaskDetailStatus.loading),
          TaskDetailState(
            status: TaskDetailStatus.loaded,
            task: testTask,
          ),
        ],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits [loading, error] when load fails',
        build: () {
          when(() => mockTaskRepository.getTaskDetail(42))
              .thenThrow(Exception('Not found'));
          return taskDetailBloc;
        },
        act: (bloc) => bloc.add(const TaskDetailLoadRequested(42)),
        expect: () => [
          const TaskDetailState(status: TaskDetailStatus.loading),
          isA<TaskDetailState>()
              .having((s) => s.status, 'status', TaskDetailStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    // ==================== 申请任务 ====================

    group('TaskDetailApplyRequested', () {
      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits [submitting, success] when apply succeeds',
        build: () {
          when(() => mockTaskRepository.applyTask(
                42,
                message: any(named: 'message'),
                negotiatedPrice: any(named: 'negotiatedPrice'),
                currency: any(named: 'currency'),
              )).thenAnswer((_) async {});
          when(() => mockTaskRepository.getTaskDetail(42))
              .thenAnswer((_) async => testTask);
          return taskDetailBloc;
        },
        seed: () => TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailApplyRequested(
          message: 'I can help!',
        )),
        expect: () => [
          isA<TaskDetailState>().having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage', 'application_submitted'),
        ],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits error when apply fails',
        build: () {
          when(() => mockTaskRepository.applyTask(
                42,
                message: any(named: 'message'),
                negotiatedPrice: any(named: 'negotiatedPrice'),
                currency: any(named: 'currency'),
              )).thenThrow(Exception('Already applied'));
          return taskDetailBloc;
        },
        seed: () => TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailApplyRequested(
          message: 'I can help!',
        )),
        expect: () => [
          isA<TaskDetailState>().having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage', 'application_failed'),
        ],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'does nothing when already submitting',
        build: () => taskDetailBloc,
        seed: () => TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
          isSubmitting: true,
        ),
        act: (bloc) => bloc.add(const TaskDetailApplyRequested()),
        expect: () => [],
      );
    });

    // ==================== 批准申请（需支付） ====================

    group('TaskDetailAcceptApplicant', () {
      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits open_payment when accept returns payment data',
        build: () {
          when(() => mockTaskRepository.acceptApplication(42, 100))
              .thenAnswer((_) async => {
                    'client_secret': 'pi_secret_123',
                    'customer_id': 'cus_123',
                    'ephemeral_key_secret': 'ek_123',
                    'amount_display': '£25.00',
                  });
          return taskDetailBloc;
        },
        seed: () => TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailAcceptApplicant(100)),
        expect: () => [
          isA<TaskDetailState>().having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage', 'open_payment')
              .having((s) => s.acceptPaymentData, 'acceptPaymentData', isNotNull)
              .having((s) => s.acceptPaymentData?.clientSecret, 'clientSecret', 'pi_secret_123'),
        ],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits application_accepted when accept requires no payment',
        build: () {
          when(() => mockTaskRepository.acceptApplication(42, 100))
              .thenAnswer((_) async => null);
          when(() => mockTaskRepository.getTaskDetail(42))
              .thenAnswer((_) async => inProgressTask);
          return taskDetailBloc;
        },
        seed: () => TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailAcceptApplicant(100)),
        expect: () => [
          isA<TaskDetailState>().having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage', 'application_accepted')
              .having((s) => s.task?.status, 'task.status', 'in_progress'),
        ],
      );
    });

    // ==================== 完成任务 ====================

    group('TaskDetailCompleteRequested', () {
      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits task_completed on success',
        build: () {
          when(() => mockTaskRepository.completeTask(
                42,
                evidenceImages: any(named: 'evidenceImages'),
                evidenceText: any(named: 'evidenceText'),
              )).thenAnswer((_) async {});
          when(() => mockTaskRepository.getTaskDetail(42))
              .thenAnswer((_) async => completedTask);
          return taskDetailBloc;
        },
        seed: () => TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: inProgressTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailCompleteRequested(
          evidenceText: 'Done!',
        )),
        expect: () => [
          isA<TaskDetailState>().having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage', 'task_completed')
              .having((s) => s.task?.status, 'task.status', 'completed'),
        ],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits submit_failed on error',
        build: () {
          when(() => mockTaskRepository.completeTask(
                42,
                evidenceImages: any(named: 'evidenceImages'),
                evidenceText: any(named: 'evidenceText'),
              )).thenThrow(Exception('Server error'));
          return taskDetailBloc;
        },
        seed: () => TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: inProgressTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailCompleteRequested()),
        expect: () => [
          isA<TaskDetailState>().having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage', 'submit_failed'),
        ],
      );
    });

    // ==================== 确认完成 ====================

    group('TaskDetailConfirmCompletionRequested', () {
      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits completion_confirmed on success',
        build: () {
          when(() => mockTaskRepository.confirmCompletion(
                42,
                partialTransferAmount: any(named: 'partialTransferAmount'),
                partialTransferReason: any(named: 'partialTransferReason'),
              )).thenAnswer((_) async {});
          when(() => mockTaskRepository.getTaskDetail(42))
              .thenAnswer((_) async => completedTask);
          return taskDetailBloc;
        },
        seed: () => TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: completedTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailConfirmCompletionRequested()),
        expect: () => [
          isA<TaskDetailState>().having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage', 'completion_confirmed'),
        ],
      );
    });

    // ==================== 取消任务 ====================

    group('TaskDetailCancelRequested', () {
      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits task_cancelled on success',
        build: () {
          final cancelledTask = Task(
            id: 42,
            title: 'Test Task',
            taskType: 'errand',
            reward: 25.0,
            status: 'cancelled',
            posterId: 'poster1',
          );
          when(() => mockTaskRepository.cancelTask(
                42,
                reason: any(named: 'reason'),
              )).thenAnswer((_) async {});
          when(() => mockTaskRepository.getTaskDetail(42))
              .thenAnswer((_) async => cancelledTask);
          return taskDetailBloc;
        },
        seed: () => TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailCancelRequested(
          reason: 'Changed my mind',
        )),
        expect: () => [
          isA<TaskDetailState>().having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage', 'task_cancelled')
              .having((s) => s.task?.status, 'task.status', 'cancelled'),
        ],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits cancel_failed on error',
        build: () {
          when(() => mockTaskRepository.cancelTask(
                42,
                reason: any(named: 'reason'),
              )).thenThrow(Exception('Cannot cancel'));
          return taskDetailBloc;
        },
        seed: () => TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailCancelRequested()),
        expect: () => [
          isA<TaskDetailState>().having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage', 'cancel_failed'),
        ],
      );
    });

    // ==================== 清除支付数据 ====================

    group('TaskDetailClearAcceptPaymentData', () {
      blocTest<TaskDetailBloc, TaskDetailState>(
        'clears acceptPaymentData',
        build: () => taskDetailBloc,
        seed: () => TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
          acceptPaymentData: const AcceptPaymentData(
            taskId: 42,
            clientSecret: 'secret',
            customerId: 'cus',
            ephemeralKeySecret: 'ek',
          ),
        ),
        act: (bloc) => bloc.add(const TaskDetailClearAcceptPaymentData()),
        expect: () => [
          isA<TaskDetailState>()
              .having((s) => s.acceptPaymentData, 'acceptPaymentData', isNull),
        ],
      );
    });

    // ==================== State helpers ====================

    group('TaskDetailState helpers', () {
      test('isLoading returns true for loading status', () {
        const state = TaskDetailState(status: TaskDetailStatus.loading);
        expect(state.isLoading, isTrue);
      });

      test('isLoaded returns true for loaded status', () {
        const state = TaskDetailState(status: TaskDetailStatus.loaded);
        expect(state.isLoaded, isTrue);
      });

      test('copyWith preserves values when no overrides', () {
        final state = TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
          isSubmitting: true,
        );
        final copied = state.copyWith();
        expect(copied.status, TaskDetailStatus.loaded);
        expect(copied.task, testTask);
        expect(copied.isSubmitting, isTrue);
      });

      test('copyWith clears errorMessage when not provided', () {
        const state = TaskDetailState(
          status: TaskDetailStatus.error,
          errorMessage: 'old error',
        );
        final copied = state.copyWith(status: TaskDetailStatus.loaded);
        expect(copied.errorMessage, isNull);
      });
    });
  });
}
