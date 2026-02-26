import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/coupon_points.dart';
import '../../../data/repositories/coupon_points_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class CouponPointsEvent extends Equatable {
  const CouponPointsEvent();

  @override
  List<Object?> get props => [];
}

/// 加载积分账户信息
class CouponPointsLoadRequested extends CouponPointsEvent {
  const CouponPointsLoadRequested();
}

/// 加载积分交易记录
class CouponPointsLoadTransactions extends CouponPointsEvent {
  const CouponPointsLoadTransactions({this.type});

  final String? type;

  @override
  List<Object?> get props => [type];
}

/// 加载更多交易记录
class CouponPointsLoadMoreTransactions extends CouponPointsEvent {
  const CouponPointsLoadMoreTransactions();
}

/// 执行签到
class CouponPointsCheckIn extends CouponPointsEvent {
  const CouponPointsCheckIn();
}

/// 加载签到状态
class CouponPointsLoadCheckInStatus extends CouponPointsEvent {
  const CouponPointsLoadCheckInStatus();
}

/// 加载可用优惠券
class CouponPointsLoadAvailableCoupons extends CouponPointsEvent {
  const CouponPointsLoadAvailableCoupons();
}

/// 加载我的优惠券
class CouponPointsLoadMyCoupons extends CouponPointsEvent {
  const CouponPointsLoadMyCoupons({this.status});

  final String? status;

  @override
  List<Object?> get props => [status];
}

/// 领取优惠券
class CouponPointsClaimCoupon extends CouponPointsEvent {
  const CouponPointsClaimCoupon(this.couponId);

  final int couponId;

  @override
  List<Object?> get props => [couponId];
}

/// 积分兑换优惠券
class CouponPointsRedeemCoupon extends CouponPointsEvent {
  const CouponPointsRedeemCoupon(this.couponId);

  final int couponId;

  @override
  List<Object?> get props => [couponId];
}

