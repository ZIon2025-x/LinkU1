import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../data/models/flea_market.dart';
import '../bloc/flea_market_rental_bloc.dart';

/// 租用申请底部弹窗
class RentalRequestSheet extends StatefulWidget {
  const RentalRequestSheet({super.key, required this.item, required this.bloc});

  final FleaMarketItem item;
  final FleaMarketRentalBloc bloc;

  static Future<void> show(BuildContext context, FleaMarketItem item) {
    final bloc = context.read<FleaMarketRentalBloc>();
    return SheetAdaptation.showAdaptiveModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RentalRequestSheet(item: item, bloc: bloc),
    );
  }

  @override
  State<RentalRequestSheet> createState() => _RentalRequestSheetState();
}

class _RentalRequestSheetState extends State<RentalRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _durationController = TextEditingController();
  final _desiredTimeController = TextEditingController();
  final _usageController = TextEditingController();
  final _proposedPriceController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _durationController.dispose();
    _desiredTimeController.dispose();
    _usageController.dispose();
    _proposedPriceController.dispose();
    super.dispose();
  }

  int? get _duration => int.tryParse(_durationController.text.trim());

  double get _rentalPrice => widget.item.rentalPrice ?? 0;
  double get _deposit => widget.item.deposit ?? 0;

  double get _subtotal {
    final d = _duration;
    if (d == null || d <= 0) return 0;
    return _rentalPrice * d;
  }

  double get _total => _subtotal + _deposit;

  String _unitLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch (widget.item.rentalUnit) {
      'week' => l10n.fleaMarketRentalUnitWeek,
      'month' => l10n.fleaMarketRentalUnitMonth,
      _ => l10n.fleaMarketRentalUnitDay,
    };
  }

  String _perUnitLabel(BuildContext context) {
    final l10n = context.l10n;
    return switch (widget.item.rentalUnit) {
      'week' => l10n.fleaMarketPerWeek,
      'month' => l10n.fleaMarketPerMonth,
      _ => l10n.fleaMarketPerDay,
    };
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final proposedPrice = double.tryParse(_proposedPriceController.text.trim());
    final desiredTime = _desiredTimeController.text.trim();
    final usage = _usageController.text.trim();

    widget.bloc.add(
          RentalSubmitRequest(
            itemId: widget.item.id,
            rentalDuration: _duration!,
            desiredTime: desiredTime.isEmpty ? null : desiredTime,
            usageDescription: usage.isEmpty ? null : usage,
            proposedRentalPrice: proposedPrice,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = Helpers.currencySymbolFor(widget.item.currency);

    return BlocListener<FleaMarketRentalBloc, FleaMarketRentalState>(
      bloc: widget.bloc,
      listenWhen: (p, c) =>
          c.actionMessage == 'rental_request_sent' ||
          (c.errorMessage != null && c.errorMessage != p.errorMessage),
      listener: (context, state) {
        if (state.actionMessage == 'rental_request_sent') {
          Navigator.of(context).pop();
          return;
        }
        if (state.errorMessage != null) {
          if (mounted) {
            setState(() {
              _isSubmitting = false;
              _errorMessage = state.errorMessage;
            });
          }
        }
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    // 标题栏
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.fleaMarketApplyToRent,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          IconButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            tooltip: 'Close',
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 商品预览
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.skeletonBase
                                      : AppColors.skeletonHighlight,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    if (widget.item.firstImage != null)
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        child: Image.network(
                                          widget.item.firstImage!,
                                          width: 70,
                                          height: 70,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox(
                                                  width: 70, height: 70),
                                        ),
                                      ),
                                    if (widget.item.firstImage != null)
                                      const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.item.title,
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '$symbol${_rentalPrice.toStringAsFixed(2)}${_perUnitLabel(context)}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.priceRed,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // 租用时长
                              Text(
                                l10n.fleaMarketRentalDuration,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _durationController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: '1',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.medium),
                                        ),
                                        filled: true,
                                        fillColor: isDark
                                            ? AppColors.skeletonBase
                                            : AppColors.skeletonHighlight,
                                      ),
                                      validator: (value) {
                                        final v = int.tryParse(
                                            value?.trim() ?? '');
                                        if (v == null || v <= 0) {
                                          return l10n.fleaMarketRentalDuration;
                                        }
                                        return null;
                                      },
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.medium),
                                    ),
                                    child: Text(
                                      _unitLabel(context),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 期望开始时间
                              Text(
                                l10n.fleaMarketDesiredTime,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _desiredTimeController,
                                decoration: InputDecoration(
                                  hintText: l10n.fleaMarketDesiredTimeHint,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.medium),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? AppColors.skeletonBase
                                      : AppColors.skeletonHighlight,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 使用场景
                              Text(
                                l10n.fleaMarketUsageDescription,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _usageController,
                                maxLines: 3,
                                maxLength: 500,
                                decoration: InputDecoration(
                                  hintText:
                                      l10n.fleaMarketUsageDescriptionHint,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.medium),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? AppColors.skeletonBase
                                      : AppColors.skeletonHighlight,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 建议价格（选填）
                              Text(
                                l10n.fleaMarketProposedPrice,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _proposedPriceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  hintText: l10n.fleaMarketProposedPriceHint,
                                  prefixText: '$symbol ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.medium),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? AppColors.skeletonBase
                                      : AppColors.skeletonHighlight,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // 费用预览
                              _buildCostPreview(context, symbol),

                              // 错误信息
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 18,
                                          color: AppColors.error),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                              color: AppColors.error,
                                              fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),

                              // 提交按钮
                              SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isSubmitting ? null : () => _submit(),
                                  icon: _isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.send, size: 20),
                                  label: Text(
                                    l10n.fleaMarketApplyToRent,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(25),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSubmitting)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                                color: Colors.white),
                            const SizedBox(height: 16),
                            Text(
                              l10n.fleaMarketRentalRequestSent,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCostPreview(BuildContext context, String symbol) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = _duration;
    final hasValidDuration = d != null && d > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                l10n.fleaMarketRentalCostPreview,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 租金小计
          _costRow(
            l10n.fleaMarketRentalSubtotal,
            hasValidDuration
                ? '$symbol${_subtotal.toStringAsFixed(2)}'
                : '--',
            isDark: isDark,
          ),
          if (hasValidDuration)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Text(
                '$symbol${_rentalPrice.toStringAsFixed(2)} x $d ${_unitLabel(context)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ),
          // 押金
          _costRow(
            l10n.fleaMarketDeposit,
            '$symbol${_deposit.toStringAsFixed(2)}',
            isDark: isDark,
          ),
          const Divider(height: 16),
          // 合计
          _costRow(
            l10n.fleaMarketRentalTotal,
            hasValidDuration
                ? '$symbol${_total.toStringAsFixed(2)}'
                : '--',
            isDark: isDark,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _costRow(String label, String value,
      {required bool isDark, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 15 : 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 18 : 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold
                  ? AppColors.priceRed
                  : (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight),
            ),
          ),
        ],
      ),
    );
  }
}
