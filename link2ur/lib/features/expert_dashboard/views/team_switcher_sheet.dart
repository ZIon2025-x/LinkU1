import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/expert_team.dart';
import '../bloc/selected_expert_cubit.dart';

class TeamSwitcherSheet extends StatelessWidget {
  const TeamSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: context.read<SelectedExpertCubit>(),
        child: const TeamSwitcherSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SelectedExpertCubit, SelectedExpertState>(
      builder: (context, state) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    context.l10n.expertDashboardSwitchTeam,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...state.myTeams.map((team) => _TeamTile(
                      team: team,
                      isSelected: team.id == state.currentExpertId,
                    )),
                const Divider(height: 24),
                _ActionTile(
                  icon: Icons.add_circle_outline,
                  iconColor: AppColors.primary,
                  label: context.l10n.expertDashboardApplyNewTeam,
                  onTap: () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push(AppRoutes.expertTeamCreate);
                  },
                ),
                _ActionTile(
                  icon: Icons.mail_outline,
                  label: context.l10n.expertDashboardMyInvitations,
                  onTap: () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push(AppRoutes.expertTeamInvitations);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({required this.team, required this.isSelected});
  final ExpertTeam team;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final cubit = context.read<SelectedExpertCubit>();
        final navigator = Navigator.of(context);
        await cubit.switchTo(team.id);
        navigator.pop();
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage:
                  team.avatar != null ? NetworkImage(team.avatar!) : null,
              child: team.avatar == null
                  ? Text(team.name.isNotEmpty ? team.name.characters.first : '?')
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(team.name,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    '${(team.myRole ?? 'member').toUpperCase()} · ${team.totalServices} ${context.l10n.expertDashboardServiceCount}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      dense: true,
    );
  }
}
