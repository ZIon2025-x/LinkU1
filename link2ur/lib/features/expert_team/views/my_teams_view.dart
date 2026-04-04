import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:link2ur/data/models/expert_team.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';

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
        title: const Text('我的团队'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/expert-teams/create'),
        tooltip: '创建团队',
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
                    const Text(
                      '你还没有加入任何团队',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.push('/expert-teams/create'),
                      child: const Text('创建团队'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
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

    // Find the current user's role in this team
    final myMember = team.members?.isNotEmpty == true ? team.members!.first : null;
    final role = myMember?.role;

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
                          _RoleBadge(role: role),
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

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final String label;

    switch (role) {
      case 'owner':
        bgColor = Theme.of(context).colorScheme.primary;
        label = '创始人';
      case 'admin':
        bgColor = Colors.orange;
        label = '管理员';
      default:
        bgColor = Colors.grey;
        label = '成员';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
