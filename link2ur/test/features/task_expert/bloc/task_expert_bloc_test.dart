import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/task_expert/bloc/task_expert_bloc.dart';
import 'package:link2ur/data/models/task_expert.dart';
import 'package:link2ur/data/repositories/task_expert_repository.dart';
import 'package:link2ur/data/repositories/activity_repository.dart';
import 'package:link2ur/data/repositories/question_repository.dart';

class MockTaskExpertRepository extends Mock
    implements TaskExpertRepository {}

class MockActivityRepository extends Mock implements ActivityRepository {}

class MockQuestionRepository extends Mock implements QuestionRepository {}

void main() {
  late MockTaskExpertRepository mockExpertRepo;
  late MockActivityRepository mockActivityRepo;
  late MockQuestionRepository mockQuestionRepo;
  late TaskExpertBloc bloc;

  const testExpert = TaskExpert(
    id: 'expert1',
    expertName: 'Test Expert',
    rating: 4.5,
    totalServices: 10,
    completedTasks: 8,
    category: 'tutoring',
    location: 'London',
  );

  const testExpert2 = TaskExpert(
    id: 'expert2',
    expertName: 'Another Expert',
    rating: 4.0,
    category: 'delivery',
  );

  const testListResponse = TaskExpertListResponse(
    experts: [testExpert, testExpert2],
    total: 2,
    page: 1,
    pageSize: 50,
  );

  const testService = TaskExpertService(
    id: 1,
    expertId: 'expert1',
    serviceName: 'Math Tutoring',
    basePrice: 20.0,
  );

  setUp(() {
    mockExpertRepo = MockTaskExpertRepository();
    mockActivityRepo = MockActivityRepository();
    mockQuestionRepo = MockQuestionRepository();
    bloc = TaskExpertBloc(
      taskExpertRepository: mockExpertRepo,
      activityRepository: mockActivityRepo,
      questionRepository: mockQuestionRepo,
    );
  });

  tearDown(() {
    bloc.close();
  });

  group('TaskExpertBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, equals(TaskExpertStatus.initial));
      expect(bloc.state.experts, isEmpty);
      expect(bloc.state.selectedExpert, isNull);
      expect(bloc.state.services, isEmpty);
    });

    group('TaskExpertLoadRequested', () {
      blocTest<TaskExpertBloc, TaskExpertState>(
        'emits [loading, loaded] with experts on success',
        build: () {
          when(() => mockExpertRepo.getExperts(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                keyword: any(named: 'keyword'),
                category: any(named: 'category'),
                location: any(named: 'location'),
                sort: any(named: 'sort'),
                forceRefresh: any(named: 'forceRefresh'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testListResponse);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const TaskExpertLoadRequested()),
        expect: () => [
          // _onLoadRequested sets searchKeyword: '' so we can't use const
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loading)
              .having((s) => s.searchKeyword, 'searchKeyword', ''),
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loaded)
              .having(
                  (s) => s.experts.length, 'experts.length', 2),
        ],
      );

      blocTest<TaskExpertBloc, TaskExpertState>(
        'emits [loading, error] when load fails',
        build: () {
          when(() => mockExpertRepo.getExperts(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                keyword: any(named: 'keyword'),
                category: any(named: 'category'),
                location: any(named: 'location'),
                sort: any(named: 'sort'),
                forceRefresh: any(named: 'forceRefresh'),
                cancelToken: any(named: 'cancelToken'),
              )).thenThrow(Exception('Network error'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const TaskExpertLoadRequested()),
        expect: () => [
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loading)
              .having((s) => s.searchKeyword, 'searchKeyword', ''),
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.error)
              .having(
                  (s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('TaskExpertLoadMore', () {
      blocTest<TaskExpertBloc, TaskExpertState>(
        'appends more experts',
        build: () {
          when(() => mockExpertRepo.getExperts(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                keyword: any(named: 'keyword'),
                category: any(named: 'category'),
                location: any(named: 'location'),
                sort: any(named: 'sort'),
                forceRefresh: any(named: 'forceRefresh'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => const TaskExpertListResponse(
                experts: [testExpert2],
                total: 3,
                page: 2,
                pageSize: 50,
              ));
          return bloc;
        },
        seed: () => const TaskExpertState(
          status: TaskExpertStatus.loaded,
          experts: [testExpert],
        ),
        act: (bloc) => bloc.add(const TaskExpertLoadMore()),
        expect: () => [
          isA<TaskExpertState>()
              .having(
                  (s) => s.experts.length, 'experts.length', 2)
              .having((s) => s.page, 'page', 2),
        ],
      );

      blocTest<TaskExpertBloc, TaskExpertState>(
        'does nothing when hasMore is false',
        build: () => bloc,
        seed: () => const TaskExpertState(
          status: TaskExpertStatus.loaded,
          experts: [testExpert],
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const TaskExpertLoadMore()),
        expect: () => [],
      );
    });

    group('TaskExpertFilterChanged', () {
      blocTest<TaskExpertBloc, TaskExpertState>(
        'updates filters and reloads',
        build: () {
          when(() => mockExpertRepo.getExperts(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                keyword: any(named: 'keyword'),
                category: any(named: 'category'),
                location: any(named: 'location'),
                sort: any(named: 'sort'),
                forceRefresh: any(named: 'forceRefresh'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => const TaskExpertListResponse(
                experts: [testExpert],
                total: 1,
                page: 1,
                pageSize: 50,
              ));
          return bloc;
        },
        act: (bloc) => bloc.add(const TaskExpertFilterChanged(
          category: 'tutoring',
          city: 'London',
        )),
        expect: () => [
          isA<TaskExpertState>()
              .having((s) => s.selectedCategory,
                  'selectedCategory', 'tutoring')
              .having(
                  (s) => s.selectedCity, 'selectedCity', 'London')
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loading),
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loaded),
        ],
      );
    });

    group('TaskExpertLoadDetail', () {
      blocTest<TaskExpertBloc, TaskExpertState>(
        'loads expert detail with services',
        build: () {
          when(() => mockExpertRepo.getExpertById(any()))
              .thenAnswer((_) async => testExpert);
          when(() => mockExpertRepo.getExpertServices(any()))
              .thenAnswer((_) async => [testService]);
          return bloc;
        },
        act: (bloc) => bloc.add(
            const TaskExpertLoadDetail('expert1')),
        expect: () => [
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loading),
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loaded)
              .having((s) => s.selectedExpert,
                  'selectedExpert', testExpert)
              .having(
                  (s) => s.services.length, 'services.length', 1),
        ],
      );

      blocTest<TaskExpertBloc, TaskExpertState>(
        'emits error when detail load fails',
        build: () {
          when(() => mockExpertRepo.getExpertById(any()))
              .thenThrow(Exception('Not found'));
          return bloc;
        },
        act: (bloc) => bloc.add(
            const TaskExpertLoadDetail('bad_id')),
        expect: () => [
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loading),
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.error),
        ],
      );
    });

    group('TaskExpertApplyService', () {
      blocTest<TaskExpertBloc, TaskExpertState>(
        'applies to service on success',
        build: () {
          when(() => mockExpertRepo.applyService(
                any(),
                message: any(named: 'message'),
                counterPrice: any(named: 'counterPrice'),
                timeSlotId: any(named: 'timeSlotId'),
                preferredDeadline: any(named: 'preferredDeadline'),
                isFlexibleTime: any(named: 'isFlexibleTime'),
              )).thenAnswer((_) async => {'success': true});
          return bloc;
        },
        act: (bloc) => bloc.add(const TaskExpertApplyService(
          1,
          message: 'I need help',
        )),
        expect: () => [
          isA<TaskExpertState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<TaskExpertState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'application_submitted'),
        ],
      );

      blocTest<TaskExpertBloc, TaskExpertState>(
        'emits error on apply failure',
        build: () {
          when(() => mockExpertRepo.applyService(
                any(),
                message: any(named: 'message'),
                counterPrice: any(named: 'counterPrice'),
                timeSlotId: any(named: 'timeSlotId'),
                preferredDeadline: any(named: 'preferredDeadline'),
                isFlexibleTime: any(named: 'isFlexibleTime'),
              )).thenThrow(Exception('Failed'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const TaskExpertApplyService(1)),
        expect: () => [
          isA<TaskExpertState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<TaskExpertState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  isNotNull),
        ],
      );
    });

    group('TaskExpertSearchRequested', () {
      blocTest<TaskExpertBloc, TaskExpertState>(
        'searches experts by keyword',
        build: () {
          when(() => mockExpertRepo.searchExperts(
                keyword: any(named: 'keyword'),
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => [testExpert]);
          return bloc;
        },
        act: (bloc) => bloc.add(
            const TaskExpertSearchRequested('math')),
        expect: () => [
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loading),
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loaded)
              .having((s) => s.searchResults.length,
                  'searchResults.length', 1),
        ],
      );
    });

    group('TaskExpertLoadMyApplications', () {
      blocTest<TaskExpertBloc, TaskExpertState>(
        'loads my service applications',
        build: () {
          when(() => mockExpertRepo.getMyServiceApplications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => [
                {
                  'id': 1,
                  'service_id': 1,
                  'status': 'pending',
                }
              ]);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const TaskExpertLoadMyApplications()),
        expect: () => [
          // _onLoadMyApplications emits loading first, then loaded
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loading),
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loaded)
              .having((s) => s.applications.length,
                  'applications.length', 1),
        ],
      );
    });

    group('TaskExpertLoadServiceReviews', () {
      blocTest<TaskExpertBloc, TaskExpertState>(
        'loads service reviews',
        build: () {
          when(() => mockExpertRepo.getServiceReviews(
                any(),
                limit: any(named: 'limit'),
                offset: any(named: 'offset'),
              )).thenAnswer((_) async => {
                // BLoC reads result['items'] and result['total']
                'items': <Map<String, dynamic>>[
                  {'id': 1, 'rating': 5, 'comment': 'Great'},
                ],
                'total': 1,
              });
          return bloc;
        },
        act: (bloc) => bloc.add(
            const TaskExpertLoadServiceReviews(1)),
        expect: () => [
          // _onLoadServiceReviews emits isLoadingReviews:true first
          isA<TaskExpertState>()
              .having((s) => s.isLoadingReviews,
                  'isLoadingReviews', isTrue),
          isA<TaskExpertState>()
              .having((s) => s.isLoadingReviews,
                  'isLoadingReviews', isFalse)
              .having(
                  (s) => s.reviews.length, 'reviews.length', 1)
              .having(
                  (s) => s.reviewsTotal, 'reviewsTotal', 1),
        ],
      );
    });

    group('TaskExpertLoadExpertApplications', () {
      blocTest<TaskExpertBloc, TaskExpertState>(
        'loads incoming expert applications',
        build: () {
          when(() => mockExpertRepo.getExpertApplications('expert1'))
              .thenAnswer((_) async => [
                    {
                      'id': 1,
                      'user_id': 'user1',
                      'status': 'pending',
                    }
                  ]);
          return TaskExpertBloc(
            taskExpertRepository: mockExpertRepo,
            activityRepository: mockActivityRepo,
            questionRepository: mockQuestionRepo,
            expertId: 'expert1',
          );
        },
        act: (bloc) =>
            bloc.add(const TaskExpertLoadExpertApplications()),
        expect: () => [
          // _onLoadExpertApplications emits loading first, then loaded
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loading),
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loaded)
              .having((s) => s.expertApplications.length,
                  'expertApplications.length', 1),
        ],
      );
    });

    group('TaskExpertApproveApplication', () {
      blocTest<TaskExpertBloc, TaskExpertState>(
        'approves application and reloads',
        build: () {
          when(() => mockExpertRepo.approveServiceApplication(any()))
              .thenAnswer((_) async => {'success': true});
          // Chained reload uses expertId=null branch, no repo call.
          return bloc;
        },
        act: (bloc) => bloc.add(
            const TaskExpertApproveApplication(1)),
        expect: () => [
          // 1) isSubmitting: true
          isA<TaskExpertState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isTrue),
          // 2) isSubmitting: false, actionMessage set
          isA<TaskExpertState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'application_approved'),
          // 3) chained TaskExpertLoadExpertApplications -> loading
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loading),
          // 4) chained TaskExpertLoadExpertApplications -> loaded
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loaded)
              .having((s) => s.expertApplications,
                  'expertApplications', isEmpty),
        ],
      );
    });

    group('TaskExpertRejectApplication', () {
      blocTest<TaskExpertBloc, TaskExpertState>(
        'rejects application with reason',
        build: () {
          when(() => mockExpertRepo.rejectServiceApplication(
                any(),
                reason: any(named: 'reason'),
              )).thenAnswer((_) async {});
          // Chained reload uses expertId=null branch, no repo call.
          return bloc;
        },
        act: (bloc) => bloc.add(
            const TaskExpertRejectApplication(
              1,
              reason: 'Not qualified',
            )),
        expect: () => [
          // 1) isSubmitting: true
          isA<TaskExpertState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isTrue),
          // 2) isSubmitting: false, actionMessage set
          isA<TaskExpertState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'application_rejected'),
          // 3) chained TaskExpertLoadExpertApplications -> loading
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loading),
          // 4) chained TaskExpertLoadExpertApplications -> loaded
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loaded)
              .having((s) => s.expertApplications,
                  'expertApplications', isEmpty),
        ],
      );
    });

    group('TaskExpertLoadMyExpertApplicationStatus', () {
      blocTest<TaskExpertBloc, TaskExpertState>(
        'loads expert application status',
        build: () {
          when(() => mockExpertRepo.getMyExpertApplication())
              .thenAnswer((_) async => {
                    'status': 'approved',
                  });
          return bloc;
        },
        act: (bloc) => bloc
            .add(const TaskExpertLoadMyExpertApplicationStatus()),
        expect: () => [
          // myExpertApplicationStatus is a Map, not a String
          isA<TaskExpertState>()
              .having((s) => s.myExpertApplicationStatus,
                  'myExpertApplicationStatus',
                  {'status': 'approved'}),
        ],
      );

      blocTest<TaskExpertBloc, TaskExpertState>(
        'sets null when no application exists',
        build: () {
          when(() => mockExpertRepo.getMyExpertApplication())
              .thenAnswer((_) async => null);
          return bloc;
        },
        act: (bloc) => bloc
            .add(const TaskExpertLoadMyExpertApplicationStatus()),
        // copyWith always resets errorMessage/actionMessage/serviceDetail to null
        // (direct assignment, not ?? this.x), causing a new state emission
        // even though myExpertApplicationStatus stays null
        expect: () => [
          isA<TaskExpertState>()
              .having((s) => s.myExpertApplicationStatus,
                  'myExpertApplicationStatus', isNull),
        ],
      );
    });

    group('TaskExpertApplyToBeExpert', () {
      blocTest<TaskExpertBloc, TaskExpertState>(
        'applies to become expert on success',
        build: () {
          when(() => mockExpertRepo.applyToBeExpert(
                applicationData: any(named: 'applicationData'),
              )).thenAnswer((_) async => {'success': true});
          when(() => mockExpertRepo.getMyExpertApplication())
              .thenAnswer((_) async => {'status': 'pending'});
          return bloc;
        },
        act: (bloc) => bloc.add(
            const TaskExpertApplyToBeExpert(
              message: 'Expert in math',
            )),
        expect: () => [
          // 1) isSubmitting: true
          isA<TaskExpertState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isTrue),
          // 2) isSubmitting: false, actionMessage set
          isA<TaskExpertState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'expert_application_submitted'),
          // 3) chained TaskExpertLoadMyExpertApplicationStatus -> sets Map
          isA<TaskExpertState>()
              .having((s) => s.myExpertApplicationStatus,
                  'myExpertApplicationStatus',
                  {'status': 'pending'}),
        ],
      );
    });

    group('TaskExpertRefreshRequested', () {
      blocTest<TaskExpertBloc, TaskExpertState>(
        'refreshes experts from page 1',
        build: () {
          when(() => mockExpertRepo.getExperts(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                keyword: any(named: 'keyword'),
                category: any(named: 'category'),
                location: any(named: 'location'),
                sort: any(named: 'sort'),
                forceRefresh: any(named: 'forceRefresh'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testListResponse);
          return bloc;
        },
        seed: () => const TaskExpertState(
          status: TaskExpertStatus.loaded,
          experts: [testExpert],
          page: 3,
        ),
        act: (bloc) =>
            bloc.add(const TaskExpertRefreshRequested()),
        // _onRefresh does NOT emit loading state — goes straight to loaded
        expect: () => [
          isA<TaskExpertState>()
              .having((s) => s.status, 'status',
                  TaskExpertStatus.loaded)
              .having(
                  (s) => s.experts.length, 'experts.length', 2)
              .having((s) => s.page, 'page', 1),
        ],
      );
    });

    group('TaskExpertState helpers', () {
      test('isLoading returns true for loading status', () {
        const state =
            TaskExpertState(status: TaskExpertStatus.loading);
        expect(state.isLoading, isTrue);
      });

      test('isLoading returns false for loaded status', () {
        const state =
            TaskExpertState(status: TaskExpertStatus.loaded);
        expect(state.isLoading, isFalse);
      });
    });
  });
}
