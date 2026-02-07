import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/payment/bloc/payment_bloc.dart';
import 'package:link2ur/data/models/payment.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  late MockPaymentRepository mockPaymentRepository;
  late PaymentBloc paymentBloc;

  setUp(() {
    mockPaymentRepository = MockPaymentRepository();
    paymentBloc = PaymentBloc(paymentRepository: mockPaymentRepository);
    registerFallbackValues();
  });

  tearDown(() {
    paymentBloc.close();
  });

  group('PaymentBloc', () {
    final testPaymentResponse = TaskPaymentResponse(
      originalAmount: 9999, // 99.99 pounds in pence
      finalAmount: 8999, // 89.99 pounds in pence
      currency: 'GBP',
      clientSecret: 'pi_test_secret',
      customerId: 'cus_test',
      ephemeralKeySecret: 'ek_test_secret',
      originalAmountDisplay: '£99.99',
      finalAmountDisplay: '£89.99',
    );

    test('initial state is correct', () {
      expect(paymentBloc.state.status, equals(PaymentStatus.initial));
      expect(paymentBloc.state.paymentResponse, isNull);
    });

    group('PaymentCreateIntent', () {
      blocTest<PaymentBloc, PaymentState>(
        'emits [loading, ready] when creating payment intent succeeds',
        build: () {
          when(() => mockPaymentRepository.createPaymentIntent(
                taskId: any(named: 'taskId'),
                couponId: any(named: 'couponId'),
                preferredPaymentMethod: any(named: 'preferredPaymentMethod'),
              )).thenAnswer((_) async => testPaymentResponse);
          return paymentBloc;
        },
        act: (bloc) => bloc.add(const PaymentCreateIntent(
          taskId: 1,
          preferredPaymentMethod: 'card',
        )),
        expect: () => [
          const PaymentState(status: PaymentStatus.loading),
          PaymentState(
            status: PaymentStatus.ready,
            paymentResponse: testPaymentResponse,
            preferredPaymentMethod: 'card',
          ),
        ],
        verify: (_) {
          verify(() => mockPaymentRepository.createPaymentIntent(
                taskId: 1,
                couponId: null,
                preferredPaymentMethod: 'card',
              )).called(1);
        },
      );

      blocTest<PaymentBloc, PaymentState>(
        'emits [loading, error] when creating payment intent fails',
        build: () {
          when(() => mockPaymentRepository.createPaymentIntent(
                taskId: any(named: 'taskId'),
                couponId: any(named: 'couponId'),
                preferredPaymentMethod: any(named: 'preferredPaymentMethod'),
              )).thenThrow(Exception('Payment intent creation failed'));
          return paymentBloc;
        },
        act: (bloc) => bloc.add(const PaymentCreateIntent(
          taskId: 1,
          preferredPaymentMethod: 'card',
        )),
        expect: () => [
          const PaymentState(status: PaymentStatus.loading),
          const PaymentState(
            status: PaymentStatus.error,
            errorMessage: 'Payment intent creation failed',
          ),
        ],
      );

      blocTest<PaymentBloc, PaymentState>(
        'does not reset UI when switching payment method',
        build: () {
          when(() => mockPaymentRepository.createPaymentIntent(
                taskId: any(named: 'taskId'),
                couponId: any(named: 'couponId'),
                preferredPaymentMethod: any(named: 'preferredPaymentMethod'),
              )).thenAnswer((_) async => testPaymentResponse);
          return paymentBloc;
        },
        seed: () => PaymentState(
          status: PaymentStatus.ready,
          paymentResponse: testPaymentResponse,
          preferredPaymentMethod: 'card',
        ),
        act: (bloc) => bloc.add(const PaymentCreateIntent(
          taskId: 1,
          preferredPaymentMethod: 'alipay',
          isMethodSwitch: true,
        )),
        expect: () => [
          PaymentState(
            status: PaymentStatus.ready,
            paymentResponse: testPaymentResponse,
            preferredPaymentMethod: 'card',
            isMethodSwitching: true,
          ),
          PaymentState(
            status: PaymentStatus.ready,
            paymentResponse: testPaymentResponse,
            preferredPaymentMethod: 'alipay',
            isMethodSwitching: false,
          ),
        ],
      );
    });

    group('PaymentSelectCoupon', () {
      blocTest<PaymentBloc, PaymentState>(
        'updates selected coupon',
        build: () => paymentBloc,
        act: (bloc) => bloc.add(const PaymentSelectCoupon(
          couponId: 123,
          couponName: 'SUMMER20',
        )),
        expect: () => [
          const PaymentState(
            selectedCouponId: 123,
            selectedCouponName: 'SUMMER20',
          ),
        ],
      );
    });

    group('PaymentRemoveCoupon', () {
      blocTest<PaymentBloc, PaymentState>(
        'clears selected coupon',
        build: () => paymentBloc,
        seed: () => const PaymentState(
          selectedCouponId: 123,
          selectedCouponName: 'SUMMER20',
        ),
        act: (bloc) => bloc.add(const PaymentRemoveCoupon()),
        expect: () => [
          const PaymentState(
            selectedCouponId: null,
            selectedCouponName: null,
          ),
        ],
      );
    });

    group('PaymentMarkSuccess', () {
      blocTest<PaymentBloc, PaymentState>(
        'transitions to success state',
        build: () => paymentBloc,
        seed: () => PaymentState(
          status: PaymentStatus.processing,
          paymentResponse: testPaymentResponse,
        ),
        act: (bloc) => bloc.add(const PaymentMarkSuccess()),
        expect: () => [
          PaymentState(
            status: PaymentStatus.success,
            paymentResponse: testPaymentResponse,
          ),
        ],
      );
    });

    group('PaymentMarkFailed', () {
      blocTest<PaymentBloc, PaymentState>(
        'transitions to error state with error message',
        build: () => paymentBloc,
        seed: () => PaymentState(
          status: PaymentStatus.processing,
          paymentResponse: testPaymentResponse,
        ),
        act: (bloc) => bloc.add(const PaymentMarkFailed('Payment declined')),
        expect: () => [
          PaymentState(
            status: PaymentStatus.error,
            paymentResponse: testPaymentResponse,
            errorMessage: 'Payment declined',
          ),
        ],
      );
    });

    group('PaymentStartProcessing', () {
      blocTest<PaymentBloc, PaymentState>(
        'transitions to processing state',
        build: () => paymentBloc,
        seed: () => PaymentState(
          status: PaymentStatus.ready,
          paymentResponse: testPaymentResponse,
        ),
        act: (bloc) => bloc.add(const PaymentStartProcessing()),
        expect: () => [
          PaymentState(
            status: PaymentStatus.processing,
            paymentResponse: testPaymentResponse,
          ),
        ],
      );
    });

    group('PaymentCheckStatus', () {
      blocTest<PaymentBloc, PaymentState>(
        'emits success when payment status is paid',
        build: () {
          when(() => mockPaymentRepository.getTaskPaymentStatus(any()))
              .thenAnswer((_) async => {'status': 'paid'});
          return paymentBloc;
        },
        act: (bloc) => bloc.add(const PaymentCheckStatus(1)),
        expect: () => [
          const PaymentState(status: PaymentStatus.success),
        ],
      );

      blocTest<PaymentBloc, PaymentState>(
        'does not change state when payment is still pending',
        build: () {
          when(() => mockPaymentRepository.getTaskPaymentStatus(any()))
              .thenAnswer((_) async => {'status': 'pending'});
          return paymentBloc;
        },
        act: (bloc) => bloc.add(const PaymentCheckStatus(1)),
        expect: () => [],
      );
    });
  });
}
