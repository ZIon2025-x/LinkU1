import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/flea_market/bloc/flea_market_bloc.dart';
import 'package:link2ur/data/models/flea_market.dart';
import 'package:link2ur/data/repositories/flea_market_repository.dart';
import 'package:link2ur/features/tasks/bloc/task_detail_bloc.dart' show AcceptPaymentData;

class MockFleaMarketRepository extends Mock
    implements FleaMarketRepository {}

void main() {
  late MockFleaMarketRepository mockRepo;
  late FleaMarketBloc bloc;

  const testItem = FleaMarketItem(
    id: '1',
    title: 'Test Item',
    price: 25.0,
    sellerId: 'seller1',
    status: 'active',
  );

  const testItem2 = FleaMarketItem(
    id: '2',
    title: 'Another Item',
    price: 50.0,
    sellerId: 'seller2',
    status: 'active',
  );

  const testListResponse = FleaMarketListResponse(
    items: [testItem, testItem2],
    total: 2,
    page: 1,
    pageSize: 20,
  );

  const testCreateRequest = CreateFleaMarketRequest(
    title: 'New Item',
    price: 30.0,
  );

  setUpAll(() {
    registerFallbackValue(testCreateRequest);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockRepo = MockFleaMarketRepository();
    bloc = FleaMarketBloc(fleaMarketRepository: mockRepo);
  });

  tearDown(() {
    bloc.close();
  });

  group('FleaMarketBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, equals(FleaMarketStatus.initial));
      expect(bloc.state.items, isEmpty);
      expect(bloc.state.selectedItem, isNull);
      expect(bloc.state.isSubmitting, isFalse);
    });

    group('FleaMarketLoadRequested', () {
      blocTest<FleaMarketBloc, FleaMarketState>(
        'emits [loading, loaded] with items on success',
        build: () {
          when(() => mockRepo.getItems(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                category: any(named: 'category'),
                keyword: any(named: 'keyword'),
              )).thenAnswer((_) async => testListResponse);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const FleaMarketLoadRequested()),
        expect: () => [
          const FleaMarketState(status: FleaMarketStatus.loading),
          isA<FleaMarketState>()
              .having((s) => s.status, 'status',
                  FleaMarketStatus.loaded)
              .having(
                  (s) => s.items.length, 'items.length', 2),
        ],
      );

      blocTest<FleaMarketBloc, FleaMarketState>(
        'emits [loading, error] when load fails',
        build: () {
          when(() => mockRepo.getItems(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                category: any(named: 'category'),
                keyword: any(named: 'keyword'),
              )).thenThrow(Exception('Network error'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const FleaMarketLoadRequested()),
        expect: () => [
          const FleaMarketState(status: FleaMarketStatus.loading),
          isA<FleaMarketState>()
              .having((s) => s.status, 'status',
                  FleaMarketStatus.error)
              .having(
                  (s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('FleaMarketLoadMore', () {
      blocTest<FleaMarketBloc, FleaMarketState>(
        'appends more items',
        build: () {
          when(() => mockRepo.getItems(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                category: any(named: 'category'),
                keyword: any(named: 'keyword'),
              )).thenAnswer((_) async => const FleaMarketListResponse(
                items: [testItem2],
                total: 3,
                page: 2,
                pageSize: 20,
              ));
          return bloc;
        },
        seed: () => const FleaMarketState(
          status: FleaMarketStatus.loaded,
          items: [testItem],
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const FleaMarketLoadMore()),
        expect: () => [
          isA<FleaMarketState>()
              .having(
                  (s) => s.isLoadingMore, 'isLoadingMore', isTrue),
          isA<FleaMarketState>()
              .having(
                  (s) => s.items.length, 'items.length', 2)
              .having((s) => s.page, 'page', 2)
              .having(
                  (s) => s.isLoadingMore, 'isLoadingMore', isFalse),
        ],
      );

      blocTest<FleaMarketBloc, FleaMarketState>(
        'does nothing when hasMore is false',
        build: () => bloc,
        seed: () => const FleaMarketState(
          status: FleaMarketStatus.loaded,
          items: [testItem],
          hasMore: false,
        ),
        act: (bloc) => bloc.add(const FleaMarketLoadMore()),
        expect: () => [],
      );
    });

    group('FleaMarketCategoryChanged', () {
      blocTest<FleaMarketBloc, FleaMarketState>(
        'updates category and reloads',
        build: () {
          when(() => mockRepo.getItems(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                category: any(named: 'category'),
                keyword: any(named: 'keyword'),
              )).thenAnswer((_) async => const FleaMarketListResponse(
                items: [testItem],
                total: 1,
                page: 1,
                pageSize: 20,
              ));
          return bloc;
        },
        act: (bloc) => bloc.add(
            const FleaMarketCategoryChanged('electronics')),
        expect: () => [
          isA<FleaMarketState>()
              .having((s) => s.selectedCategory, 'selectedCategory',
                  'electronics')
              .having((s) => s.status, 'status',
                  FleaMarketStatus.loading),
          isA<FleaMarketState>()
              .having((s) => s.status, 'status',
                  FleaMarketStatus.loaded),
        ],
      );
    });

    group('FleaMarketCreateItem', () {
      blocTest<FleaMarketBloc, FleaMarketState>(
        'creates item and refreshes list on success',
        build: () {
          when(() => mockRepo.createItem(any()))
              .thenAnswer((_) async => '1');
          when(() => mockRepo.getItems(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                category: any(named: 'category'),
                keyword: any(named: 'keyword'),
              )).thenAnswer((_) async => testListResponse);
          return bloc;
        },
        act: (bloc) => bloc.add(
            FleaMarketCreateItem(testCreateRequest)),
        expect: () => [
          isA<FleaMarketState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<FleaMarketState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'item_published'),
          // FleaMarketRefreshRequested is triggered after create
          isA<FleaMarketState>()
              .having(
                  (s) => s.isRefreshing, 'isRefreshing', isTrue),
          isA<FleaMarketState>()
              .having((s) => s.status, 'status',
                  FleaMarketStatus.loaded)
              .having(
                  (s) => s.isRefreshing, 'isRefreshing', isFalse)
              .having(
                  (s) => s.items.length, 'items.length', 2),
        ],
      );

      blocTest<FleaMarketBloc, FleaMarketState>(
        'emits error on create failure',
        build: () {
          when(() => mockRepo.createItem(any()))
              .thenThrow(Exception('Create failed'));
          return bloc;
        },
        act: (bloc) => bloc.add(
            FleaMarketCreateItem(testCreateRequest)),
        expect: () => [
          isA<FleaMarketState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<FleaMarketState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  isNotNull),
        ],
      );
    });

    group('FleaMarketLoadDetailRequested', () {
      blocTest<FleaMarketBloc, FleaMarketState>(
        'loads item detail with favorite status',
        build: () {
          when(() => mockRepo.getItemById(any()))
              .thenAnswer((_) async => testItem);
          when(() => mockRepo.getFavoriteItems(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => const FleaMarketListResponse(
                items: [testItem],
                total: 1,
                page: 1,
                pageSize: 100,
              ));
          return bloc;
        },
        act: (bloc) => bloc.add(
            const FleaMarketLoadDetailRequested('1')),
        expect: () => [
          isA<FleaMarketState>()
              .having((s) => s.detailStatus, 'detailStatus',
                  FleaMarketStatus.loading),
          isA<FleaMarketState>()
              .having((s) => s.detailStatus, 'detailStatus',
                  FleaMarketStatus.loaded)
              .having(
                  (s) => s.selectedItem, 'selectedItem', testItem),
          isA<FleaMarketState>()
              .having(
                  (s) => s.isFavorited, 'isFavorited', isTrue),
        ],
      );
    });

    group('FleaMarketToggleFavorite', () {
      blocTest<FleaMarketBloc, FleaMarketState>(
        'toggles favorite optimistically',
        build: () {
          when(() => mockRepo.toggleFavorite(any()))
              .thenAnswer((_) async => true);
          return bloc;
        },
        seed: () => const FleaMarketState(
          status: FleaMarketStatus.loaded,
          selectedItem: testItem,
          isFavorited: false,
        ),
        act: (bloc) => bloc.add(
            const FleaMarketToggleFavorite('1')),
        expect: () => [
          isA<FleaMarketState>()
              .having((s) => s.isFavorited, 'isFavorited', isTrue)
              .having((s) => s.isTogglingFavorite, 'isTogglingFavorite', isTrue),
          isA<FleaMarketState>()
              .having((s) => s.isFavorited, 'isFavorited', isTrue)
              .having((s) => s.isTogglingFavorite, 'isTogglingFavorite', isFalse),
        ],
      );
    });

    group('FleaMarketDeleteItem', () {
      blocTest<FleaMarketBloc, FleaMarketState>(
        'deletes item and removes from list',
        build: () {
          when(() => mockRepo.deleteItem(any()))
              .thenAnswer((_) async {});
          return bloc;
        },
        seed: () => const FleaMarketState(
          status: FleaMarketStatus.loaded,
          items: [testItem, testItem2],
        ),
        act: (bloc) =>
            bloc.add(const FleaMarketDeleteItem('1')),
        expect: () => [
          isA<FleaMarketState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<FleaMarketState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having(
                  (s) => s.items.length, 'items.length', 1)
              .having((s) => s.actionMessage, 'actionMessage',
                  'item_deleted'),
        ],
      );

      blocTest<FleaMarketBloc, FleaMarketState>(
        'emits error on delete failure',
        build: () {
          when(() => mockRepo.deleteItem(any()))
              .thenThrow(Exception('Delete failed'));
          return bloc;
        },
        seed: () => const FleaMarketState(
          status: FleaMarketStatus.loaded,
          items: [testItem],
        ),
        act: (bloc) =>
            bloc.add(const FleaMarketDeleteItem('1')),
        expect: () => [
          isA<FleaMarketState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<FleaMarketState>()
              .having(
                  (s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  isNotNull),
        ],
      );
    });

    group('FleaMarketUploadImage', () {
      blocTest<FleaMarketBloc, FleaMarketState>(
        'uploads image and stores URL',
        build: () {
          when(() => mockRepo.uploadImage(any(), any(),
                  itemId: any(named: 'itemId')))
              .thenAnswer(
                  (_) async => 'https://example.com/image.jpg');
          return bloc;
        },
        act: (bloc) => bloc.add(FleaMarketUploadImage(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          filename: 'test.jpg',
        )),
        expect: () => [
          isA<FleaMarketState>()
              .having((s) => s.isUploadingImage,
                  'isUploadingImage', isTrue),
          isA<FleaMarketState>()
              .having((s) => s.isUploadingImage,
                  'isUploadingImage', isFalse)
              .having((s) => s.uploadedImageUrl,
                  'uploadedImageUrl',
                  'https://example.com/image.jpg'),
        ],
      );
    });

    group('FleaMarketClearAcceptPaymentData', () {
      blocTest<FleaMarketBloc, FleaMarketState>(
        'clears payment data',
        build: () => bloc,
        seed: () => const FleaMarketState(
          acceptPaymentData: AcceptPaymentData(
            taskId: 1,
            clientSecret: 'secret',
            customerId: 'cust_1',
            ephemeralKeySecret: 'ek_1',
          ),
        ),
        act: (bloc) =>
            bloc.add(const FleaMarketClearAcceptPaymentData()),
        expect: () => [
          isA<FleaMarketState>()
              .having((s) => s.acceptPaymentData,
                  'acceptPaymentData', isNull),
        ],
      );
    });

    group('FleaMarketRefreshRequested', () {
      blocTest<FleaMarketBloc, FleaMarketState>(
        'refreshes list from page 1',
        build: () {
          when(() => mockRepo.getItems(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                category: any(named: 'category'),
                keyword: any(named: 'keyword'),
              )).thenAnswer((_) async => testListResponse);
          return bloc;
        },
        seed: () => const FleaMarketState(
          status: FleaMarketStatus.loaded,
          items: [testItem],
          page: 3,
        ),
        act: (bloc) =>
            bloc.add(const FleaMarketRefreshRequested()),
        expect: () => [
          isA<FleaMarketState>()
              .having(
                  (s) => s.isRefreshing, 'isRefreshing', isTrue),
          isA<FleaMarketState>()
              .having((s) => s.status, 'status',
                  FleaMarketStatus.loaded)
              .having(
                  (s) => s.isRefreshing, 'isRefreshing', isFalse)
              .having(
                  (s) => s.items.length, 'items.length', 2)
              .having((s) => s.page, 'page', 1),
        ],
      );
    });

    group('FleaMarketState helpers', () {
      test('isLoading returns true for loading status', () {
        const state =
            FleaMarketState(status: FleaMarketStatus.loading);
        expect(state.isLoading, isTrue);
      });
    });
  });
}
