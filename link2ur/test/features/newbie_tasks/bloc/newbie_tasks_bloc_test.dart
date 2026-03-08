import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/newbie_tasks/bloc/newbie_tasks_bloc.dart';
import 'package:link2ur/data/models/newbie_task.dart';
import 'package:link2ur/data/models/official_task.dart';
import 'package:link2ur/data/repositories/newbie_tasks_repository.dart';
import 'package:link2ur/data/repositories/official_tasks_repository.dart';

class MockNewbieTasksRepository extends Mock implements NewbieTasksRepository {}

class MockOfficialTasksRepository extends Mock
    implements OfficialTasksRepository {}

void main() {
  late MockNewbieTasksRepository mockNewbieTasksRepository;
  late MockOfficialTasksRepository mockOfficialTasksRepository;
  late NewbieTasksBloc bloc;

  // Mock data
  final progressData = <Map<String, dynamic>>[
    {
      'task_key': 'upload_avatar',
      'status': 'completed',
      'completed_at': '2026-01-01T00:00:00.000Z',
      'claimed_at': null,
      'config': {
        'task_key': 'upload_avatar',
        'stage': 1,
        'title_zh': '上传头像',
        'title_en': 'Upload Avatar',
        'reward_type': 'points',
        'reward_amount': 50,
        'display_order': 1,
      }
    }
  ];

  final stagesData = <Map<String, dynamic>>[
    {
      'stage': 1,
      'status': 'pending',
      'claimed_at': null,
      'config': {
        'stage': 1,
        'title_zh': '第一阶段',
        'title_en': 'Stage 1',
        'reward_type': 'points',
        'reward_amount': 100,
      }
    }
  ];

  final officialTasksData = <Map<String, dynamic>>[
    {
      'id': 1,
      'title_zh': '分享心得',
      'title_en': 'Share Experience',
      'task_type': 'forum_post',
      'reward_type': 'points',
      'reward_amount': 100,
      'max_per_user': 3,
      'is_active': true,
      'user_submission_count': 0,
    }
  ];

  final expectedTasks =
      progressData.map((e) => NewbieTaskProgress.fromJson(e)).toList();
  final expectedStages =
      stagesData.map((e) => StageProgress.fromJson(e)).toList();
  final expectedOfficialTasks =
      officialTasksData.map((e) => OfficialTask.fromJson(e)).toList();

  setUp(() {
    mockNewbieTasksRepository = MockNewbieTasksRepository();
    mockOfficialTasksRepository = MockOfficialTasksRepository();
    bloc = NewbieTasksBloc(
      newbieTasksRepository: mockNewbieTasksRepository,
      officialTasksRepository: mockOfficialTasksRepository,
    );
  });

  tearDown(() {
    bloc.close();
  });

  group('NewbieTasksBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, equals(NewbieTasksStatus.initial));
      expect(bloc.state.tasks, isEmpty);
      expect(bloc.state.stages, isEmpty);
      expect(bloc.state.officialTasks, isEmpty);
      expect(bloc.state.errorMessage, isNull);
      expect(bloc.state.claimingTaskKey, isNull);
      expect(bloc.state.claimingStage, isNull);
    });

    // ==================== Load ====================

    group('NewbieTasksLoadRequested', () {
      blocTest<NewbieTasksBloc, NewbieTasksState>(
        'emits [loading, loaded] with tasks/stages/officialTasks on success',
        build: () {
          when(() => mockNewbieTasksRepository.getProgress())
              .thenAnswer((_) async => progressData);
          when(() => mockNewbieTasksRepository.getStages())
              .thenAnswer((_) async => stagesData);
          when(() => mockOfficialTasksRepository.getOfficialTasks())
              .thenAnswer((_) async => officialTasksData);
          return bloc;
        },
        act: (bloc) => bloc.add(const NewbieTasksLoadRequested()),
        expect: () => [
          isA<NewbieTasksState>()
              .having((s) => s.status, 'status', NewbieTasksStatus.loading),
          isA<NewbieTasksState>()
              .having((s) => s.status, 'status', NewbieTasksStatus.loaded)
              .having((s) => s.tasks, 'tasks', expectedTasks)
              .having((s) => s.stages, 'stages', expectedStages)
              .having(
                  (s) => s.officialTasks, 'officialTasks', expectedOfficialTasks)
              .having((s) => s.claimingTaskKey, 'claimingTaskKey', isNull)
              .having((s) => s.claimingStage, 'claimingStage', isNull),
        ],
        verify: (_) {
          verify(() => mockNewbieTasksRepository.getProgress()).called(1);
          verify(() => mockNewbieTasksRepository.getStages()).called(1);
          verify(() => mockOfficialTasksRepository.getOfficialTasks())
              .called(1);
        },
      );

      blocTest<NewbieTasksBloc, NewbieTasksState>(
        'emits [loading, error] on failure',
        build: () {
          when(() => mockNewbieTasksRepository.getProgress())
              .thenThrow(Exception('network error'));
          when(() => mockNewbieTasksRepository.getStages())
              .thenAnswer((_) async => stagesData);
          when(() => mockOfficialTasksRepository.getOfficialTasks())
              .thenAnswer((_) async => officialTasksData);
          return bloc;
        },
        act: (bloc) => bloc.add(const NewbieTasksLoadRequested()),
        expect: () => [
          isA<NewbieTasksState>()
              .having((s) => s.status, 'status', NewbieTasksStatus.loading),
          isA<NewbieTasksState>()
              .having((s) => s.status, 'status', NewbieTasksStatus.error)
              .having((s) => s.errorMessage, 'errorMessage',
                  'newbie_tasks_load_failed'),
        ],
      );
    });

    // ==================== Claim Task ====================

    group('NewbieTaskClaimRequested', () {
      blocTest<NewbieTasksBloc, NewbieTasksState>(
        'sets claimingTaskKey, claims task, then triggers reload',
        build: () {
          when(() => mockNewbieTasksRepository.claimTask('upload_avatar'))
              .thenAnswer((_) async => <String, dynamic>{'success': true});
          // The bloc calls add(NewbieTasksLoadRequested()) after claim success,
          // so we need to mock the reload calls too.
          when(() => mockNewbieTasksRepository.getProgress())
              .thenAnswer((_) async => progressData);
          when(() => mockNewbieTasksRepository.getStages())
              .thenAnswer((_) async => stagesData);
          when(() => mockOfficialTasksRepository.getOfficialTasks())
              .thenAnswer((_) async => officialTasksData);
          return bloc;
        },
        act: (bloc) => bloc.add(const NewbieTaskClaimRequested('upload_avatar')),
        expect: () => [
          // First: claimingTaskKey is set
          isA<NewbieTasksState>()
              .having((s) => s.claimingTaskKey, 'claimingTaskKey',
                  'upload_avatar'),
          // Then: reload sequence — loading
          isA<NewbieTasksState>()
              .having((s) => s.status, 'status', NewbieTasksStatus.loading),
          // Then: reload sequence — loaded
          isA<NewbieTasksState>()
              .having((s) => s.status, 'status', NewbieTasksStatus.loaded)
              .having((s) => s.tasks, 'tasks', expectedTasks)
              .having((s) => s.claimingTaskKey, 'claimingTaskKey', isNull)
              .having((s) => s.claimingStage, 'claimingStage', isNull),
        ],
        verify: (_) {
          verify(() => mockNewbieTasksRepository.claimTask('upload_avatar'))
              .called(1);
          verify(() => mockNewbieTasksRepository.getProgress()).called(1);
        },
      );

      blocTest<NewbieTasksBloc, NewbieTasksState>(
        'emits error on claim failure',
        build: () {
          when(() => mockNewbieTasksRepository.claimTask('upload_avatar'))
              .thenThrow(Exception('claim failed'));
          return bloc;
        },
        act: (bloc) => bloc.add(const NewbieTaskClaimRequested('upload_avatar')),
        expect: () => [
          // First: claimingTaskKey is set
          isA<NewbieTasksState>()
              .having((s) => s.claimingTaskKey, 'claimingTaskKey',
                  'upload_avatar'),
          // Then: error with claiming cleared
          isA<NewbieTasksState>()
              .having((s) => s.errorMessage, 'errorMessage',
                  'newbie_task_claim_failed')
              .having((s) => s.claimingTaskKey, 'claimingTaskKey', isNull)
              .having((s) => s.claimingStage, 'claimingStage', isNull),
        ],
      );
    });

    // ==================== Claim Stage Bonus ====================

    group('NewbieStageBonusClaimRequested', () {
      blocTest<NewbieTasksBloc, NewbieTasksState>(
        'sets claimingStage, claims bonus, then triggers reload',
        build: () {
          when(() => mockNewbieTasksRepository.claimStageBonus(1))
              .thenAnswer((_) async => <String, dynamic>{'success': true});
          // The bloc calls add(NewbieTasksLoadRequested()) after success
          when(() => mockNewbieTasksRepository.getProgress())
              .thenAnswer((_) async => progressData);
          when(() => mockNewbieTasksRepository.getStages())
              .thenAnswer((_) async => stagesData);
          when(() => mockOfficialTasksRepository.getOfficialTasks())
              .thenAnswer((_) async => officialTasksData);
          return bloc;
        },
        act: (bloc) => bloc.add(const NewbieStageBonusClaimRequested(1)),
        expect: () => [
          // First: claimingStage is set
          isA<NewbieTasksState>()
              .having((s) => s.claimingStage, 'claimingStage', 1),
          // Then: reload sequence — loading
          isA<NewbieTasksState>()
              .having((s) => s.status, 'status', NewbieTasksStatus.loading),
          // Then: reload sequence — loaded
          isA<NewbieTasksState>()
              .having((s) => s.status, 'status', NewbieTasksStatus.loaded)
              .having((s) => s.stages, 'stages', expectedStages)
              .having((s) => s.claimingTaskKey, 'claimingTaskKey', isNull)
              .having((s) => s.claimingStage, 'claimingStage', isNull),
        ],
        verify: (_) {
          verify(() => mockNewbieTasksRepository.claimStageBonus(1)).called(1);
          verify(() => mockNewbieTasksRepository.getProgress()).called(1);
        },
      );

      blocTest<NewbieTasksBloc, NewbieTasksState>(
        'emits error on failure',
        build: () {
          when(() => mockNewbieTasksRepository.claimStageBonus(1))
              .thenThrow(Exception('stage claim failed'));
          return bloc;
        },
        act: (bloc) => bloc.add(const NewbieStageBonusClaimRequested(1)),
        expect: () => [
          // First: claimingStage is set
          isA<NewbieTasksState>()
              .having((s) => s.claimingStage, 'claimingStage', 1),
          // Then: error with claiming cleared
          isA<NewbieTasksState>()
              .having((s) => s.errorMessage, 'errorMessage',
                  'newbie_stage_claim_failed')
              .having((s) => s.claimingTaskKey, 'claimingTaskKey', isNull)
              .having((s) => s.claimingStage, 'claimingStage', isNull),
        ],
      );
    });
  });
}
