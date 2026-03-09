import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/profile/bloc/profile_bloc.dart';
import 'package:link2ur/data/models/user.dart';
import 'package:link2ur/data/models/task.dart';
import 'package:link2ur/data/models/forum.dart';
import 'package:link2ur/data/repositories/user_repository.dart';
import 'package:link2ur/data/repositories/task_repository.dart';
import 'package:link2ur/data/repositories/forum_repository.dart';

class MockUserRepository extends Mock implements UserRepository {}

class MockTaskRepository extends Mock implements TaskRepository {}

class MockForumRepository extends Mock implements ForumRepository {}

void main() {
  late MockUserRepository mockUserRepo;
  late MockTaskRepository mockTaskRepo;
  late MockForumRepository mockForumRepo;
  late ProfileBloc bloc;

  final testUser = User(
    id: '1',
    name: 'Test User',
    email: 'test@example.com',
    createdAt: DateTime(2026),
  );

  const testTask = Task(
    id: 1,
    title: 'Test Task',
    taskType: 'delivery',
    reward: 10.0,
    status: 'open',
    posterId: 'user1',
  );

  const testTaskListResponse = TaskListResponse(
    tasks: [testTask],
    total: 1,
    page: 1,
    pageSize: 20,
  );

  const testForumPost = ForumPost(
    id: 1,
    title: 'Test Post',
    categoryId: 1,
    authorId: '1',
  );

  const testForumPostListResponse = ForumPostListResponse(
    posts: [testForumPost],
    total: 1,
    page: 1,
    pageSize: 20,
  );

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockUserRepo = MockUserRepository();
    mockTaskRepo = MockTaskRepository();
    mockForumRepo = MockForumRepository();
    bloc = ProfileBloc(
      userRepository: mockUserRepo,
      taskRepository: mockTaskRepo,
      forumRepository: mockForumRepo,
    );
  });

  tearDown(() {
    bloc.close();
  });

  group('ProfileBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, equals(ProfileStatus.initial));
      expect(bloc.state.user, isNull);
      expect(bloc.state.isUpdating, isFalse);
      expect(bloc.state.myTasks, isEmpty);
      expect(bloc.state.postedTasks, isEmpty);
      expect(bloc.state.myForumPosts, isEmpty);
    });

    group('ProfileLoadRequested', () {
      blocTest<ProfileBloc, ProfileState>(
        'emits [loading, loaded] with user on success',
        build: () {
          when(() => mockUserRepo.getProfile())
              .thenAnswer((_) async => testUser);
          return bloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadRequested()),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          ProfileState(
            status: ProfileStatus.loaded,
            user: testUser,
          ),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits [loading, error] when load fails',
        build: () {
          when(() => mockUserRepo.getProfile())
              .thenThrow(Exception('Network error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadRequested()),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          isA<ProfileState>()
              .having(
                  (s) => s.status, 'status', ProfileStatus.error)
              .having((s) => s.errorMessage, 'errorMessage',
                  'profile_load_failed'),
        ],
      );
    });

    group('ProfileUpdateRequested', () {
      blocTest<ProfileBloc, ProfileState>(
        'emits [updating, updated] with new user on success',
        build: () {
          final updatedUser = User(
            id: '1',
            name: 'Updated Name',
            email: 'test@example.com',
            createdAt: DateTime(2026),
          );
          when(() => mockUserRepo.updateProfile(
                name: any(named: 'name'),
                residenceCity: any(named: 'residenceCity'),
                languagePreference: any(named: 'languagePreference'),
                email: any(named: 'email'),
                emailVerificationCode:
                    any(named: 'emailVerificationCode'),
                phone: any(named: 'phone'),
                phoneVerificationCode:
                    any(named: 'phoneVerificationCode'),
              )).thenAnswer((_) async => updatedUser);
          return bloc;
        },
        act: (bloc) => bloc.add(
            const ProfileUpdateRequested({'name': 'Updated Name'})),
        expect: () => [
          isA<ProfileState>()
              .having((s) => s.isUpdating, 'isUpdating', isTrue),
          isA<ProfileState>()
              .having((s) => s.isUpdating, 'isUpdating', isFalse)
              .having(
                  (s) => s.user?.name, 'user.name', 'Updated Name')
              .having((s) => s.actionMessage, 'actionMessage',
                  'profile_updated'),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'does nothing when already updating',
        build: () => bloc,
        seed: () => const ProfileState(isUpdating: true),
        act: (bloc) => bloc.add(
            const ProfileUpdateRequested({'name': 'New Name'})),
        expect: () => [],
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits error on update failure',
        build: () {
          when(() => mockUserRepo.updateProfile(
                name: any(named: 'name'),
                residenceCity: any(named: 'residenceCity'),
                languagePreference: any(named: 'languagePreference'),
                email: any(named: 'email'),
                emailVerificationCode:
                    any(named: 'emailVerificationCode'),
                phone: any(named: 'phone'),
                phoneVerificationCode:
                    any(named: 'phoneVerificationCode'),
              )).thenThrow(Exception('Update failed'));
          return bloc;
        },
        act: (bloc) => bloc.add(
            const ProfileUpdateRequested({'name': 'Bad Name'})),
        expect: () => [
          isA<ProfileState>()
              .having((s) => s.isUpdating, 'isUpdating', isTrue),
          isA<ProfileState>()
              .having((s) => s.isUpdating, 'isUpdating', isFalse)
              .having((s) => s.errorMessage, 'errorMessage',
                  'profile_update_failed')
              .having((s) => s.actionMessage, 'actionMessage',
                  'update_failed'),
        ],
      );
    });

    group('ProfileUpdateAvatar', () {
      blocTest<ProfileBloc, ProfileState>(
        'updates avatar on success',
        build: () {
          when(() => mockUserRepo.updateAvatar(any()))
              .thenAnswer((_) async => testUser);
          return bloc;
        },
        act: (bloc) => bloc.add(
            const ProfileUpdateAvatar('/path/to/avatar.jpg')),
        expect: () => [
          isA<ProfileState>()
              .having((s) => s.isUpdating, 'isUpdating', isTrue),
          isA<ProfileState>()
              .having((s) => s.isUpdating, 'isUpdating', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'avatar_updated'),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits error on avatar update failure',
        build: () {
          when(() => mockUserRepo.updateAvatar(any()))
              .thenThrow(Exception('Upload failed'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const ProfileUpdateAvatar('/bad/path.jpg')),
        expect: () => [
          isA<ProfileState>()
              .having((s) => s.isUpdating, 'isUpdating', isTrue),
          isA<ProfileState>()
              .having((s) => s.isUpdating, 'isUpdating', isFalse)
              .having((s) => s.errorMessage, 'errorMessage',
                  'profile_update_avatar_failed'),
        ],
      );
    });

    group('ProfileUploadAvatar', () {
      blocTest<ProfileBloc, ProfileState>(
        'uploads avatar bytes on success',
        build: () {
          when(() => mockUserRepo.uploadAvatar(any(), any()))
              .thenAnswer((_) async => testUser);
          return bloc;
        },
        act: (bloc) => bloc.add(
            ProfileUploadAvatar(Uint8List.fromList([1, 2, 3]), 'avatar.png')),
        expect: () => [
          isA<ProfileState>()
              .having((s) => s.isUpdating, 'isUpdating', isTrue),
          isA<ProfileState>()
              .having((s) => s.isUpdating, 'isUpdating', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'avatar_updated'),
        ],
      );
    });

    group('ProfileLoadMyTasks', () {
      blocTest<ProfileBloc, ProfileState>(
        'loads my accepted tasks on first page',
        build: () {
          when(() => mockTaskRepo.getMyTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                status: any(named: 'status'),
              )).thenAnswer((_) async => testTaskListResponse);
          return bloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadMyTasks()),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          isA<ProfileState>()
              .having(
                  (s) => s.status, 'status', ProfileStatus.loaded)
              .having((s) => s.myTasks.length, 'myTasks.length', 1),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'loads my posted tasks on first page',
        build: () {
          when(() => mockTaskRepo.getMyPostedTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                status: any(named: 'status'),
              )).thenAnswer((_) async => testTaskListResponse);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const ProfileLoadMyTasks(isPosted: true)),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          isA<ProfileState>()
              .having(
                  (s) => s.status, 'status', ProfileStatus.loaded)
              .having((s) => s.postedTasks.length,
                  'postedTasks.length', 1),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'appends tasks on subsequent pages',
        build: () {
          when(() => mockTaskRepo.getMyTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                status: any(named: 'status'),
              )).thenAnswer((_) async => testTaskListResponse);
          return bloc;
        },
        seed: () => const ProfileState(
          status: ProfileStatus.loaded,
          myTasks: [testTask],
        ),
        act: (bloc) =>
            bloc.add(const ProfileLoadMyTasks(page: 2)),
        expect: () => [
          isA<ProfileState>()
              .having(
                  (s) => s.myTasks.length, 'myTasks.length', 2),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits error when loading tasks fails',
        build: () {
          when(() => mockTaskRepo.getMyTasks(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                status: any(named: 'status'),
              )).thenThrow(Exception('Failed'));
          return bloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadMyTasks()),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          isA<ProfileState>()
              .having(
                  (s) => s.status, 'status', ProfileStatus.error)
              .having((s) => s.errorMessage, 'errorMessage',
                  'profile_load_tasks_failed'),
        ],
      );
    });

    group('ProfileLoadPublicProfile', () {
      blocTest<ProfileBloc, ProfileState>(
        'loads public profile on success',
        build: () {
          final detail = UserProfileDetail(
            user: testUser,
            stats: const UserProfileStats(),
          );
          when(() => mockUserRepo.getPublicProfileDetail(any()))
              .thenAnswer((_) async => detail);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const ProfileLoadPublicProfile('user2')),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          isA<ProfileState>()
              .having(
                  (s) => s.status, 'status', ProfileStatus.loaded)
              .having((s) => s.publicUser, 'publicUser', isNotNull)
              .having((s) => s.publicProfileDetail,
                  'publicProfileDetail', isNotNull),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits error when public profile fails',
        build: () {
          when(() => mockUserRepo.getPublicProfileDetail(any()))
              .thenThrow(Exception('Not found'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const ProfileLoadPublicProfile('bad_id')),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          isA<ProfileState>()
              .having(
                  (s) => s.status, 'status', ProfileStatus.error)
              .having((s) => s.errorMessage, 'errorMessage',
                  'profile_load_public_failed'),
        ],
      );
    });

    group('ProfileLoadMyForumPosts', () {
      blocTest<ProfileBloc, ProfileState>(
        'loads forum posts on success',
        build: () {
          when(() => mockForumRepo.getMyPosts(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => testForumPostListResponse);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const ProfileLoadMyForumPosts()),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          isA<ProfileState>()
              .having(
                  (s) => s.status, 'status', ProfileStatus.loaded)
              .having((s) => s.myForumPosts.length,
                  'myForumPosts.length', 1),
        ],
      );
    });

    group('ProfileLoadMyForumActivity', () {
      blocTest<ProfileBloc, ProfileState>(
        'loads favorited posts',
        build: () {
          when(() => mockForumRepo.getFavoritePosts(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => testForumPostListResponse);
          return bloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadMyForumActivity(
            type: 'favorited')),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          isA<ProfileState>()
              .having(
                  (s) => s.status, 'status', ProfileStatus.loaded)
              .having((s) => s.favoritedPosts.length,
                  'favoritedPosts.length', 1),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'loads liked posts',
        build: () {
          when(() => mockForumRepo.getLikedPosts(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => testForumPostListResponse);
          return bloc;
        },
        act: (bloc) => bloc.add(
            const ProfileLoadMyForumActivity(type: 'liked')),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          isA<ProfileState>()
              .having(
                  (s) => s.status, 'status', ProfileStatus.loaded)
              .having((s) => s.likedPosts.length,
                  'likedPosts.length', 1),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'loads posts type uses getMyPosts',
        build: () {
          when(() => mockForumRepo.getMyPosts(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => testForumPostListResponse);
          return bloc;
        },
        act: (bloc) => bloc.add(
            const ProfileLoadMyForumActivity(type: 'posts')),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          isA<ProfileState>()
              .having(
                  (s) => s.status, 'status', ProfileStatus.loaded)
              .having((s) => s.myForumPosts.length,
                  'myForumPosts.length', 1),
        ],
      );
    });

    group('ProfileLoadPreferences', () {
      blocTest<ProfileBloc, ProfileState>(
        'loads preferences on success',
        build: () {
          when(() => mockUserRepo.getUserPreferences())
              .thenAnswer((_) async => {'theme': 'dark'});
          return bloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadPreferences()),
        expect: () => [
          const ProfileState(status: ProfileStatus.loading),
          isA<ProfileState>()
              .having(
                  (s) => s.status, 'status', ProfileStatus.loaded)
              .having((s) => s.preferences, 'preferences',
                  {'theme': 'dark'}),
        ],
      );
    });

    group('ProfileUpdatePreferences', () {
      blocTest<ProfileBloc, ProfileState>(
        'updates preferences on success',
        build: () {
          when(() => mockUserRepo.updateUserPreferences(any()))
              .thenAnswer((_) async {});
          when(() => mockUserRepo.getUserPreferences())
              .thenAnswer((_) async => {'theme': 'light'});
          return bloc;
        },
        act: (bloc) => bloc.add(
            const ProfileUpdatePreferences({'theme': 'light'})),
        expect: () => [
          isA<ProfileState>()
              .having((s) => s.isUpdating, 'isUpdating', isTrue),
          isA<ProfileState>()
              .having((s) => s.isUpdating, 'isUpdating', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'preferences_updated'),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits error on update preferences failure',
        build: () {
          when(() => mockUserRepo.updateUserPreferences(any()))
              .thenThrow(Exception('Failed'));
          return bloc;
        },
        act: (bloc) => bloc.add(
            const ProfileUpdatePreferences({'theme': 'light'})),
        expect: () => [
          isA<ProfileState>()
              .having((s) => s.isUpdating, 'isUpdating', isTrue),
          isA<ProfileState>()
              .having((s) => s.isUpdating, 'isUpdating', isFalse)
              .having((s) => s.errorMessage, 'errorMessage',
                  'profile_update_preferences_failed'),
        ],
      );
    });

    group('ProfileSendEmailCode', () {
      blocTest<ProfileBloc, ProfileState>(
        'sends email code and starts countdown on success',
        build: () {
          when(() => mockUserRepo.sendEmailUpdateCode(any()))
              .thenAnswer((_) async {});
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const ProfileSendEmailCode('test@example.com')),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<ProfileState>()
              .having(
                  (s) => s.isSendingEmailCode, 'isSendingEmailCode', isTrue)
              .having(
                  (s) => s.showEmailCodeField, 'showEmailCodeField', isTrue),
          isA<ProfileState>()
              .having((s) => s.isSendingEmailCode, 'isSendingEmailCode',
                  isFalse)
              .having((s) => s.emailCountdown, 'emailCountdown', 60)
              .having((s) => s.actionMessage, 'actionMessage',
                  'email_code_sent'),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'does nothing when already sending email code',
        build: () => bloc,
        seed: () => const ProfileState(isSendingEmailCode: true),
        act: (bloc) =>
            bloc.add(const ProfileSendEmailCode('test@example.com')),
        expect: () => [],
      );

      blocTest<ProfileBloc, ProfileState>(
        'emits error on send email code failure',
        build: () {
          when(() => mockUserRepo.sendEmailUpdateCode(any()))
              .thenThrow(Exception('Failed'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const ProfileSendEmailCode('bad@example.com')),
        expect: () => [
          isA<ProfileState>()
              .having(
                  (s) => s.isSendingEmailCode, 'isSendingEmailCode', isTrue),
          isA<ProfileState>()
              .having((s) => s.isSendingEmailCode, 'isSendingEmailCode',
                  isFalse)
              .having((s) => s.errorMessage, 'errorMessage',
                  'profile_send_email_code_failed'),
        ],
      );
    });

    group('ProfileSendPhoneCode', () {
      blocTest<ProfileBloc, ProfileState>(
        'sends phone code and starts countdown on success',
        build: () {
          when(() => mockUserRepo.sendPhoneUpdateCode(any()))
              .thenAnswer((_) async {});
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const ProfileSendPhoneCode('+447123456789')),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<ProfileState>()
              .having(
                  (s) => s.isSendingPhoneCode, 'isSendingPhoneCode', isTrue)
              .having(
                  (s) => s.showPhoneCodeField, 'showPhoneCodeField', isTrue),
          isA<ProfileState>()
              .having((s) => s.isSendingPhoneCode, 'isSendingPhoneCode',
                  isFalse)
              .having((s) => s.phoneCountdown, 'phoneCountdown', 60)
              .having((s) => s.actionMessage, 'actionMessage',
                  'phone_code_sent'),
        ],
      );
    });

    group('ProfileState helpers', () {
      test('isLoading returns true for loading status', () {
        const state = ProfileState(status: ProfileStatus.loading);
        expect(state.isLoading, isTrue);
      });

      test('isLoading returns false for loaded status', () {
        const state = ProfileState(status: ProfileStatus.loaded);
        expect(state.isLoading, isFalse);
      });

      test('copyWith preserves values when no overrides', () {
        final state = ProfileState(
          status: ProfileStatus.loaded,
          user: testUser,
        );
        final copied = state.copyWith();
        expect(copied.status, equals(ProfileStatus.loaded));
        expect(copied.user, equals(testUser));
      });
    });
  });
}
