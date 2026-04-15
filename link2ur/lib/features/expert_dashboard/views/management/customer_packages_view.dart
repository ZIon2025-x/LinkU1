import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../data/repositories/package_purchase_repository.dart';

/// 团队 "我的客户" view (A1)
///
/// 列出所有买过此团队套餐的用户和套餐余额。
/// 顶部有"扫码核销"快捷按钮。
class CustomerPackagesView extends StatefulWidget {
  final String expertId;
  final PackagePurchaseRepository repository;

  const CustomerPackagesView({
    super.key,
    required this.expertId,
    required this.repository,
  });

  @override
  State<CustomerPackagesView> createState() => _CustomerPackagesViewState();
}

class _CustomerPackagesViewState extends State<CustomerPackagesView> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'active';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.getCustomerPackages(
        widget.expertId,
        statusFilter: _statusFilter == 'all' ? null : _statusFilter,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _items = (data['items'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openScanner() {
    context
        .push('/expert-dashboard/${widget.expertId}/management/package-redeem')
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.customerPackagesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: l10n.customerPackagesScanRedeem,
            onPressed: _openScanner,
          ),
        ],
      ),
      body: Column(
        children: [
          // 过滤器
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'active', label: Text(l10n.packageStatusActive)),
                ButtonSegment(value: 'exhausted', label: Text(l10n.packageStatusExhausted)),
                ButtonSegment(value: 'expired', label: Text(l10n.packageStatusExpired)),
                ButtonSegment(value: 'all', label: Text(l10n.packageStatusAll)),
              ],
              selected: {_statusFilter},
              onSelectionChanged: (s) {
                setState(() => _statusFilter = s.first);
                _load();
              },
            ),
          ),
          Expanded(
            child: _buildList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanner,
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(l10n.customerPackagesScanRedeem),
      ),
    );
  }

  Widget _buildList() {
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(child: Text(l10n.customerPackagesEmpty));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final p = _items[index];
          final remaining = (p['remaining_sessions'] as num?)?.toInt() ?? 0;
          final total = (p['total_sessions'] as num?)?.toInt() ?? 0;
          final used = total - remaining;
          final progress = total > 0 ? used / total : 0.0;
          final status = p['status'] as String? ?? '';
          final breakdown = p['bundle_breakdown'] as Map<String, dynamic>?;
          final subNames = p['sub_service_names'] as Map<String, dynamic>?;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: p['user_avatar'] != null &&
                                (p['user_avatar'] as String).isNotEmpty
                            ? NetworkImage(Helpers.getImageUrl(p['user_avatar'] as String))
                            : null,
                        child: p['user_avatar'] == null ||
                                (p['user_avatar'] as String).isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['user_name'] as String? ?? l10n.customerPackagesAnonymousUser,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              p['service_name'] as String? ?? '',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      _statusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 4),
                  Text(l10n.customerPackagesUsedCount(used, total)),
                  if (breakdown != null && breakdown.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(l10n.customerPackagesSubServiceProgress,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    ...breakdown.entries.map((e) {
                      final entry = e.value as Map<String, dynamic>;
                      final t = (entry['total'] as num?)?.toInt() ?? 0;
                      final u = (entry['used'] as num?)?.toInt() ?? 0;
                      final done = u >= t;
                      final nameMap = subNames?[e.key] as Map<String, dynamic>?;
                      final subName = (nameMap?['service_name'] as String?) ??
                          (nameMap?['service_name_en'] as String?) ??
                          (nameMap?['service_name_zh'] as String?) ??
                          '#${e.key}';
                      return Padding(
                        padding: const EdgeInsets.only(top: 4, left: 8),
                        child: Row(
                          children: [
                            Icon(
                              done ? Icons.check_circle : Icons.circle_outlined,
                              size: 14,
                              color: done ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l10n.customerPackagesSubServiceLine(subName, u, t),
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (p['expires_at'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.customerPackagesExpiresOn((p['expires_at'] as String).substring(0, 10)),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusBadge(String status) {
    final l10n = context.l10n;
    Color c;
    String label;
    switch (status) {
      case 'active':
        c = Colors.green;
        label = l10n.packageStatusActive;
        break;
      case 'exhausted':
        c = Colors.orange;
        label = l10n.packageStatusExhausted;
        break;
      case 'expired':
        c = Colors.red;
        label = l10n.packageStatusExpired;
        break;
      case 'released':
        c = Colors.teal;
        label = l10n.packageStatusReleased;
        break;
      case 'refunded':
        c = Colors.blue;
        label = l10n.packageStatusRefunded;
        break;
      case 'partially_refunded':
        c = Colors.indigo;
        label = l10n.packageStatusPartiallyRefunded;
        break;
      case 'disputed':
        c = Colors.deepOrange;
        label = l10n.packageStatusDisputed;
        break;
      case 'cancelled':
        c = Colors.grey;
        label = l10n.packageStatusCancelled;
        break;
      default:
        c = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c),
      ),
      child: Text(label, style: TextStyle(color: c, fontSize: 11)),
    );
  }
}
