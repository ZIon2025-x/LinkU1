part of 'payment_view.dart';

/// 优惠券选择底部弹窗
class _CouponSelectorSheet extends StatefulWidget {
  const _CouponSelectorSheet({
    this.selectedUserCouponId,
    this.orderAmountPence,
    this.taskId,
  });

  final int? selectedUserCouponId;
  /// 订单金额（便士），用于过滤不满足最低使用金额的优惠券
  final int? orderAmountPence;
  /// 任务ID，传入后后端会校验每张券的适用性
  final int? taskId;

  @override
  State<_CouponSelectorSheet> createState() => _CouponSelectorSheetState();
}

class _CouponSelectorSheetState extends State<_CouponSelectorSheet> {
  bool _isLoading = true;
  /// 每项包含 id, name, description, applicable (bool?), inapplicableReason (String?)
  List<Map<String, dynamic>> _coupons = [];

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    try {
      final repo = context.read<CouponPointsRepository>();
      final result = await repo.getMyCoupons(
        status: 'unused',
        taskId: widget.taskId,
      );
      if (mounted) {
        setState(() {
          _coupons = result
              .where((c) => c.isUsable) // 过滤已过期但 status 未更新的优惠券
              .map((c) => {
                    'id': c.id,
                    'name': c.coupon.name,
                    'description': c.coupon.discountDisplayFormatted,
                    'applicable': c.applicable,
                    'inapplicableReason': c.inapplicableReason,
                  })
              .toList();
          // 适用的排前面，不适用的排后面
          _coupons.sort((a, b) {
            final aOk = a['applicable'] != false;
            final bOk = b['applicable'] != false;
            if (aOk && !bOk) return -1;
            if (!aOk && bOk) return 1;
            return 0;
          });
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 不画自定义拖拽条：主题 showDragHandle: true 已提供
          const SizedBox(height: 16),
          Text(
            context.l10n.paymentSelectCoupon,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: LoadingView(),
              ),
            )
          else if (_coupons.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(Icons.local_offer_outlined,
                      size: 48, color: AppColors.textTertiaryLight),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.paymentNoAvailableCoupons,
                    style: const TextStyle(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                itemCount: _coupons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final coupon = _coupons[index];
                  final isSelected = coupon['id'] == widget.selectedUserCouponId;
                  final isApplicable = coupon['applicable'] != false;
                  final reason = coupon['inapplicableReason'] as String?;
                  return Semantics(
                    button: isApplicable,
                    label: 'View details',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: isApplicable
                          ? () => Navigator.pop(context, coupon)
                          : null,
                      child: Opacity(
                        opacity: isApplicable ? 1.0 : 0.45,
                        child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.05)
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.dividerLight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.accentPink.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.local_offer,
                                color: AppColors.accentPink,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    coupon['name'] ?? context.l10n.paymentCoupon,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (coupon['description'] != null)
                                    Text(
                                      coupon['description'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  if (!isApplicable && reason != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        reason,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle,
                                  color: AppColors.primary),
                          ],
                        ),
                      ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

