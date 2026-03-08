import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/coupon_points/bloc/coupon_points_bloc.dart';
import 'package:link2ur/data/models/coupon_points.dart';
import 'package:link2ur/data/repositories/coupon_points_repository.dart';

class MockCouponPointsRepository extends Mock
    implements CouponPointsRepository {}

void main() {
  late MockCouponPointsRepository mockRepo;
  late CouponPointsBloc bloc;

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
      description: 'Check-in',
      createdAt: DateTime(2026),
    ),
    PointsTransaction(
      id: 2,
      type: 'spend',
      amount: -50,
      description: 'Coupon',
      createdAt: DateTime(2026, 1, 2),
    ),
  ];

  const testCoupon = Coupon(
    id: 1,
    code: 'TEST10',
    name: '10% Off',
    type: 'discount',
    discountValue: 10,
    pointsRequired: 100,
  );

  const testUserCoupon = UserCoupon(
    id: 1,
    coupon: testCoupon,
    status: 'unused',
  );

  setUp(() {
    mockRepo = MockCouponPointsRepository();
    bloc = CouponPointsBloc(couponPointsRepository: mockRepo);
  });

  tearDown(() {
    bloc.close();
  });

  group('CouponPointsBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, equals(CouponPointsStatus.initial));
      expect(bloc.state.pointsAccount, equals(const PointsAccount()));
      expect(bloc.state.transactions, isEmpty);
      expect(bloc.state.isSubmitting, isFalse);
    });

    group('CouponPointsLoadRequested', () {
      blocTest<CouponPointsBloc, CouponPointsState>(
        'emits [loading, loaded] with account data when load succeeds',
        build: () {
          when(() => mockRepo.getPointsAccount())
              .thenAnswer((_) async => testAccount);
          when(() => mockRepo.getCheckInStatus())
              .thenAnswer((_) async => {
                    'is_checked_in_today': false,
                    'consecutive_days': 3,
                  });
          when(() => mockRepo.getMyCoupons())
              .thenAnswer((_) async => [testUserCoupon]);
          return bloc;
        },
        act: (bloc) => bloc.add(const CouponPointsLoadRequested()),
        expect: () => [
          const CouponPointsState(status: CouponPointsStatus.loading),
          isA<CouponPointsState>()
              .having((s) => s.status, 'status', CouponPointsStatus.loaded)
              .having(
                  (s) => s.pointsAccount, 'pointsAccount', testAccount)
              .having((s) => s.myCoupons.length, 'myCoupons.length', 1),
        ],
      );

      blocTest<CouponPointsBloc, CouponPointsState>(
        'emits [loading, error] when load fails',
        build: () {
          when(() => mockRepo.getPointsAccount())
              .thenThrow(Exception('Network error'));
          when(() => mockRepo.getCheckInStatus())
              .thenAnswer((_) async => {});
          when(() => mockRepo.getMyCoupons())
              .thenAnswer((_) async => []);
          return bloc;
        },
        act: (bloc) => bloc.add(const CouponPointsLoadRequested()),
        expect: () => [
          const CouponPointsState(status: CouponPointsStatus.loading),
          isA<CouponPointsState>()
              .having(
                  (s) => s.status, 'status', CouponPointsStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('CouponPointsLoadTransactions', () {
      blocTest<CouponPointsBloc, CouponPointsState>(
        'loads transactions successfully',
        build: () {
          when(() => mockRepo.getPointsTransactions(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
              )).thenAnswer((_) async => testTransactions);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const CouponPointsLoadTransactions()),
        expect: () => [
          isA<CouponPointsState>()
              .having((s) => s.transactions.length, 'transactions.length', 2)
              .having((s) => s.hasMoreTransactions, 'hasMoreTransactions',
                  isFalse),
        ],
      );

      blocTest<CouponPointsBloc, CouponPointsState>(
        'loads transactions with type filter',
        build: () {
          when(() => mockRepo.getPointsTransactions(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
              )).thenAnswer((_) async => [testTransactions[0]]);
          return bloc;
        },
        act: (bloc) => bloc.add(
            const CouponPointsLoadTransactions(type: 'earn')),
        expect: () => [
          isA<CouponPointsState>()
              .having((s) => s.transactions.length, 'transactions.length', 1)
              .having((s) => s.currentTransactionType,
                  'currentTransactionType', 'earn'),
        ],
      );
    });

    group('CouponPointsLoadMoreTransactions', () {
      blocTest<CouponPointsBloc, CouponPointsState>(
        'appends more transactions',
        build: () {
          final moreTransactions = [
            PointsTransaction(
              id: 3,
              type: 'earn',
              amount: 30,
              createdAt: DateTime(2026, 1, 3),
            ),
          ];
          when(() => mockRepo.getPointsTransactions(
                page: any(named: 'page'),
                pageSize: any(named: 'pageSize'),
                type: any(named: 'type'),
              )).thenAnswer((_) async => moreTransactions);
          return bloc;
        },
        seed: () => CouponPointsState(
          status: CouponPointsStatus.loaded,
          transactions: testTransactions,
          hasMoreTransactions: true,
        ),
        act: (bloc) =>
            bloc.add(const CouponPointsLoadMoreTransactions()),
        expect: () => [
          isA<CouponPointsState>()
              .having(
                  (s) => s.transactions.length, 'transactions.length', 3)
              .having((s) => s.transactionPage, 'transactionPage', 2),
        ],
      );

      blocTest<CouponPointsBloc, CouponPointsState>(
        'does nothing when hasMoreTransactions is false',
        build: () => bloc,
        seed: () => CouponPointsState(
          status: CouponPointsStatus.loaded,
          transactions: testTransactions,
          hasMoreTransactions: false,
        ),
        act: (bloc) =>
            bloc.add(const CouponPointsLoadMoreTransactions()),
        expect: () => [],
      );
    });

    group('CouponPointsCheckIn', () {
      blocTest<CouponPointsBloc, CouponPointsState>(
        'emits success check-in state',
        build: () {
          when(() => mockRepo.checkIn())
              .thenAnswer((_) async => {'points_earned': 10});
          when(() => mockRepo.getPointsAccount())
              .thenAnswer((_) async => testAccount);
          when(() => mockRepo.getCheckInStatus())
              .thenAnswer((_) async => {
                    'is_checked_in_today': true,
                    'consecutive_days': 4,
                  });
          return bloc;
        },
        act: (bloc) => bloc.add(const CouponPointsCheckIn()),
        expect: () => [
          isA<CouponPointsState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<CouponPointsState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.isCheckedInToday, 'isCheckedInToday', isTrue)
              .having((s) => s.pointsAccount, 'pointsAccount', testAccount),
        ],
      );

      blocTest<CouponPointsBloc, CouponPointsState>(
        'emits error on check-in failure',
        build: () {
          when(() => mockRepo.checkIn())
              .thenThrow(Exception('Check-in failed'));
          return bloc;
        },
        act: (bloc) => bloc.add(const CouponPointsCheckIn()),
        expect: () => [
          isA<CouponPointsState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<CouponPointsState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage', isNotNull),
        ],
      );
    });

    group('CouponPointsLoadAvailableCoupons', () {
      blocTest<CouponPointsBloc, CouponPointsState>(
        'loads available coupons',
        build: () {
          when(() => mockRepo.getAvailableCoupons())
              .thenAnswer((_) async => [testCoupon]);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const CouponPointsLoadAvailableCoupons()),
        expect: () => [
          isA<CouponPointsState>()
              .having((s) => s.availableCoupons.length,
                  'availableCoupons.length', 1),
        ],
      );
    });

    group('CouponPointsClaimCoupon', () {
      blocTest<CouponPointsBloc, CouponPointsState>(
        'claims coupon and refreshes lists on success',
        build: () {
          when(() => mockRepo.claimCoupon(any()))
              .thenAnswer((_) async => {'success': true});
          when(() => mockRepo.getAvailableCoupons())
              .thenAnswer((_) async => []);
          when(() => mockRepo.getMyCoupons(status: any(named: 'status')))
              .thenAnswer((_) async => [testUserCoupon]);
          return bloc;
        },
        act: (bloc) => bloc.add(const CouponPointsClaimCoupon(1)),
        expect: () => [
          // 1. isSubmitting = true
          isA<CouponPointsState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          // 2. isSubmitting = false, actionMessage = 'coupon_claimed'
          isA<CouponPointsState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'coupon_claimed'),
          // 3. CouponPointsLoadMyCoupons refreshes myCoupons (actionMessage resets to null);
          //    LoadAvailableCoupons produces same state (availableCoupons already []) so deduplicated
          isA<CouponPointsState>()
              .having((s) => s.myCoupons.length, 'myCoupons.length', 1)
              .having((s) => s.actionMessage, 'actionMessage', isNull),
        ],
      );

      blocTest<CouponPointsBloc, CouponPointsState>(
        'emits error on claim failure',
        build: () {
          when(() => mockRepo.claimCoupon(any()))
              .thenThrow(Exception('Claim failed'));
          return bloc;
        },
        act: (bloc) => bloc.add(const CouponPointsClaimCoupon(1)),
        expect: () => [
          isA<CouponPointsState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<CouponPointsState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage', isNotNull),
        ],
      );
    });

    group('CouponPointsRedeemCoupon', () {
      blocTest<CouponPointsBloc, CouponPointsState>(
        'redeems coupon and refreshes account on success',
        build: () {
          when(() => mockRepo.redeemCoupon(any()))
              .thenAnswer((_) async => {'success': true});
          when(() => mockRepo.getPointsAccount())
              .thenAnswer((_) async => testAccount);
          when(() => mockRepo.getAvailableCoupons())
              .thenAnswer((_) async => []);
          when(() => mockRepo.getMyCoupons(status: any(named: 'status')))
              .thenAnswer((_) async => []);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const CouponPointsRedeemCoupon(1)),
        expect: () => [
          // 1. isSubmitting = true
          isA<CouponPointsState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          // 2. isSubmitting = false, actionMessage = 'coupon_redeemed', pointsAccount refreshed
          isA<CouponPointsState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'coupon_redeemed')
              .having((s) => s.pointsAccount, 'pointsAccount', testAccount),
          // 3. CouponPointsLoadMyCoupons emits (actionMessage resets to null);
          //    LoadAvailableCoupons produces same state so deduplicated
          isA<CouponPointsState>()
              .having((s) => s.actionMessage, 'actionMessage', isNull),
        ],
      );
    });

    group('CouponPointsUseInvitationCode', () {
      blocTest<CouponPointsBloc, CouponPointsState>(
        'uses invitation code and reloads on success',
        build: () {
          when(() => mockRepo.claimCouponByCode(any()))
              .thenAnswer((_) async => {'success': true});
          when(() => mockRepo.getPointsAccount())
              .thenAnswer((_) async => testAccount);
          when(() => mockRepo.getCheckInStatus())
              .thenAnswer((_) async => {'checked_in_today': false, 'consecutive_days': 0});
          when(() => mockRepo.getMyCoupons(status: any(named: 'status')))
              .thenAnswer((_) async => []);
          return bloc;
        },
        act: (bloc) => bloc.add(
            const CouponPointsUseInvitationCode('INVITE123')),
        expect: () => [
          // 1. isSubmitting = true
          isA<CouponPointsState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          // 2. isSubmitting = false, actionMessage = 'invite_code_used'
          isA<CouponPointsState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'invite_code_used'),
          // 3. CouponPointsLoadRequested emits loading
          isA<CouponPointsState>()
              .having((s) => s.status, 'status', CouponPointsStatus.loading),
          // 4. CouponPointsLoadRequested emits loaded with refreshed data
          isA<CouponPointsState>()
              .having((s) => s.status, 'status', CouponPointsStatus.loaded)
              .having((s) => s.pointsAccount, 'pointsAccount', testAccount),
        ],
      );

      blocTest<CouponPointsBloc, CouponPointsState>(
        'emits error on invalid invitation code',
        build: () {
          when(() => mockRepo.claimCouponByCode(any()))
              .thenThrow(Exception('Invalid code'));
          return bloc;
        },
        act: (bloc) => bloc
            .add(const CouponPointsUseInvitationCode('BAD')),
        expect: () => [
          isA<CouponPointsState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<CouponPointsState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage', isNotNull),
        ],
      );
    });

    group('CouponPointsLoadCheckInStatus', () {
      blocTest<CouponPointsBloc, CouponPointsState>(
        'loads check-in status and rewards',
        build: () {
          when(() => mockRepo.getCheckInStatus())
              .thenAnswer((_) async => {
                    'checked_in_today': true,
                    'consecutive_days': 5,
                  });
          when(() => mockRepo.getCheckInRewards())
              .thenAnswer((_) async => [
                    {'day': 1, 'points': 5},
                    {'day': 2, 'points': 10},
                  ]);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const CouponPointsLoadCheckInStatus()),
        expect: () => [
          isA<CouponPointsState>()
              .having(
                  (s) => s.isCheckedInToday, 'isCheckedInToday', isTrue)
              .having(
                  (s) => s.consecutiveDays, 'consecutiveDays', 5),
        ],
      );
    });

    group('CouponPointsLoadMyCoupons', () {
      blocTest<CouponPointsBloc, CouponPointsState>(
        'loads my coupons with status filter',
        build: () {
          when(() => mockRepo.getMyCoupons(status: any(named: 'status')))
              .thenAnswer((_) async => [testUserCoupon]);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const CouponPointsLoadMyCoupons(status: 'unused')),
        expect: () => [
          isA<CouponPointsState>()
              .having(
                  (s) => s.myCoupons.length, 'myCoupons.length', 1),
        ],
      );
    });
  });
}
