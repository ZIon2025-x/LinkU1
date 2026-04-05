import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:link2ur/core/utils/error_localizer.dart';
import 'package:link2ur/core/utils/l10n_extension.dart';
import 'package:link2ur/data/models/expert_team.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/data/services/storage_service.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';
import 'package:link2ur/features/expert_team/widgets/role_badge.dart';

class ExpertTeamDetailView extends StatelessWidget {
  final String expertId;

  const ExpertTeamDetailView({super.key, required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      )..add(ExpertTeamLoadDetail(expertId)),
      child: _ExpertTeamDetailBody(expertId: expertId),
    );
  }
}

class _ExpertTeamDetailBody extends StatelessWidget {
  final String expertId;

  const _ExpertTeamDetailBody({required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpertTeamBloc, ExpertTeamState>(
      listenWhen: (prev, curr) =>
          curr.actionMessage != prev.actionMessage ||
          curr.errorMessage != prev.errorMessage,
      listener: (context, state) {
        final msg = state.actionMessage ?? state.errorMessage;
        if (msg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(msg))),
          );
        }
      },
      child: BlocBuilder<ExpertTeamBloc, ExpertTeamState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(state.currentTeam?.name ?? context.l10n.expertTeamDetail),
            ),
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, ExpertTeamState state) {
    if (state.status == ExpertTeamStatus.loading && state.currentTeam == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == ExpertTeamStatus.error && state.currentTeam == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.errorMessage ?? '加载失败'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  context.read<ExpertTeamBloc>().add(ExpertTeamLoadDetail(expertId)),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final team = state.currentTeam;
    if (team == null) {
      return const Center(child: Text('未找到团队信息'));
    }
    return _ExpertTeamDetailContent(team: team, expertId: expertId);
  }
}

class _ExpertTeamDetailContent extends StatelessWidget {
  final ExpertTeam team;
  final String expertId;

  const _ExpertTeamDetailContent({required this.team, required this.expertId});

  @override
  Widget build(BuildContext context) {
    final currentUserId = StorageService.instance.getUserId();
    final members = team.members ?? [];
    final currentMember = members.firstWhere(
      (m) => m.userId == currentUserId,
      orElse: () => const ExpertMember(id: -1, userId: '', role: ''),
    );
    final isInTeam = currentMember.id != -1;
    final isOwner = isInTeam && currentMember.isOwner;
    final canManage = isInTeam && currentMember.canManage;
    final previewMembers = members.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, team),
          const SizedBox(height: 16),
          _buildStatsRow(context, team),
          const SizedBox(height: 16),
          if (previewMembers.isNotEmpty) ...[
            _buildMembersSection(context, previewMembers, team),
            const SizedBox(height: 16),
          ],
          _buildActionButtons(context, team, isInTeam, canManage, currentMember),
          // 管理面板（Owner/Admin 可见）
          if (canManage) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text(context.l10n.expertTeamManageMembers,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _ManagementTile(
              icon: Icons.miscellaneous_services,
              title: '服务管理',
              onTap: () => context.push('/expert-teams/$expertId/services'),
            ),
            _ManagementTile(
              icon: Icons.local_offer,
              title: context.l10n.expertTeamCoupons,
              onTap: () => context.push('/expert-teams/$expertId/coupons'),
            ),
            _ManagementTile(
              icon: Icons.forum,
              title: '达人板块',
              onTap: () {
                if (team.forumCategoryId != null) {
                  context.push('/forum/category/${team.forumCategoryId}');
                }
              },
            ),
            if (isOwner) ...[
              _ManagementTile(
                icon: Icons.toggle_on,
                title: team.allowApplications ? context.l10n.expertTeamApplicationsDisabled : context.l10n.expertTeamApplicationsEnabled,
                onTap: () {
                  context.read<ExpertTeamBloc>().add(
                    ExpertTeamToggleAllowApplications(
                      expertId: expertId,
                      allow: !team.allowApplications,
                    ),
                  );
                },
              ),
              _ManagementTile(
                icon: Icons.edit,
                title: '编辑团队信息',
                onTap: () => context.push('/expert-teams/$expertId/edit'),
              ),
              _ManagementTile(
                icon: Icons.delete_forever,
                title: '注销团队',
                color: Colors.red,
                onTap: () => _confirmDissolve(context),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _confirmDissolve(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('注销团队'),
        content: const Text('注销后所有服务将下架，达人板块将隐藏。此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认注销', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ExpertTeamBloc>().add(ExpertTeamDissolve(expertId));
    }
  }

  Widget _buildHeader(BuildContext context, ExpertTeam team) {
    final statusColor = team.status == 'active' ? Colors.green : Colors.grey;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: team.avatar != null ? NetworkImage(team.avatar!) : null,
          child: team.avatar == null
              ? Text(
                  team.name.isNotEmpty ? team.name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 28),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      team.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (team.isOfficial)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '官方',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  team.status == 'active' ? '运营中' : '已停止',
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ),
              if (team.bio != null) ...[
                const SizedBox(height: 8),
                Text(
                  team.bio!,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context, ExpertTeam team) {
    return Row(
      children: [
        _StatItem(label: '成员', value: team.memberCount.toString()),
        _StatItem(label: '服务', value: team.totalServices.toString()),
        _StatItem(label: '完成', value: team.completedTasks.toString()),
        _StatItem(
          label: '评分',
          value: team.rating.toStringAsFixed(1),
        ),
      ],
    );
  }

  Widget _buildMembersSection(
    BuildContext context,
    List<ExpertMember> previewMembers,
    ExpertTeam team,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '成员 (${team.memberCount})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (team.memberCount > 5)
              TextButton(
                onPressed: () => context.push('/expert-teams/$expertId/members'),
                child: const Text('查看全部'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: previewMembers.map((m) => _MemberChip(member: m)).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    ExpertTeam team,
    bool isInTeam,
    bool canManage,
    ExpertMember currentMember,
  ) {
    final bloc = context.read<ExpertTeamBloc>();

    if (canManage) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => context.push('/expert-teams/$expertId/members'),
          child: Text(context.l10n.expertTeamManageMembers),
        ),
      );
    }

    if (isInTeam) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => _confirmLeave(context, bloc),
          child: Text(context.l10n.expertTeamLeave),
        ),
      );
    }

    // Visitor
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () => bloc.add(ExpertTeamToggleFollow(expertId)),
          child: Text(team.isFollowing ? context.l10n.expertTeamUnfollow : context.l10n.expertTeamFollow),
        ),
        if (team.allowApplications) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => bloc.add(ExpertTeamRequestJoin(expertId: expertId)),
            child: Text(context.l10n.expertTeamRequestJoin),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmLeave(BuildContext context, ExpertTeamBloc bloc) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.expertTeamLeave),
        content: Text(l10n.expertTeamConfirmLeave),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.expertTeamLeave, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(ExpertTeamLeave(expertId));
    }
  }
}

class _ManagementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _ManagementTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: color != null ? TextStyle(color: color) : null),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  final ExpertMember member;

  const _MemberChip({required this.member});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage:
              member.userAvatar != null ? NetworkImage(member.userAvatar!) : null,
          child: member.userAvatar == null
              ? Text(
                  (member.userName ?? '?').isNotEmpty
                      ? (member.userName ?? '?')[0].toUpperCase()
                      : '?',
                )
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          member.userName ?? member.userId,
          style: const TextStyle(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        ExpertRoleBadge(role: member.role),
      ],
    );
  }
}

