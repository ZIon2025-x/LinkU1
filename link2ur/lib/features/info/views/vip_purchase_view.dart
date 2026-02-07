import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';

/// VIP 购买页
/// 参考iOS VIPPurchaseView.swift
class VIPPurchaseView extends StatefulWidget {
  const VIPPurchaseView({super.key});

  @override
  State<VIPPurchaseView> createState() => _VIPPurchaseViewState();
}

class _VIPPurchaseViewState extends State<VIPPurchaseView> {
  int? _selectedIndex;
  bool _isPurchasing = false;
  String? _errorMessage;

  // VIP 产品列表（模拟数据，实际应从 API/IAP 获取）
  static const _products = [
    _VIPProduct(
      id: 'vip_monthly',
      name: 'VIP Monthly',
      description: '1 Month VIP Membership',
      price: '£4.99',
      priceValue: 4.99,
    ),
    _VIPProduct(
      id: 'vip_quarterly',
      name: 'VIP Quarterly',
      description: '3 Months VIP Membership',
      price: '£12.99',
      priceValue: 12.99,
    ),
    _VIPProduct(
      id: 'vip_yearly',
      name: 'VIP Yearly',
      description: '12 Months VIP Membership',
      price: '£39.99',
      priceValue: 39.99,
    ),
  ];

  Future<void> _purchase() async {
    if (_selectedIndex == null) return;

    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      // TODO: 实际的 IAP 购买逻辑
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.vipPurchaseSuccess)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _errorMessage = e.toString();
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
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 产品列表
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
                        ? AppColors.primary.withOpacity(0.1)
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
                            Text(product.name,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(product.description,
                                style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        AppColors.textSecondary)),
                          ],
                        ),
                      ),

                      // 价格
                      Text(
                        product.price,
                        style: TextStyle(
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
                onPressed: _selectedIndex == null || _isPurchasing
                    ? null
                    : _purchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withOpacity(0.5),
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
              onPressed: () {
                // TODO: 恢复购买逻辑
              },
              child: Text(l10n.vipRestorePurchase,
                  style: TextStyle(color: AppColors.primary)),
            ),

            // 错误信息
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_errorMessage!,
                  style: TextStyle(
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
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(l10n.vipManageSubscription,
                      style: TextStyle(
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
          style: TextStyle(
              fontSize: 14, color: AppColors.primary)),
      trailing: Icon(Icons.chevron_right,
          size: 18, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}

class _VIPProduct {
  const _VIPProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.priceValue,
  });

  final String id;
  final String name;
  final String description;
  final String price;
  final double priceValue;
}
