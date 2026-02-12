import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/coupon_points.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/coupon_points_repository.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

/// 加载钱包全部数据（积分账户 + 交易记录 + 优惠券 + Stripe Connect 状态 + Connect 余额）
class WalletLoadRequested extends WalletEvent {
  const WalletLoadRequested();
}

/// 加载更多交易记录
class WalletLoadMoreTransactions extends WalletEvent {
  const WalletLoadMoreTransactions();
}

// ==================== State ====================

enum WalletStatus { initial, loading, loaded, error }

class WalletState extends Equatable {
  const WalletState({
    this.status = WalletStatus.initial,
    this.pointsAccount,
    this.connectBalance,
    this.transactions = const [],
    this.coupons = const [],
    this.stripeConnectStatus,
    this.transactionPage = 1,
    this.hasMoreTransactions = true,
    this.errorMessage,
  });

  final WalletStatus status;
  final PointsAccount? pointsAccount;
  final StripeConnectBalance? connectBalance;
  final List<PointsTransaction> transactions;
  final List<UserCoupon> coupons;
  final StripeConnectStatus? stripeConnectStatus;
  final int transactionPage;
  final bool hasMoreTransactions;
  final String? errorMessage;

  bool get isLoading => status == WalletStatus.loading;

  WalletState copyWith({
    WalletStatus? status,
    PointsAccount? pointsAccount,
    StripeConnectBalance? connectBalance,
    List<PointsTransaction>? transactions,
    List<UserCoupon>? coupons,
    StripeConnectStatus? stripeConnectStatus,
    int? transactionPage,
    bool? hasMoreTransactions,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WalletState(
      status: status ?? this.status,
      pointsAccount: pointsAccount ?? this.pointsAccount,
      connectBalance: connectBalance ?? this.connectBalance,
      transactions: transactions ?? this.transactions,
      coupons: coupons ?? this.coupons,
      stripeConnectStatus: stripeConnectStatus ?? this.stripeConnectStatus,
      transactionPage: transactionPage ?? this.transactionPage,
      hasMoreTransactions: hasMoreTransactions ?? this.hasMoreTransactions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        pointsAccount,
        connectBalance,
        transactions,
        coupons,
        stripeConnectStatus,
        transactionPage,
        hasMoreTransactions,
        errorMessage,
      ];
}

// ==================== Bloc ====================

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc({
    required CouponPointsRepository couponPointsRepository,
    required PaymentRepository paymentRepository,
  })  : _couponPointsRepo = couponPointsRepository,
        _paymentRepo = paymentRepository,
        super(const WalletState()) {
    on<WalletLoadRequested>(_onLoadRequested);
    on<WalletLoadMoreTransactions>(_onLoadMore);
  }

  final CouponPointsRepository _couponPointsRepo;
  final PaymentRepository _paymentRepo;

  Future<void> _onLoadRequested(
    WalletLoadRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(status: WalletStatus.loading, clearError: true));

    try {
      final results = await Future.wait([
        _couponPointsRepo.getPointsAccount(),
        _couponPointsRepo.getPointsTransactions(page: 1, pageSize: 20),
        _couponPointsRepo.getMyCoupons(),
        _paymentRepo.getStripeConnectStatus(),
      ]);

      // 尝试加载 Connect 余额（可能无账户 → 404，视为零余额）
      StripeConnectBalance? balance;
      try {
        balance = await _paymentRepo.getStripeConnectBalanceTyped();
      } catch (_) {
        // 无 Connect 账户或 API 错误，balance 保持 null → UI 显示 £0.00
      }

      emit(state.copyWith(
        status: WalletStatus.loaded,
        pointsAccount: results[0] as PointsAccount,
        transactions: results[1] as List<PointsTransaction>,
        coupons: results[2] as List<UserCoupon>,
        stripeConnectStatus: results[3] as StripeConnectStatus,
        connectBalance: balance,
        transactionPage: 1,
        hasMoreTransactions:
            (results[1] as List<PointsTransaction>).length >= 20,
      ));
    } catch (e) {
      AppLogger.error('Failed to load wallet', e);
      emit(state.copyWith(
        status: WalletStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMore(
    WalletLoadMoreTransactions event,
    Emitter<WalletState> emit,
  ) async {
    if (!state.hasMoreTransactions) return;

    try {
      final nextPage = state.transactionPage + 1;
      final more = await _couponPointsRepo.getPointsTransactions(
        page: nextPage,
        pageSize: 20,
      );

      emit(state.copyWith(
        transactions: [...state.transactions, ...more],
        transactionPage: nextPage,
        hasMoreTransactions: more.length >= 20,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more transactions', e);
    }
  }
}
