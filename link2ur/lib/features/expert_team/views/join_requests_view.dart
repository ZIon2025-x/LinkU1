import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:link2ur/core/utils/error_localizer.dart';
import 'package:link2ur/core/utils/l10n_extension.dart';
import 'package:link2ur/data/models/expert_team.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';

class JoinRequestsView extends StatelessWidget {
  final String expertId;

  const JoinRequestsView({super.key, required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      )..add(ExpertTeamLoadJoinRequests(expertId)),
      child: _JoinRequestsPage(expertId: expertId),
    );
  }
}

class _JoinRequestsPage extends StatelessWidget {
  final String expertId;

  const _JoinRequestsPage({required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpertTeamBloc, ExpertTeamState>(
      listenWhen: (prev, curr) => curr.actionMessage != null && curr.actionMessage != prev.actionMessage,
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(state.actionMessage!))),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.expertTeamJoinRequests),
        ),
        body: BlocBuilder<ExpertTeamBloc, ExpertTeamState>(
          builder: (context, state) {
            if (state.status == ExpertTeamStatus.loading && state.joinRequests.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.joinRequests.isEmpty) {
              return Center(
                child: Text(
                  context.l10n.expertTeamNoJoinRequests,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: state.joinRequests.length,
              itemBuilder: (context, index) {
                final req = state.joinRequests[index];
                return _JoinRequestCard(
                  request: req,
                  expertId: expertId,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _JoinRequestCard extends StatelessWidget {
  final ExpertJoinRequest request;
  final String expertId;

  const _JoinRequestCard({required this.request, required this.expertId});

  @override
  Widget build(BuildContext context) {
    final isPending = request.status == 'pending';

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
                  backgroundImage: request.userAvatar != null
                      ? NetworkImage(request.userAvatar!)
                      : null,
                  child: request.userAvatar == null
                      ? Text(
                          (request.userName?.isNotEmpty == true)
                              ? request.userName![0].toUpperCase()
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
                        request.userName ?? '未知用户',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        request.createdAt != null
                            ? request.createdAt!.toString().substring(0, 16)
                            : '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (!isPending)
                  _StatusBadge(status: request.status),
              ],
            ),
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                request.message!,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ],
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
                            ExpertTeamReviewJoinRequest(
                              expertId: expertId,
                              requestId: request.id,
                              action: 'reject',
                            ),
                          );
                    },
                    child: Text(context.l10n.expertTeamReject),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      context.read<ExpertTeamBloc>().add(
                            ExpertTeamReviewJoinRequest(
                              expertId: expertId,
                              requestId: request.id,
                              action: 'approve',
                            ),
                          );
                    },
                    child: Text(context.l10n.expertTeamApprove),
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

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'approved':
        color = Colors.green;
        label = '已批准';
        break;
      case 'rejected':
        color = Colors.red;
        label = '已拒绝';
        break;
      default:
        color = Colors.amber;
        label = '待审核';
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
