import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:link2ur/data/models/user_profile.dart';
import 'package:link2ur/data/repositories/user_profile_repository.dart';
import 'package:link2ur/features/user_profile/bloc/user_profile_bloc.dart';

class MockUserProfileRepository extends Mock implements UserProfileRepository {}

void main() {
  late MockUserProfileRepository mockRepo;

  setUp(() {
    mockRepo = MockUserProfileRepository();
  });

  group('UserProfileBloc', () {
    const testSummary = UserProfileSummary(
      capabilities: [
        UserCapability(
          id: 1, categoryId: 1, skillName: '英语沟通',
          proficiency: 'intermediate', verificationSource: 'self_declared',
        ),
      ],
      preference: UserProfilePreference(mode: 'online'),
      reliability: UserReliability(reliabilityScore: 85, totalTasksTaken: 10, insufficientData: false),
      demand: UserDemand(userStages: ['settling']),
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'emits [loading, loaded] when LoadSummary succeeds',
      build: () {
        when(() => mockRepo.getSummary()).thenAnswer((_) async => testSummary);
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const UserProfileLoadSummary()),
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        const UserProfileState(status: UserProfileStatus.loaded, summary: testSummary),
      ],
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'emits [loading, error] when LoadSummary fails',
      build: () {
        when(() => mockRepo.getSummary()).thenThrow(
          const UserProfileException('Network error'),
        );
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const UserProfileLoadSummary()),
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        const UserProfileState(status: UserProfileStatus.error, errorMessage: 'user_profile_load_failed'),
      ],
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'emits [loading, loaded] when UpdateCapabilities succeeds',
      build: () {
        when(() => mockRepo.updateCapabilities(any())).thenAnswer((_) async {});
        when(() => mockRepo.getSummary()).thenAnswer((_) async => testSummary);
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const UserProfileUpdateCapabilities(
        capabilities: [{'category_id': 1, 'skill_name': '开车', 'proficiency': 'beginner'}],
      )),
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        const UserProfileState(status: UserProfileStatus.loaded, summary: testSummary),
      ],
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'emits [loading, loaded] when UpdatePreferences succeeds',
      build: () {
        when(() => mockRepo.updatePreferences(any())).thenAnswer((_) async {});
        when(() => mockRepo.getSummary()).thenAnswer((_) async => testSummary);
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const UserProfileUpdatePreferences(
        preferences: {'mode': 'offline'},
      )),
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        const UserProfileState(status: UserProfileStatus.loaded, summary: testSummary),
      ],
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'emits [loading, loaded] when DeleteCapability succeeds',
      build: () {
        when(() => mockRepo.deleteCapability(1)).thenAnswer((_) async {});
        when(() => mockRepo.getSummary()).thenAnswer((_) async => testSummary);
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const UserProfileDeleteCapability(capabilityId: 1)),
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        const UserProfileState(status: UserProfileStatus.loaded, summary: testSummary),
      ],
    );

    // --- Error code differentiation tests ---

    blocTest<UserProfileBloc, UserProfileState>(
      'emits user_profile_update_failed when UpdateCapabilities fails',
      build: () {
        when(() => mockRepo.updateCapabilities(any())).thenThrow(
          const UserProfileException('Server error'),
        );
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const UserProfileUpdateCapabilities(
        capabilities: [{'category_id': 1, 'skill_name': 'test'}],
      )),
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        const UserProfileState(status: UserProfileStatus.error, errorMessage: 'user_profile_update_failed'),
      ],
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'emits user_profile_delete_failed when DeleteCapability fails',
      build: () {
        when(() => mockRepo.deleteCapability(any())).thenThrow(
          const UserProfileException('Not found'),
        );
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const UserProfileDeleteCapability(capabilityId: 99)),
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        const UserProfileState(status: UserProfileStatus.error, errorMessage: 'user_profile_delete_failed'),
      ],
    );

    blocTest<UserProfileBloc, UserProfileState>(
      'emits user_profile_update_failed when UpdatePreferences fails',
      build: () {
        when(() => mockRepo.updatePreferences(any())).thenThrow(
          const UserProfileException('Validation error'),
        );
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const UserProfileUpdatePreferences(
        preferences: {'mode': 'invalid'},
      )),
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        const UserProfileState(status: UserProfileStatus.error, errorMessage: 'user_profile_update_failed'),
      ],
    );

    // --- Error recovery test ---

    blocTest<UserProfileBloc, UserProfileState>(
      'recovers from error state when LoadSummary is retried',
      build: () {
        var callCount = 0;
        when(() => mockRepo.getSummary()).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) throw const UserProfileException('Temporary error');
          return testSummary;
        });
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) async {
        bloc.add(const UserProfileLoadSummary());
        await Future.delayed(const Duration(milliseconds: 100));
        bloc.add(const UserProfileLoadSummary());
      },
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        const UserProfileState(status: UserProfileStatus.error, errorMessage: 'user_profile_load_failed'),
        const UserProfileState(status: UserProfileStatus.loading),
        const UserProfileState(status: UserProfileStatus.loaded, summary: testSummary),
      ],
    );

    // --- Generic exception test ---

    blocTest<UserProfileBloc, UserProfileState>(
      'passes raw error message for non-UserProfileException errors',
      build: () {
        when(() => mockRepo.getSummary()).thenThrow(Exception('Unknown error'));
        return UserProfileBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const UserProfileLoadSummary()),
      expect: () => [
        const UserProfileState(status: UserProfileStatus.loading),
        const UserProfileState(status: UserProfileStatus.error, errorMessage: 'Exception: Unknown error'),
      ],
    );
  });
}
