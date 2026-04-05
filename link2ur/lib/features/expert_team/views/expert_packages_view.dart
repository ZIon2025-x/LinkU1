import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';

class ExpertPackagesView extends StatelessWidget {
  const ExpertPackagesView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      )..add(ExpertTeamLoadMyPackages()),
      child: const _PackagesBody(),
    );
  }
}

class _PackagesBody extends StatelessWidget {
  const _PackagesBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpertTeamBloc, ExpertTeamState>(
      listenWhen: (prev, curr) =>
          curr.actionMessage != null && curr.actionMessage != prev.actionMessage,
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!)),
          );
        }
      },
      builder: (context, state) {
        final packages = state.packages;
        return Scaffold(
          appBar: AppBar(title: const Text('我的套餐')),
          body: packages.isEmpty
              ? const Center(child: Text('暂无套餐'))
              : ListView.builder(
                  itemCount: packages.length,
                  itemBuilder: (context, index) {
                    final p = packages[index];
                    final remaining = (p['remaining_sessions'] ?? 0) as int;
                    final total = (p['total_sessions'] ?? 0) as int;
                    final status = p['status'] as String? ?? '';
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('套餐 #${p['id']}',
                                    style: Theme.of(context).textTheme.titleMedium),
                                _StatusChip(status: status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: total > 0 ? (total - remaining) / total : 0,
                            ),
                            const SizedBox(height: 4),
                            Text('剩余 $remaining / $total 次'),
                            if (p['expires_at'] != null) ...[
                              const SizedBox(height: 4),
                              Text('到期: ${(p['expires_at'] as String).substring(0, 10)}',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = Colors.green;
        label = '使用中';
        break;
      case 'exhausted':
        color = Colors.orange;
        label = '已用完';
        break;
      case 'expired':
        color = Colors.red;
        label = '已过期';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
