import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/tasks/bloc/task_detail_bloc.dart';
import 'package:link2ur/data/models/task.dart';
import 'package:link2ur/data/models/review.dart';
import 'package:link2ur/data/repositories/task_repository.dart';

import '../../../helpers/test_helpers.dart';

class FakeCreateReviewRequest extends Fake implements CreateReviewRequest {}

void main() {
  late MockTaskRepository mockTaskRepository;
  late MockNotificationRepository mockNotificationRepository;
  late MockQuestionRepository mockQuestionRepository;
  late TaskDetailBloc taskDetailBloc;

  const testTask = Task(
    id: 42,
    title: 'Test Task',
    taskType: 'errand',
    reward: 25.0,
    status: 'open',
    posterId: 'poster1',
  );

  const inProgressTask = Task(
    id: 42,
    title: 'Test Task',
    taskType: 'errand',
    reward: 25.0,
    status: 'in_progress',
    posterId: 'poster1',
    takerId: 'taker1',
  );

  const completedTask = Task(
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
    mockNotificationRepository = MockNotificationRepository();
    mockQuestionRepository = MockQuestionRepository();
    taskDetailBloc = TaskDetailBloc(
      taskRepository: mockTaskRepository,
      notificationRepository: mockNotificationRepository,
      questionRepository: mockQuestionRepository,
    );
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

    // ==================== Load task detail ====================

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
          const TaskDetailState(
            status: TaskDetailStatus.loaded,
            task: testTask,
          ),
        ],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits [loading, error with task_detail_load_failed] when load fails',
        build: () {
          when(() => mockTaskRepository.getTaskDetail(42))
              .thenThrow(Exception('Not found'));
          return taskDetailBloc;
        },
        act: (bloc) => bloc.add(const TaskDetailLoadRequested(42)),
        expect: () => [
          const TaskDetailState(status: TaskDetailStatus.loading),
          const TaskDetailState(
            status: TaskDetailStatus.error,
            errorMessage: 'task_detail_load_failed',
          ),
        ],
      );
    });

    // ==================== Apply task ====================

    group('TaskDetailApplyRequested', () {
      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits [isSubmitting=true, isSubmitting=false + actionMessage=application_submitted] on success',
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
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailApplyRequested(
          message: 'I can help!',
        )),
        expect: () => [
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage',
                  'application_submitted'),
        ],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits actionMessage=stripe_setup_required on TaskException(stripe_setup_required)',
        build: () {
          when(() => mockTaskRepository.applyTask(
                42,
                message: any(named: 'message'),
                negotiatedPrice: any(named: 'negotiatedPrice'),
                currency: any(named: 'currency'),
              )).thenThrow(const TaskException('stripe_setup_required'));
          return taskDetailBloc;
        },
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailApplyRequested()),
        expect: () => [
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage',
                  'stripe_setup_required')
              .having((s) => s.errorMessage, 'errorMessage', isNull),
        ],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits actionMessage=application_failed on generic error',
        build: () {
          when(() => mockTaskRepository.applyTask(
                42,
                message: any(named: 'message'),
                negotiatedPrice: any(named: 'negotiatedPrice'),
                currency: any(named: 'currency'),
              )).thenThrow(Exception('Already applied'));
          return taskDetailBloc;
        },
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailApplyRequested(
          message: 'I can help!',
        )),
        expect: () => [
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage',
                  'application_failed')
              .having((s) => s.errorMessage, 'errorMessage',
                  'task_apply_failed'),
        ],
      );
    });

    // ==================== Accept applicant ====================

    group('TaskDetailAcceptApplicant', () {
      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits open_payment when accept returns payment data',
        build: () {
          when(() => mockTaskRepository.acceptApplication(42, 100))
              .thenAnswer((_) async => {
                    'client_secret': 'pi_secret_123',
                    'customer_id': 'cus_123',
                    'ephemeral_key_secret': 'ek_123',
                    'amount_display': '\u00a325.00',
                  });
          return taskDetailBloc;
        },
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailAcceptApplicant(100)),
        expect: () => [
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having(
                  (s) => s.actionMessage, 'actionMessage', 'open_payment')
              .having((s) => s.acceptPaymentData, 'acceptPaymentData',
                  isNotNull)
              .having((s) => s.acceptPaymentData?.clientSecret,
                  'clientSecret', 'pi_secret_123'),
        ],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits application_accepted when accept requires no payment',
        build: () {
          when(() => mockTaskRepository.acceptApplication(42, 100))
              .thenAnswer((_) async => null);
          when(() => mockTaskRepository.getTaskDetail(42))
              .thenAnswer((_) async => inProgressTask);
          when(() => mockTaskRepository.getTaskApplications(42))
              .thenAnswer((_) async => <Map<String, dynamic>>[]);
          return taskDetailBloc;
        },
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailAcceptApplicant(100)),
        expect: () => [
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage',
                  'application_accepted')
              .having(
                  (s) => s.task?.status, 'task.status', 'in_progress'),
        ],
      );
    });

    // ==================== Complete task ====================

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
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: inProgressTask,
        ),
        act: (bloc) =>
            bloc.add(const TaskDetailCompleteRequested(evidenceText: 'Done!')),
        expect: () => [
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having(
                  (s) => s.actionMessage, 'actionMessage', 'task_completed')
              .having(
                  (s) => s.task?.status, 'task.status', 'completed'),
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
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: inProgressTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailCompleteRequested()),
        expect: () => [
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having(
                  (s) => s.actionMessage, 'actionMessage', 'submit_failed'),
        ],
      );
    });

    // ==================== Confirm completion ====================

    group('TaskDetailConfirmCompletionRequested', () {
      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits completion_confirmed on success',
        build: () {
          when(() => mockTaskRepository.confirmCompletion(
                42,
                partialTransferAmount:
                    any(named: 'partialTransferAmount'),
                partialTransferReason:
                    any(named: 'partialTransferReason'),
              )).thenAnswer((_) async {});
          when(() => mockTaskRepository.getTaskDetail(42))
              .thenAnswer((_) async => completedTask);
          return taskDetailBloc;
        },
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: completedTask,
        ),
        act: (bloc) =>
            bloc.add(const TaskDetailConfirmCompletionRequested()),
        expect: () => [
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage',
                  'completion_confirmed'),
        ],
      );
    });

    // ==================== Cancel task ====================

    group('TaskDetailCancelRequested', () {
      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits task_cancelled when directly cancelled',
        build: () {
          const cancelledTask = Task(
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
              )).thenAnswer((_) async => true);
          when(() => mockTaskRepository.getTaskDetail(42))
              .thenAnswer((_) async => cancelledTask);
          return taskDetailBloc;
        },
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
        ),
        act: (bloc) => bloc.add(
            const TaskDetailCancelRequested(reason: 'Changed my mind')),
        expect: () => [
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage',
                  'task_cancelled')
              .having(
                  (s) => s.task?.status, 'task.status', 'cancelled'),
        ],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'emits cancel_request_submitted when review is required',
        build: () {
          when(() => mockTaskRepository.cancelTask(
                42,
                reason: any(named: 'reason'),
              )).thenAnswer((_) async => false);
          when(() => mockTaskRepository.getTaskDetail(42))
              .thenAnswer((_) async => testTask);
          return taskDetailBloc;
        },
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
        ),
        act: (bloc) => bloc.add(
            const TaskDetailCancelRequested(reason: 'Changed my mind')),
        expect: () => [
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage',
                  'cancel_request_submitted'),
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
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
        ),
        act: (bloc) => bloc.add(const TaskDetailCancelRequested()),
        expect: () => [
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', true),
          isA<TaskDetailState>()
              .having((s) => s.isSubmitting, 'isSubmitting', false)
              .having((s) => s.actionMessage, 'actionMessage',
                  'cancel_failed')
              .having((s) => s.errorMessage, 'errorMessage',
                  'task_cancel_failed'),
        ],
      );
    });

    // ==================== Clear payment data ====================

    group('TaskDetailClearAcceptPaymentData', () {
      blocTest<TaskDetailBloc, TaskDetailState>(
        'clears acceptPaymentData',
        build: () => taskDetailBloc,
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
          acceptPaymentData: AcceptPaymentData(
            taskId: 42,
            clientSecret: 'secret',
            customerId: 'cus',
            ephemeralKeySecret: 'ek',
          ),
        ),
        act: (bloc) =>
            bloc.add(const TaskDetailClearAcceptPaymentData()),
        expect: () => [
          isA<TaskDetailState>().having(
              (s) => s.acceptPaymentData, 'acceptPaymentData', isNull),
        ],
      );
    });

    // ==================== Guard: null task ====================

    group('Guard: null task (_taskId == null)', () {
      blocTest<TaskDetailBloc, TaskDetailState>(
        'apply does nothing when task is null',
        build: () => taskDetailBloc,
        act: (bloc) => bloc.add(const TaskDetailApplyRequested()),
        expect: () => <TaskDetailState>[],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'cancel does nothing when task is null',
        build: () => taskDetailBloc,
        act: (bloc) => bloc.add(const TaskDetailCancelRequested()),
        expect: () => <TaskDetailState>[],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'complete does nothing when task is null',
        build: () => taskDetailBloc,
        act: (bloc) => bloc.add(const TaskDetailCompleteRequested()),
        expect: () => <TaskDetailState>[],
      );
    });

    // ==================== Guard: isSubmitting ====================

    group('Guard: isSubmitting deduplication', () {
      blocTest<TaskDetailBloc, TaskDetailState>(
        'apply is ignored when already submitting',
        build: () => taskDetailBloc,
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
          isSubmitting: true,
        ),
        act: (bloc) => bloc.add(const TaskDetailApplyRequested()),
        expect: () => <TaskDetailState>[],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'cancel is ignored when already submitting',
        build: () => taskDetailBloc,
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
          isSubmitting: true,
        ),
        act: (bloc) => bloc.add(const TaskDetailCancelRequested()),
        expect: () => <TaskDetailState>[],
      );

      blocTest<TaskDetailBloc, TaskDetailState>(
        'complete is ignored when already submitting',
        build: () => taskDetailBloc,
        seed: () => const TaskDetailState(
          status: TaskDetailStatus.loaded,
          task: testTask,
          isSubmitting: true,
        ),
        act: (bloc) => bloc.add(const TaskDetailCompleteRequested()),
        expect: () => <TaskDetailState>[],
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
        const state = TaskDetailState(
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
