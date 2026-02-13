import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/services/stripe_connect_service.dart';

/// Stripe Connect 入驻页
/// 对标 iOS StripeConnectOnboardingView.swift
///
/// 流程：
/// 1. 检查 /account/status → 获取账户状态
/// 2. 如果 account_id == null → 调用 /account/create-embedded 创建账户
/// 3. 如果有 client_secret → 调用原生 SDK (StripeConnectService) 进行 Onboarding
/// 4. 如果账户已完成 → 加载账户详情并展示
class StripeConnectOnboardingView extends StatefulWidget {
  const StripeConnectOnboardingView({super.key});

  @override
  State<StripeConnectOnboardingView> createState() =>
      _StripeConnectOnboardingViewState();
}

enum _ViewState { loading, ready, completed, error }

class _StripeConnectOnboardingViewState
    extends State<StripeConnectOnboardingView> {
  _ViewState _viewState = _ViewState.loading;
  String? _error;

  // 账户详情（完成后展示）
  StripeConnectAccountDetails? _accountDetails;
  List<ExternalAccount> _externalAccounts = [];

  late final PaymentRepository _paymentRepository;

  @override
  void initState() {
    super.initState();
    _paymentRepository = context.read<PaymentRepository>();
    _loadOnboardingSession();
  }

  /// 对标 iOS loadOnboardingSession()
  Future<void> _loadOnboardingSession() async {
    setState(() {
      _viewState = _ViewState.loading;
      _error = null;
    });

    try {
      final status = await _paymentRepository.getStripeConnectStatus();

      if (!mounted) return;

      if (status.accountId != null &&
          status.detailsSubmitted &&
          status.chargesEnabled) {
        // 账户已完成设置 → 加载详情
        await _loadAccountDetails();
      } else if (status.clientSecret != null &&
          status.clientSecret!.isNotEmpty) {
        // 后端已返回 client_secret（账户已存在但需要继续 onboarding）
        await _startNativeOnboarding(status.clientSecret!);
      } else if (status.accountId == null) {
        // 账户不存在，需要创建
        await _createOnboardingSession();
      } else {
        // 账户存在但没有 client_secret（异常情况），尝试创建 onboarding session
        await _createOnboardingSession();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _viewState = _ViewState.error;
        _error = _extractErrorMessage(e.toString());
      });
    }
  }

  /// 对标 iOS createOnboardingSession()
  Future<void> _createOnboardingSession() async {
    try {
      final result =
          await _paymentRepository.createStripeConnectAccountEmbedded();

      if (!mounted) return;

      final clientSecret = result['client_secret'] as String?;
      final accountStatus = result['account_status'] as bool? ?? false;
      final chargesEnabled = result['charges_enabled'] as bool? ?? false;

      if (accountStatus && chargesEnabled) {
        // 账户已完成设置
        await _loadAccountDetails();
      } else if (clientSecret != null && clientSecret.isNotEmpty) {
        await _startNativeOnboarding(clientSecret);
      } else {
        setState(() {
          _viewState = _ViewState.error;
          _error = context.l10n.stripeOnboardingCreateFailed;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _viewState = _ViewState.error;
        _error = _extractErrorMessage(e.toString());
      });
    }
  }

  /// 启动原生 Onboarding 流程
  Future<void> _startNativeOnboarding(String clientSecret) async {
    // 暂时显示 ready 状态（或 loading）
    setState(() => _viewState = _ViewState.ready);

    try {
      // 获取 Publishable Key
      // 优先从 AppConfig 获取（通过 --dart-define 传入）
      var publishableKey = AppConfig.instance.stripePublishableKey;
      
      // 如果未配置，回退到 iOS 项目中的硬编码 Key (仅作为最后的手段)
      if (publishableKey.isEmpty) {
        publishableKey = "pk_live_51SePW15vvXfvzqMhSEXu7QnduEi7axoPiUMc9gNiV8KFAa82b6rFrrbOFW3gmTiaOETlI3gA0SsAz18SSokFKGLx00bALMvCAg";
      }

      final result = await StripeConnectService.instance.openOnboarding(
        publishableKey: publishableKey,
        clientSecret: clientSecret,
      );

      if (!mounted) return;

      if (result == 'completed') {
        // 完成后重新检查状态
        _loadOnboardingSession();
      } else {
        // 取消或失败：显示具体原因，并提示常见问题
        setState(() {
          _viewState = _ViewState.error;
          _error = result == 'cancelled'
              ? context.l10n.stripeConnectOnboardingCancelled
              : context.l10n.stripeConnectOnboardingFailed;
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _viewState = _ViewState.error;
        _error = e.message ?? e.code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _viewState = _ViewState.error;
        _error = _extractErrorMessage(e.toString());
      });
    }
  }

  /// 对标 iOS loadAccountDetails()
  Future<void> _loadAccountDetails() async {
    try {
      final results = await Future.wait([
        _paymentRepository.getStripeConnectAccountDetails(),
        _paymentRepository.getExternalAccounts(),
      ]);

      if (!mounted) return;

      setState(() {
        _accountDetails = results[0] as StripeConnectAccountDetails;
        _externalAccounts = results[1] as List<ExternalAccount>;
        _viewState = _ViewState.completed;
      });
    } catch (e) {
      if (!mounted) return;
      // 详情加载失败仍显示完成状态，只是没有详情
      setState(() => _viewState = _ViewState.completed);
    }
  }

  String _extractErrorMessage(String message) {
    final colonIndex = message.indexOf(': ');
    if (colonIndex > 0 && colonIndex < 30) {
      return message.substring(colonIndex + 2);
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentStripeConnect),
      ),
      body: switch (_viewState) {
        _ViewState.loading => const Center(child: LoadingView()),
        _ViewState.error => _buildErrorView(isDark),
        _ViewState.completed => _buildCompletedView(isDark),
        _ViewState.ready => const Center(child: LoadingView()), // Native UI 覆盖
      },
    );
  }

  Widget _buildErrorView(bool isDark) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error.withValues(alpha: 0.7),
            ),
            AppSpacing.vLg,
            Text(
              _error ?? l10n.stripeConnectLoadFailed,
              style: TextStyle(
                fontSize: 16,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vMd,
            Text(
              l10n.stripeConnectOnboardingErrorHint,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vXl,
            PrimaryButton(
              text: l10n.commonRetry,
              onPressed: _loadOnboardingSession,
              width: 200,
            ),
          ],
        ),
      ),
    );
  }

  /// 对标 iOS accountDetailsView — 完成后展示账户详情 + 外部账户
  Widget _buildCompletedView(bool isDark) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // 成功图标
          AppSpacing.vLg,
          const Icon(
            Icons.check_circle,
            size: 50,
            color: AppColors.success,
          ),
          AppSpacing.vMd,
          Text(
            l10n.paymentAccountSetupComplete,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.paymentAccountInfoBelow,
            style: TextStyle(
              fontSize: 15,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          AppSpacing.vXl,

          // 账户信息卡片
          if (_accountDetails != null) ...[
            _AccountInfoCard(details: _accountDetails!, isDark: isDark),
            AppSpacing.vMd,
          ],

          // 外部账户
          if (_externalAccounts.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.paymentExternalAccount,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            AppSpacing.vSm,
            ..._externalAccounts.map((account) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child:
                      _ExternalAccountCard(account: account, isDark: isDark),
                )),
            AppSpacing.vMd,
          ],

          // 操作按钮
          OutlinedButton.icon(
            onPressed: _loadAccountDetails,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l10n.paymentRefreshAccountInfo),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
          AppSpacing.vMd,
          PrimaryButton(
            text: l10n.paymentComplete,
            onPressed: () => context.pop(true),
          ),
          AppSpacing.vLg,
        ],
      ),
    );
  }

}

