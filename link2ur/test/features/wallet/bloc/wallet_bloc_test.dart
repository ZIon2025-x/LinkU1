import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/wallet/bloc/wallet_bloc.dart';
import 'package:link2ur/data/models/coupon_points.dart';
import 'package:link2ur/data/models/payment.dart';
import 'package:link2ur/data/repositories/coupon_points_repository.dart';
import 'package:link2ur/data/repositories/payment_repository.dart';

class MockCouponPointsRepository extends Mock
    implements CouponPointsRepository {}

class MockPaymentRepository extends Mock implements PaymentRepository {}

void main() {
  late MockCouponPointsRepository mockCouponPointsRepo;
  late MockPaymentRepository mockPaymentRepo;
  late WalletBloc walletBloc;

  const testAccount = PointsAccount(
    balance: 500,
    balanceDisplay: '500',
    totalEarned: 1000,
    totalSpent: 500,
  );

  final testTransactions = [
    PointsTransaction(
      id: 1,
      type: 'earn',
      amount: 100,
      description: 'Daily check-in',
      createdAt: DateTime(2026),
    ),
    PointsTransaction(
      id: 2,
      type: 'spend',
      amount: -50,
      description: 'Coupon exchange',
      createdAt: DateTime(2026, 1, 2),
    ),
  ];

  const testCoupons = <UserCoupon>[];

  const testStripeStatus = StripeConnectStatus(
    isConnected: true,
    accountId: 'acct_test',
    chargesEnabled: true,
    payoutsEnabled: true,
  );

  setUp(() {
    mockCouponPointsRepo = MockCouponPointsRepository();
    mockPaymentRepo = MockPaymentRepository();
    walletBloc = WalletBloc(
      couponPointsRepository: mockCouponPointsRepo,
      paymentRepository: mockPaymentRepo,
    );
  });

  tearDown(() {
    walletBloc.close();
  });

  group('WalletBloc', () {
    test('initial state is correct', () {
      expect(walletBloc.state.status, equals(WalletStatus.initial));
      expect(walletBloc.state.pointsAccount, isNull);
      expect(walletBloc.state.transactions, isEmpty);
      expect(walletBloc.state.coupons, isEmpty);
      expect(walletBloc.state.stripeConnectStatus, isNull);
      expect(walletBloc.state.connectBalance, isNull);
    });

    // ==================== WalletLoadRequested ====================

    group('WalletLoadRequested', () {
      blocTest<WalletBloc, WalletState>(
        'emits [loading, loaded] with all data when load succeeds',
        build: () {
          when(() => mockCouponPointsRepo.getPointsAccount())
              .thenAnswer((_) async => testAccount);
          when(() => mockCouponPointsRepo.getPointsTransactions(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => testTransactions);
          when(() => mockCouponPointsRepo.getMyCoupons())
              .thenAnswer((_) async => testCoupons);
          when(() => mockPaymentRepo.getStripeConnectStatus())
              .thenAnswer((_) async => testStripeStatus);
          when(() => mockPaymentRepo.getStripeConnectBalanceTyped())
              .thenThrow(Exception('No connect account'));
          return walletBloc;
        },
        act: (bloc) => bloc.add(const WalletLoadRequested()),
        expect: () => [
          const WalletState(status: WalletStatus.loading),
          WalletState(
            status: WalletStatus.loaded,
            pointsAccount: testAccount,
            transactions: testTransactions,
            stripeConnectStatus: testStripeStatus,
            hasMoreTransactions: false, // 2 < 20
          ),
        ],
        verify: (_) {
          verify(() => mockCouponPointsRepo.getPointsAccount()).called(1);
          verify(() => mockCouponPointsRepo.getPointsTransactions(
                
              )).called(1);
          verify(() => mockCouponPointsRepo.getMyCoupons()).called(1);
          verify(() => mockPaymentRepo.getStripeConnectStatus()).called(1);
        },
      );

      blocTest<WalletBloc, WalletState>(
        'sets hasMoreTransactions=true when 20+ transactions returned',
        build: () {
          // 生成 20 条交易记录
          final fullPage = List.generate(
            20,
            (i) => PointsTransaction(
              id: i,
              type: 'earn',
              amount: 10,
              createdAt: DateTime(2026),
            ),
          );
          when(() => mockCouponPointsRepo.getPointsAccount())
              .thenAnswer((_) async => testAccount);
          when(() => mockCouponPointsRepo.getPointsTransactions(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => fullPage);
          when(() => mockCouponPointsRepo.getMyCoupons())
              .thenAnswer((_) async => testCoupons);
          when(() => mockPaymentRepo.getStripeConnectStatus())
              .thenAnswer((_) async => testStripeStatus);
          when(() => mockPaymentRepo.getStripeConnectBalanceTyped())
              .thenThrow(Exception('No connect account'));
          return walletBloc;
        },
        act: (bloc) => bloc.add(const WalletLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.hasMoreTransactions, isTrue);
        },
      );

      blocTest<WalletBloc, WalletState>(
        'emits [loading, error] when load fails',
        build: () {
          when(() => mockCouponPointsRepo.getPointsAccount())
              .thenThrow(Exception('Network error'));
          when(() => mockCouponPointsRepo.getPointsTransactions(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => []);
          when(() => mockCouponPointsRepo.getMyCoupons())
              .thenAnswer((_) async => []);
          when(() => mockPaymentRepo.getStripeConnectStatus())
              .thenAnswer((_) async => testStripeStatus);
          return walletBloc;
        },
        act: (bloc) => bloc.add(const WalletLoadRequested()),
        expect: () => [
          const WalletState(status: WalletStatus.loading),
          isA<WalletState>()
              .having((s) => s.status, 'status', WalletStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    // ==================== WalletLoadMoreTransactions ====================

    group('WalletLoadMoreTransactions', () {
      final moreTransactions = [
        PointsTransaction(
          id: 3,
          type: 'earn',
          amount: 30,
          createdAt: DateTime(2026, 1, 3),
        ),
      ];

      blocTest<WalletBloc, WalletState>(
        'appends new transactions and increments page',
        build: () {
          when(() => mockCouponPointsRepo.getPointsTransactions(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenAnswer((_) async => moreTransactions);
          return walletBloc;
        },
        seed: () => WalletState(
          status: WalletStatus.loaded,
          transactions: testTransactions,
        ),
        act: (bloc) => bloc.add(const WalletLoadMoreTransactions()),
        expect: () => [
          WalletState(
            status: WalletStatus.loaded,
            transactions: [...testTransactions, ...moreTransactions],
            transactionPage: 2,
            hasMoreTransactions: false, // 1 < 20
          ),
        ],
      );

      blocTest<WalletBloc, WalletState>(
        'does nothing when hasMoreTransactions is false',
        build: () => walletBloc,
        seed: () => WalletState(
          status: WalletStatus.loaded,
          transactions: testTransactions,
          hasMoreTransactions: false,
        ),
        act: (bloc) => bloc.add(const WalletLoadMoreTransactions()),
        expect: () => [], // 不应该有新状态
      );

      blocTest<WalletBloc, WalletState>(
        'emits state with errorMessage on load more failure',
        build: () {
          when(() => mockCouponPointsRepo.getPointsTransactions(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
              )).thenThrow(Exception('Network error'));
          return walletBloc;
        },
        seed: () => WalletState(
          status: WalletStatus.loaded,
          transactions: testTransactions,
        ),
        act: (bloc) => bloc.add(const WalletLoadMoreTransactions()),
        expect: () => [
          WalletState(
            status: WalletStatus.loaded,
            transactions: testTransactions,
            transactionPage: 1,
            hasMoreTransactions: true,
            errorMessage: 'Exception: Network error',
          ),
        ],
      );
    });

    // ==================== WalletState helpers ====================

    group('WalletState', () {
      test('isLoading returns true for loading status', () {
        const state = WalletState(status: WalletStatus.loading);
        expect(state.isLoading, isTrue);
      });

      test('isLoading returns false for loaded status', () {
        const state = WalletState(status: WalletStatus.loaded);
        expect(state.isLoading, isFalse);
      });

      test('copyWith clearError resets errorMessage', () {
        const state = WalletState(
          status: WalletStatus.error,
          errorMessage: 'some error',
        );
        final cleared = state.copyWith(
          status: WalletStatus.loading,
          clearError: true,
        );
        expect(cleared.errorMessage, isNull);
      });
    });
  });
}
