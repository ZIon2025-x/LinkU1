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

class MembersView extends StatelessWidget {
  final String expertId;

  const MembersView({super.key, required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      )
        ..add(ExpertTeamLoadMembers(expertId))
        ..add(ExpertTeamLoadDetail(expertId)),
      child: _MembersBody(expertId: expertId),
    );
  }
}

class _MembersBody extends StatelessWidget {
  final String expertId;

  const _MembersBody({required this.expertId});

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
          final currentUserId = StorageService.instance.getUserId();
          final members = state.members;
          final currentMember = members.firstWhere(
            (m) => m.userId == currentUserId,
            orElse: () => const ExpertMember(id: -1, userId: '', role: ''),
          );
          final canManage = currentMember.id != -1 && currentMember.canManage;
          final isOwner = currentMember.id != -1 && currentMember.isOwner;

          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.expertTeamMembers),
              actions: [
                if (canManage)
                  IconButton(
                    icon: const Icon(Icons.assignment_ind_outlined),
                    tooltip: context.l10n.expertTeamJoinRequests,
                    onPressed: () => context.push(
                        '/expert-dashboard/$expertId/management/join-requests'),
                  ),
              ],
            ),
            body: _buildBody(context, state, members, canManage, isOwner),
            floatingActionButton: canManage
                ? FloatingActionButton(
                    onPressed: () => _showInviteDialog(context),
                    child: const Icon(Icons.person_add),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ExpertTeamState state,
    List<ExpertMember> members,
    bool canManage,
    bool isOwner,
  ) {
    if (state.status == ExpertTeamStatus.loading && members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (members.isEmpty) {
      return Center(child: Text(context.l10n.expertTeamNoMembers));
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<ExpertTeamBloc>().add(ExpertTeamLoadMembers(expertId));
      },
      child: ListView.builder(
        itemCount: members.length,
        itemBuilder: (context, index) {
          final member = members[index];
          return _MemberListItem(
            member: member,
            expertId: expertId,
            canManage: canManage,
            isOwner: isOwner,
          );
        },
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final bloc = context.read<ExpertTeamBloc>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.expertTeamInviteMember),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.expertTeamInviteUserIdLabel,
            hintText: l10n.expertTeamInviteUserIdHint,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              final inviteeId = controller.text.trim();
              // 客户端校验: 非空且长度合理 (后端 user_id 通常 8-32 字符)
              if (inviteeId.isEmpty || inviteeId.length < 4 || inviteeId.length > 64) {
                return;
              }
              bloc.add(ExpertTeamInviteMember(
                expertId: expertId,
                inviteeId: inviteeId,
              ));
              Navigator.of(ctx).pop();
            },
            child: Text(l10n.expertTeamSendInvite),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _MemberListItem extends StatelessWidget {
  final ExpertMember member;
  final String expertId;
  final bool canManage;
  final bool isOwner;

  const _MemberListItem({
    required this.member,
    required this.expertId,
    required this.canManage,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    // Admin 可以看到非 owner 的菜单；只有 Owner 能看到转让/角色变更
    final showMenu = canManage && !member.isOwner;

    return ListTile(
      leading: CircleAvatar(
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
      title: Text(member.userName ?? member.userId),
      subtitle: Text(member.userId),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExpertRoleBadge(role: member.role),
          if (showMenu) _MemberMenuButton(member: member, expertId: expertId, isOwner: isOwner),
        ],
      ),
    );
  }
}

class _MemberMenuButton extends StatelessWidget {
  final ExpertMember member;
  final String expertId;
  final bool isOwner;

  const _MemberMenuButton({required this.member, required this.expertId, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ExpertTeamBloc>();

    return PopupMenuButton<String>(
      onSelected: (action) => _handleAction(context, action, bloc),
      itemBuilder: (context) => [
        // 只有 Owner 可以修改角色
        if (isOwner)
          PopupMenuItem(
            value: 'toggle_role',
            child: Text(member.isAdmin ? context.l10n.expertTeamSetMember : context.l10n.expertTeamSetAdmin),
          ),
        // 只有 Owner 可以移除成员
        if (isOwner)
          PopupMenuItem(
            value: 'remove',
            child: Text(context.l10n.expertTeamRemoveMember, style: const TextStyle(color: Colors.red)),
          ),
        // 只有 Owner 可以转让
        if (isOwner)
          PopupMenuItem(
            value: 'transfer',
            child: Text(context.l10n.expertTeamTransferOwnership, style: const TextStyle(color: Colors.orange)),
          ),
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    String action,
    ExpertTeamBloc bloc,
  ) async {
    switch (action) {
      case 'toggle_role':
        final newRole = member.isAdmin ? 'member' : 'admin';
        bloc.add(ExpertTeamChangeMemberRole(
          expertId: expertId,
          userId: member.userId,
          role: newRole,
        ));
        break;
      case 'remove':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.expertTeamRemoveMember),
            content: Text(context.l10n.expertTeamConfirmRemove),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(context.l10n.expertTeamRemoveMember,
                    style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          bloc.add(ExpertTeamRemoveMember(
            expertId: expertId,
            userId: member.userId,
          ));
        }
        break;
      case 'transfer':
        final teamName = bloc.state.currentTeam?.name ?? '';
        final newOwnerName = member.userName ?? member.userId;
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _TransferOwnershipDialog(
            teamName: teamName,
            newOwnerName: newOwnerName,
          ),
        );
        if (confirmed == true) {
          bloc.add(ExpertTeamTransferOwnership(
            expertId: expertId,
            newOwnerId: member.userId,
          ));
        }
        break;
    }
  }
}

/// 转让所有权强化确认对话框：要求输入团队名 + 列出影响。
class _TransferOwnershipDialog extends StatefulWidget {
  const _TransferOwnershipDialog({
    required this.teamName,
    required this.newOwnerName,
  });

  final String teamName;
  final String newOwnerName;

  @override
  State<_TransferOwnershipDialog> createState() =>
      _TransferOwnershipDialogState();
}

class _TransferOwnershipDialogState extends State<_TransferOwnershipDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final newMatch = _controller.text.trim() == widget.teamName;
    if (newMatch != _matches) {
      setState(() => _matches = newMatch);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.expertTeamTransferOwnership),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.expertTransferConfirmIntro(widget.newOwnerName)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.expertTransferImpactTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text('• ${l10n.expertTransferImpact1}'),
                  Text('• ${l10n.expertTransferImpact2}'),
                  Text('• ${l10n.expertTransferImpact3}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.expertTransferTypeNameToConfirm(widget.teamName)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.teamName,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: Text(l10n.expertTransferConfirmButton),
        ),
      ],
    );
  }
}