/// 使用邀请码
class CouponPointsUseInvitationCode extends CouponPointsEvent {
  const CouponPointsUseInvitationCode(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

// ==================== State ====================

enum CouponPointsStatus { initial, loading, loaded, error }

class CouponPointsState extends Equatable {
  const CouponPointsState({
    this.status = CouponPointsStatus.initial,
    this.pointsAccount = const PointsAccount(),
    this.transactions = const [],
    this.transactionPage = 1,
    this.hasMoreTransactions = true,
    this.availableCoupons = const [],
    this.myCoupons = const [],
    this.checkInStatus,
    this.checkInRewards = const [],
    this.isCheckedInToday = false,
    this.consecutiveDays = 0,
    this.errorMessage,
    this.isSubmitting = false,
    this.actionMessage,
  });

  final CouponPointsStatus status;
  final PointsAccount pointsAccount;
  final List<PointsTransaction> transactions;
  final int transactionPage;
  final bool hasMoreTransactions;
  final List<Coupon> availableCoupons;
  final List<UserCoupon> myCoupons;
  final Map<String, dynamic>? checkInStatus;
  final List<Map<String, dynamic>> checkInRewards;
  final bool isCheckedInToday;
  final int consecutiveDays;
  final String? errorMessage;
  final bool isSubmitting;
  final String? actionMessage;

  bool get isLoading => status == CouponPointsStatus.loading;

  CouponPointsState copyWith({
    CouponPointsStatus? status,
    PointsAccount? pointsAccount,
    List<PointsTransaction>? transactions,
    int? transactionPage,
    bool? hasMoreTransactions,
    List<Coupon>? availableCoupons,
    List<UserCoupon>? myCoupons,
    Map<String, dynamic>? checkInStatus,
    List<Map<String, dynamic>>? checkInRewards,
    bool? isCheckedInToday,
    int? consecutiveDays,
    String? errorMessage,
    bool? isSubmitting,
    String? actionMessage,
  }) {
    return CouponPointsState(
      status: status ?? this.status,
      pointsAccount: pointsAccount ?? this.pointsAccount,
      transactions: transactions ?? this.transactions,
      transactionPage: transactionPage ?? this.transactionPage,
      hasMoreTransactions: hasMoreTransactions ?? this.hasMoreTransactions,
      availableCoupons: availableCoupons ?? this.availableCoupons,
      myCoupons: myCoupons ?? this.myCoupons,
      checkInStatus: checkInStatus ?? this.checkInStatus,
      checkInRewards: checkInRewards ?? this.checkInRewards,
      isCheckedInToday: isCheckedInToday ?? this.isCheckedInToday,
      consecutiveDays: consecutiveDays ?? this.consecutiveDays,
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        pointsAccount,
        transactions,
        transactionPage,
        hasMoreTransactions,
        availableCoupons,
        myCoupons,
        checkInStatus,
        checkInRewards,
        isCheckedInToday,
        consecutiveDays,
        errorMessage,
        isSubmitting,
        actionMessage,
      ];
}

// ==================== Bloc ====================

class CouponPointsBloc extends Bloc<CouponPointsEvent, CouponPointsState> {
  CouponPointsBloc({required CouponPointsRepository couponPointsRepository})
      : _repository = couponPointsRepository,
        super(const CouponPointsState()) {
    on<CouponPointsLoadRequested>(_onLoadRequested);
    on<CouponPointsLoadTransactions>(_onLoadTransactions);
    on<CouponPointsLoadMoreTransactions>(_onLoadMoreTransactions);
    on<CouponPointsCheckIn>(_onCheckIn);
    on<CouponPointsLoadCheckInStatus>(_onLoadCheckInStatus);
    on<CouponPointsLoadAvailableCoupons>(_onLoadAvailableCoupons);
    on<CouponPointsLoadMyCoupons>(_onLoadMyCoupons);
    on<CouponPointsClaimCoupon>(_onClaimCoupon);
    on<CouponPointsRedeemCoupon>(_onRedeemCoupon);
    on<CouponPointsUseInvitationCode>(_onUseInvitationCode);
  }

  final CouponPointsRepository _repository;

  /// 加载积分账户 + 签到状态 + 我的优惠券
  Future<void> _onLoadRequested(
    CouponPointsLoadRequested event,
    Emitter<CouponPointsState> emit,
  ) async {
    emit(state.copyWith(status: CouponPointsStatus.loading));

    try {
      final results = await Future.wait([
        _repository.getPointsAccount(),
        _repository.getCheckInStatus(),
        _repository.getMyCoupons(),
      ]);

      final account = results[0] as PointsAccount;
      final checkInData = results[1] as Map<String, dynamic>;
      final myCoupons = results[2] as List<UserCoupon>;

      emit(state.copyWith(
        status: CouponPointsStatus.loaded,
        pointsAccount: account,
        checkInStatus: checkInData,
        isCheckedInToday: checkInData['checked_in_today'] as bool? ?? false,
        consecutiveDays: checkInData['consecutive_days'] as int? ?? 0,
        myCoupons: myCoupons,
      ));
    } catch (e) {
      AppLogger.error('Failed to load coupon points', e);
      emit(state.copyWith(
        status: CouponPointsStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// 加载交易记录
  Future<void> _onLoadTransactions(
    CouponPointsLoadTransactions event,
    Emitter<CouponPointsState> emit,
  ) async {
    try {
      final transactions = await _repository.getPointsTransactions(
        type: event.type,
      );

      emit(state.copyWith(
        transactions: transactions,
        transactionPage: 1,
        hasMoreTransactions: transactions.length >= 20,
      ));
    } catch (e) {
      AppLogger.error('Failed to load transactions', e);
    }
  }

  /// 加载更多交易记录
  Future<void> _onLoadMoreTransactions(
    CouponPointsLoadMoreTransactions event,
    Emitter<CouponPointsState> emit,
  ) async {
    if (!state.hasMoreTransactions) return;

    try {
      final nextPage = state.transactionPage + 1;
      final transactions = await _repository.getPointsTransactions(
        page: nextPage,
      );

      emit(state.copyWith(
        transactions: [...state.transactions, ...transactions],
        transactionPage: nextPage,
        hasMoreTransactions: transactions.length >= 20,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more transactions', e);
    }
  }

  /// 签到
  Future<void> _onCheckIn(
    CouponPointsCheckIn event,
    Emitter<CouponPointsState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      final checkInResult = await _repository.checkIn();

      // 刷新数据
      final results = await Future.wait([
        _repository.getPointsAccount(),
        _repository.getCheckInStatus(),
      ]);

      final account = results[0] as PointsAccount;
      final checkInData = results[1] as Map<String, dynamic>;
      final alreadyChecked = checkInResult['already_checked'] as bool? ?? false;

      emit(state.copyWith(
        isSubmitting: false,
        pointsAccount: account,
        checkInStatus: checkInData,
        isCheckedInToday: true,
        consecutiveDays: checkInData['consecutive_days'] as int? ?? 0,
        actionMessage: alreadyChecked ? 'check_in_already' : 'check_in_success',
      ));
    } catch (e) {
      final errMsg = e.toString().replaceAll('CouponPointsException: ', '');
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'check_in_failed',
        errorMessage: errMsg,
      ));
    }
  }

  /// 加载签到状态
  Future<void> _onLoadCheckInStatus(
    CouponPointsLoadCheckInStatus event,
    Emitter<CouponPointsState> emit,
  ) async {
    try {
      final results = await Future.wait([
        _repository.getCheckInStatus(),
        _repository.getCheckInRewards(),
      ]);

      final checkInData = results[0] as Map<String, dynamic>;
      final rewards = results[1] as List<Map<String, dynamic>>;

      emit(state.copyWith(
        checkInStatus: checkInData,
        checkInRewards: rewards,
        isCheckedInToday: checkInData['checked_in_today'] as bool? ?? false,
        consecutiveDays: checkInData['consecutive_days'] as int? ?? 0,
      ));
    } catch (e) {
      AppLogger.error('Failed to load check-in status', e);
    }
  }

  /// 加载可用优惠券
  Future<void> _onLoadAvailableCoupons(
    CouponPointsLoadAvailableCoupons event,
    Emitter<CouponPointsState> emit,
  ) async {
    try {
      final coupons = await _repository.getAvailableCoupons();
      emit(state.copyWith(availableCoupons: coupons));
    } catch (e) {
      AppLogger.error('Failed to load available coupons', e);
    }
  }

  /// 加载我的优惠券
  Future<void> _onLoadMyCoupons(
    CouponPointsLoadMyCoupons event,
    Emitter<CouponPointsState> emit,
  ) async {
    try {
      final coupons = await _repository.getMyCoupons(status: event.status);
      emit(state.copyWith(myCoupons: coupons));
    } catch (e) {
      AppLogger.error('Failed to load my coupons', e);
    }
  }

  /// 领取优惠券
  Future<void> _onClaimCoupon(
    CouponPointsClaimCoupon event,
    Emitter<CouponPointsState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _repository.claimCoupon(event.couponId);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'coupon_claimed',
      ));
      // 刷新优惠券列表
      add(const CouponPointsLoadMyCoupons());
      add(const CouponPointsLoadAvailableCoupons());
    } catch (e) {
      final errMsg = e.toString().replaceAll('CouponPointsException: ', '');
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'claim_failed',
        errorMessage: errMsg,
      ));
    }
  }

  /// 积分兑换优惠券
  Future<void> _onRedeemCoupon(
    CouponPointsRedeemCoupon event,
    Emitter<CouponPointsState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _repository.redeemCoupon(event.couponId);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'coupon_redeemed',
      ));
      // 刷新数据
      add(const CouponPointsLoadRequested());
    } catch (e) {
      final errMsg = e.toString().replaceAll('CouponPointsException: ', '');
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'redeem_failed',
        errorMessage: errMsg,
      ));
    }
  }

  /// 使用兑换码领取优惠券（对标 iOS redeemWithCode → claimCoupon(promotionCode:)）
  Future<void> _onUseInvitationCode(
    CouponPointsUseInvitationCode event,
    Emitter<CouponPointsState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _repository.claimCouponByCode(event.code);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'coupon_claimed',
      ));
      add(const CouponPointsLoadRequested());
    } catch (e) {
      final errMsg = e.toString().replaceAll('CouponPointsException: ', '');
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'claim_failed',
        errorMessage: errMsg,
      ));
    }
  }
}
