import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/flea_market.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../core/utils/logger.dart';

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

  final int itemId;

  @override
  List<Object?> get props => [itemId];
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

  final int itemId;
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

  final int itemId;

  @override
  List<Object?> get props => [itemId];
}

/// 刷新商品（重新上架）- 对标iOS refreshItem
class FleaMarketRefreshItem extends FleaMarketEvent {
  const FleaMarketRefreshItem(this.itemId);

  final int itemId;

  @override
  List<Object?> get props => [itemId];
}

/// 加载购买申请列表 - 对标iOS loadPurchaseRequests
class FleaMarketLoadPurchaseRequests extends FleaMarketEvent {
  const FleaMarketLoadPurchaseRequests(this.itemId);

  final int itemId;

  @override
  List<Object?> get props => [itemId];
}

class FleaMarketUploadImage extends FleaMarketEvent {
  const FleaMarketUploadImage({
    required this.imageBytes,
    required this.filename,
  });

  final Uint8List imageBytes;
  final String filename;

  @override
  List<Object?> get props => [imageBytes.length, filename];
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
    on<FleaMarketUpdateItem>(_onUpdateItem);
    on<FleaMarketLoadDetailRequested>(_onLoadDetailRequested);
    on<FleaMarketRefreshItem>(_onRefreshItem);
    on<FleaMarketLoadPurchaseRequests>(_onLoadPurchaseRequests);
    on<FleaMarketUploadImage>(_onUploadImage);
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
    if (!state.hasMore) return;

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
      ));
    } catch (e) {
      AppLogger.error('Failed to load more items', e);
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
        actionMessage: '商品发布成功',
      ));
      // 刷新列表
      add(const FleaMarketRefreshRequested());
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '发布失败: ${e.toString()}',
      ));
    }
  }

  Future<void> _onPurchaseItem(
    FleaMarketPurchaseItem event,
    Emitter<FleaMarketState> emit,
  ) async {
    // 清除旧的错误/操作消息，避免残留
    emit(state.copyWith(
      isSubmitting: true,
      actionMessage: null,
      errorMessage: null,
    ));

    try {
      await _fleaMarketRepository.directPurchase(event.itemId.toString());

      // 更新本地状态
      final updatedItems = state.items.map((item) {
        final itemIdInt = int.tryParse(item.id);
        if (itemIdInt == event.itemId) {
          return item.copyWith(status: AppConstants.fleaMarketStatusSold);
        }
        return item;
      }).toList();

      emit(state.copyWith(
        items: updatedItems,
        isSubmitting: false,
        actionMessage: '购买成功',
      ));
    } catch (e) {
      AppLogger.error('Failed to purchase item', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '购买失败',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onUpdateItem(
    FleaMarketUpdateItem event,
    Emitter<FleaMarketState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      final updatedItem = await _fleaMarketRepository.updateItem(
        event.itemId.toString(),
        title: event.title,
        description: event.description,
        price: event.price,
        category: event.category,
        images: event.images,
      );

      // 更新列表中的对应项
      final updatedItems = state.items.map((item) {
        final itemIdInt = int.tryParse(item.id);
        return itemIdInt == event.itemId ? updatedItem : item;
      }).toList();

      emit(state.copyWith(
        isSubmitting: false,
        items: updatedItems,
        selectedItem:
            state.selectedItem?.id == updatedItem.id ? updatedItem : null,
        actionMessage: '商品更新成功',
      ));
    } catch (e) {
      AppLogger.error('Failed to update flea market item', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '更新失败: ${e.toString()}',
      ));
    }
  }

  Future<void> _onLoadDetailRequested(
    FleaMarketLoadDetailRequested event,
    Emitter<FleaMarketState> emit,
  ) async {
    emit(state.copyWith(detailStatus: FleaMarketStatus.loading));

    try {
      final item = await _fleaMarketRepository.getItemById(event.itemId.toString());
      emit(state.copyWith(
        detailStatus: FleaMarketStatus.loaded,
        selectedItem: item,
      ));
    } catch (e) {
      AppLogger.error('Failed to load flea market item detail', e);
      emit(state.copyWith(
        detailStatus: FleaMarketStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// 刷新商品（重新上架）- 对标iOS refreshItem
  Future<void> _onRefreshItem(
    FleaMarketRefreshItem event,
    Emitter<FleaMarketState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _fleaMarketRepository.refreshItem(event.itemId.toString());
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '刷新成功',
      ));
      // 重新加载详情以获取最新数据
      add(FleaMarketLoadDetailRequested(event.itemId));
    } catch (e) {
      AppLogger.error('Failed to refresh flea market item', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '刷新失败: ${e.toString()}',
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
          .getItemPurchaseRequests(event.itemId.toString());

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
}
