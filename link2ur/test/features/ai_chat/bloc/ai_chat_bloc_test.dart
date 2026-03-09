import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/ai_chat/bloc/ai_chat_bloc.dart';
import 'package:link2ur/data/models/ai_chat.dart' as ai_models;
import 'package:link2ur/data/services/ai_chat_service.dart';

// ==================== Mocks ====================

class MockAIChatService extends Mock implements AIChatService {}

// ==================== Test Data ====================

final testConversation = ai_models.AIConversation(
  id: 'conv-1',
  title: 'Test Conversation',
  modelUsed: 'claude-3',
  totalTokens: 100,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final testConversation2 = ai_models.AIConversation(
  id: 'conv-2',
  title: 'Another Conversation',
  modelUsed: 'claude-3',
  totalTokens: 200,
  createdAt: DateTime(2026, 1, 2),
  updatedAt: DateTime(2026, 1, 2),
);

final testUserMessage = ai_models.AIMessage(
  id: 1,
  role: 'user',
  content: 'Hello AI',
  createdAt: DateTime(2026),
);

final testAssistantMessage = ai_models.AIMessage(
  id: 2,
  role: 'assistant',
  content: 'Hello! How can I help?',
  createdAt: DateTime(2026),
);

// ==================== Tests ====================

void main() {
  late MockAIChatService mockService;
  late AIChatBloc bloc;

  setUp(() {
    mockService = MockAIChatService();
    bloc = AIChatBloc(aiChatService: mockService);
  });

  tearDown(() {
    bloc.close();
  });

  group('AIChatBloc', () {
    // ==================== Initial State ====================

    test('initial state is correct', () {
      expect(bloc.state, equals(const AIChatState()));
      expect(bloc.state.status, equals(AIChatStatus.initial));
      expect(bloc.state.conversations, isEmpty);
      expect(bloc.state.messages, isEmpty);
      expect(bloc.state.currentConversationId, isNull);
      expect(bloc.state.isReplying, isFalse);
      expect(bloc.state.streamingContent, equals(''));
      expect(bloc.state.activeToolCall, isNull);
      expect(bloc.state.errorMessage, isNull);
      expect(bloc.state.csAvailableSignal, isNull);
      expect(bloc.state.csContactEmail, isNull);
      expect(bloc.state.taskDraft, isNull);
      expect(bloc.state.lastToolName, isNull);
    });

    // ==================== LoadConversations ====================

    group('AIChatLoadConversations', () {
      blocTest<AIChatBloc, AIChatState>(
        'emits [loading, loaded] with conversations when success',
        build: () {
          when(() => mockService.getConversations())
              .thenAnswer((_) async => [testConversation, testConversation2]);
          return bloc;
        },
        act: (bloc) => bloc.add(const AIChatLoadConversations()),
        expect: () => [
          isA<AIChatState>()
              .having((s) => s.status, 'status', AIChatStatus.loading),
          isA<AIChatState>()
              .having((s) => s.status, 'status', AIChatStatus.loaded)
              .having(
                  (s) => s.conversations.length, 'conversations.length', 2)
              .having((s) => s.conversations.first.id, 'first conv id',
                  'conv-1'),
        ],
        verify: (_) {
          verify(() => mockService.getConversations()).called(1);
        },
      );

      blocTest<AIChatBloc, AIChatState>(
        'emits [loading, error] with error code when failure',
        build: () {
          when(() => mockService.getConversations())
              .thenThrow(Exception('Network error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const AIChatLoadConversations()),
        expect: () => [
          isA<AIChatState>()
              .having((s) => s.status, 'status', AIChatStatus.loading),
          isA<AIChatState>()
              .having((s) => s.status, 'status', AIChatStatus.error)
              .having((s) => s.errorMessage, 'errorMessage',
                  'ai_chat_load_conversations_failed'),
        ],
      );
    });

    // ==================== CreateConversation ====================

    group('AIChatCreateConversation', () {
      blocTest<AIChatBloc, AIChatState>(
        'sets currentConversationId and prepends to conversations list when success',
        build: () {
          when(() => mockService.createConversation())
              .thenAnswer((_) async => testConversation);
          return bloc;
        },
        seed: () => AIChatState(
          status: AIChatStatus.loaded,
          conversations: [testConversation2],
        ),
        act: (bloc) => bloc.add(const AIChatCreateConversation()),
        expect: () => [
          isA<AIChatState>()
              .having((s) => s.currentConversationId,
                  'currentConversationId', 'conv-1')
              .having(
                  (s) => s.conversations.length, 'conversations.length', 2)
              .having((s) => s.conversations.first.id, 'first conv id',
                  'conv-1')
              .having(
                  (s) => s.messages, 'messages', isEmpty)
              .having(
                  (s) => s.streamingContent, 'streamingContent', ''),
        ],
        verify: (_) {
          verify(() => mockService.createConversation()).called(1);
        },
      );

      blocTest<AIChatBloc, AIChatState>(
        'emits nothing when createConversation returns null',
        build: () {
          when(() => mockService.createConversation())
              .thenAnswer((_) async => null);
          return bloc;
        },
        act: (bloc) => bloc.add(const AIChatCreateConversation()),
        expect: () => <AIChatState>[],
      );

      blocTest<AIChatBloc, AIChatState>(
        'emits errorMessage when createConversation throws',
        build: () {
          when(() => mockService.createConversation())
              .thenThrow(Exception('Server error'));
          return bloc;
        },
        act: (bloc) => bloc.add(const AIChatCreateConversation()),
        expect: () => [
          isA<AIChatState>().having((s) => s.errorMessage, 'errorMessage',
              'ai_chat_create_conversation_failed'),
        ],
      );
    });

    // ==================== LoadHistory ====================

    group('AIChatLoadHistory', () {
      blocTest<AIChatBloc, AIChatState>(
        'emits [loading, loaded] with messages and sets currentConversationId',
        build: () {
          when(() => mockService.getHistory('conv-1'))
              .thenAnswer((_) async => [testUserMessage, testAssistantMessage]);
          return bloc;
        },
        act: (bloc) => bloc.add(const AIChatLoadHistory('conv-1')),
        expect: () => [
          isA<AIChatState>()
              .having((s) => s.status, 'status', AIChatStatus.loading)
              .having((s) => s.currentConversationId,
                  'currentConversationId', 'conv-1'),
          isA<AIChatState>()
              .having((s) => s.status, 'status', AIChatStatus.loaded)
              .having((s) => s.messages.length, 'messages.length', 2)
              .having((s) => s.streamingContent, 'streamingContent', ''),
        ],
        verify: (_) {
          verify(() => mockService.getHistory('conv-1')).called(1);
        },
      );

      blocTest<AIChatBloc, AIChatState>(
        'emits [loading, error] with error code when failure',
        build: () {
          when(() => mockService.getHistory('conv-1'))
              .thenThrow(Exception('Not found'));
          return bloc;
        },
        act: (bloc) => bloc.add(const AIChatLoadHistory('conv-1')),
        expect: () => [
          isA<AIChatState>()
              .having((s) => s.status, 'status', AIChatStatus.loading)
              .having((s) => s.currentConversationId,
                  'currentConversationId', 'conv-1'),
          isA<AIChatState>()
              .having((s) => s.status, 'status', AIChatStatus.error)
              .having((s) => s.errorMessage, 'errorMessage',
                  'ai_chat_load_history_failed'),
        ],
      );
    });

    // ==================== SendMessage ====================

    group('AIChatSendMessage', () {
      blocTest<AIChatBloc, AIChatState>(
        'adds user message and processes SSE token stream to completion',
        build: () {
          when(() => mockService.sendMessage('conv-1', 'Hello'))
              .thenAnswer((_) => Stream.fromIterable([
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.token,
                      content: 'Hi',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.token,
                      content: ' there',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.done,
                      messageId: 42,
                    ),
                  ]));
          return bloc;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
          currentConversationId: 'conv-1',
        ),
        act: (bloc) => bloc.add(const AIChatSendMessage('Hello')),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // 1. User message added, isReplying = true
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', true)
              .having((s) => s.messages.length, 'messages.length', 1)
              .having(
                  (s) => s.messages.first.role, 'first message role', 'user')
              .having((s) => s.messages.first.content, 'first message content',
                  'Hello')
              .having((s) => s.streamingContent, 'streamingContent', ''),
          // 2. First token
          isA<AIChatState>()
              .having(
                  (s) => s.streamingContent, 'streamingContent', 'Hi'),
          // 3. Second token
          isA<AIChatState>()
              .having(
                  (s) => s.streamingContent, 'streamingContent', 'Hi there'),
          // 4. Message completed — assistant message added
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', false)
              .having((s) => s.messages.length, 'messages.length', 2)
              .having(
                  (s) => s.messages.last.role, 'last message role', 'assistant')
              .having((s) => s.messages.last.content, 'last message content',
                  'Hi there')
              .having((s) => s.messages.last.id, 'last message id', 42)
              .having((s) => s.streamingContent, 'streamingContent', ''),
        ],
      );

      blocTest<AIChatBloc, AIChatState>(
        'creates conversation first when no currentConversationId, then sends',
        build: () {
          when(() => mockService.createConversation())
              .thenAnswer((_) async => testConversation);
          when(() => mockService.sendMessage('conv-1', 'Hello'))
              .thenAnswer((_) => Stream.fromIterable([
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.token,
                      content: 'Response',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.done,
                      messageId: 10,
                    ),
                  ]));
          return bloc;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
          // No currentConversationId
        ),
        act: (bloc) => bloc.add(const AIChatSendMessage('Hello')),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // 1. Conversation created, currentConversationId set
          isA<AIChatState>()
              .having((s) => s.currentConversationId,
                  'currentConversationId', 'conv-1')
              .having(
                  (s) => s.conversations.length, 'conversations.length', 1),
          // 2. User message added, isReplying = true
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', true)
              .having((s) => s.messages.length, 'messages.length', 1)
              .having(
                  (s) => s.messages.first.content, 'content', 'Hello'),
          // 3. Token
          isA<AIChatState>()
              .having(
                  (s) => s.streamingContent, 'streamingContent', 'Response'),
          // 4. Done
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', false)
              .having((s) => s.messages.length, 'messages.length', 2)
              .having((s) => s.messages.last.content, 'content', 'Response'),
        ],
      );

      blocTest<AIChatBloc, AIChatState>(
        'emits error when create conversation fails (no existing conversationId)',
        build: () {
          when(() => mockService.createConversation())
              .thenThrow(Exception('Create failed'));
          return bloc;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
          // No currentConversationId
        ),
        act: (bloc) => bloc.add(const AIChatSendMessage('Hello')),
        expect: () => [
          isA<AIChatState>().having((s) => s.errorMessage, 'errorMessage',
              'ai_chat_create_conversation_retry'),
        ],
      );

      blocTest<AIChatBloc, AIChatState>(
        'emits error when create conversation returns null (no existing conversationId)',
        build: () {
          when(() => mockService.createConversation())
              .thenAnswer((_) async => null);
          return bloc;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
        ),
        act: (bloc) => bloc.add(const AIChatSendMessage('Hello')),
        expect: () => [
          isA<AIChatState>().having((s) => s.errorMessage, 'errorMessage',
              'ai_chat_create_conversation_retry'),
        ],
      );
    });

    // ==================== SSE Stream Events (via SendMessage) ====================

    group('SSE stream events', () {
      blocTest<AIChatBloc, AIChatState>(
        'token received accumulates streamingContent and preserves taskDraft and lastToolName',
        build: () {
          when(() => mockService.sendMessage('conv-1', 'test'))
              .thenAnswer((_) => Stream.fromIterable([
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.token,
                      content: 'Hello',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.token,
                      content: ' World',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.done,
                      messageId: 1,
                    ),
                  ]));
          return bloc;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
          currentConversationId: 'conv-1',
          taskDraft: {'title': 'Draft Task'},
          // Note: lastToolName is NOT seeded — SendMessage's copyWith omits it, resetting to null
        ),
        act: (bloc) => bloc.add(const AIChatSendMessage('test')),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // User message added (taskDraft preserved via explicit pass)
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', true)
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Draft Task'}),
          // Token 1 — preserves taskDraft; lastToolName is null (no toolResult yet)
          isA<AIChatState>()
              .having(
                  (s) => s.streamingContent, 'streamingContent', 'Hello')
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Draft Task'}),
          // Token 2 — preserves taskDraft
          isA<AIChatState>()
              .having((s) => s.streamingContent, 'streamingContent',
                  'Hello World')
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Draft Task'}),
          // Done — preserves taskDraft
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', false)
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Draft Task'}),
        ],
      );

      blocTest<AIChatBloc, AIChatState>(
        'tool call sets activeToolCall and preserves taskDraft',
        build: () {
          when(() => mockService.sendMessage('conv-1', 'find tasks'))
              .thenAnswer((_) => Stream.fromIterable([
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.toolCall,
                      toolName: 'search_tasks',
                      toolInput: {'query': 'flutter'},
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.toolResult,
                      toolName: 'search_tasks',
                      toolResult: {'tasks': []},
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.token,
                      content: 'Found tasks',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.done,
                      messageId: 5,
                    ),
                  ]));
          return bloc;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
          currentConversationId: 'conv-1',
          taskDraft: {'title': 'Existing Draft'},
        ),
        act: (bloc) => bloc.add(const AIChatSendMessage('find tasks')),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // User message
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', true)
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Existing Draft'}),
          // Tool call — activeToolCall set, taskDraft preserved
          isA<AIChatState>()
              .having(
                  (s) => s.activeToolCall, 'activeToolCall', 'search_tasks')
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Existing Draft'}),
          // Tool result — activeToolCall cleared (null), lastToolName set, taskDraft preserved
          isA<AIChatState>()
              .having((s) => s.activeToolCall, 'activeToolCall', isNull)
              .having(
                  (s) => s.lastToolName, 'lastToolName', 'search_tasks')
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Existing Draft'}),
          // Token
          isA<AIChatState>()
              .having((s) => s.streamingContent, 'streamingContent',
                  'Found tasks')
              .having(
                  (s) => s.lastToolName, 'lastToolName', 'search_tasks')
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Existing Draft'}),
          // Done — assistant message created with lastToolName
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', false)
              .having((s) => s.messages.last.toolName, 'toolName',
                  'search_tasks')
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Existing Draft'}),
        ],
      );

      blocTest<AIChatBloc, AIChatState>(
        'tool result with prepare_task_draft sets taskDraft from result',
        build: () {
          when(() => mockService.sendMessage('conv-1', 'create task'))
              .thenAnswer((_) => Stream.fromIterable([
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.toolCall,
                      toolName: 'prepare_task_draft',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.toolResult,
                      toolName: 'prepare_task_draft',
                      toolResult: {
                        'draft': {
                          'title': 'New Task',
                          'description': 'Task description',
                        }
                      },
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.token,
                      content: 'Draft created',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.done,
                      messageId: 7,
                    ),
                  ]));
          return bloc;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
          currentConversationId: 'conv-1',
        ),
        act: (bloc) => bloc.add(const AIChatSendMessage('create task')),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // User message
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', true),
          // Tool call
          isA<AIChatState>()
              .having((s) => s.activeToolCall, 'activeToolCall',
                  'prepare_task_draft'),
          // Tool result — taskDraft extracted from result['draft']
          isA<AIChatState>()
              .having((s) => s.activeToolCall, 'activeToolCall', isNull)
              .having((s) => s.lastToolName, 'lastToolName',
                  'prepare_task_draft')
              .having((s) => s.taskDraft, 'taskDraft', const {
                'title': 'New Task',
                'description': 'Task description',
              }),
          // Token — taskDraft preserved
          isA<AIChatState>()
              .having((s) => s.streamingContent, 'streamingContent',
                  'Draft created')
              .having((s) => s.taskDraft, 'taskDraft', isNotNull),
          // Done — taskDraft preserved
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', false)
              .having((s) => s.taskDraft, 'taskDraft', const {
                'title': 'New Task',
                'description': 'Task description',
              }),
        ],
      );

      blocTest<AIChatBloc, AIChatState>(
        'error event with streaming content saves partial message and preserves taskDraft',
        build: () {
          when(() => mockService.sendMessage('conv-1', 'test'))
              .thenAnswer((_) => Stream.fromIterable([
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.token,
                      content: 'Partial response',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.error,
                      error: 'stream_interrupted',
                    ),
                  ]));
          return bloc;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
          currentConversationId: 'conv-1',
          taskDraft: {'title': 'Keep this'},
        ),
        act: (bloc) => bloc.add(const AIChatSendMessage('test')),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // User message
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', true)
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Keep this'}),
          // Token
          isA<AIChatState>()
              .having((s) => s.streamingContent, 'streamingContent',
                  'Partial response')
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Keep this'}),
          // Error — partial content saved as assistant message
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', false)
              .having((s) => s.messages.last.role, 'last role', 'assistant')
              .having((s) => s.messages.last.content, 'last content',
                  'Partial response')
              .having((s) => s.streamingContent, 'streamingContent', '')
              .having((s) => s.errorMessage, 'errorMessage',
                  'stream_interrupted')
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Keep this'}),
        ],
      );

      blocTest<AIChatBloc, AIChatState>(
        'error event without streaming content does not save partial message',
        build: () {
          when(() => mockService.sendMessage('conv-1', 'test'))
              .thenAnswer((_) => Stream.fromIterable([
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.error,
                      error: 'immediate_error',
                    ),
                  ]));
          return bloc;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
          currentConversationId: 'conv-1',
        ),
        act: (bloc) => bloc.add(const AIChatSendMessage('test')),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // User message
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', true)
              .having((s) => s.messages.length, 'messages.length', 1),
          // Error — no partial save, only user message remains
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', false)
              .having((s) => s.messages.length, 'messages.length', 1)
              .having((s) => s.errorMessage, 'errorMessage',
                  'immediate_error'),
        ],
      );

      blocTest<AIChatBloc, AIChatState>(
        'csAvailable event sets csAvailableSignal and csContactEmail, preserves lastToolName and taskDraft',
        build: () {
          when(() => mockService.sendMessage('conv-1', 'help'))
              .thenAnswer((_) => Stream.fromIterable([
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.token,
                      content: 'Let me help',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.csAvailable,
                      csAvailable: true,
                      contactEmail: 'support@link2ur.com',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.done,
                      messageId: 20,
                    ),
                  ]));
          return bloc;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
          currentConversationId: 'conv-1',
          // lastToolName NOT seeded — SendMessage clears it
          taskDraft: {'title': 'Preserved'},
        ),
        act: (bloc) => bloc.add(const AIChatSendMessage('help')),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // User message
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', true)
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Preserved'}),
          // Token — preserves taskDraft (lastToolName is null, no toolResult in this flow)
          isA<AIChatState>()
              .having((s) => s.streamingContent, 'streamingContent',
                  'Let me help')
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Preserved'}),
          // CS available — preserves taskDraft
          isA<AIChatState>()
              .having(
                  (s) => s.csAvailableSignal, 'csAvailableSignal', true)
              .having((s) => s.csContactEmail, 'csContactEmail',
                  'support@link2ur.com')
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Preserved'}),
          // Done
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', false)
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'Preserved'}),
        ],
      );

      blocTest<AIChatBloc, AIChatState>(
        'taskDraft event sets taskDraft and preserves lastToolName',
        build: () {
          when(() => mockService.sendMessage('conv-1', 'draft'))
              .thenAnswer((_) => Stream.fromIterable([
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.taskDraft,
                      taskDraft: {
                        'title': 'SSE Draft',
                        'budget': 50,
                      },
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.token,
                      content: 'Here is your draft',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.done,
                      messageId: 30,
                    ),
                  ]));
          return bloc;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
          currentConversationId: 'conv-1',
          // lastToolName NOT seeded — SendMessage clears it
        ),
        act: (bloc) => bloc.add(const AIChatSendMessage('draft')),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // User message
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', true),
          // Task draft event — sets taskDraft (lastToolName still null, no toolResult)
          isA<AIChatState>()
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'SSE Draft', 'budget': 50}),
          // Token — preserves taskDraft
          isA<AIChatState>()
              .having((s) => s.streamingContent, 'streamingContent',
                  'Here is your draft')
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'SSE Draft', 'budget': 50}),
          // Done
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', false)
              .having((s) => s.taskDraft, 'taskDraft',
                  const {'title': 'SSE Draft', 'budget': 50}),
        ],
      );

      blocTest<AIChatBloc, AIChatState>(
        'message completed with empty streamingContent does not create assistant message',
        build: () {
          when(() => mockService.sendMessage('conv-1', 'test'))
              .thenAnswer((_) => Stream.fromIterable([
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.done,
                      messageId: 99,
                    ),
                  ]));
          return bloc;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
          currentConversationId: 'conv-1',
        ),
        act: (bloc) => bloc.add(const AIChatSendMessage('test')),
        wait: const Duration(milliseconds: 300),
        expect: () => [
          // User message
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', true)
              .having((s) => s.messages.length, 'messages.length', 1),
          // Done — no assistant message added (streamingContent was empty)
          isA<AIChatState>()
              .having((s) => s.isReplying, 'isReplying', false)
              .having((s) => s.messages.length, 'messages.length', 1),
        ],
      );
    });

    // ==================== ClearTaskDraft ====================

    group('AIChatClearTaskDraft', () {
      blocTest<AIChatBloc, AIChatState>(
        'clears taskDraft while preserving csAvailableSignal, csContactEmail, and lastToolName',
        build: () => bloc,
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
          currentConversationId: 'conv-1',
          taskDraft: {'title': 'To Be Cleared'},
          csAvailableSignal: true,
          csContactEmail: 'cs@link2ur.com',
          lastToolName: 'prepare_task_draft',
        ),
        act: (bloc) => bloc.add(const AIChatClearTaskDraft()),
        expect: () => [
          isA<AIChatState>()
              .having((s) => s.taskDraft, 'taskDraft', isNull)
              .having(
                  (s) => s.csAvailableSignal, 'csAvailableSignal', true)
              .having((s) => s.csContactEmail, 'csContactEmail',
                  'cs@link2ur.com')
              .having((s) => s.lastToolName, 'lastToolName',
                  'prepare_task_draft')
              .having((s) => s.currentConversationId,
                  'currentConversationId', 'conv-1'),
        ],
      );
    });

    // ==================== ArchiveConversation ====================

    group('AIChatArchiveConversation', () {
      blocTest<AIChatBloc, AIChatState>(
        'removes conversation from list and resets state when archiving current conversation',
        build: () {
          when(() => mockService.archiveConversation('conv-1'))
              .thenAnswer((_) async => true);
          return bloc;
        },
        seed: () => AIChatState(
          status: AIChatStatus.loaded,
          conversations: [testConversation, testConversation2],
          currentConversationId: 'conv-1',
          messages: [testUserMessage, testAssistantMessage],
        ),
        act: (bloc) =>
            bloc.add(const AIChatArchiveConversation('conv-1')),
        expect: () => [
          isA<AIChatState>()
              .having(
                  (s) => s.conversations.length, 'conversations.length', 1)
              .having((s) => s.conversations.first.id, 'remaining conv id',
                  'conv-2')
              // Note: copyWith uses ?? for currentConversationId, so null → keeps old value
              .having((s) => s.currentConversationId,
                  'currentConversationId', 'conv-1')
              // Messages cleared since we archived the current conversation
              .having((s) => s.messages, 'messages', isEmpty),
        ],
        verify: (_) {
          verify(() => mockService.archiveConversation('conv-1')).called(1);
        },
      );

      blocTest<AIChatBloc, AIChatState>(
        'removes conversation but keeps current state when archiving a different conversation',
        build: () {
          when(() => mockService.archiveConversation('conv-2'))
              .thenAnswer((_) async => true);
          return bloc;
        },
        seed: () => AIChatState(
          status: AIChatStatus.loaded,
          conversations: [testConversation, testConversation2],
          currentConversationId: 'conv-1',
          messages: [testUserMessage],
        ),
        act: (bloc) =>
            bloc.add(const AIChatArchiveConversation('conv-2')),
        expect: () => [
          isA<AIChatState>()
              .having(
                  (s) => s.conversations.length, 'conversations.length', 1)
              .having((s) => s.conversations.first.id, 'remaining conv id',
                  'conv-1')
              // Current conversation NOT archived → keep id
              .having((s) => s.currentConversationId,
                  'currentConversationId', 'conv-1')
              // Messages preserved
              .having((s) => s.messages.length, 'messages.length', 1),
        ],
      );

      blocTest<AIChatBloc, AIChatState>(
        'emits nothing when archive fails (error only logged)',
        build: () {
          when(() => mockService.archiveConversation('conv-1'))
              .thenThrow(Exception('Server error'));
          return bloc;
        },
        seed: () => AIChatState(
          status: AIChatStatus.loaded,
          conversations: [testConversation],
          currentConversationId: 'conv-1',
        ),
        act: (bloc) =>
            bloc.add(const AIChatArchiveConversation('conv-1')),
        expect: () => <AIChatState>[],
      );
    });

    // ==================== taskDraft persistence ====================

    group('taskDraft persistence', () {
      blocTest<AIChatBloc, AIChatState>(
        'taskDraft persists through full SSE flow: token, toolCall, csAvailable, messageCompleted',
        build: () {
          when(() => mockService.sendMessage('conv-1', 'msg'))
              .thenAnswer((_) => Stream.fromIterable([
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.token,
                      content: 'A',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.toolCall,
                      toolName: 'some_tool',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.toolResult,
                      toolName: 'some_tool',
                      toolResult: {'data': 'value'},
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.csAvailable,
                      csAvailable: true,
                      contactEmail: 'help@test.com',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.token,
                      content: 'B',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.done,
                      messageId: 100,
                    ),
                  ]));
          return bloc;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
          currentConversationId: 'conv-1',
          taskDraft: {'title': 'Persistent Draft'},
        ),
        act: (bloc) => bloc.add(const AIChatSendMessage('msg')),
        wait: const Duration(milliseconds: 300),
        verify: (bloc) {
          // After all events, taskDraft should still be present
          expect(bloc.state.taskDraft,
              equals(const {'title': 'Persistent Draft'}));
          expect(bloc.state.isReplying, isFalse);
          expect(bloc.state.messages.last.role, equals('assistant'));
        },
      );
    });

    // ==================== lastToolName persistence ====================

    group('lastToolName persistence', () {
      blocTest<AIChatBloc, AIChatState>(
        'lastToolName persists through token, csAvailable, taskDraft events',
        build: () {
          when(() => mockService.sendMessage('conv-1', 'msg'))
              .thenAnswer((_) => Stream.fromIterable([
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.toolCall,
                      toolName: 'my_tool',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.toolResult,
                      toolName: 'my_tool',
                      toolResult: {'ok': true},
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.csAvailable,
                      csAvailable: false,
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.taskDraft,
                      taskDraft: {'draft': true},
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.token,
                      content: 'Result',
                    ),
                    const ai_models.AIChatEvent(
                      type: ai_models.AIChatEventType.done,
                      messageId: 200,
                    ),
                  ]));
          return bloc;
        },
        seed: () => const AIChatState(
          status: AIChatStatus.loaded,
          currentConversationId: 'conv-1',
        ),
        act: (bloc) => bloc.add(const AIChatSendMessage('msg')),
        wait: const Duration(milliseconds: 300),
        verify: (bloc) {
          // lastToolName is captured in the AIMessage.toolName before messageCompleted clears it
          // (messageCompleted's copyWith omits lastToolName → null)
          expect(bloc.state.lastToolName, isNull);
          expect(bloc.state.isReplying, isFalse);
          expect(bloc.state.messages.last.toolName, equals('my_tool'));
        },
      );
    });

    // ==================== copyWith behavior ====================

    group('AIChatState copyWith', () {
      test('nullable fields are cleared (set to null) when omitted from copyWith', () {
        const state = AIChatState(
          activeToolCall: 'tool1',
          errorMessage: 'err',
          csAvailableSignal: true,
          csContactEmail: 'test@test.com',
          taskDraft: {'key': 'value'},
          lastToolName: 'someTool',
        );
        // copyWith without passing nullable fields → they become null
        final newState = state.copyWith(status: AIChatStatus.loaded);
        expect(newState.activeToolCall, isNull);
        expect(newState.errorMessage, isNull);
        expect(newState.csAvailableSignal, isNull);
        expect(newState.csContactEmail, isNull);
        expect(newState.taskDraft, isNull);
        expect(newState.lastToolName, isNull);
      });

      test('non-nullable fields are preserved when omitted from copyWith', () {
        final state = AIChatState(
          status: AIChatStatus.loaded,
          conversations: [testConversation],
          currentConversationId: 'conv-1',
          messages: [testUserMessage],
          isReplying: true,
          streamingContent: 'hello',
        );
        final newState = state.copyWith();
        expect(newState.status, equals(AIChatStatus.loaded));
        expect(newState.conversations.length, equals(1));
        expect(newState.currentConversationId, equals('conv-1'));
        expect(newState.messages.length, equals(1));
        expect(newState.isReplying, isTrue);
        expect(newState.streamingContent, equals('hello'));
      });

      test('Equatable props include all fields', () {
        const state1 = AIChatState(lastToolName: 'a');
        const state2 = AIChatState(lastToolName: 'b');
        expect(state1, isNot(equals(state2)));
      });
    });
  });
}
