import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import '../../../data/models/flea_market_rental.dart';
import '../../../data/repositories/flea_market_repository.dart';

// ==================== Events ====================

abstract class FleaMarketRentalEvent extends Equatable {
  const FleaMarketRentalEvent();

  @override
  List<Object?> get props => [];
}

class RentalSubmitRequest extends FleaMarketRentalEvent {
  const RentalSubmitRequest({
    required this.itemId,
    required this.rentalDuration,
    this.desiredTime,
    this.usageDescription,
    this.proposedRentalPrice,
  });

  final String itemId;
  final int rentalDuration;
  final String? desiredTime;
  final String? usageDescription;
  final double? proposedRentalPrice;

  @override
  List<Object?> get props => [
        itemId,
        rentalDuration,
        desiredTime,
        usageDescription,
        proposedRentalPrice,
      ];
}

class RentalLoadRequests extends FleaMarketRentalEvent {
  const RentalLoadRequests(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

class RentalApproveRequest extends FleaMarketRentalEvent {
  const RentalApproveRequest({
    required this.requestId,
    required this.itemId,
  });

  final String requestId;
  final String itemId;

  @override
  List<Object?> get props => [requestId, itemId];
}

class RentalRejectRequest extends FleaMarketRentalEvent {
  const RentalRejectRequest({
    required this.requestId,
    required this.itemId,
  });

  final String requestId;
  final String itemId;

  @override
  List<Object?> get props => [requestId, itemId];
}

class RentalCounterOffer extends FleaMarketRentalEvent {
  const RentalCounterOffer({
    required this.requestId,
    required this.itemId,
    required this.counterPrice,
  });

  final String requestId;
  final String itemId;
  final double counterPrice;

  @override
  List<Object?> get props => [requestId, itemId, counterPrice];
}

class RentalRespondCounterOffer extends FleaMarketRentalEvent {
  const RentalRespondCounterOffer({
    required this.requestId,
    required this.itemId,
    required this.accept,
  });

  final String requestId;
  final String itemId;
  final bool accept;

  @override
  List<Object?> get props => [requestId, itemId, accept];
}

class RentalRenterConfirmReturn extends FleaMarketRentalEvent {
  const RentalRenterConfirmReturn(this.rentalId);

  final String rentalId;

  @override
  List<Object?> get props => [rentalId];
}

class RentalConfirmReturn extends FleaMarketRentalEvent {
  const RentalConfirmReturn(this.rentalId);

  final String rentalId;

  @override
  List<Object?> get props => [rentalId];
}

class RentalLoadDetail extends FleaMarketRentalEvent {
  const RentalLoadDetail(this.rentalId);

  final String rentalId;

  @override
  List<Object?> get props => [rentalId];
}

class RentalClearPaymentData extends FleaMarketRentalEvent {
  const RentalClearPaymentData();
}

class RentalClearActionMessage extends FleaMarketRentalEvent {
  const RentalClearActionMessage();
}

// ==================== State ====================

class FleaMarketRentalState extends Equatable {
  const FleaMarketRentalState({
    this.rentalRequests = const [],
    this.isLoadingRequests = false,
    this.isLoadingDetail = false,
    this.currentRental,
    this.isSubmitting = false,
    this.actionMessage,
    this.errorMessage,
    this.acceptPaymentData,
  });

  final List<FleaMarketRentalRequest> rentalRequests;
  final bool isLoadingRequests;
  final bool isLoadingDetail;
  final FleaMarketRental? currentRental;
  final bool isSubmitting;
  final String? actionMessage;
  final String? errorMessage;
  /// 批准/接受还价后返回的支付信息
  final Map<String, dynamic>? acceptPaymentData;

  FleaMarketRentalState copyWith({
    List<FleaMarketRentalRequest>? rentalRequests,
    bool? isLoadingRequests,
    bool? isLoadingDetail,
    FleaMarketRental? currentRental,
    bool clearCurrentRental = false,
    bool? isSubmitting,
    String? actionMessage,
    String? errorMessage,
    Map<String, dynamic>? acceptPaymentData,
    bool clearAcceptPaymentData = false,
  }) {
    return FleaMarketRentalState(
      rentalRequests: rentalRequests ?? this.rentalRequests,
      isLoadingRequests: isLoadingRequests ?? this.isLoadingRequests,
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      currentRental: clearCurrentRental
          ? null
          : (currentRental ?? this.currentRental),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
      errorMessage: errorMessage,
      acceptPaymentData: clearAcceptPaymentData
          ? null
          : (acceptPaymentData ?? this.acceptPaymentData),
    );
  }

  @override
  List<Object?> get props => [
        rentalRequests,
        isLoadingRequests,
        isLoadingDetail,
        currentRental,
        isSubmitting,
        actionMessage,
        errorMessage,
        acceptPaymentData,
      ];
}

// ==================== Bloc ====================

class FleaMarketRentalBloc
    extends Bloc<FleaMarketRentalEvent, FleaMarketRentalState> {
  FleaMarketRentalBloc({required FleaMarketRepository repository})
      : _repository = repository,
        super(const FleaMarketRentalState()) {
    on<RentalSubmitRequest>(_onSubmitRequest);
    on<RentalLoadRequests>(_onLoadRequests);
    on<RentalApproveRequest>(_onApproveRequest);
    on<RentalRejectRequest>(_onRejectRequest);
    on<RentalCounterOffer>(_onCounterOffer);
    on<RentalRespondCounterOffer>(_onRespondCounterOffer);
    on<RentalRenterConfirmReturn>(_onRenterConfirmReturn);
    on<RentalConfirmReturn>(_onConfirmReturn);
    on<RentalLoadDetail>(_onLoadDetail);
    on<RentalClearPaymentData>(_onClearPaymentData);
    on<RentalClearActionMessage>(_onClearActionMessage);
  }

  final FleaMarketRepository _repository;

  Future<void> _onSubmitRequest(
    RentalSubmitRequest event,
    Emitter<FleaMarketRentalState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _repository.submitRentalRequest(
        event.itemId,
        rentalDuration: event.rentalDuration,
        desiredTime: event.desiredTime,
        usageDescription: event.usageDescription,
        proposedRentalPrice: event.proposedRentalPrice,
      );

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'rental_request_sent',
      ));
    } catch (e) {
      AppLogger.error('Failed to submit rental request', e);
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadRequests(
    RentalLoadRequests event,
    Emitter<FleaMarketRentalState> emit,
  ) async {
    emit(state.copyWith(isLoadingRequests: true));

    try {
      final requests = await _repository.getItemRentalRequests(event.itemId);

      emit(state.copyWith(
        isLoadingRequests: false,
        rentalRequests: requests,
      ));
    } catch (e) {
      AppLogger.error('Failed to load rental requests', e);
      emit(state.copyWith(
        isLoadingRequests: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onApproveRequest(
    RentalApproveRequest event,
    Emitter<FleaMarketRentalState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      final result = await _repository.approveRentalRequest(event.requestId);

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'rental_request_approved',
        acceptPaymentData: result,
      ));

      // 刷新申请列表
      add(RentalLoadRequests(event.itemId));
    } catch (e) {
      AppLogger.error('Failed to approve rental request', e);
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRejectRequest(
    RentalRejectRequest event,
    Emitter<FleaMarketRentalState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _repository.rejectRentalRequest(event.requestId);

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'rental_request_rejected',
      ));

      // 刷新申请列表
      add(RentalLoadRequests(event.itemId));
    } catch (e) {
      AppLogger.error('Failed to reject rental request', e);
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCounterOffer(
    RentalCounterOffer event,
    Emitter<FleaMarketRentalState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _repository.counterOfferRental(event.requestId, event.counterPrice);

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'rental_counter_offer_sent',
      ));

      // 刷新申请列表
      add(RentalLoadRequests(event.itemId));
    } catch (e) {
      AppLogger.error('Failed to send rental counter offer', e);
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRespondCounterOffer(
    RentalRespondCounterOffer event,
    Emitter<FleaMarketRentalState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      final result = await _repository.respondRentalCounterOffer(
        event.requestId,
        accept: event.accept,
      );

      if (event.accept && result != null) {
        // 接受还价 → 返回支付数据
        emit(state.copyWith(
          isSubmitting: false,
          actionMessage: 'rental_counter_offer_accepted',
          acceptPaymentData: result,
        ));
      } else {
        emit(state.copyWith(
          isSubmitting: false,
          actionMessage: event.accept
              ? 'rental_counter_offer_accepted'
              : 'rental_counter_offer_rejected',
        ));
      }

      // 刷新申请列表
      add(RentalLoadRequests(event.itemId));
    } catch (e) {
      AppLogger.error('Failed to respond to rental counter offer', e);
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRenterConfirmReturn(
    RentalRenterConfirmReturn event,
    Emitter<FleaMarketRentalState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _repository.renterConfirmReturn(event.rentalId);

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'rental_renter_confirm_return',
      ));

      // 刷新租赁详情
      add(RentalLoadDetail(event.rentalId));
    } catch (e) {
      AppLogger.error('Failed to renter confirm return', e);
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onConfirmReturn(
    RentalConfirmReturn event,
    Emitter<FleaMarketRentalState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _repository.confirmReturn(event.rentalId);

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'rental_return_confirmed',
      ));

      // 刷新租赁详情
      add(RentalLoadDetail(event.rentalId));
    } catch (e) {
      AppLogger.error('Failed to confirm rental return', e);
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadDetail(
    RentalLoadDetail event,
    Emitter<FleaMarketRentalState> emit,
  ) async {
    emit(state.copyWith(isLoadingDetail: true));

    try {
      final rental = await _repository.getRentalDetail(event.rentalId);

      emit(state.copyWith(
        isLoadingDetail: false,
        currentRental: rental,
      ));
    } catch (e) {
      AppLogger.error('Failed to load rental detail', e);
      emit(state.copyWith(
        isLoadingDetail: false,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onClearPaymentData(
    RentalClearPaymentData event,
    Emitter<FleaMarketRentalState> emit,
  ) {
    emit(state.copyWith(clearAcceptPaymentData: true));
  }

  void _onClearActionMessage(
    RentalClearActionMessage event,
    Emitter<FleaMarketRentalState> emit,
  ) {
    emit(state.copyWith(errorMessage: state.errorMessage));
  }
}
