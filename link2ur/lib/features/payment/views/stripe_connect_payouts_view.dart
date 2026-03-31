import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/external_web_view.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/payment_repository.dart';
import 'stripe_connect_account_webview.dart';

/// Stripe Connect 提现管理页
/// 对标 iOS StripeConnectPayoutsView.swift
/// 包含：余额卡片、提现按钮、查看详情、交易记录、提现弹窗、账户详情弹窗
class StripeConnectPayoutsView extends StatefulWidget {
  const StripeConnectPayoutsView({super.key});

  @override
  State<StripeConnectPayoutsView> createState() =>
      _StripeConnectPayoutsViewState();
}

class _StripeConnectPayoutsViewState extends State<StripeConnectPayoutsView> {
  List<WalletBalance> _walletBalances = [];
  /// 当前选中的钱包索引（用于提现时选择币种）
  int _selectedWalletIndex = 0;
  StripeConnectStatus? _connectStatus;
  StripeConnectAccountDetails? _accountDetails;
  List<ExternalAccount> _externalAccounts = [];
  List<StripeConnectTransaction> _transactions = [];
  bool _isLoading = true;
  bool _isCreatingPayout = false;
  String? _error;

  late final PaymentRepository _repo;

  /// 便捷访问：当前选中的钱包
  WalletBalance? get _selectedWallet =>
      _walletBalances.isNotEmpty ? _walletBalances[_selectedWalletIndex] : null;

