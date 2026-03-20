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
    final testSummary = UserProfileSummary(
      capabilities: [
        const UserCapability(
          id: 1, categoryId: 1, skillName: '英语沟通',
          proficiency: 'intermediate', verificationSource: 'self_declared',
        ),
      ],
      preference: const UserProfilePreference(mode: 'online'),
      reliability: const UserReliability(reliabilityScore: 85, totalTasksTaken: 10, insufficientData: false),
      demand: const UserDemand(userStage: 'settling'),
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
        UserProfileState(status: UserProfileStatus.loaded, summary: testSummary),
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
        UserProfileState(status: UserProfileStatus.loaded, summary: testSummary),
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
        UserProfileState(status: UserProfileStatus.loaded, summary: testSummary),
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
        UserProfileState(status: UserProfileStatus.loaded, summary: testSummary),
      ],
    );
  });
}
