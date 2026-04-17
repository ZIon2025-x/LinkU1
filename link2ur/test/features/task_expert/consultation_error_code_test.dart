import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:link2ur/features/task_expert/bloc/task_expert_bloc.dart';
import 'package:link2ur/data/repositories/task_expert_repository.dart';
import 'package:link2ur/data/repositories/question_repository.dart';

class _MockTaskExpertRepo extends Mock implements TaskExpertRepository {}

class _MockQuestionRepo extends Mock implements QuestionRepository {}

void main() {
  group('TaskExpertBloc consultation errorCode plumbing', () {
    late _MockTaskExpertRepo taskExpertRepo;
    late _MockQuestionRepo questionRepo;

    setUp(() {
      taskExpertRepo = _MockTaskExpertRepo();
      questionRepo = _MockQuestionRepo();
    });

    blocTest<TaskExpertBloc, TaskExpertState>(
      'populates errorCode when repo throws TaskExpertException with errorCode',
      build: () {
        when(() => taskExpertRepo.createConsultation(any())).thenThrow(
          const TaskExpertException('服务已下架', errorCode: 'SERVICE_INACTIVE'),
        );
        return TaskExpertBloc(
          taskExpertRepository: taskExpertRepo,
          questionRepository: questionRepo,
        );
      },
      act: (bloc) => bloc.add(const TaskExpertStartConsultation(42)),
      expect: () => [
        isA<TaskExpertState>()
            .having((s) => s.isSubmitting, 'isSubmitting', true),
        isA<TaskExpertState>()
            .having((s) => s.errorCode, 'errorCode', 'SERVICE_INACTIVE')
            .having((s) => s.errorMessage, 'errorMessage', contains('服务已下架')),
      ],
    );

    blocTest<TaskExpertBloc, TaskExpertState>(
      'leaves errorCode null for generic Exception',
      build: () {
        when(() => taskExpertRepo.createConsultation(any()))
            .thenThrow(Exception('oops'));
        return TaskExpertBloc(
          taskExpertRepository: taskExpertRepo,
          questionRepository: questionRepo,
        );
      },
      act: (bloc) => bloc.add(const TaskExpertStartConsultation(42)),
      expect: () => [
        isA<TaskExpertState>()
            .having((s) => s.isSubmitting, 'isSubmitting', true),
        isA<TaskExpertState>().having((s) => s.errorCode, 'errorCode', null),
      ],
    );
  });
}