  @override
  void initState() {
    super.initState();
    _repo = context.read<PaymentRepository>();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repo.getWalletBalances(),
        _repo.getStripeConnectStatus(),
        _repo.getStripeConnectTransactions(),
      ]);

      if (!mounted) return;

      final wallets = results[0] as List<WalletBalance>;
      final allTransactions = results[2] as List<StripeConnectTransaction>;
      // 对标 iOS：提现记录页只显示支出（expense）
      final expenseOnly = allTransactions
          .where((t) => t.type.toLowerCase() == 'expense')
          .toList();

      setState(() {
        _walletBalances = wallets;
        // 确保 selectedIndex 不越界
        if (_selectedWalletIndex >= wallets.length) {
          _selectedWalletIndex = 0;
        }
        _connectStatus = results[1] as StripeConnectStatus;
        _transactions = expenseOnly;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = ErrorLocalizer.localizeFromException(context, e);
      });
    }
  }

  Future<void> _loadAccountDetails() async {
    try {
      final results = await Future.wait([
        _repo.getStripeConnectAccountDetails(),
        _repo.getExternalAccounts(),
      ]);

      if (!mounted) return;

      setState(() {
        _accountDetails = results[0] as StripeConnectAccountDetails;
        _externalAccounts = results[1] as List<ExternalAccount>;
      });
    } catch (e) {
      AppLogger.warning('Failed to load Stripe account details: $e');
    }
  }

  Future<void> _createPayout(double amount, String currency) async {
    setState(() => _isCreatingPayout = true);

    try {
      final requestId = const Uuid().v4();
      await _repo.requestWithdrawal(
        amount: amount,
        requestId: requestId,
        currency: currency,
      );

      if (!mounted) return;

      // 刷新余额和交易记录
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      final message = ErrorLocalizer.localizeFromException(context, e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isCreatingPayout = false);
    }
  }

  void _showDashboardUnavailableSnackBar([String? reason]) {
    if (!mounted) return;
    final l10n = context.l10n;
    final msg = switch (reason) {
      'onboarding_incomplete' => l10n.stripeConnectDashboardOnboardingIncomplete,
      'account_restricted' => l10n.stripeConnectDashboardAccountRestricted,
      'unsupported_account_type' => l10n.stripeConnectDashboardUnsupportedType,
      _ => l10n.stripeConnectDashboardUnavailable,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _openStripeDashboard() async {
    final l10n = context.l10n;
    try {
      final details = await _repo.getStripeConnectAccountDetails();
      if (!mounted) return;
      final url = details.dashboardUrl;
      if (url != null && url.isNotEmpty) {
        await ExternalWebView.openInApp(
          context,
          url: url,
          title: l10n.stripeConnectOpenDashboard,
        );
        return;
      }
      if (details.dashboardUnavailableReason == 'unsupported_account_type') {
        // V2 账户使用嵌入式账户管理
        await _openAccountManagement(details.accountId);
        return;
      }
      _showDashboardUnavailableSnackBar(details.dashboardUnavailableReason);
    } catch (_) {
      _showDashboardUnavailableSnackBar();
    }
  }

  Future<void> _openAccountManagement(String accountId) async {
    try {
      final publishableKey = AppConfig.instance.stripePublishableKey;
      if (publishableKey.isEmpty) return;

      final session = await _repo.createAccountManagementSession(accountId);
      final clientSecret = session['client_secret'] as String?;
      if (clientSecret == null || clientSecret.isEmpty) {
        _showDashboardUnavailableSnackBar();
        return;
      }

      if (!mounted) return;
      // V2 账户没有 Express Dashboard，不传 onOpenDashboard
      await StripeConnectAccountWebView.open(
        context,
        publishableKey: publishableKey,
        clientSecret: clientSecret,
      );

      // 管理完成后刷新数据
      if (mounted) await _loadAll();
    } catch (_) {
      _showDashboardUnavailableSnackBar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentPayoutManagement),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser_outlined),
            tooltip: l10n.stripeConnectOpenDashboard,
            onPressed: _openStripeDashboard,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.paymentRecordsLoadFailed),
                      AppSpacing.vMd,
                      TextButton(
                        onPressed: _loadAll,
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 余额卡片 — 支持多币种
                              if (_walletBalances.isNotEmpty) ...[
                                // 多币种选择器
                                if (_walletBalances.length > 1) ...[
                                  _CurrencySelector(
                                    wallets: _walletBalances,
                                    selectedIndex: _selectedWalletIndex,
                                    onSelected: (index) =>
                                        setState(() => _selectedWalletIndex = index),
                                  ),
                                  AppSpacing.vMd,
                                ],
                                _BalanceCard(walletBalance: _selectedWallet!),
                                AppSpacing.vMd,
                                // 按钮组
                                _ActionButtons(
                                  walletBalance: _selectedWallet!,
                                  isCreatingPayout: _isCreatingPayout,
                                  onViewDetails: () async {
                                    await _loadAccountDetails();
                                    if (!mounted) return;
                                    _showAccountDetailsSheet();
                                  },
                                  onPayout: () => _showPayoutSheet(),
                                ),
                                AppSpacing.vMd,
                                if (_selectedWallet!.balance == 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.medium),
                                    ),
                                    child: Text(
                                      l10n.paymentNoAvailableBalance,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ),
                              ],
                              AppSpacing.vLg,
                              // 交易记录标题
                              Text(
                                l10n.paymentPayoutRecords,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              AppSpacing.vSm,
                              // 交易记录列表空状态
                              if (_transactions.isEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 40),
                                  child: EmptyStateView(
                                    icon: Icons.account_balance,
                                    title: l10n.paymentNoPayoutRecords,
                                    message: l10n.paymentNoPayoutRecordsMessage,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_transactions.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final t = _transactions[index];
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm),
                                  child: _TransactionCard(
                                    transaction: t,
                                    onTap: () => _showTransactionDetailSheet(t),
                                  ),
                                );
                              },
                              childCount: _transactions.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  void _showPayoutSheet() {
    // 检查是否已绑定收款账户
    if (_connectStatus == null || !_connectStatus!.isConnected) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.stripeConnectRequired),
          content: Text(context.l10n.stripeConnectSetupPrompt),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go(AppRoutes.stripeConnectOnboarding);
              },
              child: Text(context.l10n.stripeConnectSetupNow),
            ),
          ],
        ),
      );
      return;
    }

    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PayoutSheet(
        walletBalance: _selectedWallet!,
        isCreatingPayout: _isCreatingPayout,
        onCreatePayout: _createPayout,
      ),
    );
  }

  void _showAccountDetailsSheet() {
    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _AccountDetailsSheet(
          accountDetails: _accountDetails,
          externalAccounts: _externalAccounts,
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _showTransactionDetailSheet(StripeConnectTransaction transaction) {
    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => _TransactionDetailSheet(
          transaction: transaction,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

/// 币种选择器（多钱包时显示）
class _CurrencySelector extends StatelessWidget {
  const _CurrencySelector({
    required this.wallets,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<WalletBalance> wallets;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < wallets.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: i == selectedIndex
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(
                    color: i == selectedIndex
                        ? AppColors.primary
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      wallets[i].currency.toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: i == selectedIndex
                            ? AppColors.primary
                            : AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Helpers.formatPrice(
                        wallets[i].balance,
                        currency: wallets[i].currency,
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: i == selectedIndex
                            ? AppColors.primary
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 余额卡片（本地钱包余额）
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.walletBalance});
  final WalletBalance walletBalance;

  String _formatAmount(double amount) {
    return '${Helpers.currencySymbolFor(walletBalance.currency)}${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // 可提现余额
          Text(
            l10n.paymentAvailableBalance,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatAmount(walletBalance.balance),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          AppSpacing.vMd,
          const Divider(),
          AppSpacing.vMd,
          // 累计收入和累计提现
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.walletTotalEarned,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatAmount(walletBalance.totalEarned),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      l10n.walletTotalWithdrawn,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatAmount(walletBalance.totalWithdrawn),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 操作按钮组
class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.walletBalance,
    required this.isCreatingPayout,
    required this.onViewDetails,
    required this.onPayout,
  });

  final WalletBalance walletBalance;
  final bool isCreatingPayout;
  final VoidCallback onViewDetails;
  final VoidCallback onPayout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onViewDetails,
            icon: const Icon(Icons.info_outline, size: 18),
            label: Text(l10n.paymentViewDetails),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        if (walletBalance.balance > 0) ...[
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FilledButton.icon(
              onPressed: isCreatingPayout ? null : onPayout,
              icon: const Icon(Icons.arrow_upward, size: 18),
              label: Text(l10n.paymentPayout),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
                backgroundColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 交易记录卡片
class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction, this.onTap});

  final StripeConnectTransaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;

    return Semantics(
      button: true,
      label: 'View details',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isIncome ? AppColors.success : AppColors.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome ? AppColors.success : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description.isNotEmpty
                        ? transaction.description
                        : transaction.source,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(transaction.createdAt),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            Text(
              transaction.amountDisplay,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isIncome ? AppColors.success : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal());
    } catch (_) {
      return dateStr;
    }
  }
}

/// 提现弹窗
class _PayoutSheet extends StatefulWidget {
  const _PayoutSheet({
    required this.walletBalance,
    required this.isCreatingPayout,
    required this.onCreatePayout,
  });

  final WalletBalance walletBalance;
  final bool isCreatingPayout;
  final Future<void> Function(double amount, String currency) onCreatePayout;

  @override
  State<_PayoutSheet> createState() => _PayoutSheetState();
}

class _PayoutSheetState extends State<_PayoutSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.paymentPayout,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
          AppSpacing.vMd,
          // 可用余额
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Column(
              children: [
                Text(
                  l10n.paymentAvailableBalance,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${Helpers.currencySymbolFor(widget.walletBalance.currency)}${widget.walletBalance.balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.vLg,
          // 提现金额
          Text(l10n.paymentPayoutAmount,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              prefixText: '${Helpers.currencySymbolFor(widget.walletBalance.currency)} ',
              hintText: '0.00',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
            onChanged: (_) {},
          ),
          AppSpacing.vMd,
          // 备注
          Text(l10n.paymentNoteOptional,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: l10n.paymentPayoutNote,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
          ),
          AppSpacing.vLg,
          // 提现按钮
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _amountController,
            builder: (context, value, child) {
              final amount = double.tryParse(value.text);
              final canCreate = amount != null &&
                  amount > 0 &&
                  amount <= widget.walletBalance.balance &&
                  !_isProcessing;

              return PrimaryButton(
                text: l10n.paymentConfirmPayout,
                isLoading: _isProcessing,
                onPressed: canCreate
                    ? () async {
                        final amount =
                            double.tryParse(_amountController.text) ?? 0;
                        final navigator = Navigator.of(context);
                        setState(() => _isProcessing = true);
                        await widget.onCreatePayout(
                            amount, widget.walletBalance.currency);
                        if (mounted) {
                          setState(() => _isProcessing = false);
                          navigator.pop();
                        }
                      }
                    : null,
              );
            },
          ),
          AppSpacing.vMd,
        ],
      ),
    );
  }
}

/// 账户详情弹窗（对标 iOS AccountDetailsSheet）
class _AccountDetailsSheet extends StatelessWidget {
  const _AccountDetailsSheet({
    required this.accountDetails,
    required this.externalAccounts,
    required this.scrollController,
  });

  final StripeConnectAccountDetails? accountDetails;
  final List<ExternalAccount> externalAccounts;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // 不画自定义拖拽条：主题 showDragHandle: true 已提供
        // 标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.paymentAccountDetails,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: accountDetails == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // 账户信息
                    _AccountInfoSection(
                        details: accountDetails!, isDark: isDark),
                    AppSpacing.vLg,
                    // 外部账户
                    if (externalAccounts.isNotEmpty) ...[
                      Text(
                        l10n.paymentExternalAccount,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      AppSpacing.vSm,
                      ...externalAccounts.map((account) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _ExternalAccountCard(
                                account: account, isDark: isDark),
                          )),
                    ] else ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Icon(Icons.credit_card,
                                  size: 40,
                                  color: AppColors.textTertiary
                                      .withValues(alpha: 0.5)),
                              AppSpacing.vSm,
                              Text(
                                l10n.paymentNoExternalAccount,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// 账户信息区域（对标 iOS AccountInfoSection）
class _AccountInfoSection extends StatelessWidget {
  const _AccountInfoSection({required this.details, required this.isDark});

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
            label: l10n.paymentDetailsSubmitted,
            value: details.detailsSubmitted ? l10n.paymentYes : l10n.paymentNo,
            valueColor:
                details.detailsSubmitted ? AppColors.success : AppColors.error,
          ),
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
          if (details.dashboardUrl != null && details.dashboardUrl!.isNotEmpty) ...[
            AppSpacing.vMd,
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ExternalWebView.openInApp(
                  context,
                  url: details.dashboardUrl!,
                  title: l10n.stripeConnectOpenDashboard,
                ),
                icon: const Icon(Icons.open_in_browser_outlined, size: 18),
                label: Text(l10n.stripeConnectOpenDashboard),
              ),
            ),
          ],
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

/// 外部账户卡片（对标 iOS ExternalAccountCard）
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
              child: Text(
                context.l10n.commonDefault,
                style: const TextStyle(
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

/// 交易详情弹窗（对标 iOS TransactionDetailSheet）
class _TransactionDetailSheet extends StatelessWidget {
  const _TransactionDetailSheet({
    required this.transaction,
    required this.scrollController,
  });

  final StripeConnectTransaction transaction;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = transaction.isIncome;

    return Column(
      children: [
        // 不画自定义拖拽条：主题 showDragHandle: true 已提供
        // 标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.paymentTransactionDetails,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // 金额卡片
              Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: Column(
                  children: [
                    Text(
                      isIncome
                          ? l10n.paymentIncomeAmount
                          : l10n.paymentPayoutAmountTitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      Helpers.formatPrice(transaction.amount.abs(), currency: transaction.currency),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: isIncome
                            ? AppColors.success
                            : (isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.vLg,
              // 详细信息
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.paymentDetails,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    AppSpacing.vMd,
                    _DetailRow(
                        icon: Icons.tag,
                        label: l10n.paymentTransactionId,
                        value: transaction.id),
                    _DetailRow(
                        icon: Icons.description,
                        label: l10n.paymentDescription,
                        value: transaction.description.isNotEmpty
                            ? transaction.description
                            : '-'),
                    _DetailRow(
                        icon: Icons.access_time,
                        label: l10n.paymentTime,
                        value: _formatDate(transaction.createdAt)),
                    _DetailRow(
                        icon: Icons.check_circle,
                        label: l10n.paymentStatus,
                        value: _getStatusText(context, transaction.status)),
                    _DetailRow(
                        icon: Icons.credit_card,
                        label: l10n.paymentType,
                        value: isIncome
                            ? l10n.paymentIncome
                            : l10n.paymentPayout),
                    _DetailRow(
                        icon: Icons.arrow_forward,
                        label: l10n.paymentSource,
                        value: _getSourceText(context, transaction.source)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getStatusText(BuildContext context, String status) {
    final l10n = context.l10n;
    switch (status.toLowerCase()) {
      case 'paid':
      case 'succeeded':
        return l10n.paymentStatusSuccess;
      case 'pending':
      case 'in_transit':
        return l10n.paymentStatusProcessing;
      case 'canceled':
        return l10n.paymentStatusCanceled;
      case 'failed':
        return l10n.paymentStatusFailed;
      default:
        return status;
    }
  }

  String _getSourceText(BuildContext context, String source) {
    final l10n = context.l10n;
    switch (source) {
      case 'payout':
        return l10n.paymentPayout;
      case 'transfer':
        return 'Transfer';
      case 'charge':
        return l10n.paymentIncome;
      case 'payment_intent':
        return l10n.paymentStatusTaskPayment;
      default:
        return source;
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(date.toLocal());
    } catch (_) {
      return dateStr;
    }
  }
}

/// 详情行
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textTertiary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
