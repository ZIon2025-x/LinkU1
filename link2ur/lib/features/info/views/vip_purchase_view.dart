import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/services/iap_service.dart';

/// VIP 购买页
/// 参考iOS VIPPurchaseView.swift
/// 集成 in_app_purchase 实现真实 IAP 购买
class VIPPurchaseView extends StatefulWidget {
  const VIPPurchaseView({super.key});

  @override
  State<VIPPurchaseView> createState() => _VIPPurchaseViewState();
}

class _VIPPurchaseViewState extends State<VIPPurchaseView> {
  int? _selectedIndex;
  bool _isPurchasing = false;
  bool _isLoadingProducts = true;
  String? _errorMessage;
  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    // 监听购买完成
    IAPService.instance.onPurchaseComplete = _onPurchaseComplete;
  }

  @override
  void dispose() {
    IAPService.instance.onPurchaseComplete = null;
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _errorMessage = null;
    });

    final iapService = IAPService.instance;

    // 如果产品尚未加载，重新加载
    if (iapService.products.isEmpty) {
      await iapService.loadProducts();
    }

    if (mounted) {
      setState(() {
        _products = iapService.products;
        _isLoadingProducts = false;
        if (_products.isEmpty && iapService.errorMessage != null) {
          _errorMessage = iapService.errorMessage;
        }
      });
    }
  }

  void _onPurchaseComplete(bool success, String? error) {
    if (!mounted) return;

    setState(() => _isPurchasing = false);

    if (success) {
      _showPurchaseSuccessDialog();
    } else if (error != null) {
      setState(() => _errorMessage = error);
    }
  }

  void _showPurchaseSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF9500)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 12),
            Text(context.l10n.vipPurchaseSuccess),
          ],
        ),
        content: Text(
          context.l10n.vipCongratulations,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(context.l10n.vipPurchaseConfirm),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _purchase() async {
    if (_selectedIndex == null || _selectedIndex! >= _products.length) return;

    final product = _products[_selectedIndex!];

    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      await IAPService.instance.purchase(product);
      // 实际购买结果会通过 onPurchaseComplete 回调
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _errorMessage = context.l10n.purchaseFailed;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      await IAPService.instance.restorePurchases();
      // 等待一下让购买流处理
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() => _isPurchasing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.vipPurchaseRestoreMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _errorMessage = context.l10n.restorePurchaseFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vipPurchaseTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),

            // 标题
            Text(
              l10n.vipBecomeVip,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.vipSelectPackage,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 加载状态
            if (_isLoadingProducts)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              )
            else if (_products.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.workspace_premium,
                        size: 48, color: AppColors.textTertiary),
                    const SizedBox(height: 12),
                    Text(context.l10n.vipNoProducts,
                        style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _loadProducts,
                      child: Text(context.l10n.commonReload),
                    ),
                  ],
                ),
              )
            else
              // 产品列表 - 使用真实 IAP 产品
              ...List.generate(_products.length, (index) {
                final product = _products[index];
                final isSelected = _selectedIndex == index;

                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Theme.of(context).cardColor,
                      borderRadius:
                          BorderRadius.circular(AppRadius.medium),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        // 选择器
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textTertiary,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 14)
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.md),

                        // 产品信息
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.title,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(product.description,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                        ),

                        // 价格
                        Text(
                          product.price,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: AppSpacing.lg),

            // 购买按钮
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                    _selectedIndex == null || _isPurchasing || _products.isEmpty
                        ? null
                        : _purchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppRadius.large),
                  ),
                ),
                child: _isPurchasing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _selectedIndex == null
                            ? l10n.vipPleaseSelect
                            : l10n.vipBuyNow,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 恢复购买
            TextButton(
              onPressed: _isPurchasing ? null : _restorePurchases,
              child: Text(l10n.vipRestorePurchase,
                  style: const TextStyle(color: AppColors.primary)),
            ),

            // 错误信息
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_errorMessage!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 13)),
            ],

            const SizedBox(height: AppSpacing.xl),

            // 说明
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius:
                    BorderRadius.circular(AppRadius.medium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.vipPurchaseInstructions,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(l10n.vipSubscriptionAutoRenew,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(l10n.vipManageSubscription,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 隐私政策 & 服务条款
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius:
                    BorderRadius.circular(AppRadius.medium),
              ),
              child: Column(
                children: [
                  _buildLink(
                    context,
                    l10n.infoPrivacyPolicy,
                    () => context.push('/privacy'),
                  ),
                  const Divider(height: 1),
                  _buildLink(
                    context,
                    l10n.infoTermsOfService,
                    () => context.push('/terms'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildLink(
      BuildContext context, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title,
          style: const TextStyle(
              fontSize: 14, color: AppColors.primary)),
      trailing: const Icon(Icons.chevron_right,
          size: 18, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
