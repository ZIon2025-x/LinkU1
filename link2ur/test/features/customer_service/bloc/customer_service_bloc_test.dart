import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/customer_service/bloc/customer_service_bloc.dart';
import 'package:link2ur/data/models/customer_service.dart';
import 'package:link2ur/data/repositories/common_repository.dart';

class MockCommonRepository extends Mock implements CommonRepository {}

void main() {
  late MockCommonRepository mockRepo;
  late CustomerServiceBloc bloc;

  setUp(() {
    mockRepo = MockCommonRepository();
    bloc = CustomerServiceBloc(commonRepository: mockRepo);
  });

  tearDown(() {
    bloc.close();
  });

  group('CustomerServiceBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, equals(CustomerServiceStatus.initial));
      expect(bloc.state.messages, isEmpty);
      expect(bloc.state.chat, isNull);
      expect(bloc.state.serviceInfo, isNull);
      expect(bloc.state.isSending, isFalse);
      expect(bloc.state.isRating, isFalse);
    });

    group('CustomerServiceConnectRequested', () {
      blocTest<CustomerServiceBloc, CustomerServiceState>(
        'connects to customer service and loads history on success',
        build: () {
          when(() => mockRepo.assignCustomerService())
              .thenAnswer((_) async => {
                    'chat': {
                      'chat_id': 'chat1',
                      'user_id': 'user1',
                      'service_id': 'cs1',
                      'is_ended': 0,
                    },
                    'service': {
                      'id': 'cs1',
                      'name': 'Support Agent',
                    },
                  });
          when(() => mockRepo.getCustomerServiceMessages(any()))
              .thenAnswer((_) async => []);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const CustomerServiceConnectRequested()),
        expect: () => [
          isA<CustomerServiceState>()
              .having((s) => s.status, 'status',
                  CustomerServiceStatus.connecting),
          isA<CustomerServiceState>()
              .having((s) => s.status, 'status',
                  CustomerServiceStatus.connected)
              .having((s) => s.chat, 'chat', isNotNull),
        ],
      );

      blocTest<CustomerServiceBloc, CustomerServiceState>(
        'emits error when connection fails',
        build: () {
          when(() => mockRepo.assignCustomerService())
              .thenThrow(Exception('No agents available'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const CustomerServiceConnectRequested()),
        expect: () => [
          isA<CustomerServiceState>()
              .having((s) => s.status, 'status',
                  CustomerServiceStatus.connecting),
          isA<CustomerServiceState>()
              .having((s) => s.status, 'status',
                  CustomerServiceStatus.error)
              .having(
                  (s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('CustomerServiceSendMessage', () {
      blocTest<CustomerServiceBloc, CustomerServiceState>(
        'sends message optimistically then reloads',
        build: () {
          when(() => mockRepo.sendCustomerServiceMessage(any(), any()))
              .thenAnswer((_) async => {'success': true});
          when(() => mockRepo.getCustomerServiceMessages(any()))
              .thenAnswer((_) async => [
                    {
                      'content': 'Hello',
                      'sender_type': 'user',
                      'created_at': '2026-01-01T00:00:00',
                    }
                  ]);
          return bloc;
        },
        seed: () => const CustomerServiceState(
          status: CustomerServiceStatus.connected,
          chat: CustomerServiceChat(
            chatId: 'chat1',
            userId: 'user1',
            serviceId: 'cs1',
          ),
        ),
        act: (bloc) => bloc.add(
            const CustomerServiceSendMessage('Hello')),
        expect: () => [
          isA<CustomerServiceState>()
              .having((s) => s.isSending, 'isSending', isTrue)
              .having((s) => s.messages.length, 'messages.length', 1),
          isA<CustomerServiceState>()
              .having((s) => s.isSending, 'isSending', isFalse),
        ],
      );
    });

    group('CustomerServiceEndChat', () {
      blocTest<CustomerServiceBloc, CustomerServiceState>(
        'ends chat session',
        build: () {
          when(() => mockRepo.endCustomerServiceChat(any()))
              .thenAnswer((_) async {});
          return bloc;
        },
        seed: () => const CustomerServiceState(
          status: CustomerServiceStatus.connected,
          chat: CustomerServiceChat(
            chatId: 'chat1',
            userId: 'user1',
            serviceId: 'cs1',
          ),
        ),
        act: (bloc) =>
            bloc.add(const CustomerServiceEndChat()),
        expect: () => [
          isA<CustomerServiceState>()
              .having((s) => s.status, 'status',
                  CustomerServiceStatus.ended),
        ],
      );

      blocTest<CustomerServiceBloc, CustomerServiceState>(
        'emits error on end chat failure',
        build: () {
          when(() => mockRepo.endCustomerServiceChat(any()))
              .thenThrow(Exception('Failed'));
          return bloc;
        },
        seed: () => const CustomerServiceState(
          status: CustomerServiceStatus.connected,
          chat: CustomerServiceChat(
            chatId: 'chat1',
            userId: 'user1',
            serviceId: 'cs1',
          ),
        ),
        act: (bloc) =>
            bloc.add(const CustomerServiceEndChat()),
        expect: () => [
          isA<CustomerServiceState>()
              .having((s) => s.status, 'status',
                  CustomerServiceStatus.connected)
              .having((s) => s.actionMessage, 'actionMessage',
                  'end_conversation_failed'),
        ],
      );
    });

    group('CustomerServiceRateChat', () {
      blocTest<CustomerServiceBloc, CustomerServiceState>(
        'rates chat session on success',
        build: () {
          when(() => mockRepo.rateCustomerService(
                any(),
                rating: any(named: 'rating'),
                comment: any(named: 'comment'),
              )).thenAnswer((_) async {});
          return bloc;
        },
        seed: () => const CustomerServiceState(
          status: CustomerServiceStatus.ended,
          chat: CustomerServiceChat(
            chatId: 'chat1',
            userId: 'user1',
            serviceId: 'cs1',
          ),
        ),
        act: (bloc) => bloc.add(const CustomerServiceRateChat(
          rating: 5,
          comment: 'Great service',
        )),
        expect: () => [
          isA<CustomerServiceState>()
              .having((s) => s.isRating, 'isRating', isTrue),
          isA<CustomerServiceState>()
              .having((s) => s.isRating, 'isRating', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'feedback_success'),
        ],
      );

      blocTest<CustomerServiceBloc, CustomerServiceState>(
        'emits error on rating failure',
        build: () {
          when(() => mockRepo.rateCustomerService(
                any(),
                rating: any(named: 'rating'),
                comment: any(named: 'comment'),
              )).thenThrow(Exception('Rating failed'));
          return bloc;
        },
        seed: () => const CustomerServiceState(
          status: CustomerServiceStatus.ended,
          chat: CustomerServiceChat(
            chatId: 'chat1',
            userId: 'user1',
            serviceId: 'cs1',
          ),
        ),
        act: (bloc) => bloc.add(const CustomerServiceRateChat(
          rating: 3,
        )),
        expect: () => [
          isA<CustomerServiceState>()
              .having((s) => s.isRating, 'isRating', isTrue),
          isA<CustomerServiceState>()
              .having((s) => s.isRating, 'isRating', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  isNotNull),
        ],
      );
    });

    group('CustomerServiceCheckQueue', () {
      blocTest<CustomerServiceBloc, CustomerServiceState>(
        'checks queue status',
        build: () {
          when(() => mockRepo.getCustomerServiceQueueStatus())
              .thenAnswer((_) async => {
                    'position': 3,
                    'estimated_wait_time': 120,
                    'status': 'waiting',
                  });
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const CustomerServiceCheckQueue()),
        expect: () => [
          isA<CustomerServiceState>()
              .having((s) => s.queueStatus, 'queueStatus', isNotNull),
        ],
      );
    });

    group('CustomerServiceStartNew', () {
      blocTest<CustomerServiceBloc, CustomerServiceState>(
        'resets state for new conversation',
        build: () => bloc,
        seed: () => const CustomerServiceState(
          status: CustomerServiceStatus.ended,
          chat: CustomerServiceChat(
            chatId: 'chat1',
            userId: 'user1',
            serviceId: 'cs1',
          ),
          messages: [
            CustomerServiceMessage(content: 'Old message'),
          ],
        ),
        act: (bloc) =>
            bloc.add(const CustomerServiceStartNew()),
        expect: () => [
          isA<CustomerServiceState>()
              .having((s) => s.status, 'status',
                  CustomerServiceStatus.initial)
              .having((s) => s.messages, 'messages', isEmpty)
              .having((s) => s.chat, 'chat', isNull),
        ],
      );
    });

    group('CustomerServiceLoadMessages', () {
      blocTest<CustomerServiceBloc, CustomerServiceState>(
        'loads chat messages',
        build: () {
          when(() => mockRepo.getCustomerServiceMessages(any()))
              .thenAnswer((_) async => [
                    {
                      'content': 'Hello',
                      'sender_type': 'user',
                      'created_at': '2026-01-01T00:00:00',
                    },
                    {
                      'content': 'Hi there',
                      'sender_type': 'service',
                      'created_at': '2026-01-01T00:01:00',
                    },
                  ]);
          return bloc;
        },
        seed: () => const CustomerServiceState(
          status: CustomerServiceStatus.connected,
          chat: CustomerServiceChat(
            chatId: 'chat1',
            userId: 'user1',
            serviceId: 'cs1',
          ),
        ),
        act: (bloc) =>
            bloc.add(const CustomerServiceLoadMessages('chat1')),
        expect: () => [
          isA<CustomerServiceState>()
              .having((s) => s.messages.length, 'messages.length', 2),
        ],
      );
    });

    group('CustomerServiceState helpers', () {
      test('props include all fields', () {
        const state = CustomerServiceState();
        expect(state.props, isNotEmpty);
      });
    });
  });
}
