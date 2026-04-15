import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:link2ur/core/utils/error_localizer.dart';
import 'package:link2ur/core/utils/l10n_extension.dart';
import 'package:link2ur/data/models/expert_team.dart';
import 'package:link2ur/core/utils/helpers.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';

class MyInvitationsView extends StatelessWidget {
  const MyInvitationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      )..add(ExpertTeamLoadMyInvitations()),
      child: const _MyInvitationsPage(),
    );
  }
}

class _MyInvitationsPage extends StatelessWidget {
  const _MyInvitationsPage();

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpertTeamBloc, ExpertTeamState>(
      listenWhen: (prev, curr) =>
          curr.actionMessage != null && curr.actionMessage != prev.actionMessage,
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(state.actionMessage!))),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.expertTeamInvitations)),
        body: BlocBuilder<ExpertTeamBloc, ExpertTeamState>(
          builder: (context, state) {
            final invitations = state.myInvitations;

            if (invitations.isEmpty) {
              return Center(
                child: Text(context.l10n.expertTeamNoInvitations,
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<ExpertTeamBloc>().add(ExpertTeamLoadMyInvitations());
              },
              child: ListView.builder(
                itemCount: invitations.length,
                itemBuilder: (context, index) {
                  final inv = invitations[index];
                  return _InvitationCard(invitation: inv);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final ExpertInvitation invitation;

  const _InvitationCard({required this.invitation});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: invitation.expertAvatar != null
                      ? NetworkImage(Helpers.getImageUrl(invitation.expertAvatar!))
                      : null,
                  child: invitation.expertAvatar == null
                      ? const Icon(Icons.group)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.expertName ?? '未知团队',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (invitation.createdAt != null)
                        Text(
                          invitation.createdAt!.toString().substring(0, 16),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (invitation.isPending) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      context.read<ExpertTeamBloc>().add(
                            ExpertTeamRespondInvitation(
                              invitationId: invitation.id,
                              action: 'reject',
                            ),
                          );
                    },
                    child: Text(context.l10n.expertTeamReject),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ExpertTeamBloc>().add(
                            ExpertTeamRespondInvitation(
                              invitationId: invitation.id,
                              action: 'accept',
                            ),
                          );
                    },
                    child: Text(context.l10n.expertTeamAccept),
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
