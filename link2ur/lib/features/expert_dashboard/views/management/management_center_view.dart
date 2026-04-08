import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_spacing.dart';
import '../../../../core/utils/error_localizer.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../data/models/expert_team.dart';
import '../../../../data/repositories/expert_team_repository.dart';
import '../../../../data/services/storage_service.dart';
import '../../../../features/expert_team/bloc/expert_team_bloc.dart';

/// 管理中心主页
/// 通过 ExpertTeamBloc 加载团队详情，并把 allowApplications 等状态变更
/// 走同一条 BLoC 流，避免和 detail view 出现状态分裂。
class ManagementCenterView extends StatelessWidget {
  const ManagementCenterView({super.key, required this.expertId});
  final String expertId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ExpertTeamBloc>(
      create: (ctx) => ExpertTeamBloc(
        repository: ctx.read<ExpertTeamRepository>(),
      )..add(ExpertTeamLoadDetail(expertId)),
      child: _ManagementCenterContent(expertId: expertId),
    );
  }
}

class _ManagementCenterContent extends StatelessWidget {
  const _ManagementCenterContent({required this.expertId});
  final String expertId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpertTeamBloc, ExpertTeamState>(
      listenWhen: (prev, curr) =>
          prev.actionMessage != curr.actionMessage ||
          prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
          messenger.showSnackBar(
            SnackBar(content: Text(context.localizeError(state.errorMessage!))),
          );
        } else if (state.actionMessage != null &&
            state.actionMessage!.isNotEmpty) {
          messenger.showSnackBar(
            SnackBar(content: Text(context.localizeError(state.actionMessage!))),
          );
        }
      },
      builder: (context, state) {
        final team = state.currentTeam;

        if (state.status == ExpertTeamStatus.loading && team == null) {
          return Scaffold(
            appBar:
                AppBar(title: Text(context.l10n.expertDashboardManagement)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (team == null) {
          return Scaffold(
            appBar:
                AppBar(title: Text(context.l10n.expertDashboardManagement)),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(context
                      .localizeError(state.errorMessage ?? 'load_failed')),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context
                        .read<ExpertTeamBloc>()
                        .add(ExpertTeamLoadDetail(expertId)),
                    child: Text(context.l10n.commonRetry),
                  ),
                ],
              ),
            ),
          );
        }

        return _ManagementCenterScaffold(team: team, expertId: expertId);
      },
    );
  }
}

class _ManagementCenterScaffold extends StatelessWidget {
  const _ManagementCenterScaffold({required this.team, required this.expertId});
  final ExpertTeam team;
  final String expertId;

  @override
  Widget build(BuildContext context) {
    final role = team.myRole ?? 'member';
    final isOwner = role == 'owner';
    final canManage = isOwner || role == 'admin';

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.expertDashboardManagement)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          // ========== TEAM SECTION ==========
          _SectionHeader(title: context.l10n.expertManagementSectionTeam),
          _MenuCard(children: [
            _MenuTile(
              icon: Icons.people_outline,
              label: context.l10n.expertTeamMembers,
              onTap: () =>
                  context.push('/expert-dashboard/$expertId/management/members'),
            ),
            if (canManage)
              _MenuTile(
                icon: Icons.mail_outline,
                label: context.l10n.expertTeamJoinRequests,
                onTap: () => context
                    .push('/expert-dashboard/$expertId/management/join-requests'),
              ),
            if (isOwner)
              _AllowApplicationsSwitchTile(
                value: team.allowApplications,
                onChanged: (newValue) => context.read<ExpertTeamBloc>().add(
                      ExpertTeamToggleAllowApplications(
                        expertId: expertId,
                        allow: newValue,
                      ),
                    ),
              ),
            if (isOwner)
              _MenuTile(
                icon: Icons.edit_outlined,
                label: context.l10n.expertDashboardEditTeamProfile,
                onTap: () => context
                    .push('/expert-dashboard/$expertId/management/edit-profile'),
              ),
          ]),

