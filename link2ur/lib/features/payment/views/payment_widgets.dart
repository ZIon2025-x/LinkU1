part of 'payment_view.dart';

/// 优惠券选择底部弹窗
class _CouponSelectorSheet extends StatefulWidget {
  const _CouponSelectorSheet({this.selectedCouponId});

  final int? selectedCouponId;

  @override
  State<_CouponSelectorSheet> createState() => _CouponSelectorSheetState();
}

class _CouponSelectorSheetState extends State<_CouponSelectorSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _coupons = [];

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    try {
      final repo = context.read<CouponPointsRepository>();
      final result = await repo.getMyCoupons(status: 'unused');
      if (mounted) {
        setState(() {
          _coupons = result
              .map((c) => {
                    'id': c.id,
                    'name': c.coupon.name,
                    'description': c.coupon.discountDisplayFormatted,
                  })
              .toList();
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
                  final isSelected = coupon['id'] == widget.selectedCouponId;
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, coupon),
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
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: AppColors.primary),
                        ],
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

