import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/ai_chat/bloc/unified_chat_bloc.dart';
import 'package:link2ur/features/ai_chat/bloc/ai_chat_bloc.dart';
import 'package:link2ur/data/services/ai_chat_service.dart';
import 'package:link2ur/data/models/ai_chat.dart';
import 'package:link2ur/data/models/customer_service.dart';

import '../../../helpers/test_helpers.dart';

class MockAIChatService extends Mock implements AIChatService {}

void main() {
  late MockAIChatService mockAIChatService;
  late MockCommonRepository mockCommonRepo;

  setUp(() {
    mockAIChatService = MockAIChatService();
    mockCommonRepo = MockCommonRepository();
  });

  UnifiedChatBloc buildBloc() {
    return UnifiedChatBloc(
      aiChatService: mockAIChatService,
      commonRepository: mockCommonRepo,
    );
  }

  group('UnifiedChatBloc', () {
    // ==================== Initial State ====================

    test('initial state is correct', () {
      final bloc = buildBloc();
      addTearDown(() => bloc.close());

      expect(bloc.state.mode, equals(ChatMode.ai));
      expect(bloc.state.aiMessages, isEmpty);
      expect(bloc.state.csMessages, isEmpty);
      expect(bloc.state.isTyping, isFalse);
      expect(bloc.state.streamingContent, equals(''));
      expect(bloc.state.activeToolCall, isNull);
      expect(bloc.state.taskDraft, isNull);
      expect(bloc.state.csOnlineStatus, isNull);
      expect(bloc.state.csContactEmail, isNull);
      expect(bloc.state.csServiceName, isNull);
      expect(bloc.state.csChatId, isNull);
      expect(bloc.state.errorMessage, isNull);
      expect(bloc.state.actionMessage, isNull);
      expect(bloc.state.isRating, isFalse);
    });

    // ==================== UnifiedChatInit ====================

    group('UnifiedChatInit', () {
      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'dispatches to AI sub-bloc, updates state when conversation created',
        build: () {
          when(() => mockAIChatService.createConversation())
              .thenAnswer((_) async => const AIConversation(id: 'conv-1'));
          return buildBloc();
        },
        act: (bloc) => bloc.add(const UnifiedChatInit()),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // AI sub-bloc emits state with currentConversationId set;
          // that propagates to unified state via _AIStateChanged.
          // The projected state should show empty aiMessages (new conversation).
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.ai)
              .having((s) => s.aiMessages, 'aiMessages', isEmpty),
        ],
        verify: (_) {
          verify(() => mockAIChatService.createConversation()).called(1);
        },
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'propagates error when createConversation fails',
        build: () {
          when(() => mockAIChatService.createConversation())
              .thenThrow(Exception('Network error'));
          return buildBloc();
        },
        act: (bloc) => bloc.add(const UnifiedChatInit()),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          isA<UnifiedChatState>()
              .having((s) => s.errorMessage, 'errorMessage',
                  'ai_chat_create_conversation_failed'),
        ],
      );
    });

    // ==================== UnifiedChatSendMessage ====================

    group('UnifiedChatSendMessage', () {
      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'does nothing when content is empty',
        build: () => buildBloc(),
        act: (bloc) => bloc.add(const UnifiedChatSendMessage('')),
        wait: const Duration(milliseconds: 100),
        expect: () => [],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'does nothing when content is only whitespace',
        build: () => buildBloc(),
        act: (bloc) => bloc.add(const UnifiedChatSendMessage('   ')),
        wait: const Duration(milliseconds: 100),
        expect: () => [],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'routes to AI sub-bloc in AI mode and updates state with user message',
        build: () {
          // First create a conversation so there is a currentConversationId
          when(() => mockAIChatService.createConversation())
              .thenAnswer((_) async => const AIConversation(id: 'conv-1'));
          // sendMessage returns a stream that immediately completes with done
          when(() => mockAIChatService.sendMessage('conv-1', 'Hello'))
              .thenAnswer((_) => Stream.fromIterable([
                    const AIChatEvent(
                      type: AIChatEventType.token,
                      content: 'Hi there',
                    ),
                    const AIChatEvent(
                      type: AIChatEventType.done,
                      messageId: 1,
                    ),
                  ]));
          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const UnifiedChatInit());
          await Future.delayed(const Duration(milliseconds: 200));
          bloc.add(const UnifiedChatSendMessage('Hello'));
        },
        wait: const Duration(milliseconds: 500),
        expect: () => [
          // 1. AI conversation created -> state projection
          isA<UnifiedChatState>()
              .having((s) => s.aiMessages, 'aiMessages', isEmpty),
          // 2+ : user message added, isTyping, streaming, then completed
          // We check the last state has the conversation messages
          isA<UnifiedChatState>()
              .having((s) => s.aiMessages.length, 'aiMessages.length', 1)
              .having((s) => s.isTyping, 'isTyping', isTrue),
          // Token received -> streamingContent updated
          isA<UnifiedChatState>()
              .having(
                  (s) => s.streamingContent, 'streamingContent', 'Hi there')
              .having((s) => s.isTyping, 'isTyping', isTrue),
          // Message completed -> assistant message added, isTyping false
          isA<UnifiedChatState>()
              .having((s) => s.aiMessages.length, 'aiMessages.length', 2)
              .having((s) => s.isTyping, 'isTyping', isFalse)
              .having((s) => s.streamingContent, 'streamingContent', ''),
        ],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'auto-creates conversation when sending without existing one',
        build: () {
          // createConversation will be called by sendMessage handler in AIChatBloc
          when(() => mockAIChatService.createConversation())
              .thenAnswer((_) async => const AIConversation(id: 'conv-auto'));
          when(() => mockAIChatService.sendMessage('conv-auto', 'Quick msg'))
              .thenAnswer((_) => Stream.fromIterable([
                    const AIChatEvent(
                      type: AIChatEventType.done,
                      messageId: 1,
                    ),
                  ]));
          return buildBloc();
        },
        act: (bloc) =>
            bloc.add(const UnifiedChatSendMessage('Quick msg')),
        wait: const Duration(milliseconds: 500),
        expect: () => [
          // AIChatBloc auto-creates conversation, then sends -> multiple state changes
          isA<UnifiedChatState>(),
          isA<UnifiedChatState>(),
          isA<UnifiedChatState>(),
        ],
        verify: (_) {
          verify(() => mockAIChatService.createConversation()).called(1);
        },
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'does not route to CS bloc when not in csConnected mode',
        build: () => buildBloc(),
        seed: () => const UnifiedChatState(mode: ChatMode.transferring),
        act: (bloc) =>
            bloc.add(const UnifiedChatSendMessage('Hello')),
        wait: const Duration(milliseconds: 100),
        expect: () => [],
      );
    });

    // ==================== UnifiedChatRequestHumanCS ====================

    group('UnifiedChatRequestHumanCS', () {
      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'immediately emits transferring mode, then csConnected on success',
        build: () {
          when(() => mockCommonRepo.assignCustomerService())
              .thenAnswer((_) async => {
                    'chat': {
                      'chat_id': 'chat-1',
                      'user_id': 'user-1',
                      'service_id': 'cs-1',
                      'is_ended': 0,
                    },
                    'service': {
                      'id': 'cs-1',
                      'name': 'Agent Smith',
                    },
                  });
          when(() => mockCommonRepo.getCustomerServiceMessages(any()))
              .thenAnswer((_) async => []);
          return buildBloc();
        },
        act: (bloc) =>
            bloc.add(const UnifiedChatRequestHumanCS()),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // 1. Immediate emit: mode -> transferring
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          // 2. CS sub-bloc emits connecting -> _CSStateChanged -> mode stays transferring
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          // 3. CS sub-bloc emits connected -> _CSStateChanged -> mode -> csConnected
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.csConnected)
              .having((s) => s.csServiceName, 'csServiceName', 'Agent Smith')
              .having((s) => s.csChatId, 'csChatId', 'chat-1'),
        ],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'falls back to AI mode on CS connection error',
        build: () {
          when(() => mockCommonRepo.assignCustomerService())
              .thenThrow(Exception('No agents'));
          return buildBloc();
        },
        act: (bloc) =>
            bloc.add(const UnifiedChatRequestHumanCS()),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // 1. Immediate emit: mode -> transferring
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          // 2. CS sub-bloc emits connecting
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          // 3. CS sub-bloc emits error -> _CSStateChanged -> mode -> ai (fallback)
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.ai)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    // ==================== UnifiedChatReturnToAI ====================

    group('UnifiedChatReturnToAI', () {
      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'emits mode: ai',
        build: () => buildBloc(),
        seed: () => const UnifiedChatState(mode: ChatMode.csEnded),
        act: (bloc) => bloc.add(const UnifiedChatReturnToAI()),
        expect: () => [
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.ai),
        ],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'preserves existing AI messages and CS messages when returning',
        build: () => buildBloc(),
        seed: () => UnifiedChatState(
          mode: ChatMode.csEnded,
          aiMessages: [
            AIMessage(
              role: 'user',
              content: 'Old AI message',
              createdAt: DateTime(2026),
            ),
          ],
          csMessages: const [
            CustomerServiceMessage(content: 'CS message'),
          ],
        ),
        act: (bloc) => bloc.add(const UnifiedChatReturnToAI()),
        expect: () => [
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.ai)
              .having(
                  (s) => s.aiMessages.length, 'aiMessages.length', 1)
              .having(
                  (s) => s.csMessages.length, 'csMessages.length', 1),
        ],
      );
    });

    // ==================== UnifiedChatLoadHistory ====================

    group('UnifiedChatLoadHistory', () {
      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'dispatches to AI sub-bloc and projects loaded messages',
        build: () {
          when(() => mockAIChatService.getHistory('conv-old'))
              .thenAnswer((_) async => [
                    AIMessage(
                      id: 1,
                      role: 'user',
                      content: 'Old question',
                      createdAt: DateTime(2026),
                    ),
                    AIMessage(
                      id: 2,
                      role: 'assistant',
                      content: 'Old answer',
                      createdAt: DateTime(2026),
                    ),
                  ]);
          return buildBloc();
        },
        act: (bloc) =>
            bloc.add(const UnifiedChatLoadHistory('conv-old')),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // AIChatBloc emits loading state first
          isA<UnifiedChatState>(),
          // Then loaded state with messages
          isA<UnifiedChatState>()
              .having((s) => s.aiMessages.length, 'aiMessages.length', 2)
              .having((s) => s.aiMessages.first.content, 'first message',
                  'Old question')
              .having((s) => s.aiMessages.last.content, 'last message',
                  'Old answer'),
        ],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'does nothing when mode is not AI',
        build: () => buildBloc(),
        seed: () => const UnifiedChatState(mode: ChatMode.csConnected),
        act: (bloc) =>
            bloc.add(const UnifiedChatLoadHistory('conv-old')),
        wait: const Duration(milliseconds: 100),
        expect: () => [],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'does nothing when mode is transferring',
        build: () => buildBloc(),
        seed: () => const UnifiedChatState(mode: ChatMode.transferring),
        act: (bloc) =>
            bloc.add(const UnifiedChatLoadHistory('conv-old')),
        wait: const Duration(milliseconds: 100),
        expect: () => [],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'propagates error when history load fails',
        build: () {
          when(() => mockAIChatService.getHistory('conv-bad'))
              .thenThrow(Exception('Not found'));
          return buildBloc();
        },
        act: (bloc) =>
            bloc.add(const UnifiedChatLoadHistory('conv-bad')),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // AIChatBloc emits loading
          isA<UnifiedChatState>(),
          // AIChatBloc emits error
          isA<UnifiedChatState>()
              .having((s) => s.errorMessage, 'errorMessage',
                  'ai_chat_load_history_failed'),
        ],
      );
    });

    // ==================== UnifiedChatClearTaskDraft ====================

    group('UnifiedChatClearTaskDraft', () {
      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'clears taskDraft on unified state and dispatches to AI sub-bloc',
        build: () => buildBloc(),
        seed: () => const UnifiedChatState(
          taskDraft: {'title': 'Test Task', 'description': 'A task'},
        ),
        act: (bloc) => bloc.add(const UnifiedChatClearTaskDraft()),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // Immediate emit from _onClearTaskDraft: taskDraft -> null
          isA<UnifiedChatState>()
              .having((s) => s.taskDraft, 'taskDraft', isNull),
          // AI sub-bloc also processes AIChatClearTaskDraft -> emits state ->
          // _AIStateChanged -> but taskDraft is already null, so this may or
          // may not produce a distinct state (Equatable dedup). We just verify
          // the first state has null taskDraft.
        ],
      );
    });

    // ==================== UnifiedChatCSEndChat ====================

    group('UnifiedChatCSEndChat', () {
      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'dispatches to CS sub-bloc and projects ended state',
        build: () {
          when(() => mockCommonRepo.endCustomerServiceChat(any()))
              .thenAnswer((_) async {});
          // Need to first connect to CS so the chat object exists
          when(() => mockCommonRepo.assignCustomerService())
              .thenAnswer((_) async => {
                    'chat': {
                      'chat_id': 'chat-1',
                      'user_id': 'user-1',
                      'service_id': 'cs-1',
                      'is_ended': 0,
                    },
                    'service': {
                      'id': 'cs-1',
                      'name': 'Agent',
                    },
                  });
          when(() => mockCommonRepo.getCustomerServiceMessages(any()))
              .thenAnswer((_) async => []);
          return buildBloc();
        },
        act: (bloc) async {
          // First connect to CS
          bloc.add(const UnifiedChatRequestHumanCS());
          await Future.delayed(const Duration(milliseconds: 300));
          // Then end chat
          bloc.add(const UnifiedChatCSEndChat());
        },
        wait: const Duration(milliseconds: 500),
        expect: () => [
          // UnifiedChatRequestHumanCS sequence
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.csConnected),
          // UnifiedChatCSEndChat -> CS sub-bloc emits ended -> _CSStateChanged
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.csEnded)
              .having((s) => s.actionMessage, 'actionMessage',
                  'conversation_ended'),
        ],
      );
    });

    // ==================== UnifiedChatCSRateChat ====================

    group('UnifiedChatCSRateChat', () {
      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'dispatches to CS sub-bloc and projects rating states',
        build: () {
          when(() => mockCommonRepo.rateCustomerService(
                any(),
                rating: any(named: 'rating'),
                comment: any(named: 'comment'),
              )).thenAnswer((_) async {});
          when(() => mockCommonRepo.assignCustomerService())
              .thenAnswer((_) async => {
                    'chat': {
                      'chat_id': 'chat-1',
                      'user_id': 'user-1',
                      'service_id': 'cs-1',
                      'is_ended': 0,
                    },
                    'service': {
                      'id': 'cs-1',
                      'name': 'Agent',
                    },
                  });
          when(() => mockCommonRepo.getCustomerServiceMessages(any()))
              .thenAnswer((_) async => []);
          when(() => mockCommonRepo.endCustomerServiceChat(any()))
              .thenAnswer((_) async {});
          return buildBloc();
        },
        act: (bloc) async {
          // Connect -> end -> rate
          bloc.add(const UnifiedChatRequestHumanCS());
          await Future.delayed(const Duration(milliseconds: 300));
          bloc.add(const UnifiedChatCSEndChat());
          await Future.delayed(const Duration(milliseconds: 200));
          bloc.add(const UnifiedChatCSRateChat(
            rating: 5,
            comment: 'Great service',
          ));
        },
        wait: const Duration(milliseconds: 600),
        expect: () => [
          // Connect sequence
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.csConnected),
          // End chat
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.csEnded),
          // Rate: isRating -> true
          isA<UnifiedChatState>()
              .having((s) => s.isRating, 'isRating', isTrue),
          // Rate: isRating -> false, actionMessage set
          isA<UnifiedChatState>()
              .having((s) => s.isRating, 'isRating', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'feedback_success'),
        ],
      );
    });

    // ==================== AI State Projection ====================

    group('AI state projection via _AIStateChanged', () {
      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'projects AI streaming content to unified state',
        build: () {
          when(() => mockAIChatService.createConversation())
              .thenAnswer((_) async => const AIConversation(id: 'conv-1'));
          when(() => mockAIChatService.sendMessage('conv-1', 'Tell me'))
              .thenAnswer((_) => Stream.fromIterable([
                    const AIChatEvent(
                      type: AIChatEventType.token,
                      content: 'Here ',
                    ),
                    const AIChatEvent(
                      type: AIChatEventType.token,
                      content: 'you go',
                    ),
                    const AIChatEvent(
                      type: AIChatEventType.done,
                      messageId: 10,
                    ),
                  ]));
          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const UnifiedChatInit());
          await Future.delayed(const Duration(milliseconds: 200));
          bloc.add(const UnifiedChatSendMessage('Tell me'));
        },
        wait: const Duration(milliseconds: 500),
        expect: () => [
          // Init: conversation created
          isA<UnifiedChatState>()
              .having((s) => s.aiMessages, 'aiMessages', isEmpty),
          // Send: user message added, isReplying
          isA<UnifiedChatState>()
              .having((s) => s.aiMessages.length, 'length', 1)
              .having((s) => s.isTyping, 'isTyping', isTrue),
          // Token 1
          isA<UnifiedChatState>()
              .having(
                  (s) => s.streamingContent, 'streamingContent', 'Here '),
          // Token 2
          isA<UnifiedChatState>()
              .having((s) => s.streamingContent, 'streamingContent',
                  'Here you go'),
          // Done: assistant message finalized
          isA<UnifiedChatState>()
              .having((s) => s.aiMessages.length, 'length', 2)
              .having((s) => s.isTyping, 'isTyping', isFalse)
              .having((s) => s.streamingContent, 'streamingContent', ''),
        ],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'projects csAvailableSignal from AI sub-bloc',
        build: () {
          when(() => mockAIChatService.createConversation())
              .thenAnswer((_) async => const AIConversation(id: 'conv-1'));
          when(() => mockAIChatService.sendMessage('conv-1', 'need help'))
              .thenAnswer((_) => Stream.fromIterable([
                    const AIChatEvent(
                      type: AIChatEventType.csAvailable,
                      csAvailable: true,
                      contactEmail: 'support@link2ur.com',
                    ),
                    const AIChatEvent(
                      type: AIChatEventType.done,
                      messageId: 20,
                    ),
                  ]));
          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const UnifiedChatInit());
          await Future.delayed(const Duration(milliseconds: 200));
          bloc.add(const UnifiedChatSendMessage('need help'));
        },
        wait: const Duration(milliseconds: 500),
        expect: () => [
          // Init
          isA<UnifiedChatState>(),
          // User message added
          isA<UnifiedChatState>()
              .having((s) => s.isTyping, 'isTyping', isTrue),
          // csAvailable signal
          isA<UnifiedChatState>()
              .having((s) => s.csOnlineStatus, 'csOnlineStatus', isTrue)
              .having((s) => s.csContactEmail, 'csContactEmail',
                  'support@link2ur.com'),
          // Done
          isA<UnifiedChatState>()
              .having((s) => s.isTyping, 'isTyping', isFalse),
        ],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'projects taskDraft from AI sub-bloc',
        build: () {
          when(() => mockAIChatService.createConversation())
              .thenAnswer((_) async => const AIConversation(id: 'conv-1'));
          when(() => mockAIChatService.sendMessage('conv-1', 'create task'))
              .thenAnswer((_) => Stream.fromIterable([
                    const AIChatEvent(
                      type: AIChatEventType.taskDraft,
                      taskDraft: {
                        'title': 'Help with math',
                        'category': 'tutoring',
                      },
                    ),
                    const AIChatEvent(
                      type: AIChatEventType.token,
                      content: 'Here is your task draft.',
                    ),
                    const AIChatEvent(
                      type: AIChatEventType.done,
                      messageId: 30,
                    ),
                  ]));
          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const UnifiedChatInit());
          await Future.delayed(const Duration(milliseconds: 200));
          bloc.add(const UnifiedChatSendMessage('create task'));
        },
        wait: const Duration(milliseconds: 500),
        expect: () => [
          // Init
          isA<UnifiedChatState>(),
          // User message
          isA<UnifiedChatState>()
              .having((s) => s.isTyping, 'isTyping', isTrue),
          // taskDraft received
          isA<UnifiedChatState>()
              .having((s) => s.taskDraft, 'taskDraft', isNotNull)
              .having((s) => s.taskDraft!['title'], 'title',
                  'Help with math'),
          // Token
          isA<UnifiedChatState>()
              .having((s) => s.taskDraft, 'taskDraft', isNotNull),
          // Done: taskDraft persists
          isA<UnifiedChatState>()
              .having((s) => s.taskDraft, 'taskDraft', isNotNull)
              .having((s) => s.isTyping, 'isTyping', isFalse),
        ],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'AI state changes are ignored when mode is not AI',
        build: () {
          when(() => mockAIChatService.createConversation())
              .thenAnswer((_) async => const AIConversation(id: 'conv-1'));
          return buildBloc();
        },
        seed: () => const UnifiedChatState(mode: ChatMode.csConnected),
        act: (bloc) async {
          // Dispatch init which triggers AI sub-bloc to create conversation
          // But since mode is csConnected, _onAIStateChanged should ignore
          bloc.add(const UnifiedChatInit());
        },
        wait: const Duration(milliseconds: 300),
        // No state changes because AI state changes are filtered out when mode != ai
        expect: () => [],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'projects AI error message to unified state',
        build: () {
          when(() => mockAIChatService.createConversation())
              .thenAnswer((_) async => const AIConversation(id: 'conv-1'));
          when(() => mockAIChatService.sendMessage('conv-1', 'test error'))
              .thenAnswer((_) => Stream.fromIterable([
                    const AIChatEvent(
                      type: AIChatEventType.error,
                      error: 'rate_limit_exceeded',
                    ),
                  ]));
          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const UnifiedChatInit());
          await Future.delayed(const Duration(milliseconds: 200));
          bloc.add(const UnifiedChatSendMessage('test error'));
        },
        wait: const Duration(milliseconds: 500),
        expect: () => [
          // Init
          isA<UnifiedChatState>(),
          // User message + isTyping
          isA<UnifiedChatState>()
              .having((s) => s.isTyping, 'isTyping', isTrue),
          // Error from SSE -> AI sub-bloc error state
          isA<UnifiedChatState>()
              .having((s) => s.errorMessage, 'errorMessage',
                  'rate_limit_exceeded')
              .having((s) => s.isTyping, 'isTyping', isFalse),
        ],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'projects tool call and tool result through unified state',
        build: () {
          when(() => mockAIChatService.createConversation())
              .thenAnswer((_) async => const AIConversation(id: 'conv-1'));
          when(() =>
                  mockAIChatService.sendMessage('conv-1', 'find task'))
              .thenAnswer((_) => Stream.fromIterable([
                    const AIChatEvent(
                      type: AIChatEventType.toolCall,
                      toolName: 'search_tasks',
                      toolInput: {'query': 'math'},
                    ),
                    const AIChatEvent(
                      type: AIChatEventType.toolResult,
                      toolName: 'search_tasks',
                      toolResult: {'tasks': []},
                    ),
                    const AIChatEvent(
                      type: AIChatEventType.token,
                      content: 'No tasks found.',
                    ),
                    const AIChatEvent(
                      type: AIChatEventType.done,
                      messageId: 40,
                    ),
                  ]));
          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const UnifiedChatInit());
          await Future.delayed(const Duration(milliseconds: 200));
          bloc.add(const UnifiedChatSendMessage('find task'));
        },
        wait: const Duration(milliseconds: 500),
        expect: () => [
          // Init
          isA<UnifiedChatState>(),
          // User message
          isA<UnifiedChatState>()
              .having((s) => s.isTyping, 'isTyping', isTrue),
          // Tool call
          isA<UnifiedChatState>()
              .having((s) => s.activeToolCall, 'activeToolCall',
                  'search_tasks'),
          // Tool result (activeToolCall cleared by default copyWith)
          isA<UnifiedChatState>(),
          // Token
          isA<UnifiedChatState>()
              .having((s) => s.streamingContent, 'streamingContent',
                  'No tasks found.'),
          // Done
          isA<UnifiedChatState>()
              .having((s) => s.isTyping, 'isTyping', isFalse)
              .having(
                  (s) => s.aiMessages.length, 'aiMessages.length', 2),
        ],
      );
    });

    // ==================== CS State Projection ====================

    group('CS state projection via _CSStateChanged', () {
      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'projects CS connected state with service info',
        build: () {
          when(() => mockCommonRepo.assignCustomerService())
              .thenAnswer((_) async => {
                    'chat': {
                      'chat_id': 'chat-cs',
                      'user_id': 'user-1',
                      'service_id': 'cs-1',
                      'is_ended': 0,
                    },
                    'service': {
                      'id': 'cs-1',
                      'name': 'Alice Support',
                    },
                    'system_message': {
                      'content': 'Welcome to support!',
                    },
                  });
          when(() => mockCommonRepo.getCustomerServiceMessages(any()))
              .thenAnswer((_) async => []);
          return buildBloc();
        },
        act: (bloc) =>
            bloc.add(const UnifiedChatRequestHumanCS()),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // Immediate: transferring
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          // CS connecting
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          // CS connected
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.csConnected)
              .having(
                  (s) => s.csServiceName, 'csServiceName', 'Alice Support')
              .having((s) => s.csChatId, 'csChatId', 'chat-cs')
              .having((s) => s.csMessages, 'csMessages', isNotEmpty),
        ],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'projects CS ended state with isRating',
        build: () {
          when(() => mockCommonRepo.assignCustomerService())
              .thenAnswer((_) async => {
                    'chat': {
                      'chat_id': 'chat-1',
                      'user_id': 'user-1',
                      'service_id': 'cs-1',
                      'is_ended': 0,
                    },
                    'service': {
                      'id': 'cs-1',
                      'name': 'Agent',
                    },
                  });
          when(() => mockCommonRepo.getCustomerServiceMessages(any()))
              .thenAnswer((_) async => []);
          when(() => mockCommonRepo.endCustomerServiceChat(any()))
              .thenAnswer((_) async {});
          return buildBloc();
        },
        act: (bloc) async {
          bloc.add(const UnifiedChatRequestHumanCS());
          await Future.delayed(const Duration(milliseconds: 300));
          bloc.add(const UnifiedChatCSEndChat());
        },
        wait: const Duration(milliseconds: 500),
        expect: () => [
          // Connect sequence
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.csConnected),
          // End chat -> CS ended
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.csEnded)
              .having((s) => s.isTyping, 'isTyping', isFalse),
        ],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'CS error falls back to AI mode with error message',
        build: () {
          when(() => mockCommonRepo.assignCustomerService())
              .thenThrow(
                  const CommonException('customer_service_unavailable'));
          return buildBloc();
        },
        act: (bloc) =>
            bloc.add(const UnifiedChatRequestHumanCS()),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // Immediate: transferring
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          // CS connecting
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          // CS error -> fallback to AI
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.ai)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );

      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'CS assign returns ended chat -> projects csEnded mode',
        build: () {
          when(() => mockCommonRepo.assignCustomerService())
              .thenAnswer((_) async => {
                    'chat': {
                      'chat_id': 'chat-ended',
                      'user_id': 'user-1',
                      'service_id': 'cs-1',
                      'is_ended': 1,
                    },
                    'service': {
                      'id': 'cs-1',
                      'name': 'Agent',
                    },
                  });
          when(() => mockCommonRepo.getCustomerServiceMessages(any()))
              .thenAnswer((_) async => []);
          return buildBloc();
        },
        act: (bloc) =>
            bloc.add(const UnifiedChatRequestHumanCS()),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // Immediate: transferring
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          // CS connecting
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          // CS ended (is_ended == 1)
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.csEnded),
        ],
      );
    });

    // ==================== UnifiedChatState ====================

    group('UnifiedChatState', () {
      test('supports Equatable comparison', () {
        const state1 = UnifiedChatState();
        const state2 = UnifiedChatState();
        expect(state1, equals(state2));
      });

      test('copyWith creates correct copy', () {
        const state = UnifiedChatState(
          mode: ChatMode.ai,
          isTyping: false,
        );
        final newState = state.copyWith(
          mode: ChatMode.csConnected,
          isTyping: true,
          csServiceName: 'Agent',
        );
        expect(newState.mode, equals(ChatMode.csConnected));
        expect(newState.isTyping, isTrue);
        expect(newState.csServiceName, equals('Agent'));
      });

      test('copyWith resets nullable fields to null when not passed', () {
        const state = UnifiedChatState(
          activeToolCall: 'search_tasks',
          taskDraft: {'title': 'task'},
          errorMessage: 'some_error',
          actionMessage: 'some_action',
        );
        final newState = state.copyWith(mode: ChatMode.ai);
        // activeToolCall, taskDraft, errorMessage, actionMessage use direct assignment
        // so they reset to null when not passed
        expect(newState.activeToolCall, isNull);
        expect(newState.taskDraft, isNull);
        expect(newState.errorMessage, isNull);
        expect(newState.actionMessage, isNull);
      });

      test('copyWith preserves fields using ?? pattern', () {
        const state = UnifiedChatState(
          mode: ChatMode.csConnected,
          isTyping: true,
          csOnlineStatus: true,
          csContactEmail: 'test@test.com',
          csServiceName: 'Agent',
          csChatId: 'chat-1',
          isRating: true,
        );
        // copyWith with no args preserves ??-pattern fields
        final newState = state.copyWith();
        expect(newState.mode, equals(ChatMode.csConnected));
        expect(newState.isTyping, isTrue);
        expect(newState.csOnlineStatus, isTrue);
        expect(newState.csContactEmail, equals('test@test.com'));
        expect(newState.csServiceName, equals('Agent'));
        expect(newState.csChatId, equals('chat-1'));
        expect(newState.isRating, isTrue);
      });

      test('props includes all fields', () {
        const state = UnifiedChatState();
        // Verify props has the correct number of entries
        expect(state.props.length, equals(13));
      });
    });

    // ==================== ChatMode Enum ====================

    group('ChatMode', () {
      test('has all expected values', () {
        expect(ChatMode.values.length, equals(4));
        expect(ChatMode.values, contains(ChatMode.ai));
        expect(ChatMode.values, contains(ChatMode.transferring));
        expect(ChatMode.values, contains(ChatMode.csConnected));
        expect(ChatMode.values, contains(ChatMode.csEnded));
      });
    });

    // ==================== Event Equatable ====================

    group('UnifiedChatEvent Equatable', () {
      test('UnifiedChatInit instances are equal', () {
        expect(const UnifiedChatInit(), equals(const UnifiedChatInit()));
      });

      test('UnifiedChatSendMessage with same content are equal', () {
        expect(
          const UnifiedChatSendMessage('hello'),
          equals(const UnifiedChatSendMessage('hello')),
        );
      });

      test('UnifiedChatSendMessage with different content are not equal', () {
        expect(
          const UnifiedChatSendMessage('hello'),
          isNot(equals(const UnifiedChatSendMessage('world'))),
        );
      });

      test('UnifiedChatLoadHistory with same id are equal', () {
        expect(
          const UnifiedChatLoadHistory('conv-1'),
          equals(const UnifiedChatLoadHistory('conv-1')),
        );
      });

      test('UnifiedChatCSRateChat with same rating are equal', () {
        expect(
          const UnifiedChatCSRateChat(rating: 5, comment: 'Great'),
          equals(const UnifiedChatCSRateChat(rating: 5, comment: 'Great')),
        );
      });

      test('UnifiedChatCSRateChat with different rating are not equal', () {
        expect(
          const UnifiedChatCSRateChat(rating: 5),
          isNot(equals(const UnifiedChatCSRateChat(rating: 3))),
        );
      });
    });

    // ==================== Bloc Closing ====================

    group('close', () {
      test('closes without errors', () async {
        final bloc = buildBloc();
        await expectLater(bloc.close(), completes);
      });

      test('cancels subscriptions on close', () async {
        final bloc = buildBloc();
        // Dispatch an event to ensure subscriptions are active
        when(() => mockAIChatService.createConversation())
            .thenAnswer((_) async => const AIConversation(id: 'conv-1'));
        bloc.add(const UnifiedChatInit());
        await Future.delayed(const Duration(milliseconds: 100));

        // Close should not throw
        await expectLater(bloc.close(), completes);
      });
    });

    // ==================== CS Send Message in CS Mode ====================

    group('SendMessage in CS mode', () {
      blocTest<UnifiedChatBloc, UnifiedChatState>(
        'routes message to CS sub-bloc when in csConnected mode',
        build: () {
          // Setup: connect to CS first
          when(() => mockCommonRepo.assignCustomerService())
              .thenAnswer((_) async => {
                    'chat': {
                      'chat_id': 'chat-1',
                      'user_id': 'user-1',
                      'service_id': 'cs-1',
                      'is_ended': 0,
                    },
                    'service': {
                      'id': 'cs-1',
                      'name': 'Agent',
                    },
                  });
          when(() => mockCommonRepo.getCustomerServiceMessages(any()))
              .thenAnswer((_) async => [
                    {
                      'content': 'Hello from user',
                      'sender_type': 'user',
                      'created_at': '2026-01-01T00:00:00',
                    },
                  ]);
          when(() =>
                  mockCommonRepo.sendCustomerServiceMessage(any(), any()))
              .thenAnswer((_) async => {'success': true});
          return buildBloc();
        },
        act: (bloc) async {
          // First connect
          bloc.add(const UnifiedChatRequestHumanCS());
          await Future.delayed(const Duration(milliseconds: 300));
          // Then send message in CS mode
          bloc.add(const UnifiedChatSendMessage('Help me please'));
        },
        wait: const Duration(milliseconds: 500),
        expect: () => [
          // Connect sequence
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.transferring),
          isA<UnifiedChatState>()
              .having((s) => s.mode, 'mode', ChatMode.csConnected),
          // CS send message: isSending -> true, optimistic message added
          isA<UnifiedChatState>()
              .having((s) => s.isTyping, 'isTyping', isTrue)
              .having((s) => s.csMessages, 'csMessages', isNotEmpty),
          // CS send complete: isSending -> false, messages reloaded
          isA<UnifiedChatState>()
              .having((s) => s.isTyping, 'isTyping', isFalse),
        ],
      );
    });
  });
}
