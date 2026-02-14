import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/cache_manager.dart';
import '../../../data/models/flea_market.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../core/utils/logger.dart';
import '../../tasks/bloc/task_detail_bloc.dart' show AcceptPaymentData;

// ==================== Events ====================

abstract class FleaMarketEvent extends Equatable {
  const FleaMarketEvent();

  @override
  List<Object?> get props => [];
}

class FleaMarketLoadRequested extends FleaMarketEvent {
  const FleaMarketLoadRequested();
}

class FleaMarketRefreshRequested extends FleaMarketEvent {
  const FleaMarketRefreshRequested();
}

class FleaMarketLoadMore extends FleaMarketEvent {
  const FleaMarketLoadMore();
}

class FleaMarketCategoryChanged extends FleaMarketEvent {
  const FleaMarketCategoryChanged(this.category);

  final String category;

  @override
  List<Object?> get props => [category];
}

class FleaMarketSearchChanged extends FleaMarketEvent {
  const FleaMarketSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class FleaMarketCreateItem extends FleaMarketEvent {
  const FleaMarketCreateItem(this.request);

  final CreateFleaMarketRequest request;

  @override
  List<Object?> get props => [request];
}

class FleaMarketPurchaseItem extends FleaMarketEvent {
  const FleaMarketPurchaseItem(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// 提交购买/议价申请（留言 + 可选议价金额）- 对标 iOS 购买弹窗
class FleaMarketSubmitPurchaseOrRequest extends FleaMarketEvent {
  const FleaMarketSubmitPurchaseOrRequest(
    this.itemId, {
    this.message,
    this.proposedPrice,
  });

  final String itemId;
  final String? message;
  final double? proposedPrice;

  @override
  List<Object?> get props => [itemId, message, proposedPrice];
}

class FleaMarketUpdateItem extends FleaMarketEvent {
  const FleaMarketUpdateItem({
    required this.itemId,
    required this.title,
    required this.description,
    required this.price,
    this.location,
    this.category,
    this.images,
  });

  final String itemId;
  final String title;
  final String description;
  final double price;
  final String? location;
  final String? category;
  final List<String>? images;

  @override
  List<Object?> get props =>
      [itemId, title, description, price, location, category, images];
}

class FleaMarketLoadDetailRequested extends FleaMarketEvent {
  const FleaMarketLoadDetailRequested(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// 刷新商品（重新上架）- 对标iOS refreshItem
class FleaMarketRefreshItem extends FleaMarketEvent {
  const FleaMarketRefreshItem(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// 加载购买申请列表 - 对标iOS loadPurchaseRequests
class FleaMarketLoadPurchaseRequests extends FleaMarketEvent {
  const FleaMarketLoadPurchaseRequests(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// 收藏/取消收藏 - 对标iOS toggleFavorite
class FleaMarketToggleFavorite extends FleaMarketEvent {
  const FleaMarketToggleFavorite(this.itemId);

  final String itemId;

  @override
  List<Object?> get props => [itemId];
}

/// 清除直接购买后的支付数据（关闭支付页或支付完成后调用）
class FleaMarketClearAcceptPaymentData extends FleaMarketEvent {
  const FleaMarketClearAcceptPaymentData();
}

class FleaMarketUploadImage extends FleaMarketEvent {
  const FleaMarketUploadImage({
    required this.imageBytes,
    required this.filename,
    this.itemId,
  });

  final Uint8List imageBytes;
  final String filename;
  /// 编辑时传入，上传到商品目录；新建时不传
  final String? itemId;

  @override
  List<Object?> get props => [imageBytes.length, filename, itemId];
}

// ==================== State ====================

enum FleaMarketStatus { initial, loading, loaded, error }

class FleaMarketState extends Equatable {
  const FleaMarketState({
    this.status = FleaMarketStatus.initial,
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.hasMore = true,
    this.selectedCategory = 'all',
    this.searchQuery = '',
    this.errorMessage,
    this.isRefreshing = false,
    this.isSubmitting = false,
    this.actionMessage,
    this.selectedItem,
    this.detailStatus = FleaMarketStatus.initial,
    this.isUploadingImage = false,
    this.uploadedImageUrl,
    this.purchaseRequests = const [],
    this.isLoadingPurchaseRequests = false,
    this.isFavorited = false,
    this.isTogglingFavorite = false,
    this.isLoadingMore = false,
    this.acceptPaymentData,
    this.clearAcceptPaymentData = false,
  });

  final FleaMarketStatus status;
  final List<FleaMarketItem> items;
  final int total;
  final int page;
  final bool hasMore;
  final String selectedCategory;
  final String searchQuery;
  final String? errorMessage;
  final bool isRefreshing;
  final bool isSubmitting;
  final String? actionMessage;
  final FleaMarketItem? selectedItem;
  final FleaMarketStatus detailStatus;
  final bool isUploadingImage;
  final String? uploadedImageUrl;
  final List<PurchaseRequest> purchaseRequests;
  final bool isLoadingPurchaseRequests;
  final bool isFavorited;
  final bool isTogglingFavorite;
  final bool isLoadingMore;
  /// 直接购买后需支付时由后端返回，用于打开支付页（对标 iOS handlePurchaseComplete）
  final AcceptPaymentData? acceptPaymentData;
  final bool clearAcceptPaymentData;

  bool get isLoading => status == FleaMarketStatus.loading;
  bool get isEmpty => items.isEmpty && status == FleaMarketStatus.loaded;
  bool get isDetailLoading => detailStatus == FleaMarketStatus.loading;
  bool get isDetailLoaded => detailStatus == FleaMarketStatus.loaded && selectedItem != null;

  FleaMarketState copyWith({
    FleaMarketStatus? status,
    List<FleaMarketItem>? items,
    int? total,
    int? page,
    bool? hasMore,
    String? selectedCategory,
    String? searchQuery,
    String? errorMessage,
    bool? isRefreshing,
    bool? isSubmitting,
    String? actionMessage,
    FleaMarketItem? selectedItem,
    FleaMarketStatus? detailStatus,
    bool? isUploadingImage,
    String? uploadedImageUrl,
    List<PurchaseRequest>? purchaseRequests,
    bool? isLoadingPurchaseRequests,
    bool? isFavorited,
    bool? isTogglingFavorite,
    bool? isLoadingMore,
    AcceptPaymentData? acceptPaymentData,
    bool clearAcceptPaymentData = false,
  }) {
    return FleaMarketState(
      status: status ?? this.status,
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
      selectedItem: selectedItem ?? this.selectedItem,
      detailStatus: detailStatus ?? this.detailStatus,
      isUploadingImage: isUploadingImage ?? this.isUploadingImage,
      uploadedImageUrl: uploadedImageUrl,
      purchaseRequests: purchaseRequests ?? this.purchaseRequests,
      isLoadingPurchaseRequests: isLoadingPurchaseRequests ?? this.isLoadingPurchaseRequests,
      isFavorited: isFavorited ?? this.isFavorited,
      isTogglingFavorite: isTogglingFavorite ?? this.isTogglingFavorite,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      acceptPaymentData: clearAcceptPaymentData
          ? null
          : (acceptPaymentData ?? this.acceptPaymentData),
      clearAcceptPaymentData: clearAcceptPaymentData,
    );
  }

  @override
  List<Object?> get props => [
        status,
        items,
        total,
        page,
        hasMore,
        selectedCategory,
        searchQuery,
        errorMessage,
        isRefreshing,
        isSubmitting,
        actionMessage,
        selectedItem,
        detailStatus,
        purchaseRequests,
        isLoadingPurchaseRequests,
        isFavorited,
        isTogglingFavorite,
        isLoadingMore,
        acceptPaymentData,
      ];
}

// ==================== Bloc ====================

class FleaMarketBloc extends Bloc<FleaMarketEvent, FleaMarketState> {
  FleaMarketBloc({required FleaMarketRepository fleaMarketRepository})
      : _fleaMarketRepository = fleaMarketRepository,
        super(const FleaMarketState()) {
    on<FleaMarketLoadRequested>(_onLoadRequested);
    on<FleaMarketRefreshRequested>(_onRefresh);
    on<FleaMarketLoadMore>(_onLoadMore);
    on<FleaMarketCategoryChanged>(_onCategoryChanged);
    on<FleaMarketSearchChanged>(_onSearchChanged);
    on<FleaMarketCreateItem>(_onCreateItem);
    on<FleaMarketPurchaseItem>(_onPurchaseItem);
    on<FleaMarketSubmitPurchaseOrRequest>(_onSubmitPurchaseOrRequest);
    on<FleaMarketUpdateItem>(_onUpdateItem);
    on<FleaMarketLoadDetailRequested>(_onLoadDetailRequested);
    on<FleaMarketRefreshItem>(_onRefreshItem);
    on<FleaMarketLoadPurchaseRequests>(_onLoadPurchaseRequests);
    on<FleaMarketUploadImage>(_onUploadImage);
    on<FleaMarketToggleFavorite>(_onToggleFavorite);
    on<FleaMarketClearAcceptPaymentData>(_onClearAcceptPaymentData);
  }

  final FleaMarketRepository _fleaMarketRepository;

  Future<void> _onLoadRequested(
    FleaMarketLoadRequested event,
    Emitter<FleaMarketState> emit,
  ) async {
    emit(state.copyWith(status: FleaMarketStatus.loading));

    try {
      final response = await _fleaMarketRepository.getItems(
        page: 1,
        category: state.selectedCategory,
        keyword: state.searchQuery.isEmpty ? null : state.searchQuery,
      );

      emit(state.copyWith(
        status: FleaMarketStatus.loaded,
        items: response.items,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load flea market items', e);
      emit(state.copyWith(
        status: FleaMarketStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRefresh(
    FleaMarketRefreshRequested event,
    Emitter<FleaMarketState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true));

    // 下拉刷新前失效缓存，确保获取最新数据
    await CacheManager.shared.invalidateFleaMarketCache();

    try {
      final response = await _fleaMarketRepository.getItems(
        page: 1,
        category: state.selectedCategory,
      );

      emit(state.copyWith(
        status: FleaMarketStatus.loaded,
        items: response.items,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
        isRefreshing: false,
      ));
    } catch (e) {
      emit(state.copyWith(isRefreshing: false));
    }
  }

  Future<void> _onLoadMore(
    FleaMarketLoadMore event,
    Emitter<FleaMarketState> emit,
  ) async {
    // 防重复：正在加载中或无更多数据时跳过
    if (!state.hasMore || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));

    try {
      final nextPage = state.page + 1;
      final response = await _fleaMarketRepository.getItems(
        page: nextPage,
        category: state.selectedCategory,
        keyword: state.searchQuery.isEmpty ? null : state.searchQuery,
      );

      emit(state.copyWith(
        items: [...state.items, ...response.items],
        page: nextPage,
        hasMore: response.hasMore,
        isLoadingMore: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more items', e);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onCategoryChanged(
    FleaMarketCategoryChanged event,
    Emitter<FleaMarketState> emit,
  ) async {
    emit(state.copyWith(
      selectedCategory: event.category,
      status: FleaMarketStatus.loading,
    ));

    try {
      final response = await _fleaMarketRepository.getItems(
        page: 1,
        category: event.category,
      );

      emit(state.copyWith(
        status: FleaMarketStatus.loaded,
        items: response.items,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: FleaMarketStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSearchChanged(
    FleaMarketSearchChanged event,
    Emitter<FleaMarketState> emit,
  ) async {
    emit(state.copyWith(
      searchQuery: event.query,
      status: FleaMarketStatus.loading,
    ));

    try {
      final response = await _fleaMarketRepository.getItems(
        page: 1,
        keyword: event.query.isEmpty ? null : event.query,
        category: state.selectedCategory,
      );

      emit(state.copyWith(
        status: FleaMarketStatus.loaded,
        items: response.items,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: FleaMarketStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCreateItem(
    FleaMarketCreateItem event,
    Emitter<FleaMarketState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _fleaMarketRepository.createItem(event.request);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'item_published',
      ));
      // 刷新列表
      add(const FleaMarketRefreshRequested());
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'publish_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  /// 从直接购买接口返回的 body 中解析支付数据（后端返回 { success, data: { task_id, client_secret, ... } }）
  /// 对标 iOS DirectPurchaseResponse.DirectPurchaseData，仅当需支付（pending_payment + client_secret）时返回非 null
  AcceptPaymentData? _parseDirectPurchasePaymentData(Map<String, dynamic> raw) {
    final payload = raw['data'] as Map<String, dynamic>? ?? raw;
    final clientSecret = payload['client_secret'] as String?;
    if (clientSecret == null || clientSecret.isEmpty) return null;
    final taskStatus = payload['task_status'] as String?;
    if (taskStatus != null && taskStatus != 'pending_payment') return null;
    final taskIdRaw = payload['task_id'];
    final taskId = taskIdRaw != null
        ? (int.tryParse(taskIdRaw.toString()) ?? 0)
        : 0;
    if (taskId == 0) return null;
    return AcceptPaymentData(
      taskId: taskId,
      clientSecret: clientSecret,
      customerId: (payload['customer_id'] as String?) ?? '',
      ephemeralKeySecret: (payload['ephemeral_key_secret'] as String?) ?? '',
      amountDisplay: payload['amount_display'] as String?,
      applicationId: null,
      paymentExpiresAt: payload['payment_expires_at'] as String?,
    );
  }

  Future<void> _onPurchaseItem(
    FleaMarketPurchaseItem event,
    Emitter<FleaMarketState> emit,
  ) async {
    emit(state.copyWith(
      isSubmitting: true,
      actionMessage: null,
      errorMessage: null,
    ));

    try {
      final result = await _fleaMarketRepository.directPurchase(event.itemId);
      final paymentData = _parseDirectPurchasePaymentData(result);

      if (paymentData != null) {
        // ✅ 正常流程：需要支付，打开支付页
        // 此时商品状态在后端仍为 active（但 sold_task_id 已设置），不在本地改状态
        emit(state.copyWith(
          isSubmitting: false,
          actionMessage: 'open_payment',
          acceptPaymentData: paymentData,
        ));
        return;
      }

      // ⚠️ 无需支付的情况（极少见，如0元商品）：刷新详情确认最新状态
      FleaMarketItem? refreshedDetail;
      if (state.selectedItem?.id == event.itemId) {
        refreshedDetail =
            await _fleaMarketRepository.getItemById(event.itemId);
      }
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'purchase_success',
        selectedItem: refreshedDetail ?? state.selectedItem,
      ));
    } catch (e) {
      AppLogger.error('Failed to purchase item', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'purchase_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSubmitPurchaseOrRequest(
    FleaMarketSubmitPurchaseOrRequest event,
    Emitter<FleaMarketState> emit,
  ) async {
    emit(state.copyWith(
      isSubmitting: true,
      actionMessage: null,
      errorMessage: null,
    ));

    try {
      FleaMarketItem? refreshedDetail;
      if (event.proposedPrice != null) {
        await _fleaMarketRepository.sendPurchaseRequest(
          event.itemId,
          proposedPrice: event.proposedPrice,
          message: event.message,
        );
        if (state.selectedItem?.id == event.itemId) {
          refreshedDetail =
              await _fleaMarketRepository.getItemById(event.itemId);
        }
        emit(state.copyWith(
          isSubmitting: false,
          actionMessage: 'negotiate_request_sent',
          selectedItem: refreshedDetail ?? state.selectedItem,
        ));
      } else {
        final result = await _fleaMarketRepository.directPurchase(event.itemId);
        final paymentData = _parseDirectPurchasePaymentData(result);

        if (paymentData != null) {
          // ✅ 正常流程：需要支付，打开支付页
          // 对标 iOS handlePurchaseComplete：不改变本地商品状态，等支付完成后刷新
          emit(state.copyWith(
            isSubmitting: false,
            actionMessage: 'open_payment',
            acceptPaymentData: paymentData,
          ));
          return;
        }

        // ⚠️ 无需支付的情况：刷新详情确认最新状态
        if (state.selectedItem?.id == event.itemId) {
          refreshedDetail =
              await _fleaMarketRepository.getItemById(event.itemId);
        }
        emit(state.copyWith(
          isSubmitting: false,
          actionMessage: 'purchase_success',
          selectedItem: refreshedDetail ?? state.selectedItem,
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to submit purchase/request', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: event.proposedPrice != null
            ? 'negotiate_request_failed'
            : 'purchase_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  void _onClearAcceptPaymentData(
    FleaMarketClearAcceptPaymentData event,
    Emitter<FleaMarketState> emit,
  ) {
    emit(state.copyWith(clearAcceptPaymentData: true));
  }

  Future<void> _onUpdateItem(
    FleaMarketUpdateItem event,
    Emitter<FleaMarketState> emit,
  ) async {
    emit(state.copyWith(
      isSubmitting: true,
      actionMessage: null,
      errorMessage: null,
    ));

    try {
      final updatedItem = await _fleaMarketRepository.updateItem(
        event.itemId,
        title: event.title,
        description: event.description,
        price: event.price,
        category: event.category,
        images: event.images,
      );

      // 更新列表中的对应项
      final updatedItems = state.items.map((item) {
        return item.id == event.itemId ? updatedItem : item;
      }).toList();

      emit(state.copyWith(
        isSubmitting: false,
        items: updatedItems,
        selectedItem:
            state.selectedItem?.id == updatedItem.id ? updatedItem : null,
        actionMessage: 'item_updated',
      ));
    } catch (e) {
      AppLogger.error('Failed to update flea market item', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'update_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadDetailRequested(
    FleaMarketLoadDetailRequested event,
    Emitter<FleaMarketState> emit,
  ) async {
    if (event.itemId.trim().isEmpty) {
      emit(state.copyWith(
        detailStatus: FleaMarketStatus.error,
        errorMessage: '无效的商品 ID',
      ));
      return;
    }

    emit(state.copyWith(detailStatus: FleaMarketStatus.loading));

    try {
      final item = await _fleaMarketRepository.getItemById(event.itemId);
      emit(state.copyWith(
        detailStatus: FleaMarketStatus.loaded,
        selectedItem: item,
      ));
      // 对标iOS checkFavoriteStatus：从收藏列表判断是否已收藏
      _checkFavoriteStatus(item.id, emit);
    } catch (e) {
      AppLogger.error('Failed to load flea market item detail', e);
      emit(state.copyWith(
        detailStatus: FleaMarketStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// 检查商品是否已收藏 - 对标iOS checkFavoriteStatus
  Future<void> _checkFavoriteStatus(
    String itemId,
    Emitter<FleaMarketState> emit,
  ) async {
    try {
      final favResponse = await _fleaMarketRepository.getFavoriteItems(
        page: 1,
        pageSize: 100,
      );
      final favoriteIds = favResponse.items.map((e) => e.id).toSet();
      emit(state.copyWith(isFavorited: favoriteIds.contains(itemId)));
    } catch (e) {
      AppLogger.error('Failed to check favorite status', e);
    }
  }

  /// 刷新商品（重新上架）- 对标iOS refreshItem
  Future<void> _onRefreshItem(
    FleaMarketRefreshItem event,
    Emitter<FleaMarketState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _fleaMarketRepository.refreshItem(event.itemId);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'refresh_success',
      ));
      // 重新加载详情以获取最新数据
      add(FleaMarketLoadDetailRequested(event.itemId));
    } catch (e) {
      AppLogger.error('Failed to refresh flea market item', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'refresh_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  /// 加载购买申请列表 - 对标iOS loadPurchaseRequests
  Future<void> _onLoadPurchaseRequests(
    FleaMarketLoadPurchaseRequests event,
    Emitter<FleaMarketState> emit,
  ) async {
    emit(state.copyWith(isLoadingPurchaseRequests: true));

    try {
      final rawRequests = await _fleaMarketRepository
          .getItemPurchaseRequests(event.itemId);

      final requests = rawRequests
          .map((e) => PurchaseRequest.fromJson(e))
          .toList();

      emit(state.copyWith(
        isLoadingPurchaseRequests: false,
        purchaseRequests: requests,
      ));
    } catch (e) {
      AppLogger.error('Failed to load purchase requests', e);
      emit(state.copyWith(
        isLoadingPurchaseRequests: false,
      ));
    }
  }

  Future<void> _onUploadImage(
    FleaMarketUploadImage event,
    Emitter<FleaMarketState> emit,
  ) async {
    emit(state.copyWith(
      isUploadingImage: true,
      uploadedImageUrl: null,
      errorMessage: null,
    ));

    try {
      final url = await _fleaMarketRepository.uploadImage(
        event.imageBytes,
        event.filename,
        itemId: event.itemId,
      );
      emit(state.copyWith(
        isUploadingImage: false,
        uploadedImageUrl: url,
      ));
    } catch (e) {
      AppLogger.error('Failed to upload image', e);
      emit(state.copyWith(
        isUploadingImage: false,
        errorMessage: e.toString(),
      ));
    }
  }

  /// 收藏/取消收藏 - 对标iOS toggleFavorite
  Future<void> _onToggleFavorite(
    FleaMarketToggleFavorite event,
    Emitter<FleaMarketState> emit,
  ) async {
    if (state.isTogglingFavorite) return;
    emit(state.copyWith(isTogglingFavorite: true));

    try {
      final isFavorited = await _fleaMarketRepository.toggleFavorite(event.itemId);
      emit(state.copyWith(
        isTogglingFavorite: false,
        isFavorited: isFavorited,
      ));
    } catch (e) {
      AppLogger.error('Failed to toggle favorite', e);
      emit(state.copyWith(isTogglingFavorite: false));
    }
  }
}
