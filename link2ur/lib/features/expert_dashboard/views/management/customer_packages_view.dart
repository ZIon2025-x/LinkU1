import 'package:flutter/material.dart';

import '../../../../data/repositories/package_purchase_repository.dart';
import 'package_redemption_scan_view.dart';

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
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => PackageRedemptionScanView(
              expertId: widget.expertId,
              repository: widget.repository,
            ),
          ),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的客户 · 套餐'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: '扫码核销',
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
              segments: const [
                ButtonSegment(value: 'active', label: Text('使用中')),
                ButtonSegment(value: 'exhausted', label: Text('已用完')),
                ButtonSegment(value: 'expired', label: Text('已过期')),
                ButtonSegment(value: 'all', label: Text('全部')),
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
        label: const Text('扫码核销'),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('暂无客户套餐数据'));
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
                            ? NetworkImage(p['user_avatar'] as String)
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
                              p['user_name'] as String? ?? '匿名用户',
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
                  Text('已核销 $used / $total 次'),
                  if (breakdown != null && breakdown.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('子服务进度:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    ...breakdown.entries.map((e) {
                      final entry = e.value as Map<String, dynamic>;
                      final t = (entry['total'] as num?)?.toInt() ?? 0;
                      final u = (entry['used'] as num?)?.toInt() ?? 0;
                      final done = u >= t;
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
                            Text(
                              '服务 #${e.key}: $u / $t',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (p['expires_at'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '到期: ${(p['expires_at'] as String).substring(0, 10)}',
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
    Color c;
    String label;
    switch (status) {
      case 'active':
        c = Colors.green;
        label = '使用中';
        break;
      case 'exhausted':
        c = Colors.orange;
        label = '已用完';
        break;
      case 'expired':
        c = Colors.red;
        label = '已过期';
        break;
      default:
        c = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c),
      ),
      child: Text(label, style: TextStyle(color: c, fontSize: 11)),
    );
  }
}
