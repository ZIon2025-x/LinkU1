import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:link2ur/core/utils/error_localizer.dart';
import 'package:link2ur/core/utils/l10n_extension.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';

class GroupBuyView extends StatelessWidget {
  final int activityId;
  const GroupBuyView({super.key, required this.activityId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      ),
      child: _GroupBuyBody(activityId: activityId),
    );
  }
}

class _GroupBuyBody extends StatefulWidget {
  final int activityId;
  const _GroupBuyBody({required this.activityId});

  @override
  State<_GroupBuyBody> createState() => _GroupBuyBodyState();
}

class _GroupBuyBodyState extends State<_GroupBuyBody> {
  Map<String, dynamic>? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final repo = context.read<ExpertTeamRepository>();
      final status = await repo.getGroupBuyStatus(widget.activityId);
      if (mounted) setState(() { _status = status; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

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
          _loadStatus(); // Refresh after action
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(context.l10n.expertTeamGroupBuy)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _status == null
                ? const Center(child: Text('无法加载拼单信息'))
                : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final current = _status!['current_count'] as int? ?? 0;
    final min = _status!['min_required'] as int? ?? 1;
    final userJoined = _status!['user_joined'] as bool? ?? false;
    final deadline = _status!['deadline'] as String?;
    final round = _status!['round'] as int? ?? 1;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          // Progress circle
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: min > 0 ? current / min : 0,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade200,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$current / $min',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('人', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(current >= min ? '拼单成功！' : '还差 ${min - current} 人成单',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (deadline != null)
            Text('截止: ${deadline.substring(0, 16)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          Text('第 $round 轮', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 32),
          // Action button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: userJoined
                ? OutlinedButton(
                    onPressed: () {
                      context.read<ExpertTeamBloc>().add(
                            ExpertTeamCancelGroupBuy(widget.activityId),
                          );
                    },
                    child: const Text('取消报名'),
                  )
                : ElevatedButton(
                    onPressed: current >= min ? null : () {
                      context.read<ExpertTeamBloc>().add(
                            ExpertTeamJoinGroupBuy(widget.activityId),
                          );
                    },
                    child: Text(current >= min ? '已成单' : '立即报名'),
                  ),
          ),
        ],
      ),
    );
  }
}
