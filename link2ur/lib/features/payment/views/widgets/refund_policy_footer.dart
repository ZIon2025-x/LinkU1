import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/l10n_extension.dart';

/// 支付页底部的退款政策 footer。
///
/// 显示在 PrimaryButton 下方,提示用户支付即视为已阅读并同意《退款政策》。
/// 「《退款政策》」部分可点击,跳转 [AppRoutes.refundPolicy]。
///
/// StatefulWidget 用于 dispose [TapGestureRecognizer]。
class RefundPolicyFooter extends StatefulWidget {
  const RefundPolicyFooter({super.key});

  @override
  State<RefundPolicyFooter> createState() => _RefundPolicyFooterState();
}

class _RefundPolicyFooterState extends State<RefundPolicyFooter> {
  late final TapGestureRecognizer _tapRecognizer;

  @override
  void initState() {
    super.initState();
    _tapRecognizer = TapGestureRecognizer()
      ..onTap = () {
        if (mounted) {
          context.push(AppRoutes.refundPolicy);
        }
      };
  }

  @override
  void dispose() {
    _tapRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 12, color: baseColor),
          children: [
            TextSpan(text: context.l10n.refundPolicyFooterPrefix),
            TextSpan(
              text: context.l10n.refundPolicyLinkText,
              style: const TextStyle(
                color: AppColors.primary,
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w500,
              ),
              recognizer: _tapRecognizer,
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
