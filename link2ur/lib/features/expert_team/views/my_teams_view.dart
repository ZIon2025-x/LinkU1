import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:link2ur/core/utils/l10n_extension.dart';
import 'package:link2ur/data/models/expert_team.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';
import 'package:link2ur/core/widgets/expert_status_badge.dart';
import 'package:link2ur/features/expert_team/widgets/role_badge.dart';

/// 我的团队页
class MyTeamsView extends StatelessWidget {
  const MyTeamsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ExpertTeamBloc>(
      create: (context) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      )..add(ExpertTeamLoadMyTeams()),
      child: const _MyTeamsContent(),
    );
  }
}

class _MyTeamsContent extends StatelessWidget {
  const _MyTeamsContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.expertTeamMyTeams),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/expert-teams/create'),
        tooltip: context.l10n.expertTeamCreateTeam,
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<ExpertTeamBloc, ExpertTeamState>(
        builder: (context, state) {
          if (state.status == ExpertTeamStatus.loading ||
              state.status == ExpertTeamStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == ExpertTeamStatus.error) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.errorMessage ?? '加载失败',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          context.read<ExpertTeamBloc>().add(ExpertTeamLoadMyTeams()),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }

          final teams = state.myTeams;

          if (teams.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.expertTeamNoTeams,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.push('/expert-teams/create'),
                      child: Text(context.l10n.expertTeamCreateTeam),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ExpertTeamBloc>().add(ExpertTeamLoadMyTeams());
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index];
                return _TeamCard(
                  key: ValueKey(team.id),
                  team: team,
                  onTap: () => context.push('/expert-teams/${team.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    super.key,
    required this.team,
    required this.onTap,
  });

  final ExpertTeam team;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // 使用后端返回的 my_role 字段
    final role = team.myRole;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundImage:
                    team.avatar != null ? NetworkImage(team.avatar!) : null,
                backgroundColor: colorScheme.surfaceContainerHighest,
                child: team.avatar == null
                    ? const Icon(Icons.group, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            team.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (role != null) ...[
                          const SizedBox(width: 8),
                          ExpertRoleBadge(role: role),
                        ],
                        if (team.isOpen != null) ...[
                          const SizedBox(width: 6),
                          ExpertStatusBadge(isOpen: team.isOpen),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${team.memberCount} 位成员',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.star_outline, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          team.rating.toStringAsFixed(1),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