/// 账户信息卡片
class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({required this.details, required this.isDark});

  final StripeConnectAccountDetails details;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.paymentAccountInfo,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          AppSpacing.vMd,
          _InfoRow(label: l10n.paymentAccountId, value: details.accountId),
          if (details.displayName != null)
            _InfoRow(
                label: l10n.paymentDisplayName,
                value: details.displayName!),
          if (details.email != null)
            _InfoRow(label: 'Email', value: details.email!),
          _InfoRow(label: l10n.paymentCountry, value: details.country),
          _InfoRow(label: l10n.paymentAccountType, value: details.type),
          _InfoRow(
            label: l10n.paymentChargesEnabled,
            value: details.chargesEnabled ? l10n.paymentYes : l10n.paymentNo,
            valueColor:
                details.chargesEnabled ? AppColors.success : AppColors.error,
          ),
          _InfoRow(
            label: l10n.paymentPayoutsEnabled,
            value: details.payoutsEnabled ? l10n.paymentYes : l10n.paymentNo,
            valueColor:
                details.payoutsEnabled ? AppColors.success : AppColors.error,
          ),
        ],
      ),
    );
  }
}

/// 外部账户卡片
class _ExternalAccountCard extends StatelessWidget {
  const _ExternalAccountCard({required this.account, required this.isDark});

  final ExternalAccount account;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              account.isBankAccount
                  ? Icons.account_balance
                  : Icons.credit_card,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.isBankAccount
                      ? (account.bankName ?? l10n.paymentBankAccount)
                      : (account.brand ?? l10n.paymentCard),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '•••• ${account.last4 ?? '****'}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textTertiary),
                ),
                if (account.isCard &&
                    account.expMonth != null &&
                    account.expYear != null)
                  Text(
                    '${l10n.paymentExpiry}: ${account.expMonth}/${account.expYear}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
              ],
            ),
          ),
          if (account.isDefault)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Default',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 信息行
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
