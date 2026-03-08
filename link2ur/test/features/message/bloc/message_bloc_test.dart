import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/message/bloc/message_bloc.dart';
import 'package:link2ur/data/models/message.dart';
import 'package:link2ur/data/models/user.dart';
import 'package:link2ur/data/repositories/message_repository.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  late MockMessageRepository mockMessageRepository;
  late MessageBloc messageBloc;

  // Test data
  final testContacts = [
    ChatContact(
      id: 'c1',
      user: const UserBrief(id: 'u1', name: 'Alice'),
      lastMessage: 'Hello',
      unreadCount: 2,
    ),
    ChatContact(
      id: 'c2',
      user: const UserBrief(id: 'u2', name: 'Bob'),
      lastMessage: 'Hi',
      unreadCount: 0,
    ),
  ];

  final testTaskChats = [
    TaskChat(
      taskId: 1,
      taskTitle: 'Task A',
      participants: const [UserBrief(id: 'u1', name: 'Alice')],
      lastMessage: 'Task msg 1',
      unreadCount: 3,
      lastMessageTime: DateTime(2026, 3, 8, 10, 0),
    ),
    TaskChat(
      taskId: 2,
      taskTitle: 'Task B',
      participants: const [UserBrief(id: 'u2', name: 'Bob')],
      lastMessage: 'Task msg 2',
      unreadCount: 1,
      lastMessageTime: DateTime(2026, 3, 8, 9, 0),
    ),
  ];

  final moreTaskChats = [
    TaskChat(
      taskId: 3,
      taskTitle: 'Task C',
      participants: const [UserBrief(id: 'u3', name: 'Charlie')],
      lastMessage: 'Task msg 3',
      unreadCount: 0,
      lastMessageTime: DateTime(2026, 3, 7),
    ),
  ];

  setUp(() {
    mockMessageRepository = MockMessageRepository();
    messageBloc = MessageBloc(messageRepository: mockMessageRepository);
  });

  tearDown(() {
    messageBloc.close();
  });

  group('MessageBloc', () {
    // ==================== Initial State ====================

    test('initial state is correct', () {
      expect(messageBloc.state.status, equals(MessageStatus.initial));
      expect(messageBloc.state.contacts, isEmpty);
      expect(messageBloc.state.taskChats, isEmpty);
      expect(messageBloc.state.taskChatUnreadFromApi, isNull);
      expect(messageBloc.state.errorMessage, isNull);
      expect(messageBloc.state.taskChatsPage, equals(1));
      expect(messageBloc.state.hasMoreTaskChats, isTrue);
      expect(messageBloc.state.isLoadingMore, isFalse);
      expect(messageBloc.state.isRefreshing, isFalse);
      expect(messageBloc.state.pinnedTaskIds, isEmpty);
      expect(messageBloc.state.hiddenTaskChats, isEmpty);
      expect(messageBloc.state.isLoading, isFalse);
      expect(messageBloc.state.totalUnread, equals(0));
      expect(messageBloc.state.taskChatUnreadForBadge, equals(0));
    });

    // ==================== MessageLoadContacts ====================

    group('MessageLoadContacts', () {
      blocTest<MessageBloc, MessageState>(
        'emits [loading, loaded] with contacts on success',
        build: () {
          when(() => mockMessageRepository.getContacts(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => testContacts);
          return messageBloc;
        },
        act: (bloc) => bloc.add(const MessageLoadContacts()),
        expect: () => [
          isA<MessageState>()
              .having((s) => s.status, 'status', MessageStatus.loading),
          isA<MessageState>()
              .having((s) => s.status, 'status', MessageStatus.loaded)
              .having(
                  (s) => s.contacts.length, 'contacts.length', 2),
        ],
        verify: (_) {
          verify(() => mockMessageRepository.getContacts()).called(1);
        },
      );

      blocTest<MessageBloc, MessageState>(
        'emits [loading, error] on failure',
        build: () {
          when(() => mockMessageRepository.getContacts(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenThrow(Exception('Network error'));
          return messageBloc;
        },
        act: (bloc) => bloc.add(const MessageLoadContacts()),
        expect: () => [
          isA<MessageState>()
              .having((s) => s.status, 'status', MessageStatus.loading),
          isA<MessageState>()
              .having((s) => s.status, 'status', MessageStatus.error)
              .having(
                  (s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );

      blocTest<MessageBloc, MessageState>(
        'does not emit when contacts already exist and returned same list',
        build: () {
          when(() => mockMessageRepository.getContacts(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => testContacts);
          return messageBloc;
        },
        seed: () => MessageState(
          status: MessageStatus.loaded,
          contacts: testContacts,
        ),
        act: (bloc) => bloc.add(const MessageLoadContacts()),
        // Skips loading (hasExistingData), then emits loaded with same
        // contacts → Equatable dedup → no emission.
        expect: () => [],
      );

      blocTest<MessageBloc, MessageState>(
        'skips when already loading',
        build: () => messageBloc,
        seed: () => const MessageState(status: MessageStatus.loading),
        act: (bloc) => bloc.add(const MessageLoadContacts()),
        expect: () => [],
      );
    });

    // ==================== MessageLoadTaskChats ====================

    group('MessageLoadTaskChats', () {
      blocTest<MessageBloc, MessageState>(
        'emits [loading, loaded] on success from initial (_loadPreferences deduped by Equatable)',
        build: () {
          when(() => mockMessageRepository.getTaskChats(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => testTaskChats);
          return messageBloc;
        },
        act: (bloc) => bloc.add(const MessageLoadTaskChats(forceRefresh: true)),
        expect: () => [
          // 1. loading status
          isA<MessageState>()
              .having((s) => s.status, 'status', MessageStatus.loading),
          // 2. loaded with task chats (_loadPreferences emits same defaults → Equatable dedup)
          isA<MessageState>()
              .having((s) => s.status, 'status', MessageStatus.loaded)
              .having((s) => s.taskChats.length, 'taskChats.length', 2)
              .having((s) => s.taskChatsPage, 'taskChatsPage', 1)
              .having((s) => s.taskChatUnreadFromApi, 'taskChatUnreadFromApi',
                  isNull), // cleared
        ],
        verify: (_) {
          verify(() => mockMessageRepository.getTaskChats()).called(1);
        },
      );

      blocTest<MessageBloc, MessageState>(
        'emits error on task chats load failure when not yet loaded',
        build: () {
          when(() => mockMessageRepository.getTaskChats(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenThrow(Exception('Failed'));
          return messageBloc;
        },
        act: (bloc) => bloc.add(const MessageLoadTaskChats(forceRefresh: true)),
        expect: () => [
          isA<MessageState>()
              .having((s) => s.status, 'status', MessageStatus.loading),
          isA<MessageState>()
              .having((s) => s.status, 'status', MessageStatus.error)
              .having(
                  (s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );

      blocTest<MessageBloc, MessageState>(
        'does not emit error when already loaded (silent failure)',
        build: () {
          when(() => mockMessageRepository.getTaskChats(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenThrow(Exception('Failed'));
          return messageBloc;
        },
        seed: () => MessageState(
          status: MessageStatus.loaded,
          taskChats: testTaskChats,
        ),
        act: (bloc) => bloc.add(const MessageLoadTaskChats(forceRefresh: true)),
        // _loadPreferences emits same defaults → Equatable dedup; error suppressed because already loaded
        expect: () => [],
      );
    });

    // ==================== MessageLoadMoreTaskChats ====================

    group('MessageLoadMoreTaskChats', () {
      blocTest<MessageBloc, MessageState>(
        'appends task chats and increments page on success',
        build: () {
          when(() => mockMessageRepository.getTaskChats(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => moreTaskChats);
          return messageBloc;
        },
        seed: () => MessageState(
          status: MessageStatus.loaded,
          taskChats: testTaskChats,
          taskChatsPage: 1,
          hasMoreTaskChats: true,
        ),
        act: (bloc) => bloc.add(const MessageLoadMoreTaskChats()),
        expect: () => [
          isA<MessageState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', true),
          isA<MessageState>()
              .having(
                  (s) => s.taskChats.length, 'taskChats.length', 3)
              .having((s) => s.taskChatsPage, 'taskChatsPage', 2)
              .having((s) => s.hasMoreTaskChats, 'hasMoreTaskChats',
                  false) // 1 < 20
              .having(
                  (s) => s.isLoadingMore, 'isLoadingMore', false),
        ],
        verify: (_) {
          verify(() => mockMessageRepository.getTaskChats(page: 2))
              .called(1);
        },
      );

      blocTest<MessageBloc, MessageState>(
        'does not emit when hasMoreTaskChats is false',
        build: () => messageBloc,
        seed: () => MessageState(
          status: MessageStatus.loaded,
          taskChats: testTaskChats,
          hasMoreTaskChats: false,
        ),
        act: (bloc) => bloc.add(const MessageLoadMoreTaskChats()),
        expect: () => [],
      );

      blocTest<MessageBloc, MessageState>(
        'does not emit when already loading more',
        build: () => messageBloc,
        seed: () => MessageState(
          status: MessageStatus.loaded,
          taskChats: testTaskChats,
          hasMoreTaskChats: true,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const MessageLoadMoreTaskChats()),
        expect: () => [],
      );

      blocTest<MessageBloc, MessageState>(
        'resets isLoadingMore on failure',
        build: () {
          when(() => mockMessageRepository.getTaskChats(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenThrow(Exception('Load more failed'));
          return messageBloc;
        },
        seed: () => MessageState(
          status: MessageStatus.loaded,
          taskChats: testTaskChats,
          taskChatsPage: 1,
          hasMoreTaskChats: true,
        ),
        act: (bloc) => bloc.add(const MessageLoadMoreTaskChats()),
        expect: () => [
          isA<MessageState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', true),
          isA<MessageState>()
              .having(
                  (s) => s.isLoadingMore, 'isLoadingMore', false),
        ],
      );
    });

    // ==================== MessageMarkTaskChatRead ====================

    group('MessageMarkTaskChatRead', () {
      blocTest<MessageBloc, MessageState>(
        'optimistically sets unreadCount to 0 for matching taskId',
        build: () {
          // markTaskChatRead is called async in background, mock it
          when(() => mockMessageRepository.markTaskChatRead(
                any(),
                uptoMessageId: any(named: 'uptoMessageId'),
                messageIds: any(named: 'messageIds'),
              )).thenAnswer((_) async {});
          return messageBloc;
        },
        seed: () => MessageState(
          status: MessageStatus.loaded,
          taskChats: testTaskChats,
        ),
        act: (bloc) => bloc.add(const MessageMarkTaskChatRead(1)),
        expect: () => [
          isA<MessageState>().having(
            (s) => s.taskChats.firstWhere((c) => c.taskId == 1).unreadCount,
            'taskId=1 unreadCount',
            0,
          ),
        ],
      );

      blocTest<MessageBloc, MessageState>(
        'does not emit when task chat is not found',
        build: () => messageBloc,
        seed: () => MessageState(
          status: MessageStatus.loaded,
          taskChats: testTaskChats,
        ),
        act: (bloc) => bloc.add(const MessageMarkTaskChatRead(999)),
        expect: () => [],
      );

      blocTest<MessageBloc, MessageState>(
        'does not emit when unreadCount is already 0',
        build: () => messageBloc,
        seed: () => MessageState(
          status: MessageStatus.loaded,
          taskChats: [
            TaskChat(
              taskId: 1,
              taskTitle: 'Task A',
              participants: const [],
              unreadCount: 0,
            ),
          ],
        ),
        act: (bloc) => bloc.add(const MessageMarkTaskChatRead(1)),
        expect: () => [],
      );
    });

    // ==================== MessageFetchUnreadCount ====================

    group('MessageFetchUnreadCount', () {
      blocTest<MessageBloc, MessageState>(
        'updates taskChatUnreadFromApi on success',
        build: () {
          when(() => mockMessageRepository.getTaskChatUnreadCount())
              .thenAnswer((_) async => 5);
          return messageBloc;
        },
        act: (bloc) => bloc.add(const MessageFetchUnreadCount()),
        expect: () => [
          isA<MessageState>().having(
            (s) => s.taskChatUnreadFromApi,
            'taskChatUnreadFromApi',
            5,
          ),
        ],
      );

      blocTest<MessageBloc, MessageState>(
        'does not emit on failure (silent catch)',
        build: () {
          when(() => mockMessageRepository.getTaskChatUnreadCount())
              .thenThrow(Exception('API error'));
          return messageBloc;
        },
        act: (bloc) => bloc.add(const MessageFetchUnreadCount()),
        expect: () => [],
      );
    });

    // ==================== MessageRefreshRequested ====================

    group('MessageRefreshRequested', () {
      blocTest<MessageBloc, MessageState>(
        'refreshes contacts and task chats on success',
        build: () {
          when(() => mockMessageRepository.getContacts(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => testContacts);
          when(() => mockMessageRepository.getTaskChats(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => testTaskChats);
          return messageBloc;
        },
        seed: () => const MessageState(status: MessageStatus.loaded),
        act: (bloc) => bloc.add(const MessageRefreshRequested()),
        expect: () => [
          // 1. isRefreshing = true
          isA<MessageState>()
              .having((s) => s.isRefreshing, 'isRefreshing', true),
          // 2. loaded with refreshed data (_loadPreferences deduped by Equatable)
          isA<MessageState>()
              .having((s) => s.status, 'status', MessageStatus.loaded)
              .having(
                  (s) => s.contacts.length, 'contacts.length', 2)
              .having(
                  (s) => s.taskChats.length, 'taskChats.length', 2)
              .having(
                  (s) => s.isRefreshing, 'isRefreshing', false)
              .having((s) => s.taskChatUnreadFromApi,
                  'taskChatUnreadFromApi', isNull),
        ],
      );

      blocTest<MessageBloc, MessageState>(
        'emits error with isRefreshing=false on failure',
        build: () {
          when(() => mockMessageRepository.getContacts(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenThrow(Exception('Refresh failed'));
          return messageBloc;
        },
        seed: () => const MessageState(status: MessageStatus.loaded),
        act: (bloc) => bloc.add(const MessageRefreshRequested()),
        expect: () => [
          isA<MessageState>()
              .having((s) => s.isRefreshing, 'isRefreshing', true),
          // _loadPreferences deduped by Equatable
          isA<MessageState>()
              .having((s) => s.status, 'status', MessageStatus.error)
              .having(
                  (s) => s.isRefreshing, 'isRefreshing', false)
              .having(
                  (s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    // ==================== MessageState ====================

    group('MessageState', () {
      test('totalUnread sums contacts and taskChats unread counts', () {
        final state = MessageState(
          contacts: testContacts,
          taskChats: testTaskChats,
        );
        // contacts: 2+0 = 2, taskChats: 3+1 = 4, total = 6
        expect(state.totalUnread, equals(6));
      });

      test('taskChatUnreadForBadge prefers API count when available', () {
        final state = MessageState(
          taskChats: testTaskChats,
          taskChatUnreadFromApi: 10,
        );
        expect(state.taskChatUnreadForBadge, equals(10));
      });

      test('taskChatUnreadForBadge falls back to list sum when API is null',
          () {
        final state = MessageState(
          taskChats: testTaskChats,
        );
        // taskChats: 3+1 = 4
        expect(state.taskChatUnreadForBadge, equals(4));
      });

      test('displayTaskChats filters hidden chats without new messages', () {
        final hiddenTime = DateTime(2026, 3, 8, 11, 0); // after last message
        final state = MessageState(
          taskChats: testTaskChats,
          hiddenTaskChats: {1: hiddenTime},
        );
        final display = state.displayTaskChats;
        // Task 1 was hidden at 11:00, last message at 10:00 — should be hidden
        expect(display.length, equals(1));
        expect(display.first.taskId, equals(2));
      });

      test('displayTaskChats shows hidden chat with new message after hide',
          () {
        final hiddenTime = DateTime(2026, 3, 8, 9, 0); // before last message
        final state = MessageState(
          taskChats: testTaskChats,
          hiddenTaskChats: {1: hiddenTime},
        );
        final display = state.displayTaskChats;
        // Task 1 hidden at 9:00, last message at 10:00 — should show
        expect(display.length, equals(2));
      });

      test('displayTaskChats sorts pinned chats first', () {
        final state = MessageState(
          taskChats: testTaskChats,
          pinnedTaskIds: {2},
        );
        final display = state.displayTaskChats;
        // Task 2 is pinned, should be first
        expect(display.first.taskId, equals(2));
        expect(display.last.taskId, equals(1));
      });

      test('displayTaskChats sorts by lastMessageTime within same group', () {
        final state = MessageState(
          taskChats: testTaskChats,
          // No pinned — both in unpinned group, sorted by time descending
        );
        final display = state.displayTaskChats;
        // Task 1: 10:00, Task 2: 9:00 — Task 1 first
        expect(display.first.taskId, equals(1));
        expect(display.last.taskId, equals(2));
      });

      test('isLoading returns true when status is loading', () {
        const state = MessageState(status: MessageStatus.loading);
        expect(state.isLoading, isTrue);
      });

      test('isLoading returns false when status is not loading', () {
        const state = MessageState(status: MessageStatus.loaded);
        expect(state.isLoading, isFalse);
      });

      test('copyWith preserves values by default', () {
        final state = MessageState(
          status: MessageStatus.loaded,
          contacts: testContacts,
          taskChats: testTaskChats,
          taskChatUnreadFromApi: 5,
          taskChatsPage: 2,
          hasMoreTaskChats: false,
          isLoadingMore: true,
          isRefreshing: true,
          pinnedTaskIds: const {1, 2},
          hiddenTaskChats: {1: DateTime(2026)},
        );
        final copy = state.copyWith();
        expect(copy.status, state.status);
        expect(copy.contacts, state.contacts);
        expect(copy.taskChats, state.taskChats);
        expect(copy.taskChatUnreadFromApi, state.taskChatUnreadFromApi);
        // errorMessage uses direct assignment — not passed means null
        expect(copy.errorMessage, isNull);
        expect(copy.taskChatsPage, state.taskChatsPage);
        expect(copy.hasMoreTaskChats, state.hasMoreTaskChats);
        expect(copy.isLoadingMore, state.isLoadingMore);
        expect(copy.isRefreshing, state.isRefreshing);
        expect(copy.pinnedTaskIds, state.pinnedTaskIds);
        expect(copy.hiddenTaskChats, state.hiddenTaskChats);
      });

      test('copyWith clearTaskChatUnreadFromApi sets value to null', () {
        const state = MessageState(taskChatUnreadFromApi: 5);
        final copy = state.copyWith(clearTaskChatUnreadFromApi: true);
        expect(copy.taskChatUnreadFromApi, isNull);
      });

      test('Equatable: states with same props are equal', () {
        const state1 = MessageState(
          status: MessageStatus.loaded,
          taskChatsPage: 2,
        );
        const state2 = MessageState(
          status: MessageStatus.loaded,
          taskChatsPage: 2,
        );
        expect(state1, equals(state2));
      });
    });

    // ==================== Event equality ====================

    group('MessageEvent equality', () {
      test('MessageLoadContacts instances are equal', () {
        const event1 = MessageLoadContacts();
        const event2 = MessageLoadContacts();
        expect(event1, equals(event2));
      });

      test('MessageLoadTaskChats with same forceRefresh are equal', () {
        const event1 = MessageLoadTaskChats(forceRefresh: true);
        const event2 = MessageLoadTaskChats(forceRefresh: true);
        expect(event1, equals(event2));
      });

      test('MessageLoadTaskChats with different forceRefresh are not equal',
          () {
        const event1 = MessageLoadTaskChats(forceRefresh: true);
        const event2 = MessageLoadTaskChats(forceRefresh: false);
        expect(event1, isNot(equals(event2)));
      });

      test('MessageLoadMoreTaskChats instances are equal', () {
        const event1 = MessageLoadMoreTaskChats();
        const event2 = MessageLoadMoreTaskChats();
        expect(event1, equals(event2));
      });

      test('MessageRefreshRequested instances are equal', () {
        const event1 = MessageRefreshRequested();
        const event2 = MessageRefreshRequested();
        expect(event1, equals(event2));
      });

      test('MessagePinTaskChat with same taskId are equal', () {
        const event1 = MessagePinTaskChat(1);
        const event2 = MessagePinTaskChat(1);
        expect(event1, equals(event2));
      });

      test('MessagePinTaskChat with different taskId are not equal', () {
        const event1 = MessagePinTaskChat(1);
        const event2 = MessagePinTaskChat(2);
        expect(event1, isNot(equals(event2)));
      });

      test('MessageUnpinTaskChat with same taskId are equal', () {
        const event1 = MessageUnpinTaskChat(1);
        const event2 = MessageUnpinTaskChat(1);
        expect(event1, equals(event2));
      });

      test('MessageHideTaskChat with same taskId are equal', () {
        const event1 = MessageHideTaskChat(1);
        const event2 = MessageHideTaskChat(1);
        expect(event1, equals(event2));
      });

      test('MessageMarkTaskChatRead with same taskId are equal', () {
        const event1 = MessageMarkTaskChatRead(1);
        const event2 = MessageMarkTaskChatRead(1);
        expect(event1, equals(event2));
      });

      test('MessageStartPolling instances are equal', () {
        const event1 = MessageStartPolling();
        const event2 = MessageStartPolling();
        expect(event1, equals(event2));
      });

      test('MessageStopPolling instances are equal', () {
        const event1 = MessageStopPolling();
        const event2 = MessageStopPolling();
        expect(event1, equals(event2));
      });

      test('MessageFetchUnreadCount instances are equal', () {
        const event1 = MessageFetchUnreadCount();
        const event2 = MessageFetchUnreadCount();
        expect(event1, equals(event2));
      });
    });
  });
}
