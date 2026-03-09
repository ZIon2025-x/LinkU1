import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/notification/bloc/notification_bloc.dart';
import 'package:link2ur/data/models/notification.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  late MockNotificationRepository mockRepo;
  late NotificationBloc bloc;

  // -------------------- Test data --------------------

  final now = DateTime(2026, 3, 8, 12);

  final systemNotification1 = AppNotification(
    id: 1,
    userId: 'user1',
    type: 'task_applied',
    title: '新申请',
    content: '有人申请了你的任务',
    createdAt: now,
  );

  final systemNotification2 = AppNotification(
    id: 2,
    userId: 'user1',
    type: 'system',
    title: '系统通知',
    content: '系统维护公告',
    createdAt: now.subtract(const Duration(hours: 1)),
  );

  final readSystemNotification = AppNotification(
    id: 3,
    userId: 'user1',
    type: 'payment',
    title: '支付通知',
    content: '支付成功',
    isRead: true,
    createdAt: now.subtract(const Duration(hours: 2)),
  );

  final forumNotification1 = AppNotification(
    id: 10,
    userId: 'user1',
    type: 'forum_reply',
    title: '论坛回复',
    content: '有人回复了你的帖子',
    createdAt: now.subtract(const Duration(minutes: 10)),
  );

  final forumNotification2 = AppNotification(
    id: 11,
    userId: 'user1',
    type: 'forum_like',
    title: '论坛点赞',
    content: '有人点赞了你的帖子',
    createdAt: now.subtract(const Duration(minutes: 30)),
  );

  final leaderboardNotification = AppNotification(
    id: 20,
    userId: 'user1',
    type: 'leaderboard_rank_up',
    title: '排行榜',
    content: '你的排名上升了',
    createdAt: now.subtract(const Duration(minutes: 20)),
  );

  // -------------------- Setup / teardown --------------------

  setUp(() {
    mockRepo = MockNotificationRepository();
    bloc = NotificationBloc(notificationRepository: mockRepo);
    registerFallbackValues();
  });

  tearDown(() {
    bloc.close();
  });

  // -------------------- Tests --------------------

  group('NotificationBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, equals(NotificationStatus.initial));
      expect(bloc.state.notifications, isEmpty);
      expect(bloc.state.total, equals(0));
      expect(bloc.state.page, equals(1));
      expect(bloc.state.hasMore, isTrue);
      expect(bloc.state.unreadCount.count, equals(0));
      expect(bloc.state.unreadCount.forumCount, equals(0));
      expect(bloc.state.unreadCount.totalCount, equals(0));
      expect(bloc.state.errorMessage, isNull);
      expect(bloc.state.selectedType, isNull);
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.hasUnread, isFalse);
    });

    // ==================== NotificationLoadRequested ====================

    group('NotificationLoadRequested', () {
      blocTest<NotificationBloc, NotificationState>(
        'emits [loading, loaded] with all notifications when type is null',
        build: () {
          when(() => mockRepo.getNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => NotificationListResponse(
                notifications: [systemNotification1, systemNotification2],
                total: 2,
                page: 1,
                pageSize: 20,
              ));
          return bloc;
        },
        act: (bloc) => bloc.add(const NotificationLoadRequested()),
        expect: () => [
          const NotificationState(status: NotificationStatus.loading),
          NotificationState(
            status: NotificationStatus.loaded,
            notifications: [systemNotification1, systemNotification2],
            total: 2,
            hasMore: false,
          ),
        ],
        verify: (_) {
          verify(() => mockRepo.getNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
                cancelToken: any(named: 'cancelToken'),
              )).called(1);
        },
      );

      blocTest<NotificationBloc, NotificationState>(
        'emits [loading, loaded] with system notifications when type is system',
        build: () {
          when(() => mockRepo.getNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => NotificationListResponse(
                notifications: [
                  systemNotification1,
                  systemNotification2,
                  readSystemNotification,
                ],
                total: 3,
                page: 1,
                pageSize: 20,
              ));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const NotificationLoadRequested(type: 'system')),
        expect: () => [
          const NotificationState(status: NotificationStatus.loading),
          NotificationState(
            status: NotificationStatus.loaded,
            notifications: [
              systemNotification1,
              systemNotification2,
              readSystemNotification,
            ],
            total: 3,
            hasMore: false,
            selectedType: 'system',
          ),
        ],
        verify: (_) {
          verify(() => mockRepo.getNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: 'system',
                cancelToken: any(named: 'cancelToken'),
              )).called(1);
        },
      );

      blocTest<NotificationBloc, NotificationState>(
        'emits [loading, loaded] with merged interaction notifications when type is interaction',
        build: () {
          // getForumNotifications returns forum notifications
          when(() => mockRepo.getForumNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => NotificationListResponse(
                notifications: [forumNotification1, forumNotification2],
                total: 2,
                page: 1,
                pageSize: 20,
              ));
          // getNotifications returns all (including leaderboard ones)
          when(() => mockRepo.getNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => NotificationListResponse(
                notifications: [
                  systemNotification1,
                  leaderboardNotification,
                  systemNotification2,
                ],
                total: 3,
                page: 1,
                pageSize: 20,
              ));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const NotificationLoadRequested(type: 'interaction')),
        expect: () => [
          const NotificationState(status: NotificationStatus.loading),
          // Merged: forum_reply (10min ago), leaderboard (20min ago), forum_like (30min ago)
          // sorted by createdAt descending
          NotificationState(
            status: NotificationStatus.loaded,
            notifications: [
              forumNotification1, // 10 min ago
              leaderboardNotification, // 20 min ago
              forumNotification2, // 30 min ago
            ],
            total: 3,
            hasMore: false,
            selectedType: 'interaction',
          ),
        ],
        verify: (_) {
          verify(() => mockRepo.getForumNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).called(1);
          verify(() => mockRepo.getNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
                cancelToken: any(named: 'cancelToken'),
              )).called(1);
        },
      );

      blocTest<NotificationBloc, NotificationState>(
        'filters out non-system notifications when type is system and response contains mixed types',
        build: () {
          // Backend returns mixed types (should not happen, but client filters)
          when(() => mockRepo.getNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => NotificationListResponse(
                notifications: [
                  systemNotification1,
                  forumNotification1, // should be filtered out
                  systemNotification2,
                ],
                total: 3,
                page: 1,
                pageSize: 20,
              ));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const NotificationLoadRequested(type: 'system')),
        expect: () => [
          const NotificationState(status: NotificationStatus.loading),
          NotificationState(
            status: NotificationStatus.loaded,
            notifications: [systemNotification1, systemNotification2],
            total: 2,
            hasMore: false,
            selectedType: 'system',
          ),
        ],
      );

      blocTest<NotificationBloc, NotificationState>(
        'emits [loading, error] when getNotifications throws',
        build: () {
          when(() => mockRepo.getNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
                cancelToken: any(named: 'cancelToken'),
              )).thenThrow(Exception('Network error'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const NotificationLoadRequested(type: 'system')),
        expect: () => [
          const NotificationState(status: NotificationStatus.loading),
          isA<NotificationState>()
              .having((s) => s.status, 'status', NotificationStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );

      blocTest<NotificationBloc, NotificationState>(
        'emits [loading, error] when getForumNotifications throws for interaction type',
        build: () {
          when(() => mockRepo.getForumNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenThrow(Exception('Forum API error'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const NotificationLoadRequested(type: 'interaction')),
        expect: () => [
          const NotificationState(status: NotificationStatus.loading),
          isA<NotificationState>()
              .having((s) => s.status, 'status', NotificationStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );

      blocTest<NotificationBloc, NotificationState>(
        'sets hasMore=true when response has >= pageSize notifications',
        build: () {
          // Create a response with exactly 20 items (pageSize)
          final manyNotifications = List.generate(
            20,
            (i) => AppNotification(
              id: 100 + i,
              userId: 'user1',
              type: 'system',
              title: 'Notification $i',
              content: 'Content $i',
              createdAt: now.subtract(Duration(minutes: i)),
            ),
          );
          when(() => mockRepo.getNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => NotificationListResponse(
                notifications: manyNotifications,
                total: 50,
                page: 1,
                pageSize: 20,
              ));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const NotificationLoadRequested(type: 'system')),
        expect: () => [
          const NotificationState(status: NotificationStatus.loading),
          isA<NotificationState>()
              .having((s) => s.status, 'status', NotificationStatus.loaded)
              .having((s) => s.hasMore, 'hasMore', isTrue)
              .having(
                  (s) => s.notifications.length, 'notifications.length', 20),
        ],
      );
    });

    // ==================== NotificationLoadMore ====================

    group('NotificationLoadMore', () {
      final initialNotifications = [systemNotification1, systemNotification2];
      final moreNotifications = [readSystemNotification];

      blocTest<NotificationBloc, NotificationState>(
        'appends new notifications and increments page',
        build: () {
          when(() => mockRepo.getNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => NotificationListResponse(
                notifications: moreNotifications,
                total: 3,
                page: 2,
                pageSize: 20,
              ));
          return bloc;
        },
        seed: () => NotificationState(
          status: NotificationStatus.loaded,
          notifications: initialNotifications,
          total: 3,
          selectedType: 'system',
        ),
        act: (bloc) => bloc.add(const NotificationLoadMore()),
        expect: () => [
          NotificationState(
            status: NotificationStatus.loaded,
            notifications: [...initialNotifications, ...moreNotifications],
            total: 3,
            page: 2,
            hasMore: false,
            selectedType: 'system',
          ),
        ],
        verify: (_) {
          verify(() => mockRepo.getNotifications(
                page: 2,
                pageSize: any(named: 'pageSize'),
                type: 'system',
                cancelToken: any(named: 'cancelToken'),
              )).called(1);
        },
      );

      blocTest<NotificationBloc, NotificationState>(
        'does not emit when hasMore is false',
        build: () => bloc,
        seed: () => NotificationState(
          status: NotificationStatus.loaded,
          notifications: initialNotifications,
          total: 2,
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const NotificationLoadMore()),
        expect: () => [],
        verify: (_) {
          verifyNever(() => mockRepo.getNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
                cancelToken: any(named: 'cancelToken'),
              ));
        },
      );

      blocTest<NotificationBloc, NotificationState>(
        'sets hasMore to false when load more throws',
        build: () {
          when(() => mockRepo.getNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
                cancelToken: any(named: 'cancelToken'),
              )).thenThrow(Exception('Network error'));
          return bloc;
        },
        seed: () => NotificationState(
          status: NotificationStatus.loaded,
          notifications: initialNotifications,
          total: 10,
        ),
        act: (bloc) => bloc.add(const NotificationLoadMore()),
        expect: () => [
          NotificationState(
            status: NotificationStatus.loaded,
            notifications: initialNotifications,
            total: 10,
            hasMore: false,
          ),
        ],
      );
    });

    // ==================== NotificationMarkAsRead ====================

    group('NotificationMarkAsRead', () {
      blocTest<NotificationBloc, NotificationState>(
        'optimistically marks system notification as read and decrements count',
        build: () {
          when(() => mockRepo.markAsRead(any()))
              .thenAnswer((_) async {});
          return bloc;
        },
        seed: () => NotificationState(
          status: NotificationStatus.loaded,
          notifications: [systemNotification1, systemNotification2],
          total: 2,
          hasMore: false,
          unreadCount: const UnreadNotificationCount(count: 3, forumCount: 2),
        ),
        act: (bloc) =>
            bloc.add(const NotificationMarkAsRead(1)), // id=1 is task_applied (system)
        expect: () => [
          isA<NotificationState>()
              .having((s) => s.status, 'status', NotificationStatus.loaded)
              .having((s) => s.notifications.length, 'notifications.length', 2)
              .having(
                  (s) => s.notifications[0].isRead, 'first notification isRead', true)
              .having(
                  (s) => s.notifications[1].isRead, 'second notification isRead', false)
              .having((s) => s.unreadCount.count, 'unreadCount.count', 2)
              .having(
                  (s) => s.unreadCount.forumCount, 'unreadCount.forumCount', 2),
        ],
      );

      blocTest<NotificationBloc, NotificationState>(
        'optimistically marks forum notification as read and decrements forumCount',
        build: () {
          when(() => mockRepo.markAsRead(any()))
              .thenAnswer((_) async {});
          return bloc;
        },
        seed: () => NotificationState(
          status: NotificationStatus.loaded,
          notifications: [forumNotification1, forumNotification2],
          total: 2,
          hasMore: false,
          selectedType: 'interaction',
          unreadCount: const UnreadNotificationCount(count: 3, forumCount: 2),
        ),
        act: (bloc) =>
            bloc.add(const NotificationMarkAsRead(10)), // id=10 is forum_reply
        expect: () => [
          isA<NotificationState>()
              .having((s) => s.status, 'status', NotificationStatus.loaded)
              .having(
                  (s) => s.notifications[0].isRead, 'forum_reply isRead', true)
              .having(
                  (s) => s.notifications[1].isRead, 'forum_like isRead', false)
              .having((s) => s.unreadCount.count, 'unreadCount.count', 3)
              .having(
                  (s) => s.unreadCount.forumCount, 'unreadCount.forumCount', 1),
        ],
      );

      blocTest<NotificationBloc, NotificationState>(
        'optimistically marks leaderboard notification as read and decrements forumCount',
        build: () {
          when(() => mockRepo.markAsRead(any()))
              .thenAnswer((_) async {});
          return bloc;
        },
        seed: () => NotificationState(
          status: NotificationStatus.loaded,
          notifications: [leaderboardNotification],
          total: 1,
          hasMore: false,
          selectedType: 'interaction',
          unreadCount: const UnreadNotificationCount(count: 1, forumCount: 1),
        ),
        act: (bloc) =>
            bloc.add(const NotificationMarkAsRead(20)), // leaderboard_rank_up
        expect: () => [
          isA<NotificationState>()
              .having((s) => s.status, 'status', NotificationStatus.loaded)
              .having((s) => s.notifications[0].isRead,
                  'leaderboard isRead', true)
              .having((s) => s.unreadCount.count, 'unreadCount.count', 1)
              .having(
                  (s) => s.unreadCount.forumCount, 'unreadCount.forumCount', 0),
        ],
      );

      blocTest<NotificationBloc, NotificationState>(
        'does not decrement count below zero',
        build: () {
          when(() => mockRepo.markAsRead(any()))
              .thenAnswer((_) async {});
          return bloc;
        },
        seed: () => NotificationState(
          status: NotificationStatus.loaded,
          notifications: [systemNotification1],
          total: 1,
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const NotificationMarkAsRead(1)),
        expect: () => [
          isA<NotificationState>()
              .having((s) => s.notifications[0].isRead, 'isRead', true)
              .having((s) => s.unreadCount.count, 'unreadCount.count', 0)
              .having(
                  (s) => s.unreadCount.forumCount, 'unreadCount.forumCount', 0),
        ],
      );

      blocTest<NotificationBloc, NotificationState>(
        'still emits update even when notification id is not found in list',
        build: () {
          when(() => mockRepo.markAsRead(any()))
              .thenAnswer((_) async {});
          return bloc;
        },
        seed: () => NotificationState(
          status: NotificationStatus.loaded,
          notifications: [systemNotification1],
          total: 1,
          hasMore: false,
          unreadCount: const UnreadNotificationCount(count: 2, forumCount: 1),
        ),
        act: (bloc) =>
            bloc.add(const NotificationMarkAsRead(999)), // non-existent id
        expect: () => [
          // target is null, isInteraction is false, so count decremented
          isA<NotificationState>()
              .having((s) => s.notifications.length, 'notifications.length', 1)
              .having((s) => s.notifications[0].id, 'notification id', 1)
              .having(
                  (s) => s.notifications[0].isRead, 'isRead unchanged', false)
              .having((s) => s.unreadCount.count, 'unreadCount.count', 1)
              .having(
                  (s) => s.unreadCount.forumCount, 'unreadCount.forumCount', 1),
        ],
      );
    });

    // ==================== NotificationMarkAllAsRead ====================

    group('NotificationMarkAllAsRead', () {
      blocTest<NotificationBloc, NotificationState>(
        'marks all notifications as read and sets unreadCount to zero',
        build: () {
          when(() => mockRepo.markAllAsRead())
              .thenAnswer((_) async {});
          return bloc;
        },
        seed: () => NotificationState(
          status: NotificationStatus.loaded,
          notifications: [
            systemNotification1,
            systemNotification2,
            forumNotification1,
          ],
          total: 3,
          hasMore: false,
          unreadCount: const UnreadNotificationCount(count: 2, forumCount: 1),
        ),
        act: (bloc) => bloc.add(const NotificationMarkAllAsRead()),
        expect: () => [
          isA<NotificationState>()
              .having((s) => s.status, 'status', NotificationStatus.loaded)
              .having((s) => s.notifications.length, 'notifications.length', 3)
              .having(
                  (s) => s.notifications.every((n) => n.isRead), 'all read', true)
              .having((s) => s.unreadCount.count, 'unreadCount.count', 0)
              .having(
                  (s) => s.unreadCount.forumCount, 'unreadCount.forumCount', 0),
        ],
      );

      blocTest<NotificationBloc, NotificationState>(
        'does not emit when all notifications are already read (Equatable dedup)',
        build: () {
          when(() => mockRepo.markAllAsRead())
              .thenAnswer((_) async {});
          return bloc;
        },
        seed: () => NotificationState(
          status: NotificationStatus.loaded,
          notifications: [readSystemNotification],
          total: 1,
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const NotificationMarkAllAsRead()),
        // All notifications already read + count already 0 → emitted state
        // is identical to seed → Equatable deduplication suppresses emission
        expect: () => [],
      );
    });

    // ==================== NotificationLoadUnreadNotificationCount ====================

    group('NotificationLoadUnreadNotificationCount', () {
      blocTest<NotificationBloc, NotificationState>(
        'updates unreadCount from repository',
        build: () {
          when(() => mockRepo.getUnreadCount(
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async =>
              const UnreadNotificationCount(count: 5, forumCount: 3));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const NotificationLoadUnreadNotificationCount()),
        expect: () => [
          isA<NotificationState>()
              .having((s) => s.unreadCount.count, 'unreadCount.count', 5)
              .having(
                  (s) => s.unreadCount.forumCount, 'unreadCount.forumCount', 3),
        ],
        verify: (_) {
          verify(() => mockRepo.getUnreadCount(
                cancelToken: any(named: 'cancelToken'),
              )).called(1);
        },
      );

      blocTest<NotificationBloc, NotificationState>(
        'does not change state when getUnreadCount throws',
        build: () {
          when(() => mockRepo.getUnreadCount(
                cancelToken: any(named: 'cancelToken'),
              )).thenThrow(Exception('Network error'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const NotificationLoadUnreadNotificationCount()),
        expect: () => [],
      );

      blocTest<NotificationBloc, NotificationState>(
        'updates unreadCount while preserving existing loaded state',
        build: () {
          when(() => mockRepo.getUnreadCount(
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async =>
              const UnreadNotificationCount(count: 10, forumCount: 4));
          return bloc;
        },
        seed: () => NotificationState(
          status: NotificationStatus.loaded,
          notifications: [systemNotification1],
          total: 1,
          hasMore: false,
          selectedType: 'system',
          unreadCount: const UnreadNotificationCount(count: 2, forumCount: 1),
        ),
        act: (bloc) =>
            bloc.add(const NotificationLoadUnreadNotificationCount()),
        expect: () => [
          isA<NotificationState>()
              .having((s) => s.status, 'status', NotificationStatus.loaded)
              .having((s) => s.notifications, 'notifications',
                  [systemNotification1])
              .having((s) => s.selectedType, 'selectedType', 'system')
              .having((s) => s.unreadCount.count, 'unreadCount.count', 10)
              .having(
                  (s) => s.unreadCount.forumCount, 'unreadCount.forumCount', 4),
        ],
      );
    });

    // ==================== NotificationRefreshListIfLoaded ====================

    group('NotificationRefreshListIfLoaded', () {
      blocTest<NotificationBloc, NotificationState>(
        'dispatches LoadRequested with selectedType when loaded with selectedType',
        build: () {
          when(() => mockRepo.getNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => NotificationListResponse(
                notifications: [systemNotification1],
                total: 1,
                page: 1,
                pageSize: 20,
              ));
          return bloc;
        },
        seed: () => NotificationState(
          status: NotificationStatus.loaded,
          notifications: [systemNotification1, systemNotification2],
          total: 2,
          hasMore: false,
          selectedType: 'system',
        ),
        act: (bloc) => bloc.add(const NotificationRefreshListIfLoaded()),
        expect: () => [
          // LoadRequested dispatched -> loading
          isA<NotificationState>()
              .having((s) => s.status, 'status', NotificationStatus.loading),
          // then loaded
          isA<NotificationState>()
              .having((s) => s.status, 'status', NotificationStatus.loaded)
              .having((s) => s.selectedType, 'selectedType', 'system'),
        ],
      );

      blocTest<NotificationBloc, NotificationState>(
        'dispatches LoadRequested with system type when loaded without selectedType',
        build: () {
          when(() => mockRepo.getNotifications(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => NotificationListResponse(
                notifications: [systemNotification1],
                total: 1,
                page: 1,
                pageSize: 20,
              ));
          return bloc;
        },
        seed: () => NotificationState(
          status: NotificationStatus.loaded,
          notifications: [systemNotification1],
          total: 1,
          hasMore: false,
          // selectedType is null
        ),
        act: (bloc) => bloc.add(const NotificationRefreshListIfLoaded()),
        expect: () => [
          isA<NotificationState>()
              .having((s) => s.status, 'status', NotificationStatus.loading),
          isA<NotificationState>()
              .having((s) => s.status, 'status', NotificationStatus.loaded)
              .having((s) => s.selectedType, 'selectedType', 'system'),
        ],
      );

      blocTest<NotificationBloc, NotificationState>(
        'does nothing when status is not loaded',
        build: () => bloc,
        // initial status (not loaded)
        act: (bloc) => bloc.add(const NotificationRefreshListIfLoaded()),
        expect: () => [],
      );

      blocTest<NotificationBloc, NotificationState>(
        'does nothing when status is error',
        build: () => bloc,
        seed: () => const NotificationState(
          status: NotificationStatus.error,
          errorMessage: 'some error',
        ),
        act: (bloc) => bloc.add(const NotificationRefreshListIfLoaded()),
        expect: () => [],
      );
    });

    // ==================== NotificationStopPolling ====================

    group('NotificationStopPolling', () {
      blocTest<NotificationBloc, NotificationState>(
        'does not emit any state changes',
        build: () => bloc,
        act: (bloc) => bloc.add(const NotificationStopPolling()),
        expect: () => [],
      );
    });

    // ==================== NotificationStartPolling ====================

    group('NotificationStartPolling', () {
      blocTest<NotificationBloc, NotificationState>(
        'does not emit any immediate state changes',
        build: () => bloc,
        act: (bloc) => bloc.add(const NotificationStartPolling()),
        expect: () => [],
      );
    });

    // ==================== State helpers ====================

    group('NotificationState helpers', () {
      test('isLoading returns true when status is loading', () {
        const state = NotificationState(status: NotificationStatus.loading);
        expect(state.isLoading, isTrue);
      });

      test('isLoading returns false when status is not loading', () {
        const state = NotificationState(status: NotificationStatus.loaded);
        expect(state.isLoading, isFalse);
      });

      test('hasUnread returns true when totalCount > 0', () {
        const state = NotificationState(
          unreadCount: UnreadNotificationCount(count: 1),
        );
        expect(state.hasUnread, isTrue);
      });

      test('hasUnread returns true when forumCount > 0', () {
        const state = NotificationState(
          unreadCount: UnreadNotificationCount(count: 0, forumCount: 1),
        );
        expect(state.hasUnread, isTrue);
      });

      test('hasUnread returns false when both counts are 0', () {
        const state = NotificationState();
        expect(state.hasUnread, isFalse);
      });
    });

    // ==================== State copyWith ====================

    group('NotificationState copyWith', () {
      test('copyWith preserves all fields when no arguments are provided', () {
        final state = NotificationState(
          status: NotificationStatus.loaded,
          notifications: [systemNotification1],
          total: 1,
          page: 2,
          hasMore: false,
          unreadCount: const UnreadNotificationCount(count: 5, forumCount: 3),
          errorMessage: 'error',
          selectedType: 'system',
        );

        final copied = state.copyWith();

        expect(copied.status, equals(NotificationStatus.loaded));
        expect(copied.notifications, equals([systemNotification1]));
        expect(copied.total, equals(1));
        expect(copied.page, equals(2));
        expect(copied.hasMore, isFalse);
        expect(copied.unreadCount.count, equals(5));
        expect(copied.unreadCount.forumCount, equals(3));
        // errorMessage uses direct assignment (not ?? this.errorMessage)
        // so omitting it resets to null
        expect(copied.errorMessage, isNull);
        expect(copied.selectedType, equals('system'));
      });

      test('copyWith replaces specified fields', () {
        const state = NotificationState();
        final copied = state.copyWith(
          status: NotificationStatus.loaded,
          page: 3,
          hasMore: false,
          errorMessage: 'new error',
          selectedType: 'interaction',
        );

        expect(copied.status, equals(NotificationStatus.loaded));
        expect(copied.page, equals(3));
        expect(copied.hasMore, isFalse);
        expect(copied.errorMessage, equals('new error'));
        expect(copied.selectedType, equals('interaction'));
      });

      test('copyWith resets errorMessage when not provided', () {
        const state = NotificationState(errorMessage: 'old error');
        final copied = state.copyWith(status: NotificationStatus.loaded);
        expect(copied.errorMessage, isNull);
      });
    });

    // ==================== Event equality ====================

    group('NotificationEvent equality', () {
      test('NotificationLoadRequested with same type are equal', () {
        expect(
          const NotificationLoadRequested(type: 'system'),
          equals(const NotificationLoadRequested(type: 'system')),
        );
      });

      test('NotificationLoadRequested with different types are not equal', () {
        expect(
          const NotificationLoadRequested(type: 'system'),
          isNot(equals(const NotificationLoadRequested(type: 'interaction'))),
        );
      });

      test('NotificationLoadRequested with null type are equal', () {
        expect(
          const NotificationLoadRequested(),
          equals(const NotificationLoadRequested()),
        );
      });

      test('NotificationMarkAsRead with same id are equal', () {
        expect(
          const NotificationMarkAsRead(1),
          equals(const NotificationMarkAsRead(1)),
        );
      });

      test('NotificationMarkAsRead with different ids are not equal', () {
        expect(
          const NotificationMarkAsRead(1),
          isNot(equals(const NotificationMarkAsRead(2))),
        );
      });

      test('NotificationLoadMore instances are equal', () {
        expect(
          const NotificationLoadMore(),
          equals(const NotificationLoadMore()),
        );
      });

      test('NotificationMarkAllAsRead instances are equal', () {
        expect(
          const NotificationMarkAllAsRead(),
          equals(const NotificationMarkAllAsRead()),
        );
      });

      test('NotificationLoadUnreadNotificationCount instances are equal', () {
        expect(
          const NotificationLoadUnreadNotificationCount(),
          equals(const NotificationLoadUnreadNotificationCount()),
        );
      });

      test('NotificationStartPolling instances are equal', () {
        expect(
          const NotificationStartPolling(),
          equals(const NotificationStartPolling()),
        );
      });

      test('NotificationStopPolling instances are equal', () {
        expect(
          const NotificationStopPolling(),
          equals(const NotificationStopPolling()),
        );
      });

      test('NotificationRefreshListIfLoaded instances are equal', () {
        expect(
          const NotificationRefreshListIfLoaded(),
          equals(const NotificationRefreshListIfLoaded()),
        );
      });
    });

    // ==================== UnreadNotificationCount ====================

    group('UnreadNotificationCount', () {
      test('totalCount sums count and forumCount', () {
        const unread = UnreadNotificationCount(count: 3, forumCount: 2);
        expect(unread.totalCount, equals(5));
      });

      test('forumCount defaults to 0', () {
        const unread = UnreadNotificationCount(count: 5);
        expect(unread.forumCount, equals(0));
        expect(unread.totalCount, equals(5));
      });

      test('fromJson parses correctly', () {
        final unread = UnreadNotificationCount.fromJson({
          'unread_count': 7,
          'forum_count': 3,
        });
        expect(unread.count, equals(7));
        expect(unread.forumCount, equals(3));
      });

      test('fromJson falls back to count key', () {
        final unread = UnreadNotificationCount.fromJson({
          'count': 4,
        });
        expect(unread.count, equals(4));
        expect(unread.forumCount, equals(0));
      });

      test('fromJson defaults to zero for missing keys', () {
        final unread = UnreadNotificationCount.fromJson({});
        expect(unread.count, equals(0));
        expect(unread.forumCount, equals(0));
      });
    });
  });
}
