import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:link2ur/data/models/expert_team.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';

class MyInvitationsView extends StatelessWidget {
  const MyInvitationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      ),
      // TODO: implement when backend adds GET /api/experts/my-invitations endpoint
      child: const _MyInvitationsPage(),
    );
  }
}

class _MyInvitationsPage extends StatelessWidget {
  const _MyInvitationsPage();

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpertTeamBloc, ExpertTeamState>(
      listenWhen: (prev, curr) => curr.actionMessage != null && curr.actionMessage != prev.actionMessage,
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('团队邀请'),
        ),
        // TODO: replace with real invitations list once
        // GET /api/experts/my-invitations endpoint is available
        body: const Center(
          child: Text(
            '暂无收到的邀请',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

/// Builds a single invitation card.
/// Used by [_MyInvitationsPage] when the backend endpoint is available.
// ignore: unused_element
class _InvitationCard extends StatelessWidget {
  final ExpertInvitation invitation;

  const _InvitationCard({required this.invitation});

  @override
  Widget build(BuildContext context) {
    final isPending = invitation.isPending;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: invitation.expertAvatar != null
                      ? NetworkImage(invitation.expertAvatar!)
                      : null,
                  child: invitation.expertAvatar == null
                      ? Text(
                          (invitation.expertName?.isNotEmpty == true)
                              ? invitation.expertName![0].toUpperCase()
                              : '?',
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.expertName ?? '未知团队',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '邀请人：${invitation.inviterId}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        invitation.createdAt != null
                            ? invitation.createdAt!.toString().substring(0, 16)
                            : '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (!isPending)
                  _InvitationStatusBadge(status: invitation.status),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () {
                      context.read<ExpertTeamBloc>().add(
                            ExpertTeamRespondInvitation(
                              invitationId: invitation.id,
                              action: 'reject',
                            ),
                          );
                    },
                    child: const Text('拒绝'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      context.read<ExpertTeamBloc>().add(
                            ExpertTeamRespondInvitation(
                              invitationId: invitation.id,
                              action: 'accept',
                            ),
                          );
                    },
                    child: const Text('接受'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InvitationStatusBadge extends StatelessWidget {
  final String status;

  const _InvitationStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'accepted':
        color = Colors.green;
        label = '已接受';
        break;
      case 'rejected':
        color = Colors.red;
        label = '已拒绝';
        break;
      default:
        color = Colors.amber;
        label = '待响应';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
