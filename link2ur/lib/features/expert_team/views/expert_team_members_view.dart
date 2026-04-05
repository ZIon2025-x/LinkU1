import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:link2ur/data/models/expert_team.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/data/services/storage_service.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';

class ExpertTeamMembersView extends StatelessWidget {
  final String expertId;

  const ExpertTeamMembersView({super.key, required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      )..add(ExpertTeamLoadMembers(expertId)),
      child: _ExpertTeamMembersBody(expertId: expertId),
    );
  }
}

class _ExpertTeamMembersBody extends StatelessWidget {
  final String expertId;

  const _ExpertTeamMembersBody({required this.expertId});

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
            SnackBar(content: Text(msg)),
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
              title: const Text('成员管理'),
              actions: [
                if (canManage)
                  IconButton(
                    icon: const Icon(Icons.assignment_ind_outlined),
                    tooltip: '加入申请',
                    onPressed: () =>
                        context.push('/expert-teams/$expertId/join-requests'),
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
      return const Center(child: Text('暂无成员'));
    }

    return ListView.builder(
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
    );
  }

  Future<void> _showInviteDialog(BuildContext context) async {
    final controller = TextEditingController();
    final bloc = context.read<ExpertTeamBloc>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('邀请成员'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '用户 ID',
            hintText: '请输入要邀请的用户 ID',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final inviteeId = controller.text.trim();
              if (inviteeId.isNotEmpty) {
                bloc.add(ExpertTeamInviteMember(
                  expertId: expertId,
                  inviteeId: inviteeId,
                ));
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('发送邀请'),
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
          _RoleBadge(role: member.role),
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
            child: Text(member.isAdmin ? '设为成员' : '设为管理员'),
          ),
        // 只有 Owner 可以移除成员
        if (isOwner)
          const PopupMenuItem(
            value: 'remove',
            child: Text('移除成员', style: TextStyle(color: Colors.red)),
          ),
        // 只有 Owner 可以转让
        if (isOwner)
          const PopupMenuItem(
            value: 'transfer',
            child: Text('转让所有权', style: TextStyle(color: Colors.orange)),
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
            title: const Text('移除成员'),
            content: Text('确认移除 ${member.userName ?? member.userId}？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('确认移除',
                    style: TextStyle(color: Colors.red)),
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
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('转让所有权'),
            content: Text(
                '确认将所有权转让给 ${member.userName ?? member.userId}？转让后您将成为普通成员。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('确认转让',
                    style: TextStyle(color: Colors.orange)),
              ),
            ],
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

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (role) {
      case 'owner':
        bgColor = Colors.blue;
        textColor = Colors.white;
        label = '所有者';
        break;
      case 'admin':
        bgColor = Colors.orange;
        textColor = Colors.white;
        label = '管理员';
        break;
      default:
        bgColor = Colors.grey.shade200;
        textColor = Colors.black87;
        label = '成员';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 12),
      ),
    );
  }
}
