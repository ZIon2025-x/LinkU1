import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/payment.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class WalletEvent extends Equatable {
  const WalletEvent();

  @override
  List<Object?> get props => [];
}

class WalletLoadRequested extends WalletEvent {
  const WalletLoadRequested();
}

class WalletLoadTransactions extends WalletEvent {
  const WalletLoadTransactions({this.type});

  final String? type;

  @override
  List<Object?> get props => [type];
}

class WalletLoadMoreTransactions extends WalletEvent {
  const WalletLoadMoreTransactions();
}

// ==================== State ====================

enum WalletStatus { initial, loading, loaded, error }

class WalletState extends Equatable {
  const WalletState({
    this.status = WalletStatus.initial,
    this.walletInfo,
    this.transactions = const [],
    this.page = 1,
    this.hasMore = true,
    this.errorMessage,
  });

  final WalletStatus status;
  final WalletInfo? walletInfo;
  final List<Transaction> transactions;
  final int page;
  final bool hasMore;
  final String? errorMessage;

  bool get isLoading => status == WalletStatus.loading;

  WalletState copyWith({
    WalletStatus? status,
    WalletInfo? walletInfo,
    List<Transaction>? transactions,
    int? page,
    bool? hasMore,
    String? errorMessage,
  }) {
    return WalletState(
      status: status ?? this.status,
      walletInfo: walletInfo ?? this.walletInfo,
      transactions: transactions ?? this.transactions,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, walletInfo, transactions, page, hasMore, errorMessage];
}

// ==================== Bloc ====================

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc({required UserRepository userRepository})
      : _userRepository = userRepository,
        super(const WalletState()) {
    on<WalletLoadRequested>(_onLoadRequested);
    on<WalletLoadTransactions>(_onLoadTransactions);
    on<WalletLoadMoreTransactions>(_onLoadMore);
  }

  final UserRepository _userRepository;

  Future<void> _onLoadRequested(
    WalletLoadRequested event,
    Emitter<WalletState> emit,
  ) async {
    emit(state.copyWith(status: WalletStatus.loading));

    try {
      final walletInfo = await _userRepository.getWalletInfo();
      final transactions = await _userRepository.getTransactions(page: 1);

      emit(state.copyWith(
        status: WalletStatus.loaded,
        walletInfo: walletInfo,
        transactions: transactions,
        page: 1,
        hasMore: transactions.length >= 20,
      ));
    } catch (e) {
      AppLogger.error('Failed to load wallet', e);
      emit(state.copyWith(
        status: WalletStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadTransactions(
    WalletLoadTransactions event,
    Emitter<WalletState> emit,
  ) async {
    try {
      final transactions = await _userRepository.getTransactions(
        page: 1,
        type: event.type,
      );

      emit(state.copyWith(
        transactions: transactions,
        page: 1,
        hasMore: transactions.length >= 20,
      ));
    } catch (e) {
      AppLogger.error('Failed to load transactions', e);
    }
  }

  Future<void> _onLoadMore(
    WalletLoadMoreTransactions event,
    Emitter<WalletState> emit,
  ) async {
    if (!state.hasMore) return;

    try {
      final nextPage = state.page + 1;
      final transactions = await _userRepository.getTransactions(
        page: nextPage,
      );

      emit(state.copyWith(
        transactions: [...state.transactions, ...transactions],
        page: nextPage,
        hasMore: transactions.length >= 20,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more transactions', e);
    }
  }
}
