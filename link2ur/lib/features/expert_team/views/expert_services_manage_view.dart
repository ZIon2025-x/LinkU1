import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:link2ur/core/utils/error_localizer.dart';
import 'package:link2ur/core/utils/l10n_extension.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';

class ExpertServicesManageView extends StatelessWidget {
  final String expertId;
  const ExpertServicesManageView({super.key, required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      )..add(ExpertTeamLoadServices(expertId)),
      child: _ServicesBody(expertId: expertId),
    );
  }
}

class _ServicesBody extends StatelessWidget {
  final String expertId;
  const _ServicesBody({required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpertTeamBloc, ExpertTeamState>(
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
      builder: (context, state) {
        final services = state.services;
        return Scaffold(
          appBar: AppBar(title: const Text('服务管理')),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showCreateServiceDialog(context),
            child: const Icon(Icons.add),
          ),
          body: services.isEmpty
              ? const Center(child: Text('暂无服务，点击右下角创建'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final s = services[index];
                    return _ServiceCard(
                      service: s,
                      expertId: expertId,
                    );
                  },
                ),
        );
      },
    );
  }

  void _showCreateServiceDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('创建服务'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '服务名称'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: '描述'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: '价格 (GBP)', prefixText: '£'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              final price = double.tryParse(priceCtrl.text) ?? 0;
              if (nameCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请填写完整信息')),
                );
                return;
              }
              context.read<ExpertTeamBloc>().add(ExpertTeamCreateService(
                expertId: expertId,
                data: {
                  'service_name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'base_price': price,
                },
              ));
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final String expertId;

  const _ServiceCard({required this.service, required this.expertId});

  @override
  Widget build(BuildContext context) {
    final name = service['service_name'] ?? '';
    final price = service['base_price'] ?? 0;
    final currency = service['currency'] ?? 'GBP';
    final status = service['status'] ?? '';
    final viewCount = service['view_count'] ?? 0;
    final appCount = service['application_count'] ?? 0;

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
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: status == 'active'
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status == 'active' ? '上架' : '下架',
                    style: TextStyle(
                      color: status == 'active' ? Colors.green : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$currency ${price is double ? price.toStringAsFixed(2) : price}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '浏览 $viewCount · 申请 $appCount',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    final id = service['id'];
                    if (id != null) {
                      context.read<ExpertTeamBloc>().add(ExpertTeamDeleteService(
                        expertId: expertId,
                        serviceId: id as int,
                      ));
                    }
                  },
                  child: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
