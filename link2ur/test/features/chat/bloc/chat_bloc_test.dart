import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/chat/bloc/chat_bloc.dart';
import 'package:link2ur/data/models/message.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  late MockMessageRepository mockMessageRepository;
  late ChatBloc chatBloc;

  // Test messages for private chat (old → new order)
  final testMessages = [
    const Message(
      id: 1,
      senderId: 'user2',
      receiverId: 'user1',
      content: 'Hello',
      createdAt: null,
    ),
    const Message(
      id: 2,
      senderId: 'user1',
      receiverId: 'user2',
      content: 'Hi there',
      createdAt: null,
    ),
    const Message(
      id: 3,
      senderId: 'user2',
      receiverId: 'user1',
      content: 'How are you?',
      createdAt: null,
    ),
  ];

  // Test messages for task chat (new → old order)
  final taskMessages = [
    const Message(
      id: 10,
      senderId: 'user1',
      content: 'Latest task message',
      taskId: 42,
    ),
    const Message(
      id: 9,
      senderId: 'user2',
      content: 'Older task message',
      taskId: 42,
    ),
  ];

  // Sent message returned from server
  const sentMessage = Message(
    id: 100,
    senderId: 'user1',
    receiverId: 'user2',
    content: 'New message',
    messageType: 'text',
  );

  // Sent task message returned from server
  const sentTaskMessage = Message(
    id: 101,
    senderId: 'user1',
    content: 'Task message sent',
    messageType: 'text',
    taskId: 42,
  );

  setUp(() {
    mockMessageRepository = MockMessageRepository();
    chatBloc = ChatBloc(messageRepository: mockMessageRepository);

    // Register fallback values for mocktail
    registerFallbackValue(const SendMessageRequest(
      receiverId: '',
      content: '',
    ));
  });

  tearDown(() {
    chatBloc.close();
  });

  group('ChatBloc', () {
    // ==================== Initial State ====================

    test('initial state is correct', () {
      expect(chatBloc.state.status, equals(ChatStatus.initial));
      expect(chatBloc.state.messages, isEmpty);
      expect(chatBloc.state.userId, equals(''));
      expect(chatBloc.state.taskId, isNull);
      expect(chatBloc.state.taskStatus, isNull);
      expect(chatBloc.state.page, equals(1));
      expect(chatBloc.state.hasMore, isTrue);
      expect(chatBloc.state.nextCursor, isNull);
      expect(chatBloc.state.isSending, isFalse);
      expect(chatBloc.state.isLoadingMore, isFalse);
      expect(chatBloc.state.errorMessage, isNull);
      expect(chatBloc.state.peerIsTyping, isFalse);
      expect(chatBloc.state.isTaskChat, isFalse);
      expect(chatBloc.state.isTaskClosed, isFalse);
    });

    // ==================== ChatLoadMessages ====================

    group('ChatLoadMessages', () {
      blocTest<ChatBloc, ChatState>(
        'emits [loading, loaded] and triggers ChatMarkAsRead on private chat success',
        build: () {
          when(() => mockMessageRepository.getMessagesWith(
                any(),
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => testMessages);
          when(() => mockMessageRepository.markMessagesRead(any()))
              .thenAnswer((_) async {});
          return chatBloc;
        },
        act: (bloc) => bloc.add(const ChatLoadMessages(userId: 'user2')),
        expect: () => [
          isA<ChatState>()
              .having((s) => s.status, 'status', ChatStatus.loading)
              .having((s) => s.userId, 'userId', 'user2')
              .having((s) => s.taskId, 'taskId', isNull),
          isA<ChatState>()
              .having((s) => s.status, 'status', ChatStatus.loaded)
              .having((s) => s.messages, 'messages', testMessages)
              .having((s) => s.page, 'page', 1)
              .having(
                  (s) => s.hasMore, 'hasMore', false), // 3 < 50
        ],
        verify: (_) {
          verify(() => mockMessageRepository.getMessagesWith('user2')).called(1);
          // ChatMarkAsRead triggers markMessagesRead
          verify(() => mockMessageRepository.markMessagesRead('user2')).called(1);
        },
      );

      blocTest<ChatBloc, ChatState>(
        'emits [loading, loaded] on task chat success with taskId',
        build: () {
          when(() => mockMessageRepository.getTaskChatMessages(
                any(),
                limit: any(named: 'limit'),
                cursor: any(named: 'cursor'),
              )).thenAnswer((_) async => (
                messages: taskMessages,
                nextCursor: 'cursor_abc',
                hasMore: true,
                taskStatus: 'in_progress',
              ));
          when(() => mockMessageRepository.markTaskChatRead(
                any(),
                uptoMessageId: any(named: 'uptoMessageId'),
                messageIds: any(named: 'messageIds'),
              )).thenAnswer((_) async {});
          return chatBloc;
        },
        act: (bloc) => bloc.add(const ChatLoadMessages(
          userId: 'user2',
          taskId: 42,
        )),
        expect: () => [
          isA<ChatState>()
              .having((s) => s.status, 'status', ChatStatus.loading)
              .having((s) => s.userId, 'userId', 'user2')
              .having((s) => s.taskId, 'taskId', 42),
          isA<ChatState>()
              .having((s) => s.status, 'status', ChatStatus.loaded)
              .having((s) => s.messages, 'messages', taskMessages)
              .having((s) => s.hasMore, 'hasMore', true)
              .having((s) => s.nextCursor, 'nextCursor', 'cursor_abc')
              .having((s) => s.taskStatus, 'taskStatus', 'in_progress'),
        ],
        verify: (_) {
          verify(() => mockMessageRepository.getTaskChatMessages(42)).called(1);
        },
      );

      blocTest<ChatBloc, ChatState>(
        'emits [loading, error] on failure',
        build: () {
          when(() => mockMessageRepository.getMessagesWith(
                any(),
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenThrow(Exception('Network error'));
          return chatBloc;
        },
        act: (bloc) => bloc.add(const ChatLoadMessages(userId: 'user2')),
        expect: () => [
          isA<ChatState>()
              .having((s) => s.status, 'status', ChatStatus.loading),
          isA<ChatState>()
              .having((s) => s.status, 'status', ChatStatus.error)
              .having(
                  (s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    // ==================== ChatLoadMore ====================

    group('ChatLoadMore', () {
      blocTest<ChatBloc, ChatState>(
        'appends messages on private chat load more success',
        build: () {
          final moreMessages = [
            const Message(
              id: 4,
              senderId: 'user2',
              receiverId: 'user1',
              content: 'Older message',
            ),
          ];
          when(() => mockMessageRepository.getMessagesWith(
                any(),
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => moreMessages);
          return chatBloc;
        },
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: testMessages,
          userId: 'user2',
          page: 1,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const ChatLoadMore()),
        expect: () => [
          isA<ChatState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', true),
          isA<ChatState>()
              .having((s) => s.messages.length, 'messages.length', 4)
              .having((s) => s.page, 'page', 2)
              .having(
                  (s) => s.hasMore, 'hasMore', false) // 1 < 50
              .having((s) => s.isLoadingMore, 'isLoadingMore', false),
        ],
        verify: (_) {
          verify(() => mockMessageRepository.getMessagesWith(
                'user2',
                page: 2,
              )).called(1);
        },
      );

      blocTest<ChatBloc, ChatState>(
        'uses cursor pagination for task chat load more',
        build: () {
          final olderTaskMessages = [
            const Message(
              id: 8,
              senderId: 'user1',
              content: 'Even older',
              taskId: 42,
            ),
          ];
          when(() => mockMessageRepository.getTaskChatMessages(
                any(),
                limit: any(named: 'limit'),
                cursor: any(named: 'cursor'),
              )).thenAnswer((_) async => (
                messages: olderTaskMessages,
                nextCursor: null,
                hasMore: false,
                taskStatus: 'in_progress',
              ));
          return chatBloc;
        },
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: taskMessages,
          userId: 'user2',
          taskId: 42,
          taskStatus: 'in_progress',
          hasMore: true,
          nextCursor: 'cursor_abc',
        ),
        act: (bloc) => bloc.add(const ChatLoadMore()),
        expect: () => [
          isA<ChatState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', true),
          isA<ChatState>()
              .having((s) => s.messages.length, 'messages.length', 3)
              .having((s) => s.hasMore, 'hasMore', false)
              // copyWith preserves old nextCursor when null is passed
              .having((s) => s.isLoadingMore, 'isLoadingMore', false),
        ],
        verify: (_) {
          verify(() => mockMessageRepository.getTaskChatMessages(
                42,
                cursor: 'cursor_abc',
              )).called(1);
        },
      );

      blocTest<ChatBloc, ChatState>(
        'does not emit when hasMore is false',
        build: () => chatBloc,
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: testMessages,
          userId: 'user2',
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const ChatLoadMore()),
        expect: () => [],
      );

      blocTest<ChatBloc, ChatState>(
        'does not emit when already loading more',
        build: () => chatBloc,
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: testMessages,
          userId: 'user2',
          hasMore: true,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const ChatLoadMore()),
        expect: () => [],
      );

      blocTest<ChatBloc, ChatState>(
        'sets hasMore to false when task chat nextCursor is null/empty',
        build: () => chatBloc,
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: taskMessages,
          userId: 'user2',
          taskId: 42,
          hasMore: true,
          nextCursor: null,
        ),
        act: (bloc) => bloc.add(const ChatLoadMore()),
        expect: () => [
          isA<ChatState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', true),
          isA<ChatState>()
              .having((s) => s.hasMore, 'hasMore', false)
              .having((s) => s.isLoadingMore, 'isLoadingMore', false),
        ],
      );
    });

    // ==================== ChatSendMessage ====================

    group('ChatSendMessage', () {
      blocTest<ChatBloc, ChatState>(
        'optimistic update + server replace on private chat with senderId',
        build: () {
          when(() => mockMessageRepository.sendMessage(any()))
              .thenAnswer((_) async => sentMessage);
          return chatBloc;
        },
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: testMessages,
          userId: 'user2',
        ),
        act: (bloc) => bloc.add(const ChatSendMessage(
          content: 'New message',
          senderId: 'user1',
        )),
        expect: () => [
          // 1. Optimistic update: pending message appended (private chat: end)
          isA<ChatState>()
              .having((s) => s.isSending, 'isSending', true)
              .having(
                  (s) => s.messages.length, 'messages.length', 4)
              .having((s) => s.messages.last.content, 'last content',
                  'New message')
              .having(
                  (s) => s.messages.last.id, 'last id (negative)', isNegative),
          // 2. Server response replaces pending message
          isA<ChatState>()
              .having((s) => s.isSending, 'isSending', false)
              .having(
                  (s) => s.messages.length, 'messages.length', 4)
              .having(
                  (s) => s.messages.last, 'last message', sentMessage),
        ],
        verify: (_) {
          verify(() => mockMessageRepository.sendMessage(any())).called(1);
        },
      );

      blocTest<ChatBloc, ChatState>(
        'removes pending message and shows error on private chat send failure',
        build: () {
          when(() => mockMessageRepository.sendMessage(any()))
              .thenThrow(Exception('Send failed'));
          return chatBloc;
        },
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: testMessages,
          userId: 'user2',
        ),
        act: (bloc) => bloc.add(const ChatSendMessage(
          content: 'Will fail',
          senderId: 'user1',
        )),
        expect: () => [
          // 1. Optimistic update adds pending
          isA<ChatState>()
              .having((s) => s.isSending, 'isSending', true)
              .having((s) => s.messages.length, 'messages.length', 4),
          // 2. Failure removes pending, shows error
          isA<ChatState>()
              .having((s) => s.isSending, 'isSending', false)
              .having((s) => s.messages.length, 'messages.length', 3)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );

      blocTest<ChatBloc, ChatState>(
        'optimistic update inserts at head for task chat',
        build: () {
          when(() => mockMessageRepository.sendTaskChatMessage(
                any(),
                content: any(named: 'content'),
                messageType: any(named: 'messageType'),
                attachments: any(named: 'attachments'),
              )).thenAnswer((_) async => sentTaskMessage);
          return chatBloc;
        },
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: taskMessages,
          userId: 'user2',
          taskId: 42,
          taskStatus: 'in_progress',
        ),
        act: (bloc) => bloc.add(const ChatSendMessage(
          content: 'Task message sent',
          senderId: 'user1',
        )),
        expect: () => [
          // 1. Optimistic: pending message inserted at head (task chat: new→old)
          isA<ChatState>()
              .having((s) => s.isSending, 'isSending', true)
              .having(
                  (s) => s.messages.length, 'messages.length', 3)
              .having((s) => s.messages.first.content, 'first content',
                  'Task message sent')
              .having((s) => s.messages.first.id, 'first id (negative)',
                  isNegative),
          // 2. Server response replaces pending
          isA<ChatState>()
              .having((s) => s.isSending, 'isSending', false)
              .having(
                  (s) => s.messages.length, 'messages.length', 3)
              .having(
                  (s) => s.messages.first, 'first message', sentTaskMessage),
        ],
        verify: (_) {
          verify(() => mockMessageRepository.sendTaskChatMessage(
                42,
                content: 'Task message sent',
                messageType: 'text',
              )).called(1);
        },
      );

      blocTest<ChatBloc, ChatState>(
        'sends without optimistic update when senderId is null',
        build: () {
          when(() => mockMessageRepository.sendMessage(any()))
              .thenAnswer((_) async => sentMessage);
          return chatBloc;
        },
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: testMessages,
          userId: 'user2',
        ),
        act: (bloc) => bloc.add(const ChatSendMessage(
          content: 'New message',
          // senderId is null — no optimistic update
        )),
        expect: () => [
          // 1. Just isSending=true, no new message yet
          isA<ChatState>()
              .having((s) => s.isSending, 'isSending', true)
              .having(
                  (s) => s.messages.length, 'messages.length', 3),
          // 2. Server response appended to end (private chat)
          isA<ChatState>()
              .having((s) => s.isSending, 'isSending', false)
              .having(
                  (s) => s.messages.length, 'messages.length', 4)
              .having(
                  (s) => s.messages.last, 'last message', sentMessage),
        ],
      );
    });

    // ==================== ChatMessageReceived ====================

    group('ChatMessageReceived', () {
      blocTest<ChatBloc, ChatState>(
        'adds message to private chat when from relevant user',
        build: () {
          // ChatMarkAsRead triggered after receive
          when(() => mockMessageRepository.markMessagesRead(any()))
              .thenAnswer((_) async {});
          return chatBloc;
        },
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: testMessages,
          userId: 'user2',
        ),
        act: (bloc) => bloc.add(const ChatMessageReceived(
          Message(
            id: 50,
            senderId: 'user2',
            receiverId: 'user1',
            content: 'New incoming',
          ),
        )),
        expect: () => [
          isA<ChatState>()
              .having(
                  (s) => s.messages.length, 'messages.length', 4)
              .having(
                  (s) => s.messages.last.id, 'last message id', 50),
        ],
      );

      blocTest<ChatBloc, ChatState>(
        'does not emit for duplicate message (deduplication)',
        build: () => chatBloc,
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: testMessages,
          userId: 'user2',
        ),
        act: (bloc) => bloc.add(ChatMessageReceived(testMessages.first)),
        expect: () => [],
      );

      blocTest<ChatBloc, ChatState>(
        'inserts at head for task chat message with matching taskId',
        build: () {
          when(() => mockMessageRepository.markTaskChatRead(
                any(),
                uptoMessageId: any(named: 'uptoMessageId'),
                messageIds: any(named: 'messageIds'),
              )).thenAnswer((_) async {});
          return chatBloc;
        },
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: taskMessages,
          userId: 'user2',
          taskId: 42,
        ),
        act: (bloc) => bloc.add(const ChatMessageReceived(
          Message(
            id: 50,
            senderId: 'user2',
            content: 'New task message',
            taskId: 42,
          ),
        )),
        expect: () => [
          isA<ChatState>()
              .having(
                  (s) => s.messages.length, 'messages.length', 3)
              .having(
                  (s) => s.messages.first.id, 'first message id', 50),
        ],
      );

      blocTest<ChatBloc, ChatState>(
        'ignores task chat message with non-matching taskId',
        build: () => chatBloc,
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: taskMessages,
          userId: 'user2',
          taskId: 42,
        ),
        act: (bloc) => bloc.add(const ChatMessageReceived(
          Message(
            id: 50,
            senderId: 'user2',
            content: 'Wrong task',
            taskId: 99,
          ),
        )),
        expect: () => [],
      );

      blocTest<ChatBloc, ChatState>(
        'ignores private chat message from unrelated user',
        build: () => chatBloc,
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: testMessages,
          userId: 'user2',
        ),
        act: (bloc) => bloc.add(const ChatMessageReceived(
          Message(
            id: 50,
            senderId: 'user999',
            receiverId: 'user888',
            content: 'Not for this chat',
          ),
        )),
        expect: () => [],
      );
    });

    // ==================== ChatClearError ====================

    group('ChatClearError', () {
      blocTest<ChatBloc, ChatState>(
        'clears errorMessage',
        build: () => chatBloc,
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: testMessages,
          userId: 'user2',
          errorMessage: 'Some error',
        ),
        act: (bloc) => bloc.add(const ChatClearError()),
        expect: () => [
          isA<ChatState>()
              .having((s) => s.errorMessage, 'errorMessage', isNull),
        ],
      );
    });

    // ==================== ChatPeerTypingReceived ====================

    group('ChatPeerTypingReceived', () {
      blocTest<ChatBloc, ChatState>(
        'sets peerIsTyping to true for private chat when from userId',
        build: () => chatBloc,
        seed: () => const ChatState(
          status: ChatStatus.loaded,
          userId: 'user2',
        ),
        act: (bloc) => bloc.add(const ChatPeerTypingReceived('user2')),
        expect: () => [
          isA<ChatState>()
              .having((s) => s.peerIsTyping, 'peerIsTyping', true),
        ],
      );

      blocTest<ChatBloc, ChatState>(
        'ignores typing from non-peer user in private chat',
        build: () => chatBloc,
        seed: () => const ChatState(
          status: ChatStatus.loaded,
          userId: 'user2',
        ),
        act: (bloc) => bloc.add(const ChatPeerTypingReceived('user999')),
        expect: () => [],
      );

      blocTest<ChatBloc, ChatState>(
        'accepts typing from any participant in task chat',
        build: () => chatBloc,
        seed: () => const ChatState(
          status: ChatStatus.loaded,
          userId: 'user2',
          taskId: 42,
        ),
        act: (bloc) =>
            bloc.add(const ChatPeerTypingReceived('any_participant')),
        expect: () => [
          isA<ChatState>()
              .having((s) => s.peerIsTyping, 'peerIsTyping', true),
        ],
      );
    });

    // ==================== ChatReadReceiptReceived ====================

    group('ChatReadReceiptReceived', () {
      blocTest<ChatBloc, ChatState>(
        'processes read receipt from peer in private chat (isRead not in Message.props)',
        build: () => chatBloc,
        seed: () => ChatState(
          status: ChatStatus.loaded,
          userId: 'user2',
          messages: [
            const Message(
              id: 1,
              senderId: 'user1',
              receiverId: 'user2',
              content: 'Hello',
              isRead: false,
            ),
            const Message(
              id: 2,
              senderId: 'user2',
              receiverId: 'user1',
              content: 'Hi',
              isRead: false,
            ),
          ],
        ),
        act: (bloc) => bloc.add(const ChatReadReceiptReceived('user2')),
        // Message.props = [id, senderId, receiverId, content, createdAt]
        // isRead is NOT in props, so copyWith(isRead: true) produces an
        // Equatable-equal Message → ChatState unchanged → no emission.
        expect: () => [],
      );

      blocTest<ChatBloc, ChatState>(
        'does not emit when receipt is from non-peer in private chat',
        build: () => chatBloc,
        seed: () => ChatState(
          status: ChatStatus.loaded,
          userId: 'user2',
          messages: [
            const Message(
              id: 1,
              senderId: 'user1',
              receiverId: 'user2',
              content: 'Hello',
              isRead: false,
            ),
          ],
        ),
        act: (bloc) => bloc.add(const ChatReadReceiptReceived('user999')),
        expect: () => [],
      );

      blocTest<ChatBloc, ChatState>(
        'marks non-sender messages as read in task chat',
        build: () => chatBloc,
        seed: () => const ChatState(
          status: ChatStatus.loaded,
          userId: 'user2',
          taskId: 42,
          messages: [
            // user1's message — not from receipt sender (user3), should be marked read
            Message(
              id: 1,
              senderId: 'user1',
              content: 'Task msg',
              isRead: false,
              taskId: 42,
            ),
            // user3's message — from receipt sender, should stay unread
            Message(
              id: 2,
              senderId: 'user3',
              content: 'Another msg',
              isRead: false,
              taskId: 42,
            ),
          ],
        ),
        act: (bloc) => bloc.add(const ChatReadReceiptReceived('user3')),
        // Message.props doesn't include isRead, so the updated messages
        // are Equatable-equal to the seed → no emission.
        expect: () => [],
      );
    });

    // ==================== ChatMarkAsRead ====================

    group('ChatMarkAsRead', () {
      blocTest<ChatBloc, ChatState>(
        'calls markMessagesRead for private chat',
        build: () {
          when(() => mockMessageRepository.markMessagesRead(any()))
              .thenAnswer((_) async {});
          return chatBloc;
        },
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: testMessages,
          userId: 'user2',
        ),
        act: (bloc) => bloc.add(const ChatMarkAsRead()),
        expect: () => [],
        verify: (_) {
          verify(() => mockMessageRepository.markMessagesRead('user2'))
              .called(1);
        },
      );

      blocTest<ChatBloc, ChatState>(
        'calls markTaskChatRead with latest message id for task chat',
        build: () {
          when(() => mockMessageRepository.markTaskChatRead(
                any(),
                uptoMessageId: any(named: 'uptoMessageId'),
                messageIds: any(named: 'messageIds'),
              )).thenAnswer((_) async {});
          return chatBloc;
        },
        seed: () => ChatState(
          status: ChatStatus.loaded,
          messages: taskMessages,
          userId: 'user2',
          taskId: 42,
        ),
        act: (bloc) => bloc.add(const ChatMarkAsRead()),
        expect: () => [],
        verify: (_) {
          // messages[0].id is 10 (latest, since task chat is new→old)
          verify(() => mockMessageRepository.markTaskChatRead(
                42,
                uptoMessageId: 10,
              )).called(1);
        },
      );
    });

    // ==================== ChatState ====================

    group('ChatState', () {
      test('isTaskChat returns true when taskId is set', () {
        const state = ChatState(taskId: 42);
        expect(state.isTaskChat, isTrue);
      });

      test('isTaskChat returns false when taskId is null', () {
        const state = ChatState();
        expect(state.isTaskChat, isFalse);
      });

      test('isTaskClosed returns true for completed status', () {
        const state = ChatState(taskStatus: 'completed');
        expect(state.isTaskClosed, isTrue);
      });

      test('isTaskClosed returns true for cancelled status', () {
        const state = ChatState(taskStatus: 'cancelled');
        expect(state.isTaskClosed, isTrue);
      });

      test('isTaskClosed returns true for expired status', () {
        const state = ChatState(taskStatus: 'expired');
        expect(state.isTaskClosed, isTrue);
      });

      test('isTaskClosed returns true for closed status', () {
        const state = ChatState(taskStatus: 'closed');
        expect(state.isTaskClosed, isTrue);
      });

      test('isTaskClosed returns false for in_progress status', () {
        const state = ChatState(taskStatus: 'in_progress');
        expect(state.isTaskClosed, isFalse);
      });

      test('isTaskClosed returns false when taskStatus is null', () {
        const state = ChatState();
        expect(state.isTaskClosed, isFalse);
      });

      test('copyWith preserves values when no arguments provided', () {
        final state = ChatState(
          status: ChatStatus.loaded,
          messages: testMessages,
          userId: 'user2',
          taskId: 42,
          taskStatus: 'in_progress',
          page: 2,
          hasMore: false,
          nextCursor: 'abc',
          isSending: true,
          isLoadingMore: true,
          errorMessage: 'error',
          peerIsTyping: true,
        );
        // Note: copyWith without errorMessage resets it to null
        final copy = state.copyWith();
        expect(copy.status, state.status);
        expect(copy.messages, state.messages);
        expect(copy.userId, state.userId);
        expect(copy.taskId, state.taskId);
        expect(copy.taskStatus, state.taskStatus);
        expect(copy.page, state.page);
        expect(copy.hasMore, state.hasMore);
        expect(copy.nextCursor, state.nextCursor);
        expect(copy.isSending, state.isSending);
        expect(copy.isLoadingMore, state.isLoadingMore);
        // errorMessage uses direct assignment in copyWith: errorMessage: errorMessage
        // When not passed, it becomes null
        expect(copy.errorMessage, isNull);
        expect(copy.peerIsTyping, state.peerIsTyping);
      });

      test('Equatable: states with same props are equal', () {
        const state1 = ChatState(
          status: ChatStatus.loaded,
          userId: 'user2',
        );
        const state2 = ChatState(
          status: ChatStatus.loaded,
          userId: 'user2',
        );
        expect(state1, equals(state2));
      });
    });

    // ==================== Event equality ====================

    group('ChatEvent equality', () {
      test('ChatLoadMessages with same props are equal', () {
        const event1 = ChatLoadMessages(userId: 'u1', taskId: 42);
        const event2 = ChatLoadMessages(userId: 'u1', taskId: 42);
        expect(event1, equals(event2));
      });

      test('ChatLoadMessages with different props are not equal', () {
        const event1 = ChatLoadMessages(userId: 'u1', taskId: 42);
        const event2 = ChatLoadMessages(userId: 'u1', taskId: 99);
        expect(event1, isNot(equals(event2)));
      });

      test('ChatSendMessage with same props are equal', () {
        const event1 =
            ChatSendMessage(content: 'hi', senderId: 'u1');
        const event2 =
            ChatSendMessage(content: 'hi', senderId: 'u1');
        expect(event1, equals(event2));
      });

      test('ChatMessageReceived with same message are equal', () {
        const msg = Message(id: 1, senderId: 's', content: 'c');
        const event1 = ChatMessageReceived(msg);
        const event2 = ChatMessageReceived(msg);
        expect(event1, equals(event2));
      });

      test('ChatLoadMore instances are equal', () {
        const event1 = ChatLoadMore();
        const event2 = ChatLoadMore();
        expect(event1, equals(event2));
      });

      test('ChatClearError instances are equal', () {
        const event1 = ChatClearError();
        const event2 = ChatClearError();
        expect(event1, equals(event2));
      });

      test('ChatPeerTypingReceived with same senderId are equal', () {
        const event1 = ChatPeerTypingReceived('u1');
        const event2 = ChatPeerTypingReceived('u1');
        expect(event1, equals(event2));
      });

      test('ChatReadReceiptReceived with same senderId are equal', () {
        const event1 = ChatReadReceiptReceived('u1');
        const event2 = ChatReadReceiptReceived('u1');
        expect(event1, equals(event2));
      });
    });
  });
}
