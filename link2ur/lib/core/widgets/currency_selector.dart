import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';

/// 货币选项配置
class CurrencyOption {
  const CurrencyOption({
    required this.code,
    required this.symbol,
    required this.name,
    this.paymentTags = const [],
    this.isRecommended = false,
  });

  final String code;
  final String symbol;
  final String name;
  final List<PaymentTag> paymentTags;
  final bool isRecommended;
}

/// 支付方式标签
class PaymentTag {
  const PaymentTag({required this.label, required this.color, required this.bgColor});

  final String label;
  final Color color;
  final Color bgColor;
}

/// 预定义支付标签
class PaymentTags {
  PaymentTags._();

  static const card = PaymentTag(
    label: '💳 Card',
    color: Color(0xFF7B1FA2),
    bgColor: Color(0xFFF3E5F5),
  );
  static const applePay = PaymentTag(
    label: ' Apple Pay',
    color: Color(0xFF333333),
    bgColor: Color(0xFFF5F5F5),
  );
  static const wechatPay = PaymentTag(
    label: '微信支付',
    color: Color(0xFF2E7D32),
    bgColor: Color(0xFFE8F5E9),
  );
  static const alipay = PaymentTag(
    label: '支付宝',
    color: Color(0xFF1565C0),
    bgColor: Color(0xFFE3F2FD),
  );
}

/// 默认的 GBP + EUR 选项（任务、跳蚤市场、个人服务）
final List<CurrencyOption> defaultCurrencyOptions = [
  const CurrencyOption(
    code: 'GBP',
    symbol: '£',
    name: 'British Pound',
    isRecommended: true,
    paymentTags: [PaymentTags.card, PaymentTags.applePay, PaymentTags.wechatPay, PaymentTags.alipay],
  ),
  const CurrencyOption(
    code: 'EUR',
    symbol: '€',
    name: 'Euro',
    paymentTags: [PaymentTags.card, PaymentTags.applePay],
  ),
];


/// 货币选择器组件
///
/// 用于任务发布、跳蚤市场发布等需要选择货币的页面。
/// 对齐 mockup：显示支付方式标签，GBP 带"推荐"徽章。
class CurrencySelector extends StatelessWidget {
  const CurrencySelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.options,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  /// 货币选项列表，默认为 [defaultCurrencyOptions]
  final List<CurrencyOption>? options;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = options ?? defaultCurrencyOptions;

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _CurrencyOptionTile(
            option: items[i],
            isSelected: items[i].code == selected,
            isDark: isDark,
            onTap: () => onChanged(items[i].code),
          ),
        ],
      ],
    );
  }
}

class _CurrencyOptionTile extends StatelessWidget {
  const _CurrencyOptionTile({
    required this.option,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final CurrencyOption option;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08)),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.04)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // 货币图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: option.code == 'GBP'
                    ? const Color(0xFFEEF0FF)
                    : option.code == 'EUR'
                        ? const Color(0xFFFFF8E1)
                        : option.code == 'CNY'
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                option.symbol,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            // 货币信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名称 + 推荐标签
                  Row(
                    children: [
                      Text(
                        '${option.name}  ${option.code}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      if (option.isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '推荐',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  // 支付方式标签
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: option.paymentTags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tag.bgColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: tag.color,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            // 单选圆圈
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : (isDark ? Colors.white30 : Colors.black26),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
