import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/utils/error_localizer.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/external_web_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../data/repositories/expert_team_repository.dart';

/// 达人团队 Stripe Connect 设置页
///
/// 与用户级 [StripeConnectOnboardingView] 区分:
/// - 此页操作 [Expert].stripe_account_id (团队收款账户)
/// - 用户级页面操作 [User].stripe_account_id (个人收款账户)
///
/// 后端走 [ExpertTeamRepository.getStripeConnectStatus] /
/// [ExpertTeamRepository.createStripeConnect],redirect 模式 (非嵌入式)。
class ExpertTeamStripeConnectView extends StatefulWidget {
  const ExpertTeamStripeConnectView({super.key, required this.expertId});

  final String expertId;

  @override
  State<ExpertTeamStripeConnectView> createState() =>
      _ExpertTeamStripeConnectViewState();
}

enum _ViewState { loading, noAccount, incomplete, complete, error }

class _ExpertTeamStripeConnectViewState
    extends State<ExpertTeamStripeConnectView> {
  late final ExpertTeamRepository _repo;

  _ViewState _state = _ViewState.loading;
  String? _error;
  String? _teamName;
  String? _accountId;
  String? _country;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repo = context.read<ExpertTeamRepository>();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _state = _ViewState.loading;
      _error = null;
    });
    try {
      // 并行拿团队名和 Stripe 状态;团队名失败不影响主流程。
      final results = await Future.wait([
        _repo.getStripeConnectStatus(widget.expertId),
        _repo.getExpertById(widget.expertId).then<String?>((t) => t.name).catchError((_) => null),
      ]);
      if (!mounted) return;
      final status = results[0] as Map<String, dynamic>;
      final name = results[1] as String?;
      _applyStatus(status, name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ViewState.error;
        _error = context.localizeError(e.toString());
      });
    }
  }

  void _applyStatus(Map<String, dynamic> status, String? teamName) {
    final hasAccount = status['has_account'] == true;
    final detailsSubmitted = status['details_submitted'] == true;
    setState(() {
      _teamName = teamName;
      _accountId = status['account_id'] as String?;
      _country = status['country'] as String?;
      if (!hasAccount) {
        _state = _ViewState.noAccount;
      } else if (!detailsSubmitted) {
        _state = _ViewState.incomplete;
      } else {
        _state = _ViewState.complete;
      }
    });
  }

  Future<void> _startOrResumeOnboarding() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await _repo.createStripeConnect(widget.expertId);
      if (!mounted) return;
      final url = result['onboarding_url'] as String?;
      if (url != null && url.isNotEmpty) {
        await ExternalWebView.open(url);
        if (!mounted) return;
        // 用户从浏览器回来后让他自己点刷新,避免误判已完成。
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.stripeConnectWebOnboardingHint),
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        // 后端没给 onboarding_url,可能账户已是完成状态,刷新看看。
        await _loadAll();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.localizeError(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.paymentStripeConnect),
        actions: [
          if (_state != _ViewState.loading)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: context.l10n.paymentRefreshAccountInfo,
              onPressed: _busy ? null : _loadAll,
            ),
        ],
      ),
      body: switch (_state) {
        _ViewState.loading => const Center(child: LoadingView()),
        _ViewState.error => _buildError(),
        _ViewState.noAccount => _buildPrompt(
            iconData: Icons.add_card,
            iconColor: AppColors.primary,
            title: context.l10n.expertStripeNotActive,
            actionLabel: context.l10n.expertStripeStartOnboarding,
          ),
        _ViewState.incomplete => _buildPrompt(
            iconData: Icons.hourglass_bottom,
            iconColor: AppColors.warning,
            title: context.l10n.expertStripeNotActive,
            actionLabel: context.l10n.expertStripeStartOnboarding,
          ),
        _ViewState.complete => _buildComplete(),
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            AppSpacing.vMd,
            Text(
              _error ?? context.l10n.stripeConnectLoadFailed,
              textAlign: TextAlign.center,
            ),
            AppSpacing.vLg,
            PrimaryButton(
              text: context.l10n.commonRetry,
              onPressed: _loadAll,
              width: 200,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrompt({
    required IconData iconData,
    required Color iconColor,
    required String title,
    required String actionLabel,
  }) {
    return Padding(
      padding: AppSpacing.allLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSpacing.vXl,
          Icon(iconData, size: 56, color: iconColor),
          AppSpacing.vMd,
          if (_teamName != null && _teamName!.isNotEmpty)
            _TeamBanner(teamName: _teamName!),
          AppSpacing.vMd,
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          const Spacer(),
          PrimaryButton(
            text: actionLabel,
            onPressed: _busy ? null : _startOrResumeOnboarding,
            isLoading: _busy,
          ),
          AppSpacing.vLg,
        ],
      ),
    );
  }

  Widget _buildComplete() {
    return Padding(
      padding: AppSpacing.allLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSpacing.vXl,
          const Icon(Icons.check_circle, size: 56, color: AppColors.success),
          AppSpacing.vMd,
          if (_teamName != null && _teamName!.isNotEmpty)
            _TeamBanner(teamName: _teamName!),
          AppSpacing.vMd,
          Text(
            context.l10n.expertStripeAlreadyActive,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          AppSpacing.vLg,
          if (_accountId != null) _AccountSummary(accountId: _accountId!, country: _country),
        ],
      ),
    );
  }
}

class _TeamBanner extends StatelessWidget {
  const _TeamBanner({required this.teamName});

  final String teamName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_2, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              teamName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  const _AccountSummary({required this.accountId, this.country});

  final String accountId;
  final String? country;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context, context.l10n.paymentAccountId, accountId),
          if (country != null && country!.isNotEmpty)
            _row(context, context.l10n.paymentCountry, country!),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