          // ========== MARKETING SECTION (canManage only) ==========
          if (canManage) ...[
            const SizedBox(height: AppSpacing.md),
            _SectionHeader(
                title: context.l10n.expertManagementSectionMarketing),
            _MenuCard(children: [
              _MenuTile(
                icon: Icons.local_activity_outlined,
                label: context.l10n.expertTeamCoupons,
                onTap: () => context
                    .push('/expert-dashboard/$expertId/management/coupons'),
              ),
              _MenuTile(
                icon: Icons.inventory_2_outlined,
                label: context.l10n.expertManagementPackages,
                onTap: () => context
                    .push('/expert-dashboard/$expertId/management/packages'),
              ),
              _MenuTile(
                icon: Icons.reviews_outlined,
                label: context.l10n.expertManagementReviewReplies,
                onTap: () => context.push(
                    '/expert-dashboard/$expertId/management/review-replies'),
              ),
              _MenuTile(
                icon: Icons.qr_code_scanner_outlined,
                label: '套餐核销 / 我的客户',
                onTap: () => context.push(
                    '/expert-dashboard/$expertId/management/customer-packages'),
              ),
            ]),
          ],

          // ========== FINANCE SECTION (owner only) ==========
          if (isOwner) ...[
            const SizedBox(height: AppSpacing.md),
            _SectionHeader(
                title: context.l10n.expertManagementSectionFinance),
            _MenuCard(children: [
              _MenuTile(
                icon: Icons.credit_card,
                label: 'Stripe Connect',
                onTap: () => _handleStripeConnect(context, expertId),
              ),
            ]),
          ],

          // ========== OTHER SECTION ==========
          const SizedBox(height: AppSpacing.md),
          _SectionHeader(title: context.l10n.expertManagementSectionOther),
          _MenuCard(children: [
            _MenuTile(
              icon: Icons.public,
              label: context.l10n.expertManagementViewPublicPage,
              onTap: () => context.push('/expert-teams/$expertId'),
            ),
            if (!isOwner)
              _MenuTile(
                icon: Icons.exit_to_app,
                label: context.l10n.expertManagementLeaveTeam,
                color: Colors.red,
                onTap: () => _confirmLeave(context, expertId),
              ),
          ]),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context, String expertId) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final repo = context.read<ExpertTeamRepository>();
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.expertManagementLeaveTeam),
        content: Text(l10n.expertManagementLeaveConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.expertManagementLeaveTeam,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await repo.leaveTeam(expertId);
      await StorageService.instance.clearSelectedExpertId();
      router.go('/expert-dashboard');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _handleStripeConnect(
      BuildContext context, String expertId) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final l10n = context.l10n;
    try {
      final status = await context
          .read<ExpertTeamRepository>()
          .getStripeConnectStatus(expertId);
      final isActive = status['onboarding_complete'] == true;

      if (!context.mounted) return;
      final goToOnboarding = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stripe Connect'),
          content: Text(isActive
              ? l10n.expertStripeAlreadyActive
              : l10n.expertStripeNotActive),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(isActive
                  ? l10n.expertStripeViewDashboard
                  : l10n.expertStripeStartOnboarding),
            ),
          ],
        ),
      );

      if (goToOnboarding == true) {
        router.push('/payment/stripe-connect/onboarding');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _AllowApplicationsSwitchTile extends StatelessWidget {
  const _AllowApplicationsSwitchTile({
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    // 注意：用 secondary 而不是 leading —— SwitchListTile 没有 leading 参数。
    // 为了和 _MenuTile 的 leading icon 对齐，把开关本体放在 trailing 位置，
    // 用 ListTile 自己组装而不是 SwitchListTile，确保左侧 icon 距离一致 (16dp)。
    return ListTile(
      leading: Icon(
        value ? Icons.lock_open_outlined : Icons.lock_outlined,
      ),
      title: Text(context.l10n.expertManagementAllowApplications),
      subtitle: Text(
        value
            ? context.l10n.expertManagementAllowApplicationsOn
            : context.l10n.expertManagementAllowApplicationsOff,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
      onTap: onChanged == null ? null : () => onChanged!(!value),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: color != null ? TextStyle(color: color) : null),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
