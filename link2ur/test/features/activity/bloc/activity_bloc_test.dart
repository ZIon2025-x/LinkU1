import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/activity/bloc/activity_bloc.dart';
import 'package:link2ur/data/models/activity.dart';
import 'package:link2ur/data/models/task_expert.dart';
import 'package:link2ur/data/repositories/activity_repository.dart';
import 'package:link2ur/data/repositories/task_expert_repository.dart';

class MockActivityRepository extends Mock implements ActivityRepository {}

class MockTaskExpertRepository extends Mock implements TaskExpertRepository {}

void main() {
  late MockActivityRepository mockActivityRepo;
  late MockTaskExpertRepository mockExpertRepo;
  late ActivityBloc bloc;

  const testActivity = Activity(
    id: 1,
    title: 'Test Activity',
    expertId: 'expert1',
    expertServiceId: 1,
    maxParticipants: 10,
    currentParticipants: 3,
  );

  const testActivity2 = Activity(
    id: 2,
    title: 'Another Activity',
    expertId: 'expert2',
    expertServiceId: 2,
  );

  const testListResponse = ActivityListResponse(
    activities: [testActivity, testActivity2],
    total: 2,
    page: 1,
    pageSize: 20,
  );

  const testExpert = TaskExpert(
    id: 'expert1',
    expertName: 'Test Expert',
    rating: 4.5,
  );

  const testOfficialResult = OfficialActivityResult(
    isDrawn: true,
    myStatus: 'winner',
  );

  setUp(() {
    mockActivityRepo = MockActivityRepository();
    mockExpertRepo = MockTaskExpertRepository();
    bloc = ActivityBloc(
      activityRepository: mockActivityRepo,
      taskExpertRepository: mockExpertRepo,
    );
  });

  tearDown(() {
    bloc.close();
  });

  group('ActivityBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, equals(ActivityStatus.initial));
      expect(bloc.state.activities, isEmpty);
      expect(bloc.state.activityDetail, isNull);
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.page, equals(1));
    });

    group('ActivityLoadRequested', () {
      blocTest<ActivityBloc, ActivityState>(
        'emits [loading, loaded] with activities on success',
        build: () {
          when(() => mockActivityRepo.getActivities(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                status: any(named: 'status'),
                keyword: any(named: 'keyword'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testListResponse);
          return bloc;
        },
        act: (bloc) => bloc.add(const ActivityLoadRequested()),
        expect: () => [
          const ActivityState(status: ActivityStatus.loading),
          isA<ActivityState>()
              .having(
                  (s) => s.status, 'status', ActivityStatus.loaded)
              .having((s) => s.activities.length,
                  'activities.length', 2)
              .having((s) => s.total, 'total', 2),
        ],
      );

      blocTest<ActivityBloc, ActivityState>(
        'emits [loading, error] when load fails',
        build: () {
          when(() => mockActivityRepo.getActivities(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                status: any(named: 'status'),
                keyword: any(named: 'keyword'),
                cancelToken: any(named: 'cancelToken'),
              )).thenThrow(Exception('Network error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const ActivityLoadRequested()),
        expect: () => [
          const ActivityState(status: ActivityStatus.loading),
          isA<ActivityState>()
              .having(
                  (s) => s.status, 'status', ActivityStatus.error)
              .having(
                  (s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );

      blocTest<ActivityBloc, ActivityState>(
        'loads with status filter',
        build: () {
          when(() => mockActivityRepo.getActivities(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                status: any(named: 'status'),
                keyword: any(named: 'keyword'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => const ActivityListResponse(
                activities: [testActivity],
                total: 1,
                page: 1,
                pageSize: 20,
              ));
          return bloc;
        },
        act: (bloc) => bloc.add(
            const ActivityLoadRequested(status: 'open')),
        expect: () => [
          const ActivityState(status: ActivityStatus.loading),
          isA<ActivityState>()
              .having((s) => s.activities.length,
                  'activities.length', 1),
        ],
      );
    });

    group('ActivityLoadMore', () {
      blocTest<ActivityBloc, ActivityState>(
        'appends more activities',
        build: () {
          when(() => mockActivityRepo.getActivities(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                status: any(named: 'status'),
                keyword: any(named: 'keyword'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => const ActivityListResponse(
                activities: [testActivity2],
                total: 3,
                page: 2,
                pageSize: 20,
              ));
          return bloc;
        },
        seed: () => const ActivityState(
          status: ActivityStatus.loaded,
          activities: [testActivity],
        ),
        act: (bloc) => bloc.add(const ActivityLoadMore()),
        expect: () => [
          // First emit: isLoadingMore = true
          isA<ActivityState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', isTrue),
          // Second emit: activities appended, isLoadingMore = false
          isA<ActivityState>()
              .having((s) => s.activities.length,
                  'activities.length', 2)
              .having((s) => s.page, 'page', 2)
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse),
        ],
      );

      blocTest<ActivityBloc, ActivityState>(
        'does nothing when hasMore is false',
        build: () => bloc,
        seed: () => const ActivityState(
          status: ActivityStatus.loaded,
          activities: [testActivity],
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const ActivityLoadMore()),
        expect: () => [],
      );

      blocTest<ActivityBloc, ActivityState>(
        'does nothing when already loading more',
        build: () => bloc,
        seed: () => const ActivityState(
          status: ActivityStatus.loaded,
          activities: [testActivity],
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const ActivityLoadMore()),
        expect: () => [],
      );
    });

    group('ActivityRefreshRequested', () {
      blocTest<ActivityBloc, ActivityState>(
        'refreshes activities from page 1',
        build: () {
          when(() => mockActivityRepo.getActivities(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                status: any(named: 'status'),
                keyword: any(named: 'keyword'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testListResponse);
          return bloc;
        },
        seed: () => const ActivityState(
          status: ActivityStatus.loaded,
          activities: [testActivity],
          page: 3,
        ),
        act: (bloc) => bloc.add(const ActivityRefreshRequested()),
        expect: () => [
          // _onRefresh does NOT emit loading state; it directly emits loaded result
          isA<ActivityState>()
              .having(
                  (s) => s.status, 'status', ActivityStatus.loaded)
              .having((s) => s.activities.length,
                  'activities.length', 2)
              .having((s) => s.page, 'page', 1),
        ],
      );
    });

    group('ActivityLoadDetail', () {
      blocTest<ActivityBloc, ActivityState>(
        'loads activity detail with expert info',
        build: () {
          when(() => mockActivityRepo.getActivityById(any()))
              .thenAnswer((_) async => testActivity);
          when(() => mockExpertRepo.getExpertById(any()))
              .thenAnswer((_) async => testExpert);
          when(() => mockActivityRepo.getFavoriteStatus(any()))
              .thenAnswer((_) async => false);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const ActivityLoadDetail(1)),
        expect: () => [
          // 1. detailStatus = loading, officialApplyStatus = idle, isFavorited = false
          isA<ActivityState>()
              .having((s) => s.detailStatus, 'detailStatus',
                  ActivityStatus.loading),
          // 2. detailStatus = loaded, activityDetail = testActivity
          isA<ActivityState>()
              .having((s) => s.detailStatus, 'detailStatus',
                  ActivityStatus.loaded)
              .having((s) => s.activityDetail, 'activityDetail',
                  testActivity),
          // 3. expert loaded (separate emit since expertId is non-empty)
          isA<ActivityState>()
              .having((s) => s.expert, 'expert', testExpert),
          // Note: ActivityLoadFavoriteStatus emits copyWith(isFavorited: false)
          // but isFavorited is already false (set in loading emit), so Equatable
          // deduplication suppresses this state emission.
        ],
      );

      blocTest<ActivityBloc, ActivityState>(
        'emits error when detail load fails',
        build: () {
          when(() => mockActivityRepo.getActivityById(any()))
              .thenThrow(Exception('Not found'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const ActivityLoadDetail(99)),
        expect: () => [
          isA<ActivityState>()
              .having((s) => s.detailStatus, 'detailStatus',
                  ActivityStatus.loading),
          isA<ActivityState>()
              .having((s) => s.detailStatus, 'detailStatus',
                  ActivityStatus.error),
        ],
      );
    });

    group('ActivityApply', () {
      blocTest<ActivityBloc, ActivityState>(
        'applies to activity on success',
        build: () {
          when(() => mockActivityRepo.applyActivity(
                any(),
                timeSlotId: any(named: 'timeSlotId'),
                preferredDeadline: any(named: 'preferredDeadline'),
                isFlexibleTime: any(named: 'isFlexibleTime'),
              )).thenAnswer((_) async => {'success': true});
          // Mock for the chained ActivityRefreshRequested
          when(() => mockActivityRepo.getActivities(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                status: any(named: 'status'),
                keyword: any(named: 'keyword'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => testListResponse);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const ActivityApply(1)),
        expect: () => [
          // 1. isSubmitting = true
          isA<ActivityState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isTrue),
          // 2. isSubmitting = false, actionMessage = 'registration_success'
          isA<ActivityState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'registration_success'),
          // 3. Chained ActivityRefreshRequested emits loaded state
          isA<ActivityState>()
              .having(
                  (s) => s.status, 'status', ActivityStatus.loaded),
        ],
      );

      blocTest<ActivityBloc, ActivityState>(
        'emits error on apply failure',
        build: () {
          when(() => mockActivityRepo.applyActivity(
                any(),
                timeSlotId: any(named: 'timeSlotId'),
                preferredDeadline: any(named: 'preferredDeadline'),
                isFlexibleTime: any(named: 'isFlexibleTime'),
              )).thenThrow(Exception('Full'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const ActivityApply(1)),
        expect: () => [
          isA<ActivityState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<ActivityState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  isNotNull),
        ],
      );
    });

    group('ActivityLoadTimeSlots', () {
      blocTest<ActivityBloc, ActivityState>(
        'loads time slots for service',
        build: () {
          when(() => mockExpertRepo.getServiceTimeSlots(any()))
              .thenAnswer((_) async => [
                    {
                      'id': 1,
                      'service_id': 1,
                      'slot_start_datetime': '2026-03-10T10:00:00',
                      'slot_end_datetime': '2026-03-10T11:00:00',
                      'current_participants': 2,
                      'max_participants': 5,
                    }
                  ]);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const ActivityLoadTimeSlots(serviceId: 1, activityId: 1)),
        expect: () => [
          isA<ActivityState>()
              .having((s) => s.isLoadingTimeSlots,
                  'isLoadingTimeSlots', isTrue),
          isA<ActivityState>()
              .having((s) => s.isLoadingTimeSlots,
                  'isLoadingTimeSlots', isFalse),
        ],
      );
    });

    group('ActivityToggleFavorite', () {
      blocTest<ActivityBloc, ActivityState>(
        'toggles favorite optimistically from false to true',
        build: () {
          when(() => mockActivityRepo.toggleFavorite(any()))
              .thenAnswer((_) async {});
          return bloc;
        },
        seed: () => const ActivityState(
          status: ActivityStatus.loaded,
          activityDetail: testActivity,
        ),
        act: (bloc) => bloc.add(
            const ActivityToggleFavorite(activityId: 1)),
        expect: () => [
          // 1. Optimistic: isFavorited toggled + isTogglingFavorite = true
          isA<ActivityState>()
              .having((s) => s.isFavorited, 'isFavorited', isTrue)
              .having((s) => s.isTogglingFavorite,
                  'isTogglingFavorite', isTrue),
          // 2. Completed: isTogglingFavorite = false
          isA<ActivityState>()
              .having((s) => s.isFavorited, 'isFavorited', isTrue)
              .having((s) => s.isTogglingFavorite,
                  'isTogglingFavorite', isFalse),
        ],
      );

      blocTest<ActivityBloc, ActivityState>(
        'toggles favorite optimistically from true to false',
        build: () {
          when(() => mockActivityRepo.toggleFavorite(any()))
              .thenAnswer((_) async {});
          return bloc;
        },
        seed: () => const ActivityState(
          status: ActivityStatus.loaded,
          activityDetail: testActivity,
          isFavorited: true,
        ),
        act: (bloc) => bloc.add(
            const ActivityToggleFavorite(activityId: 1)),
        expect: () => [
          // 1. Optimistic: isFavorited toggled + isTogglingFavorite = true
          isA<ActivityState>()
              .having(
                  (s) => s.isFavorited, 'isFavorited', isFalse)
              .having((s) => s.isTogglingFavorite,
                  'isTogglingFavorite', isTrue),
          // 2. Completed: isTogglingFavorite = false
          isA<ActivityState>()
              .having(
                  (s) => s.isFavorited, 'isFavorited', isFalse)
              .having((s) => s.isTogglingFavorite,
                  'isTogglingFavorite', isFalse),
        ],
      );
    });

    group('ActivityApplyOfficial', () {
      blocTest<ActivityBloc, ActivityState>(
        'applies to official activity on success',
        build: () {
          when(() => mockActivityRepo.applyOfficialActivity(any()))
              .thenAnswer((_) async => <String, dynamic>{'success': true, 'requires_payment': false});
          // Mock for chained ActivityLoadDetail(activityId)
          when(() => mockActivityRepo.getActivityById(any()))
              .thenAnswer((_) async => testActivity);
          when(() => mockExpertRepo.getExpertById(any()))
              .thenAnswer((_) async => testExpert);
          when(() => mockActivityRepo.getFavoriteStatus(any()))
              .thenAnswer((_) async => false);
          return bloc;
        },
        act: (bloc) => bloc.add(
            const ActivityApplyOfficial(activityId: 1)),
        expect: () => [
          // 1. officialApplyStatus = applying
          isA<ActivityState>()
              .having((s) => s.officialApplyStatus,
                  'officialApplyStatus', OfficialApplyStatus.applying),
          // 2. officialApplyStatus = applied
          isA<ActivityState>()
              .having((s) => s.officialApplyStatus,
                  'officialApplyStatus', OfficialApplyStatus.applied),
          // 3-5. Chained ActivityLoadDetail emits: loading, loaded, expert
          // (isFavorited=false is deduplicated since _onLoadDetail sets it to false in loading emit)
          isA<ActivityState>()
              .having((s) => s.detailStatus, 'detailStatus',
                  ActivityStatus.loading),
          isA<ActivityState>()
              .having((s) => s.detailStatus, 'detailStatus',
                  ActivityStatus.loaded),
          isA<ActivityState>()
              .having((s) => s.expert, 'expert', testExpert),
        ],
      );
    });

    group('ActivityCancelApplyOfficial', () {
      blocTest<ActivityBloc, ActivityState>(
        'cancels official activity application on success',
        build: () {
          when(() =>
                  mockActivityRepo.cancelOfficialActivityApplication(any()))
              .thenAnswer((_) async {});
          // Mock for chained ActivityLoadDetail(activityId)
          when(() => mockActivityRepo.getActivityById(any()))
              .thenAnswer((_) async => testActivity);
          when(() => mockExpertRepo.getExpertById(any()))
              .thenAnswer((_) async => testExpert);
          when(() => mockActivityRepo.getFavoriteStatus(any()))
              .thenAnswer((_) async => false);
          return bloc;
        },
        seed: () => const ActivityState(
          officialApplyStatus: OfficialApplyStatus.applied,
        ),
        act: (bloc) => bloc.add(
            const ActivityCancelApplyOfficial(activityId: 1)),
        expect: () => [
          // 1. officialApplyStatus = idle (no "applying" state emitted)
          isA<ActivityState>()
              .having((s) => s.officialApplyStatus,
                  'officialApplyStatus', OfficialApplyStatus.idle),
          // 2-4. Chained ActivityLoadDetail emits: loading, loaded, expert
          // (isFavorited=false is deduplicated since _onLoadDetail sets it to false in loading emit)
          isA<ActivityState>()
              .having((s) => s.detailStatus, 'detailStatus',
                  ActivityStatus.loading),
          isA<ActivityState>()
              .having((s) => s.detailStatus, 'detailStatus',
                  ActivityStatus.loaded),
          isA<ActivityState>()
              .having((s) => s.expert, 'expert', testExpert),
        ],
      );
    });

    group('ActivityLoadResult', () {
      blocTest<ActivityBloc, ActivityState>(
        'loads official activity result on success',
        build: () {
          when(() =>
                  mockActivityRepo.getOfficialActivityResult(any()))
              .thenAnswer((_) async => testOfficialResult);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const ActivityLoadResult(activityId: 1)),
        expect: () => [
          isA<ActivityState>()
              .having((s) => s.officialResult, 'officialResult',
                  testOfficialResult),
        ],
      );
    });

    group('ActivityClearActionMessage', () {
      blocTest<ActivityBloc, ActivityState>(
        'clears action message',
        build: () => bloc,
        seed: () => const ActivityState(
          actionMessage: 'some_action',
        ),
        act: (bloc) =>
            bloc.add(const ActivityClearActionMessage()),
        expect: () => [
          isA<ActivityState>()
              .having(
                  (s) => s.actionMessage, 'actionMessage', isNull),
        ],
      );
    });

    group('ActivityState helpers', () {
      test('isLoading returns true for loading status', () {
        const state = ActivityState(status: ActivityStatus.loading);
        expect(state.isLoading, isTrue);
      });

      test('isLoading returns false for loaded status', () {
        const state = ActivityState(status: ActivityStatus.loaded);
        expect(state.isLoading, isFalse);
      });
    });
  });
}
