import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/utils/logger.dart';
import '../../core/config/api_config.dart';
import 'api_service.dart';

/// IAP 内购服务
/// 对齐 iOS IAPService.swift
/// 负责 VIP 订阅的加载、购买、验证、恢复和状态管理
class IAPService {
  IAPService._();
  static final IAPService instance = IAPService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  ApiService? _apiService;

  /// 产品 ID
  static const String vipMonthlyId = 'com.link2ur.vip.monthly';
  static const String vipYearlyId = 'com.link2ur.vip.yearly';
  static const Set<String> _productIds = {vipMonthlyId, vipYearlyId};

  /// 可用产品列表
  List<ProductDetails> products = [];

  /// 已购买的产品 ID
  final Set<String> _purchasedProductIds = {};

  /// 购买状态流
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// 加载状态
  bool isLoading = false;

  /// 错误信息
  String? errorMessage;

  /// 是否已初始化
  bool _initialized = false;

  /// 购买完成回调
  void Function(bool success, String? error)? onPurchaseComplete;

  /// 懒初始化：首次进入支付/VIP 页面时调用
  /// 如果已经初始化过则直接返回，避免重复初始化
  Future<void> ensureInitialized({required ApiService apiService}) async {
    if (_initialized) return;
    await initialize(apiService: apiService);
  }

  /// 初始化
  Future<void> initialize({required ApiService apiService}) async {
    _initialized = true;
    _apiService = apiService;

    // Web 上不支持应用内购买
    if (kIsWeb) {
      AppLogger.info('IAP: Not available on Web');
      errorMessage = 'Web 端不支持应用内购买';
      return;
    }

    final available = await _iap.isAvailable();
    if (!available) {
      AppLogger.warning('IAP: Store not available');
      errorMessage = '应用商店不可用';
      return;
    }

    // 监听购买流
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        AppLogger.error('IAP: Purchase stream error', error);
      },
    );

    // 加载产品
    await loadProducts();

    AppLogger.info('IAP: Service initialized');
  }

  /// 加载产品列表
  Future<void> loadProducts() async {
    isLoading = true;
    errorMessage = null;

    try {
      final response = await _iap.queryProductDetails(_productIds);
      if (response.error != null) {
        AppLogger.error('IAP: Query products error', response.error);
        errorMessage = '加载产品失败: ${response.error?.message}';
      }

      if (response.notFoundIDs.isNotEmpty) {
        AppLogger.warning(
            'IAP: Products not found: ${response.notFoundIDs}');
      }

      products = response.productDetails.toList();
      // 按价格排序（月度在前）
      products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

      AppLogger.info('IAP: Loaded ${products.length} products');
    } catch (e) {
      AppLogger.error('IAP: Load products failed', e);
      errorMessage = '加载产品失败';
    } finally {
      isLoading = false;
    }
  }

  /// 购买产品
  Future<void> purchase(ProductDetails product) async {
    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      // VIP 为订阅类型，使用 buyNonConsumable
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      AppLogger.info('IAP: Purchase initiated for ${product.id}');
    } catch (e) {
      AppLogger.error('IAP: Purchase failed', e);
      onPurchaseComplete?.call(false, '购买失败: $e');
    }
  }

  /// 恢复购买
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
      AppLogger.info('IAP: Restore purchases initiated');
    } catch (e) {
      AppLogger.error('IAP: Restore purchases failed', e);
    }
  }

  /// 处理购买更新
  Future<void> _onPurchaseUpdate(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          AppLogger.info('IAP: Purchase pending - ${purchase.productID}');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final valid = await _verifyAndSync(purchase);
          if (valid) {
            _purchasedProductIds.add(purchase.productID);
            onPurchaseComplete?.call(true, null);
          } else {
            onPurchaseComplete?.call(false, '验证失败，请联系客服');
          }
          break;

        case PurchaseStatus.error:
          AppLogger.error(
              'IAP: Purchase error - ${purchase.error?.message}');
          onPurchaseComplete?.call(
              false, purchase.error?.message ?? '购买失败');
          break;

        case PurchaseStatus.canceled:
          AppLogger.info('IAP: Purchase cancelled');
          onPurchaseComplete?.call(false, null);
          break;
      }

      // 完成交易
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// 验证购买并同步到后端
  Future<bool> _verifyAndSync(PurchaseDetails purchase) async {
    if (_apiService == null) return false;

    try {
      final response = await _apiService!.post<Map<String, dynamic>>(
        ApiEndpoints.activateVIP,
        data: {
          'product_id': purchase.productID,
          'transaction_id':
              purchase.purchaseID ?? '',
          'receipt_data':
              purchase.verificationData.serverVerificationData,
          'platform': ApiConfig.platformId,
        },
      );

      if (response.isSuccess) {
        AppLogger.info(
            'IAP: VIP activated for ${purchase.productID}');
        return true;
      } else {
        AppLogger.error(
            'IAP: VIP activation failed - ${response.message}');
        return false;
      }
    } catch (e) {
      AppLogger.error('IAP: Verify and sync failed', e);
      return false;
    }
  }

  /// 检查是否有活跃的 VIP 订阅
  bool get hasActiveVIP => _purchasedProductIds.isNotEmpty;

  /// 获取已购买的产品 ID
  Set<String> get purchasedProductIds =>
      Set.unmodifiable(_purchasedProductIds);

  /// 通过产品 ID 获取产品详情
  ProductDetails? getProduct(String productId) {
    try {
      return products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }

  /// 释放资源
  void dispose() {
    _subscription?.cancel();
  }
}
