import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';

class ExpertCouponsView extends StatelessWidget {
  final String expertId;
  const ExpertCouponsView({super.key, required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      )..add(ExpertTeamLoadCoupons(expertId)),
      child: _CouponsBody(expertId: expertId),
    );
  }
}

class _CouponsBody extends StatelessWidget {
  final String expertId;
  const _CouponsBody({required this.expertId});

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
        final coupons = state.coupons;
        return Scaffold(
          appBar: AppBar(title: const Text('优惠券管理')),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showCreateDialog(context),
            child: const Icon(Icons.add),
          ),
          body: coupons.isEmpty
              ? const Center(child: Text('暂无优惠券'))
              : ListView.builder(
                  itemCount: coupons.length,
                  itemBuilder: (context, index) {
                    final c = coupons[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        title: Text(c['name'] ?? ''),
                        subtitle: Text('${c['type'] == 'percentage' ? '${c['discount_value']}%' : '£${c['discount_value']}'} · ${c['status']}'),
                        trailing: c['status'] == 'active'
                            ? IconButton(
                                icon: const Icon(Icons.block, color: Colors.red),
                                onPressed: () {
                                  context.read<ExpertTeamBloc>().add(
                                    ExpertTeamDeactivateCoupon(
                                      expertId: expertId,
                                      couponId: c['id'] as int,
                                    ),
                                  );
                                },
                              )
                            : const Icon(Icons.check_circle, color: Colors.grey),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    String type = 'fixed_amount';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('创建优惠券'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名称')),
              const SizedBox(height: 8),
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: '优惠码')),
              const SizedBox(height: 8),
              TextField(controller: valueCtrl, decoration: const InputDecoration(labelText: '优惠值'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              final now = DateTime.now();
              context.read<ExpertTeamBloc>().add(ExpertTeamCreateCoupon(
                expertId: expertId,
                data: {
                  'name': nameCtrl.text,
                  'code': codeCtrl.text,
                  'type': type,
                  'discount_value': int.tryParse(valueCtrl.text) ?? 0,
                  'valid_from': now.toIso8601String(),
                  'valid_until': now.add(const Duration(days: 30)).toIso8601String(),
                },
              ));
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
    // Controllers will be GC'd with the dialog
  }
}
